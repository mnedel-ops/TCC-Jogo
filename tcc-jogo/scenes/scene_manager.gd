class_name SceneManager
extends Node

@export var level_holder: Node3D
@export var player: CharacterBody3D
@export var camera_rig: Node3D

@export var first_level: PackedScene        # arrasta Scene1.tscn aqui no Inspector
@export var first_spawn_point: String

var _current_level: Node3D
signal ChangeScene

func _ready() -> void:
	add_to_group("scene_manager")
	if _resume_saved_position(GameSession.take_resume_position()):
		return
	if first_level:
		change_level(first_level, first_spawn_point)

func change_level(new_level_scene: PackedScene, spawn_point_name: String) -> void:
	if new_level_scene == null:
		push_error("Cena destino não configurada para porta.")
		return

	var new_level := _swap_level(new_level_scene)
	var spawn := new_level.get_node_or_null(spawn_point_name) as Marker3D

	if spawn == null:
		push_warning("Spawn '%s' nao existe em %s" % [spawn_point_name, new_level.name])
		return

	_place_player(spawn.global_transform)


## Where to put the player on Load. false = bad data / level gone: caller falls back to the first level.
func _resume_saved_position(pos: Dictionary) -> bool:
	if pos.is_empty():
		return false
	var path := String(pos.get("level", ""))
	var scene := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		push_warning("Saved level '%s' not found, starting at the first level." % path)
		return false

	_swap_level(scene)
	_place_player(Transform3D(Basis(), Vector3(pos["x"], pos["y"], pos["z"])))
	var mesh := player.get_node_or_null("Mesh") as Node3D   # the Mesh turns, the body does not
	if mesh != null:
		mesh.global_rotation.y = float(pos["yaw"])
	return true


## What GameSession writes in the save: current level + where the player stands/faces.
func get_save_position() -> Dictionary:
	if _current_level == null or _current_level.scene_file_path == "":
		return {}
	var p := player.global_position
	var mesh := player.get_node_or_null("Mesh") as Node3D
	return {
		"level": _current_level.scene_file_path,
		"x": p.x, "y": p.y, "z": p.z,
		"yaw": mesh.global_rotation.y if mesh != null else 0.0,
	}


func _swap_level(new_level_scene: PackedScene) -> Node3D:
	if _current_level:
		_current_level.queue_free()
	var new_level := new_level_scene.instantiate() as Node3D
	level_holder.add_child(new_level)
	_current_level = new_level
	return new_level


func _place_player(xform: Transform3D) -> void:
	player.velocity = Vector3.ZERO             # zera momentum, evita herdar impulso da scene anterior
	player.global_transform = xform
	camera_rig.set_player(player)
