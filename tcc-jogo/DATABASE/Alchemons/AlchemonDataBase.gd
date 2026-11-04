class_name AlchemonDatabase
extends Resource


@export var alchemons: Array[AlchemonSheet] = []

func get_by_id(id: int) -> AlchemonSheet:
	for a in alchemons:
		if a.id == id:
			return a
	push_warning("AlchemonSheet com id %d nao encontrado no database." % id)
	return null
