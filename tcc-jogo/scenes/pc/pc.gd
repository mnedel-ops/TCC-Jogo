class_name PCStation
extends Node3D

signal opened(player: Node3D)
signal closed

@export var interact_action: StringName = &"ui_interact"
@export var player_group: StringName = &"player"
@export var ui_scene: PackedScene = preload("pc_ui.tscn")

@export var party: PlayerPartyData = preload("res://DATABASE/Alchemons/PlayerCurrentAlchemon.tres")
@export var storage: CapturedStorage = preload("res://DATABASE/Alchemons/captured_storage.tres")
@export var bond: PlayerBondData = preload("res://DATABASE/Alchemons/player_bond.tres")
@export var database: AlchemonDatabase = preload("res://DATABASE/Alchemons/AlchemonDataBaseComplete.tres")

@onready var interact_area: Area3D = $InteractArea
@onready var prompt: Label3D = $Prompt

var _player: Node3D = null
var _ui: Node = null
var _is_open := false
var _saved_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	_fill_missing_exports()
	if not InputMap.has_action(interact_action):
		push_warning("PCStation: InputMap missing action '%s'" % interact_action)
	prompt.visible = false
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)


# O editor grava "null" nesses exports quando salva uma cena enquanto um preload
# está quebrado (ex.: pasta movida). O null sobrescreve o padrão e o PC "abre"
# sem tela. Aqui qualquer export vazio volta ao padrão.
func _fill_missing_exports() -> void:
	if interact_action == &"":
		interact_action = &"ui_interact"
	if player_group == &"":
		player_group = &"player"
	if ui_scene == null:
		ui_scene = preload("pc_ui.tscn")
	if party == null:
		party = preload("res://DATABASE/Alchemons/PlayerCurrentAlchemon.tres")
	if storage == null:
		storage = preload("res://DATABASE/Alchemons/captured_storage.tres")
	if bond == null:
		bond = preload("res://DATABASE/Alchemons/player_bond.tres")
	if database == null:
		database = preload("res://DATABASE/Alchemons/AlchemonDataBaseComplete.tres")


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
	if ui_scene == null:
		push_error("PCStation: ui_scene vazio, PC não abre.")
		return
	_is_open = true
	prompt.visible = false
	_lock_player(true)
	_saved_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if ui_scene:
		_ui = ui_scene.instantiate()
		get_tree().current_scene.add_child(_ui)
		_ui.setup(party, storage, bond, database)
		_ui.party_changed.connect(func(): CombatSignal.party_changed.emit())
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
