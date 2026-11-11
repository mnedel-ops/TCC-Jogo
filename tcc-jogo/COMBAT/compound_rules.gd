class_name CompoundRules
extends RefCounted
## Regras de formação de compostos (iônicos, covalentes e moléculas elementares).
##
## A seleção do jogador é reduzida a elementos distintos; as QUANTIDADES são
## calculadas aqui (Mg + Cl -> MgCl₂). Nada nesta classe depende de combate.

const MAX_ELEMENTS := 4
const MAX_QTY := 6
const MAX_ATOMS := 12
const MAX_BOND_ORDER := 3
# |Δχ| abaixo disto = ligação apolar.
const POLAR_THRESHOLD := 0.4
# Limite de passos da busca de moléculas (evita travar a UI).
const SEARCH_BUDGET := 60000
const SUPPORT_ELEMENTAL_MOLECULES := true
# false: só liga elementos DIFERENTES (evita peróxidos, C₂H₂ etc.), exceto
# moléculas elementares (O₂, N₂...).
const ALLOW_HOMONUCLEAR_BONDS := false

# Alótropos de um único elemento que o modelo de valência não deriva sozinho.
# atomic_number -> {nº de átomos -> ordens das ligações}. As ligações entre
# átomos iguais são só informativas (O₃ é ressonante; P₄ é um tetraedro).
# Quantos átomos entram = quantas criaturas do mesmo elemento foram escolhidas.
const ALLOTROPES := {
	8: {3: [2, 1]},
	15: {4: [1, 1, 1, 1, 1, 1]},
}

# Nomes/fórmulas canônicos. Chave: "elemento:qtd|elemento:qtd" ordenado por
# número atômico. Só vale para elementos com atomic_number definido.
const KNOWN := {
	"1:2": ["H₂", "Gás hidrogênio"],
	"7:2": ["N₂", "Gás nitrogênio"],
	"8:2": ["O₂", "Gás oxigênio"],
	"8:3": ["O₃", "Ozônio"],
	"15:4": ["P₄", "Fósforo branco"],
	"17:2": ["Cl₂", "Gás cloro"],
	"1:2|8:1": ["H₂O", "Água"],
	"1:3|7:1": ["NH₃", "Amônia"],
	"1:1|17:1": ["HCl", "Ácido clorídrico"],
	"1:4|6:1": ["CH₄", "Metano"],
	"6:1|8:2": ["CO₂", "Dióxido de carbono"],
	"11:1|17:1": ["NaCl", "Cloreto de sódio"],
	"12:1|17:2": ["MgCl₂", "Cloreto de magnésio"],
	"8:1|11:2": ["Na₂O", "Óxido de sódio"],
	"8:1|12:1": ["MgO", "Óxido de magnésio"],
	"8:3|13:2": ["Al₂O₃", "Óxido de alumínio"],
}


# ---------------------------------------------------------------------------
# API pública
# ---------------------------------------------------------------------------

## Dois metais (de qualquer espécie) formam uma Mistura, não um composto.
static func is_mixture(sheets: Array[AlchemonSheet]) -> bool:
	if sheets.size() != 2 or sheets[0] == null or sheets[1] == null:
		return false
	return sheets[0].is_metal() and sheets[1].is_metal()


## Resultado da combinação, ou null se ela não forma composto.
static func resolve(sheets: Array[AlchemonSheet]) -> CompoundData:
	return _analyze(sheets).get("data") as CompoundData


## "" se a combinação forma composto; senão o motivo da rejeição.
static func failure_reason(sheets: Array[AlchemonSheet]) -> String:
	var r := _analyze(sheets)
	return "" if r.get("data") != null else String(r.get("reason", "Impossible bond."))


## Elementos distintos (por element_key), ordenados de forma estável.
static func unique_elements(sheets: Array[AlchemonSheet]) -> Array[AlchemonSheet]:
	var seen: Dictionary = {}
	for s in sheets:
		if s != null and not seen.has(s.element_key()):
			seen[s.element_key()] = s
	var keys := seen.keys()
	keys.sort()
	var out: Array[AlchemonSheet] = []
	for k in keys:
		out.append(seen[k])
	return out


# ---------------------------------------------------------------------------
# Classificação
# ---------------------------------------------------------------------------

static func _fail(reason: String) -> Dictionary:
	return {"data": null, "reason": reason}


