extends Node

@onready var player: Player = $"../player"
@onready var follower_holder: Node3D = $"../FollowerHolder"

var alchemonfollower: PackedScene = load("res://DATABASE/Alchemons/AlchemonActor.tscn")
var alchemonfollowerinstance : Node3D

func _ready() -> void:
	set_follower(0)
	set_follower(3)
	
func set_follower(offset: int):
	alchemonfollowerinstance = alchemonfollower.instantiate() as Node3D
	follower_holder.add_child(alchemonfollowerinstance)
	alchemonfollowerinstance.global_position = player.global_position + Vector3(offset, 0,0)
	
