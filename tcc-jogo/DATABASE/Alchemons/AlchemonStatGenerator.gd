class_name AlchemonStatGenerator
extends RefCounted
## Gera os atributos base (30..110) a partir de propriedades químicas tabeladas.
##   HP         <- entalpia de atomização (kJ/mol)
##   Ataque     <- reatividade: metal = R_MAX * I_MIN / I1 ; ametal/metaloide = afinidade eletrônica
##                 gás nobre = inerte (reatividade 0)
##   Defesa     <- primeira energia de ionização I1 (kJ/mol)
##   Velocidade <- eletronegatividade de Pauling / raiz(massa atômica)
##                 sem eletronegatividade (gás nobre) = só a massa: 1 / raiz(massa)
## Cada propriedade passa por normalização min-max e é mapeada para [BASE_MIN, BASE_MAX].
##
## Os dados químicos da ficha são a fonte oficial: esta classe só LÊ eles e
## ESCREVE os atributos base. Nunca altera os dados químicos originais.

const BASE_MIN := 30
const BASE_MAX := 110

# Limites de referência da Tabela Periódica.
const I_MIN := 375.7   # Cs
const I_MAX := 2372.3  # He
const H_MIN := 0.0
const H_MAX := 850.0   # W
const R_MIN := 0.0
const R_MAX := 350.0   # Cl (afinidade eletrônica)
const K_MIN := 0.05    # Fr
const K_MAX := 2.19    # H
const M_MAX := 294.0   # Og (maior massa tabelada)


static func _norm(value: float, lo: float, hi: float) -> float:
	return clampf((value - lo) / (hi - lo), 0.0, 1.0)


static func _to_base(normalized: float) -> int:
	return BASE_MIN + roundi(normalized * float(BASE_MAX - BASE_MIN))


## Retorna {base_hp, base_attack, base_defense, base_mechanical_speed}.
## electronegativity <= 0 = indisponível: a velocidade usa só a massa.
## is_noble_gas = true: ataque fixo no mínimo (elemento inerte, sem afinidade usada).
static func generate_base_stats(mass: float, ionization_energy: float, electron_affinity: float, electronegativity: float, atomization_enthalpy: float, is_metal: bool, is_noble_gas: bool = false) -> Dictionary:
	var reactivity: float
	if is_noble_gas:
		reactivity = R_MIN
	elif is_metal:
		reactivity = R_MAX * I_MIN / maxf(ionization_energy, 1.0)
	else:
		reactivity = electron_affinity
	var speed_norm: float
	if electronegativity > 0.0:
		speed_norm = _norm(electronegativity / sqrt(maxf(mass, 1.0)), K_MIN, K_MAX)
	else:
		speed_norm = _norm(1.0 / sqrt(maxf(mass, 1.0)), 1.0 / sqrt(M_MAX), 1.0)
	return {
		"base_hp": _to_base(_norm(atomization_enthalpy, H_MIN, H_MAX)),
		"base_attack": _to_base(_norm(reactivity, R_MIN, R_MAX)),
		"base_defense": _to_base(_norm(ionization_energy, I_MIN, I_MAX)),
		"base_mechanical_speed": _to_base(speed_norm),
	}


## Mensagem de erro (elemento + propriedade) se faltar dado necessário; "" se ok.
##   massa atômica ............ obrigatória, > 0
##   energia de ionização ..... obrigatória, > 0
##   entalpia de atomização ... obrigatória, aceita 0 (ex.: gases nobres)
##   afinidade eletrônica ..... só ametal/metaloide; pode ser negativa, 0 ou positiva
##   eletronegatividade ....... obrigatória, exceto gás nobre (indisponível em Pauling)
static func validate(sheet: AlchemonSheet) -> String:
	var who := sheet.chem_symbol()
	if who == "":
		who = "id %d" % sheet.id
	if sheet.atomic_mass <= 0:
		return "%s: atomic_mass missing (must be > 0)." % who
	if sheet.first_ionization_energy <= 0.0:
		return "%s: first_ionization_energy missing (must be > 0)." % who
	if not sheet.has_atomization_enthalpy():
		return "%s: atomization_enthalpy missing (use 0 if the value is really zero)." % who
	var cat := sheet.chem_category()
	if cat != AlchemonSheet.Category.GAS_NOBRE:
		if sheet.electronegativity <= 0.0:
			return "%s: electronegativity missing (only noble gases may omit it)." % who
		if cat != AlchemonSheet.Category.METAL and not sheet.has_electron_affinity():
			return "%s: electron_affinity missing (required for nonmetal/metalloid)." % who
	return ""


## True se a ficha tem os dados químicos necessários.
static func has_data(sheet: AlchemonSheet) -> bool:
	return validate(sheet) == ""


