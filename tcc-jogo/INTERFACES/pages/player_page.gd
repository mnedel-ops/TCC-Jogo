class_name PlayerPage
extends MenuPage

## Player page: one card, two columns.
##  Left : top = name / money / time played, bottom = badges grid.
##  Right: player portrait.
## Data comes from PlayerData. Pure UI, read only.
##
## Keys: menu_left (or Esc) = back to the menu list.
## Mouse: hover a badge = tooltip.

const GOLD := Color(1, 0.85, 0.2)
const PANEL_BG := Color(0.07, 0.07, 0.11, 0.94)
const PANEL_BORDER := Color(0.5, 0.5, 0.6)
const SLOT_BG := Color(0.2, 0.2, 0.28)
const DEFAULT_DATA := "res://DATABASE/Player/player.tres"

@export var player: PlayerData
@export var badge_columns := 4
@export var badge_size := Vector2(64, 64)

var _name_label: Label
var _money_label: Label
var _time_label: Label
var _badge_count: Label
var _badge_grid: GridContainer
var _portrait_holder: Control
var _last_second := -1


func _ready() -> void:      # no super: no placeholder
	if player == null:
		player = load(DEFAULT_DATA)
	_build()
	refresh()


func _process(_delta: float) -> void:
	if player == null or not is_visible_in_tree():
		return
	var sec := int(player.get_play_time())
	if sec != _last_second:
		_last_second = sec
		_time_label.text = _format_time(sec)


# --------------------------------------------------------------- MenuPage API

func on_open() -> void:
	refresh()


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("menu_left"):
		back_requested.emit()
		return true
	return false


# ------------------------------------------------------------------ building

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
	title_lbl.text = "Jogador"
	title_lbl.add_theme_font_size_override("font_size", 32)
	title_lbl.add_theme_color_override("font_color", GOLD)
	root.add_child(title_lbl)
	root.add_child(HSeparator.new())

	# the card
	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _box(PANEL_BG, PANEL_BORDER, 8))
	root.add_child(card)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	card.add_child(cols)

	_build_left(cols)
	_build_right(cols)


func _build_left(cols: Control) -> void:
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.4
	left.add_theme_constant_override("separation", 12)
	cols.add_child(left)

	# line 1: name / money / time
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	left.add_child(info)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 32)
	_name_label.add_theme_color_override("font_color", GOLD)
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(_name_label)

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 24)
	stats.add_theme_constant_override("v_separation", 4)
	info.add_child(stats)
	_money_label = _add_stat(stats, "Dinheiro")
	_time_label = _add_stat(stats, "Tempo de jogo")

	left.add_child(HSeparator.new())

	# line 2: badges
	var head := HBoxContainer.new()
	left.add_child(head)
	var badges_title := Label.new()
	badges_title.text = "Insignias"
	badges_title.add_theme_font_size_override("font_size", 22)
	badges_title.add_theme_color_override("font_color", GOLD)
	badges_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(badges_title)
	_badge_count = Label.new()
	_badge_count.modulate.a = 0.7
	head.add_child(_badge_count)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)

	_badge_grid = GridContainer.new()
	_badge_grid.columns = badge_columns
	_badge_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_badge_grid.add_theme_constant_override("h_separation", 12)
	_badge_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_badge_grid)


func _add_stat(grid: GridContainer, key_text: String) -> Label:
	var key := Label.new()
	key.text = key_text
	key.modulate.a = 0.7
	grid.add_child(key)
	var val := Label.new()
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(val)
	return val


func _build_right(cols: Control) -> void:
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = 1.0
	frame.add_theme_stylebox_override("panel", _box(Color(0.04, 0.04, 0.07, 0.9), PANEL_BORDER, 8))
	cols.add_child(frame)

	_portrait_holder = Control.new()
	frame.add_child(_portrait_holder)


func _box(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2 if border.a > 0.0 else 0)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


# ------------------------------------------------------------------- refresh

func refresh() -> void:
	if player == null:
		return
	_name_label.text = player.player_name
	_money_label.text = "$ " + _with_thousands(player.money)
	_last_second = -1
	_set_portrait()
	_fill_badges()


func _set_portrait() -> void:
	for c in _portrait_holder.get_children():
		_portrait_holder.remove_child(c)
		c.queue_free()

	if player.portrait != null:
		var tex := TextureRect.new()
		tex.texture = player.portrait
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_portrait_holder.add_child(tex)
		return

	# no portrait yet: big first letter
	var lbl := Label.new()
	lbl.text = player.player_name.left(1)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 96)
	lbl.modulate.a = 0.35
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_holder.add_child(lbl)


func _fill_badges() -> void:
	for c in _badge_grid.get_children():
		_badge_grid.remove_child(c)
		c.queue_free()

	var earned := 0
	var slots := maxi(player.badge_slots, player.badges.size())
	for i in slots:
		var data: BadgeData = player.badges[i] if i < player.badges.size() else null
		if data != null and data.earned:
			earned += 1
		_badge_grid.add_child(_make_badge_slot(data))
	_badge_count.text = "%d / %d" % [earned, slots]


func _make_badge_slot(data: BadgeData) -> Control:
	var has := data != null and data.earned

	var slot := PanelContainer.new()
	slot.custom_minimum_size = badge_size
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.add_theme_stylebox_override("panel", _box(
		SLOT_BG if has else Color(0.1, 0.1, 0.15),
		GOLD if has else PANEL_BORDER, 6))
	if data != null:
		slot.tooltip_text = data.badge_name if has else "???"

	if data != null and data.icon != null:
		var tex := TextureRect.new()
		tex.texture = data.icon
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex.modulate = Color.WHITE if has else Color(0, 0, 0, 0.6)
		slot.add_child(tex)
	else:
		var l := Label.new()
		l.text = data.badge_name.left(1) if data != null and has else "?"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", int(badge_size.y * 0.45))
		l.add_theme_color_override("font_color", GOLD if has else Color.WHITE)
		l.modulate.a = 1.0 if has else 0.3
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(l)
	return slot


# ------------------------------------------------------------------- helpers

func _format_time(total_seconds: int) -> String:
	return "%d:%02d:%02d" % [total_seconds / 3600, (total_seconds / 60) % 60, total_seconds % 60]


func _with_thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += "."
		out += s[i]
	return ("-" if n < 0 else "") + out
