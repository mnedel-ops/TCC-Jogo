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
const DESCRIPTIONS := {
	"Alchemy": "Make the Component (bond).\nPick 2 Alchemons from party + storage.\nThe Component goes into every fight.\nWith an active Component you can only break it.",
	"Stored": "Stored Alchemons.\nSwap captured Alchemons with your party.",
	"Exit": "Close the PC.",
}

var _party_data: PlayerPartyData
var _storage: CapturedStorage
var _bond: PlayerBondData
var _db: AlchemonDatabase

var _level := Level.LIST
var _current_option := ""
var _ready_to_input := false
const COMPONENT_CREATED_TEXT := "Seu Composto foi criado!"
var _popup: Control

var _menu: ItemList
var _pages: Dictionary = {}
var _hint: Label

var _alch_header: Label
var _alch_list: ItemList
var _alch_rows: Array = []
var _alch_picked: Array[AlchemonInstance] = []
var _alch_info: Label

const ST_TITLE_PARTY := "Seu time"
const ST_TITLE_STORED := "Armazenados"
var _st_party_list: ItemList
var _st_stored_list: ItemList
var _st_party_rows: Array = []
var _st_stored_rows: Array = []
var _st_focus: ItemList
var _st_info: Label
var _st_stats: Label
var _alch_stats: Label

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


func _label_of(inst: AlchemonInstance) -> String:
	if inst == null:
		return "(empty)"
	var n := inst.creature_name
	if n == "" and _db != null:
		var sheet := _db.get_by_id(inst.species_id)
		n = sheet.creature_name if sheet != null else "???"
	return "%s  Lv.%d" % [n, inst.level]


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
		BondRules.MIXTURE: return "Mixture"
		BondRules.COMPOUND: return "Compound"
	return "none"


func _bond_text() -> String:
	if _bond == null or not _bond.is_active():
		return "Current Component: none"
	var names: Array[String] = []
	for i in _bond.member_indices:
		if i >= 0 and i < _party().size():
			names.append(_short_name(_party()[i]))
	return "Current Component: %s (%s)" % [_kind_label(_bond.kind), " + ".join(names)]


func _stats_text(inst: AlchemonInstance) -> String:
	if inst == null:
		return ""
	var sheet: AlchemonSheet = _db.get_by_id(inst.species_id) if _db != null else null
	var n := _short_name(inst)
	if sheet == null:
		return "%s\nLv.%d\n(no species data)" % [n, inst.level]

	var iv := inst.individual_value
	var stats := inst.compute_stats(sheet)
	var atk: int = stats.attack
	var def: int = stats.defense
	var spd: int = stats.mechanical_speed
	var en: int = stats.action_energy
	var max_hp: int = stats.max_hp
	var hp := inst.hp_or_full(max_hp)

	return "%s\nLv.%d   (%s)\n\nHP: %d/%d\nXP: %d/%d\nValence e-: %d\n\nAttack: %d\nDefense: %d\nMech. Speed: %d\nAction Energy: %d\nIV: %d" % [
		n, inst.level, AlchemonType.type_name(sheet.element_type),
		hp, max_hp,
		inst.experience, AlchemonGrowth.XP_TO_LEVEL_UP,
		sheet.max_valence_electrons,
		atk, def, spd, en, iv]


