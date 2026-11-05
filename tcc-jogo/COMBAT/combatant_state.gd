class_name CombatantState
extends Resource


signal arena_hotter_than_myself(slot: int)


@export var id: int = -1
@export var species_id: int = -1
@export var source_uid: String = ""
@export var slot: int = -1
@export var hp: int = 0
@export var max_hp: int = 0
@export var valence_electrons: int = 0
@export var max_valence_electrons: int = 0
@export var level: int = 1
@export var experience: int = 0
@export var start_level: int = 1
@export var start_experience: int = 0
@export var individual_value: int = 1
@export var attack: int = 1
@export var defense: int = 1
@export var mechanical_speed: int = 1
@export var action_energy: int = 1
@export var bond_kind: String = BondRules.NONE
@export var bond_partner_id: int = -1
@export var is_bond_cation: bool = false
@export var is_bond_inactive: bool = false
@export var initiative: int = 0
@export var is_player: bool = false
@export var alive: bool = true
@export var physical_state: String = AlchemonSheet.SOLIDO 
@export var temperature: float = 0.00
@export var attack_ids: Array[int] = []
@export var pending_attack_ids: Array[int] = []
@export var learned_attack_ids: Array[int] = []

func _init(
	p_id: int = -1,
	p_species_id: int = -1,
	p_max_hp: int = 0,
	p_is_player: bool = false,
	p_slot: int = -1,
	p_max_valence_electrons: int = 0,
	p_temperature: float = 0.00,
	p_physical_state: String = AlchemonSheet.SOLIDO
) -> void:
	id = p_id
	species_id = p_species_id
	max_hp = p_max_hp
	hp = p_max_hp
	is_player = p_is_player
	slot = p_slot
	max_valence_electrons = p_max_valence_electrons
	valence_electrons = p_max_valence_electrons
	temperature = p_temperature
	physical_state = p_physical_state
