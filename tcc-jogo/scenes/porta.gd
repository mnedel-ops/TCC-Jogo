class_name SceneDoor
extends Area3D

@export_file("*.tscn") var target_level_path: String
@export var target_spawn_point: String

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	var scene_manager := get_tree().get_first_node_in_group("scene_manager") as SceneManager
	if scene_manager == null:
		push_error("SceneManager nao encontrado")
		return
	var target_level: PackedScene = load(target_level_path)
	scene_manager.change_level(target_level, target_spawn_point)
