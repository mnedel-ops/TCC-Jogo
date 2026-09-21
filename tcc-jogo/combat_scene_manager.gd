# tcc-jogo/combat_scene_manager.gd
extends CanvasLayer
class_name CombatSceneManager

@onready var combat_holder: Control = $"../CombatHolder"
var player : PackedScene = load("res://EXPLORATION/Player/player.tscn")
var combatScene : PackedScene = load("res://COMBAT/combat_refactored.tscn")
@export var party : PlayerPartyData

func _ready() -> void:
	CombatSignal.combat_start.connect(_on_combat_start)

func _on_combat_start(index: int, id2: int) -> void:
	var combatScenes = combatScene.instantiate()
	combatScenes.player_species_ids = party.party
	combatScenes.enemy_species_ids = _get_enemy_species_ids(index, id2)
	combat_holder.add_child(combatScenes)

## -1 = no second mon. Filter, don't pass as species_id.
func _get_enemy_species_ids(index: int, id2: int) -> Array[int]:
	var ids: Array[int] = []
	if index >= 0:
		ids.append(index)
	if id2 >= 0:
		ids.append(id2)
	if ids.is_empty():
		push_warning("CombatSceneManager: no valid enemy ids, fallback [3].")
		return [3]
	return ids

	
