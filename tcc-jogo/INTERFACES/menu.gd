extends CanvasLayer
class_name Menu

signal menu_opened
signal menu_closed
signal menu_button_pressed(button_name: String)

@onready var navigation: MenuNavigationComponent = $NavigationComponent
@onready var exit_flow: ExitFlowComponent = $ExitFlowComponent
@onready var bag: BagComponent = $BagComponent

var is_open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	navigation.button_activated.connect(_on_button_activated)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_menu"):
		toggle_menu()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if navigation.handle_input(event):
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
	navigation.reset_selection()
	menu_opened.emit()

func close_menu() -> void:
	is_open = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	menu_closed.emit()

func _on_button_activated(button_name: String) -> void:
	match button_name:
		"Exit":
			exit_flow.start_exit_flow()
		"Bag":
			bag.open_bag()
	menu_button_pressed.emit(button_name)
