class_name AlchemonSheet
extends Resource
## Ficha de uma espécie de Alchemon: dados fixos (identidade, stats base,
## propriedades químicas e físicas). Valores por criatura (nível, XP, HP atual)
## ficam em AlchemonInstance.

const SOLIDO := "solido"
const LIQUIDO := "liquido"
const GASOSO := "gasoso"

enum Category { AUTO, METAL, AMETAL, METALOIDE, GAS_NOBRE }


@export_group("Identidade")
## Identificador único da espécie no banco de dados.
@export var id: int = -1
## Nome exibido da espécie.
@export var creature_name: String = ""
## Massa atômica do elemento (u).
@export_range(0, 999) var atomic_mass: int = 0
## Descrição curta mostrada na interface.
@export_multiline var description: String = ""
## Texto de ambientação (história da espécie).
@export_multiline var lore: String = ""
## Local onde a espécie pode ser encontrada.
@export var found_at: String = ""
## Preferências positivas da espécie.
@export var likes: String = ""
## Preferências negativas da espécie.
@export var dislikes: String = ""
## Cena 3D usada para exibir a criatura.
@export var model: PackedScene


@export_group("Atributos base")
## HP base. O HP real da criatura é calculado a partir dele, do IV e do nível
## (mesma fórmula do ataque: AlchemonFormulas.compute_stat).
@export var base_hp: int = 30
## Ataque base. Escala o dano causado.
@export var base_attack: int = 70
## Defesa base. Reduz o dano recebido.
@export var base_defense: int = 70
## Velocidade mecânica base. Define a iniciativa no combate.
@export var base_mechanical_speed: int = 70
## Energia de ação base. Escala a energia de ação da criatura com o nível.
@export var energia_de_acao: int = 8
## Limite de energia gasta pelos golpes no combate (Mistura/Composto somam nele).
## Não é a valência química: ver valence_electrons.
@export var max_valence_electrons: int = 8
## XP concedida a quem derrota ou captura esta espécie.
@export var xp_reward: int = 100


@export_group("Propriedades químicas")
## Número atômico. 0 = não definido (usa o id da espécie como identidade).
@export_range(0, 118) var atomic_number: int = 0
## Símbolo químico usado nas fórmulas (ex.: "Mg"). Vazio = usa creature_name.
@export var symbol: String = ""
## Elétrons na camada de valência (propriedade química). -1 = usa max_valence_electrons.
@export var valence_electrons: int = -1
## Total de elétrons que completa a camada de valência (regra do octeto, máx. 8).
@export var octet_target: int = 8
## Eletronegatividade (escala de Pauling). 0 = deriva da categoria.
@export var electronegativity: float = 0.0
## Estados de oxidação possíveis. O primeiro é o preferido (ex.: Fe -> [3, 2]).
## Vazio = deriva da valência.
@export var oxidation_states: Array[int] = []
## Quantas ligações o elemento aceita fazer. -1 = deriva da valência.
@export var bonding_capacity: int = -1
## Categoria do elemento na tabela periódica. AUTO = deriva do tipo e da valência.
@export var element_category: Category = Category.AUTO
## Tipo de combate do elemento (metal, ametal, metaloide).
@export var element_type: AlchemonType.Type = AlchemonType.Type.METAL


@export_group("Propriedades físicas")
## Ponto de fusão em kelvin. Em temperaturas até ele, a criatura é sólida.
@export var melting_point: float = 298.15
## Ponto de ebulição em kelvin. Acima dele, a criatura é gasosa.
@export var boiling_point: float = 373.15


@export_group("Combate")
## Golpes que a espécie conhece e pode aprender.
@export var attacks: Array[AttackData] = []


func _init(p_name: String = "", p_base_hp: int = 30, p_id: int = -1) -> void:
	creature_name = p_name
	base_hp = p_base_hp
	id = p_id


## Estado físico na temperatura da arena (em kelvin).
func state_at(arena_temperature: float) -> String:
	if arena_temperature <= melting_point:
		return SOLIDO
	if arena_temperature <= boiling_point:
		return LIQUIDO
	return GASOSO


static func state_rank(state: String) -> int:
	match state:
		LIQUIDO:
			return 1
		GASOSO:
			return 2
	return 0


## Quantos estados a criatura avançou (sólido -> líquido -> gasoso). Nunca negativo.
func transformation_points_exceeded(from_state: String, to_state: String) -> int:
	return maxi(state_rank(to_state) - state_rank(from_state), 0)


# ---------------------------------------------------------------------------
# Propriedades químicas efetivas (valores não definidos caem num padrão derivado)
# ---------------------------------------------------------------------------

## Identidade do elemento: número atômico, ou o id da espécie se não definido.
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


## Mensagem de erro se os dados químicos forem incoerentes; "" se estiver ok.
func chemistry_problem() -> String:
	if octet_target > 8 or octet_target < 1:
		return "%s breaks the octet limit (max 8)." % creature_name
	var v := chem_valence()
	if v < 0 or v > octet_target:
		return "%s has an invalid valence shell." % creature_name
	return ""
