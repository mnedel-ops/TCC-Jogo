extends Node

@onready var alchemon: Node3D = $".."

## Marker to follow while exploring (set by FollowerManager). Null = stay put.
var follow_target: Node3D = null
## Set = alchemon goes to this marker and stays (battle). Overrides follow_target.
var battle_anchor: Node3D = null

@export var follow_speed: float = 12.0        # higher = snappier. 0 = snap instantly
@export var battle_move_speed: float = 10.0   # higher = snappier
@export var turn_speed: float = 10.0          # higher = turns faster. 0 = snap
@export var teleport_distance: float = 12.0   # farther than this = snap (scene change etc.)


func set_follow_target(marker: Node3D) -> void:
	follow_target = marker


func go_to_anchor(anchor: Node3D) -> void:
	battle_anchor = anchor


func resume_follow() -> void:
	battle_anchor = null


func _process(delta: float) -> void:
	var target := battle_anchor if battle_anchor != null else follow_target
	if target == null:
		return
	var speed := battle_move_speed if battle_anchor != null else follow_speed
	_move_toward(target.global_position, speed, delta)
	_face(target.global_rotation.y, delta) # same facing as marker (= player)


func _move_toward(goal: Vector3, speed: float, delta: float) -> void:
	var pos := alchemon.global_position
	if speed <= 0.0 or pos.distance_to(goal) > teleport_distance:
		alchemon.global_position = goal
		alchemon.global_rotation.y = (battle_anchor if battle_anchor != null else follow_target).global_rotation.y
		return
	# framerate-independent smooth move
	alchemon.global_position = pos.lerp(goal, 1.0 - exp(-speed * delta))


func _face(yaw: float, delta: float) -> void:
	if turn_speed <= 0.0:
		alchemon.global_rotation.y = yaw
		return
	# lerp_angle = shortest way around, no 350 degree spin
	alchemon.global_rotation.y = lerp_angle(alchemon.global_rotation.y, yaw, 1.0 - exp(-turn_speed * delta))
