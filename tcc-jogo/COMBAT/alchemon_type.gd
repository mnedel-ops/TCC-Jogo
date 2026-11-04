class_name AlchemonType
extends RefCounted


enum Type {
	METAL,
	AMETAL,
	METALOIDE,
}

const _BEATS := {
	Type.METAL: Type.METALOIDE,
	Type.METALOIDE: Type.AMETAL,
	Type.AMETAL: Type.METAL,
}

const SUPER_EFFECTIVE := 1.5
const RESISTED := 0.66
const NEUTRAL := 1.0


static func effectiveness(attack_type: int, defender_type: int) -> float:
	if attack_type == defender_type:
		return NEUTRAL
	if _BEATS[attack_type] == defender_type:
		return SUPER_EFFECTIVE
	return RESISTED


static func type_name(t: int) -> String:
	match t:
		Type.METAL:
			return "Metal"
		Type.AMETAL:
			return "Ametal"
		Type.METALOIDE:
			return "Metaloide"
		_:
			return "Desconhecido"
