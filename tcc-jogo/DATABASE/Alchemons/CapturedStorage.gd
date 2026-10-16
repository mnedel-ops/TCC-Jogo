class_name CapturedStorage
extends Resource

## Stand-in for the PC. species_id of every captured creature, in order.

@export var species_ids: Array[int] = []


func add(species_id: int) -> void:
	species_ids.append(species_id)
	emit_changed()
