class_name PCStatsCard
extends PanelContainer
## Cartão com retrato 3D, tipo, nível, barra de PV e atributos do Alchemon selecionado.

const EMPTY_TEXT := "Selecione um Alchemon"
const HP_GOOD := Color(0.4, 0.85, 0.5)
const HP_MID := Color(0.95, 0.8, 0.3)
const HP_LOW := Color(0.9, 0.35, 0.3)

var _empty: Label
var _body: VBoxContainer
var _preview: AlchemonPreview
var _name: Label
var _chips: HBoxContainer
var _hp_bar: ProgressBar
var _hp_label: Label
var _grid: GridContainer


func _init() -> void:
	custom_minimum_size = Vector2(260, 0)
	add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL_BG_DEEP, Color(UIStyle.PANEL_BORDER, 0.5), 8))

	_empty = Label.new()
	_empty.text = EMPTY_TEXT
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.modulate.a = 0.6
	_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_empty)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_body.visible = false
	add_child(_body)

	_preview = AlchemonPreview.new()
	_body.add_child(_preview)

	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 24)
	_name.add_theme_color_override("font_color", UIStyle.GOLD)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_body.add_child(_name)

	var chips_center := CenterContainer.new()
	_body.add_child(chips_center)
	_chips = HBoxContainer.new()
	_chips.add_theme_constant_override("separation", 8)
	chips_center.add_child(_chips)

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	_body.add_child(hp_row)
	var hp_key := Label.new()
	hp_key.text = "PV"
	hp_key.modulate.a = 0.7
	hp_row.add_child(hp_key)
	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(0, 14)
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hp_bar.add_theme_stylebox_override("background", UIStyle.box(Color(0, 0, 0, 0.5), Color(UIStyle.PANEL_BORDER, 0.6), 4))
	hp_row.add_child(_hp_bar)
	_hp_label = Label.new()
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_row.add_child(_hp_label)

	_body.add_child(HSeparator.new())
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 20)
	_grid.add_theme_constant_override("v_separation", 3)
	_body.add_child(_grid)


func clear() -> void:
	_body.visible = false
	_empty.visible = true
	_empty.text = EMPTY_TEXT


func show_instance(inst: AlchemonInstance, sheet: AlchemonSheet, display_name: String) -> void:
	if inst == null:
		clear()
		return
	_empty.visible = false
	_body.visible = true
	_name.text = display_name
	_preview.set_sheet(sheet)
	_clear_children(_chips)
	_clear_children(_grid)

	_chips.add_child(UIStyle.chip("Nv.%d" % inst.level, Color(0.85, 0.85, 0.9)))
	if sheet == null:
		_chips.add_child(UIStyle.chip("sem dados da espécie", UIStyle.PANEL_BORDER))
		_hp_bar.value = 0
		_hp_label.text = "-"
		return
	_chips.add_child(UIStyle.chip(AlchemonType.type_name(sheet.element_type), UIStyle.type_color(sheet.element_type)))

	var stats := inst.compute_stats(sheet)
	var max_hp: int = stats.max_hp
	var hp := inst.hp_or_full(max_hp)
	_hp_bar.max_value = maxi(max_hp, 1)
	_hp_bar.value = hp
	var ratio := float(hp) / float(maxi(max_hp, 1))
	var fill := HP_GOOD if ratio > 0.5 else (HP_MID if ratio > 0.2 else HP_LOW)
	_hp_bar.add_theme_stylebox_override("fill", UIStyle.box(fill, UIStyle.CLEAR, 4))
	_hp_label.text = "%d/%d" % [hp, max_hp]

	var rows: Array = [
		["XP", "%d/%d" % [inst.experience, AlchemonGrowth.xp_to_next(inst.level)]],
		["Valência", str(sheet.max_valence_electrons)],
		["Ataque", str(int(stats.attack))],
		["Defesa", str(int(stats.defense))],
		["Vel. mecânica", str(int(stats.mechanical_speed))],
		["Energia de ação", str(int(stats.action_energy))],
		["IV", str(inst.individual_value)],
	]
	for r in rows:
		var key := Label.new()
		key.text = r[0]
		key.modulate.a = 0.7
		_grid.add_child(key)
		var val := Label.new()
		val.text = r[1]
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(val)


func _clear_children(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
