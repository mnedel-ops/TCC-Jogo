class_name InventoryComponent
extends Node

signal item_collected(item_id: int)

@export var mochila: Resource   # teu InventoryData

func collect_from_area(item: Area3D) -> bool:
	if mochila == null or item == null or not item.has_method("get_item_id"):
		return false

	var item_id: int = item.get_item_id()
	if item_id < 0:
		return false

	mochila.add_item(item_id)
	item.queue_free()
	item_collected.emit(item_id)
	return true
