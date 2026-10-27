extends GdUnitTestSuite

var db: AlchemonDatabase


func before_test() -> void:
	db = load("res://DATABASE/Alchemons/AlchemonDataBaseComplete.tres")


func _inst(level: int = 5) -> AlchemonInstance:
	return CreatureFactory.create(db.alchemons[0].id, level)


func _state(party: Array[AlchemonInstance]) -> CombatState:
	var enemies: Array[int] = [db.alchemons[0].id]
	return CombatStateFactory.build(db, party, enemies, 3)


func _sheet() -> AlchemonSheet:
	return db.alchemons[0]


# ---------------------------------------------------------------- player data

func test_new_player_starts_with_500_coins() -> void:
	assert_int(PlayerData.new().money).is_equal(500)
	var shipped: PlayerData = load("res://DATABASE/Player/player.tres")
	assert_int(shipped.money).is_equal(500)


func test_add_money_never_goes_negative() -> void:
	var p := PlayerData.new()
	p.add_money(100)
	assert_int(p.money).is_equal(600)
	p.add_money(-9999)
	assert_int(p.money).is_equal(0)


# ---------------------------------------------------------------- money rules

func test_money_only_for_beating_a_trainer() -> void:
	assert_int(BattleRewards.money_for(true, true)).is_equal(100)
	assert_int(BattleRewards.money_for(true, false)).is_equal(0)    # wild
	assert_int(BattleRewards.money_for(false, true)).is_equal(0)    # lost
	assert_int(BattleRewards.money_for(false, false)).is_equal(0)


# ---------------------------------------------------------------- xp / level up

func test_xp_gained_without_level_up() -> void:
	var a := _inst(5)
	var state := _state([a])
	var c := state.get_combatant(state.player_ids[0])
	AlchemonGrowth.grant_experience(c, _sheet(), 60)
	var r := BattleRewards.build(state, db, [a], false)
	assert_int(r.entries[0].xp_gained).is_equal(60)
	assert_int(r.entries[0].level_after).is_equal(r.entries[0].level_before)


func test_xp_gained_across_a_level_up() -> void:
	var a := _inst(5)
	a.experience = 80
	var state := _state([a])
	var c := state.get_combatant(state.player_ids[0])
	AlchemonGrowth.grant_experience(c, _sheet(), 50)    # 80 + 50 -> level 6, bar at 30
	var r := BattleRewards.build(state, db, [a], false)
	assert_int(r.entries[0].xp_gained).is_equal(50)
	assert_int(r.entries[0].level_before).is_equal(5)
	assert_int(r.entries[0].level_after).is_equal(6)


func test_entry_uses_nickname() -> void:
	var a := _inst()
	a.creature_name = "Fofo"
	var state := _state([a])
	var r := BattleRewards.build(state, db, [a], false)
	assert_str(r.entries[0].name).is_equal("Fofo")


# ---------------------------------------------------------------- screen text

func test_text_shows_exp_levelup_and_coins() -> void:
	var r := BattleRewards.new()
	r.player_won = true
	r.money = 100
	r.entries.append({"name": "Ametal", "xp_gained": 120, "level_before": 5, "level_after": 6})
	var texts: Array[String] = []
	for l in BattleRewardsScreen.lines_for(r):
		texts.append(l.text)
	assert_array(texts).contains(["Ametal gained 120 EXP", "Ametal leveled up to 6!", "You received 100 coins!"])


func test_text_without_xp_or_money() -> void:
	var r := BattleRewards.new()
	r.entries.append({"name": "Ametal", "xp_gained": 0, "level_before": 5, "level_after": 5})
	var lines := BattleRewardsScreen.lines_for(r)
	assert_int(lines.size()).is_equal(1)
	assert_str(lines[0].text).is_equal("No EXP gained.")


# ---------------------------------------------------------------- input behaviour

func _key() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_SPACE
	e.pressed = true
	return e


func test_screen_ignores_input_until_delay_then_dismisses_on_any_key() -> void:
	var screen := BattleRewardsScreen.new()
	add_child(auto_free(screen))
	var hits := []
	screen.dismissed.connect(func(): hits.append(1))
	screen.show_rewards(BattleRewards.new())
	screen._input(_key())                       # too early (mashed key)
	assert_int(hits.size()).is_equal(0)
	await get_tree().create_timer(BattleRewardsScreen.INPUT_DELAY + 0.2).timeout
	var release := _key()
	release.pressed = false
	screen._input(release)                      # key release does not count
	assert_int(hits.size()).is_equal(0)
	screen._input(_key())
	screen._input(_key())                       # only emits once
	assert_int(hits.size()).is_equal(1)


func test_gamepad_also_dismisses_mouse_does_not() -> void:
	var mouse := InputEventMouseButton.new()
	mouse.pressed = true
	var s := BattleRewardsScreen.new()
	add_child(auto_free(s))
	var mouse_hits := []
	s.dismissed.connect(func(): mouse_hits.append(1))
	s.show_rewards(BattleRewards.new())
	await get_tree().create_timer(BattleRewardsScreen.INPUT_DELAY + 0.2).timeout
	s._input(mouse)
	assert_int(mouse_hits.size()).is_equal(0)

	for ev in [InputEventJoypadButton.new()]:
		var screen := BattleRewardsScreen.new()
		add_child(auto_free(screen))
		var hits := []
		screen.dismissed.connect(func(): hits.append(1))
		screen.show_rewards(BattleRewards.new())
		await get_tree().create_timer(BattleRewardsScreen.INPUT_DELAY + 0.2).timeout
		ev.pressed = true
		screen._input(ev)
		assert_int(hits.size()).is_equal(1)


# ---------------------------------------------------------------- flow

func test_rules_layer_no_longer_ends_combat_for_exploration() -> void:
	# The controller emits combat_ended after the rewards screen. If the rules
	# layer still emitted it, the player would be released before the screen.
	var fired := []
	var cb := func(): fired.append(1)
	CombatSignal.combat_ended.connect(cb)
	var state := _state([_inst()])
	var enemy_id := state.enemy_ids[0]
	CombatResultApplier.apply(state, CombatResult.capture_success(state.player_ids[0], enemy_id), db)
	CombatSignal.combat_ended.disconnect(cb)
	assert_bool(state.combat_over).is_true()
	assert_int(fired.size()).is_equal(0)
