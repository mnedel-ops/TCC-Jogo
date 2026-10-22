class_name AlchemonGrowth
extends RefCounted

## Cresce os atributos de um CombatantState ao subir de nivel.
##
## Ataque agora e recalculado do zero via AlchemonFormulas.compute_attack()
## a cada level up (formula do GDD, sem EV) - nao e mais um incremento
## aleatorio acumulado. Defesa, Velocidade Mecanica e Energia de Acao ainda
## usam a faixa min/max configurada no AlchemonSheet (nao convertidas pra
## formula ainda). Minimo de 1 sempre garantido em todos os atributos.
##
## HP: max_hp sobe via AlchemonFormulas.compute_max_hp e o hp atual ganha o
## mesmo valor (se vivo).

## XP necessario pra subir 1 nivel. Fixo por enquanto - GDD ainda nao
## define uma curva de XP por nivel/especie.
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
		# HP: max grows, and current HP gains the same amount (only if still alive).
		# Diff, not absolute, so bond bonuses on max_hp are kept.
		var hp_gain := AlchemonFormulas.compute_max_hp(template.max_hp, iv, combatant.level) - old_hp_max
		combatant.max_hp += hp_gain
		if combatant.hp > 0:
			combatant.hp += hp_gain
		print("LVUP %s Lv%d atk=%d def=%d spd=%d en=%d" % [combatant.id, combatant.level, combatant.attack, combatant.defense, combatant.mechanical_speed, combatant.action_energy])

## Concede XP a um combatente e aplica quantos level ups o total acumulado
## render (normalmente 0 ou 1, mas cobre o caso de uma recompensa grande
## de uma vez so - ex: capturar algo muito acima do nivel atual). Sobra de
## XP alem do necessario pro proximo nivel fica guardada, nunca se perde.
static func grant_experience(combatant: CombatantState, template: AlchemonSheet, amount: int) -> void:
	if amount <= 0:
		return

	combatant.experience += amount
	while combatant.experience >= XP_TO_LEVEL_UP:
		combatant.experience -= XP_TO_LEVEL_UP
		level_up(combatant, template)
