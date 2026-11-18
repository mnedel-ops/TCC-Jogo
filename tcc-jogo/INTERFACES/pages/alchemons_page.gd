class_name AlchemonsPage
extends MenuPage


signal alchemon_selected(index: int)

const GOLD := Color(1, 0.85, 0.2)
const PANEL_BG := Color(0.07, 0.07, 0.11, 0.94)
const PANEL_BG_ACTIVE := Color(0.14, 0.13, 0.08, 0.96)
const PANEL_BORDER := Color(0.5, 0.5, 0.6)
const DEFAULT_PARTY := "res://DATABASE/Alchemons/PlayerCurrentAlchemon.tres"
const DEFAULT_DATABASE := "res://DATABASE/Alchemons/AlchemonDataBaseComplete.tres"
const DEFAULT_PLAYER := "res://DATABASE/Player/player.tres"
const STATS_TAB := 0
const ATTRS: Array[Dictionary] = [
	{"key": "hp", "label": "HP"},
	{"key": "attack", "label": "Ataque"},
	{"key": "defense", "label": "Defesa"},
	{"key": "speed", "label": "Velocidade"},
	{"key": "energy", "label": "Energia de ação"},
]

@export var party: PlayerPartyData
@export var database: AlchemonDatabase
@export var player: PlayerData

var _entries: Array[Dictionary] = []
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
var _stats_left: VBoxContainer
var _detail_box: VBoxContainer
var _hint_label: Label
var _attr_rows: Array[PanelContainer] = []
var _attr_names: Array[Label] = []
var _consulting := false
var _attr_cursor := 0
var _attacks_grid: GridContainer
var _info_grid: GridContainer


func _ready() -> void:
	if party == null:
		party = load(DEFAULT_PARTY)
	if database == null:
		database = load(DEFAULT_DATABASE)
	if player == null:
		player = load(DEFAULT_PLAYER)
	_build()
	_populate()


func on_open() -> void:
	_consulting = false
	_attr_cursor = 0
	_populate()


func handle_input(event: InputEvent) -> bool:
	if _consulting:
		return _handle_consult_input(event)
	if event.is_action_pressed("menu_interact"):
		return _begin_consult()
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


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

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

	_tabs_panel = PanelContainer.new()
	_tabs_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs_panel.size_flags_stretch_ratio = 1.0
	_tabs_panel.add_theme_stylebox_override("panel", _box(PANEL_BG, PANEL_BORDER, 8))
	root.add_child(_tabs_panel)

	_tabs = TabContainer.new()
	_tabs.get_tab_bar().focus_mode = Control.FOCUS_NONE
	_tabs.add_theme_color_override("font_hovered_color", GOLD)
	_tabs.add_theme_color_override("font_selected_color", GOLD)
	_tabs_panel.add_child(_tabs)

	_make_stats_tab()
	_attacks_grid = _make_grid_tab("Ataques", 4)
	_info_grid = _make_grid_tab("Info", 2)
	_tabs.tab_changed.connect(_on_tab_changed)


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
	preview.set_sheet(sheet)

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


func _show_detail() -> void:
	if _selected < 0 or _selected >= _entries.size():
		return
	var inst: AlchemonInstance = _entries[_selected].inst
	var sheet: AlchemonSheet = _entries[_selected].sheet
	_fill_stats(inst, sheet)
	_fill_attacks(inst, sheet)
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


func _make_stats_tab() -> void:
	var split := HBoxContainer.new()
	split.name = "Stats"
	split.add_theme_constant_override("separation", 16)
	_tabs.add_child(split)

	var left_scroll := ScrollContainer.new()
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_stretch_ratio = 1.0
	split.add_child(left_scroll)
	_stats_left = VBoxContainer.new()
	_stats_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_left.add_theme_constant_override("separation", 4)
	left_scroll.add_child(_stats_left)

	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.4
	right.add_theme_stylebox_override("panel", _box(Color(0.04, 0.04, 0.07, 0.9), Color(PANEL_BORDER, 0.5), 8))
	split.add_child(right)
	var right_v := VBoxContainer.new()
	right_v.add_theme_constant_override("separation", 6)
	right.add_child(right_v)

	var right_scroll := ScrollContainer.new()
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_v.add_child(right_scroll)
	_detail_box = VBoxContainer.new()
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.add_theme_constant_override("separation", 4)
	right_scroll.add_child(_detail_box)

	_hint_label = Label.new()
	_hint_label.modulate.a = 0.7
	right_v.add_child(_hint_label)


