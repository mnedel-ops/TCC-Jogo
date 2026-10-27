class_name GameMenu
extends CanvasLayer

## Tab (ui_menu) = pause + vertical list on the left (icon + name).
## Pick one = page opens to the right, filling the rest of the screen.
##
## Keys: menu_up / menu_down = row, menu_interact / menu_right = open page,
## ui_cancel = page -> list -> close. Tab closes from anywhere.
## Mouse: hover changes colour, click opens.

signal menu_opened
signal menu_closed
signal page_opened(entry_name: String)

enum Mode { CLOSED, LIST, PAGE }

## name = label | icon = texture path ("" = letter placeholder)
## page = scene path, root extends MenuPage ("" = placeholder page)
## action = "exit" asks to quit instead of opening a page.
## action = "save" writes the save file (replaces the old one) and shows a toast.
@export var entries: Array[Dictionary] = [
	{"name": "Table", "icon": "", "page": "res://INTERFACES/pages/table_page.tscn"},
	{"name": "Bag", "icon": "", "page": "res://INTERFACES/pages/bag_page.tscn"},
	{"name": "Alchemons", "icon": "", "page": "res://INTERFACES/pages/alchemons_page.tscn"},
	{"name": "Player", "icon": "", "page": "res://INTERFACES/pages/player_page.tscn"},
	{"name": "Save", "icon": "", "page": "", "action": "save"},
	{"name": "Exit", "icon": "", "page": "", "action": "exit"},
]
@export var icon_size := Vector2(40, 40)
@export var list_width := 240.0
@export var screen_margin := 32
@export var capture_mouse_on_close := true   # same as old menu.gd

const GOLD := Color(1, 0.85, 0.2)

var _mode: Mode = Mode.CLOSED
var _cursor := 0            # highlighted row (-1 = none)
var _open_index := -1       # row whose page is open

var _root: ColorRect
var _slots: Array[PanelContainer] = []
var _labels: Array[Label] = []
var _page_panel: PanelContainer
var _page: MenuPage
var _exit_dialog: ConfirmationDialog
var _toast: Label
var _toast_id := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()
	_root.visible = false


# ------------------------------------------------------------------ building

func _build() -> void:
	_root = ColorRect.new()                       # dim + blocks clicks to game
	_root.color = Color(0, 0, 0, 0.6)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, screen_margin)
	_root.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	# left: vertical list
	var list_panel := PanelContainer.new()
	list_panel.custom_minimum_size.x = list_width
	list_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	list_panel.add_theme_stylebox_override("panel", _box(Color(0.07, 0.07, 0.11, 0.94), Color(0.5, 0.5, 0.6), 8))
	hbox.add_child(list_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	list_panel.add_child(vbox)

	for i in entries.size():
		_add_slot(vbox, i)

	# right: page host, takes all remaining space
	_page_panel = PanelContainer.new()
	_page_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_panel.add_theme_stylebox_override("panel", _box(Color(0.07, 0.07, 0.11, 0.94), Color(0.5, 0.5, 0.6), 8))
	_page_panel.visible = false
	hbox.add_child(_page_panel)

	_exit_dialog = ConfirmationDialog.new()
	_exit_dialog.dialog_text = "Quer sair do jogo?"
	_exit_dialog.ok_button_text = "Sair"
	_exit_dialog.cancel_button_text = "Cancelar"
	_exit_dialog.confirmed.connect(func(): get_tree().quit())
	add_child(_exit_dialog)

	_toast = Label.new()
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.offset_bottom = -48.0
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.visible = false
	_root.add_child(_toast)


func _add_slot(parent: Control, i: int) -> void:
	var e: Dictionary = entries[i]

	var slot := PanelContainer.new()
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 6))

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(h)

	h.add_child(_make_icon(e))

	var lbl := Label.new()
	lbl.text = e.get("name", "?")
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(lbl)

	slot.mouse_entered.connect(_on_slot_hover.bind(i))
	slot.mouse_exited.connect(_on_slot_exit.bind(i))
	slot.gui_input.connect(_on_slot_gui_input.bind(i))

	parent.add_child(slot)
	_slots.append(slot)
	_labels.append(lbl)


func _make_icon(e: Dictionary) -> Control:
	var path: String = e.get("icon", "")
	if path != "" and ResourceLoader.exists(path):
		var tex := TextureRect.new()
		tex.texture = load(path)
		tex.custom_minimum_size = icon_size
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tex
	# no icon yet: box with first letter
	var box := PanelContainer.new()
	box.custom_minimum_size = icon_size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_stylebox_override("panel", _box(Color(0.2, 0.2, 0.28), Color(0.5, 0.5, 0.6), 6))
	var l := Label.new()
	l.text = String(e.get("name", "?")).left(1)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	return box


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


