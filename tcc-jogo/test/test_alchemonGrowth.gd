extends GdUnitTestSuite

func _make_combatant(level: int) -> CombatantState:
	var c := CombatantState.new()
	c.level = level
	c.individual_value = 1
	c.action_energy = 3   # pool parcialmente gasto
	return c

func _make_template() -> AlchemonSheet:
	var t := AlchemonSheet.new()
	t.base_attack = 10
	t.base_defense = 10
	t.base_mechanical_speed = 10
	t.base_action_energy = 10
	return t

func test_compute_stat_formula() -> void:
	assert_int(AlchemonFormulas.compute_stat(10, 1, 1)).is_equal(5)    # floor(0.21)+5
	assert_int(AlchemonFormulas.compute_stat(10, 1, 10)).is_equal(7)   # floor(2.1)+5
	assert_int(AlchemonFormulas.compute_stat(10, 1, 50)).is_equal(15)  # floor(10.5)+5

func test_level_up_increases_stats() -> void:
	var c := _make_combatant(1)
	var t := _make_template()
	AlchemonGrowth.level_up(c, t, 9)   # 1 -> 10
	assert_int(c.level).is_equal(10)
	assert_int(c.attack).is_equal(7)
	assert_int(c.defense).is_equal(7)
	assert_int(c.mechanical_speed).is_equal(7)

func test_level_up_keeps_spent_energy() -> void:
	var c := _make_combatant(1)
	AlchemonGrowth.level_up(c, _make_template(), 9)
	# pool era 3, máximo subiu 5 -> 7 (delta +2): 3 + 2 = 5, não encheu
	assert_int(c.action_energy).is_equal(5)
	
func test_state_at() -> void:
	var s := AlchemonSheet.new()
	s.temperature = 300.0
	s.boiling_point = 400.0
	assert_str(s.state_at(273.15)).is_equal(AlchemonSheet.SOLIDO)
	assert_str(s.state_at(350.0)).is_equal(AlchemonSheet.LIQUIDO)
	assert_str(s.state_at(500.0)).is_equal(AlchemonSheet.GASOSO)
