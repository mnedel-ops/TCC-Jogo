class_name AlchemonStatGenerator
extends RefCounted
## Gera os atributos base (30..110) a partir de propriedades químicas tabeladas.
##   HP         <- entalpia de atomização (kJ/mol)
##   Ataque     <- reatividade: metal = R_MAX * I_MIN / I1 ; ametal/metaloide = afinidade eletrônica
##   Defesa     <- primeira energia de ionização I1 (kJ/mol)
##   Velocidade <- eletronegatividade de Pauling / raiz(massa atômica)
## Cada propriedade passa por normalização min-max e é mapeada para [BASE_MIN, BASE_MAX].

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


static func _norm(value: float, lo: float, hi: float) -> float:
	return clampf((value - lo) / (hi - lo), 0.0, 1.0)


static func _to_base(normalized: float) -> int:
	return BASE_MIN + roundi(normalized * float(BASE_MAX - BASE_MIN))


## Retorna {base_hp, base_attack, base_defense, base_mechanical_speed}.
static func generate_base_stats(mass: float, ionization_energy: float, electron_affinity: float, electronegativity: float, atomization_enthalpy: float, is_metal: bool) -> Dictionary:
	var reactivity: float = R_MAX * I_MIN / maxf(ionization_energy, 1.0) if is_metal else electron_affinity
	var kinetic: float = electronegativity / sqrt(maxf(mass, 1.0))
	return {
		"base_hp": _to_base(_norm(atomization_enthalpy, H_MIN, H_MAX)),
		"base_attack": _to_base(_norm(reactivity, R_MIN, R_MAX)),
		"base_defense": _to_base(_norm(ionization_energy, I_MIN, I_MAX)),
		"base_mechanical_speed": _to_base(_norm(kinetic, K_MIN, K_MAX)),
	}


## True se a ficha tem os dados químicos necessários.
static func has_data(sheet: AlchemonSheet) -> bool:
	return sheet.first_ionization_energy > 0.0 and sheet.atomization_enthalpy > 0.0 and sheet.electronegativity > 0.0 and sheet.atomic_mass > 0


static func from_sheet(sheet: AlchemonSheet) -> Dictionary:
	return generate_base_stats(
		float(sheet.atomic_mass),
		sheet.first_ionization_energy,
		sheet.electron_affinity,
		sheet.electronegativity,
		sheet.atomization_enthalpy,
		sheet.is_metal())


## Escreve os atributos gerados na ficha. Retorna false se faltarem dados químicos.
static func apply_to(sheet: AlchemonSheet) -> bool:
	if not has_data(sheet):
		return false
	var s := from_sheet(sheet)
	sheet.base_hp = s["base_hp"]
	sheet.base_attack = s["base_attack"]
	sheet.base_defense = s["base_defense"]
	sheet.base_mechanical_speed = s["base_mechanical_speed"]
	return true
