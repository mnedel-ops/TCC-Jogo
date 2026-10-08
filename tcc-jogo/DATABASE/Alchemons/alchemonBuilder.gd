extends Node3D
class_name AlchemonBuilder

var id : int = -1
var database := load("res://DATABASE/Alchemons/AlchemonDataBaseComplete.tres")
var alchemonLevel :int= 5

var instance: AlchemonInstance
var stats: Dictionary

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	alchemon_instance()
	
func _set_id(sent_id: int):
	id = sent_id
	
func alchemon_instance():
	var sheet :AlchemonSheet= database.get_by_id(id)
	if sheet == null:
		push_error("Sem sheet id %d" % id)
		return
	
	instance = AlchemonInstance.new()
	instance.init_from_template(sheet)
	instance.level=alchemonLevel
	
	print_debug("Nome do alchemon: ", instance.creature_name)
	
	stats = apply_level(sheet,instance)
	
func apply_level(sheet:AlchemonSheet, inst:AlchemonInstance) -> Dictionary: #Criar uma instancia da ficha. Que eu estou usando a ficha base, e altero ela
	var iv := inst.individual_value
	var lv := inst.level
	return {
		"attack": AlchemonFormulas.compute_stat(sheet.base_attack, iv, lv),
		"defense": AlchemonFormulas.compute_stat(sheet.base_defense, iv, lv),
		"speed": AlchemonFormulas.compute_stat(sheet.base_mechanical_speed, iv, lv),
		"energy": AlchemonFormulas.compute_stat(sheet.base_action_energy, iv, lv),
		"max_hp": AlchemonFormulas.compute_stat(sheet.max_hp, iv, lv),
	}