static func from_sheet(sheet: AlchemonSheet) -> Dictionary:
	return generate_base_stats(
		float(sheet.atomic_mass),
		sheet.first_ionization_energy,
		sheet.electron_affinity,
		sheet.electronegativity,
		sheet.atomization_enthalpy,
		sheet.is_metal(),
		sheet.chem_category() == AlchemonSheet.Category.GAS_NOBRE)


## Escreve os atributos gerados na ficha. Se faltar dado, NÃO altera nada,
## registra o erro (elemento + propriedade) e retorna false.
static func apply_to(sheet: AlchemonSheet) -> bool:
	var problem := validate(sheet)
	if problem != "":
		push_error("AlchemonStatGenerator: " + problem)
		return false
	var s := from_sheet(sheet)
	sheet.base_hp = s["base_hp"]
	sheet.base_attack = s["base_attack"]
	sheet.base_defense = s["base_defense"]
	sheet.base_mechanical_speed = s["base_mechanical_speed"]
	return true


## Texto de tooltip (propriedade química + relação com o atributo de jogo).
## stat: "hp" | "attack" | "defense" | "speed". Descreve as fórmulas de generate_base_stats;
## lê da ficha só para mostrar o valor químico, sem recalcular nada.
static func stat_tooltip(stat: String, sheet: AlchemonSheet) -> String:
	var note := "\n\nAtributo de jogo derivado da propriedade química (normalizada para a faixa %d–%d), não a propriedade medida." % [BASE_MIN, BASE_MAX]
	match stat:
		"hp":
			return "HP — Entalpia molar de atomização (ΔH°at)\nEnergia necessária para separar os átomos de uma substância em átomos isolados no estado gasoso. Fundamenta a resistência do Alchemon.\nValor: %.1f kJ/mol%s" % [sheet.atomization_enthalpy, note]
		"attack":
			if sheet.chem_category() == AlchemonSheet.Category.GAS_NOBRE:
				return "Ataque — Reatividade\nGás nobre é inerte: o ataque fica no mínimo.%s" % note
			if sheet.is_metal():
				return "Ataque — Primeira energia de ionização (metal)\nPara metais, o potencial ofensivo cresce quanto menor a I₁ (maior facilidade de perder elétron).\nValor de I₁: %.1f kJ/mol%s" % [sheet.first_ionization_energy, note]
			return "Ataque — Afinidade eletrônica (ametal/metaloide)\nEnergia associada ao ganho de um elétron por um átomo isolado no estado gasoso. Fundamenta o potencial ofensivo do Alchemon.\nValor: %.1f kJ/mol%s" % [sheet.electron_affinity, note]
		"defense":
			return "Defesa — Primeira energia de ionização (I₁)\nEnergia necessária para remover o primeiro elétron de um átomo isolado no estado gasoso. Fundamenta a capacidade defensiva do Alchemon.\nValor: %.1f kJ/mol%s" % [sheet.first_ionization_energy, note]
		"speed":
			return "Velocidade — Índice cinético (K = χ/√M)\nÍndice derivado da eletronegatividade de Pauling (χ) e da massa atômica (M). Fundamenta a velocidade do Alchemon.\nχ = %.2f | M = %s%s" % [sheet.electronegativity, str(sheet.atomic_mass), note]
	return ""


# ---------------------------------------------------------------------------
# Detalhamento para a interface (aba Stats do menu Alchemon).
# Só LÊ a ficha e repete as contas de generate_base_stats passo a passo;
# não altera nenhum dado nem o cálculo de combate.
# ---------------------------------------------------------------------------

const STAT_KEYS: Array[String] = ["hp", "attack", "defense", "speed", "energy"]


## Número com vírgula decimal (padrão pt-BR), ex.: fmt(0.5294, 3) = "0,529".
static func fmt(value: float, decimals: int = 1) -> String:
	return (("%." + str(decimals) + "f") % value).replace(".", ",")


## Valor normalizado para exibição; avisa quando o min-max foi limitado a [0, 1].
static func _norm_txt(value: float, lo: float, hi: float) -> String:
	var raw := (value - lo) / (hi - lo)
	if raw < 0.0 or raw > 1.0:
		return "%s (fora do intervalo 0 a 1, limitado a %s)" % [fmt(raw, 3), fmt(clampf(raw, 0.0, 1.0), 3)]
	return fmt(raw, 3)


static func category_name(cat: AlchemonSheet.Category) -> String:
	match cat:
		AlchemonSheet.Category.METAL:
			return "metal"
		AlchemonSheet.Category.AMETAL:
			return "ametal"
		AlchemonSheet.Category.METALOIDE:
			return "metaloide"
		AlchemonSheet.Category.GAS_NOBRE:
			return "gás nobre"
	return "indefinida"


