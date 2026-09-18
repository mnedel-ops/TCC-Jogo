extends Node3D
class_name Level

@export var npc_scene: PackedScene
@onready var NPCHolder_guy: Node = $NPCHolder

signal existo

func _ready() -> void:
	put_npcs()

func put_npcs() -> void:
	var placement = NPCHolder_guy.get_children()
	
	var npc_scene_guy := npc_scene.instantiate()
	npc_scene_guy.position = placement[2].position as Vector3
	npc_scene_guy.alchemon1 = placement[2].alchemons_ids[0]
	npc_scene_guy.alchemon2 = placement[2].alchemons_ids[1]
	npc_scene_guy.figther=true
	NPCHolder_guy.add_child(npc_scene_guy)
	existo.emit()
