class_name MenuPage
extends Control


signal back_requested

var title := ""


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


func on_open() -> void:
	pass


func on_close() -> void:
	pass


func handle_input(_event: InputEvent) -> bool:
	return false
