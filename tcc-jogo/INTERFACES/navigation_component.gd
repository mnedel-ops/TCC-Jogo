class_name MenuNavigationComponent
extends Node

signal button_activated(button_name: String)

@export var buttons_container: VBoxContainer
@export var button_names: PackedStringArray = []

var _button_nodes: Array[Button] = []
var _selected_index := 0

func _ready() -> void:
	_create_buttons()

func _create_buttons() -> void:
	for child in buttons_container.get_children():
		child.queue_free()
	_button_nodes.clear()

	for button_name in button_names:
		var button := Button.new()
		button.text = button_name
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.pressed.connect(_on_button_pressed.bind(button_name))
		buttons_container.add_child(button)
		_button_nodes.append(button)

func reset_selection() -> void:
	_selected_index = 0
	_update_selection_visual()

# Retorna true se consumiu o evento (pra quem chama saber se marca handled).
func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("menu_down"):
		_move_selection(1)
		return true
	elif event.is_action_pressed("menu_up"):
		_move_selection(-1)
		return true
	elif event.is_action_pressed("menu_interact") or event.is_action_pressed("menu_right"):
		_activate_selected()
		return true
	return false

func _move_selection(delta: int) -> void:
	if _button_nodes.is_empty():
		return
	_selected_index = wrapi(_selected_index + delta, 0, _button_nodes.size())
	_update_selection_visual()

func _update_selection_visual() -> void:
	for i in _button_nodes.size():
		_button_nodes[i].modulate = Color.WHITE if i != _selected_index else Color(1, 1, 0)

func _activate_selected() -> void:
	if _button_nodes.is_empty():
		return
	_button_nodes[_selected_index].pressed.emit()

func _on_button_pressed(button_name: String) -> void:
	button_activated.emit(button_name)
