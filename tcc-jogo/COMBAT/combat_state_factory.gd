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
		var template := database.get_by_id(instance.species_id)
		if template == null:
			continue

		var slot := BattlefieldSlot.PLAYER_SLOT_1 + player_slot_index
		if player_slot_index >= 2:
			push_warning("Too many players for battlefield (max 2 slots)")
			break
# If current_hp hasn't been set yet (or was defaulted to -1), initialize it to max_hp
		if instance.current_hp <= 0:
			instance.current_hp = template.max_hp
			
		var c := CombatantState.new(next_instance_id, instance.species_id, instance.current_hp, true, slot, template.max_valence_electrons)
		
		_seed_player_stats(c, template, instance)
		
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

		var c := CombatantState.new(next_instance_id, species_id, template.max_hp, false, slot, template.max_valence_electrons)
		_seed_enemy_stats(c, template, enemy_level)
		state.combatants[c.id] = c
		state.enemy_ids.append(c.id)
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

static func _seed_player_stats(combatant: CombatantState, template: AlchemonSheet, instance: AlchemonInstance) -> void:
	combatant.level = instance.level
	combatant.experience = instance.experience
	combatant.individual_value = instance.individual_value
	
	combatant.max_hp = template.max_hp
	combatant.temperature = template.temperature

	# _seed_player_stats
	combatant.attack = AlchemonFormulas.compute_stat(template.base_attack, combatant.individual_value, combatant.level)
	combatant.defense = AlchemonFormulas.compute_stat(template.base_defense, combatant.individual_value, combatant.level)
	combatant.mechanical_speed = AlchemonFormulas.compute_stat(template.base_mechanical_speed, combatant.individual_value, combatant.level)
	combatant.action_energy = AlchemonFormulas.compute_stat(template.base_action_energy, combatant.individual_value, combatant.level)
	
	# CombatStateFactory._seed_player_stats, no fim
	if instance.defense > 0: combatant.defense = instance.defense
	if instance.mechanical_speed > 0: combatant.mechanical_speed = instance.mechanical_speed
	if instance.action_energy > 0: combatant.action_energy = instance.action_energy

static func _seed_enemy_stats(combatant: CombatantState, template: AlchemonSheet, enemy_level: int = -1) -> void:
	combatant.level = enemy_level if enemy_level >= 1 else DEFAULT_ENEMY_LEVEL
	combatant.experience = 0
	combatant.individual_value = 1
	combatant.attack = AlchemonFormulas.compute_stat(template.base_attack, combatant.individual_value, combatant.level)
	combatant.defense = AlchemonFormulas.compute_stat(template.base_defense, combatant.individual_value, combatant.level)
	combatant.mechanical_speed = AlchemonFormulas.compute_stat(template.base_mechanical_speed, combatant.individual_value, combatant.level)
	combatant.action_energy = AlchemonFormulas.compute_stat(template.base_action_energy, combatant.individual_value, combatant.level)
	combatant.temperature = template.temperature
