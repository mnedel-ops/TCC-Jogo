class_name AlchemonsPage
extends MenuPage

## Alchemons page (the player's team): header + portraits row + tabs.
##  Header : player name (left), "Equipe: <team name>" (right).
##  Portraits: one card per party member (3D preview, name, level).
##             The card being read is highlighted in gold.
##  Tabs   : Stats / Ataques / Info for the highlighted alchemon.
## Pure UI, read only. Data: PlayerPartyData + AlchemonDatabase + PlayerData.
##
## Keys: menu_left / menu_right = previous / next alchemon
##         (menu_left on the first one = back to the menu list),
##       menu_up / menu_down (or ui_page_up / ui_page_down) = previous / next tab.
## Mouse: click a portrait = select it.

signal alchemon_selected(index: int)

const GOLD := Color(1, 0.85, 0.2)
const PANEL_BG := Color(0.07, 0.07, 0.11, 0.94)
const PANEL_BG_ACTIVE := Color(0.14, 0.13, 0.08, 0.96)
const PANEL_BORDER := Color(0.5, 0.5, 0.6)
const DEFAULT_PARTY := "res://DATABASE/Alchemons/PlayerCurrentAlchemon.tres"
const DEFAULT_DATABASE := "res://DATABASE/Alchemons/AlchemonDataBaseComplete.tres"
const DEFAULT_PLAYER := "res://DATABASE/Player/player.tres"

@export var party: PlayerPartyData
@export var database: AlchemonDatabase
@export var player: PlayerData

var _entries: Array[Dictionary] = []     # {inst: AlchemonInstance, sheet: AlchemonSheet}
var _cards: Array[PanelContainer] = []
var _previews: Array[AlchemonPreview] = []
var _name_labels: Array[Label] = []
var _selected := 0
var _hover := -1

var _title_label: Label
var _team_label: Label
var _cards_box: HBoxContainer
var _empty_label: Label
var _tabs_panel: PanelContainer
var _tabs: TabContainer
var _stats_grid: GridContainer
var _attacks_grid: GridContainer
var _info_grid: GridContainer


func _ready() -> void:      # no super: no placeholder
	if party == null:
		party = load(DEFAULT_PARTY)
	if database == null:
		database = load(DEFAULT_DATABASE)
	if player == null:
		player = load(DEFAULT_PLAYER)
	_build()
	_populate()


# --------------------------------------------------------------- MenuPage API

func on_open() -> void:
	_populate()


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("menu_left"):
		if _selected > 0:
			_select(_selected - 1)
		else:
			back_requested.emit()
	elif event.is_action_pressed("menu_right"):
		_select(_selected + 1)
	elif event.is_action_pressed("menu_down") or event.is_action_pressed("ui_page_down"):
		_step_tab(1)
	elif event.is_action_pressed("menu_up") or event.is_action_pressed("ui_page_up"):
		_step_tab(-1)
	else:
		return false
	return true


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

	# header: player name + team
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", GOLD)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)
	var team_key := Label.new()
	team_key.text = "Equipe:"
	team_key.modulate.a = 0.7
	header.add_child(team_key)
	_team_label = Label.new()
	header.add_child(_team_label)
	root.add_child(HSeparator.new())

	# portraits row
	var top := Control.new()
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.size_flags_stretch_ratio = 1.2
	root.add_child(top)

	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 12)
	_cards_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top.add_child(_cards_box)

	_empty_label = Label.new()
	_empty_label.text = "Nenhum alchemon na equipe"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.modulate.a = 0.6
	_empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_empty_label)

	# tabs
	_tabs_panel = PanelContainer.new()
	_tabs_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs_panel.size_flags_stretch_ratio = 1.0
	_tabs_panel.add_theme_stylebox_override("panel", _box(PANEL_BG, PANEL_BORDER, 8))
	root.add_child(_tabs_panel)

	_tabs = TabContainer.new()
	_tabs.get_tab_bar().focus_mode = Control.FOCUS_NONE   # keys go to handle_input, not the tab bar
	_tabs.add_theme_color_override("font_hovered_color", GOLD)
	_tabs.add_theme_color_override("font_selected_color", GOLD)
	_tabs_panel.add_child(_tabs)

	_stats_grid = _make_grid_tab("Stats", 2)
	_attacks_grid = _make_grid_tab("Ataques", 4)
	_info_grid = _make_grid_tab("Info", 2)


func _make_grid_tab(tab_name: String, columns: int) -> GridContainer:
	var sc := ScrollContainer.new()
	sc.name = tab_name
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 4)
	sc.add_child(grid)
	return grid


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


# ---------------------------------------------------------------------- data

func _populate() -> void:
	var previous := _selected

	if player != null:
		_title_label.text = player.player_name
		_team_label.text = player.get_team_name()

	_entries.clear()
	if party != null and database != null:
		for inst in party.party:
			if inst == null:
				continue
			var sheet := database.get_by_id(inst.species_id)
			if sheet != null:
				_entries.append({"inst": inst, "sheet": sheet})

	for c in _cards_box.get_children():
		_cards_box.remove_child(c)
		c.queue_free()
	_cards.clear()
	_previews.clear()
	_name_labels.clear()
	for i in _entries.size():
		_cards_box.add_child(_make_card(i, _entries[i]))

	_empty_label.visible = _entries.is_empty()
	_tabs_panel.visible = not _entries.is_empty()
	_selected = clampi(previous, 0, maxi(_entries.size() - 1, 0))
	_refresh_cards()
	_show_detail()


