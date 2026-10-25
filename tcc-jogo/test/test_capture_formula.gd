extends GdUnitTestSuite

# a = max(floor((3*HPmax - 2*HPcur) * X / (3*HPmax)), 1), a <= 255
# 3*HPmax > 255  ->  both terms >> 1 >> 1 first.

func test_full_hp_small_creature() -> void:
	# HPmax 30: 3*30 = 90 (<= 255, no reduction). (90-60)*255/90 = 85
	assert_int(AlchemonFormulas.compute_capture_value(30, 30, 255.0)).is_equal(85)


func test_low_hp_raises_value() -> void:
	# (90-2)*255/90 = 249.33 -> 249
	assert_int(AlchemonFormulas.compute_capture_value(30, 1, 255.0)).is_equal(249)


func test_value_never_below_one() -> void:
	# (90-60)*1/90 = 0.33 -> floor 0 -> max(.,1) = 1
	assert_int(AlchemonFormulas.compute_capture_value(30, 30, 1.0)).is_equal(1)


func test_value_capped_at_255() -> void:
	assert_int(AlchemonFormulas.compute_capture_value(30, 1, 1000.0)).is_equal(255)
	assert_int(AlchemonFormulas.compute_capture_value(30, 0, 255.0)).is_equal(255)


func test_eight_bit_reduction_changes_result() -> void:
	# HPmax 100, HPcur 33: 300 > 255 -> 300>>2 = 75, 66>>2 = 16.
	# (75-16)*255/75 = 200.6 -> 200. (Without reduction it would be 198.)
	assert_int(AlchemonFormulas.compute_capture_value(100, 33, 255.0)).is_equal(200)


func test_reduction_is_two_floor_divisions_by_two() -> void:
	# HPmax 90, HPcur 45: 270 > 255 -> 270>>1=135>>1=67 ; 90>>1=45>>1=22.
	# (67-22)*255/67 = 171.26 -> 171
	assert_int(AlchemonFormulas.compute_capture_value(90, 45, 255.0)).is_equal(171)


func test_no_reduction_at_exactly_255() -> void:
	# HPmax 85: 3*85 = 255, NOT > 255 -> no reduction. HPcur 10: (255-20)*255/255 = 235
	assert_int(AlchemonFormulas.compute_capture_value(85, 10, 255.0)).is_equal(235)


func test_bad_input_does_not_crash() -> void:
	assert_int(AlchemonFormulas.compute_capture_value(0, 0, 255.0)).is_between(1, 255)
	assert_int(AlchemonFormulas.compute_capture_value(30, 500, 255.0)).is_equal(85)   # hp above max treated as full


func test_roll_rule() -> void:
	assert_bool(CombatRules.capture_roll_succeeds(85, 84)).is_true()
	assert_bool(CombatRules.capture_roll_succeeds(85, 85)).is_false()
	for roll in 255:
		assert_bool(CombatRules.capture_roll_succeeds(255, roll)).is_true()   # a = 255 never fails


func test_tool_category() -> void:
	assert_float(CombatRules.tool_multiplier(AlchemonType.Type.METAL, AlchemonType.Type.METAL)).is_equal(CombatRules.TOOL_MULTIPLIER_MATCH)
	assert_float(CombatRules.tool_multiplier(AlchemonType.Type.METAL, AlchemonType.Type.AMETAL)).is_equal(CombatRules.TOOL_MULTIPLIER_WRONG)


# ---- through the real resolver (random, so wide bounds)

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
	assert_int(wins).is_between(150, 250)     # expected ~200 (a=85 -> 33%)


func test_resolver_low_hp_is_almost_certain() -> void:
	var wins := _throws(0.0, true, 300)       # hp clamps to 1
	assert_int(wins).is_greater(285)


func test_resolver_wrong_tool_is_worse_than_right_tool() -> void:
	var right := _throws(1.0, true, 600)
	var wrong := _throws(1.0, false, 600)
	assert_int(wrong).is_less(right)
