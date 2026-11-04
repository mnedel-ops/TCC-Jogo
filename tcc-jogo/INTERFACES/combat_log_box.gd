class_name CombatLogBox
extends Control

const WIDTH := 560.0
const GAP := 12.0
const MAX_LINES := 6
const PROMPT_COLOR := Color(1, 0.85, 0.3)
const LINE_COLOR := Color(0.92, 0.92, 0.95)

var commands: BattleCommands

var _panel: PanelContainer
var _lines: VBoxContainer
var _x := 0.0
var _bar_height := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size.x = WIDTH
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.07, 0.11, 0.9)
	box.border_color = Color(0.5, 0.5, 0.6)
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", box)
	add_child(_panel)
	_lines = VBoxContainer.new()
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.add_theme_constant_override("separation", 2)
	_panel.add_child(_lines)
	_panel.visible = false


func show_prompt(text: String) -> void:
	_clear()
	_add(text, PROMPT_COLOR)


func begin_round() -> void:
	_clear()


func add_line(text: String) -> void:
	_add(text, LINE_COLOR)


func reset_anchor() -> void:
	_x = 0.0


func _clear() -> void:
	for c in _lines.get_children():
		_lines.remove_child(c)
		c.queue_free()
	_panel.reset_size()


func _add(text: String, color: Color) -> void:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = WIDTH - 24.0
	l.add_theme_color_override("font_color", color)
	_lines.add_child(l)
	while _lines.get_child_count() > MAX_LINES:
		var old := _lines.get_child(0)
		_lines.remove_child(old)
		old.queue_free()
	_panel.visible = true
	_panel.reset_size()


func _process(_delta: float) -> void:
	if commands == null or not is_instance_valid(commands):
		return
	if commands.visible:
		var r := commands.bar_rect()
		_x = maxf(_x, r.end.x + GAP)
		_bar_height = r.size.y
		position.y = r.position.y
	var max_x := get_viewport_rect().size.x - WIDTH - 8.0
	position.x = minf(_x, max_x)
	_panel.custom_minimum_size.y = _bar_height
