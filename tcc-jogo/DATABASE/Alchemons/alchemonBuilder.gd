extends Node3D

@export var id : int
@export var database := load("res://DATABASE/Alchemons/AlchemonDataBaseComplete.tres")
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	id = 999

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
