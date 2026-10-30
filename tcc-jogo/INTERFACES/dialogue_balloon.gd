class_name DialogueBalloon
extends Control
## Speech balloon that follows a 3D node on screen (same projection trick as
## CombatBalloon). The root Control sits exactly on the anchor point above the
## NPC's head; the panel is drawn above it and a small tail points down at it.

@export var offset := Vector3(0, 2.4, 0)   # above the NPC's head
@export var chars_per_second := 45.0

const MIN_WIDTH := 90.0
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

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_panel.add_child(_label)

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
	var font := _label.get_theme_font("font")
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	_label.custom_minimum_size.x = clampf(text_w + 4.0, MIN_WIDTH, MAX_WIDTH)
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


func is_open() -> bool:
	return visible


func is_typing() -> bool:
	return visible and _tween != null and _tween.is_running()


## Finishes the typewriter right now.
func skip_typing() -> void:
	if _tween != null:
		_tween.kill()
	_label.visible_ratio = 1.0


func close() -> void:
	if _tween != null:
		_tween.kill()
	visible = false


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
