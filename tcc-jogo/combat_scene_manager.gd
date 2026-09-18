# tcc-jogo/combat_scene_manager.gd
extends CanvasLayer
class_name CombatSceneManager

@onready var NPCGet = $"../LevelHolder/scene1/SignalReceiver"
@onready var combat_holder: Control = $"../CombatHolder"

var combatScene : PackedScene = load("res://COMBAT/combat_refactored.tscn")

func _ready() -> void:
	if NPCGet:
		NPCGet.combat_start.connect(_on_combat_start)

func _on_combat_start(index: int, id2: int) -> void:
	npc_alchemons(index, id2)
	var combatScenes = combatScene.instantiate()
	combatScenes.player_species_ids = _get_player_species_ids()
	combat_holder.add_child(combatScenes)

func npc_alchemons(index: int, id2: int) -> void:
	print(index, id2)

## Pulls party species_ids from player's InventoryComponent -> PlayerPartyData resource.
## Fallback [0,1] if missing - never crash combat setup.
func _get_player_species_ids() -> Array[int]:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("CombatSceneManager: player node not in group 'player'.")
		return [0, 1]

	var inventory: InventoryComponent = player.find_child("InventoryComponent", true, false)
	if inventory == null or inventory.party_data == null:
		push_warning("CombatSceneManager: InventoryComponent or party_data missing.")
		return [0, 1]

	return inventory.party_data.species_ids
