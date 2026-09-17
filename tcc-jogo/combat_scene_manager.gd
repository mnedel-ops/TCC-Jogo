extends CanvasLayer
class_name CombatSceneManager

@onready var NPCGet = $"../LevelHolder/scene1/SignalReceiver"
@onready var combat_holder: Control = $"../CombatHolder"

var combatScene : PackedScene = load("res://COMBAT/combat_refactored.tscn")

func _ready() -> void:
	if NPCGet:
		print("NPC existea")
	
	if NPCGet:
		NPCGet.combat_start.connect(_on_combat_start)

func _on_combat_start(index: int,id2:int)->void:
	print("Entramos no combate...", index)
	npc_alchemons(index,id2)
	var combatScenes = combatScene.instantiate()
	combat_holder.add_child(combatScenes)
	
func npc_alchemons(index:int,id2:int):
	var npc_alchemon1 :int= index
	var alchemon2:int=id2
	print(npc_alchemon1,alchemon2)
