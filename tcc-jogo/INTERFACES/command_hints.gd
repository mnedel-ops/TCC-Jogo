class_name CommandHints
extends CanvasLayer
## Lembretes permanentes de comandos no canto inferior esquerdo da tela.
## Troca sozinho entre exploração e combate (CombatSignal.in_combat)
## e some quando o jogo está pausado (GameMenu aberto).

const EXPLORATION: Array[Dictionary] = [
	{"keys": ["TAB"], "label": "Menu"},
	{"keys": ["E"], "label": "Interagir"},
]
const COMBAT: Array[Dictionary] = [
	{"keys": ["W", "A", "S", "D"], "label": "Navegar"},
	{"keys": ["E"], "label": "Confirmar"},
]

const SCREEN_MARGIN := 24
const ENTRY_GAP := 28
const KEY_GAP := 4
const FONT_SIZE := 18
const KEY_FONT_SIZE := 16
const TEXT_COLOR := Color(0.92, 0.92, 0.95)
const PANEL_BG := Color(0.07, 0.07, 0.11, 0.9)
const PANEL_BORDER := Color(0.5, 0.5, 0.6)
const KEY_BG := Color(0.2, 0.2, 0.28)
const KEY_TEXT := Color(1, 1, 1)

var _panel: PanelContainer
var _row: HBoxContainer
var _current: Array[Dictionary] = []


static func hints_for(in_combat: bool) -> Array[Dictionary]:
	return COMBAT if in_combat else EXPLORATION


func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_apply(hints_for(CombatSignal.in_combat))


func _process(_delta: float) -> void:
	visible = not get_tree().paused
	var wanted := hints_for(CombatSignal.in_combat)
	if wanted != _current:
		_apply(wanted)


func set_hints(entries: Array[Dictionary]) -> void:
	_apply(entries)


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(
			Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, SCREEN_MARGIN)
	_panel.grow_horizontal = Control.GROW_DIRECTION_END
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", ENTRY_GAP)
	_panel.add_child(_row)


func _apply(entries: Array[Dictionary]) -> void:
	_current = entries
	for c in _row.get_children():
		_row.remove_child(c)
		c.queue_free()
	for e in entries:
		_row.add_child(_make_entry(e))
	_panel.reset_size()


func _make_entry(e: Dictionary) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 10)

	var keys := HBoxContainer.new()
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keys.add_theme_constant_override("separation", KEY_GAP)
	for k in e.get("keys", []):
		keys.add_child(_make_key(String(k)))
	box.add_child(keys)

	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.text = String(e.get("label", ""))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", FONT_SIZE)
	lbl.add_theme_color_override("font_color", TEXT_COLOR)
	box.add_child(lbl)
	return box


func _make_key(text: String) -> PanelContainer:
	var key := PanelContainer.new()
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.custom_minimum_size = Vector2(30, 30)
	key.add_theme_stylebox_override("panel", _key_style())
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", KEY_FONT_SIZE)
	l.add_theme_color_override("font_color", KEY_TEXT)
	key.add_child(l)
	return key


func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_BG
	s.border_color = PANEL_BORDER
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


## Tecla com borda inferior mais grossa: parece tecla física.
func _key_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = KEY_BG
	s.border_color = PANEL_BORDER
	s.set_border_width_all(2)
	s.border_width_bottom = 4
	s.set_corner_radius_all(5)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	return s