# --------------------------------------------------------------- open / close

func toggle_menu() -> void:
	if _mode == Mode.CLOSED:
		if CombatSignal.in_combat:   # combat has its own UI, never pause it
			return
		open_menu()
	else:
		close_menu()


func open_menu() -> void:
	_mode = Mode.LIST
	_cursor = 0
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_rows()
	menu_opened.emit()


func close_menu() -> void:
	_toast.visible = false
	_clear_page()
	_mode = Mode.CLOSED
	_root.visible = false
	get_tree().paused = false
	if capture_mouse_on_close:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	menu_closed.emit()


# --------------------------------------------------------------------- pages

func _open_entry(i: int) -> void:
	var e: Dictionary = entries[i]
	if e.get("action", "") == "exit":
		_exit_dialog.popup_centered()
		return

	if e.get("action", "") == "save":
		_save_game()
		return

	_clear_page()
	_open_index = i
	_page = _make_page(e)
	_page_panel.add_child(_page)
	_page_panel.visible = true
	_mode = Mode.PAGE
	_cursor = -1
	_refresh_rows()
	_page.on_open()
	page_opened.emit(e.get("name", ""))


## Same file every time: GameSession.save_game() replaces the old one
## (the previous save is kept once as slot_1.json.bak).
func _save_game() -> void:
	var ok := GameSession.save_game() == OK
	_toast.text = "Game saved." if ok else "Could not save the game!"
	_toast.add_theme_color_override("font_color", GOLD if ok else Color(1, 0.4, 0.4))
	_toast.visible = true
	_toast_id += 1
	var id := _toast_id
	await get_tree().create_timer(1.5, true).timeout   # true = still ticks while paused
	if id == _toast_id:                                # a newer save restarts the timer
		_toast.visible = false


func _make_page(e: Dictionary) -> MenuPage:
	var path: String = e.get("page", "")
	var page: MenuPage = null
	if path != "" and ResourceLoader.exists(path):
		page = (load(path) as PackedScene).instantiate() as MenuPage
	if page == null:
		page = MenuPage.new()
	page.title = e.get("name", "")
	page.back_requested.connect(_back_to_list)
	return page


func _clear_page() -> void:
	if _page != null and is_instance_valid(_page):
		_page.on_close()
		_page.queue_free()
	_page = null
	_page_panel.visible = false
	_open_index = -1


func _back_to_list() -> void:
	var was := _open_index
	_clear_page()
	_mode = Mode.LIST
	_cursor = maxi(was, 0)
	_refresh_rows()


# -------------------------------------------------------------------- cursor

func _refresh_rows() -> void:
	for i in _slots.size():
		var hot := (i == _cursor)
		var active := (_mode == Mode.PAGE and i == _open_index)
		var bg := Color(0, 0, 0, 0)
		var border := Color(0, 0, 0, 0)
		if hot:
			bg = Color(GOLD, 0.18)
			border = GOLD
		elif active:
			bg = Color(GOLD, 0.08)
			border = Color(GOLD, 0.45)
		_slots[i].add_theme_stylebox_override("panel", _box(bg, border, 6))
		_labels[i].add_theme_color_override("font_color", GOLD if (hot or active) else Color.WHITE)


func _move_cursor(delta: int) -> void:
	_cursor = wrapi(_cursor + delta, 0, _slots.size())
	_refresh_rows()


# --------------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_menu"):
		toggle_menu()
		get_viewport().set_input_as_handled()
		return

	match _mode:
		Mode.LIST:
			if event.is_action_pressed("menu_down"):
				_move_cursor(1)
			elif event.is_action_pressed("menu_up"):
				_move_cursor(-1)
			elif event.is_action_pressed("menu_interact") or event.is_action_pressed("menu_right"):
				_open_entry(_cursor)
			elif event.is_action_pressed("ui_cancel"):
				close_menu()
			else:
				return
		Mode.PAGE:
			if _page != null and _page.handle_input(event):
				pass
			elif event.is_action_pressed("ui_cancel"):
				_back_to_list()
			else:
				return
		_:
			return
	get_viewport().set_input_as_handled()


func _on_slot_hover(i: int) -> void:
	if _mode == Mode.CLOSED:
		return
	_cursor = i
	_refresh_rows()


func _on_slot_exit(i: int) -> void:
	if _mode == Mode.PAGE and _cursor == i:   # list mode keeps cursor, like keyboard
		_cursor = -1
		_refresh_rows()


func _on_slot_gui_input(event: InputEvent, i: int) -> void:
	if _mode == Mode.CLOSED:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_entry(i)