func _fill_stats(inst: AlchemonInstance, s: AlchemonSheet) -> void:
	for c in _stats_left.get_children():
		_stats_left.remove_child(c)
		c.queue_free()
	_attr_rows.clear()
	_attr_names.clear()

	var stats := inst.compute_stats(s)
	var max_hp: int = stats.max_hp
	var max_energy: int = stats.action_energy
	var values := {
		"hp": "%d / %d" % [inst.hp_or_full(max_hp), max_hp],
		"attack": str(stats.attack),
		"defense": str(stats.defense),
		"speed": str(stats.mechanical_speed),
		"energy": "%d / %d" % [inst.energy_or_full(max_energy), max_energy],
	}

	_stats_left.add_child(_section_label("Informações da criatura"))
	var info := GridContainer.new()
	info.columns = 2
	info.add_theme_constant_override("h_separation", 24)
	info.add_theme_constant_override("v_separation", 4)
	_stats_left.add_child(info)
	_add_pair(info, "Tipo", AlchemonType.type_name(s.element_type))
	_add_pair(info, "Nivel", str(inst.level))
	_add_pair(info, "XP", "%d / %d" % [inst.experience, AlchemonGrowth.xp_to_next(inst.level)])
	_add_pair(info, "Elétrons de valência", str(s.chem_valence()))

	_stats_left.add_child(HSeparator.new())
	_stats_left.add_child(_section_label("Atributos"))
	for i in ATTRS.size():
		_stats_left.add_child(_make_attr_row(i, values[ATTRS[i].key]))

	_refresh_attr_rows()
	_refresh_detail()


func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", GOLD)
	return l


func _make_attr_row(i: int, value_text: String) -> PanelContainer:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 6))
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	var name_lbl := Label.new()
	name_lbl.text = ATTRS[i].label
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(name_lbl)
	var val_lbl := Label.new()
	val_lbl.text = value_text
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(val_lbl)
	row.gui_input.connect(_on_attr_gui_input.bind(i))
	_attr_rows.append(row)
	_attr_names.append(name_lbl)
	return row


func _refresh_attr_rows() -> void:
	for i in _attr_rows.size():
		var on := _consulting and i == _attr_cursor
		_attr_rows[i].add_theme_stylebox_override("panel", _box(
			Color(GOLD, 0.18) if on else Color(0, 0, 0, 0),
			GOLD if on else Color(0, 0, 0, 0), 6))
		_attr_names[i].add_theme_color_override("font_color", GOLD if on else Color.WHITE)


func _on_attr_gui_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _entries.is_empty():
			return
		_consulting = true
		_attr_cursor = i
		_refresh_attr_rows()
		_refresh_detail()


func _on_tab_changed(_tab: int) -> void:
	if _consulting:
		_end_consult()


func _begin_consult() -> bool:
	if _entries.is_empty() or _tabs.current_tab != STATS_TAB:
		return false
	_consulting = true
	_attr_cursor = 0
	_refresh_attr_rows()
	_refresh_detail()
	return true


func _end_consult() -> void:
	_consulting = false
	_refresh_attr_rows()
	_refresh_detail()


func _move_attr(delta: int) -> void:
	_attr_cursor = wrapi(_attr_cursor + delta, 0, ATTRS.size())
	_refresh_attr_rows()
	_refresh_detail()


## Durante a consulta: setas cima/baixo trocam o atributo; E ou Esc saem.
## Esquerda/direita e troca de aba ficam bloqueadas (sem sair da aba Stats por engano).
func _handle_consult_input(event: InputEvent) -> bool:
	if event.is_action_pressed("menu_down"):
		_move_attr(1)
	elif event.is_action_pressed("menu_up"):
		_move_attr(-1)
	elif event.is_action_pressed("menu_interact") or event.is_action_pressed("ui_cancel"):
		_end_consult()
	elif event.is_action_pressed("menu_left") or event.is_action_pressed("menu_right") \
			or event.is_action_pressed("ui_page_down") or event.is_action_pressed("ui_page_up"):
		pass
	else:
		return false
	return true


