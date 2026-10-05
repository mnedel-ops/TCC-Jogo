extends Node
var alchemonfollower :PackedScene= load("res://DATABASE/Alchemons/AlchemonMetal.tscn")
@onready var player:= $".."
var instanceAlchemonFollower : Node3D = null
@onready var follower_target: Marker3D = $"../Mesh/Follower_target"

func _ready() -> void:
	spawn_follower()
	
func spawn_follower(): 
	instanceAlchemonFollower = alchemonfollower.instantiate()
	add_child(instanceAlchemonFollower)
	

@export var follow_speed: float = 6.0
@export var follow_offset: Vector3 = Vector3(2.0, 0.0, 0) # 2m behind player

func _process(delta: float) -> void:
	if not player:
		return
		
	var target_pos: Vector3 = player.global_transform * follow_offset
	instanceAlchemonFollower.global_position=follower_target.global_position
