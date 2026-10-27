extends Control

## Title screen: New Game / Load Game / Quit.
## No class_name on purpose: INTERFACES/menu.gd already owns "Menu".

const GAME_SCENE := "res://scenes/main.tscn"

@onready var new_button: Button = %NewGameButton
@onready var load_button: Button = %LoadGameButton
@onready var quit_button: Button = %QuitButton
@onready var overwrite_dialog: ConfirmationDialog = %OverwriteDialog
@onready var message: Label = %MessageLabel


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false

	overwrite_dialog.dialog_text = "A saved game exists. Starting a new game will overwrite it. Continue?"
	overwrite_dialog.ok_button_text = "New Game"
	overwrite_dialog.cancel_button_text = "Cancel"

	new_button.pressed.connect(_on_new_pressed)
	load_button.pressed.connect(_on_load_pressed)
	quit_button.pressed.connect(get_tree().quit)
	overwrite_dialog.confirmed.connect(_start_new_game)

	load_button.disabled = not GameSession.has_save()
	(new_button if load_button.disabled else load_button).grab_focus()


func _on_new_pressed() -> void:
	if GameSession.has_save():
		overwrite_dialog.popup_centered()
	else:
		_start_new_game()


func _start_new_game() -> void:
	if GameSession.new_game() != OK:
		message.text = "Could not start a new game."
		return
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_load_pressed() -> void:
	# false = main.tscn is not loaded yet, FollowerManager reads the party in _ready.
	if GameSession.load_game(false) != OK:
		message.text = "Save file is missing or corrupt."
		load_button.disabled = not GameSession.has_save()
		return
	get_tree().change_scene_to_file(GAME_SCENE)
