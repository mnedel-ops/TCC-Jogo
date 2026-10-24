class_name CombatStateFactory
extends RefCounted

## Constroi um CombatState inicial a partir do database + listas de species_id.
## Nao decide regra de combate (isso e CombatRules); so monta estado inicial.
## Tambem aloca slots iniciais no battlefield via BattlefieldRules.
const DEFAULT_ENEMY_LEVEL := 1
## player_bond = the Component the player made at the PC (null = none).
## Player NEVER auto-bonds here. Enemies (NPC) do, automatically.
static func build(database: AlchemonDatabase, player_party: Array[AlchemonInstance], enemy_species_ids: Array[int], enemy_level: int = -1, player_bond: PlayerBondData = null) -> CombatState:
	var state := CombatState.new()
	var next_instance_id := 0
	var player_slot_index := 0
	var enemy_slot_index := 0

	# Create player combatants and assign slots
	for instance in player_party:
		if instance == null:
			continue
		var template := database.get_by_id(instance.species_id)
		if template == null:
			continue

		var slot := BattlefieldSlot.PLAYER_SLOT_1 + player_slot_index
		if player_slot_index >= 2:
			push_warning("Too many players for battlefield (max 2 slots)")
			break

		instance.ensure_uid()
		if instance.is_fainted() and CreatureSync.REVIVE_FAINTED_ON_BATTLE_START:
			instance.current_hp = AlchemonInstance.UNSET   # = full, see CreatureSync
		elif instance.is_fainted():
			continue   # stays KO'd, cannot fight

		var c := _combatant_from(next_instance_id, instance, template, true, slot)
		state.combatants[c.id] = c
		state.player_ids.append(c.id)
		BattlefieldRules.assign_combatant(state.battlefield, c.id, slot)
		next_instance_id += 1
		player_slot_index += 1

	# Create enemy combatants and assign slots
	for species_id in enemy_species_ids:
		var template := database.get_by_id(species_id)
		if template == null:
			continue

		var slot := BattlefieldSlot.ENEMY_SLOT_1 + enemy_slot_index
		if enemy_slot_index >= 2:
			push_warning("Too many enemies for battlefield (max 2 slots)")
			break

		# Wild/NPC creatures are real individuals too (IV, personality), so a
		# capture can keep exactly what was fought.
		var lvl := enemy_level if enemy_level >= 1 else DEFAULT_ENEMY_LEVEL
		var enemy_inst := CreatureFactory.create(species_id, lvl)
		var c := _combatant_from(next_instance_id, enemy_inst, template, false, slot)
		state.combatants[c.id] = c
		state.enemy_ids.append(c.id)
		state.enemy_instances[c.id] = enemy_inst
		BattlefieldRules.assign_combatant(state.battlefield, c.id, slot)
		next_instance_id += 1
		enemy_slot_index += 1

	# Player: bond comes from the PC (PlayerBondData). No auto-bond.
	_apply_player_bond(state, database, player_bond)
	# NPC / enemies: automatic.
	_try_bond(state, database, state.enemy_ids)
	
	for id in state.player_ids + state.enemy_ids:
		var c := state.get_combatant(id)
		var t := database.get_by_id(c.species_id)
		if t != null:
			c.physical_state = t.state_at(state.arena_temperature)
	
	return state
	

## Applies the bond the player made at the PC. Skips (with warning) if the
## data is stale instead of crashing the fight.
static func _apply_player_bond(state: CombatState, database: AlchemonDatabase, bond: PlayerBondData) -> void:
	if bond == null or not bond.is_active():
		return
	var parts: Array[CombatantState] = []
	var sheets: Array[AlchemonSheet] = []
	for i in bond.member_indices:
		if i < 0 or i >= state.player_ids.size():
			push_warning("PlayerBondData: member index %d not in party. Bond skipped." % i)
			return
		var c := state.get_combatant(state.player_ids[i])
		var sheet := database.get_by_id(c.species_id)
		if sheet == null:
			return
		parts.append(c)
		sheets.append(sheet)
	if AlchemyStation.determine_bond_kind(sheets) != bond.kind:
		push_warning("PlayerBondData out of date (kind no longer valid). Bond skipped.")
		return
	BondRules.apply_bond(bond.kind, parts, sheets)


static func _try_bond(state: CombatState, database: AlchemonDatabase, ids: Array) -> void:
	if ids.size() != 2:
		return
	var c0 := state.get_combatant(ids[0])
	var c1 := state.get_combatant(ids[1])
	var sheets: Array[AlchemonSheet] = [database.get_by_id(c0.species_id), database.get_by_id(c1.species_id)]
	var kind := AlchemyStation.determine_bond_kind(sheets)
	if kind != BondRules.NONE:
		BondRules.apply_bond(kind, [c0, c1], sheets)

## instance -> battle state. Stats come ONLY from instance.compute_stats(), so
## there is one formula path for player, enemy and every UI screen.
static func _combatant_from(id: int, instance: AlchemonInstance, template: AlchemonSheet, is_player: bool, slot: int) -> CombatantState:
	var stats := instance.compute_stats(template)
	var c := CombatantState.new(id, instance.species_id, stats.max_hp, is_player, slot, template.max_valence_electrons)
	c.source_uid = instance.uid
	c.level = instance.level
	c.experience = instance.experience
	c.individual_value = instance.individual_value
	c.max_hp = stats.max_hp
	c.hp = instance.hp_or_full(stats.max_hp)
	c.attack = stats.attack
	c.defense = stats.defense
	c.mechanical_speed = stats.mechanical_speed
	c.action_energy = stats.action_energy
	c.temperature = template.temperature
	if CreatureSync.PERSIST_ENERGY and instance.current_energy != AlchemonInstance.UNSET:
		c.valence_electrons = clampi(instance.current_energy, 0, c.max_valence_electrons)
	return c
