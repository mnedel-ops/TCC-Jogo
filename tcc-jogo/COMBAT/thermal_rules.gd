class_name ThermalRules
extends RefCounted
## Mecânica térmica de Alchemons FORA de Composto.
## Cada criatura tem temperatura e estado físico próprios. Ataque que acerta
## injeta energia térmica Q no alvo: dT = Q / (m * cp). Cruzar um ponto de
## transição causa dano direto uma única vez. Não há bônus/penalidade de
## atributos por estado físico: só o dano de transição.

## Fator de escala jogo: converte o "valor térmico" do golpe em energia Q.
## Parâmetro de balanceamento (sem ele dT seria desprezível frente a pontos em K).
const ENERGY_SCALE := 1000.0

## [percentual de HP máx (inteiro), fator por nível x10 (inteiro)] por transição.
## Inteiros evitam erro de ponto flutuante no arredondamento para baixo.
const TRANSITIONS := {
	"solido>liquido": [10, 10],  # Fusão
	"liquido>gasoso": [20, 20],  # Ebulição
	"gasoso>liquido": [15, 15],  # Condensação
	"liquido>solido": [10, 10],  # Solidificação
}


## Conta se a criatura está fora de Composto (única que usa esta rotina).
static func applies_to(c: CombatantState) -> bool:
	return c != null and c.bond_kind != BondRules.COMPOUND


## dT = Q / (m * cp). Q negativo = resfriamento.
static func delta_temperature(q: float, mass: float, specific_heat: float) -> float:
	return q / (maxf(mass, 0.0001) * maxf(specific_heat, 0.0001))


## Dano de uma transição: floor(pct * HPmax + nivel * fator). Sobre HP MÁXIMO.
@warning_ignore("integer_division")
static func transition_damage(from_state: String, to_state: String, max_hp: int, level: int) -> int:
	var key := "%s>%s" % [from_state, to_state]
	if not TRANSITIONS.has(key):
		return 0
	var p: Array = TRANSITIONS[key]
	return (max_hp * int(p[0]) + level * int(p[1]) * 10) / 100


## Sequência de transições entre dois estados (sólido->gasoso = fusão + ebulição).
static func transition_path(from_state: String, to_state: String) -> Array[String]:
	var order := [AlchemonSheet.SOLIDO, AlchemonSheet.LIQUIDO, AlchemonSheet.GASOSO]
	var a: int = order.find(from_state)
	var b: int = order.find(to_state)
	var path: Array[String] = []
	if a < 0 or b < 0 or a == b:
		return path
	var step := 1 if b > a else -1
	var i := a
	while i != b:
		path.append(order[i])
		i += step
		path.append(order[i])
	return path


## Esfria/aquece a criatura em dT e aplica as transições. Devolve o dano total
## calculado (a aplicação em HP é feita por quem chama, com piso em zero).
## Atualiza temperatura, estado anterior/atual e flags de perfil.
static func heat(c: CombatantState, sheet: AlchemonSheet, q: float) -> int:
	if not applies_to(c) or sheet == null or q == 0.0:
		return 0
	c.temperature += delta_temperature(q, float(sheet.atomic_mass), sheet.specific_heat)
	var new_state := sheet.state_at(c.temperature)
	if new_state == c.physical_state:
		return 0
	c.previous_physical_state = c.physical_state
	var path := transition_path(c.physical_state, new_state)
	var total := 0
	var i := 0
	while i < path.size():
		total += transition_damage(path[i], path[i + 1], c.max_hp, c.level)
		i += 2
	c.physical_state = new_state
	return total
