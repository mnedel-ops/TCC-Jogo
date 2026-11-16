class_name SceneManager
extends Node

@export var level_holder: Node3D
@export var player: CharacterBody3D
@export var camera_rig: Node3D

@export var first_level: PackedScene
@export var first_spawn_point: String

var _current_level: Node3D
var _toast: Label
var _toast_id := 0

func _ready() -> void:
	add_to_group("scene_manager")
	_build_toast()
	if _resume_saved_position(GameSession.take_resume_position()):
		return
	if first_level:
		change_level(first_level, first_spawn_point)

func _unhandled_input(event: InputEvent) -> void:
	if CombatSignal.in_combat:
		return
	if event.is_action_pressed("quick_save", false, true):
		quick_save()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_load", false, true):
		quick_load()
		get_viewport().set_input_as_handled()


func quick_save() -> void:
	var ok := GameSession.save_game() == OK
	_show_toast("Jogo salvo (F5)." if ok else "Falha ao salvar!", ok)


func quick_load() -> void:
	if not GameSession.has_save():
		_show_toast("Nenhum save para carregar.", false)
		return
	if GameSession.load_game() != OK:
		_show_toast("Falha ao carregar!", false)
		return
	var pos := GameSession.take_resume_position()
	if not _resume_saved_position(pos):
		push_warning("Quick load: save sem posição, mantendo posição atual.")
	_show_toast("Jogo carregado (F9).", true)


func _build_toast() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_toast = Label.new()
	_toast.visible = false
	_toast.add_theme_font_size_override("font_size", 28)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 24)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.add_child(_toast)


func _show_toast(text: String, ok: bool) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", Color(1, 0.85, 0.3) if ok else Color(1, 0.4, 0.4))
	_toast.visible = true
	_toast_id += 1
	var id := _toast_id
	await get_tree().create_timer(1.5, true).timeout
	if id == _toast_id:
		_toast.visible = false


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
	var mesh := player.get_node_or_null("Mesh") as Node3D
	if mesh != null:
		mesh.global_rotation.y = float(pos["yaw"])
	return true


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
	player.velocity = Vector3.ZERO
	player.global_transform = xform
	camera_rig.set_player(player)
