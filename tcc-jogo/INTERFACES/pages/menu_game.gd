extends CanvasLayer

signal menu_opened
signal menu_closed
signal menu_button_pressed(button_name: String)

@export var mochila: InventoryData

@export var button_names: PackedStringArray = [
	"Periodic",
	"Alchemon",
	"Bag",
	"Save",
	"Settings",
	"Exit"
]

@export var buttons: VBoxContainer

var is_open := false
var _button_nodes: Array[Button] = []   # Referencia direta, nao depende de get_children() toda hora.
var _selected_index := 0

#Exit nodes: depois alterar par um export.
@onready var exit_without_saving_dialog: ConfirmationDialog = $ExitWithoutSavingDialog
@onready var exit_confirm_dialog: ConfirmationDialog = $ExitConfirmDialog

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_create_buttons()
	#Caixas de texto para sair do jogo
	exit_without_saving_dialog.confirmed.connect(_open_exit_confirmation)
	exit_confirm_dialog.confirmed.connect(_quit_game)

	exit_without_saving_dialog.dialog_text = "Do you wish to exit without saving?"
	exit_without_saving_dialog.ok_button_text = "Yes"
	exit_without_saving_dialog.cancel_button_text = "No"

	exit_confirm_dialog.dialog_text = "You want to exit the game?"
	exit_confirm_dialog.ok_button_text = "Exit"
	exit_confirm_dialog.cancel_button_text = "Cancel"

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_menu"):
		toggle_menu()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
#Movimentaco no menu
	if event.is_action_pressed("menu_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
		
	elif event.is_action_pressed("menu_interact") or event.is_action_pressed("menu_right"):
		_activate_selected()
		get_viewport().set_input_as_handled()

func toggle_menu() -> void:
	if is_open:
		close_menu()
	else:
		open_menu()

func open_menu() -> void:
	is_open = true
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_selected_index = 0
	_update_selection_visual()
	menu_opened.emit()

func close_menu() -> void:
	is_open = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	menu_closed.emit()

func _create_buttons() -> void:
	for child in buttons.get_children():
		child.queue_free()
	_button_nodes.clear()

	for button_name in button_names:
		var button := Button.new()
		button.text = button_name
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE          # Sem navegacao nativa ui_up/ui_down.
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE  # So teclado.
		button.pressed.connect(_on_button_pressed.bind(button_name))
		buttons.add_child(button)
		_button_nodes.append(button)

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
	if button_name == "Exit":
		_open_exit_without_saving_popup()
		return
		
	if button_name == "Bag":
		_open_bag()
	menu_button_pressed.emit(button_name)

#Abrir a mochila.
func _open_bag():
	print(mochila.items)
	

# Exit confirmation functions
func _open_exit_without_saving_popup() -> void:
	exit_without_saving_dialog.popup_centered()


func _open_exit_confirmation() -> void:
	exit_confirm_dialog.popup_centered()


func _quit_game() -> void:
	get_tree().quit()
