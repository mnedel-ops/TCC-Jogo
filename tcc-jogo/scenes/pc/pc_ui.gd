class_name PCUI
extends CanvasLayer
## PC interface, 2 levels:
##  1) Option list: Alchemy / Stored / Exit  (up/down to move)
##  2) Option menu: opens with "menu_interact". "ui_cancel" goes back.
## Every select inside menus also uses "menu_interact".

signal exit_requested
## Player pick Alchemons + "Make Component" row. Hook your recipe logic here.
signal craft_requested(selected: Array)
signal party_changed

@export var select_action: StringName = &"menu_interact"
@export var back_action: StringName = &"ui_cancel"
@export var party_property: StringName = &"party"
@export var stored_property: StringName = &"stored_alchemons"
@export var max_party_size := 6

enum Level { LIST, OPTION }

const OPTIONS := ["Alchemy", "Stored", "Exit"]
const DESCRIPTIONS := {
	"Alchemy": "Component manager.\nUse Alchemons from party and storage to make Components.",
	"Stored": "Stored Alchemons.\nSwap captured Alchemons with your party.",
	"Exit": "Close the PC.",
}

var _player: Node = null
var _party: Array = []
var _stored: Array = []
var _level := Level.LIST
var _current_option := ""
var _ready_to_input := false

var _menu: ItemList
var _pages: Dictionary = {}
var _hint: Label

# Alchemy
var _alch_list: ItemList
var _alch_rows: Array = []        # {"kind": "mon"/"craft", "ref": Variant}
var _alch_picked: Dictionary = {} # row index -> true
var _alch_info: Label

# Stored
var _st_list: ItemList
var _st_rows: Array = []          # {"src": "party"/"stored", "idx": int}
var _st_info: Label

# Exit
var _exit_yes: Button
var _exit_no: Button

# Idle (description)
var _idle_label: Label


func setup(player: Node) -> void:
	_player = player
	_load_data()
	_refresh_all()


func _ready() -> void:
	layer = 10
	for a in [select_action, back_action]:
		if not InputMap.has_action(a):
			push_warning("PCUI: InputMap missing action '%s'" % a)
	_build_ui()
	if _party.is_empty() and _stored.is_empty():
		_load_data()
	_refresh_all()
	_menu.select(0)
	_on_menu_selected(0)
	_go_list()
	# Ignore input for 1 frame: the key that opened the PC must not select.
	await get_tree().process_frame
	_ready_to_input = true


# ---------- data ----------

func _load_data() -> void:
	var p = _player.get(party_property) if _player else null
	var s = _player.get(stored_property) if _player else null
	if p is Array and s is Array:
		_party = p
		_stored = s
	else:
		push_warning("PCUI: player lacks '%s'/'%s'. Using demo data." % [party_property, stored_property])
		_party = [{"name": "Flamling"}, {"name": "Aquaby"}]
		_stored = [{"name": "Leafox"}, {"name": "Rockit"}, {"name": "Voltik"}]


func _name_of(a) -> String:
	if a is Dictionary:
		return str(a.get("name", "???"))
	if a is Object:
		var n = a.get("name")
		if n == null:
			n = a.get("alchemon_name")
		return str(n) if n != null else "???"
	return str(a)


# ---------- build ----------

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

	# Menu 1: option list
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

	# Menu 2: option pages
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
	var h := Label.new()
	h.text = "Alchemy - pick Alchemons to make a Component"
	page.add_child(h)
	_alch_list = ItemList.new()
	_alch_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_alch_list.item_activated.connect(func(_i): _alchemy_select())
	page.add_child(_alch_list)
	_alch_info = Label.new()
	page.add_child(_alch_info)
	return page


func _build_stored_page() -> Control:
	var page := VBoxContainer.new()
	var h := Label.new()
	h.text = "Stored - select to swap between Party and Stored"
	page.add_child(h)
	_st_list = ItemList.new()
	_st_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_st_list.item_activated.connect(func(_i): _stored_select())
	page.add_child(_st_list)
	_st_info = Label.new()
	page.add_child(_st_info)
	return page


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