static func _analyze(sheets: Array[AlchemonSheet]) -> Dictionary:
	if sheets.is_empty():
		return _fail("Select at least one Alchemon.")
	for s in sheets:
		if s == null:
			return _fail("Unknown species in selection.")
		var problem := s.chemistry_problem()
		if problem != "":
			return _fail(problem)

	var elems := unique_elements(sheets)
	if elems.size() > MAX_ELEMENTS:
		return _fail("Max %d different elements per Component." % MAX_ELEMENTS)

	var metals: Array[AlchemonSheet] = []
	var others: Array[AlchemonSheet] = []
	for e in elems:
		if e.chem_category() == AlchemonSheet.Category.GAS_NOBRE:
			return _fail("%s already has a full octet and cannot bond." % e.creature_name)
		if e.is_metal():
			metals.append(e)
		else:
			others.append(e)

	if others.is_empty():
		if metals.size() == 1:
			return _fail("A lone metal does not form a compound.")
		return _fail("Metals only bond as a Mixture (2 metals).")
	if metals.is_empty():
		var copies := 0
		for sh in sheets:
			if sh.element_key() == others[0].element_key():
				copies += 1
		return _covalent(others, copies)
	return _ionic(metals, others)


# ---------------------------------------------------------------------------
# Iônico: Σ n_i · q_i = 0 com mdc(n) = 1
# ---------------------------------------------------------------------------

static func _ionic(cations: Array[AlchemonSheet], anions: Array[AlchemonSheet]) -> Dictionary:
	var elems: Array[AlchemonSheet] = []
	elems.append_array(cations)
	elems.append_array(anions)

	var options: Array = []
	for e in elems:
		var want_positive := e.is_metal()
		var states: Array[int] = []
		for q in e.chem_oxidation_states():
			if q != 0 and (q > 0) == want_positive:
				states.append(q)
		if states.is_empty():
			return _fail("%s has no %s oxidation state." % [e.creature_name, "positive" if want_positive else "negative"])
		options.append(states)

	var best: Dictionary = {}
	_pick_states(options, 0, [], 0, best)
	if best.is_empty():
		return _fail("Charges do not balance: no proportion up to %d atoms of each element neutralizes them." % MAX_QTY)

	var composition: Dictionary = {}
	var charge := 0
	for i in elems.size():
		composition[elems[i].element_key()] = best.qty[i]
		charge += int(best.qty[i]) * int(best.charges[i])
	if charge != 0:
		return _fail("Charges do not balance.")

	var data := CompoundData.new()
	data.bond_type = CompoundData.BondType.IONIC
	data.composition = composition
	data.total_charge = 0
	_finish(data, elems)
	return {"data": data, "reason": ""}


static func _pick_states(options: Array, idx: int, chosen: Array, rank: int, best: Dictionary) -> void:
	if idx == options.size():
		var qty := _best_quantities(chosen)
		if qty.is_empty():
			return
		var total := 0
		for q in qty:
			total += int(q)
		var cand := {"rank": rank, "total": total, "qty": qty, "charges": chosen.duplicate()}
		if best.is_empty() or _is_better(cand, best):
			best.clear()
			best.merge(cand)
		return
	for k in options[idx].size():
		chosen.append(options[idx][k])
		_pick_states(options, idx + 1, chosen, rank + k, best)
		chosen.pop_back()


static func _is_better(a: Dictionary, b: Dictionary) -> bool:
	if a.rank != b.rank:
		return a.rank < b.rank
	if a.total != b.total:
		return a.total < b.total
	for i in a.qty.size():
		if a.qty[i] != b.qty[i]:
			return a.qty[i] < b.qty[i]
	return false


# Menor total (e, no empate, menor vetor lexicográfico) que neutraliza as cargas.
static func _best_quantities(charges: Array) -> Array:
	var holder := {"qty": [], "total": MAX_ATOMS + 1}
	_qty_rec(charges, 0, [], 0, 0, holder)
	return holder.qty


static func _qty_rec(charges: Array, idx: int, cur: Array, sum: int, total: int, holder: Dictionary) -> void:
	var n := charges.size()
	if idx == n:
		if sum == 0 and total < holder.total and _gcd_all(cur) == 1:
			holder.total = total
			holder.qty = cur.duplicate()
		return
	for q in range(1, MAX_QTY + 1):
		var t := total + q
		if t + (n - idx - 1) >= holder.total:
			break
		cur.append(q)
		_qty_rec(charges, idx + 1, cur, sum + q * int(charges[idx]), t, holder)
		cur.pop_back()


static func _gcd(a: int, b: int) -> int:
	while b != 0:
		var t := b
		b = a % b
		a = t
	return absi(a)


