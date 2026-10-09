# INTERFACES/combat_balloon.gd
class_name CombatBalloon
extends Control

@export var offset := Vector3(0, 1.8, 0)   # above head
var target: Node3D
var _hidden_by_state := false

@onready var name_label: Label = $PanelContainer/VBoxContainer/Name
@onready var hp_bar: ProgressBar = $PanelContainer/VBoxContainer/HP
@onready var energy_bar: ProgressBar = $PanelContainer/VBoxContainer/ValenceEnergy

func bind(p_target: Node3D) -> void:
	target = p_target

func update_entry(e: Dictionary) -> void:
	name_label.text = "%s Lv%d" % [e.name, e.level]
	hp_bar.max_value = e.max_hp
	energy_bar.max_value = e.max_energy
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
	position = cam.unproject_position(world_pos) - Vector2(size.x * 0.5, size.y)
