class_name BattleCommands
extends Control

## Horizontal command bar (top left): Attack | Item | Flee | "who you are ordering".
## Cursor icon expands to show its name. Activating it opens a vertical dropdown
## under that icon. Attack / Item rows open a SECOND dropdown (targets) to the right,
## starting at the chosen row. Pure UI: gets plain Dictionaries, emits signals,
## knows no combat rules.
##
## Keys: left/right = icon, down/interact = open, up/down = row, interact = pick,
## left / ui_cancel / up on first row = back one level.
## Mouse: hover icon, click icon, hover + click rows.

signal attack_confirmed(attack_index: int, target_id: int)
signal item_confirmed(item_index: int, target_id: int)
signal flee_confirmed
## Combatant under the target cursor. -1 = none (list closed / picked).
signal target_hovered(target_id: int)

signal capture_confirmed(item_index: int, target_id: int)

enum Cmd { ATTACK, ITEM, FLEE }
enum Mode { LOCKED, ICONS, DROPDOWN, TARGET }

const ICON_SHEET := "res://INTERFACES/assets/comandos.png"
const CMD_NAMES: Array[String] = ["Ataque", "Item", "Fugir"]

## Where each icon sits inside comandos.png (229x169). Tweak if the crop is off.
@export var attack_icon_region := Rect2(6, 6, 98, 84)
@export var item_icon_region := Rect2(78, 66, 80, 90)
@export var flee_icon_region := Rect2(136, 18, 90, 86)
@export var icon_size := Vector2(56, 56)
@export var screen_margin := Vector2(16, 16)
@export var name_expand_time := 0.12

## One vertical list (panel + selectable rows + what each row does).
class DropList:
	var panel: PanelContainer
	var rows: Array[PanelContainer] = []
	var callbacks: Array[Callable] = []
	var cursor := 0

var _mode: Mode = Mode.LOCKED
var _cursor: int = Cmd.ATTACK     # highlighted icon
var _open_cmd: int = -1           # icon whose dropdown is open

var _actor_name := ""
var _attacks: Array = []          # [{name, damage, type}]
var _items: Array = []            # [{index, name, effect}]
var _enemy_targets: Array = []    # [{id, name, hp, max_hp, type}]  (attack targets)
var _ally_targets: Array = []     # same shape                       (item targets)

var _pending_kind := ""           # "attack" | "item" while the target list is open
var _pending_index := -1

var _bar: PanelContainer
var _slots: Array[PanelContainer] = []
var _name_labels: Array[Label] = []
var _actor_label: Label
var _menu: DropList               # level 0: attacks / items / flee confirm
var _targets: DropList            # level 1: targets, right of _menu


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = screen_margin
	_build_bar()
	hide_menu()


# ---------------------------------------------------------------- public API

## Show the bar for one actor. Same actor again keeps the cursor.
func open_for(actor_name: String, attacks: Array, items: Array,
		enemy_targets: Array, ally_targets: Array) -> void:
	if actor_name != _actor_name:
		_cursor = Cmd.ATTACK
	_actor_name = actor_name
	_attacks = attacks
	_items = items
	_enemy_targets = enemy_targets
	_ally_targets = ally_targets
	_actor_label.text = "Ordem: %s" % actor_name
	_close_menu()
	visible = true
	modulate.a = 1.0
	_mode = Mode.ICONS
	_refresh_cursor()


## Keep bar visible but dimmed and deaf to input.
func lock() -> void:
	_close_menu()
	_mode = Mode.LOCKED
	modulate.a = 0.55
	_refresh_cursor()


func hide_menu() -> void:
	_close_menu()
	_mode = Mode.LOCKED
	visible = false


# ------------------------------------------------------------------ building

