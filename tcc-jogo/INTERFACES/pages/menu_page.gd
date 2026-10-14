class_name MenuPage
extends Control

## Base for every full-screen page of the game menu (Table, Bag, Alchemons...).
## Make a scene whose ROOT has a script extending MenuPage, then put its path
## in GameMenu.entries ("page"). Empty page = this placeholder.

## Page wants to go back to the list (ex: a "Back" button inside the page).
signal back_requested

var title := ""   # set by GameMenu before add_child


func _ready() -> void:
	if get_child_count() > 0:
		return
	var lbl := Label.new()
	lbl.text = "%s\n(em construcao)" % title
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_font_size_override("font_size", 28)
	add_child(lbl)


## Called each time page opens. Refresh your data here.
func on_open() -> void:
	pass


## Called right before page is freed.
func on_close() -> void:
	pass


## Page gets input first while open. Return true = consumed.
## Not consumed + ui_cancel = menu goes back to the list.
func handle_input(_event: InputEvent) -> bool:
	return false
