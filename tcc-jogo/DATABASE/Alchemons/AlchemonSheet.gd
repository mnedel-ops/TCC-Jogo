class_name AlchemonSheet
extends Resource

## Dado puro - uma criatura em combate. Sem metodos de regra (take_damage,
## heal etc). Quem manipula esses valores e CombatRules.

const SOLIDO := "solido"
const LIQUIDO := "liquido"
const GASOSO := "gasoso"

@export var id: int = -1
@export var creature_name: String = ""
#Stats
@export var max_hp: int = 30
@export var hp: int = 30
@export var max_valence_electrons: int = 8   # cresce no level-up, mesma formula de sec 7.2 (ainda nao implementada)
@export var octet_target: int = 8            # eletrons de valencia p/ octeto completo (GDD - Regra do Octeto)
# Species/base stats. Per-battle values belong in CombatantState.
@export var base_attack: int = 70
@export var base_defense: int = 70
@export var base_mechanical_speed: int = 70
@export var base_action_energy: int = 8

@export var xp_reward: int = 100

@export var physical_state: String = SOLIDO   # SOLIDO | LIQUIDO | GASOSO - ver sec 8.2 (temperatura da arena)
@export var temperature: float = 298.15 #Temperatura em Kelvin. 
@export var element_type: AlchemonType.Type = AlchemonType.Type.METAL   # tipo da CRIATURA - so importa como defensor (sem STAB)
@export var attacks: Array[AttackData] = []   # ate 4 ataques


func _init(p_name: String = "", p_max_hp: int = 30, p_id_or_is_player: Variant = -1, legacy_id: Variant = null) -> void:
	# Third argument is the species id. Accept prior (name, hp, is_player, id)
	# calls while old tests/assets are migrated.
	if legacy_id != null:
		id = int(legacy_id)
	else:
		id = int(p_id_or_is_player)
	creature_name = p_name
	max_hp = p_max_hp
	hp = p_max_hp

@export var boiling_point: float = 373.15   # K - acima disso: GASOSO

## Estado fisico que esta espécie tem numa arena a `arena_temperature` (GDD 8.2).
## <= temperature (fusao): SOLIDO | <= boiling_point: LIQUIDO | acima: GASOSO
func state_at(arena_temperature: float) -> String:
	if arena_temperature <= temperature:
		return SOLIDO
	if arena_temperature <= boiling_point:
		return LIQUIDO
	return GASOSO