func _build_bar() -> void:
	_bar = PanelContainer.new()
	_bar.add_theme_stylebox_override("panel", _box(Color(0.07, 0.07, 0.11, 0.9), Color(0.5, 0.5, 0.6), 8))
	add_child(_bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	_bar.add_child(hbox)

	var sheet := load(ICON_SHEET) as Texture2D
	if sheet == null:
		push_warning("BattleCommands: %s not found." % ICON_SHEET)
	var regions := [attack_icon_region, item_icon_region, flee_icon_region]

	for i in CMD_NAMES.size():
		var slot := PanelContainer.new()
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 6))

		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(h)

		var icon := TextureRect.new()
		icon.custom_minimum_size = icon_size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if sheet != null:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = regions[i]
			icon.texture = atlas
		h.add_child(icon)

		var lbl := Label.new()
		lbl.text = CMD_NAMES[i]
		lbl.clip_text = true                       # width 0 = collapsed
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(lbl)

		slot.mouse_entered.connect(_on_slot_hover.bind(i))
		slot.gui_input.connect(_on_slot_gui_input.bind(i))
		hbox.add_child(slot)
		_slots.append(slot)
		_name_labels.append(lbl)

	var gap := Control.new()
	gap.custom_minimum_size.x = 16
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(gap)

	_actor_label = Label.new()                     # end of the bar: who is ordering
	_actor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_actor_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	hbox.add_child(_actor_label)


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


# -------------------------------------------------------------------- cursor

func _refresh_cursor() -> void:
	for i in _slots.size():
		var on := (i == _cursor and _mode != Mode.LOCKED)
		_slots[i].add_theme_stylebox_override("panel", _box(
			Color(1, 0.85, 0.2, 0.18) if on else Color(0, 0, 0, 0),
			Color(1, 0.85, 0.2) if on else Color(0, 0, 0, 0), 6))
		_set_name_width(i, _text_width(_name_labels[i]) if on else 0.0)


func _text_width(lbl: Label) -> float:
	var font := lbl.get_theme_font("font")
	return font.get_string_size(lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, lbl.get_theme_font_size("font_size")).x + 6.0


func _set_name_width(i: int, width: float) -> void:
	create_tween().tween_property(_name_labels[i], "custom_minimum_size:x", width, name_expand_time)


func _move_cursor(delta: int) -> void:
	_cursor = wrapi(_cursor + delta, 0, _slots.size())
	_refresh_cursor()


# ------------------------------------------------------- level 0: main dropdown

func _open_menu(cmd: int) -> void:
	_close_menu()
	_cursor = cmd
	_open_cmd = cmd
	match cmd:
		Cmd.ATTACK:
			var rows: Array = []
			for i in _attacks.size():
				var a: Dictionary = _attacks[i]
				rows.append({"cells": [a.name, str(a.damage), a.type],
					"callback": _open_targets.bind("attack", i)})
			if rows.is_empty():
				rows.append({"cells": ["Sem ataques", "", ""], "enabled": false})
			_menu = _build_list("", ["Nome", "Dano", "Tipo"], rows, [170, 70, 100], 0)
		Cmd.ITEM:
			var rows: Array = []
			for it in _items:
				var kind := "capture" if it.get("capture", false) else "item"
				rows.append({"cells": [it.name, it.effect],
					"callback": _open_targets.bind(kind, it.index)})
			if rows.is_empty():
				rows.append({"cells": ["Sem itens", ""], "enabled": false})
			_menu = _build_list("", ["Nome", "Efeito"], rows, [180, 300], 0)
		Cmd.FLEE:
			_menu = _build_list("Fugir do combate?", [], [
				{"cells": ["Sim"], "callback": _pick_flee},
				{"cells": ["Nao"], "callback": _cancel_menu},
			], [160], 0)
			_menu.cursor = 1                        # default on "Nao": double-tap can't flee
			_refresh_rows(_menu)
	_mode = Mode.DROPDOWN
	_refresh_cursor()


func _close_menu() -> void:
	_close_targets()
	if _menu != null and is_instance_valid(_menu.panel):
		_menu.panel.queue_free()
	_menu = null
	_open_cmd = -1
	if _mode == Mode.DROPDOWN or _mode == Mode.TARGET:
		_mode = Mode.ICONS


func _cancel_menu() -> void:
	_close_menu()
	_refresh_cursor()


