class_name InteractableItem
extends Area3D

@export var item_data: ItemData

func get_item_id() -> int:
	return item_data.index if item_data else -1