## Explica a parte QUÍMICA de um atributo base.
## stat: "hp" | "attack" | "defense" | "speed" | "energy".
## Retorna {title, description, origin, source, formulas: Array, steps: Array,
##          base: int (gerado; -1 se não deriva de química), problem: String}.
## "problem" != "" = faltam dados químicos; formulas/steps ficam vazios.
static func describe_stat(stat: String, sheet: AlchemonSheet) -> Dictionary:
	var d := {
		"title": "", "description": "", "origin": "", "source": "",
		"formulas": [], "steps": [], "base": -1, "problem": "",
	}
	var span := BASE_MAX - BASE_MIN
	var problem := validate(sheet)
	match stat:
		"hp":
			d["title"] = "HP — Pontos de vida"
			d["description"] = "Quanto dano o Alchemon aguenta antes de desmaiar."
			d["origin"] = "Entalpia molar de atomização (ΔH°at): energia necessária para separar os átomos de uma substância em átomos isolados no estado gasoso."
			d["source"] = "%s kJ/mol" % fmt(sheet.atomization_enthalpy)
			if problem == "":
				var h := sheet.atomization_enthalpy
				var n := _norm(h, H_MIN, H_MAX)
				d["formulas"] = [
					"norm = (ΔH - %s) / (%s - %s)" % [fmt(H_MIN, 0), fmt(H_MAX, 0), fmt(H_MIN, 0)],
					"B = %d + arred(norm · %d)" % [BASE_MIN, span],
				]
				d["steps"] = [
					"norm = (%s - %s) / (%s - %s) = %s" % [fmt(h), fmt(H_MIN, 0), fmt(H_MAX, 0), fmt(H_MIN, 0), _norm_txt(h, H_MIN, H_MAX)],
					"B = %d + arred(%s · %d) = %d" % [BASE_MIN, fmt(n, 3), span, _to_base(n)],
				]
				d["base"] = _to_base(n)
		"attack":
			d["title"] = "Ataque — Poder ofensivo"
			d["description"] = "Escala o dano dos golpes: o dano cresce com o Ataque de quem bate e cai com a Defesa de quem apanha."
			var cat := sheet.chem_category()
			var r_text := ""
			var r: float = 0.0
			if cat == AlchemonSheet.Category.GAS_NOBRE:
				d["origin"] = "Categoria química: gás nobre. Regra de reatividade: gás nobre é inerte, então a reatividade é 0 (nenhuma propriedade medida é usada)."
				d["source"] = "Sem valor tabelado (inerte)"
				r = R_MIN
				r_text = "R = 0 (gás nobre é inerte)"
				d["formulas"] = ["R = 0 (gás nobre)"]
			elif cat == AlchemonSheet.Category.METAL:
				d["origin"] = "Categoria química: metal. Regra de reatividade: quanto menor a primeira energia de ionização (I₁), mais fácil perder elétron e maior a reatividade. R = Rmax · Imin / I₁."
				d["source"] = "I₁ = %s kJ/mol" % fmt(sheet.first_ionization_energy)
				r = R_MAX * I_MIN / maxf(sheet.first_ionization_energy, 1.0)
				r_text = "R = %s · %s / %s = %s" % [fmt(R_MAX, 0), fmt(I_MIN), fmt(sheet.first_ionization_energy), fmt(r)]
				d["formulas"] = ["R = %s · %s / I₁" % [fmt(R_MAX, 0), fmt(I_MIN)]]
			else:
				d["origin"] = "Categoria química: %s. Regra de reatividade: a reatividade é a afinidade eletrônica (EA), energia associada ao ganho de um elétron por um átomo isolado no estado gasoso." % category_name(cat)
				d["source"] = "EA = %s kJ/mol" % (fmt(sheet.electron_affinity) if sheet.has_electron_affinity() else "indisponível")
				r = sheet.electron_affinity
				r_text = "R = EA = %s" % fmt(r)
				d["formulas"] = ["R = EA"]
			if problem == "":
				var n := _norm(r, R_MIN, R_MAX)
				d["formulas"] = d["formulas"] + [
					"norm = (R - %s) / (%s - %s)" % [fmt(R_MIN, 0), fmt(R_MAX, 0), fmt(R_MIN, 0)],
					"B = %d + arred(norm · %d)" % [BASE_MIN, span],
				]
				d["steps"] = [
					r_text,
					"norm = (%s - %s) / (%s - %s) = %s" % [fmt(r), fmt(R_MIN, 0), fmt(R_MAX, 0), fmt(R_MIN, 0), _norm_txt(r, R_MIN, R_MAX)],
					"B = %d + arred(%s · %d) = %d" % [BASE_MIN, fmt(n, 3), span, _to_base(n)],
				]
				d["base"] = _to_base(n)
		"defense":
			d["title"] = "Defesa — Resistência ao dano"
			d["description"] = "Reduz o dano recebido: o dano é proporcional a Ataque ÷ Defesa."
			d["origin"] = "Primeira energia de ionização (I₁): energia necessária para remover o primeiro elétron de um átomo isolado no estado gasoso."
			d["source"] = "%s kJ/mol" % fmt(sheet.first_ionization_energy)
			if problem == "":
				var i1 := sheet.first_ionization_energy
				var n := _norm(i1, I_MIN, I_MAX)
				d["formulas"] = [
					"norm = (I₁ - %s) / (%s - %s)" % [fmt(I_MIN), fmt(I_MAX), fmt(I_MIN)],
					"B = %d + arred(norm · %d)" % [BASE_MIN, span],
				]
				d["steps"] = [
					"norm = (%s - %s) / (%s - %s) = %s" % [fmt(i1), fmt(I_MIN), fmt(I_MAX), fmt(I_MIN), _norm_txt(i1, I_MIN, I_MAX)],
					"B = %d + arred(%s · %d) = %d" % [BASE_MIN, fmt(n, 3), span, _to_base(n)],
				]
				d["base"] = _to_base(n)
		"speed":
			d["title"] = "Velocidade — Iniciativa"
			d["description"] = "Define a iniciativa: quem tem mais velocidade tende a agir antes na rodada."
			var mass := float(sheet.atomic_mass)
			d["source"] = "χ = %s | M = %s u" % [fmt(sheet.electronegativity, 2) if sheet.electronegativity > 0.0 else "indisponível", str(sheet.atomic_mass)]
			if sheet.electronegativity > 0.0:
				d["origin"] = "Eletronegatividade de Pauling (χ) e massa atômica (M). Índice cinético K = χ / √M: átomos leves e muito eletronegativos têm K alto."
				if problem == "":
					var k := sheet.electronegativity / sqrt(maxf(mass, 1.0))
					var n := _norm(k, K_MIN, K_MAX)
					d["formulas"] = [
						"K = χ / √M",
						"norm = (K - %s) / (%s - %s)" % [fmt(K_MIN, 2), fmt(K_MAX, 2), fmt(K_MIN, 2)],
						"B = %d + arred(norm · %d)" % [BASE_MIN, span],
					]
					d["steps"] = [
						"K = %s / √%s = %s" % [fmt(sheet.electronegativity, 2), fmt(mass, 0), fmt(k, 3)],
						"norm = (%s - %s) / (%s - %s) = %s" % [fmt(k, 3), fmt(K_MIN, 2), fmt(K_MAX, 2), fmt(K_MIN, 2), _norm_txt(k, K_MIN, K_MAX)],
						"B = %d + arred(%s · %d) = %d" % [BASE_MIN, fmt(n, 3), span, _to_base(n)],
					]
					d["base"] = _to_base(n)
			else:
				d["origin"] = "Eletronegatividade indisponível na escala de Pauling (gás nobre): o índice cinético usa só a massa atômica, K = 1 / √M."
				if problem == "":
					var k := 1.0 / sqrt(maxf(mass, 1.0))
					var k_lo := 1.0 / sqrt(M_MAX)
					var n := _norm(k, k_lo, 1.0)
					d["formulas"] = [
						"K = 1 / √M",
						"norm = (K - 1/√%s) / (1 - 1/√%s)" % [fmt(M_MAX, 0), fmt(M_MAX, 0)],
						"B = %d + arred(norm · %d)" % [BASE_MIN, span],
					]
					d["steps"] = [
						"K = 1 / √%s = %s" % [fmt(mass, 0), fmt(k, 3)],
						"norm = (%s - %s) / (1 - %s) = %s" % [fmt(k, 3), fmt(k_lo, 3), fmt(k_lo, 3), _norm_txt(k, k_lo, 1.0)],
						"B = %d + arred(%s · %d) = %d" % [BASE_MIN, fmt(n, 3), span, _to_base(n)],
					]
					d["base"] = _to_base(n)
		"energy":
			d["title"] = "Energia de ação — Recurso de golpes"
			d["description"] = "Energia gasta para usar golpes; cada golpe tem um custo."
			d["origin"] = "Não deriva de propriedade química na implementação atual. É um valor base definido na ficha da espécie (parâmetro de design do jogo)."
			d["source"] = "Base da ficha: %d (sem valor químico tabelado)" % sheet.energia_de_acao
			return d
	if problem != "":
		d["problem"] = problem
	return d