# ---------- levels ----------

func _input(event: InputEvent) -> void:
	if not _ready_to_input:
		return
	if event is InputEventKey and event.echo:
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
	# Highlight only. Never opens anything.
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
			_st_list.grab_focus()
		"Exit":
			_exit_no.grab_focus() # safe default: No
	_hint.text = "Up/Down: move   [%s]: select   [%s]: back" % [select_action, back_action]


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


# ---------- refresh ----------

func _refresh_all() -> void:
	if _alch_list == null:
		return
	_refresh_alchemy()
	_refresh_stored()


func _refresh_alchemy() -> void:
	var keep := _alch_list.get_selected_items()
	_alch_list.clear()
	_alch_rows.clear()
	for a in _party:
		_alch_rows.append({"kind": "mon", "ref": a, "tag": "Party"})
	for a in _stored:
		_alch_rows.append({"kind": "mon", "ref": a, "tag": "Stored"})
	_alch_rows.append({"kind": "craft"})
	for i in _alch_rows.size():
		var r: Dictionary = _alch_rows[i]
		if r.kind == "mon":
			var mark := "[x]" if _alch_picked.has(i) else "[ ]"
			_alch_list.add_item("%s %s - %s" % [mark, r.tag, _name_of(r.ref)])
		else:
			_alch_list.add_item(">> Make Component (%d selected)" % _alch_picked.size())
	if not keep.is_empty():
		_alch_list.select(mini(keep[0], _alch_list.item_count - 1))
	elif _alch_list.item_count > 0:
		_alch_list.select(0)


func _refresh_stored() -> void:
	var keep := _st_list.get_selected_items()
	_st_list.clear()
	_st_rows.clear()
	for i in _party.size():
		_st_rows.append({"src": "party", "idx": i})
		_st_list.add_item("[Party]  " + _name_of(_party[i]))
	for i in _stored.size():
		_st_rows.append({"src": "stored", "idx": i})
		_st_list.add_item("[Stored] " + _name_of(_stored[i]))
	_st_info.text = "Party: %d/%d   Stored: %d" % [_party.size(), max_party_size, _stored.size()]
	if _st_list.item_count > 0:
		_st_list.select(mini(keep[0] if not keep.is_empty() else 0, _st_list.item_count - 1))


# ---------- actions ----------

func _alchemy_select() -> void:
	var sel := _alch_list.get_selected_items()
	if sel.is_empty():
		return
	var i: int = sel[0]
	var row: Dictionary = _alch_rows[i]
	if row.kind == "mon":
		if _alch_picked.has(i):
			_alch_picked.erase(i)
		else:
			_alch_picked[i] = true
		_alch_info.text = ""
	else:
		if _alch_picked.is_empty():
			_alch_info.text = "Select at least 1 Alchemon first."
		else:
			var picked: Array = []
			for k in _alch_picked:
				picked.append(_alch_rows[k].ref)
			if _player and _player.has_method("craft_component"):
				_player.craft_component(picked)
			craft_requested.emit(picked)
			_alch_picked.clear()
			_alch_info.text = "Component request sent."
	_refresh_all()


func _stored_select() -> void:
	var sel := _st_list.get_selected_items()
	if sel.is_empty():
		return
	var row: Dictionary = _st_rows[sel[0]]
	if row.src == "party":
		if _party.size() <= 1:
			_st_info.text = "Need at least 1 Alchemon in party."
			return
		var a = _party[row.idx]
		_party.remove_at(row.idx)
		_stored.append(a)
	else:
		if _party.size() >= max_party_size:
			_st_info.text = "Party FULL (%d/%d)" % [_party.size(), max_party_size]
			return
		var b = _stored[row.idx]
		_stored.remove_at(row.idx)
		_party.append(b)
	_alch_picked.clear()
	party_changed.emit()
	_refresh_all()
