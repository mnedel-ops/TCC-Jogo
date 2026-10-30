class_name DialogueBalloon
extends Control
## Speech balloon that follows a 3D node on screen (same projection trick as
## CombatBalloon). The root Control sits exactly on the anchor point above the
## NPC's head; the panel is drawn above it and a small tail points down at it.

@export var offset := Vector3(0, 2.4, 0)   # above the NPC's head
@export var chars_per_second := 45.0

## ask() finished: index of the picked option. -1 = balloon was closed by someone else.
signal choice_made(index: int)

@export var left_action: StringName = &"menu_left"
@export var right_action: StringName = &"menu_right"
@export var up_action: StringName = &"menu_up"
@export var down_action: StringName = &"menu_down"
@export var select_action: StringName = &"menu_interact"
@export var back_action: StringName = &"ui_cancel"

const MIN_WIDTH := 90.0
const MIN_WIDTH_CHOICES := 170.0
const CHOICE_COLOR := Color(0.35, 0.35, 0.4)
const CHOICE_SELECTED_COLOR := Color(0.75, 0.25, 0.1)
const MAX_WIDTH := 260.0
const TAIL_HEIGHT := 12.0
const FONT_SIZE := 16
const BG_COLOR := Color(0.97, 0.97, 0.94)
const BORDER_COLOR := Color(0.1, 0.1, 0.12)
const TEXT_COLOR := Color(0.08, 0.08, 0.1)

var target: Node3D

var _panel: PanelContainer
var _label: Label
var _tail: Polygon2D
var _tail_line: Line2D
var _tween: Tween
var _box: VBoxContainer
var _choice_row: HBoxContainer
var _choice_labels: Array[Label] = []
var _choosing := false
var _armed := false     # 1 frame after ask(): the key that opened it must not pick
var _cursor := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = BG_COLOR
	box.border_color = BORDER_COLOR
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", box)
	add_child(_panel)

	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_box)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_box.add_child(_label)

	_choice_row = HBoxContainer.new()
	_choice_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_row.add_theme_constant_override("separation", 24)
	_choice_row.visible = false
	_box.add_child(_choice_row)

	# Tail: filled triangle + border, tip exactly on the anchor point (0, 0).
	var tip := Vector2.ZERO
	var left := Vector2(-8, -TAIL_HEIGHT)
	var right := Vector2(8, -TAIL_HEIGHT)
	_tail = Polygon2D.new()
	_tail.color = BG_COLOR
	_tail.polygon = PackedVector2Array([left, right, tip])
	add_child(_tail)
	_tail_line = Line2D.new()
	_tail_line.width = 2.0
	_tail_line.default_color = BORDER_COLOR
	_tail_line.points = PackedVector2Array([left, tip, right])
	add_child(_tail_line)


func bind(p_target: Node3D) -> void:
	target = p_target


## Opens the balloon with `text`, typed out letter by letter.
func show_text(text: String) -> void:
	_end_choices()
	_open_text(text, MIN_WIDTH)


## Same as show_text, then shows `options` side by side under the text.
## Left/right (or up/down) move, menu_interact picks, ui_cancel picks the LAST
## option (put "No" last). Result comes on `choice_made`.
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
	_cursor = 0
	_choosing = true
	_refresh_choices(options)
	_choice_row.visible = true
	_choice_row.modulate.a = 0.0      # takes its space now, shows when typing ends
	_open_text(text, MIN_WIDTH_CHOICES)
	_armed = false
	await get_tree().process_frame
	_armed = true


func _open_text(text: String, min_width: float) -> void:
	var font := _label.get_theme_font("font")
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	_label.custom_minimum_size.x = clampf(text_w + 4.0, min_width, MAX_WIDTH)
	_label.text = text
	_label.visible_characters = 0
	_panel.reset_size()
	_place()   # position before the first visible frame, no one-frame flicker
	visible = true

	if _tween != null:
		_tween.kill()
	var duration := maxf(float(text.length()) / chars_per_second, 0.05)
	_tween = create_tween()
	_tween.tween_property(_label, "visible_ratio", 1.0, duration).from(0.0)
	_tween.finished.connect(_on_typing_done)


func is_open() -> bool:
	return visible


func is_typing() -> bool:
	return visible and _tween != null and _tween.is_running()


## Finishes the typewriter right now.
func skip_typing() -> void:
	if _tween != null:
		_tween.kill()
	_label.visible_ratio = 1.0
	_on_typing_done()


func close() -> void:
	if _tween != null:
		_tween.kill()
	visible = false
	if _choosing:
		_end_choices()
		choice_made.emit(-1)
	else:
		_end_choices()


func _on_typing_done() -> void:
	_choice_row.modulate.a = 1.0


func _end_choices() -> void:
	_choosing = false
	_armed = false
	_choice_row.visible = false


var _option_texts: Array[String] = []

func _refresh_choices(options: Array[String] = []) -> void:
	if not options.is_empty():
		_option_texts = options
	for i in _choice_labels.size():
		var sel := i == _cursor
		_choice_labels[i].text = ("▶ " if sel else "   ") + _option_texts[i]
		_choice_labels[i].add_theme_color_override("font_color", CHOICE_SELECTED_COLOR if sel else CHOICE_COLOR)


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


func _place() -> void:
	var cam := get_viewport().get_camera_3d()
	if target == null or not is_instance_valid(target) or cam == null:
		return
	var world_pos := target.global_position + offset
	_panel.modulate.a = 0.0 if cam.is_position_behind(world_pos) else 1.0
	_tail.modulate.a = _panel.modulate.a
	_tail_line.modulate.a = _panel.modulate.a
	position = cam.unproject_position(world_pos)
	_panel.position = Vector2(-_panel.size.x * 0.5, -_panel.size.y - TAIL_HEIGHT + 1.0)
