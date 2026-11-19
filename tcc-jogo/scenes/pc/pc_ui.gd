class_name PCUI
extends CanvasLayer

signal exit_requested
signal bond_changed
signal party_changed

@export var select_action: StringName = &"menu_interact"
@export var back_action: StringName = &"ui_cancel"
@export var max_party_size := 2

enum Level { LIST, OPTION }

const OPTIONS := ["Alchemy", "Stored", "Exit"]
const OPTION_LABELS := {"Alchemy": "Alquimia", "Stored": "Armazenados", "Exit": "Sair"}
const DESCRIPTIONS := {
	"Alchemy": "Forme o Composto (vínculo).\nEscolha de 2 a 4 Alchemons entre o time e o armazenamento.\nValem as regras da química: as cargas devem se anular (iônico)\nou todas as valências devem fechar (covalente).\nAs proporções são calculadas para você.\nVárias cópias de um elemento formam moléculas (O₂, O₃, P₄).\nO Composto entra em todas as lutas.\nCom um Composto ativo, só é possível rompê-lo.",
	"Stored": "Alchemons armazenados.\nTroque Alchemons capturados com o seu time.",
	"Exit": "Fechar o PC.",
}

# Mesmo padrão visual das páginas de Alchemons / Mochila (ui_style.gd)
const GOLD := UIStyle.GOLD
const TITLE_GOLD := Color(1, 0.85, 0.3)
const PANEL_BG := UIStyle.PANEL_BG
const PANEL_BORDER := UIStyle.PANEL_BORDER
const TEXT_COLOR := UIStyle.TEXT
const MUTED := Color(1, 1, 1, 0.6)
const SEND_COLOR := Color(1, 0.62, 0.3)
const TAKE_COLOR := Color(0.4, 0.85, 0.5)
const TAG_PARTY := Color(0.45, 0.7, 1.0)
const TAG_STORED := Color(0.72, 0.72, 0.8)
const PANEL_SIZE := Vector2(1180, 740)

var _party_data: PlayerPartyData
var _storage: CapturedStorage
var _bond: PlayerBondData
var _db: AlchemonDatabase

var _level := Level.LIST
var _current_option := ""
var _ready_to_input := false
const COMPONENT_CREATED_TEXT := "Seu Composto foi criado!"
var _popup: Control

var _menu: PCList
var _pages: Dictionary = {}
var _hint: Label

var _alch_header: Label
var _alch_list: PCList
var _alch_rows: Array = []
var _alch_picked: Array[AlchemonInstance] = []
var _alch_info: Label
var _alch_action: Label

const ST_TITLE_PARTY := "Seu time"
const ST_TITLE_STORED := "Armazenados"
var _st_party_list: PCList
var _st_stored_list: PCList
var _st_party_rows: Array = []
var _st_stored_rows: Array = []
var _st_focus: PCList
var _st_info: Label
var _st_action: Label
var _st_party_title: Label
var _st_stored_title: Label
var _st_stats: PCStatsCard
var _alch_stats: PCStatsCard

var _exit_yes: Button
var _exit_no: Button

var _idle_label: Label


func setup(party: PlayerPartyData, storage: CapturedStorage, bond: PlayerBondData, database: AlchemonDatabase) -> void:
	_party_data = party
	_storage = storage
	_bond = bond
	_db = database
	_alch_picked.clear()
	_purge_nulls()
	_refresh_all()


func _ready() -> void:
	layer = 10
	for a in [select_action, back_action]:
		if not InputMap.has_action(a):
			push_warning("PCUI: InputMap missing action '%s'" % a)
	_build_ui()
	_menu.select(0)
	_go_list()
	await get_tree().process_frame
	_ready_to_input = true


func _party() -> Array:
	return _party_data.party if _party_data != null else []


func _stored() -> Array:
	return _storage.instances if _storage != null else []


func _purge_nulls() -> void:
	if _party_data != null and _party_data.party.has(null):
		push_warning("PCUI: null entry in PlayerPartyData.party removed. Check PlayerCurrentAlchemon.tres.")
		while _party_data.party.has(null):
			_party_data.party.erase(null)
	if _storage != null and _storage.instances.has(null):
		push_warning("PCUI: null entry in CapturedStorage.instances removed. Check captured_storage.tres.")
		while _storage.instances.has(null):
			_storage.instances.erase(null)


