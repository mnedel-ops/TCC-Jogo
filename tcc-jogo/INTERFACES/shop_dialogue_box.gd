class_name ShopDialogueBox
extends CanvasLayer

signal option_chosen(option: StringName)
signal closed

@export var up_action: StringName = &"menu_up"
@export var down_action: StringName = &"menu_down"
@export var select_action: StringName = &"menu_interact"
@export var back_action: StringName = &"ui_cancel"

enum Page { MENU, BUY, SELL }

const OPTION_IDS: Array[StringName] = [&"buy", &"sell", &"leave"]
const OPTION_LABELS: Array[String] = ["Comprar", "Vender", "Sair"]
const BACK_LABEL := "Voltar"
const EMPTY_BUY_TEXT := "Não tenho nada à venda."
const EMPTY_SELL_TEXT := "Você não tem nada que eu queira comprar."
const MAX_ROWS := 6

const BOX_WIDTH := 640.0
const BOTTOM_MARGIN := 24.0
const FONT_SIZE := 20
const BG_COLOR := Color(0.97, 0.97, 0.94)
const BORDER_COLOR := Color(0.1, 0.1, 0.12)
const TEXT_COLOR := Color(0.08, 0.08, 0.1)
const OPTION_COLOR := Color(0.35, 0.35, 0.4)
const SELECTED_COLOR := Color(0.75, 0.25, 0.1)
const DISABLED_COLOR := Color(0.62, 0.62, 0.66)

var _greeting := ""
var _cursor := 0
var _scroll := 0
var _page := Page.MENU
var _message := ""
var _ready_to_input := false

var _stock: Array[ItemData] = []
var _player: PlayerData
var _inventory: InventoryData
var _item_db: ItemDatabase
var _rows: Array[Dictionary] = []

var _text_label: Label
var _money_label: Label
var _list_box: VBoxContainer
var _option_labels: Array[Label] = []


func _ready() -> void:
	layer = 10
	_build_ui()
	_refresh()
	await get_tree().process_frame
	_ready_to_input = true


# stock vazio = vende tudo que tem preço no ItemDatabase.
func open(greeting: String, stock: Array[ItemData] = [], player: PlayerData = null, inventory: InventoryData = null, item_db: ItemDatabase = null) -> void:
	_greeting = greeting
	_player = player if player != null else GameSession.player
	_inventory = inventory if inventory != null else GameSession.inventory
	_item_db = item_db if item_db != null else load("res://DATABASE/Inventory/ItemDatabase.tres")
	_stock = _priced(stock if not stock.is_empty() else ShopRules.tradable_items(_item_db))
	_page = Page.MENU
	_message = ""
	_cursor = 0
	_scroll = 0
	if is_node_ready():
		_refresh()


func _priced(list: Array[ItemData]) -> Array[ItemData]:
	var out: Array[ItemData] = []
	for item in list:
		if item == null:
			continue
		if ShopRules.can_buy(item):
			out.append(item)
		else:
			push_warning("ShopDialogueBox: '%s' sem valorVenda, fora da loja." % item.nome)
	return out


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -BOX_WIDTH * 0.5
	panel.offset_right = BOX_WIDTH * 0.5
	panel.offset_top = -BOTTOM_MARGIN
	panel.offset_bottom = -BOTTOM_MARGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var box := StyleBoxFlat.new()
	box.bg_color = BG_COLOR
	box.border_color = BORDER_COLOR
	box.set_border_width_all(3)
	box.set_corner_radius_all(12)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", box)
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	_text_label = Label.new()
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(BOX_WIDTH - 40.0, 56.0)
	_text_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_text_label.add_theme_color_override("font_color", TEXT_COLOR)
	vbox.add_child(_text_label)

	_money_label = Label.new()
	_money_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_money_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_money_label.add_theme_color_override("font_color", OPTION_COLOR)
	vbox.add_child(_money_label)

	vbox.add_child(HSeparator.new())

	_list_box = VBoxContainer.new()
	_list_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_list_box)


