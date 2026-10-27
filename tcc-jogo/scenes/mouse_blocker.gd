extends Node

## Gameplay is keyboard/gamepad only. Eats every mouse event in _input, which runs
## BEFORE the GUI, so buttons in menus / combat / PC get no click and no hover.
## Also keeps the cursor captured, because menus set it VISIBLE when they open.
## Lives in main.tscn only: the title menu (scenes/menu.tscn) still takes the mouse.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep working while the tree is paused (menus)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
