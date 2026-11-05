extends GdUnitTestSuite

func _make_combatant(level: int) -> CombatantState:
	var c := CombatantState.new()
	c.level = level
	c.individual_value = 1
	c.action_energy = 3
	return c

func _make_template() -> AlchemonSheet:
	var t := AlchemonSheet.new()
	t.base_attack = 10
	t.base_defense = 10
	t.base_mechanical_speed = 10
	t.base_action_energy = 10
	return t

func test_compute_stat_formula() -> void:
	assert_int(AlchemonFormulas.compute_stat(10, 1, 1)).is_equal(5)
	assert_int(AlchemonFormulas.compute_stat(10, 1, 10)).is_equal(7)
	assert_int(AlchemonFormulas.compute_stat(10, 1, 50)).is_equal(15)

func test_level_up_increases_stats() -> void:
	var c := _make_combatant(1)
	var t := _make_template()
	AlchemonGrowth.level_up(c, t, 9)
	assert_int(c.level).is_equal(10)
	assert_int(c.attack).is_equal(7)
	assert_int(c.defense).is_equal(7)
	assert_int(c.mechanical_speed).is_equal(7)

func test_level_up_keeps_spent_energy() -> void:
	var c := _make_combatant(1)
	AlchemonGrowth.level_up(c, _make_template(), 9)
	assert_int(c.action_energy).is_equal(5)
	
func test_state_at() -> void:
	var s := AlchemonSheet.new()
	s.temperature = 300.0
	s.boiling_point = 400.0
	assert_str(s.state_at(273.15)).is_equal(AlchemonSheet.SOLIDO)
	assert_str(s.state_at(350.0)).is_equal(AlchemonSheet.LIQUIDO)
	assert_str(s.state_at(500.0)).is_equal(AlchemonSheet.GASOSO)


func test_xp_curve_is_cubic() -> void:
	assert_int(AlchemonGrowth.xp_for_level(5)).is_equal(125)
	assert_int(AlchemonGrowth.xp_to_next(5)).is_equal(91)
	assert_int(AlchemonGrowth.xp_between(5, 7)).is_equal(218)
	assert_int(AlchemonGrowth.xp_between(7, 7)).is_equal(0)


func test_grant_experience_uses_cubic_curve() -> void:
	var c := _make_combatant(5)
	AlchemonGrowth.grant_experience(c, _make_template(), 91 + 127 + 10)
	assert_int(c.level).is_equal(7)
	assert_int(c.experience).is_equal(10)
