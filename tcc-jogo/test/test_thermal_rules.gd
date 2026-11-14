extends GdUnitTestSuite
## Mecânica térmica individual (Alchemons fora de Composto).

var db: AlchemonDatabase


func before_test() -> void:
	db = AlchemonDatabase.new()


## Massa 10 e cp 1 => dT = Q / 10.
func _sheet(melt: float = 300.0, boil: float = 400.0) -> AlchemonSheet:
	var s := AlchemonSheet.new("S", 100, 1)
	s.atomic_mass = 10
	s.specific_heat = 1.0
	s.melting_point = melt
	s.boiling_point = boil
	db.alchemons.append(s)
	return s


func _creature(max_hp: int = 200, level: int = 15, temp: float = 273.15) -> CombatantState:
	var c := CombatantState.new(1, 1, max_hp, true, 0, 8, temp)
	c.level = level
	c.defense = 100
	c.mechanical_speed = 100
	return c


func _state(c: CombatantState) -> CombatState:
	var st := CombatState.new()
	st.combatants[c.id] = c
	st.player_ids.append(c.id)
	st.battlefield.assign_combatant(c.id, 0)
	return st


func _hit(st: CombatState, q: float) -> void:
	var r := CombatResult.attack_hit(99, 1, "x", 0, false)
	r.thermal_energy = q
	CombatResultApplier.apply(st, r, db)


func test_heating_below_melting_no_transition_damage() -> void:
	var s := _sheet()
	var c := _creature()
	var st := _state(c)
	_hit(st, 100.0) # +10 K
	assert_float(c.temperature).is_equal_approx(283.15, 0.001)
	assert_int(c.hp).is_equal(200)
	assert_str(c.physical_state).is_equal(AlchemonSheet.SOLIDO)


func test_fusion_damage() -> void:
	var s := _sheet()
	var c := _creature()
	var st := _state(c)
	_hit(st, 300.0) # 303.15 > 300
	assert_str(c.physical_state).is_equal(AlchemonSheet.LIQUIDO)
	assert_str(c.previous_physical_state).is_equal(AlchemonSheet.SOLIDO)
	assert_int(c.hp).is_equal(200 - (20 + 15))


func test_boiling_damage_matches_spec_example() -> void:
	assert_int(ThermalRules.transition_damage(AlchemonSheet.LIQUIDO, AlchemonSheet.GASOSO, 200, 15)).is_equal(70)


func test_condensation_and_solidification_damage() -> void:
	assert_int(ThermalRules.transition_damage(AlchemonSheet.GASOSO, AlchemonSheet.LIQUIDO, 200, 15)).is_equal(30 + 22) # 22,5 -> 22
	assert_int(ThermalRules.transition_damage(AlchemonSheet.LIQUIDO, AlchemonSheet.SOLIDO, 200, 15)).is_equal(20 + 15)


func test_liquid_to_gas_then_back() -> void:
	var s := _sheet()
	var c := _creature(200, 15, 350.0)
	c.physical_state = AlchemonSheet.LIQUIDO
	var st := _state(c)
	_hit(st, 600.0) # 410 K > 400
	assert_str(c.physical_state).is_equal(AlchemonSheet.GASOSO)
	assert_int(c.hp).is_equal(200 - 70)
	_hit(st, -200.0) # 390 K
	assert_str(c.physical_state).is_equal(AlchemonSheet.LIQUIDO)
	assert_int(c.hp).is_equal(200 - 70 - 52)
	_hit(st, -1000.0) # 290 K
	assert_str(c.physical_state).is_equal(AlchemonSheet.SOLIDO)
	assert_int(c.hp).is_equal(200 - 70 - 52 - 35)


func test_same_state_does_not_repeat_damage() -> void:
	var s := _sheet()
	var c := _creature()
	var st := _state(c)
	_hit(st, 300.0)
	var hp_after := c.hp
	_hit(st, 100.0)
	_hit(st, 100.0)
	assert_int(c.hp).is_equal(hp_after)


func test_jump_solid_to_gas_applies_fusion_then_boiling() -> void:
	var s := _sheet()
	var c := _creature()
	var st := _state(c)
	_hit(st, 1500.0) # 423 K
	assert_str(c.physical_state).is_equal(AlchemonSheet.GASOSO)
	assert_int(c.hp).is_equal(200 - (20 + 15) - 70)


func test_hp_never_below_zero_and_dies() -> void:
	var s := _sheet()
	var c := _creature(20, 15)
	var st := _state(c)
	_hit(st, 1500.0)
	assert_int(c.hp).is_equal(0)
	assert_bool(c.alive).is_false()


func test_compound_member_skips_individual_heat() -> void:
	var s := _sheet()
	var c := _creature()
	c.bond_kind = BondRules.COMPOUND
	var st := _state(c)
	_hit(st, 5000.0)
	assert_float(c.temperature).is_equal_approx(273.15, 0.001)
	assert_int(c.hp).is_equal(200)


func test_base_stats_untouched_after_transitions() -> void:
	var s := _sheet()
	var c := _creature()
	var st := _state(c)
	_hit(st, 300.0)
	_hit(st, 1500.0)
	_hit(st, -3000.0)
	assert_int(c.mechanical_speed).is_equal(100)
	assert_int(c.defense).is_equal(100)
	assert_int(c.max_hp).is_equal(200)
