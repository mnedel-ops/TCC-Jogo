extends Node3D

var id : int = 2
var database := load("res://DATABASE/Alchemons/AlchemonDataBaseComplete.tres")
var alchemonLevel :int= 5

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var sheet :AlchemonSheet= database.get_by_id(id)
	print_debug("Nome do alchemon: ", sheet.creature_name)
	print_debug("stats: ", sheet.max_hp)
	
	sheet.max_hp += AlchemonFormulas.compute_stat(sheet.hp, 5, alchemonLevel)
	print_debug("stats: ", sheet.max_hp)
	
