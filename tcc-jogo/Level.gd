extends Node3D
class_name Level

@export var npc_scene: PackedScene
@onready var NPCHolder_guy: Node = $NPCHolder
#func get_npc_spawn_points() -> Array[NPCSpawnPoint]:

func _ready() -> void:
	put_npcs()

func put_npcs() -> void:
	var placement = NPCHolder_guy.get_children()
	print(placement[2])
	
	var npc_scene_guy := npc_scene.instantiate()
	npc_scene_guy.position = placement[2].position as Vector3
	npc_scene_guy.alchemon1 = 0
	npc_scene_guy.alchemon2 = 0
	npc_scene_guy.figther=true
	NPCHolder_guy.add_child(npc_scene_guy)
	
