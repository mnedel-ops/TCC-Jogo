class_name ThermalRules
extends RefCounted
## Mecânica térmica.
## Fora de Composto: cada criatura tem temperatura e estado físico próprios.
## Dentro de Composto: a temperatura é do vínculo (ver CompoundThermal e
## compound_heat); só dano de transição, cisão, choque térmico e Sobrecarga.
## Ataque que acerta
## injeta energia térmica Q no alvo: dT = Q / (m * cp). Cruzar um ponto de
## transição causa dano direto uma única vez. Não há bônus/penalidade de
## atributos por estado físico: só o dano de transição.

## Fator de escala jogo: converte o "valor térmico" do golpe em energia Q.
## Parâmetro de balanceamento (sem ele dT seria desprezível frente a pontos em K).
const ENERGY_SCALE := 1000.0

# --- Composto (parâmetros de balanceamento) -------------------------------
## Calor específico do Composto por tipo de ligação. Iônico resiste mais.
const COMPOUND_CP_IONIC := 2.0
const COMPOUND_CP_COVALENT := 1.0
## Limite de surto térmico (|dT| máx. por ataque) por tipo de ligação.
const COMPOUND_MAX_DELTA_T_IONIC := 200.0
const COMPOUND_MAX_DELTA_T_COVALENT := 150.0
## Dano fixo de choque térmico (uma vez por Alchemon por combate).
const THERMAL_SHOCK_DAMAGE := 20
## Turnos completos de Sobrecarga Térmica após a cisão.
const OVERLOAD_TURNS := 2

## [percentual de HP máx (inteiro), fator por nível x10 (inteiro)] por transição.
## Inteiros evitam erro de ponto flutuante no arredondamento para baixo.
const TRANSITIONS := {
	"solido>liquido": [10, 10],  # Fusão
	"liquido>gasoso": [20, 20],  # Ebulição
	"gasoso>liquido": [15, 15],  # Condensação
	"liquido>solido": [10, 10],  # Solidificação
}


## Rótulo em português do estado físico.
static func state_label(physical_state: String) -> String:
	match physical_state:
		AlchemonSheet.LIQUIDO:
			return "líquido"
		AlchemonSheet.GASOSO:
			return "gasoso"
	return "sólido"


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


# ---------------------------------------------------------------------------
# Composto
# ---------------------------------------------------------------------------

## Aquece/esfria o Composto em Q. Atualiza temperatura e estados do vínculo
## (sem tocar em HP nem atributos). Devolve:
##   delta:   dT aplicado;
##   steps:   pares planos [de, para, de, para...] das transições cruzadas, em ordem;
##   scission: true se T >= T_cisão ou |dT| > dT_máx (cisão é decidida por quem chama).
static func compound_heat(th: CompoundThermal, q: float) -> Dictionary:
	var out := {"delta": 0.0, "steps": [] as Array[String], "scission": false}
	if th == null or q == 0.0:
		return out
	var dt := AlchemonFormulas.compound_delta_temperature(q, th.total_mass, th.specific_heat)
	th.temperature += dt
	out["delta"] = dt
	var new_state := th.state_at(th.temperature)
	if new_state != th.physical_state:
		th.previous_physical_state = th.physical_state
		out["steps"] = transition_path(th.physical_state, new_state)
		th.physical_state = new_state
	out["scission"] = th.reached_scission_temperature() or th.is_thermal_surge(dt)
	return out


static func is_overloaded(c: CombatantState) -> bool:
	return c != null and c.thermal_overload_turns > 0


## Chamar ao fim de cada rodada. A rodada em que a Sobrecarga começou não conta:
## assim ela dura duas rodadas completas.
static func tick_overload(state: CombatState) -> void:
	for id in state.combatants:
		var c: CombatantState = state.combatants[id]
		if c.thermal_overload_turns <= 0:
			continue
		if c.thermal_overload_fresh:
			c.thermal_overload_fresh = false
		else:
			c.thermal_overload_turns -= 1
