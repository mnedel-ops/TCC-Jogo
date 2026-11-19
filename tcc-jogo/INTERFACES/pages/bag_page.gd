class_name BagPage
extends MenuPage


signal item_activated(item_index: int)

const GOLD := UIStyle.GOLD
const PANEL_BG := UIStyle.PANEL_BG
const PANEL_BORDER := UIStyle.PANEL_BORDER
const HINT_TEXT := "Cima/Baixo: selecionar     E: usar item     Esquerda/Esc: voltar"
const CATEGORY_ORDER: Array[String] = ["heal", "capture", "other"]
const CATEGORIES := {
	"heal": {"label": "Cura", "color": Color(0.4, 0.85, 0.5)},
	"capture": {"label": "Captura", "color": Color(0.45, 0.7, 1.0)},
	"other": {"label": "Outros", "color": Color(0.72, 0.72, 0.8)},
}

@export var mochila: InventoryData
@export var inventory_database: ItemDatabase
@export var icon_size := Vector2(36, 36)
@export var detail_icon_size := Vector2(112, 112)

var _stacks: Array[Dictionary] = []
var _rows: Array[PanelContainer] = []
var _headers: Array[Control] = []
var _name_labels: Array[Label] = []
var _cursor := 0

var _count_label: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _empty_label: Label
var _detail_box: VBoxContainer
var _detail_icon_holder: Control
var _detail_name: Label
var _detail_chips: HBoxContainer
var _detail_desc: Label
var _detail_effect: Label


func _ready() -> void:
	if mochila == null:
		mochila = load("res://DATABASE/Inventory/inventory.tres")
	if inventory_database == null:
		inventory_database = load("res://DATABASE/Inventory/ItemDatabase.tres")
	_build()
	refresh()


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


static func category_of(data: ItemData) -> String:
	if data == null:
		return "other"
	if data.is_capture_method:
		return "capture"
	if data.heal_amount > 0:
		return "heal"
	return "other"


static func category_color(cat: String) -> Color:
	return CATEGORIES[cat]["color"]


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

	var list_panel := PanelContainer.new()
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_panel.size_flags_stretch_ratio = 1.3
	list_panel.add_theme_stylebox_override("panel", UIStyle.box(PANEL_BG, PANEL_BORDER, 8))
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

	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL_BG_ACTIVE, PANEL_BORDER, 8))
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

	var chips_center := CenterContainer.new()
	_detail_box.add_child(chips_center)
	_detail_chips = HBoxContainer.new()
	_detail_chips.add_theme_constant_override("separation", 8)
	chips_center.add_child(_detail_chips)

	_detail_box.add_child(HSeparator.new())

	_detail_desc = Label.new()
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_box.add_child(_detail_desc)

	_detail_effect = Label.new()
	_detail_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_effect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_effect.add_theme_color_override("font_color", GOLD)
	_detail_box.add_child(_detail_effect)

	root.add_child(UIStyle.hint_label(HINT_TEXT))


func _make_icon(data: ItemData, size: Vector2, fallback_name: String, accent: Color) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs := UIStyle.box(Color(0.12, 0.12, 0.18), Color(accent, 0.9), 6)
	fs.content_margin_left = 2
	fs.content_margin_right = 2
	fs.content_margin_top = 2
	fs.content_margin_bottom = 2
	frame.add_theme_stylebox_override("panel", fs)
	if data != null and data.icone != null:
		var tex := TextureRect.new()
		tex.texture = data.icone
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(tex)
		return frame
	var l := Label.new()
	l.text = fallback_name.left(1)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(size.y * 0.5))
	l.add_theme_color_override("font_color", accent)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(l)
	return frame


func refresh() -> void:
	var previous_index := -1
	if _cursor >= 0 and _cursor < _stacks.size():
		previous_index = _stacks[_cursor].index

	_stacks.clear()
	if mochila != null:
		var view := mochila.get_stacked_view(inventory_database)
		for cat in CATEGORY_ORDER:
			for stack in view:
				if category_of(stack.get("data")) == cat:
					stack["category"] = cat
					_stacks.append(stack)

	_cursor = clampi(_cursor, 0, maxi(_stacks.size() - 1, 0))
	for i in _stacks.size():
		if _stacks[i].index == previous_index:
			_cursor = i
			break

	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_rows.clear()
	_headers.clear()
	_name_labels.clear()

	var last_cat := ""
	for i in _stacks.size():
		var cat: String = _stacks[i].category
		if cat != last_cat:
			var h := _make_header(cat)
			_list.add_child(h)
			_headers.append(h)
			last_cat = cat
		var row := _make_row(i, _stacks[i])
		_list.add_child(row)
		_rows.append(row)

	var total := mochila.items.size() if mochila != null else 0
	_count_label.text = "%d %s" % [total, "item" if total == 1 else "itens"]
	_empty_label.visible = _stacks.is_empty()
	_detail_box.visible = not _stacks.is_empty()
	_refresh_cursor()


func _make_header(cat: String) -> Control:
	var l := Label.new()
	l.text = CATEGORIES[cat]["label"].to_upper()
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", category_color(cat))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _make_row(i: int, stack: Dictionary) -> PanelContainer:
	var data: ItemData = stack.get("data")
	var accent := category_color(stack.category)

	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_stylebox_override("panel", UIStyle.row_box(false, accent))

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)

	h.add_child(_make_icon(data, icon_size, stack.nome, accent))

	var name_lbl := Label.new()
	name_lbl.text = stack.nome
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(name_lbl)
	_name_labels.append(name_lbl)

	var qty := UIStyle.chip("x%d" % stack.quantidade, Color(0.85, 0.85, 0.9))
	qty.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(qty)

	row.mouse_entered.connect(_on_row_hover.bind(i))
	row.gui_input.connect(_on_row_gui_input.bind(i))
	return row


func _refresh_cursor() -> void:
	for i in _rows.size():
		var on := (i == _cursor)
		_rows[i].add_theme_stylebox_override("panel", UIStyle.row_box(on, category_color(_stacks[i].category)))
		_name_labels[i].add_theme_color_override("font_color", GOLD if on else Color.WHITE)
	if _cursor < _rows.size():
		_scroll_to_cursor.call_deferred()
	_show_detail()


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


func _effect_text(data: ItemData) -> String:
	if data == null:
		return ""
	if data.is_capture_method:
		return "Captura Alchemons do tipo %s." % AlchemonType.type_name(data.capture_type)
	if data.heal_amount > 0:
		return "Recupera %d HP." % data.heal_amount
	return ""


func _show_detail() -> void:
	if _cursor < 0 or _cursor >= _stacks.size():
		return
	var stack := _stacks[_cursor]
	var data: ItemData = stack.get("data")
	var cat: String = stack.category
	var accent := category_color(cat)

	for c in _detail_icon_holder.get_children():
		_detail_icon_holder.remove_child(c)
		c.queue_free()
	_detail_icon_holder.add_child(_make_icon(data, detail_icon_size, stack.nome, accent))

	for c in _detail_chips.get_children():
		_detail_chips.remove_child(c)
		c.queue_free()
	_detail_chips.add_child(UIStyle.chip(CATEGORIES[cat]["label"], accent))
	_detail_chips.add_child(UIStyle.chip("Quantidade: %d" % stack.quantidade, Color(0.85, 0.85, 0.9)))

	_detail_name.text = stack.nome
	_detail_desc.text = data.descricao if data != null and data.descricao != "" else "Sem descricao."
	var effect := _effect_text(data)
	_detail_effect.text = effect
	_detail_effect.visible = effect != ""


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
