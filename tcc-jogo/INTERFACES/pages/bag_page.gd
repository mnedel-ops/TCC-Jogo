class_name BagPage
extends MenuPage

## Bag page: item list (left) + selected item detail (right).
## Data comes from InventoryData + ItemDatabase. Refreshes live on
## InventoryData.changed. Pure UI: item_activated is the hook for "use item".
##
## Keys: menu_up / menu_down = row, menu_interact = activate,
## menu_left = back to menu list.  Mouse: hover = select, click = activate.

signal item_activated(item_index: int)

const GOLD := Color(1, 0.85, 0.2)
const PANEL_BG := Color(0.07, 0.07, 0.11, 0.94)
const PANEL_BORDER := Color(0.5, 0.5, 0.6)

@export var mochila: InventoryData
@export var inventory_database: ItemDatabase
@export var icon_size := Vector2(36, 36)
@export var detail_icon_size := Vector2(112, 112)

var _stacks: Array[Dictionary] = []
var _rows: Array[PanelContainer] = []
var _cursor := 0

var _count_label: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _empty_label: Label
var _detail_box: VBoxContainer
var _detail_icon_holder: Control
var _detail_name: Label
var _detail_qty: Label
var _detail_desc: Label


func _ready() -> void:      # no super: no placeholder
	if mochila == null:
		mochila = load("res://DATABASE/Inventory/inventory.tres")
	if inventory_database == null:
		inventory_database = load("res://DATABASE/Inventory/ItemDatabase.tres")
	_build()
	refresh()


# --------------------------------------------------------------- MenuPage API

func on_open() -> void:
	if mochila != null and not mochila.changed.is_connected(refresh):
		mochila.changed.connect(refresh)
	_cursor = 0
	refresh()


func on_close() -> void:
	if mochila != null and mochila.changed.is_connected(refresh):
		mochila.changed.disconnect(refresh)


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("menu_down"):
		_move_cursor(1)
	elif event.is_action_pressed("menu_up"):
		_move_cursor(-1)
	elif event.is_action_pressed("menu_interact"):
		_activate(_cursor)
	elif event.is_action_pressed("menu_left"):
		back_requested.emit()
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

	# header
	var header := HBoxContainer.new()
	root.add_child(header)
	var title_lbl := Label.new()
	title_lbl.text = "Mochila"
	title_lbl.add_theme_font_size_override("font_size", 32)
	title_lbl.add_theme_color_override("font_color", GOLD)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)
	_count_label = Label.new()
	_count_label.modulate.a = 0.7
	header.add_child(_count_label)
	root.add_child(HSeparator.new())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	# left: list
	var list_panel := PanelContainer.new()
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_panel.size_flags_stretch_ratio = 1.3
	list_panel.add_theme_stylebox_override("panel", _box(PANEL_BG, PANEL_BORDER, 8))
	body.add_child(list_panel)

	var list_stack := Control.new()
	list_panel.add_child(list_stack)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	list_stack.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	_scroll.add_child(_list)

	_empty_label = Label.new()
	_empty_label.text = "Mochila vazia"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.modulate.a = 0.6
	_empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_stack.add_child(_empty_label)

	# right: detail
	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", _box(PANEL_BG, PANEL_BORDER, 8))
	body.add_child(detail_panel)

	_detail_box = VBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", 10)
	detail_panel.add_child(_detail_box)

	_detail_icon_holder = CenterContainer.new()
	_detail_box.add_child(_detail_icon_holder)

	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", 28)
	_detail_name.add_theme_color_override("font_color", GOLD)
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_box.add_child(_detail_name)

	_detail_qty = Label.new()
	_detail_qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_qty.modulate.a = 0.7
	_detail_box.add_child(_detail_qty)

	_detail_box.add_child(HSeparator.new())

	_detail_desc = Label.new()
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_box.add_child(_detail_desc)


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


