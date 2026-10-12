# tcc-jogo/combat_scene_manager.gd
extends CanvasLayer
class_name CombatSceneManager

@onready var combat_holder: Control = $"../CombatHolder"
var combatScene : PackedScene = load("res://COMBAT/combat_refactored.tscn")
@export var party : PlayerPartyData

@onready var anchors_root: Node3D = $"../BattleAnchors"
@onready var player_node: Node3D = $"../player"

func _ready() -> void:
	CombatSignal.combat_start.connect(_on_combat_start)

func _on_combat_start(index: int, id2: int) -> void:
	# Anchors = offsets from the battle center (midpoint player <-> enemy),
	# so the fight always happens on screen, wherever it started.
	anchors_root.global_position = _get_battle_center()
	
	var combatScenes = combatScene.instantiate()
	combatScenes.player_species_ids = party.party
	combatScenes.enemy_species_ids = _get_enemy_species_ids(index, id2)

	combatScenes.anchors = { #Combat positions
		BattlefieldSlot.PLAYER_SLOT_1: anchors_root.get_node("P1"),
		BattlefieldSlot.PLAYER_SLOT_2: anchors_root.get_node("P2"),
		BattlefieldSlot.ENEMY_SLOT_1:  anchors_root.get_node("E3"),
		BattlefieldSlot.ENEMY_SLOT_2:  anchors_root.get_node("E4"),
	}
	combat_holder.add_child(combatScenes)

func _get_battle_center() -> Vector3:
	var p := player_node.global_position
	var e :Vector3= CombatSignal.enemy_position
	CombatSignal.enemy_position = Vector3.INF # consume, no stale value next fight
	if not e.is_finite():
		return p # no enemy pos sent: center on player
	var center := p.lerp(e, 0.5)
	center.y = p.y # keep ground height of player
	return center

## -1 = no second mon. Filter, don't pass as species_id.
func _get_enemy_species_ids(index: int, id2: int) -> Array[int]:
	var ids: Array[int] = []
	if index >= 0:
		print_debug(index)
		ids.append(index)
	if id2 >= 0:
		print_debug(id2)
		ids.append(id2)
	if ids.is_empty():
		push_warning("CombatSceneManager: no valid enemy ids, fallback [3].")
		return [3]
	return ids
