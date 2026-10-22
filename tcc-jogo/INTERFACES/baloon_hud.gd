class_name CombatBalloon
extends Control

@export var offset := Vector3(0, 1.8, 0)   # above head
var target: Node3D
var _hidden_by_state := false

const HP_COLOR := Color(0.25, 0.8, 0.3)       # green
const ENERGY_COLOR := Color(0.25, 0.55, 1.0)  # blue
const BAR_HEIGHT := 6.0                       # thin bars
const TEXT_SIZE := 12

@onready var panel: PanelContainer = $PanelContainer
@onready var name_label: Label = $PanelContainer/VBoxContainer/Name
@onready var hp_bar: ProgressBar = $PanelContainer/VBoxContainer/HP
@onready var energy_bar: ProgressBar = $PanelContainer/VBoxContainer/ValenceEnergy

var _hp_label: Label
var _energy_label: Label


func _ready() -> void:
	_hp_label = _setup_bar(hp_bar, HP_COLOR)
	_energy_label = _setup_bar(energy_bar, ENERGY_COLOR)


## Thin colored bar + a "HP 2/3" style label right above it. No percentage text.
func _setup_bar(bar: ProgressBar, color: Color) -> Label:
	bar.show_percentage = false
	bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END
	bar.custom_minimum_size.y = BAR_HEIGHT

	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.1, 0.1, 0.12, 0.85)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)

	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", TEXT_SIZE)
	lbl.add_theme_color_override("font_color", color.lightened(0.35))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := bar.get_parent()
	box.add_child(lbl)
	box.move_child(lbl, bar.get_index())          # label above its bar
	return lbl


func bind(p_target: Node3D) -> void:
	target = p_target


func update_entry(e: Dictionary) -> void:
	name_label.text = "%s Lv%d" % [e.name, e.level]
	hp_bar.max_value = e.max_hp
	energy_bar.max_value = e.max_energy
	_hp_label.text = "HP %d/%d" % [e.hp, e.max_hp]
	_energy_label.text = "Energia %d/%d" % [e.energy, e.max_energy]
	_tween_bar(hp_bar, e.hp)
	_tween_bar(energy_bar, e.energy)
	_hidden_by_state = not e.visible   # dead / cation


func _tween_bar(bar: ProgressBar, value: float) -> void:
	create_tween().tween_property(bar, "value", value, 0.25)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if target == null or cam == null:
		return
	var world_pos := target.global_position + offset
	visible = not _hidden_by_state and not cam.is_position_behind(world_pos)
	position = cam.unproject_position(world_pos) - Vector2(panel.size.x * 0.5, panel.size.y)
