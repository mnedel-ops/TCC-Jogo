class_name PCList
extends ScrollContainer
## Lista vertical de cartões navegável por teclado/mouse, no estilo das telas de Alchemons.
## Substitui o ItemList do PC: mesma ideia (select / get_selected_items / item_activated),
## mas cada entrada é um Control montado por quem chama.
##
## Selecionada + com foco = dourado forte. Selecionada sem foco = dourado suave.

signal item_selected(index: int)
signal item_activated(index: int)

var item_count: int:
	get:
		return _rows.size()

var _list: VBoxContainer
var _rows: Array[PanelContainer] = []
var _accents: Array[Color] = []
var _titles: Array[Label] = []
var _selected := -1


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	add_child(_list)
	focus_entered.connect(_refresh)
	focus_exited.connect(_refresh)


func clear() -> void:
	for r in _rows:
		_list.remove_child(r)
		r.queue_free()
	_rows.clear()
	_accents.clear()
	_titles.clear()
	_selected = -1


## `title` (opcional): Label do nome, pintado de dourado quando a entrada está selecionada.
func add_entry(content: Control, accent := UIStyle.CLEAR, title: Label = null) -> int:
	var i := _rows.size()
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(content)
	row.gui_input.connect(_on_row_gui_input.bind(i))
	_list.add_child(row)
	_rows.append(row)
	_accents.append(accent)
	_titles.append(title)
	_style_row(i)
	return i


func get_selected_items() -> PackedInt32Array:
	return PackedInt32Array([_selected]) if _selected >= 0 else PackedInt32Array()


## Seleciona sem emitir item_selected (mesmo comportamento do ItemList.select).
func select(i: int) -> void:
	if _rows.is_empty():
		_selected = -1
		return
	_selected = clampi(i, 0, _rows.size() - 1)
	_refresh()
	_scroll_to_selected.call_deferred()


func _gui_input(event: InputEvent) -> void:
	if not has_focus():
		return
	if event is InputEventKey and not event.pressed:
		return
	if event.is_action_pressed("menu_down") or event.is_action_pressed("ui_down"):
		_move(1)
		accept_event()
	elif event.is_action_pressed("menu_up") or event.is_action_pressed("ui_up"):
		_move(-1)
		accept_event()
	elif event.is_action_pressed("ui_accept") and _selected >= 0:
		item_activated.emit(_selected)
		accept_event()


func _move(delta: int) -> void:
	if _rows.is_empty():
		return
	var next := wrapi(_selected + delta, 0, _rows.size()) if _selected >= 0 else 0
	_selected = next
	_refresh()
	_scroll_to_selected.call_deferred()
	item_selected.emit(_selected)


func _on_row_gui_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var changed := i != _selected
		_selected = i
		if focus_mode != Control.FOCUS_NONE:
			grab_focus()
		_refresh()
		if changed:
			item_selected.emit(i)
		if event.double_click:
			item_activated.emit(i)


func _refresh() -> void:
	for i in _rows.size():
		_style_row(i)


func _style_row(i: int) -> void:
	var chosen := i == _selected
	var style: StyleBoxFlat
	if chosen and has_focus():
		style = UIStyle.row_box(true, _accents[i])
	elif chosen:
		style = UIStyle.box(Color(UIStyle.GOLD, 0.08), Color(UIStyle.GOLD, 0.45), 6)
		style.border_width_left = 4
	else:
		style = UIStyle.row_box(false, _accents[i])
	_rows[i].add_theme_stylebox_override("panel", style)
	if _titles[i] != null:
		_titles[i].add_theme_color_override("font_color", UIStyle.GOLD if chosen else Color.WHITE)


func _scroll_to_selected() -> void:
	if _selected < 0 or _selected >= _rows.size():
		return
	var row := _rows[_selected]
	if is_instance_valid(row) and is_ancestor_of(row):
		ensure_control_visible(row)
