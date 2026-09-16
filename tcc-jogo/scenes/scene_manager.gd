class_name SceneManager
extends Node

@export var level_holder: Node3D
@export var player: CharacterBody3D
@export var camera_rig: Node3D

@export var first_level: PackedScene        # arrasta Scene1.tscn aqui no Inspector
@export var first_spawn_point: String

var _current_level: Node3D

func _ready() -> void:
	add_to_group("scene_manager")
	if first_level:
		change_level(first_level, first_spawn_point)
		print("Fase inicial")

func change_level(new_level_scene: PackedScene, spawn_point_name: String) -> void:
	if new_level_scene == null:
		push_error("Cena destino não configurada para porta.")
		return

	if _current_level:
		_current_level.queue_free()

	var new_level: Node3D = new_level_scene.instantiate()
	level_holder.add_child(new_level)
	_current_level = new_level

	var spawn := new_level.get_node_or_null(spawn_point_name) as Marker3D
	if spawn == null:
		push_warning("Spawn '%s' nao existe em %s" % [spawn_point_name, new_level.name])
		return

	player.velocity = Vector3.ZERO             # zera momentum, evita herdar impulso da scene anterior
	player.global_transform = spawn.global_transform
	camera_rig.set_player(player)               # reusa o setter do CameraRig (recentraliza sem lerp)
