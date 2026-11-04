class_name BattlePhaseRules
extends RefCounted


const ENCOUNTER_START := BattlePhaseMachine.ENCOUNTER_START
const SELECTING_ACTIONS := BattlePhaseMachine.SELECTING_ACTIONS
const RESOLVING_ACTIONS := BattlePhaseMachine.RESOLVING_ACTIONS
const END_OF_ROUND := BattlePhaseMachine.END_OF_ROUND
const COMBAT_OVER := BattlePhaseMachine.COMBAT_OVER
const VICTORY := BattlePhaseMachine.VICTORY
const DEFEAT := BattlePhaseMachine.DEFEAT


static func is_terminal_phase(phase: String) -> bool:
	return BattlePhaseMachine.is_terminal_phase(phase)


static func is_valid_transition(from_phase: String, to_phase: String) -> bool:
	return BattlePhaseMachine.is_valid_transition(from_phase, to_phase)