func _make_stats_label() -> Label:
	var l := Label.new()
	l.custom_minimum_size = Vector2(230, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return l


func _stats_panel(l: Label) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_child(l)
	return pc


func _update_stats(list: ItemList, rows: Array, label: Label, inst_key := "inst") -> void:
	if list == null or label == null:
		return
	var sel := list.get_selected_items()
	if sel.is_empty() or sel[0] >= rows.size():
		label.text = ""
		return
	var row: Dictionary = rows[sel[0]]
	label.text = _stats_text(row.get(inst_key)) if row.get(inst_key) != null else ""


func _on_st_selected(_i: int) -> void:
	_update_st_stats()


func _st_rows_of(list: ItemList) -> Array:
	return _st_party_rows if list == _st_party_list else _st_stored_rows


func _update_st_stats() -> void:
	if _st_focus != null:
		_update_stats(_st_focus, _st_rows_of(_st_focus), _st_stats)


func _st_switch_column(to_stored: bool) -> void:
	var target := _st_stored_list if to_stored else _st_party_list
	if target == _st_focus or target.item_count == 0:
		return
	if target.get_selected_items().is_empty():
		target.select(0)
	target.grab_focus()


func _on_alch_selected(_i: int) -> void:
	_update_stats(_alch_list, _alch_rows, _alch_stats)


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(900, 520)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)

	var outer := VBoxContainer.new()
	margin.add_child(outer)

	var root := HBoxContainer.new()
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 16)
	outer.add_child(root)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(200, 0)
	root.add_child(left)
	var title := Label.new()
	title.text = "ALCHEMY PC"
	title.add_theme_font_size_override("font_size", 22)
	left.add_child(title)
	_menu = ItemList.new()
	_menu.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in OPTIONS.size():
		_menu.add_item("%d. %s" % [i + 1, OPTIONS[i]])
	_menu.item_selected.connect(_on_menu_selected)
	_menu.item_activated.connect(func(_i): _open_option())
	left.add_child(_menu)

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
	outer.add_child(_hint)


func _build_idle_page() -> Control:
	var page := VBoxContainer.new()
	_idle_label = Label.new()
	_idle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_idle_label)
	return page


func _build_alchemy_page() -> Control:
	var page := VBoxContainer.new()
	_alch_header = Label.new()
	_alch_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_alch_header)
	var h := Label.new()
	h.text = "Pick 2 Alchemons (party + storage), then Make Component"
	page.add_child(h)
	_alch_list = ItemList.new()
	_alch_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_alch_list.item_activated.connect(func(_i): _alchemy_select())
	_alch_list.item_selected.connect(_on_alch_selected)
	_alch_stats = _make_stats_label()
	var arow := HBoxContainer.new()
	arow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arow.add_theme_constant_override("separation", 12)
	page.add_child(arow)
	arow.add_child(_alch_list)
	_alch_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arow.add_child(_stats_panel(_alch_stats))
	_alch_info = Label.new()
	_alch_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_alch_info)
	return page


func _build_stored_page() -> Control:
	var page := VBoxContainer.new()
	_st_stats = _make_stats_label()
	var srow := HBoxContainer.new()
	srow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	srow.add_theme_constant_override("separation", 12)
	page.add_child(srow)

	_st_party_list = _make_st_column(srow, ST_TITLE_PARTY)
	_st_stored_list = _make_st_column(srow, ST_TITLE_STORED)
	_st_focus = _st_party_list
	srow.add_child(_stats_panel(_st_stats))

	_st_info = Label.new()
	_st_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_st_info)
	return page


func _make_st_column(parent: Control, title: String) -> ItemList:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(col)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var list := ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_activated.connect(func(_i): _stored_select())
	list.item_selected.connect(_on_st_selected)
	list.focus_entered.connect(func():
		_st_focus = list
		_update_st_stats())
	col.add_child(list)
	return list


func _build_exit_page() -> Control:
	var page := VBoxContainer.new()
	var l := Label.new()
	l.text = "Close the PC?"
	l.add_theme_font_size_override("font_size", 20)
	page.add_child(l)
	var row := HBoxContainer.new()
	page.add_child(row)
	_exit_yes = Button.new()
	_exit_yes.text = "Yes"
	_exit_yes.pressed.connect(func(): exit_requested.emit())
	row.add_child(_exit_yes)
	_exit_no = Button.new()
	_exit_no.text = "No"
	_exit_no.pressed.connect(_go_list)
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
	_hint.text = "Up/Down: move   [%s]: select   [%s]: back" % [select_action, back_action]
	if _current_option == "Stored":
		_hint.text = "Up/Down: move   Left/Right: change column   [%s]: move Alchemon   [%s]: back" % [select_action, back_action]


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
	_hint.text = "Up/Down: move   [%s]: open option" % select_action


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
			_alch_info.text = "A Component is active. Break it to make a new one."
	else:
		for inst in _party():
			_alch_rows.append({"kind": "mon", "inst": inst, "tag": "Party"})
		for inst in _stored():
			_alch_rows.append({"kind": "mon", "inst": inst, "tag": "Stored"})
		_alch_rows.append({"kind": "make"})
	_alch_rows.append({"kind": "back"})

	for r in _alch_rows:
		match r.kind:
			"mon":
				var mark := "[x]" if _alch_picked.has(r.inst) else "[ ]"
				_alch_list.add_item("%s [%s] %s" % [mark, r.tag, _label_of(r.inst)])
			"make":
				_alch_list.add_item(">> Make Component (%d/2 selected)" % _alch_picked.size())
			"break":
				_alch_list.add_item("xx Break Component")
			"back":
				_alch_list.add_item("<< Back")

	if _alch_list.item_count > 0:
		_alch_list.select(mini(keep[0] if not keep.is_empty() else 0, _alch_list.item_count - 1))
	_update_stats(_alch_list, _alch_rows, _alch_stats)


