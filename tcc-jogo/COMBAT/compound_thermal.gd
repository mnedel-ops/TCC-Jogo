class_name CompoundThermal
extends Resource
## Dados térmicos de UM Composto (vínculo iônico ou covalente).
## Pertencem ao vínculo, não às criaturas: ficam em CombatState.compound_thermals,
## indexados pelo id do participante ativo. Os participantes não têm temperatura
## individual enquanto o vínculo existe.

@export var active_id: int = -1
@export var member_ids: Array[int] = []
@export var is_ionic: bool = false
## Soma das massas atômicas dos participantes.
@export var total_mass: float = 1.0
## Resistência térmica (parâmetro de jogo por tipo de ligação).
@export var specific_heat: float = 1.0
## Temperatura interna compartilhada (K). Independe da temperatura da arena.
@export var temperature: float = 0.0
@export var melting_point: float = 0.0
@export var boiling_point: float = 0.0
## Limite absoluto: temperature >= scission_temperature rompe o vínculo.
@export var scission_temperature: float = 0.0
## Surto térmico: |dT| de um único ataque acima disto rompe o vínculo.
@export var max_delta_t: float = 0.0
@export var physical_state: String = AlchemonSheet.SOLIDO
@export var previous_physical_state: String = AlchemonSheet.SOLIDO


## Sólido: T < fusão. Líquido: fusão <= T < ebulição. Gasoso: T >= ebulição.
func state_at(t: float) -> String:
	if t < melting_point:
		return AlchemonSheet.SOLIDO
	if t < boiling_point:
		return AlchemonSheet.LIQUIDO
	return AlchemonSheet.GASOSO


## Põe a temperatura interna em t e alinha estado atual/anterior (sem dano).
func reset_temperature(t: float) -> void:
	temperature = t
	physical_state = state_at(t)
	previous_physical_state = physical_state


func reached_scission_temperature() -> bool:
	return temperature >= scission_temperature


func is_thermal_surge(delta_t: float) -> bool:
	return absf(delta_t) > max_delta_t
