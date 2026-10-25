class_name BattleRewards
extends RefCounted

## What the player earned from one battle. Pure data + a pure builder (no UI,
## no autoload). The controller builds it, applies the money, and the
## BattleRewardsScreen displays it.

## Coins for beating a trainer (NPC). TEMPORARY flat value - replace
## money_for() with the real formula later; nothing else needs to change.
const TRAINER_WIN_MONEY := 100

var player_won := false
var is_trainer_battle := false
var money := 0
## One per party member that fought:
## {"name": String, "xp_gained": int, "level_before": int, "level_after": int}
var entries: Array[Dictionary] = []


## Single place for the coin formula.
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
		# XP is a flat AlchemonGrowth.XP_TO_LEVEL_UP per level, so total gained
		# = whole levels climbed + the change in the bar.
		var gained := (c.level - c.start_level) * AlchemonGrowth.XP_TO_LEVEL_UP + c.experience - c.start_experience
		r.entries.append({
			"name": display,
			"xp_gained": maxi(gained, 0),
			"level_before": c.start_level,
			"level_after": c.level,
		})
	return r
