extends Node
class_name CombatSceneManager

@onready var NPCGet = "res://combat_scene_manager.gd"
@onready var combat_holder: Control = $"../CombatHolder"

var combatScene : PackedScene = load("res://COMBAT/combat_refactored.tscn")

func _ready() -> void:
	if NPCGet:
		print("NPC existea")
	
	if NPCGet:
		NPCGet.combat_start.connect(_on_combat_start)

func _on_combat_start(index: int)->void:
	print("Entramos no combate...")
	var combatScenes = combatScene.instantiate()
	combat_holder.add_child(combatScenes)
