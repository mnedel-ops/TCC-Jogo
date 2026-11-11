extends GdUnitTestSuite


var db: AlchemonDatabase


func before_test() -> void:
	db = AlchemonDatabase.new()


func _sheet(id: int, melt: float, boil: float) -> AlchemonSheet:
	var s := AlchemonSheet.new("S%d" % id, 100, id)
	s.melting_point = melt
	s.boiling_point = boil
	db.alchemons.append(s)
	return s


func _state_with(sheets: Array[AlchemonSheet]) -> CombatState:
	var st := CombatState.new()
	st.arena_temperature = 273.15
	var slot := 0
	for s in sheets:
		var c := CombatantState.new(s.id, s.id, 100, slot < 3, slot, 8, s.melting_point)
		c.physical_state = AlchemonSheet.SOLIDO
		st.combatants[c.id] = c
		if c.is_player:
			st.player_ids.append(c.id)
		else:
			st.enemy_ids.append(c.id)
		st.battlefield.assign_combatant(c.id, slot)
		slot += 1
	return st


func _heat_to(st: CombatState, temp: float) -> void:
	st.arena_temperature = temp
	CombatResultApplier._apply_arena_heat(st, db)


func test_damages_every_creature_whose_point_was_exceeded() -> void:
	var a := _sheet(1, 300.0, 400.0)
	var b := _sheet(2, 350.0, 500.0)
	var c := _sheet(3, 500.0, 600.0)
	var st := _state_with([a, b, c])
	_heat_to(st, 320.0)
	assert_int(st.get_combatant(1).hp).is_equal(100 - CombatResultApplier.STATE_CHANGE_DAMAGE)
	assert_int(st.get_combatant(2).hp).is_equal(100)
	assert_int(st.get_combatant(3).hp).is_equal(100)
	_heat_to(st, 360.0)
	assert_int(st.get_combatant(1).hp).is_equal(100 - CombatResultApplier.STATE_CHANGE_DAMAGE)
	assert_int(st.get_combatant(2).hp).is_equal(100 - CombatResultApplier.STATE_CHANGE_DAMAGE)


func test_skipping_two_points_damages_twice() -> void:
	var a := _sheet(1, 300.0, 400.0)
	var st := _state_with([a])
	_heat_to(st, 450.0)
	assert_int(st.get_combatant(1).hp).is_equal(100 - 2 * CombatResultApplier.STATE_CHANGE_DAMAGE)
	assert_str(st.get_combatant(1).physical_state).is_equal(AlchemonSheet.GASOSO)


func test_compound_breaks_and_cation_takes_damage() -> void:
	var anion := _sheet(1, 500.0, 600.0)
	var cation := _sheet(2, 300.0, 400.0)
	var st := _state_with([anion, cation])
	var a := st.get_combatant(1)
	var k := st.get_combatant(2)
	a.bond_kind = BondRules.COMPOUND
	a.bond_partner_id = a.id
	k.bond_kind = BondRules.COMPOUND
	k.bond_partner_id = a.id
	k.is_bond_inactive = true
	k.is_bond_cation = true
	a.max_hp += 70
	a.hp += 70
	_heat_to(st, 320.0)
	assert_str(a.bond_kind).is_equal(BondRules.NONE)
	assert_str(k.bond_kind).is_equal(BondRules.NONE)
	assert_bool(k.is_bond_cation).is_false()
	assert_bool(k.is_bond_inactive).is_false()
	assert_int(a.max_hp).is_equal(100)
	assert_int(a.hp).is_equal(100)
	assert_int(k.hp).is_less(30)
