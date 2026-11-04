extends GdUnitTestSuite


func test_full_hp_small_creature() -> void:
	assert_int(AlchemonFormulas.compute_capture_value(30, 30, 255.0)).is_equal(85)


func test_low_hp_raises_value() -> void:
	assert_int(AlchemonFormulas.compute_capture_value(30, 1, 255.0)).is_equal(249)


func test_value_never_below_one() -> void:
	assert_int(AlchemonFormulas.compute_capture_value(30, 30, 1.0)).is_equal(1)


func test_value_capped_at_255() -> void:
	assert_int(AlchemonFormulas.compute_capture_value(30, 1, 1000.0)).is_equal(255)
	assert_int(AlchemonFormulas.compute_capture_value(30, 0, 255.0)).is_equal(255)


func test_eight_bit_reduction_changes_result() -> void:
	assert_int(AlchemonFormulas.compute_capture_value(100, 33, 255.0)).is_equal(200)


func test_reduction_is_two_floor_divisions_by_two() -> void:
	assert_int(AlchemonFormulas.compute_capture_value(90, 45, 255.0)).is_equal(171)


func test_no_reduction_at_exactly_255() -> void:
	assert_int(AlchemonFormulas.compute_capture_value(85, 10, 255.0)).is_equal(235)


func test_bad_input_does_not_crash() -> void:
	assert_int(AlchemonFormulas.compute_capture_value(0, 0, 255.0)).is_between(1, 255)
	assert_int(AlchemonFormulas.compute_capture_value(30, 500, 255.0)).is_equal(85)


func test_roll_rule() -> void:
	assert_bool(CombatRules.capture_roll_succeeds(85, 84)).is_true()
	assert_bool(CombatRules.capture_roll_succeeds(85, 85)).is_false()
	for roll in 255:
		assert_bool(CombatRules.capture_roll_succeeds(255, roll)).is_true()


func test_tool_category() -> void:
	assert_float(CombatRules.tool_multiplier(AlchemonType.Type.METAL, AlchemonType.Type.METAL)).is_equal(CombatRules.TOOL_MULTIPLIER_MATCH)
	assert_float(CombatRules.tool_multiplier(AlchemonType.Type.METAL, AlchemonType.Type.AMETAL)).is_equal(CombatRules.TOOL_MULTIPLIER_WRONG)


func _throws(hp_fraction: float, matching: bool, n: int) -> int:
	var db: AlchemonDatabase = load("res://DATABASE/Alchemons/AlchemonDataBaseComplete.tres")
	var items: ItemDatabase = load("res://DATABASE/Inventory/ItemDatabase.tres")
	var sheet := db.alchemons[0]
	var tool: ItemData = null
	for it in items.items:
		if it.is_capture_method and ((it.capture_type == sheet.element_type) == matching):
			tool = it
			break
	assert_object(tool).is_not_null()
	var party: Array[AlchemonInstance] = [CreatureFactory.create(sheet.id, 5)]
	var enemies: Array[int] = [sheet.id]
	var state := CombatStateFactory.build(db, party, enemies, 3)
	var enemy := state.get_combatant(state.enemy_ids[0])
	enemy.hp = maxi(int(enemy.max_hp * hp_fraction), 1)
	var cmd := ActionCommand.new(state.player_ids[0], "capture", enemy.id, -1, tool.index)
	var wins := 0
	for i in n:
		if CombatRules.resolve_action(state, cmd, db, items).outcome == CombatResult.Outcome.CAPTURE_SUCCESS:
			wins += 1
	return wins


func test_resolver_full_hp_right_tool_is_about_one_third() -> void:
	var wins := _throws(1.0, true, 600)
	assert_int(wins).is_between(150, 250)


func test_resolver_low_hp_is_almost_certain() -> void:
	var wins := _throws(0.0, true, 300)
	assert_int(wins).is_greater(285)


func test_resolver_wrong_tool_is_worse_than_right_tool() -> void:
	var right := _throws(1.0, true, 600)
	var wrong := _throws(1.0, false, 600)
	assert_int(wrong).is_less(right)
