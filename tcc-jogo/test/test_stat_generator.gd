extends GdUnitTestSuite

const DB_PATH := "res://DATABASE/Alchemons/AlchemonDataBaseComplete.tres"


func test_every_sheet_matches_generator() -> void:
	var db: AlchemonDatabase = load(DB_PATH)
	for sheet in db.alchemons:
		if not AlchemonStatGenerator.has_data(sheet):
			continue
		var s := AlchemonStatGenerator.from_sheet(sheet)
		assert_int(sheet.base_hp).is_equal(s["base_hp"])
		assert_int(sheet.base_attack).is_equal(s["base_attack"])
		assert_int(sheet.base_defense).is_equal(s["base_defense"])
		assert_int(sheet.base_mechanical_speed).is_equal(s["base_mechanical_speed"])


func test_stats_inside_range() -> void:
	var s := AlchemonStatGenerator.generate_base_stats(1.0, 2372.3, 349.0, 4.0, 850.0, false)
	for k in s:
		assert_int(s[k]).is_between(AlchemonStatGenerator.BASE_MIN, AlchemonStatGenerator.BASE_MAX)


func test_hydrogen_is_fastest_and_gold_slow() -> void:
	var h := AlchemonStatGenerator.generate_base_stats(1.0, 1312.0, 72.8, 2.2, 218.0, false)
	var au := AlchemonStatGenerator.generate_base_stats(197.0, 890.1, 222.8, 2.54, 368.2, true)
	assert_int(h["base_mechanical_speed"]).is_equal(110)
	assert_int(au["base_mechanical_speed"]).is_equal(35)
