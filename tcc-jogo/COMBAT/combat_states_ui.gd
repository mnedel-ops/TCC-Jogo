class_name Combat_UI_states
extends VBoxContainer

## Gerencia TODA a apresentacao do combate: log, HP, texto de turno, botoes.
## Nao decide regra nenhuma - so mostra o que o Controller manda. Botoes
## (incluindo Fugir) sao todos instanciados dinamicamente via show_options.

@onready var log_label: Label = $LogLabel
@onready var hp_label: Label = $HPLabel
@onready var turn_label: Label = $TurnLabel
@onready var action_buttons: VBoxContainer = $ActionButtons
@onready var temperature_label: Label = $TemperatureLabel

func log_message(text: String) -> void:
	log_label.text += "\n" + text


func set_turn_text(text: String) -> void:
	turn_label.text = text

# Versao V2, sem depender de AlchemonSheet - recebe so {name, hp, max_hp}.
# UI recebe entradas prontas para exibicao; so entende Dictionary generico.
func update_hp_dict(player_entries: Array[Dictionary], enemy_entries: Array[Dictionary]) -> void:
	var text := ""
	for e in player_entries:
		text += "%s Lv%d: %d/%d HP  (XP %d/%d)   " % [e.name, e.level, e.hp, e.max_hp, e.xp, e.xp_max]
	text += "\n"
	for e in enemy_entries:
		text += "%s Lv%d: %d/%d HP  (XP %d/%d)   " % [e.name, e.level, e.hp, e.max_hp, e.xp, e.xp_max]
	hp_label.text = text

func update_temperature(temperature: float):
	temperature_label.text = "Temperatura da Arena: %.2fK" %temperature

var _button_nodes: Array[Button] = []
var _selected_index := 0

func show_options(options: Array) -> void:
	clear_options()
	_button_nodes.clear()
	_selected_index = 0
	for option in options:
		var button := Button.new()
		button.text = option.text
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(option.callback)
		action_buttons.add_child(button)
		_button_nodes.append(button)
	_update_selection_visual()

func clear_options() -> void:
	for child in action_buttons.get_children():
		child.queue_free()
	_button_nodes.clear()

func _unhandled_input(event: InputEvent) -> void:
	if _button_nodes.is_empty():
		return
	if event.is_action_pressed("menu_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_interact") or event.is_action_pressed("menu_right"):
		_activate_selected()
		get_viewport().set_input_as_handled()

func _move_selection(delta: int) -> void:
	_selected_index = wrapi(_selected_index + delta, 0, _button_nodes.size())
	_update_selection_visual()

func _update_selection_visual() -> void:
	for i in _button_nodes.size():
		_button_nodes[i].modulate = Color.WHITE if i != _selected_index else Color(1, 1, 0)

func _activate_selected() -> void:
	_button_nodes[_selected_index].pressed.emit()


func show_combat_end(player_won: bool) -> void:
	set_turn_text("Fim de combate.")
	log_message("Vitoria!" if player_won else "Derrota!")
	clear_options()
