class_name CapturedStorage
extends Resource


@export var instances: Array[AlchemonInstance] = []

var species_ids: Array[int]:
	get:
		var ids: Array[int] = []
		for i in instances:
			ids.append(i.species_id)
		return ids


func find_by_uid(uid: String) -> AlchemonInstance:
	for i in instances:
		if i != null and i.uid == uid:
			return i
	return null


func add_instance(inst: AlchemonInstance) -> void:
	inst.ensure_uid()
	instances.append(inst)
	emit_changed()


func remove_instance(inst: AlchemonInstance) -> void:
	instances.erase(inst)
	emit_changed()
