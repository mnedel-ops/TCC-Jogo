extends Node

@onready var player: Player = $"../player"
@onready var follower_holder: Node3D = $"../FollowerHolder"

var alchemonfollower: PackedScene = load("res://DATABASE/Alchemons/AlchemonActor.tscn")
var alchemonfollowerinstance : Node3D

@export var equipe_player: PlayerPartyData 

func _ready() -> void:
	for m in equipe_player.party:
		print_debug(equipe_player.species_ids[m])
	set_follower()
	
func set_follower():
	alchemonfollowerinstance = alchemonfollower.instantiate() as Node3D
	alchemonfollowerinstance._set_id(equipe_player.species_ids[0])
	follower_holder.add_child(alchemonfollowerinstance)
	alchemonfollowerinstance.global_position = player.global_position
	