func _detail_text(text: String, alpha := 1.0, font_size := 0, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.modulate.a = alpha
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	if color != Color.WHITE:
		l.add_theme_color_override("font_color", color)
	return l


func _refresh_detail() -> void:
	if _detail_box == null:
		return
	for c in _detail_box.get_children():
		_detail_box.remove_child(c)
		c.queue_free()
	if not _consulting:
		_hint_label.text = "E: consultar atributos"
	else:
		_hint_label.text = "Cima/Baixo: trocar atributo     E ou Esc: sair da consulta"
	if _selected < 0 or _selected >= _entries.size():
		return
	if not _consulting:
		_detail_box.add_child(_detail_text("Pressione E para consultar a origem química e o cálculo de cada atributo desta criatura.", 0.7))
		return

	var inst: AlchemonInstance = _entries[_selected].inst
	var sheet: AlchemonSheet = _entries[_selected].sheet
	var key: String = ATTRS[_attr_cursor].key
	var chem := AlchemonStatGenerator.describe_stat(key, sheet)
	var fin := inst.stat_breakdown(sheet, key)

	_detail_box.add_child(_detail_text("Selecionado", 0.7))
	_detail_box.add_child(_detail_text(chem["title"], 1.0, 22, GOLD))
	_detail_box.add_child(_detail_text(str(fin["result"]), 1.0, 40))
	_detail_box.add_child(_detail_text(chem["description"]))

	_detail_box.add_child(_detail_text("Origem química", 0.7))
	_detail_box.add_child(_detail_text(chem["origin"]))
	_detail_box.add_child(_detail_text("Valor de origem", 0.7))
	_detail_box.add_child(_detail_text(chem["source"]))

	_detail_box.add_child(_detail_text("Cálculo", 0.7))
	var problem: String = chem["problem"]
	if problem != "":
		_detail_box.add_child(_detail_text("Dados químicos incompletos: %s A base abaixo vem direto da ficha." % problem, 1.0, 0, Color(1, 0.6, 0.4)))

	var formulas: Array = chem["formulas"] + fin["formulas"]
	for line in formulas:
		_detail_box.add_child(_detail_text(str(line), 0.7))

	_detail_box.add_child(_detail_text("Com os valores desta criatura:", 0.7))
	for line in chem["steps"]:
		_detail_box.add_child(_detail_text(str(line)))
	var generated: int = chem["base"]
	var stored: int = fin["base"]
	if generated >= 0 and generated != stored:
		_detail_box.add_child(_detail_text("A ficha guarda B = %d (o gerado seria %d). O jogo usa o valor da ficha." % [stored, generated], 1.0, 0, Color(1, 0.6, 0.4)))
	elif generated < 0:
		_detail_box.add_child(_detail_text("B = %d (valor base da ficha)" % stored))
	for line in fin["steps"]:
		_detail_box.add_child(_detail_text(str(line)))


func _fill_attacks(inst: AlchemonInstance, s: AlchemonSheet) -> void:
	_clear(_attacks_grid)
	# Golpes reais da criatura (attack_ids), não a lista legada da ficha da espécie.
	var ids: Array[int] = inst.attack_ids
	if ids.is_empty():
		ids = AttackLearning.initial_attack_ids(s, inst.level)
	var attacks: Array[AttackData] = []
	for id in ids:
		var a := AttackLearning.resolve(s, id)
		if a != null and a not in attacks:
			attacks.append(a)
	if attacks.is_empty():
		_add_pair(_attacks_grid, "Ataques", "-")
		return

	for h in ["Nome", "Tipo", "Poder", "Custo"]:
		var head := Label.new()
		head.text = h
		head.modulate.a = 0.7
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL if h == "Nome" else Control.SIZE_FILL
		_attacks_grid.add_child(head)
	for a in attacks:
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
