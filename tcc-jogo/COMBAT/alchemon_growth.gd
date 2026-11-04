class_name AlchemonGrowth
extends RefCounted


const XP_TO_LEVEL_UP := 100

static func level_up(combatant: CombatantState, template: AlchemonSheet, levels: int = 1) -> void:
	for i in levels:
		var old_energy_max := AlchemonFormulas.compute_stat(template.base_action_energy, combatant.individual_value, combatant.level)
		var old_hp_max := AlchemonFormulas.compute_max_hp(template.max_hp, combatant.individual_value, combatant.level)
		combatant.level += 1
		var iv := combatant.individual_value
		combatant.attack = AlchemonFormulas.compute_stat(template.base_attack, iv, combatant.level)
		combatant.defense = AlchemonFormulas.compute_stat(template.base_defense, iv, combatant.level)
		combatant.mechanical_speed = AlchemonFormulas.compute_stat(template.base_mechanical_speed, iv, combatant.level)
		var new_energy_max := AlchemonFormulas.compute_stat(template.base_action_energy, iv, combatant.level)
		combatant.action_energy += new_energy_max - old_energy_max
		var hp_gain := AlchemonFormulas.compute_max_hp(template.max_hp, iv, combatant.level) - old_hp_max
		combatant.max_hp += hp_gain
		if combatant.hp > 0:
			combatant.hp += hp_gain
		print("LVUP %s Lv%d atk=%d def=%d spd=%d en=%d" % [combatant.id, combatant.level, combatant.attack, combatant.defense, combatant.mechanical_speed, combatant.action_energy])

static func grant_experience(combatant: CombatantState, template: AlchemonSheet, amount: int) -> void:
	if amount <= 0:
		return

	combatant.experience += amount
	while combatant.experience >= XP_TO_LEVEL_UP:
		combatant.experience -= XP_TO_LEVEL_UP
		level_up(combatant, template)
