class_name TablePage
extends MenuPage

## Table page (the game's Pokedex): two columns.
##  Left : every species, ordered by atomic mass.  Row = "#056  Name".
##  Right: top = element name + 3D preview, bottom = tabs (Stats / Description / Lore).
##
## Hover / keyboard cursor only HIGHLIGHTS a row. The right column changes
## only when the player INTERACTS (click or menu_interact).
##
## Keys: menu_up / menu_down = cursor, menu_interact = select,
##       menu_right / ui_page_down = next tab, ui_page_up = previous tab,
##       menu_left (or Esc) = back to the menu list.

signal entry_selected(species_id: int)

const GOLD := Color(1, 0.85, 0.2)
const PANEL_BG := Color(0.07, 0.07, 0.11, 0.94)
const PANEL_BORDER := Color(0.5, 0.5, 0.6)
const DEFAULT_DATABASE := "res://DATABASE/Alchemons/AlchemonDataBaseComplete.tres"

@export var database: AlchemonDatabase
@export var spin_speed := 0.8            # preview rotation, rad/s
@export var preview_size := 1.6          # model is scaled so its biggest side = this

var _entries: Array[AlchemonSheet] = []
var _rows: Array[PanelContainer] = []
var _num_labels: Array[Label] = []
var _name_labels: Array[Label] = []
var _cursor := 0          # highlighted row (hover / keyboard)
var _selected := -1       # row shown on the right

# left
var _count_label: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _empty_label: Label
# right
var _right: VBoxContainer
var _name_label: Label
var _mass_label: Label
var _pivot: Node3D
var _model_holder: Node3D
var _tabs: TabContainer
var _stats_grid: GridContainer
var _desc_label: Label
var _lore_label: Label


func _ready() -> void:      # no super: no placeholder
	if database == null:
		database = load(DEFAULT_DATABASE)
	_build()
	_populate()


func _process(delta: float) -> void:
	if _pivot != null and is_visible_in_tree():
		_pivot.rotate_y(delta * spin_speed)


# --------------------------------------------------------------- MenuPage API

func on_open() -> void:
	_populate()


func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("menu_down"):
		_move_cursor(1)
	elif event.is_action_pressed("menu_up"):
		_move_cursor(-1)
	elif event.is_action_pressed("menu_interact"):
		_select(_cursor)
	elif event.is_action_pressed("menu_right") or event.is_action_pressed("ui_page_down"):
		_step_tab(1)
	elif event.is_action_pressed("ui_page_up"):
		_step_tab(-1)
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

	var header := HBoxContainer.new()
	root.add_child(header)
	var title_lbl := Label.new()
	title_lbl.text = "Tabela"
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

	_build_left(body)
	_build_right(body)


func _build_left(body: Control) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	panel.add_theme_stylebox_override("panel", _box(PANEL_BG, PANEL_BORDER, 8))
	body.add_child(panel)

	var stack := Control.new()
	panel.add_child(stack)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	_scroll.add_child(_list)

	_empty_label = Label.new()
	_empty_label.text = "Tabela vazia"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.modulate.a = 0.6
	_empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_empty_label)


func _build_right(body: Control) -> void:
	_right = VBoxContainer.new()
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.size_flags_stretch_ratio = 1.6
	_right.add_theme_constant_override("separation", 12)
	body.add_child(_right)

	# top: name + 3D preview
	var top := PanelContainer.new()
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.size_flags_stretch_ratio = 1.2
	top.add_theme_stylebox_override("panel", _box(PANEL_BG, PANEL_BORDER, 8))
	_right.add_child(top)

	var top_v := VBoxContainer.new()
	top_v.add_theme_constant_override("separation", 2)
	top.add_child(top_v)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 32)
	_name_label.add_theme_color_override("font_color", GOLD)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_v.add_child(_name_label)

	_mass_label = Label.new()
	_mass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mass_label.modulate.a = 0.7
	top_v.add_child(_mass_label)

	top_v.add_child(_build_preview())

	# bottom: tabs
	var bottom := PanelContainer.new()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom.size_flags_stretch_ratio = 1.0
	bottom.add_theme_stylebox_override("panel", _box(PANEL_BG, PANEL_BORDER, 8))
	_right.add_child(bottom)

	_tabs = TabContainer.new()
	_tabs.get_tab_bar().focus_mode = Control.FOCUS_NONE   # keys go to handle_input, not the tab bar
	_tabs.add_theme_color_override("font_hovered_color", GOLD)
	_tabs.add_theme_color_override("font_selected_color", GOLD)
	bottom.add_child(_tabs)

	var stats_scroll := _make_tab("Stats")
	_stats_grid = GridContainer.new()
	_stats_grid.columns = 2
	_stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_grid.add_theme_constant_override("h_separation", 24)
	_stats_grid.add_theme_constant_override("v_separation", 4)
	stats_scroll.add_child(_stats_grid)

	_desc_label = _make_text_tab("Description")
	_lore_label = _make_text_tab("Lore")