static func _gcd_all(values: Array) -> int:
	var g := 0
	for v in values:
		g = _gcd(g, int(v))
	return g


# ---------------------------------------------------------------------------
# Covalente: cada átomo fecha exatamente bonding_capacity ligações
# ---------------------------------------------------------------------------

static func _covalent(elems_in: Array[AlchemonSheet], copies: int = 1) -> Dictionary:
	for e in elems_in:
		if e.chem_capacity() < 1:
			return _fail("%s already has a full octet and cannot bond." % e.creature_name)

	# Átomo de maior capacidade primeiro (centro da molécula).
	var elems: Array[AlchemonSheet] = elems_in.duplicate()
	elems.sort_custom(func(a: AlchemonSheet, b: AlchemonSheet) -> bool:
		if a.chem_capacity() != b.chem_capacity():
			return a.chem_capacity() > b.chem_capacity()
		return a.element_key() < b.element_key())

	var ctx := {"budget": SEARCH_BUDGET}
	var found: Dictionary = {}

	if elems.size() == 1:
		if not SUPPORT_ELEMENTAL_MOLECULES:
			return _fail("%s cannot bond with itself." % elems[0].creature_name)
		# Elemento sozinho: nº de átomos = nº de criaturas iguais (mínimo 2).
		var atoms := maxi(copies, 2)
		if atoms == 2:
			found = _realize(elems, [2], true, ctx)
		else:
			found = _allotrope(elems[0], atoms)
		if found.is_empty():
			return _fail("%s cannot form a stable molecule of %d atoms alone." % [elems[0].creature_name, atoms])
	else:
		for total in range(elems.size(), MAX_ATOMS + 1):
			found = _enum_vectors(elems, total, 0, [], ctx)
			if not found.is_empty() or ctx.budget <= 0:
				break
		if found.is_empty():
			return _fail("No molecule closes every valence (up to %d atoms)." % MAX_ATOMS)

	var composition: Dictionary = {}
	for i in elems.size():
		composition[elems[i].element_key()] = found.qty[i]

	var data := CompoundData.new()
	data.composition = composition
	data.total_charge = 0
	data.bonds.assign(found.bonds)
	data.bond_type = _covalent_polarity(elems, found.bonds)
	_finish(data, elems)
	return {"data": data, "reason": ""}


static func _allotrope(e: AlchemonSheet, atoms: int) -> Dictionary:
	var forms: Dictionary = ALLOTROPES.get(e.atomic_number, {})
	if e.atomic_number <= 0 or not forms.has(atoms):
		return {}
	var bonds: Array = []
	for order in forms[atoms]:
		bonds.append({"a": e.element_key(), "b": e.element_key(), "order": order})
	return {"qty": [atoms], "bonds": bonds}


# Vetores de quantidade com soma == total, em ordem lexicográfica crescente.
static func _enum_vectors(elems: Array[AlchemonSheet], total: int, idx: int, cur: Array, ctx: Dictionary) -> Dictionary:
	var n := elems.size()
	if idx == n - 1:
		var last := total - _sum(cur)
		if last < 1 or last > MAX_QTY:
			return {}
		cur.append(last)
		var r := _realize(elems, cur, false, ctx)
		cur.pop_back()
		return r
	var remaining_slots := n - idx - 1
	for q in range(1, MAX_QTY + 1):
		if _sum(cur) + q + remaining_slots > total:
			break
		cur.append(q)
		var r := _enum_vectors(elems, total, idx + 1, cur, ctx)
		cur.pop_back()
		if not r.is_empty() or ctx.budget <= 0:
			return r
	return {}


static func _sum(values: Array) -> int:
	var t := 0
	for v in values:
		t += int(v)
	return t


# Tenta montar a molécula; devolve {"qty": [...], "bonds": [...]} ou {}.
static func _realize(elems: Array[AlchemonSheet], qty: Array, allow_same: bool, ctx: Dictionary) -> Dictionary:
	var rem: Array[int] = []
	var atom_elem: Array[int] = []
	for i in elems.size():
		for _k in int(qty[i]):
			rem.append(elems[i].chem_capacity())
			atom_elem.append(i)
	var n := rem.size()
	if n < 2 or n > MAX_ATOMS:
		return {}

	var total := _sum(rem)
	var biggest := 0
	for c in rem:
		biggest = maxi(biggest, c)
	if total % 2 != 0 or total < 2 * (n - 1) or biggest > total - biggest:
		return {}

	var edges: Array = []
	if not _fill(ctx, rem, atom_elem, n, 0, 1, edges, allow_same or ALLOW_HOMONUCLEAR_BONDS):
		return {}

	var bonds: Array = []
	for e in edges:
		bonds.append({
			"a": elems[atom_elem[e[0]]].element_key(),
			"b": elems[atom_elem[e[1]]].element_key(),
			"order": e[2],
		})
	return {"qty": qty.duplicate(), "bonds": bonds}


