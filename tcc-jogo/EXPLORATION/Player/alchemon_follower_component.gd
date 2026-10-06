extends Node

var player : Player
@onready var alchemon: Node3D = $".."


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	alchemon.global_position = player.global_position + Vector3(2,0,0)
	
