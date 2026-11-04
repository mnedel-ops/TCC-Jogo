class_name AlchemonSheet
extends Resource


const SOLIDO := "solido"
const LIQUIDO := "liquido"
const GASOSO := "gasoso"

@export var id: int = -1
@export var creature_name: String = ""
@export_range(0, 999) var atomic_mass: int = 0
@export_multiline var description: String = ""
@export_multiline var lore: String = ""
@export var found_at: String = ""
@export var likes: String = ""
@export var dislikes: String = ""
@export var max_hp: int = 30
@export var hp: int = 30

@export var max_valence_electrons: int = 8
@export var octet_target: int = 8
@export var base_attack: int = 70
@export var base_defense: int = 70
@export var base_mechanical_speed: int = 70
@export var base_action_energy: int = 8

@export var xp_reward: int = 100

@export var physical_state: String = SOLIDO
@export var temperature: float = 298.15
@export var boiling_point: float = 373.15

@export var element_type: AlchemonType.Type = AlchemonType.Type.METAL

@export var attacks: Array[AttackData] = []

@export var model: PackedScene

func _init(p_name: String = "", p_max_hp: int = 30, p_id_or_is_player: Variant = -1, legacy_id: Variant = null) -> void:
	if legacy_id != null:
		id = int(legacy_id)
	else:
		id = int(p_id_or_is_player)
	creature_name = p_name
	max_hp = p_max_hp
	hp = p_max_hp
	
func state_at(arena_temperature: float) -> String:
	if arena_temperature <= temperature:
		return SOLIDO
	if arena_temperature <= boiling_point:
		return LIQUIDO
	return GASOSO