func _refresh_stored() -> void:
	var keep_p := _st_party_list.get_selected_items()
	var keep_s := _st_stored_list.get_selected_items()
	_st_party_list.clear()
	_st_stored_list.clear()
	_st_party_rows.clear()
	_st_stored_rows.clear()
	for inst in _party():
		_st_party_rows.append({"src": "party", "inst": inst})
		_st_party_list.add_item(_label_of(inst))
	_st_party_rows.append({"src": "back", "inst": null})
	_st_party_list.add_item("<< Back")
	for inst in _stored():
		_st_stored_rows.append({"src": "stored", "inst": inst})
		_st_stored_list.add_item(_label_of(inst))
	_st_info.text = "Party: %d/%d   Stored: %d" % [_party().size(), max_party_size, _stored().size()]
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
			elif _alch_picked.size() >= 2:
				_alch_info.text = "Max 2. Unselect one first."
			else:
				_alch_picked.append(row.inst)
				_alch_info.text = ""
		"make":
			_make_component()
		"break":
			_bond.clear()
			_alch_info.text = "Component broken."
			bond_changed.emit()
		"back":
			_go_list()
			return
	_refresh_all()


func _make_component() -> void:
	if _has_active_bond():
		_alch_info.text = "Break the current Component first."
		return
	if _alch_picked.size() != 2:
		_alch_info.text = "Select exactly 2 Alchemons."
		return
	if _db == null or _bond == null or _party_data == null or _storage == null:
		_alch_info.text = "PC data missing (party / storage / bond / database)."
		return

	var sheets: Array[AlchemonSheet] = []
	for inst in _alch_picked:
		sheets.append(_db.get_by_id(inst.species_id))
	if sheets.has(null):
		_alch_info.text = "Unknown species in selection."
		return

	var kind := AlchemyStation.determine_bond_kind(sheets)
	if kind == BondRules.NONE:
		_alch_info.text = "Impossible bond. These two cannot form a Component."
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

	_bond.set_bond(kind, [0, 1])
	_alch_info.text = "Made: %s (%s + %s)" % [_kind_label(kind), _short_name(chosen[0]), _short_name(chosen[1])]
	_alch_picked.clear()
	party_changed.emit()
	bond_changed.emit()
	_show_popup(COMPONENT_CREATED_TEXT)


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
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.97, 0.97, 0.94)
	box.border_color = Color(0.1, 0.1, 0.12)
	box.set_border_width_all(3)
	box.set_corner_radius_all(12)
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
	l.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1))
	v.add_child(l)
	var hint := Label.new()
	hint.text = "(pressione qualquer tecla)"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
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
			_st_info.text = "Need at least 1 Alchemon in party."
			return
		_party_data.party.erase(row.inst)
		_storage.add_instance(row.inst)
	else:
		if _party().size() >= max_party_size:
			_st_info.text = "Party FULL (%d/%d). Send one to Stored first." % [_party().size(), max_party_size]
			return
		_storage.remove_instance(row.inst)
		_party_data.party.append(row.inst)

	var broke := _bond != null and _bond.is_active()
	if broke:
		_bond.clear()
		bond_changed.emit()
	_alch_picked.clear()
	party_changed.emit()
	_refresh_all()
	if broke:
		_st_info.text += "   (Component broken: party changed)"