func _short_name(inst: AlchemonInstance) -> String:
	if inst == null:
		return "(empty)"
	var n := inst.creature_name
	if n == "" and _db != null:
		var sheet := _db.get_by_id(inst.species_id)
		n = sheet.creature_name if sheet != null else "???"
	return n


func _kind_label(kind: String) -> String:
	match kind:
		BondRules.MIXTURE: return "Mistura"
		BondRules.COMPOUND: return "Composto"
	return "nenhum"


func _bond_text() -> String:
	if _bond == null or not _bond.is_active():
		return "Composto atual: nenhum"
	var names: Array[String] = []
	for i in _bond.member_indices:
		if i >= 0 and i < _party().size():
			names.append(_short_name(_party()[i]))
	var formula := _bond_formula()
	var tail := "  =  " + formula if formula != "" else ""
	return "Composto atual: %s (%s)%s" % [_kind_label(_bond.kind), " + ".join(names), tail]


func _bond_formula() -> String:
	if _bond == null or _bond.kind != BondRules.COMPOUND or _db == null:
		return ""
	var sheets: Array[AlchemonSheet] = []
	for i in _bond.member_indices:
		if i < 0 or i >= _party().size() or _party()[i] == null:
			return ""
		sheets.append(_db.get_by_id(_party()[i].species_id))
	var data := AlchemyStation.resolve_compound(sheets)
	return "" if data == null else "%s (%s)" % [data.chemical_formula, data.bond_type_label()]


func _sheet_of(inst: AlchemonInstance) -> AlchemonSheet:
	if inst == null or _db == null:
		return null
	return _db.get_by_id(inst.species_id)


func _box(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	return UIStyle.box(bg, border, radius)


func _style_panel(pc: PanelContainer) -> void:
	pc.add_theme_stylebox_override("panel", _box(PANEL_BG, PANEL_BORDER, 8))


func _style_button(b: Button) -> void:
	b.custom_minimum_size = Vector2(120, 40)
	b.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0), PANEL_BORDER, 6))
	b.add_theme_stylebox_override("hover", _box(Color(GOLD, 0.18), GOLD, 6))
	b.add_theme_stylebox_override("pressed", _box(Color(GOLD, 0.25), GOLD, 6))
	b.add_theme_stylebox_override("focus", _box(Color(GOLD, 0.18), GOLD, 6))
	b.add_theme_color_override("font_color", TEXT_COLOR)
	b.add_theme_color_override("font_focus_color", GOLD)
	b.add_theme_color_override("font_hover_color", GOLD)


func _gold_label(l: Label) -> void:
	l.add_theme_color_override("font_color", TITLE_GOLD)


func _make_list() -> PCList:
	return PCList.new()


## Moldura com a lista dentro (o ScrollContainer não desenha borda por conta própria).
func _framed(list: PCList) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_panel(pc)
	pc.add_child(list)
	return pc


func _action_chip(label: Label, text: String, color: Color) -> void:
	label.text = text
	label.add_theme_color_override("font_color", color)


## Retrato quadrado na cor do tipo, com o símbolo químico.
func _portrait(sheet: AlchemonSheet, inst: AlchemonInstance) -> Control:
	var accent := UIStyle.type_color(sheet.element_type) if sheet != null else PANEL_BORDER
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(46, 46)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs := _box(Color(accent, 0.16), Color(accent, 0.9), 6)
	fs.content_margin_left = 2
	fs.content_margin_right = 2
	fs.content_margin_top = 2
	fs.content_margin_bottom = 2
	frame.add_theme_stylebox_override("panel", fs)
	var l := Label.new()
	var sym := ""
	if sheet != null:
		sym = sheet.symbol if sheet.symbol != "" else sheet.creature_name.left(2)
	l.text = sym if sym != "" else "?"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", accent)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(l)
	return frame


