class_name CreatureSync
extends RefCounted


const REVIVE_FAINTED_ON_BATTLE_START := false

const PERSIST_ENERGY := true


static func write_back(inst: AlchemonInstance, c: CombatantState, template: AlchemonSheet) -> void:
	inst.level = c.level
	inst.experience = c.experience
	inst.attack_ids.assign(c.attack_ids)
	inst.current_hp = clampi(c.hp, 0, inst.max_hp_for(template))
	if PERSIST_ENERGY:
		inst.current_energy = clampi(c.valence_electrons, 0, template.max_valence_electrons)


static func apply_battle(party: Array[AlchemonInstance], state: CombatState, database: AlchemonDatabase) -> void:
	var by_uid := {}
	for inst in party:
		if inst != null and inst.uid != "":
			by_uid[inst.uid] = inst
	for id in state.player_ids:
		var c := state.get_combatant(id)
		if c == null:
			continue
		var inst: AlchemonInstance = by_uid.get(c.source_uid)
		var template := database.get_by_id(c.species_id)
		if inst == null or template == null:
			push_warning("CreatureSync: no creature for combatant %d (uid '%s'). Result dropped." % [id, c.source_uid])
			continue
		write_back(inst, c, template)
