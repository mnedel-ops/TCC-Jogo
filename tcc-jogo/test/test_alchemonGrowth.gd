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
	t.energia_de_acao = 10
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
	s.melting_point = 300.0
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


func test_xp_for_defeat_wild_formula() -> void:
	# ((1 * 64 * 10) / 5) / 2 = 64
	assert_int(AlchemonGrowth.xp_for_defeat(false, 64, 10)).is_equal(64)


func test_xp_for_defeat_trainer_is_1_5x() -> void:
	# ((1.5 * 64 * 10) / 5) / 2 = 96
	assert_int(AlchemonGrowth.xp_for_defeat(true, 64, 10)).is_equal(96)


func test_xp_for_defeat_never_zero() -> void:
	assert_int(AlchemonGrowth.xp_for_defeat(false, 1, 1)).is_equal(1)


func _make_template_hp() -> AlchemonSheet:
	var t := _make_template()
	t.base_hp = 50
	return t


func _combatant_from_instance(inst: AlchemonInstance, t: AlchemonSheet) -> CombatantState:
	var st := inst.compute_stats(t)
	var c := CombatantState.new(1, 1, st.max_hp, true, 0, st.action_energy)
	c.level = inst.level
	c.individual_value = inst.individual_value
	c.personality = inst.personality
	c.attack = st.attack
	c.defense = st.defense
	c.mechanical_speed = st.mechanical_speed
	c.action_energy = st.action_energy
	return c


func test_level_up_matches_instance_stats_for_every_personality() -> void:
	var t := _make_template_hp()
	for p in AlchemonPersonality.TABLE.keys():
		var inst := AlchemonInstance.new()
		inst.individual_value = 17
		inst.personality = p
		inst.level = 5
		var c := _combatant_from_instance(inst, t)
		AlchemonGrowth.level_up(c, t, 20)
		inst.level = 25
		var want := inst.compute_stats(t)
		assert_int(c.attack).is_equal(want.attack)
		assert_int(c.defense).is_equal(want.defense)
		assert_int(c.mechanical_speed).is_equal(want.mechanical_speed)
		assert_int(c.max_hp).is_equal(want.max_hp)
		assert_int(c.action_energy).is_equal(want.action_energy)


func test_level_up_applies_personality_multiplier() -> void:
	var t := _make_template_hp()
	var inst := AlchemonInstance.new()
	inst.personality = "bold"  # +10% ataque, -10% defesa
	inst.individual_value = 1
	var c := _combatant_from_instance(inst, t)
	AlchemonGrowth.level_up(c, t, 49)  # Lv50: base 15 -> atk 17 / def 14
	assert_int(c.attack).is_equal(17)
	assert_int(c.defense).is_equal(14)


func test_level_up_full_hp_follows_max() -> void:
	var t := _make_template_hp()
	var c := _combatant_from_instance(AlchemonInstance.new(), t)
	AlchemonGrowth.level_up(c, t, 30)
	assert_int(c.hp).is_equal(c.max_hp)


func test_level_up_partial_hp_keeps_missing_hp() -> void:
	var t := _make_template_hp()
	var c := _combatant_from_instance(AlchemonInstance.new(), t)
	AlchemonGrowth.level_up(c, t, 20)
	c.hp = c.max_hp - 3
	var missing := c.max_hp - c.hp
	AlchemonGrowth.level_up(c, t, 20)
	assert_int(c.max_hp - c.hp).is_equal(missing)


func test_level_up_fainted_stays_fainted() -> void:
	var t := _make_template_hp()
	var c := _combatant_from_instance(AlchemonInstance.new(), t)
	c.hp = 0
	AlchemonGrowth.level_up(c, t, 30)
	assert_int(c.hp).is_equal(0)


func test_level_up_partial_energy_not_restored() -> void:
	var t := _make_template_hp()
	var c := _combatant_from_instance(AlchemonInstance.new(), t)
	c.valence_electrons = 1
	var max_before := c.max_valence_electrons
	AlchemonGrowth.level_up(c, t, 40)
	var gain := c.max_valence_electrons - max_before
	assert_int(c.valence_electrons).is_equal(1 + gain)
	assert_bool(c.valence_electrons < c.max_valence_electrons).is_true()