func _build_rows() -> void:
	_rows.clear()
	if _page == Page.BUY:
		for item in _stock:
			_rows.append({"data": item, "price": ShopRules.buy_price(item), "qty": -1})
	elif _page == Page.SELL:
		for stack in _inventory.get_stacked_view(_item_db):
			var data: ItemData = stack.get("data")
			if data != null and ShopRules.can_sell(data):
				_rows.append({"data": data, "price": ShopRules.sell_price(data), "qty": int(stack["quantidade"])})


func _entry_count() -> int:
	if _page == Page.MENU:
		return OPTION_IDS.size()
	return _rows.size() + 1  # +1 = Voltar


func _entry_text(i: int) -> String:
	if _page == Page.MENU:
		return OPTION_LABELS[i]
	if i >= _rows.size():
		return BACK_LABEL
	var row: Dictionary = _rows[i]
	var data: ItemData = row["data"]
	var qty := ""
	if int(row["qty"]) >= 0:
		qty = "  x%d" % int(row["qty"])
	return "%s%s   $ %d" % [data.nome, qty, int(row["price"])]


func _entry_enabled(i: int) -> bool:
	if _page == Page.BUY and i < _rows.size():
		return _player.money >= int(_rows[i]["price"])
	return true


func _body_text() -> String:
	if _message != "":
		return _message
	if _page == Page.MENU:
		return _greeting
	if _rows.is_empty():
		return EMPTY_BUY_TEXT if _page == Page.BUY else EMPTY_SELL_TEXT
	if _cursor < _rows.size():
		var data: ItemData = _rows[_cursor]["data"]
		return data.descricao if data.descricao != "" else data.nome
	return _greeting


func _refresh() -> void:
	if _text_label == null:
		return
	_build_rows()
	var total := _entry_count()
	_cursor = clampi(_cursor, 0, total - 1)
	_scroll = clampi(_scroll, maxi(_cursor - MAX_ROWS + 1, 0), _cursor)
	_scroll = clampi(_scroll, 0, maxi(total - MAX_ROWS, 0))

	_text_label.text = _body_text()
	_money_label.text = "Dinheiro: $ %d" % (_player.money if _player != null else 0)

	for l in _option_labels:
		_list_box.remove_child(l)
		l.free()
	_option_labels.clear()
	for i in range(_scroll, mini(_scroll + MAX_ROWS, total)):
		var selected := i == _cursor
		var l := Label.new()
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_font_size_override("font_size", FONT_SIZE)
		l.text = ("▶ " if selected else "   ") + _entry_text(i)
		var color := OPTION_COLOR
		if not _entry_enabled(i):
			color = DISABLED_COLOR
		if selected:
			color = SELECTED_COLOR
		l.add_theme_color_override("font_color", color)
		_list_box.add_child(l)
		_option_labels.append(l)


func _go_page(page: Page) -> void:
	_page = page
	_cursor = 0
	_scroll = 0
	_message = ""
	_refresh()


func _move_cursor(step: int) -> void:
	_cursor = posmod(_cursor + step, _entry_count())
	_message = ""
	_refresh()


func _select() -> void:
	if _page == Page.MENU:
		var id := OPTION_IDS[_cursor]
		if id == &"leave":
			closed.emit()
			return
		_go_page(Page.BUY if id == &"buy" else Page.SELL)
		option_chosen.emit(id)
		return
	if _cursor >= _rows.size():
		_go_page(Page.MENU)
		return
	var data: ItemData = _rows[_cursor]["data"]
	var buying := _page == Page.BUY
	var result := ShopRules.buy(_player, _inventory, data) if buying else ShopRules.sell(_player, _inventory, data)
	_message = ShopRules.message_for(result, data, buying)
	_refresh()


func _back() -> void:
	if _page == Page.MENU:
		closed.emit()
	else:
		_go_page(Page.MENU)


func _input(event: InputEvent) -> void:
	if not _ready_to_input:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed(down_action):
		get_viewport().set_input_as_handled()
		_move_cursor(1)
	elif event.is_action_pressed(up_action):
		get_viewport().set_input_as_handled()
		_move_cursor(-1)
	elif event.is_action_pressed(select_action):
		get_viewport().set_input_as_handled()
		_select()
	elif event.is_action_pressed(back_action):
		get_viewport().set_input_as_handled()
		_back()