func _make_card(i: int, entry: Dictionary) -> PanelContainer:
	var inst: AlchemonInstance = entry.inst
	var sheet: AlchemonSheet = entry.sheet

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _box(PANEL_BG, PANEL_BORDER, 8))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)

	var preview := AlchemonPreview.new()
	v.add_child(preview)
	preview.set_sheet(sheet)   # applied when the preview enters the tree

	var nm := Label.new()
	nm.text = _display_name(inst, sheet)
	nm.add_theme_font_size_override("font_size", 24)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nm)

	var lv := Label.new()
	lv.text = "Nv %d" % inst.level
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.modulate.a = 0.7
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(lv)

	card.mouse_entered.connect(_on_card_hover.bind(i))
	card.mouse_exited.connect(_on_card_exit.bind(i))
	card.gui_input.connect(_on_card_gui_input.bind(i))
	_cards.append(card)
	_previews.append(preview)
	_name_labels.append(nm)
	return card


func _display_name(inst: AlchemonInstance, sheet: AlchemonSheet) -> String:
	return inst.creature_name if inst.creature_name != "" else sheet.creature_name


# ------------------------------------------------------------------- cursor

func _refresh_cards() -> void:
	for i in _cards.size():
		var chosen := (i == _selected)
		var hot := (i == _hover)
		var bg := PANEL_BG
		var border := PANEL_BORDER
		if chosen:
			bg = PANEL_BG_ACTIVE
			border = GOLD
		elif hot:
			border = Color(GOLD, 0.45)
		_cards[i].add_theme_stylebox_override("panel", _box(bg, border, 8))
		_name_labels[i].add_theme_color_override("font_color", GOLD if chosen else Color.WHITE)
		_previews[i].spinning = chosen


func _select(i: int) -> void:
	if _entries.is_empty():
		return
	i = clampi(i, 0, _entries.size() - 1)
	if i == _selected:
		return
	_selected = i
	_refresh_cards()
	_show_detail()
	alchemon_selected.emit(i)


func _step_tab(delta: int) -> void:
	_tabs.current_tab = wrapi(_tabs.current_tab + delta, 0, _tabs.get_tab_count())


func _on_card_hover(i: int) -> void:
	_hover = i
	_refresh_cards()


func _on_card_exit(i: int) -> void:
	if _hover == i:
		_hover = -1
		_refresh_cards()


func _on_card_gui_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select(i)


# -------------------------------------------------------------------- detail

func _show_detail() -> void:
	if _selected < 0 or _selected >= _entries.size():
		return
	var inst: AlchemonInstance = _entries[_selected].inst
	var sheet: AlchemonSheet = _entries[_selected].sheet
	_fill_stats(inst, sheet)
	_fill_attacks(sheet)
	_fill_info(sheet)


func _clear(grid: GridContainer) -> void:
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()


func _add_pair(grid: GridContainer, key_text: String, value_text: String) -> void:
	var key := Label.new()
	key.text = key_text
	key.modulate.a = 0.7
	key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	grid.add_child(key)
	var val := Label.new()
	val.text = value_text
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	grid.add_child(val)


func _fill_stats(inst: AlchemonInstance, s: AlchemonSheet) -> void:
	_clear(_stats_grid)
	# instance value if set (-1 = unset), else the GDD formula from the species base
	var max_hp := inst.max_hp if inst.max_hp > 0 else s.max_hp
	var hp := inst.current_hp if inst.current_hp >= 0 else max_hp
	var iv := inst.individual_value
	var lvl := inst.level
	var attack := AlchemonFormulas.compute_attack(s.base_attack, iv, lvl)
	var defense := inst.defense if inst.defense >= 0 else AlchemonFormulas.compute_stat(s.base_defense, iv, lvl)
	var speed := inst.mechanical_speed if inst.mechanical_speed >= 0 else AlchemonFormulas.compute_stat(s.base_mechanical_speed, iv, lvl)
	var energy := inst.action_energy if inst.action_energy >= 0 else AlchemonFormulas.compute_stat(s.base_action_energy, iv, lvl)

	var rows: Array = [
		["Tipo", AlchemonType.type_name(s.element_type)],
		["Nivel", str(lvl)],
		["XP", "%d / %d" % [inst.experience, AlchemonGrowth.XP_TO_LEVEL_UP]],
		["HP", "%d / %d" % [hp, max_hp]],
		["Ataque", str(attack)],
		["Defesa", str(defense)],
		["Velocidade", str(speed)],
		["Energia", str(energy)],
	]
	for r in rows:
		_add_pair(_stats_grid, r[0], r[1])


func _fill_attacks(s: AlchemonSheet) -> void:
	_clear(_attacks_grid)
	var any := false
	for a in s.attacks:
		if a != null:
			any = true
			break
	if not any:
		_add_pair(_attacks_grid, "Ataques", "-")
		return

	for h in ["Nome", "Tipo", "Poder", "Custo"]:
		var head := Label.new()
		head.text = h
		head.modulate.a = 0.7
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL if h == "Nome" else Control.SIZE_FILL
		_attacks_grid.add_child(head)
	for a in s.attacks:
		if a == null:
			continue
		var name_lbl := Label.new()
		name_lbl.text = a.attack_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_attacks_grid.add_child(name_lbl)
		for t in [AlchemonType.type_name(a.element_type), str(a.power), str(a.energy_cost)]:
			var l := Label.new()
			l.text = t
			_attacks_grid.add_child(l)


func _fill_info(s: AlchemonSheet) -> void:
	_clear(_info_grid)
	_add_pair(_info_grid, "Encontrado em", s.found_at if s.found_at != "" else "???")
	_add_pair(_info_grid, "Gosta de", s.likes if s.likes != "" else "???")
	_add_pair(_info_grid, "Nao gosta de", s.dislikes if s.dislikes != "" else "???")
