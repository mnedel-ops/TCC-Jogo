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
	if body == _player and not _is_open:
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
		prompt.visible = interact_area.overlaps_body(_player)
	closed.emit()


## Freeze player. Uses player's set_input_locked(bool) if it has one.
## Else turn off processing + input on player and all children.
## NOT process_mode DISABLED: that removes the body from physics space,
## Area3D fires body_exited, PC closes instantly.
var _saved_flags: Dictionary = {}

func _lock_player(locked: bool) -> void:
	if _player == null:
		return
	if _player.has_method("set_input_locked"):
		_player.set_input_locked(locked)
		return
	if locked:
		_saved_flags.clear()
		if "velocity" in _player:
			_player.velocity = Vector3.ZERO
		_freeze_tree(_player)
	else:
		for n in _saved_flags:
			if not is_instance_valid(n):
				continue
			var f: Dictionary = _saved_flags[n]
			n.set_process(f.process)
			n.set_physics_process(f.physics)
			n.set_process_input(f.input)
			n.set_process_unhandled_input(f.unhandled)
			n.set_process_unhandled_key_input(f.key)
		_saved_flags.clear()


func _freeze_tree(n: Node) -> void:
	_saved_flags[n] = {
		"process": n.is_processing(),
		"physics": n.is_physics_processing(),
		"input": n.is_processing_input(),
		"unhandled": n.is_processing_unhandled_input(),
		"key": n.is_processing_unhandled_key_input(),
	}
	n.set_process(false)
	n.set_physics_process(false)
	n.set_process_input(false)
	n.set_process_unhandled_input(false)
	n.set_process_unhandled_key_input(false)
	for c in n.get_children():
		_freeze_tree(c)
