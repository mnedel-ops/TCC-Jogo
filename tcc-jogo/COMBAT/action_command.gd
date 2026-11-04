class_name ActionCommand
extends Resource


@export var actor_id: int = -1
@export var kind: String = ""
@export var target_id: int = -1
@export var attack_index: int = -1
@export var item_index: int = -1

func _init(
	p_actor_id: int = -1,
	p_kind: String = "",
	p_target_id: int = -1,
	p_attack_index: int = -1,
	p_item_index: int = -1
) -> void:
	actor_id = p_actor_id
	kind = p_kind
	target_id = p_target_id
	attack_index = p_attack_index
	item_index = p_item_index