func _make_tab(tab_name: String) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.name = tab_name
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(sc)
	return sc


func _make_text_tab(tab_name: String) -> Label:
	var sc := _make_tab(tab_name)
	var lbl := Label.new()
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(lbl)
	return lbl


## 3D preview in its own world (SubViewport) so it never touches the game scene.
func _build_preview() -> Control:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.custom_minimum_size = Vector2(0, 140)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	container.add_child(vp)

	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.8)
	env.ambient_light_energy = 0.6

	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.environment = env
	cam.transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.9, 3.4)).looking_at(Vector3(0, 0.1, 0), Vector3.UP)
	vp.add_child(cam)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	vp.add_child(light)

	_pivot = Node3D.new()
	vp.add_child(_pivot)
	_model_holder = Node3D.new()
	_pivot.add_child(_model_holder)
	return container


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


# ---------------------------------------------------------------------- data

func _populate() -> void:
	var previous_id := -1
	if _selected >= 0 and _selected < _entries.size():
		previous_id = _entries[_selected].id

	_entries.clear()
	if database != null:
		for sheet in database.alchemons:
			if sheet != null:
				_entries.append(sheet)
	_entries.sort_custom(_by_atomic_mass)

	for row in _rows:
		_list.remove_child(row)
		row.queue_free()
	_rows.clear()
	_num_labels.clear()
	_name_labels.clear()
	for i in _entries.size():
		_list.add_child(_make_row(i, _entries[i]))

	_count_label.text = "%d %s" % [_entries.size(), "especie" if _entries.size() == 1 else "especies"]
	_empty_label.visible = _entries.is_empty()
	_right.visible = not _entries.is_empty()

	_selected = -1
	for i in _entries.size():
		if _entries[i].id == previous_id:
			_selected = i
	if _selected == -1 and not _entries.is_empty():
		_selected = 0
	_cursor = maxi(_selected, 0)
	_refresh_rows()
	if _selected >= 0:
		_show_detail(_entries[_selected])


func _by_atomic_mass(a: AlchemonSheet, b: AlchemonSheet) -> bool:
	if a.atomic_mass != b.atomic_mass:
		return a.atomic_mass < b.atomic_mass
	return a.id < b.id


func _make_row(i: int, sheet: AlchemonSheet) -> PanelContainer:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 6))

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)

	var num := Label.new()
	num.text = "#%03d" % sheet.atomic_mass
	num.custom_minimum_size.x = 56
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(num)

	var nm := Label.new()
	nm.text = sheet.creature_name
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(nm)

	row.mouse_entered.connect(_on_row_hover.bind(i))
	row.gui_input.connect(_on_row_gui_input.bind(i))
	_rows.append(row)
	_num_labels.append(num)
	_name_labels.append(nm)
	return row


# -------------------------------------------------------------------- cursor

func _refresh_rows() -> void:
	for i in _rows.size():
		var hot := (i == _cursor)
		var chosen := (i == _selected)
		var bg := Color(0, 0, 0, 0)
		var border := Color(0, 0, 0, 0)
		if hot:
			bg = Color(GOLD, 0.18)
			border = GOLD
		elif chosen:
			bg = Color(GOLD, 0.08)
			border = Color(GOLD, 0.45)
		_rows[i].add_theme_stylebox_override("panel", _box(bg, border, 6))
		var color := GOLD if (hot or chosen) else Color.WHITE
		_num_labels[i].add_theme_color_override("font_color", color)
		_name_labels[i].add_theme_color_override("font_color", color)
	_scroll_to_cursor.call_deferred()


