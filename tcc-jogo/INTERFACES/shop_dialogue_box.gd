class_name ShopDialogueBox
extends CanvasLayer

signal option_chosen(option: StringName)
signal closed

@export var up_action: StringName = &"menu_up"
@export var down_action: StringName = &"menu_down"
@export var select_action: StringName = &"menu_interact"
@export var back_action: StringName = &"ui_cancel"

const OPTION_IDS: Array[StringName] = [&"buy", &"sell", &"leave"]
const OPTION_LABELS: Array[String] = ["Comprar", "Vender", "Sair"]
const PLACEHOLDER_TEXT := "(Em breve...)"

const BOX_WIDTH := 640.0
const BOTTOM_MARGIN := 24.0
const FONT_SIZE := 20
const BG_COLOR := Color(0.97, 0.97, 0.94)
const BORDER_COLOR := Color(0.1, 0.1, 0.12)
const TEXT_COLOR := Color(0.08, 0.08, 0.1)
const OPTION_COLOR := Color(0.35, 0.35, 0.4)
const SELECTED_COLOR := Color(0.75, 0.25, 0.1)

var _greeting := ""
var _cursor := 0
var _ready_to_input := false

var _text_label: Label
var _option_labels: Array[Label] = []


func _ready() -> void:
	layer = 10
	_build_ui()
	_refresh()
	await get_tree().process_frame
	_ready_to_input = true


func open(greeting: String) -> void:
	_greeting = greeting
	_cursor = 0
	if is_node_ready():
		_refresh()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -BOX_WIDTH * 0.5
	panel.offset_right = BOX_WIDTH * 0.5
	panel.offset_top = -BOTTOM_MARGIN
	panel.offset_bottom = -BOTTOM_MARGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var box := StyleBoxFlat.new()
	box.bg_color = BG_COLOR
	box.border_color = BORDER_COLOR
	box.set_border_width_all(3)
	box.set_corner_radius_all(12)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", box)
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	_text_label = Label.new()
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(BOX_WIDTH - 40.0, 56.0)
	_text_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_text_label.add_theme_color_override("font_color", TEXT_COLOR)
	vbox.add_child(_text_label)

	vbox.add_child(HSeparator.new())

	for i in OPTION_IDS.size():
		var l := Label.new()
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_font_size_override("font_size", FONT_SIZE)
		vbox.add_child(l)
		_option_labels.append(l)


func _refresh() -> void:
	if _text_label == null:
		return
	_text_label.text = _greeting
	for i in _option_labels.size():
		var selected := i == _cursor
		_option_labels[i].text = ("▶ " if selected else "   ") + OPTION_LABELS[i]
		_option_labels[i].add_theme_color_override("font_color", SELECTED_COLOR if selected else OPTION_COLOR)


func _move_cursor(step: int) -> void:
	_cursor = posmod(_cursor + step, OPTION_IDS.size())
	_refresh()


func _select() -> void:
	var id := OPTION_IDS[_cursor]
	if id == &"leave":
		closed.emit()
		return
	_text_label.text = PLACEHOLDER_TEXT
	option_chosen.emit(id)


func _input(event: InputEvent) -> void:
	if not _ready_to_input:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed(down_action):
		get_viewport().set_input_as_handled()
		_move_cursor(1)
	elif event.is_action_pressed(up_action):
		get_viewport().set_input_as_handled()
		_move_cursor(-1)
	elif event.is_action_pressed(select_action):
		get_viewport().set_input_as_handled()
		_select()
	elif event.is_action_pressed(back_action):
		get_viewport().set_input_as_handled()
		closed.emit()
