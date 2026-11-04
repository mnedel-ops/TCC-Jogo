extends Node3D
class_name CameraRig

signal zone_transition(direction: Vector3, distance: float)

@export var player: Node3D
@export var dead_zone := Vector2(1.0, 1.0)
@export var follow_speed := 7.0
@export var transition_threshold := 0.05
@export var snap_distance := 5.0

var _fixed_y: float
var _right: Vector3
var _forward: Vector3
var _was_in_zone := true

func set_player(new_player: Node3D) -> void:
	player = new_player
	if player and is_inside_tree():
		_recenter()

func _ready() -> void:
	if not player:
		return

	_fixed_y = global_position.y

	_right = global_transform.basis.x
	_right.y = 0.0
	_right = _right.normalized()

	_forward = -global_transform.basis.z
	_forward.y = 0.0
	_forward = _forward.normalized()

	_recenter()

func _recenter() -> void:
	global_position.x = player.global_position.x
	global_position.z = player.global_position.z

func _physics_process(delta: float) -> void:
	if not player:
		return

	var offset := player.global_position - global_position

	if offset.length() > snap_distance:
		_recenter()
		_was_in_zone = true
		return

	var local_x := offset.dot(_right)
	var local_z := offset.dot(_forward)

	var target := global_position
	var excess_x := 0.0
	var excess_z := 0.0

	if abs(local_x) > dead_zone.x:
		excess_x = local_x - sign(local_x) * dead_zone.x
		target += _right * excess_x

	if abs(local_z) > dead_zone.y:
		excess_z = local_z - sign(local_z) * dead_zone.y
		target += _forward * excess_z

	target.y = _fixed_y

	var in_zone :bool= abs(local_x) <= dead_zone.x and abs(local_z) <= dead_zone.y
	if _was_in_zone and not in_zone:
		var exit_dir :Vector3= (_right * sign(excess_x) + _forward * sign(excess_z)).normalized()
		var exit_dist :float= Vector2(excess_x, excess_z).length()
		if exit_dist > transition_threshold:
			zone_transition.emit(exit_dir, exit_dist)
	_was_in_zone = in_zone

	var weight := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(target, weight)
