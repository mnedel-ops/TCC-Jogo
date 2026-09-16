class_name InventoryData
extends Resource

@export var items: Array[int] = []   # indices na ordem de coleta

func add_item(index: int) -> void:
	items.append(index)
	emit_changed()

func remove_item(index: int) -> bool:
	var pos := items.find(index)   # remove 1a ocorrencia (mais antiga)
	if pos == -1:
		return false
	items.remove_at(pos)
	emit_changed()
	return true

func is_empty() -> bool:
	return items.is_empty()

func get_quantity(index: int) -> int:
	var quantity := 0
	for item_index in items:
		if item_index == index:
			quantity += 1
	return quantity

# Agrupa indices repetidos -> lista pra UI. Ordem = primeira vez que apareceu.
func get_stacked_view(database: ItemDatabase) -> Array[Dictionary]:
	var counts: Dictionary = {}
	var order: Array[int] = []

	for idx in items:
		if not counts.has(idx):
			counts[idx] = 0
			order.append(idx)
		counts[idx] += 1

	var result: Array[Dictionary] = []
	for idx in order:
		var data := database.get_item(idx)
		var nome := data.nome if data else "Desconhecido"
		result.append({"index": idx, "nome": nome, "quantidade": counts[idx]})
	return result
