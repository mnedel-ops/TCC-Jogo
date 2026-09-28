class_name CombatStateFactory
extends RefCounted

## Constroi um CombatState inicial a partir do database + listas de species_id.
## Nao decide regra de combate (isso e CombatRules); so monta estado inicial.
## Tambem aloca slots iniciais no battlefield via BattlefieldRules.

static func build(database: AlchemonDatabase, player_party: Array[AlchemonInstance], enemy_species_ids: Array[int]) -> CombatState:
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
		_seed_enemy_stats(c, template)
		state.combatants[c.id] = c
		state.enemy_ids.append(c.id)
		BattlefieldRules.assign_combatant(state.battlefield, c.id, slot)
		next_instance_id += 1
		enemy_slot_index += 1

# CombatStateFactory.build, logo antes do "return state":
	if state.player_ids.size() == 2:
		var p0 := state.get_combatant(state.player_ids[0])
		var p1 := state.get_combatant(state.player_ids[1])
		var sheet0 := database.get_by_id(p0.species_id)
		var sheet1 := database.get_by_id(p1.species_id)
		var kind := AlchemyStation.determine_bond_kind([sheet0, sheet1])
		if kind != BondRules.NONE:
			BondRules.apply_bond(kind, [p0, p1], [sheet0, sheet1])
	
	_try_bond(state, database, state.player_ids)
	_try_bond(state, database, state.enemy_ids)
	return state

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
	combatant.attack = AlchemonFormulas.compute_attack(template.base_attack, combatant.individual_value, combatant.level)
	combatant.defense = maxi(template.base_defense, 1)
	combatant.mechanical_speed = maxi(template.base_mechanical_speed, 1)
	combatant.action_energy = maxi(template.base_action_energy, 1)
	combatant.temperature = template.temperature
	
	# CombatStateFactory._seed_player_stats, no fim
	if instance.defense > 0: combatant.defense = instance.defense
	if instance.mechanical_speed > 0: combatant.mechanical_speed = instance.mechanical_speed
	if instance.action_energy > 0: combatant.action_energy = instance.action_energy

static func _seed_enemy_stats(combatant: CombatantState, template: AlchemonSheet) -> void:
	combatant.level = 1
	combatant.experience = 0
	combatant.individual_value = 1
	combatant.attack = AlchemonFormulas.compute_attack(template.base_attack, combatant.individual_value, combatant.level)
	combatant.defense = maxi(template.base_defense, 1)
	combatant.mechanical_speed = maxi(template.base_mechanical_speed, 1)
	combatant.action_energy = maxi(template.base_action_energy, 1)
	combatant.temperature = template.temperature
