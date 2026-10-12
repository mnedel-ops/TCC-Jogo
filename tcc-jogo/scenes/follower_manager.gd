extends Node

@onready var player: Player = $"../player"
@onready var follower_holder: Node3D = $"../FollowerHolder"
@onready var anchors_root: Node3D = $"../BattleAnchors"
@onready var player_mesh: Node3D = $"../player/Mesh" # Mesh rotates, Player body does not

@export var rotate_with_player: bool = true
@export var marker_turn_speed: float = 8.0 # how fast markers orbit when player turns. 0 = snap
var _facing_yaw: float = 0.0

var alchemonfollower: PackedScene = load("res://DATABASE/Alchemons/AlchemonActor.tscn")
var alchemonfollowerinstance : Node3D

## Creature i uses marker i. Move these markers in the editor = move creatures.
## Marker position = OFFSET from player (markers ride along with the player).
const FOLLOW_MARKER_NAMES: Array[String] = ["APosition", "BPosition"]
## Party order = battle slot order (P1, P2). Same order CombatStateFactory uses.
const PLAYER_ANCHOR_NAMES: Array[String] = ["P1", "P2"]

var _followers: Array[Node3D] = []
var _markers: Array[Marker3D] = []
var _offsets: Array[Vector3] = []

@export var equipe_player: PlayerPartyData


func _ready() -> void:
	_facing_yaw = player_mesh.global_rotation.y # no swing at spawn
	_collect_markers()
	_update_markers() # markers in place BEFORE spawn
	for m in equipe_player.species_ids.size():
		set_follower(m)
	CombatSignal.combat_start.connect(_on_combat_start)
	CombatSignal.combat_ended.connect(_on_combat_ended)
	


func _process(_delta: float) -> void:
	_update_facing(_delta)
	_update_markers()

func _update_facing(delta: float) -> void:
	var target_yaw := player_mesh.global_rotation.y
	if marker_turn_speed <= 0.0:
		_facing_yaw = target_yaw
	else:
		_facing_yaw = lerp_angle(_facing_yaw, target_yaw, 1.0 - exp(-marker_turn_speed * delta))

## Read offset each marker was given in the editor.
func _collect_markers() -> void:
	for n in FOLLOW_MARKER_NAMES:
		var marker := get_node_or_null(n) as Marker3D
		if marker == null:
			push_warning("FollowerManager: marker '%s' not found." % n)
			continue
		_markers.append(marker)
		_offsets.append(marker.position)


## Markers follow player. Offset stays in world axes (no rotation).
func _update_markers() -> void:
	var basis_yaw := Basis(Vector3.UP, _facing_yaw) if rotate_with_player else Basis.IDENTITY
	for i in _markers.size():
		_markers[i].global_position = player.global_position + basis_yaw * _offsets[i]
		_markers[i].global_rotation.y = _facing_yaw if rotate_with_player else 0.0

func set_follower(index: int):
	alchemonfollowerinstance = alchemonfollower.instantiate() as Node3D
	alchemonfollowerinstance._set_id(equipe_player.species_ids[index])
	follower_holder.add_child(alchemonfollowerinstance)

	var marker: Marker3D = _markers[index] if index < _markers.size() else null
	if marker == null:
		push_warning("FollowerManager: no marker for follower %d, spawn at player." % index)
		alchemonfollowerinstance.global_position = player.global_position
	else:
		alchemonfollowerinstance.global_position = marker.global_position
		alchemonfollowerinstance.global_position = marker.global_position
		alchemonfollowerinstance.global_rotation.y = marker.global_rotation.y
		var follow := alchemonfollowerinstance.get_node_or_null("FollowComponent")
		if follow != null:
			follow.set_follow_target(marker)
	_followers.append(alchemonfollowerinstance)


func _on_combat_start(_a: int, _b: int) -> void:
	for i in _followers.size():
		if i >= PLAYER_ANCHOR_NAMES.size():
			push_warning("FollowerManager: more followers than player anchors.")
			break
		var anchor := anchors_root.get_node_or_null(PLAYER_ANCHOR_NAMES[i]) as Node3D
		var follow := _followers[i].get_node_or_null("FollowComponent")
		if anchor == null or follow == null:
			push_warning("FollowerManager: missing anchor or FollowComponent for follower %d" % i)
			continue
		follow.go_to_anchor(anchor)


func _on_combat_ended() -> void:
	for f in _followers:
		var follow := f.get_node_or_null("FollowComponent")
		if follow != null:
			follow.resume_follow()
