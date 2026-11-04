class_name PlayerBondData
extends Resource


@export var kind: String = BondRules.NONE
@export var member_indices: Array[int] = []


func is_active() -> bool:
	return kind != BondRules.NONE and member_indices.size() >= 2


func set_bond(p_kind: String, indices: Array[int]) -> void:
	kind = p_kind
	member_indices = indices.duplicate()
	emit_changed()


func clear() -> void:
	kind = BondRules.NONE
	member_indices.clear()
	emit_changed()
