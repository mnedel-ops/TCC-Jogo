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
		npc_scene_guy.dialogue = marker.dialogue
		npc_scene_guy.dialogue_defeated = marker.dialogue_defeated
		npc_scene_guy.dialogue_healed = marker.dialogue_healed
		npc_scene_guy.is_shopkeeper = marker.is_shopkeeper
		npc_scene_guy.is_healer = marker.is_healer
		var has_role := marker.is_shopkeeper or marker.is_healer
		if has_role and marker.is_fighter:
			push_warning("%s: shopkeeper/healer and is_fighter both on. No fight." % id)
		if marker.is_shopkeeper and marker.is_healer:
			push_warning("%s: is_shopkeeper and is_healer both on. Shopkeeper wins." % id)
		var fights := (marker.is_fighter or marker.is_gym_trainer) and not has_role
		npc_scene_guy.is_gym_trainer = fights and marker.is_gym_trainer
		npc_scene_guy.badge = marker.badge
		npc_scene_guy.is_trainer = fights
		npc_scene_guy.figther = fights and not GameSession.is_npc_defeated(id)
		if npc_scene_guy.figther:
			npc_scene_guy.alchemon1 = marker.alchemons_ids[0] if marker.alchemons_ids.size() > 0 else -1
			npc_scene_guy.alchemon2 = marker.alchemons_ids[1] if marker.alchemons_ids.size() > 1 else -1
			npc_scene_guy.alchemon_level = marker.level
		
		NPCHolder_guy.add_child(npc_scene_guy)
		existo.emit()


func npc_id_for(marker: NPCSpawnPoint) -> String:
	var root: Node = owner if owner != null else get_parent()
	var level_name := root.scene_file_path.get_file().get_basename()
	if level_name == "":
		level_name = String(root.name)
	return "%s/%s" % [level_name, marker.name]
