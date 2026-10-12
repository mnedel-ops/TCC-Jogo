# tcc-jogo/combat_scene_manager.gd
extends CanvasLayer
class_name CombatSceneManager

@onready var combat_holder: Control = $"../CombatHolder"
var combatScene : PackedScene = load("res://COMBAT/combat_refactored.tscn")
@export var party : PlayerPartyData

@onready var anchors_root: Node3D = $"../BattleAnchors"
@onready var player_node: Node3D = $"../player"
@onready var player_mesh: Node3D = $"../player/Mesh" # Mesh rotates, Player body does not
@onready var camera_rig: Node = $"../CameraRig"

## Seconds characters take to walk to the corners / back home.
@export var move_time: float = 0.6

var _enemy: Node3D = null
var _player_home: Vector3
var _enemy_home: Vector3
var _tween: Tween
var _moved: bool = false # true only if characters really went to corners

@export var inventory: InventoryData = preload("res://DATABASE/Inventory/inventory.tres")
@export var item_database: ItemDatabase = preload("res://DATABASE/Inventory/ItemDatabase.tres")
# ... in _on_combat_start, after enemy_species_ids line:

@onready var follower_manager: Node = $"../FollowerManager"
@onready var follower_holder: Node3D = $"../FollowerHolder"

var actor_scene: PackedScene = load("res://DATABASE/Alchemons/AlchemonActor.tscn")
var _enemy_actors: Array[Node3D] = []

func _ready() -> void:
	CombatSignal.combat_start.connect(_on_combat_start)
	CombatSignal.combat_ended.connect(_on_combat_ended)


func _on_combat_start(index: int, id2: int) -> void:
	CombatSignal.in_combat = true
	_enemy = CombatSignal.enemy_node
	CombatSignal.enemy_node = null # consume, no stale value next fight

	# Anchors = offsets from the battle center (midpoint player <-> enemy),
	# so the fight always happens on screen, wherever it started.
	anchors_root.global_position = _get_battle_center()

	var combatScenes = combatScene.instantiate()
	combatScenes.player_species_ids = party.party
	combatScenes.enemy_species_ids = _get_enemy_species_ids(index, id2)
	combatScenes.inventory = inventory
	combatScenes.item_database = item_database
	
	combatScenes.anchors = { #Combat positions
		BattlefieldSlot.PLAYER_SLOT_1: anchors_root.get_node("P1"),
		BattlefieldSlot.PLAYER_SLOT_2: anchors_root.get_node("P2"),
		BattlefieldSlot.ENEMY_SLOT_1:  anchors_root.get_node("E3"),
		BattlefieldSlot.ENEMY_SLOT_2:  anchors_root.get_node("E4"),
	}
	combat_holder.add_child(combatScenes)

	_send_characters_to_corners()
	
	var enemy_ids := _get_enemy_species_ids(index, id2)
	combatScenes.enemy_species_ids = enemy_ids
	# ... (inventory lines stay) ...
	combatScenes.actor_nodes = _collect_actor_nodes(enemy_ids)
	combat_holder.add_child(combatScenes)


func _on_combat_ended() -> void:
	_free_enemy_actors()
	_send_characters_home()

func _get_battle_center() -> Vector3:
	var p := player_node.global_position
	if _enemy == null:
		return p # no enemy sent: center on player
	var center := p.lerp(_enemy.global_position, 0.5)
	center.y = p.y # keep ground height of player
	return center


## Char0 (player, top left) and Char1 (opponent, bottom right), children of BattleAnchors.
func _send_characters_to_corners() -> void:
	var char0 := anchors_root.get_node_or_null("Char0") as Node3D
	var char1 := anchors_root.get_node_or_null("Char1") as Node3D
	if char0 == null or char1 == null:
		push_warning("CombatSceneManager: Char0/Char1 not found under BattleAnchors.")
		return

	# Camera must NOT chase player into the corner, or the corner moves too.
	camera_rig.set_physics_process(false)
	_moved = true

	_player_home = player_node.global_position
	if _enemy != null:
		_enemy_home = _enemy.global_position

	_kill_tween()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(player_node, "global_position", char0.global_position, move_time)
	_tween_yaw(player_mesh, _yaw_toward(char0.global_position, char1.global_position))
	if _enemy != null:
		_tween.tween_property(_enemy, "global_position", char1.global_position, move_time)
		_tween_yaw(_enemy, _yaw_toward(char1.global_position, char0.global_position))


func _send_characters_home() -> void:
	if not _moved:
		_finish_battle() # markers missing: nobody moved, nothing to undo
		return
	_kill_tween()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(player_node, "global_position", _player_home, move_time)
	if _enemy != null:
		_tween.tween_property(_enemy, "global_position", _enemy_home, move_time)
	# Re-enable camera + NPC fights only after everyone is home.
	_tween.chain().tween_callback(_finish_battle)


func _finish_battle() -> void:
	camera_rig.set_physics_process(true)
	CombatSignal.in_combat = false
	_moved = false
	_enemy = null


## Same convention as MovementComponent: forward = -Z.
func _yaw_toward(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(-d.x, -d.z)


func _tween_yaw(node: Node3D, target_yaw: float) -> void:
	var from := node.rotation.y
	# shortest way around, no 350 degree spin
	_tween.tween_method(func(t: float): node.rotation.y = lerp_angle(from, target_yaw, t), 0.0, 1.0, move_time)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


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

func _collect_actor_nodes(enemy_species: Array[int]) -> Dictionary:
	var actors := {}
	for i in 2:
		var f: Node3D = follower_manager.get_follower(i)
		if f != null:
			actors[BattlefieldSlot.PLAYER_SLOT_1 + i] = f

	var enemy_anchor_names: Array[String] = ["E3", "E4"]
	var look_at_pos: Vector3 = anchors_root.get_node("P1").global_position
	for i in mini(enemy_species.size(), enemy_anchor_names.size()):
		var anchor := anchors_root.get_node(enemy_anchor_names[i]) as Node3D
		var actor := actor_scene.instantiate() as Node3D
		actor._set_id(enemy_species[i])
		follower_holder.add_child(actor)
		actor.global_position = anchor.global_position
		actor.global_rotation.y = _yaw_toward(anchor.global_position, look_at_pos)
		_enemy_actors.append(actor)
		actors[BattlefieldSlot.ENEMY_SLOT_1 + i] = actor
	return actors


func _free_enemy_actors() -> void:
	for a in _enemy_actors:
		if is_instance_valid(a):
			a.queue_free()
	_enemy_actors.clear()
