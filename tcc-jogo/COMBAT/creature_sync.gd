class_name CreatureSync
extends RefCounted

## The ONLY boundary between battle state (CombatantState) and the persistent
## creature (AlchemonInstance).
##   instance -> combatant : CombatStateFactory (reads instance.compute_stats)
##   combatant -> instance : here
## Rule: write back only what the creature itself keeps (level, xp, HP, energy).
## NEVER copy derived stats - they include temporary bond bonuses.

## TEMPORARY, keeps today's behaviour: a creature at 0 HP is restored to full at
## the start of the next battle (there is no heal station yet). Once healing
## exists set this to false so KO'd creatures stay KO'd.
## Before flipping it: PlayerBondData.member_indices must move to uids, because
## skipping a fainted member shifts the party indices.
const REVIVE_FAINTED_ON_BATTLE_START := true

## false = energy refills every battle (today). true = energy carries over
## between battles like PP.
const PERSIST_ENERGY := false


## Copy one combatant's result into its creature.
static func write_back(inst: AlchemonInstance, c: CombatantState, template: AlchemonSheet) -> void:
	inst.level = c.level
	inst.experience = c.experience
	# Clamp to the REAL max: combatant max_hp may include a temporary bond bonus.
	inst.current_hp = clampi(c.hp, 0, inst.max_hp_for(template))
	if PERSIST_ENERGY:
		inst.current_energy = clampi(c.valence_electrons, 0, template.max_valence_electrons)


## Whole battle -> party. Matched by uid, never by list position, so skipped /
## reordered / null entries cannot send a result to the wrong creature.
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
