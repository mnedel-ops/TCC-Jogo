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

const CAPTURE_VALUE_MAX := 255

static func compute_capture_value(hp_max: int, hp_current: int, tool_multiplier: float) -> int:
	var hp_max_safe := maxi(hp_max, 1)
	var max_term := 3 * hp_max_safe
	var cur_term := 2 * clampi(hp_current, 0, hp_max_safe)
	if max_term > CAPTURE_VALUE_MAX:
		max_term = (max_term >> 1) >> 1
		cur_term = (cur_term >> 1) >> 1
	max_term = maxi(max_term, 1)
	var a := int(floor(float(max_term - cur_term) * tool_multiplier / float(max_term)))
	return clampi(a, 1, CAPTURE_VALUE_MAX)


static func compute_stat(base: int, individual_value: int, level: int) -> int:
	var raw := 0.01 * (2.0 * base + individual_value) * level
	return int(floor(raw)) + 5
