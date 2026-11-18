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