## Cartão de um Alchemon: retrato, nome, nível/tipo e uma etiqueta (Time / Armazenado / Marcado).
func _add_mon_entry(list: PCList, inst: AlchemonInstance, tag := "", tag_color := TAG_STORED, picked := false) -> void:
	var sheet := _sheet_of(inst)
	var accent := UIStyle.type_color(sheet.element_type) if sheet != null else UIStyle.CLEAR

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(_portrait(sheet, inst))

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var name_lbl := Label.new()
	name_lbl.text = _short_name(inst)
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(name_lbl)
	var sub := Label.new()
	sub.text = "Nv.%d" % inst.level
	if sheet != null:
		sub.text += "   %s" % AlchemonType.type_name(sheet.element_type)
	sub.add_theme_font_size_override("font_size", 13)
	sub.modulate.a = 0.7
	v.add_child(sub)

	if picked:
		var mark := UIStyle.chip("MARCADO", GOLD, 12)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(mark)
	elif tag != "":
		var chip := UIStyle.chip(tag, tag_color, 12)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(chip)
	list.add_entry(h, accent, name_lbl)


## Linha de ação simples (Formar Composto, Romper, Voltar...).
func _add_action_entry(list: PCList, text: String, color := TEXT_COLOR) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", color)
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(0, 34)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	list.add_entry(h, color if (color != TEXT_COLOR and color != MUTED) else UIStyle.CLEAR, l)


func _update_card(list: PCList, rows: Array, card: PCStatsCard, inst_key := "inst") -> void:
	if list == null or card == null:
		return
	var sel := list.get_selected_items()
	if sel.is_empty() or sel[0] >= rows.size() or rows[sel[0]].get(inst_key) == null:
		card.clear()
		return
	var inst: AlchemonInstance = rows[sel[0]].get(inst_key)
	card.show_instance(inst, _sheet_of(inst), _short_name(inst))


func _on_st_selected(_i: int) -> void:
	_update_st_stats()


func _st_rows_of(list: PCList) -> Array:
	return _st_party_rows if list == _st_party_list else _st_stored_rows


func _update_st_stats() -> void:
	if _st_focus != null:
		_update_card(_st_focus, _st_rows_of(_st_focus), _st_stats)
	_update_st_action()


## Ação que o E vai executar no item selecionado: enviar / levar / voltar.
func _update_st_action() -> void:
	if _st_action == null or _st_focus == null:
		return
	var sel := _st_focus.get_selected_items()
	var rows := _st_rows_of(_st_focus)
	if sel.is_empty() or sel[0] >= rows.size():
		_action_chip(_st_action, "", MUTED)
		return
	var row: Dictionary = rows[sel[0]]
	match row.src:
		"back":
			_action_chip(_st_action, "[E] Voltar ao menu", MUTED)
		"party":
			if _party().size() <= 1:
				_action_chip(_st_action, "O time precisa de pelo menos 1 Alchemon", MUTED)
			else:
				_action_chip(_st_action, "[E] Enviar %s para o armazenamento" % _short_name(row.inst), SEND_COLOR)
		_:
			if _party().size() >= max_party_size:
				_action_chip(_st_action, "Time cheio: envie um Alchemon para o armazenamento antes", MUTED)
			else:
				_action_chip(_st_action, "[E] Levar %s para o time" % _short_name(row.inst), TAKE_COLOR)


func _st_switch_column(to_stored: bool) -> void:
	var target := _st_stored_list if to_stored else _st_party_list
	if target == _st_focus or target.item_count == 0:
		return
	if target.get_selected_items().is_empty():
		target.select(0)
	target.grab_focus()


func _on_alch_selected(_i: int) -> void:
	_update_card(_alch_list, _alch_rows, _alch_stats)
	_update_alch_action()


