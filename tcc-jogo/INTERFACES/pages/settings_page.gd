class_name SettingsPage
extends MenuPage

# Página "Settings" do menu de pausa: Música, SFX (ligado/desligado) e FPS.
# Teclado: cima/baixo move, interagir/direita alterna, esquerda volta
# (na linha "Limite de FPS", esquerda/direita trocam o valor). Mouse: clique.

const GOLD := Color(1, 0.85, 0.2)
const PANEL_BG := Color(0.07, 0.07, 0.11, 0.94)
const PANEL_BORDER := Color(0.5, 0.5, 0.6)
const ON_COLOR := Color(0.5, 1, 0.5)
const OFF_COLOR := Color(1, 0.45, 0.45)

enum Row { MUSIC, SFX, FPS_LIMIT, SHOW_FPS }

var _cursor := 0
var _slots: Array[PanelContainer] = []
var _names: Array[Label] = []
var _values: Array[Label] = []


func _ready() -> void:
	_build()
	_refresh()


func on_open() -> void:
	_cursor = 0
	_refresh()


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("menu_down"):
		_cursor = wrapi(_cursor + 1, 0, _slots.size())
	elif event.is_action_pressed("menu_up"):
		_cursor = wrapi(_cursor - 1, 0, _slots.size())
	elif event.is_action_pressed("menu_interact") or event.is_action_pressed("menu_right"):
		_activate(_cursor, 1)
	elif event.is_action_pressed("menu_left"):
		if _cursor == Row.FPS_LIMIT:
			_activate(_cursor, -1)
		else:
			back_requested.emit()
			return true
	else:
		return false
	_refresh()
	return true


func _activate(row: int, dir: int) -> void:
	match row:
		Row.MUSIC:
			GameSettings.set_music(not GameSettings.music_on)
		Row.SFX:
			GameSettings.set_sfx(not GameSettings.sfx_on)
		Row.FPS_LIMIT:
			GameSettings.cycle_fps_limit(dir)
		Row.SHOW_FPS:
			GameSettings.set_show_fps(not GameSettings.show_fps)


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var title_lbl := Label.new()
	title_lbl.text = "Configurações"
	title_lbl.add_theme_font_size_override("font_size", 32)
	title_lbl.add_theme_color_override("font_color", GOLD)
	root.add_child(title_lbl)
	root.add_child(HSeparator.new())

	_add_section(root, "Áudio")
	_add_row(root, Row.MUSIC, "Música")
	_add_row(root, Row.SFX, "SFX")

	_add_section(root, "Vídeo")
	_add_row(root, Row.FPS_LIMIT, "Limite de FPS")
	_add_row(root, Row.SHOW_FPS, "Mostrar FPS na tela")


func _add_section(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.modulate.a = 0.7
	l.add_theme_font_size_override("font_size", 20)
	parent.add_child(l)


func _add_row(parent: Control, row: int, text: String) -> void:
	var slot := PanelContainer.new()
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))

	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(h)

	var name_lbl := Label.new()
	name_lbl.text = text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.add_theme_font_size_override("font_size", 22)
	val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(val_lbl)

	slot.mouse_entered.connect(_on_row_hover.bind(row))
	slot.gui_input.connect(_on_row_gui_input.bind(row))

	parent.add_child(slot)
	_slots.append(slot)
	_names.append(name_lbl)
	_values.append(val_lbl)


func _on_row_hover(row: int) -> void:
	_cursor = row
	_refresh()


func _on_row_gui_input(event: InputEvent, row: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_cursor = row
		_activate(row, 1)
		_refresh()


func _refresh() -> void:
	_set_bool(Row.MUSIC, GameSettings.music_on)
	_set_bool(Row.SFX, GameSettings.sfx_on)
	_values[Row.FPS_LIMIT].text = "< %s >" % GameSettings.fps_limit_text()
	_values[Row.FPS_LIMIT].add_theme_color_override("font_color", Color.WHITE)
	_set_bool(Row.SHOW_FPS, GameSettings.show_fps)

	for i in _slots.size():
		var hot := (i == _cursor)
		_slots[i].add_theme_stylebox_override("panel", _box(
			Color(GOLD, 0.18) if hot else Color(0, 0, 0, 0),
			GOLD if hot else Color(0, 0, 0, 0)))
		_names[i].add_theme_color_override("font_color", GOLD if hot else Color.WHITE)


func _set_bool(row: int, on: bool) -> void:
	_values[row].text = "Ligado" if on else "Desligado"
	_values[row].add_theme_color_override("font_color", ON_COLOR if on else OFF_COLOR)


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2 if border.a > 0.0 else 0)
	s.set_corner_radius_all(6)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s
