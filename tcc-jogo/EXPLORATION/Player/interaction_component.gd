class_name InteractionComponent
extends Node

@export var interact_area: Area3D
var current_target: Area3D = null

func _ready() -> void:
	interact_area.area_entered.connect(_on_area_entered)
	interact_area.area_exited.connect(_on_area_exited)

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("collectible"):
		current_target = area

func _on_area_exited(area: Area3D) -> void:
	if area == current_target:
		current_target = null

func try_collect() -> Area3D:
	var target := current_target
	current_target = null
	return target
