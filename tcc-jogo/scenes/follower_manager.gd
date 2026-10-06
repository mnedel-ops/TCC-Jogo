extends Node

@onready var player: Player = $"../player"
@onready var follower_holder: Node3D = $"../FollowerHolder"

var alchemonfollower: PackedScene = load("res://DATABASE/Alchemons/AlchemonMetal.tscn")
var alchemonfollowerinstance : Node3D

func _ready() -> void:
	alchemonfollowerinstance = alchemonfollower.instantiate() as Node3D
	follower_holder.add_child(alchemonfollowerinstance)
	alchemonfollowerinstance.global_position = player.global_position
	
