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
			if not died:
				died = _apply_thermal_hit(state, database, result.target_id, result.thermal_energy, result.actor_id)
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

## Calor do alvo. Fora de Composto: temperatura individual. Em Composto: temperatura
## do vínculo (_apply_compound_thermal_hit). Devolve true se o alvo morreu.
static func _apply_thermal_hit(state: CombatState, database: AlchemonDatabase, target_id: int, q: float, actor_id: int = -1) -> bool:
	var target := state.get_combatant(target_id)
	if target == null or not target.alive:
		return false
	if target.bond_kind == BondRules.COMPOUND:
		return _apply_compound_thermal_hit(state, database, target, q, actor_id)
	if not ThermalRules.applies_to(target):
		return false
	var sheet := database.get_by_id(target.species_id)
	if sheet == null:
		return false
	var previous := target.physical_state
	var damage := ThermalRules.heat(target, sheet, q)
	if target.physical_state != previous:
		target.arena_hotter_than_myself.emit(target.slot)
	if damage <= 0:
		return false
	return _apply_damage(state, target_id, damage)


## Calor num Composto: aquece o vínculo, aplica o dano de cada transição cruzada ao
## participante ATIVO (uma vez por transição, sem duplicar nos demais) e, por
## último, executa a cisão uma única vez se T >= T_cisão ou houve surto térmico.
## Mudança de estado físico não altera atributo algum nem chama break_compound.
## Devolve true se o alvo do ataque morreu.
static func _apply_compound_thermal_hit(state: CombatState, database: AlchemonDatabase, target: CombatantState, q: float, actor_id: int) -> bool:
	var th := state.get_compound_thermal(target)
	if th == null or q == 0.0:
		return false
	var active := state.get_combatant(th.active_id)
	if active == null or not active.alive:
		return false

	var info := ThermalRules.compound_heat(th, q)
	var steps: Array = info["steps"]
	var i := 0
	while i < steps.size():
		var dmg := ThermalRules.transition_damage(steps[i], steps[i + 1], active.max_hp, active.level)
		state.thermal_notes.append("O composto sofreu %s (%d de dano em %s)." % [_transition_name(steps[i], steps[i + 1]), dmg, _name_of(database, active)])
		if dmg > 0 and _apply_damage(state, active.id, dmg):
			return active.id == target.id
		i += 2

	if bool(info["scission"]):
		return _compound_scission(state, database, active, target.id, actor_id)
	return false


## Executa a cisão (uma vez) e o choque térmico dos elegíveis. Devolve true se o alvo
## original (target_id) morreu. Mortes de outros participantes dão XP aqui mesmo.
static func _compound_scission(state: CombatState, database: AlchemonDatabase, member: CombatantState, target_id: int, actor_id: int) -> bool:
	var info := BondRules.thermal_scission(state, database, member)
	if info.is_empty():
		return false
	state.thermal_notes.append("O composto rompeu a %.0fK! Sobrecarga Térmica por %d turnos." % [float(info["temperature"]), ThermalRules.OVERLOAD_TURNS])
	var target_died := false
	for id in info["shocked_ids"]:
		var c := state.get_combatant(id)
		state.thermal_notes.append("Choque térmico em %s (%d de dano)." % [_name_of(database, c), ThermalRules.THERMAL_SHOCK_DAMAGE])
		if _apply_damage(state, id, ThermalRules.THERMAL_SHOCK_DAMAGE):
			if id == target_id:
				target_died = true
			elif actor_id >= 0:
				_grant_xp(state, database, actor_id, id)
	return target_died


static func _transition_name(from_state: String, to_state: String) -> String:
	match "%s>%s" % [from_state, to_state]:
		"solido>liquido":
			return "fusão"
		"liquido>gasoso":
			return "ebulição"
		"gasoso>liquido":
			return "condensação"
		"liquido>solido":
			return "solidificação"
	return "mudança de estado"


static func _name_of(database: AlchemonDatabase, c: CombatantState) -> String:
	var sheet := database.get_by_id(c.species_id) if c != null else null
	return sheet.creature_name if sheet != null else "?"


static func _apply_arena_heat(state: CombatState, database: AlchemonDatabase) -> void:
	var all_ids: Array[int] = state.player_ids + state.enemy_ids
	var exceeded: Dictionary = {}
	var broken_compounds: Array[CombatantState] = []

	for id in state.get_alive_ids(all_ids):
		var c := state.get_combatant(id)
		# Individuais usam ThermalRules.heat; Compostos têm temperatura própria,
		# independente da arena. Nada a fazer aqui por enquanto.
		if ThermalRules.applies_to(c) or c.bond_kind == BondRules.COMPOUND:
			continue
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


## XP = ((a*b*L)/5)/2 (ver AlchemonGrowth.xp_for_defeat). Concede a XP do derrotado a todas as criaturas vivas do lado de quem agiu
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
	var xp := AlchemonGrowth.xp_for_defeat(state.is_trainer_battle, defeated_template.xp_reward, defeated.level)
	var side_ids: Array[int] = state.player_ids if actor.is_player else state.enemy_ids

	for id in side_ids:
		var receiver := state.get_combatant(id)
		if receiver == null or not receiver.alive:
			continue
		var receiver_template := database.get_by_id(receiver.species_id)
		if receiver_template == null:
			continue
		AlchemonGrowth.grant_experience(receiver, receiver_template, xp)