func _activate_menu() -> void:
	if _menu != null and _menu.cursor < _menu.callbacks.size():
		_menu.callbacks[_menu.cursor].call()


func _pick_flee() -> void:
	lock()
	flee_confirmed.emit()


# ------------------------------------------------------ level 1: target dropdown

## Opens to the right of the main dropdown, top aligned with the chosen row.
func _open_targets(kind: String, index: int) -> void:
	_close_targets()
	_pending_kind = kind
	_pending_index = index

	var list: Array = _ally_targets if kind == "item" else _enemy_targets
	var rows: Array = []
	for t in list:
		rows.append({
			"cells": [t.name, "%d/%d" % [t.hp, t.max_hp], t.type],
			"callback": _confirm_target.bind(t.id),
			"id": t.id,
		})
	if rows.is_empty():
		rows.append({"cells": ["Sem alvos", "", ""], "enabled": false})

	_targets = _build_list("", ["Nome", "HP", "Tipo"], rows, [170, 80, 100], 1)
	_mode = Mode.TARGET
	_emit_target_hover()


func _close_targets() -> void:
	if _targets != null:
		if is_instance_valid(_targets.panel):
			_targets.panel.queue_free()
		_targets = null
		target_hovered.emit(-1)
	if _mode == Mode.TARGET:
		_mode = Mode.DROPDOWN


func _activate_target() -> void:
	if _targets != null and _targets.cursor < _targets.callbacks.size():
		_targets.callbacks[_targets.cursor].call()


func _confirm_target(target_id: int) -> void:
	var kind := _pending_kind
	var index := _pending_index
	lock()                                          # closes lists + clears highlight
	match kind:
		"attack":
			attack_confirmed.emit(index, target_id)
		"capture":
			capture_confirmed.emit(index, target_id)
		_:
			item_confirmed.emit(index, target_id)


var _target_ids: Array[int] = []                    # id of each selectable target row

func _emit_target_hover() -> void:
	if _targets == null or _targets.cursor >= _target_ids.size():
		target_hovered.emit(-1)
		return
	target_hovered.emit(_target_ids[_targets.cursor])


# ------------------------------------------------------------ list building

## level 0 = main dropdown, 1 = target dropdown.
func _build_list(title: String, header: Array, rows: Array, widths: Array, level: int) -> DropList:
	var list := DropList.new()
	list.panel = PanelContainer.new()
	list.panel.modulate.a = 0.0                     # shown by _process once positioned
	list.panel.add_theme_stylebox_override("panel", _box(Color(0.07, 0.07, 0.11, 0.94), Color(0.5, 0.5, 0.6), 8))
	add_child(list.panel)

	var v := VBoxContainer.new()
	list.panel.add_child(v)

	if title != "":
		var t := Label.new()
		t.text = title
		t.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		v.add_child(t)

	if not header.is_empty():
		var h := _make_row(header, widths)
		h.modulate = Color(1, 1, 1, 0.55)           # dim header, not selectable
		v.add_child(h)

	if level == 1:
		_target_ids.clear()
	for r in rows:
		var enabled: bool = r.get("enabled", true)
		var row := _make_row(r.cells, widths)
		if enabled:
			var my_index := list.rows.size()
			row.mouse_filter = Control.MOUSE_FILTER_STOP
			row.mouse_entered.connect(_on_row_hover.bind(level, my_index))
			row.gui_input.connect(_on_row_gui_input.bind(level, my_index))
			list.rows.append(row)
			list.callbacks.append(r.callback)
			if level == 1:
				_target_ids.append(r.id)
		else:
			row.modulate = Color(1, 1, 1, 0.4)
		v.add_child(row)

	_refresh_rows(list)
	return list


func _make_row(cells: Array, widths: Array) -> PanelContainer:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4))
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	for i in cells.size():
		var lbl := Label.new()
		lbl.text = str(cells[i])
		lbl.custom_minimum_size.x = widths[i] if i < widths.size() else 80
		lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(lbl)
	return row