func _update_alch_action() -> void:
	if _alch_action == null or _alch_list == null:
		return
	var sel := _alch_list.get_selected_items()
	if sel.is_empty() or sel[0] >= _alch_rows.size():
		_action_chip(_alch_action, "", MUTED)
		return
	var row: Dictionary = _alch_rows[sel[0]]
	match row.kind:
		"mon":
			if _alch_picked.has(row.inst):
				_action_chip(_alch_action, "[E] Desmarcar %s" % _short_name(row.inst), SEND_COLOR)
			else:
				_action_chip(_alch_action, "[E] Marcar %s para o Composto" % _short_name(row.inst), TAKE_COLOR)
		"make":
			_action_chip(_alch_action, "[E] Formar Composto com os selecionados", TAKE_COLOR)
		"break":
			_action_chip(_alch_action, "[E] Romper o Composto atual", SEND_COLOR)
		_:
			_action_chip(_alch_action, "[E] Voltar ao menu", MUTED)


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = PANEL_SIZE
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_style_panel(panel)
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)

	var header := Label.new()
	header.text = "PC ALCHEMON"
	header.add_theme_font_size_override("font_size", 32)
	_gold_label(header)
	outer.add_child(header)
	outer.add_child(HSeparator.new())

	var root := HBoxContainer.new()
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 16)
	outer.add_child(root)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(240, 0)
	root.add_child(left)
	_menu = _make_list()
	for i in OPTIONS.size():
		_add_menu_entry(i)
	_menu.item_selected.connect(_on_menu_selected)
	_menu.item_activated.connect(func(_i): _open_option())
	left.add_child(_framed(_menu))

	var right := Control.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(right)
	_pages["Idle"] = _build_idle_page()
	_pages["Alchemy"] = _build_alchemy_page()
	_pages["Stored"] = _build_stored_page()
	_pages["Exit"] = _build_exit_page()
	for page in _pages.values():
		page.set_anchors_preset(Control.PRESET_FULL_RECT)
		right.add_child(page)

	_hint = Label.new()
	_hint.modulate = Color(1, 1, 1, 0.6)
	_hint.add_theme_color_override("font_color", TEXT_COLOR)
	outer.add_child(_hint)


func _add_menu_entry(i: int) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.custom_minimum_size = Vector2(0, 40)
	var num := UIStyle.chip(str(i + 1), GOLD, 14)
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(num)
	var l := Label.new()
	l.text = OPTION_LABELS[OPTIONS[i]]
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	h.add_child(l)
	_menu.add_entry(h, UIStyle.CLEAR, l)


func _build_idle_page() -> Control:
	var page := PanelContainer.new()
	_style_panel(page)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	page.add_child(v)
	v.add_child(UIStyle.section_label("Sobre esta opção"))
	_idle_label = Label.new()
	_idle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_idle_label.add_theme_color_override("font_color", TEXT_COLOR)
	v.add_child(_idle_label)
	return page


func _build_alchemy_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	_alch_header = Label.new()
	_alch_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_alch_header.add_theme_font_size_override("font_size", 20)
	_gold_label(_alch_header)
	page.add_child(_alch_header)
	var h := Label.new()
	h.text = "Escolha de 2 a %d Alchemons (time + armazenamento) e depois Formar Composto" % AlchemyStation.MAX_BOND_SIZE
	h.modulate = Color(1, 1, 1, 0.55)
	page.add_child(h)

	_alch_list = _make_list()
	_alch_list.item_activated.connect(func(_i): _alchemy_select())
	_alch_list.item_selected.connect(_on_alch_selected)
	_alch_stats = PCStatsCard.new()
	var arow := HBoxContainer.new()
	arow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arow.add_theme_constant_override("separation", 12)
	page.add_child(arow)
	arow.add_child(_framed(_alch_list))
	arow.add_child(_alch_stats)

	_alch_action = Label.new()
	_alch_action.add_theme_font_size_override("font_size", 18)
	page.add_child(_alch_action)
	_alch_info = Label.new()
	_alch_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_alch_info.add_theme_color_override("font_color", GOLD)
	page.add_child(_alch_info)
	return page


func _build_stored_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	_st_stats = PCStatsCard.new()
	var srow := HBoxContainer.new()
	srow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	srow.add_theme_constant_override("separation", 12)
	page.add_child(srow)

	_st_party_list = _make_st_column(srow, ST_TITLE_PARTY)
	_st_party_title = _st_party_list.get_meta("title")
	_st_stored_list = _make_st_column(srow, ST_TITLE_STORED)
	_st_stored_title = _st_stored_list.get_meta("title")
	_st_focus = _st_party_list
	srow.add_child(_st_stats)

	_st_action = Label.new()
	_st_action.add_theme_font_size_override("font_size", 18)
	page.add_child(_st_action)
	_st_info = Label.new()
	_st_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_st_info.add_theme_color_override("font_color", GOLD)
	page.add_child(_st_info)
	return page


