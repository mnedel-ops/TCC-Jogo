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

# max_valence_electrons = limite de ENERGIA no combate (Mistura/Composto somam nele).
# valence_electrons = propriedade QUIMICA, usada so pelas regras de composto.
@export var max_valence_electrons: int = 8
@export var octet_target: int = 8

enum Category { AUTO, METAL, AMETAL, METALOIDE, GAS_NOBRE }

# Propriedades quimicas. Valores "nao definidos" (-1 / vazio / 0 / AUTO) sao
# derivados de max_valence_electrons, octet_target e element_type pelos
# metodos chem_*(), entao os .tres antigos continuam validos sem migracao.
@export_range(0, 118) var atomic_number: int = 0
# Simbolo quimico para a formula (ex.: "Mg"). Vazio = usa creature_name.
@export var symbol: String = ""
@export var valence_electrons: int = -1
@export var electronegativity: float = 0.0
# Primeiro item = estado preferido (ex.: Fe -> [3, 2]).
@export var oxidation_states: Array[int] = []
@export var bonding_capacity: int = -1
@export var element_category: Category = Category.AUTO
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


static func state_rank(physical_state: String) -> int:
	match physical_state:
		LIQUIDO:
			return 1
		GASOSO:
			return 2
	return 0


func transformation_points_exceeded(from_state: String, to_state: String) -> int:
	return maxi(state_rank(to_state) - state_rank(from_state), 0)


# ---------------------------------------------------------------------------
# Propriedades quimicas efetivas (com fallback para os campos legados)
# ---------------------------------------------------------------------------

# Identidade do elemento: numero atomico, ou o id da especie se nao definido.
func element_key() -> int:
	return atomic_number if atomic_number > 0 else -id - 1000


func chem_symbol() -> String:
	return symbol if symbol != "" else creature_name


func chem_valence() -> int:
	return valence_electrons if valence_electrons >= 0 else max_valence_electrons


func chem_category() -> Category:
	if element_category != Category.AUTO:
		return element_category
	if chem_valence() >= octet_target and element_type != AlchemonType.Type.METAL:
		return Category.GAS_NOBRE
	match element_type:
		AlchemonType.Type.METAL:
			return Category.METAL
		AlchemonType.Type.METALOIDE:
			return Category.METALOIDE
	return Category.AMETAL


func is_metal() -> bool:
	return chem_category() == Category.METAL


func chem_capacity() -> int:
	if bonding_capacity >= 0:
		return bonding_capacity
	var cat := chem_category()
	if cat == Category.METAL or cat == Category.GAS_NOBRE:
		return 0
	return maxi(octet_target - chem_valence(), 0)


func chem_oxidation_states() -> Array[int]:
	if not oxidation_states.is_empty():
		return oxidation_states
	var out: Array[int] = []
	match chem_category():
		Category.METAL:
			if chem_valence() > 0:
				out.append(chem_valence())
		Category.AMETAL, Category.METALOIDE:
			var gap := octet_target - chem_valence()
			if gap > 0:
				out.append(-gap)
	return out


func chem_electronegativity() -> float:
	if electronegativity > 0.0:
		return electronegativity
	match chem_category():
		Category.METAL:
			return 1.0
		Category.METALOIDE:
			return 1.9
	return 3.0


# Mensagem de erro se os dados quimicos forem incoerentes; "" se estiver ok.
func chemistry_problem() -> String:
	if octet_target > 8 or octet_target < 1:
		return "%s breaks the octet limit (max 8)." % creature_name
	var v := chem_valence()
	if v < 0 or v > octet_target:
		return "%s has an invalid valence shell." % creature_name
	return ""
