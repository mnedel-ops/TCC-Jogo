extends Marker3D
class_name NPCSpawnPoint
@export var npc_scene: PackedScene
@export var alchemons_ids: Array[int] = []
@export_range(1, 100) var level: int = 1
@export var is_fighter :bool= false
@export var is_gym_trainer: bool = false
@export var badge: BadgeData
@export var is_shopkeeper: bool = false
@export var is_healer: bool = false

@export_group("Dialogue")
@export_multiline var dialogue: String = ""
@export_multiline var dialogue_defeated: String = ""
@export_multiline var dialogue_healed: String = ""