func _make_st_column(parent: Control, title: String) -> PCList:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	parent.add_child(col)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 20)
	_gold_label(t)
	col.add_child(t)
	var list := _make_list()
	list.set_meta("title", t)
	list.item_activated.connect(func(_i): _stored_select())
	list.item_selected.connect(_on_st_selected)
	list.focus_entered.connect(func():
		_st_focus = list
		_update_st_stats())
	col.add_child(_framed(list))
	return list


func _build_exit_page() -> Control:
	var page := PanelContainer.new()
	_style_panel(page)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	page.add_child(v)
	var l := Label.new()
	l.text = "Fechar o PC?"
	l.add_theme_font_size_override("font_size", 24)
	_gold_label(l)
	v.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	_exit_yes = Button.new()
	_exit_yes.text = "Sim"
	_exit_yes.pressed.connect(func(): exit_requested.emit())
	_style_button(_exit_yes)
	row.add_child(_exit_yes)
	_exit_no = Button.new()
	_exit_no.text = "Não"
	_exit_no.pressed.connect(_go_list)
	_style_button(_exit_no)
	row.add_child(_exit_no)
	return page


func _input(event: InputEvent) -> void:
	if not _ready_to_input:
		return
	if event is InputEventKey and event.echo:
		return
	if _popup != null:
		get_viewport().set_input_as_handled()
		var pressed: bool = (event is InputEventKey and event.pressed) \
				or (event is InputEventMouseButton and event.pressed) \
				or (event is InputEventJoypadButton and event.pressed)
		if pressed:
			_close_popup()
		return
	if _level == Level.OPTION and _current_option == "Stored":
		if event.is_action_pressed("menu_left"):
			get_viewport().set_input_as_handled()
			_st_switch_column(false)
			return
		if event.is_action_pressed("menu_right"):
			get_viewport().set_input_as_handled()
			_st_switch_column(true)
			return
	if event.is_action_pressed(select_action):
		get_viewport().set_input_as_handled()
		match _level:
			Level.LIST:
				_open_option()
			Level.OPTION:
				_option_select()
	elif event.is_action_pressed(back_action):
		if _level == Level.OPTION:
			get_viewport().set_input_as_handled()
			_go_list()


func _on_menu_selected(index: int) -> void:
	if _level != Level.LIST:
		return
	_idle_label.text = DESCRIPTIONS[OPTIONS[index]]
	_show_page("Idle")


func _open_option() -> void:
	if _level != Level.LIST:
		return
	var sel := _menu.get_selected_items()
	if sel.is_empty():
		return
	_current_option = OPTIONS[sel[0]]
	_level = Level.OPTION
	_menu.focus_mode = Control.FOCUS_NONE
	_menu.release_focus()
	_refresh_all()
	_show_page(_current_option)
	match _current_option:
		"Alchemy":
			_alch_list.grab_focus()
		"Stored":
			_st_focus = _st_party_list
			_st_party_list.grab_focus()
		"Exit":
			_exit_no.grab_focus()
	_hint.text = "Cima/Baixo: mover   E: selecionar   Esc: voltar"
	if _current_option == "Stored":
		_hint.text = "Cima/Baixo: mover   Esq./Dir.: trocar coluna   E: transferir Alchemon   Esc: voltar"


func _go_list() -> void:
	_level = Level.LIST
	_current_option = ""
	_menu.focus_mode = Control.FOCUS_ALL
	_menu.grab_focus()
	var sel := _menu.get_selected_items()
	if sel.is_empty():
		_menu.select(0)
		sel = [0]
	_idle_label.text = DESCRIPTIONS[OPTIONS[sel[0]]]
	_show_page("Idle")
	_hint.text = "Cima/Baixo: mover   E: abrir opção"


func _show_page(page_name: String) -> void:
	for k in _pages:
		_pages[k].visible = (k == page_name)


func _option_select() -> void:
	match _current_option:
		"Alchemy": _alchemy_select()
		"Stored": _stored_select()
		"Exit":
			var f := get_viewport().gui_get_focus_owner()
			if f is Button:
				f.pressed.emit()


