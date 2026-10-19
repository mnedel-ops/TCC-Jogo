class_name PCStation
extends Node3D
## PC interactable. Player enter Area3D, press "ui_interact" -> open PC UI.
## Player is frozen while PC is open.

signal opened(player: Node3D)
signal closed

@export var interact_action: StringName = &"ui_interact"
@export var player_group: StringName = &"player"
@export var ui_scene: PackedScene = preload("res://scenes/pc/pc_ui.tscn")

@onready var interact_area: Area3D = $InteractArea
@onready var prompt: Label3D = $Prompt

var _player: Node3D = null
var _ui: Node = null
var _is_open := false
var _saved_process_mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT
var _saved_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	if not InputMap.has_action(interact_action):
		push_warning("PCStation: InputMap missing action '%s'" % interact_action)
	prompt.visible = false
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or _is_open:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed(interact_action):
		get_viewport().set_input_as_handled()
		open_pc()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(player_group):
		_player = body
		prompt.visible = not _is_open


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		if _is_open:
			close_pc()
		_player = null
		prompt.visible = false


func open_pc() -> void:
	if _is_open or _player == null:
		return
	_is_open = true
	prompt.visible = false
	_lock_player(true)
	_saved_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if ui_scene:
		_ui = ui_scene.instantiate()
		get_tree().current_scene.add_child(_ui)
		if _ui.has_method("setup"):
			_ui.setup(_player)
		if _ui.has_signal("exit_requested"):
			_ui.exit_requested.connect(close_pc)
	opened.emit(_player)


func close_pc() -> void:
	if not _is_open:
		return
	_is_open = false
	if _ui:
		_ui.queue_free()
		_ui = null
	Input.mouse_mode = _saved_mouse_mode
	if _player:
		_lock_player(false)
		prompt.visible = true
	closed.emit()


## Freeze player. Uses player's set_input_locked(bool) if it has one,
## else disables the whole player node (no move, no camera, no input).
func _lock_player(locked: bool) -> void:
	if _player == null:
		return
	if _player.has_method("set_input_locked"):
		_player.set_input_locked(locked)
		return
	if locked:
		_saved_process_mode = _player.process_mode
		if "velocity" in _player:
			_player.velocity = Vector3.ZERO
		_player.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		_player.process_mode = _saved_process_mode
