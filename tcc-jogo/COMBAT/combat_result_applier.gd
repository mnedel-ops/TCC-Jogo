class_name CombatResultApplier
extends RefCounted


const STATE_CHANGE_DAMAGE :int= 5
static func apply(state: CombatState, result: CombatResult, database: AlchemonDatabase) -> void:
	match result.outcome:
		CombatResult.Outcome.ATTACK_HIT:
			_apply_energy_cost(state, result.actor_id, result.energy_cost)
			state.arena_temperature += result.temperature_delta
			_apply_arena_heat(state, database)
			var died := _apply_damage(state, result.target_id, result.damage)
			if died:
				_grant_xp(state, database, result.actor_id, result.target_id)
		CombatResult.Outcome.ITEM_USED:
			_apply_heal(state, result.target_id, result.amount)
		CombatResult.Outcome.ATTACK_MISS:
			_apply_energy_cost(state, result.actor_id, result.energy_cost)
		CombatResult.Outcome.CAPTURE_SUCCESS:
			_apply_capture(state, result.target_id, database)
			_grant_xp(state, database, result.actor_id, result.target_id)
		_:
			pass

	CombatRules.check_combat_end(state)


static func _apply_energy_cost(state: CombatState, actor_id: int, cost: int) -> void:
	var actor := state.get_combatant(actor_id)
	if actor != null:
		actor.valence_electrons = maxi(actor.valence_electrons - cost, 0)


static func _apply_damage(state: CombatState, target_id: int, damage: int) -> bool:
	var target := state.get_combatant(target_id)
	if target == null or not target.alive:
		return false
	target.hp = maxi(target.hp - damage, 0)
	if target.hp == 0:
		_kill(state, target)
		return true
	return false


static func _apply_heal(state: CombatState, target_id: int, amount: int) -> void:
	var target := state.get_combatant(target_id)
	if target == null or not target.alive:
		return
	target.hp = mini(target.hp + amount, target.max_hp)

static func _apply_capture(state: CombatState, target_id: int, database: AlchemonDatabase) -> void:
	var target := state.get_combatant(target_id)
	if target == null or not target.alive:
		return
	var inst: AlchemonInstance = state.enemy_instances.get(target_id)
	var template := database.get_by_id(target.species_id)
	if inst == null:
		inst = CreatureFactory.create(target.species_id, target.level)
	if template != null:
		CreatureSync.write_back(inst, target, template)
	inst.current_hp = maxi(inst.current_hp, 1)
	state.captured_instances.append(inst)
	target.hp = 0
	_kill(state, target)


static func _kill(state: CombatState, target: CombatantState) -> void:
	target.alive = false
	state.battlefield.free_slot(target.slot)
	BondRules.release_compound_partners(state, target)

static func _apply_arena_heat(state: CombatState, database: AlchemonDatabase) -> void:
	var all_ids: Array[int] = state.player_ids + state.enemy_ids
	var exceeded: Dictionary = {}
	var broken_compounds: Array[CombatantState] = []

	for id in state.get_alive_ids(all_ids):
		var c := state.get_combatant(id)
		var template := database.get_by_id(c.species_id)
		if template == null:
			continue
		var new_state := template.state_at(state.arena_temperature)
		if new_state == c.physical_state:
			continue
		var points := template.transformation_points_exceeded(c.physical_state, new_state)
		c.physical_state = new_state
		c.arena_hotter_than_myself.emit(c.slot)
		if points <= 0:
			continue
		exceeded[id] = points
		if c.bond_kind == BondRules.COMPOUND:
			broken_compounds.append(c)

	for c in broken_compounds:
		BondRules.break_compound(state, c)

	for id in exceeded:
		_apply_damage(state, id, STATE_CHANGE_DAMAGE * int(exceeded[id]))


## Concede a XP do derrotado a todas as criaturas vivas do lado de quem agiu
## (as duas criaturas do time ganham, não só a que deu o golpe/captura).
static func _grant_xp(state: CombatState, database: AlchemonDatabase, actor_id: int, defeated_id: int) -> void:
	var defeated := state.get_combatant(defeated_id)
	if defeated == null:
		return
	var defeated_template := database.get_by_id(defeated.species_id)
	if defeated_template == null:
		return

	var actor := state.get_combatant(actor_id)
	if actor == null:
		return
	var side_ids: Array[int] = state.player_ids if actor.is_player else state.enemy_ids

	for id in side_ids:
		var receiver := state.get_combatant(id)
		if receiver == null or not receiver.alive:
			continue
		var receiver_template := database.get_by_id(receiver.species_id)
		if receiver_template == null:
			continue
		AlchemonGrowth.grant_experience(receiver, receiver_template, defeated_template.xp_reward)
