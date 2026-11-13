class_name CombatState
extends Resource


@export var combatants: Dictionary = {}
@export var player_ids: Array[int] = []
@export var enemy_ids: Array[int] = []
@export var turn_order_ids: Array[int] = []
@export var pending_actions: Array[ActionCommand] = []

@export var phase: String = BattlePhaseRules.ENCOUNTER_START
@export var combat_over: bool = false
@export var player_won: bool = false

@export var arena_temperature: float = 273.15
var is_trainer_battle: bool = false
var enemy_instances: Dictionary = {}
var captured_instances: Array[AlchemonInstance] = []

var battlefield: Battlefield
var battle_phase: BattlePhaseMachine


func _init() -> void:
	battlefield = Battlefield.new()
	battle_phase = BattlePhaseMachine.new()
	phase = BattlePhaseRules.ENCOUNTER_START


func get_combatant(id: int) -> CombatantState:
	return combatants.get(id)


func get_team_ids(is_player: bool) -> Array[int]:
	return player_ids if is_player else enemy_ids


func get_alive_ids(ids: Array[int]) -> Array[int]:
	var alive_ids: Array[int] = []
	for id in ids:
		var c := get_combatant(id)
		if c != null and c.alive:
			alive_ids.append(id)
	return alive_ids


func get_active_ids(ids: Array[int]) -> Array[int]:
	var active_ids: Array[int] = []
	for id in get_alive_ids(ids):
		var c := get_combatant(id)
		if c.bond_kind == BondRules.COMPOUND and (c.is_bond_cation or c.is_bond_inactive):
			continue
		active_ids.append(id)
	return active_ids


func get_alive_opposing_combatants(is_player: bool) -> Array[int]:
	var opposing_ids := BattlefieldRules.get_opposing_combatants(battlefield, is_player)
	return get_active_ids(opposing_ids)


func get_valid_targets(actor_id: int) -> Array[int]:
	var actor := get_combatant(actor_id)
	if actor == null:
		return []
	return get_alive_opposing_combatants(actor.is_player)

func get_temperature(id: int):
	var actor := get_combatant(id)
	if arena_temperature > actor.temperature:
		print_debug("Alguem mudou", id)
		print_debug(actor.physical_state)