## Texture if item has icone, else box with first letter.
func _make_icon(data: ItemData, size: Vector2, fallback_name: String) -> Control:
	if data != null and data.icone != null:
		var tex := TextureRect.new()
		tex.texture = data.icone
		tex.custom_minimum_size = size
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tex
	var box := PanelContainer.new()
	box.custom_minimum_size = size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_stylebox_override("panel", _box(Color(0.2, 0.2, 0.28), PANEL_BORDER, 6))
	var l := Label.new()
	l.text = fallback_name.left(1)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(size.y * 0.5))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	return box


# ------------------------------------------------------------------- refresh

func refresh() -> void:
	var previous_index := -1
	if _cursor >= 0 and _cursor < _stacks.size():
		previous_index = _stacks[_cursor].index

	if mochila == null:
		_stacks.clear()
	else:
		_stacks = mochila.get_stacked_view(inventory_database)

	# keep cursor on same item if still there
	_cursor = clampi(_cursor, 0, maxi(_stacks.size() - 1, 0))
	for i in _stacks.size():
		if _stacks[i].index == previous_index:
			_cursor = i
			break

	for row in _rows:
		_list.remove_child(row)
		row.queue_free()
	_rows.clear()

	for i in _stacks.size():
		var row := _make_row(i, _stacks[i])
		_list.add_child(row)
		_rows.append(row)

	var total := mochila.items.size() if mochila != null else 0
	_count_label.text = "%d %s" % [total, "item" if total == 1 else "itens"]
	_empty_label.visible = _stacks.is_empty()
	_detail_box.visible = not _stacks.is_empty()
	_refresh_cursor()


func _make_row(i: int, stack: Dictionary) -> PanelContainer:
	var data: ItemData = stack.get("data")

	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 6))

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)

	h.add_child(_make_icon(data, icon_size, stack.nome))

	var name_lbl := Label.new()
	name_lbl.text = stack.nome
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(name_lbl)

	var qty_lbl := Label.new()
	qty_lbl.text = "x%d" % stack.quantidade
	qty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	qty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(qty_lbl)

	row.mouse_entered.connect(_on_row_hover.bind(i))
	row.gui_input.connect(_on_row_gui_input.bind(i))
	return row


# -------------------------------------------------------------------- cursor

func _refresh_cursor() -> void:
	for i in _rows.size():
		var on := (i == _cursor)
		_rows[i].add_theme_stylebox_override("panel", _box(
			Color(GOLD, 0.18) if on else Color(0, 0, 0, 0),
			GOLD if on else Color(0, 0, 0, 0), 6))
	if _cursor < _rows.size():
		_scroll_to_cursor.call_deferred()
	_show_detail()


## Deferred: rows may be rebuilt/freed before this runs. Re-check at call time.
func _scroll_to_cursor() -> void:
	if _cursor < 0 or _cursor >= _rows.size():
		return
	var row := _rows[_cursor]
	if is_instance_valid(row) and _scroll.is_ancestor_of(row):
		_scroll.ensure_control_visible(row)


func _move_cursor(delta: int) -> void:
	if _stacks.is_empty():
		return
	_cursor = wrapi(_cursor + delta, 0, _stacks.size())
	_refresh_cursor()


func _show_detail() -> void:
	if _cursor < 0 or _cursor >= _stacks.size():
		return
	var stack := _stacks[_cursor]
	var data: ItemData = stack.get("data")

	for c in _detail_icon_holder.get_children():
		_detail_icon_holder.remove_child(c)
		c.queue_free()
	_detail_icon_holder.add_child(_make_icon(data, detail_icon_size, stack.nome))

	_detail_name.text = stack.nome
	_detail_qty.text = "Quantidade: %d" % stack.quantidade
	_detail_desc.text = data.descricao if data != null and data.descricao != "" else "Sem descricao."


func _activate(i: int) -> void:
	if i < 0 or i >= _stacks.size():
		return
	item_activated.emit(_stacks[i].index)


func _on_row_hover(i: int) -> void:
	_cursor = i
	_refresh_cursor()


func _on_row_gui_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_cursor = i
		_refresh_cursor()
		_activate(i)
