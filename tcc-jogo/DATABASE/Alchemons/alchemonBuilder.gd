extends Node3D
class_name AlchemonBuilder

var id : int = -1
var database := load("res://DATABASE/Alchemons/AlchemonDataBaseComplete.tres")
var alchemonLevel :int= 5

var instance: AlchemonInstance
var stats: Dictionary

func _ready() -> void:
	alchemon_instance()
	
func _set_id(sent_id: int):
	id = sent_id
	
func alchemon_instance():
	var sheet :AlchemonSheet= database.get_by_id(id)
	if sheet == null:
		push_error("Sem sheet id %d" % id)
		return
	
	# Dados químicos = fonte oficial dos atributos base. Gera uma vez, na criação.
	if sheet.uses_chemical_stats():
		sheet.regenerate_base_stats()
	
	instance = AlchemonInstance.new()
	instance.init_from_template(sheet)
	instance.level=alchemonLevel
	
	print_debug("Nome do alchemon: ", instance.creature_name)
	
	stats = apply_level(sheet,instance)
	
func apply_level(sheet:AlchemonSheet, inst:AlchemonInstance) -> Dictionary:
	var st := inst.compute_stats(sheet)
	return {
		"attack": st.attack,
		"defense": st.defense,
		"speed": st.mechanical_speed,
		"energy": st.action_energy,
		"max_hp": st.max_hp,
	}
