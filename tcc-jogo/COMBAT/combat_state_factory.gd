class_name CombatStateFactory
extends RefCounted

const DEFAULT_ENEMY_LEVEL := 1
static func build(database: AlchemonDatabase, player_party: Array[AlchemonInstance], enemy_species_ids: Array[int], enemy_level: int = -1, player_bond: PlayerBondData = null) -> CombatState:
	var state := CombatState.new()
	var next_instance_id := 0
	var player_slot_index := 0
	var enemy_slot_index := 0
	var party_to_combatant := {}
	var bonded_positions := _bonded_positions(player_bond, player_party.size())

	for party_pos in player_party.size():
		var instance := player_party[party_pos]
		if instance == null:
			continue
		var template := database.get_by_id(instance.species_id)
		if template == null:
			continue

		var slot := BattlefieldSlot.PLAYER_SLOT_1 + player_slot_index
		if player_slot_index >= 2:
			if not bonded_positions.has(party_pos):
				push_warning("Too many players for battlefield (max 2 slots)")
				continue
			slot = -1

		instance.ensure_uid()
		if instance.is_fainted() and CreatureSync.REVIVE_FAINTED_ON_BATTLE_START:
			instance.current_hp = AlchemonInstance.UNSET
		elif instance.is_fainted():
			continue

		var c := _combatant_from(next_instance_id, instance, template, true, slot)
		state.combatants[c.id] = c
		state.player_ids.append(c.id)
		party_to_combatant[party_pos] = c.id
		if slot >= 0:
			BattlefieldRules.assign_combatant(state.battlefield, c.id, slot)
			player_slot_index += 1
		next_instance_id += 1

	for species_id in enemy_species_ids:
		var template := database.get_by_id(species_id)
		if template == null:
			continue

		var slot := BattlefieldSlot.ENEMY_SLOT_1 + enemy_slot_index
		if enemy_slot_index >= 2:
			push_warning("Too many enemies for battlefield (max 2 slots)")
			break

		var lvl := enemy_level if enemy_level >= 1 else DEFAULT_ENEMY_LEVEL
		var enemy_inst := CreatureFactory.create(species_id, lvl)
		var c := _combatant_from(next_instance_id, enemy_inst, template, false, slot)
		state.combatants[c.id] = c
		state.enemy_ids.append(c.id)
		state.enemy_instances[c.id] = enemy_inst
		BattlefieldRules.assign_combatant(state.battlefield, c.id, slot)
		next_instance_id += 1
		enemy_slot_index += 1

	_apply_player_bond(state, database, player_bond, party_to_combatant)
	_try_bond(state, database, state.enemy_ids)
	
	for id in state.player_ids + state.enemy_ids:
		var c := state.get_combatant(id)
		var t := database.get_by_id(c.species_id)
		if t != null:
			c.physical_state = t.state_at(state.arena_temperature)
	
	return state
	

static func _apply_player_bond(state: CombatState, database: AlchemonDatabase, bond: PlayerBondData, party_to_combatant: Dictionary) -> void:
	if bond == null or not bond.is_active():
		return
	var parts: Array[CombatantState] = []
	var sheets: Array[AlchemonSheet] = []
	for i in bond.member_indices:
		if not party_to_combatant.has(i):
			return
		var c := state.get_combatant(party_to_combatant[i])
		var sheet := database.get_by_id(c.species_id)
		if sheet == null:
			return
		parts.append(c)
		sheets.append(sheet)
	if AlchemyStation.determine_bond_kind(sheets) != bond.kind:
		push_warning("PlayerBondData out of date (kind no longer valid). Bond skipped.")
		return
	var result := BondRules.apply_bond(bond.kind, parts, sheets)
	if result.get("kind", "") == "compound_formed":
		_ensure_active_has_slot(state, int(result["active_id"]))


static func _bonded_positions(bond: PlayerBondData, party_size: int) -> Array[int]:
	var out: Array[int] = []
	if bond == null or not bond.is_active():
		return out
	for i in bond.member_indices:
		if i >= 0 and i < party_size:
			out.append(i)
	return out


static func _ensure_active_has_slot(state: CombatState, active_id: int) -> void:
	var active := state.get_combatant(active_id)
	if active == null or active.slot >= 0:
		return
	for id in state.player_ids:
		var c := state.get_combatant(id)
		if c.slot >= 0 and c.bond_kind == BondRules.COMPOUND and c.bond_partner_id == active_id:
			state.battlefield.free_slot(c.slot)
			active.slot = c.slot
			c.slot = -1
			state.battlefield.assign_combatant(active.id, active.slot)
			return


static func _try_bond(state: CombatState, database: AlchemonDatabase, ids: Array) -> void:
	if ids.size() != 2:
		return
	var c0 := state.get_combatant(ids[0])
	var c1 := state.get_combatant(ids[1])
	var sheets: Array[AlchemonSheet] = [database.get_by_id(c0.species_id), database.get_by_id(c1.species_id)]
	var kind := AlchemyStation.determine_bond_kind(sheets)
	if kind != BondRules.NONE:
		BondRules.apply_bond(kind, [c0, c1], sheets)

static func _combatant_from(id: int, instance: AlchemonInstance, template: AlchemonSheet, is_player: bool, slot: int) -> CombatantState:
	var stats := instance.compute_stats(template)
	var c := CombatantState.new(id, instance.species_id, stats.max_hp, is_player, slot, template.max_valence_electrons)
	c.source_uid = instance.uid
	c.level = instance.level
	c.experience = instance.experience
	c.start_level = instance.level
	c.start_experience = instance.experience
	c.individual_value = instance.individual_value
	c.max_hp = stats.max_hp
	c.hp = instance.hp_or_full(stats.max_hp)
	c.attack = stats.attack
	c.defense = stats.defense
	c.mechanical_speed = stats.mechanical_speed
	c.action_energy = stats.action_energy
	c.temperature = template.temperature
	AttackLearning.sanitize_instance(instance, template)
	c.attack_ids.assign(instance.attack_ids)
	if CreatureSync.PERSIST_ENERGY and instance.current_energy != AlchemonInstance.UNSET:
		c.valence_electrons = clampi(instance.current_energy, 0, c.max_valence_electrons)
	return c