static func _fill(ctx: Dictionary, rem: Array[int], atom_elem: Array[int], n: int, i: int, j: int, edges: Array, allow_same: bool) -> bool:
	if ctx.budget <= 0:
		return false
	ctx.budget -= 1
	if i >= n:
		return _connected(n, edges)
	if j >= n:
		if rem[i] != 0:
			return false
		return _fill(ctx, rem, atom_elem, n, i + 1, i + 2, edges, allow_same)

	var tail := 0
	for k in range(j, n):
		tail += rem[k]
	if rem[i] > tail:
		return false

	var max_order := 0
	if allow_same or atom_elem[i] != atom_elem[j]:
		max_order = mini(MAX_BOND_ORDER, mini(rem[i], rem[j]))
	for o in range(max_order, -1, -1):
		rem[i] -= o
		rem[j] -= o
		if o > 0:
			edges.append([i, j, o])
		if _fill(ctx, rem, atom_elem, n, i, j + 1, edges, allow_same):
			return true
		if o > 0:
			edges.pop_back()
		rem[i] += o
		rem[j] += o
	return false


static func _connected(n: int, edges: Array) -> bool:
	var parent: Array[int] = []
	for i in n:
		parent.append(i)
	for e in edges:
		var a := _find(parent, e[0])
		var b := _find(parent, e[1])
		if a != b:
			parent[a] = b
	var root := _find(parent, 0)
	for i in range(1, n):
		if _find(parent, i) != root:
			return false
	return true


static func _find(parent: Array[int], x: int) -> int:
	while parent[x] != x:
		parent[x] = parent[parent[x]]
		x = parent[x]
	return x


static func _covalent_polarity(elems: Array[AlchemonSheet], bonds: Array) -> CompoundData.BondType:
	var by_key: Dictionary = {}
	for e in elems:
		by_key[e.element_key()] = e
	var widest := 0.0
	for b in bonds:
		var diff := absf(by_key[b.a].chem_electronegativity() - by_key[b.b].chem_electronegativity())
		widest = maxf(widest, diff)
	return CompoundData.BondType.COVALENT_POLAR if widest >= POLAR_THRESHOLD else CompoundData.BondType.COVALENT_NONPOLAR


# ---------------------------------------------------------------------------
# Fórmula e nome
# ---------------------------------------------------------------------------

static func _finish(data: CompoundData, elems: Array[AlchemonSheet]) -> void:
	data.chemical_formula = _format_formula(data, elems)
	var known_key := _known_key(data.composition)
	if known_key != "" and KNOWN.has(known_key):
		data.chemical_formula = KNOWN[known_key][0]
		data.compound_name = KNOWN[known_key][1]
	else:
		data.compound_name = data.chemical_formula


static func _format_formula(data: CompoundData, elems: Array[AlchemonSheet]) -> String:
	var ordered: Array[AlchemonSheet] = elems.duplicate()
	var ionic := data.bond_type == CompoundData.BondType.IONIC
	ordered.sort_custom(func(a: AlchemonSheet, b: AlchemonSheet) -> bool:
		var ra := _formula_rank(a, ionic)
		var rb := _formula_rank(b, ionic)
		if ra != rb:
			return ra < rb
		if a.chem_electronegativity() != b.chem_electronegativity():
			return a.chem_electronegativity() < b.chem_electronegativity()
		return a.element_key() < b.element_key())
	var out := ""
	for e in ordered:
		out += e.chem_symbol() + CompoundData.subscript(int(data.composition[e.element_key()]))
	return out


# Iônico: metais primeiro. Covalente: carbono, hidrogênio, resto por eletronegatividade.
static func _formula_rank(s: AlchemonSheet, ionic: bool) -> int:
	if ionic:
		return 0 if s.is_metal() else 1
	if s.atomic_number == 6:
		return 0
	if s.atomic_number == 1:
		return 1
	return 2


static func _known_key(composition: Dictionary) -> String:
	var keys := composition.keys()
	keys.sort()
	var parts: Array[String] = []
	for k in keys:
		if int(k) <= 0:
			return ""
		parts.append("%d:%d" % [int(k), int(composition[k])])
	return "|".join(parts)
