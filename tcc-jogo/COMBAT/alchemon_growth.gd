class_name AlchemonGrowth
extends RefCounted


# XP acumulada para alcançar o nível n = n³ (Medium Fast).
# `experience` guarda só o progresso dentro do nível atual,
# então o custo de n → n+1 é (n+1)³ − n³.
static func xp_for_level(level: int) -> int:
	return level * level * level


static func xp_to_next(level: int) -> int:
	return xp_for_level(level + 1) - xp_for_level(level)


static func xp_between(from_level: int, to_level: int) -> int:
	var total := 0
	for l in range(from_level, to_level):
		total += xp_to_next(l)
	return total


## Sobe de nível usando o cálculo central de AlchemonInstance (mesmo da criação):
## base + IV + nível + personalidade. Sem fórmulas próprias aqui.
static func level_up(combatant: CombatantState, template: AlchemonSheet, levels: int = 1) -> void:
	for i in levels:
		var iv := combatant.individual_value
		var old_stats := AlchemonInstance.compute_stats_for(template, iv, combatant.personality, combatant.level)
		combatant.level += 1
		var new_stats := AlchemonInstance.compute_stats_for(template, iv, combatant.personality, combatant.level)
		combatant.attack = new_stats.attack
		combatant.defense = new_stats.defense
		combatant.mechanical_speed = new_stats.mechanical_speed
		var energy_gain: int = new_stats.action_energy - old_stats.action_energy
		combatant.action_energy += energy_gain
		combatant.max_valence_electrons += energy_gain
		combatant.valence_electrons = clampi(combatant.valence_electrons + energy_gain, 0, combatant.max_valence_electrons)
		var hp_gain: int = new_stats.max_hp - old_stats.max_hp
		combatant.max_hp += hp_gain
		# Derrotada (HP 0) continua derrotada: sem cura por subir de nível.
		if combatant.hp > 0:
			combatant.hp = clampi(combatant.hp + hp_gain, 1, combatant.max_hp)
		AttackLearning.on_level_reached(combatant, template, combatant.level)
		print("LVUP %s Lv%d atk=%d def=%d spd=%d en=%d" % [combatant.id, combatant.level, combatant.attack, combatant.defense, combatant.mechanical_speed, combatant.action_energy])


const WILD_MULT := 1.0
const TRAINER_MULT := 1.5


# EXP = ((a * b * L) / 5) / 2
# a: 1.0 selvagem, 1.5 treinador | b: xp_reward da espécie derrotada | L: nível do derrotado.
# Arredonda para baixo; mínimo 1 para nunca zerar o ganho.
static func xp_for_defeat(is_trainer_battle: bool, base_yield: int, defeated_level: int) -> int:
	var a := TRAINER_MULT if is_trainer_battle else WILD_MULT
	return maxi(int(floor(((a * base_yield * defeated_level) / 5.0) / 2.0)), 1)


static func grant_experience(combatant: CombatantState, template: AlchemonSheet, amount: int) -> void:
	if amount <= 0:
		return

	combatant.experience += amount
	while combatant.experience >= xp_to_next(combatant.level):
		combatant.experience -= xp_to_next(combatant.level)
		level_up(combatant, template)