func _scroll_to_cursor() -> void:
	if _cursor < 0 or _cursor >= _rows.size():
		return
	var row := _rows[_cursor]
	if is_instance_valid(row) and _scroll.is_ancestor_of(row):
		_scroll.ensure_control_visible(row)


func _move_cursor(delta: int) -> void:
	if _entries.is_empty():
		return
	_cursor = wrapi(_cursor + delta, 0, _entries.size())
	_refresh_rows()


func _step_tab(delta: int) -> void:
	_tabs.current_tab = wrapi(_tabs.current_tab + delta, 0, _tabs.get_tab_count())


func _select(i: int) -> void:
	if i < 0 or i >= _entries.size():
		return
	_selected = i
	_refresh_rows()
	_show_detail(_entries[i])
	entry_selected.emit(_entries[i].id)


func _on_row_hover(i: int) -> void:
	_cursor = i
	_refresh_rows()


func _on_row_gui_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_cursor = i
		_select(i)


# -------------------------------------------------------------------- detail

func _show_detail(sheet: AlchemonSheet) -> void:
	_name_label.text = sheet.creature_name
	_mass_label.text = "Massa atomica #%03d" % sheet.atomic_mass
	_set_model(sheet)
	_fill_stats(sheet)
	_desc_label.text = sheet.description if sheet.description != "" else "Sem descricao."
	_lore_label.text = sheet.lore if sheet.lore != "" else "Sem lore."


func _fill_stats(s: AlchemonSheet) -> void:
	for c in _stats_grid.get_children():
		_stats_grid.remove_child(c)
		c.queue_free()

	var attack_names: PackedStringArray = []
	for a in s.attacks:
		if a != null:
			attack_names.append(a.attack_name)

	var rows: Array = [
		["Tipo", AlchemonType.Type.keys()[s.element_type].capitalize()],
		["HP", str(s.max_hp)],
		["Ataque", str(s.base_attack)],
		["Defesa", str(s.base_defense)],
		["Velocidade", str(s.base_mechanical_speed)],
		["Energia", str(s.base_action_energy)],
		["Eletrons de valencia", "%d / %d" % [s.max_valence_electrons, s.octet_target]],
		["Estado fisico", s.physical_state.capitalize()],
		["Fusao", "%.1f K" % s.temperature],
		["Ebulicao", "%.1f K" % s.boiling_point],
		["Ataques", ", ".join(attack_names) if not attack_names.is_empty() else "-"],
	]
	for r in rows:
		var key := Label.new()
		key.text = r[0]
		key.modulate.a = 0.7
		_stats_grid.add_child(key)
		var val := Label.new()
		val.text = r[1]
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_stats_grid.add_child(val)


# ------------------------------------------------------------- 3D preview

func _set_model(sheet: AlchemonSheet) -> void:
	for c in _model_holder.get_children():
		_model_holder.remove_child(c)
		c.queue_free()
	_model_holder.scale = Vector3.ONE
	_model_holder.position = Vector3.ZERO

	var model: Node3D = null
	if sheet.model != null:
		var inst := sheet.model.instantiate()
		if inst is Node3D:
			model = inst
		else:
			inst.queue_free()
	if model == null:
		model = _make_placeholder_box(sheet)
	_model_holder.add_child(model)
	_fit_model()


## Placeholder until a species has a real `model`: a box tinted by element type.
func _make_placeholder_box(sheet: AlchemonSheet) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	match sheet.element_type:
		AlchemonType.Type.METAL: mat.albedo_color = Color(0.62, 0.68, 0.78)
		AlchemonType.Type.AMETAL: mat.albedo_color = Color(0.45, 0.78, 0.45)
		_: mat.albedo_color = Color(0.9, 0.62, 0.3)
	mi.material_override = mat
	return mi


## Scale + center the model so any size fits the preview.
func _fit_model() -> void:
	var box := AABB()
	var first := true
	var to_local := _model_holder.global_transform.affine_inverse()
	for n in _model_holder.find_children("*", "VisualInstance3D", true, false):
		var vi := n as VisualInstance3D
		var a: AABB = (to_local * vi.global_transform) * vi.get_aabb()
		box = a if first else box.merge(a)
		first = false
	if first:
		return
	var biggest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if biggest <= 0.0001:
		return
	var f := preview_size / biggest
	_model_holder.scale = Vector3.ONE * f
	_model_holder.position = -box.get_center() * f
