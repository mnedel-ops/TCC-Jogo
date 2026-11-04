class_name DialogueBox
extends Control

signal choice_made(index: int)

@export var chars_per_second := 45.0
@export var left_action: StringName = &"menu_left"
@export var right_action: StringName = &"menu_right"
@export var up_action: StringName = &"menu_up"
@export var down_action: StringName = &"menu_down"
@export var select_action: StringName = &"menu_interact"
@export var back_action: StringName = &"ui_cancel"

const TOP_MARGIN := 16.0
const MAX_WIDTH := 760.0
const MIN_HEIGHT := 84.0
const FONT_SIZE := 20
const CHOICE_COLOR := Color(0.35, 0.35, 0.4)
const CHOICE_SELECTED_COLOR := Color(0.75, 0.25, 0.1)
const BG_COLOR := Color(0.97, 0.97, 0.94)
const BORDER_COLOR := Color(0.1, 0.1, 0.12)
const TEXT_COLOR := Color(0.08, 0.08, 0.1)

var _panel: PanelContainer
var _label: Label
var _tween: Tween
var _choice_row: HBoxContainer
var _choice_labels: Array[Label] = []
var _option_texts: Array[String] = []
var _choosing := false
var _armed := false
var _cursor := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size.y = MIN_HEIGHT
	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(column)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	column.add_child(_label)

	_choice_row = HBoxContainer.new()
	_choice_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_row.add_theme_constant_override("separation", 24)
	_choice_row.visible = false
	column.add_child(_choice_row)


func show_text(text: String) -> void:
	_end_choices()
	_open_text(text)


func ask(text: String, options: Array[String]) -> void:
	_end_choices()
	_choice_labels.clear()
	for c in _choice_row.get_children():
		c.queue_free()
	for o in options:
		var l := Label.new()
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_font_size_override("font_size", FONT_SIZE)
		_choice_row.add_child(l)
		_choice_labels.append(l)
	_option_texts = options
	_cursor = 0
	_choosing = true
	_refresh_choices()
	_choice_row.visible = true
	_choice_row.modulate.a = 0.0
	_open_text(text)
	_armed = false
	await get_tree().process_frame
	_armed = true


func is_open() -> bool:
	return visible


func is_typing() -> bool:
	return visible and _tween != null and _tween.is_running()


func skip_typing() -> void:
	if _tween != null:
		_tween.kill()
	_label.visible_ratio = 1.0
	_on_typing_done()


func close() -> void:
	if _tween != null:
		_tween.kill()
	visible = false
	var was_choosing := _choosing
	_end_choices()
	if was_choosing:
		choice_made.emit(-1)


func _open_text(text: String) -> void:
	_label.custom_minimum_size.x = _width() - 24.0
	_label.text = text
	_label.visible_characters = 0
	_panel.reset_size()
	_place()
	visible = true

	if _tween != null:
		_tween.kill()
	var duration := maxf(float(text.length()) / chars_per_second, 0.05)
	_tween = create_tween()
	_tween.tween_property(_label, "visible_ratio", 1.0, duration).from(0.0)
	_tween.finished.connect(_on_typing_done)


func _on_typing_done() -> void:
	_choice_row.modulate.a = 1.0


func _end_choices() -> void:
	_choosing = false
	_armed = false
	_choice_row.visible = false


func _refresh_choices() -> void:
	for i in _choice_labels.size():
		var selected := i == _cursor
		_choice_labels[i].text = ("▶ " if selected else "   ") + _option_texts[i]
		_choice_labels[i].add_theme_color_override("font_color", CHOICE_SELECTED_COLOR if selected else CHOICE_COLOR)


func _pick(index: int) -> void:
	_end_choices()
	choice_made.emit(index)


func _input(event: InputEvent) -> void:
	if not _choosing or not _armed or not visible:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed(select_action):
		get_viewport().set_input_as_handled()
		if is_typing():
			skip_typing()
		else:
			_pick(_cursor)
	elif event.is_action_pressed(back_action):
		get_viewport().set_input_as_handled()
		_pick(_choice_labels.size() - 1)
	elif is_typing():
		return
	elif event.is_action_pressed(right_action) or event.is_action_pressed(down_action):
		get_viewport().set_input_as_handled()
		_cursor = posmod(_cursor + 1, _choice_labels.size())
		_refresh_choices()
	elif event.is_action_pressed(left_action) or event.is_action_pressed(up_action):
		get_viewport().set_input_as_handled()
		_cursor = posmod(_cursor - 1, _choice_labels.size())
		_refresh_choices()


func _process(_delta: float) -> void:
	if visible:
		_place()


func _width() -> float:
	return minf(MAX_WIDTH, get_viewport_rect().size.x - 32.0)


func _place() -> void:
	position = Vector2(get_viewport_rect().size.x * 0.5, TOP_MARGIN)
	_panel.position = Vector2(-_panel.size.x * 0.5, 0.0)
