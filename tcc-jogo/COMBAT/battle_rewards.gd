class_name BattleRewards
extends RefCounted


const TRAINER_WIN_MONEY := 100

var player_won := false
var is_trainer_battle := false
var money := 0
var entries: Array[Dictionary] = []


static func money_for(player_won: bool, is_trainer_battle: bool) -> int:
	return TRAINER_WIN_MONEY if (player_won and is_trainer_battle) else 0


static func build(state: CombatState, database: AlchemonDatabase, party: Array[AlchemonInstance], is_trainer_battle: bool) -> BattleRewards:
	var r := BattleRewards.new()
	r.player_won = state.player_won
	r.is_trainer_battle = is_trainer_battle
	r.money = money_for(state.player_won, is_trainer_battle)

	var by_uid := {}
	for inst in party:
		if inst != null:
			by_uid[inst.uid] = inst

	for id in state.player_ids:
		var c := state.get_combatant(id)
		if c == null:
			continue
		var sheet := database.get_by_id(c.species_id)
		var inst: AlchemonInstance = by_uid.get(c.source_uid)
		var display := "???"
		if inst != null:
			display = inst.display_name(sheet)
		elif sheet != null:
			display = sheet.creature_name
		var gained := (c.level - c.start_level) * AlchemonGrowth.XP_TO_LEVEL_UP + c.experience - c.start_experience
		r.entries.append({
			"name": display,
			"xp_gained": maxi(gained, 0),
			"level_before": c.start_level,
			"level_after": c.level,
		})
	return r
