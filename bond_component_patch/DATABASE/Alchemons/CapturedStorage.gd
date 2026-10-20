class_name CapturedStorage
extends Resource

## The PC storage. Full AlchemonInstance of every captured creature, so level,
## XP, IV and HP are NOT lost when it goes party <-> storage.

@export var instances: Array[AlchemonInstance] = []

## Compat: old code that only wants the species ids.
var species_ids: Array[int]:
	get:
		var ids: Array[int] = []
		for i in instances:
			ids.append(i.species_id)
		return ids


## Called by combat after a capture. template = sheet of the species
## (fills name + HP). level = level of the captured creature.
func add(species_id: int, template: AlchemonSheet = null, level: int = 1) -> void:
	var inst := AlchemonInstance.new()
	inst.species_id = species_id
	inst.level = maxi(level, 1)
	if template != null:
		inst.init_from_template(template)
	instances.append(inst)
	emit_changed()


func add_instance(inst: AlchemonInstance) -> void:
	instances.append(inst)
	emit_changed()


func remove_instance(inst: AlchemonInstance) -> void:
	instances.erase(inst)
	emit_changed()
