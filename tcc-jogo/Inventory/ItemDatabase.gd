class_name ItemDatabase
extends Resource

@export var items: Array[ItemData] = []

func get_item(index: int) -> ItemData:
	for item in items:
		if item.index == index:
			return item
	return null
