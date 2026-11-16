class_name AlchemonFormulas
extends RefCounted


static func compute_initiative(mechanical_speed: int, individual_value: int, level: int) -> int:
	var raw := float((mechanical_speed + individual_value) * 2 * level) / 100.0
	return int(floor(raw)) + 5


static func compute_damage(level: int, power: int, attack: int, defense: int, effectiveness: float = 1.0) -> int:
	var defense_safe := maxi(defense, 1)
	var scaled := (2.0 * level / 5.0 + 2.0) * power * (float(attack) / defense_safe)
	var damage := (scaled / 50.0 + 2.0) * effectiveness
	return maxi(int(floor(damage)), 0)


static func compute_temperature_delta(level: int, power: int, attack: int) -> float:
	var raw :float = (float(level) / 10.0 + 1.0) * (float(power) / 10.0) * (float(attack) / 100.0)
	return raw

## Composto: dT = Q / (m_composto * cp_composto).
static func compound_delta_temperature(q: float, total_mass: float, specific_heat: float) -> float:
	return ThermalRules.delta_temperature(q, total_mass, specific_heat)


## Iônico (metal + ametal): T_ebulição_ânion + ΔE*250 + |Z_cátion|*100.
static func scission_temperature_ionic(anion_boiling: float, delta_electronegativity: float, cation_charge: int) -> float:
	return anion_boiling + absf(delta_electronegativity) * 250.0 + absi(cation_charge) * 100.0


## Covalente (ametal + ametal): max(T_ebulição) + pares_compartilhados*150.
static func scission_temperature_covalent(boiling_a: float, boiling_b: float, shared_pairs: int) -> float:
	return maxf(boiling_a, boiling_b) + shared_pairs * 150.0


const CAPTURE_VALUE_MAX := 255

## Valor de captura: a = floor((3*HPmax - 2*HPatual) / (3*HPmax) * M), limitado a 1..255.
## M = 255 (ferramenta compatível) ou 127 (incompatível). Sem redução de 8 bits.
static func compute_capture_value(hp_max: int, hp_current: int, tool_multiplier: float) -> int:
	var hp_max_safe := maxi(hp_max, 1)
	var max_term := 3 * hp_max_safe
	var cur_term := 2 * clampi(hp_current, 0, hp_max_safe)
	var a := int(floor(float(max_term - cur_term) * tool_multiplier / float(max_term)))
	return clampi(a, 1, CAPTURE_VALUE_MAX)


## Chance percentual de captura: a / 255 * 100.
static func capture_chance(a: int) -> float:
	return float(a) / float(CAPTURE_VALUE_MAX) * 100.0


static func compute_stat(base: int, individual_value: int, level: int) -> int:
	var raw := 0.01 * (2.0 * base + individual_value) * level
	return int(floor(raw)) + 5
