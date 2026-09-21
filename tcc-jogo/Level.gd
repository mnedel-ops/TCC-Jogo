extends Node3D
class_name Level

@export var npc_scene: PackedScene
@onready var NPCHolder_guy: Node = $NPCHolder
var Spawn_Array: Array[NPCSpawnPoint]

signal existo

func _ready() -> void:
	put_npcs()

func put_npcs() -> void:
	for i in NPCHolder_guy.get_children():
		if i is NPCSpawnPoint:
			Spawn_Array.append(i)
		
	place_npcs()
	
func  place_npcs():
	for marker:NPCSpawnPoint in Spawn_Array:
		var npc_scene_guy := npc_scene.instantiate()
		
		npc_scene_guy.position = marker.position as Vector3
		npc_scene_guy.alchemon1 = marker.alchemons_ids[0]
		npc_scene_guy.alchemon2 = marker.alchemons_ids[1]
		
		npc_scene_guy.figther=true
		NPCHolder_guy.add_child(npc_scene_guy)
		existo.emit()