func _refresh_rows(list: DropList) -> void:
	for i in list.rows.size():
		var on := (i == list.cursor)
		list.rows[i].add_theme_stylebox_override("panel", _box(
			Color(1, 0.85, 0.2, 0.25) if on else Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4))


func _move_row(list: DropList, delta: int) -> void:
	if list.rows.is_empty():
		return
	list.cursor = clampi(list.cursor + delta, 0, list.rows.size() - 1)
	_refresh_rows(list)


## Main dropdown: left edge of its icon, under the bar.
## Target dropdown: right of the main one, top = chosen row's top.
func _process(_delta: float) -> void:
	if _menu != null and is_instance_valid(_menu.panel) and _open_cmd >= 0:
		var slot := _slots[_open_cmd]
		_menu.panel.position = Vector2(
			slot.global_position.x - global_position.x,
			_bar.size.y + 4.0)
		_menu.panel.modulate.a = 1.0

		if _targets != null and is_instance_valid(_targets.panel) \
				and _menu.cursor < _menu.rows.size():
			var chosen := _menu.rows[_menu.cursor]
			_targets.panel.position = Vector2(
				_menu.panel.position.x + _menu.panel.size.x + 6.0,
				chosen.global_position.y - global_position.y)
			_targets.panel.modulate.a = 1.0


# --------------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _mode == Mode.LOCKED:
		return

	match _mode:
		Mode.ICONS:
			if event.is_action_pressed("menu_left"):
				_move_cursor(-1)
			elif event.is_action_pressed("menu_right"):
				_move_cursor(1)
			elif event.is_action_pressed("menu_interact") or event.is_action_pressed("menu_down"):
				_open_menu(_cursor)
			else:
				return
		Mode.DROPDOWN:
			if event.is_action_pressed("menu_down"):
				_move_row(_menu, 1)
			elif event.is_action_pressed("menu_up"):
				if _menu.cursor == 0:
					_cancel_menu()                  # up past first row = back to icons
				else:
					_move_row(_menu, -1)
			elif event.is_action_pressed("menu_left"):
				_move_cursor(-1)
				_open_menu(_cursor)
			elif event.is_action_pressed("menu_right"):
				_move_cursor(1)
				_open_menu(_cursor)
			elif event.is_action_pressed("menu_interact"):
				_activate_menu()
			elif event.is_action_pressed("ui_cancel"):
				_cancel_menu()
			else:
				return
		Mode.TARGET:
			if event.is_action_pressed("menu_down"):
				_move_row(_targets, 1)
				_emit_target_hover()
			elif event.is_action_pressed("menu_up"):
				if _targets.cursor == 0:
					_close_targets()                # back to the attack/item list
				else:
					_move_row(_targets, -1)
					_emit_target_hover()
			elif event.is_action_pressed("menu_left") or event.is_action_pressed("ui_cancel"):
				_close_targets()
			elif event.is_action_pressed("menu_interact"):
				_activate_target()
			else:
				return
	get_viewport().set_input_as_handled()


func _on_slot_hover(i: int) -> void:
	if _mode != Mode.ICONS:
		return
	_cursor = i
	_refresh_cursor()


func _on_slot_gui_input(event: InputEvent, i: int) -> void:
	if _mode == Mode.LOCKED:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _open_cmd == i:
			_cancel_menu()                          # click again = close
		else:
			_open_menu(i)


func _on_row_hover(level: int, row_index: int) -> void:
	if level == 0 and _mode == Mode.DROPDOWN:
		_menu.cursor = row_index
		_refresh_rows(_menu)
	elif level == 1 and _mode == Mode.TARGET:
		_targets.cursor = row_index
		_refresh_rows(_targets)
		_emit_target_hover()


func _on_row_gui_input(event: InputEvent, level: int, row_index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if level == 0 and (_mode == Mode.DROPDOWN or _mode == Mode.TARGET):
		_menu.cursor = row_index                    # also lets you switch row while targets are open
		_refresh_rows(_menu)
		_activate_menu()
	elif level == 1 and _mode == Mode.TARGET:
		_targets.cursor = row_index
		_activate_target()