func _refresh_all() -> void:
	if _alch_list == null:
		return
	_refresh_alchemy()
	_refresh_stored()


func _has_active_bond() -> bool:
	return _bond != null and _bond.is_active()


func _refresh_alchemy() -> void:
	var keep := _alch_list.get_selected_items()
	_alch_list.clear()
	_alch_rows.clear()
	_alch_header.text = _bond_text()

	if _has_active_bond():
		_alch_picked.clear()
		_alch_rows.append({"kind": "break"})
		if _alch_info.text == "":
			_alch_info.text = "Há um Composto ativo. Rompa-o para formar outro."
	else:
		for inst in _party():
			_alch_rows.append({"kind": "mon", "inst": inst, "tag": "Time"})
		for inst in _stored():
			_alch_rows.append({"kind": "mon", "inst": inst, "tag": "Armazenado"})
		_alch_rows.append({"kind": "make"})
	_alch_rows.append({"kind": "back"})

	for r in _alch_rows:
		match r.kind:
			"mon":
				var tag_color := TAG_PARTY if r.tag == "Time" else TAG_STORED
				_add_mon_entry(_alch_list, r.inst, r.tag, tag_color, _alch_picked.has(r.inst))
			"make":
				_add_action_entry(_alch_list, "Formar Composto  (%d selecionados, 2-%d)" % [_alch_picked.size(), AlchemyStation.MAX_BOND_SIZE], TAKE_COLOR)
			"break":
				_add_action_entry(_alch_list, "Romper Composto", SEND_COLOR)
			"back":
				_add_action_entry(_alch_list, "Voltar", MUTED)

	if _alch_list.item_count > 0:
		_alch_list.select(mini(keep[0] if not keep.is_empty() else 0, _alch_list.item_count - 1))
	_update_card(_alch_list, _alch_rows, _alch_stats)
	_update_alch_action()


func _refresh_stored() -> void:
	var keep_p := _st_party_list.get_selected_items()
	var keep_s := _st_stored_list.get_selected_items()
	_st_party_list.clear()
	_st_stored_list.clear()
	_st_party_rows.clear()
	_st_stored_rows.clear()
	for inst in _party():
		_st_party_rows.append({"src": "party", "inst": inst})
		_add_mon_entry(_st_party_list, inst, "Time", TAG_PARTY)
	_st_party_rows.append({"src": "back", "inst": null})
	_add_action_entry(_st_party_list, "Voltar", MUTED)
	for inst in _stored():
		_st_stored_rows.append({"src": "stored", "inst": inst})
		_add_mon_entry(_st_stored_list, inst, "PC", TAG_STORED)
	_st_party_title.text = "%s  (%d/%d)" % [ST_TITLE_PARTY, _party().size(), max_party_size]
	_st_stored_title.text = "%s  (%d)" % [ST_TITLE_STORED, _stored().size()]
	_st_info.text = "Time: %d/%d   Armazenados: %d" % [_party().size(), max_party_size, _stored().size()]
	_st_party_list.select(mini(keep_p[0] if not keep_p.is_empty() else 0, _st_party_list.item_count - 1))
	if _st_stored_list.item_count > 0:
		_st_stored_list.select(mini(keep_s[0] if not keep_s.is_empty() else 0, _st_stored_list.item_count - 1))
	if _st_focus == _st_stored_list and _st_stored_list.item_count == 0 and _level == Level.OPTION \
			and _current_option == "Stored":
		_st_party_list.grab_focus()
	_update_st_stats()


func _alchemy_select() -> void:
	var sel := _alch_list.get_selected_items()
	if sel.is_empty():
		return
	var row: Dictionary = _alch_rows[sel[0]]
	match row.kind:
		"mon":
			if _alch_picked.has(row.inst):
				_alch_picked.erase(row.inst)
				_alch_info.text = ""
			elif _alch_picked.size() >= AlchemyStation.MAX_BOND_SIZE:
				_alch_info.text = "Máximo de %d. Desmarque um antes." % AlchemyStation.MAX_BOND_SIZE
			else:
				_alch_picked.append(row.inst)
				_alch_info.text = ""
		"make":
			_make_component()
		"break":
			_bond.clear()
			_trim_party()
			_alch_info.text = "Composto rompido."
			party_changed.emit()
			bond_changed.emit()
		"back":
			_go_list()
			return
	_refresh_all()


