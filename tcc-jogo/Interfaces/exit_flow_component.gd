class_name ExitFlowComponent
extends Node

@export var exit_without_saving_dialog: ConfirmationDialog
@export var exit_confirm_dialog: ConfirmationDialog

func _ready() -> void:
	exit_without_saving_dialog.confirmed.connect(_open_exit_confirmation)
	exit_confirm_dialog.confirmed.connect(_quit_game)

	exit_without_saving_dialog.dialog_text = "Do you wish to exit without saving?"
	exit_without_saving_dialog.ok_button_text = "Yes"
	exit_without_saving_dialog.cancel_button_text = "No"

	exit_confirm_dialog.dialog_text = "You want to exit the game?"
	exit_confirm_dialog.ok_button_text = "Exit"
	exit_confirm_dialog.cancel_button_text = "Cancel"

func start_exit_flow() -> void:
	exit_without_saving_dialog.popup_centered()

func _open_exit_confirmation() -> void:
	exit_confirm_dialog.popup_centered()

func _quit_game() -> void:
	get_tree().quit()
