extends Node

@export var entityholder: Node3D
var npc_guy: PackedScene = load("res://EXPLORATION/npc.tscn")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	npc_spawner()

func npc_spawner():
	var npc_instant = npc_guy.instantiate()
	entityholder.add_child(npc_instant)