func _make_component() -> void:
	if _has_active_bond():
		_alch_info.text = "Rompa o Composto atual primeiro."
		return
	if _alch_picked.size() < AlchemyStation.MIN_BOND_SIZE or _alch_picked.size() > AlchemyStation.MAX_BOND_SIZE:
		_alch_info.text = "Selecione de 2 a %d Alchemons." % AlchemyStation.MAX_BOND_SIZE
		return
	if _db == null or _bond == null or _party_data == null or _storage == null:
		_alch_info.text = "Faltam dados do PC (time / armazenamento / vínculo / banco de dados)."
		return

	var sheets: Array[AlchemonSheet] = []
	for inst in _alch_picked:
		sheets.append(_db.get_by_id(inst.species_id))
	if sheets.has(null):
		_alch_info.text = "Espécie desconhecida na seleção."
		return

	var kind := AlchemyStation.determine_bond_kind(sheets)
	if kind == BondRules.NONE:
		_alch_info.text = "Vínculo impossível. " + AlchemyStation.bond_failure_reason(sheets)
		return

	var chosen: Array[AlchemonInstance] = []
	for r in _alch_rows:
		if r.kind == "mon" and _alch_picked.has(r.inst):
			chosen.append(r.inst)

	for inst in _party_data.party.duplicate():
		if not chosen.has(inst):
			_storage.add_instance(inst)
	for inst in chosen:
		if _storage.instances.has(inst):
			_storage.remove_instance(inst)
	_party_data.party.clear()
	for inst in chosen:
		_party_data.party.append(inst)

	var member_indices: Array[int] = []
	var member_names: Array[String] = []
	for i in chosen.size():
		member_indices.append(i)
		member_names.append(_short_name(chosen[i]))
	_bond.set_bond(kind, member_indices)
	var made := "Formado: %s (%s)" % [_kind_label(kind), " + ".join(member_names)]
	if kind == BondRules.COMPOUND:
		var data := AlchemyStation.resolve_compound(sheets)
		if data != null:
			made += "\n%s - %s, ligação %s" % [data.chemical_formula, data.compound_name, data.bond_type_label()]
	_alch_info.text = made
	_alch_picked.clear()
	party_changed.emit()
	bond_changed.emit()
	_show_popup(COMPONENT_CREATED_TEXT)


func _trim_party() -> void:
	while _party_data.party.size() > max_party_size:
		var extra: AlchemonInstance = _party_data.party.pop_back()
		_storage.add_instance(extra)


func _show_popup(text: String) -> void:
	_close_popup()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var panel := PanelContainer.new()
	var box := _box(PANEL_BG, PANEL_BORDER, 8)
	box.content_margin_left = 36
	box.content_margin_right = 36
	box.content_margin_top = 24
	box.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", box)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", TITLE_GOLD)
	v.add_child(l)
	var hint := Label.new()
	hint.text = "(pressione qualquer tecla)"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	v.add_child(hint)
	add_child(root)
	_popup = root


func _close_popup() -> void:
	if _popup != null:
		_popup.queue_free()
		_popup = null


func _stored_select() -> void:
	var sel := _st_focus.get_selected_items()
	if sel.is_empty():
		return
	var row: Dictionary = _st_rows_of(_st_focus)[sel[0]]
	if row.src == "back":
		_go_list()
		return

	if row.src == "party":
		if _party().size() <= 1:
			_st_info.text = "É preciso ter pelo menos 1 Alchemon no time."
			return
		_party_data.party.erase(row.inst)
		_storage.add_instance(row.inst)
	else:
		if _party().size() >= max_party_size:
			_st_info.text = "Time CHEIO (%d/%d). Envie um para o armazenamento antes." % [_party().size(), max_party_size]
			return
		_storage.remove_instance(row.inst)
		_party_data.party.append(row.inst)

	var broke := _bond != null and _bond.is_active()
	if broke:
		_bond.clear()
		_trim_party()
		bond_changed.emit()
	_alch_picked.clear()
	party_changed.emit()
	_refresh_all()
	if broke:
		_st_info.text += "   (Composto rompido: o time mudou)"
