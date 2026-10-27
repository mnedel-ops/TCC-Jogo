extends Node
class_name Level

@export var npc_scene: PackedScene
@onready var NPCHolder_guy: Node = $"."
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
		npc_scene_guy.rotation = marker.rotation as Vector3
		
		var id := npc_id_for(marker)
		npc_scene_guy.npc_id = id
		# Already beaten (loaded save): still spawns and can talk, never fights again.
		npc_scene_guy.figther = marker.is_fighter and not GameSession.is_npc_defeated(id)
		if npc_scene_guy.figther:
			npc_scene_guy.alchemon1 = marker.alchemons_ids[0] if marker.alchemons_ids.size() > 0 else -1
			npc_scene_guy.alchemon2 = marker.alchemons_ids[1] if marker.alchemons_ids.size() > 1 else -1
			npc_scene_guy.alchemon_level = marker.level
		
		NPCHolder_guy.add_child(npc_scene_guy)
		existo.emit()


## "<level scene file name>/<marker name>". Stable across runs as long as the
## marker keeps its name in the level scene. Rename a marker = that NPC fights again.
func npc_id_for(marker: NPCSpawnPoint) -> String:
	var root: Node = owner if owner != null else get_parent()
	var level_name := root.scene_file_path.get_file().get_basename()
	if level_name == "":
		level_name = String(root.name)
	return "%s/%s" % [level_name, marker.name]
