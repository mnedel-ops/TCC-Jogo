extends GdUnitTestSuite
## Mecânica térmica de Alchemons em Composto (temperatura do vínculo, transição,
## cisão, choque térmico uma vez por Alchemon, Sobrecarga Térmica).

var db: AlchemonDatabase


func before_test() -> void:
	db = AlchemonDatabase.new()


func _sheet(id: int, number: int, mass: int, etype: AlchemonType.Type, valence: int, en: float, melt: float, boil: float) -> AlchemonSheet:
	var s := AlchemonSheet.new("E%d" % id, 100, id)
	s.atomic_number = number
	s.atomic_mass = mass
	s.element_type = etype
	s.valence_electrons = valence
	s.electronegativity = en
	s.melting_point = melt
	s.boiling_point = boil
	db.alchemons.append(s)
	return s


func _li() -> AlchemonSheet:
	return _sheet(1, 3, 7, AlchemonType.Type.METAL, 1, 0.98, 454.0, 1615.0)


func _f() -> AlchemonSheet:
	return _sheet(2, 9, 19, AlchemonType.Type.AMETAL, 7, 3.98, 54.0, 85.0)


func _o() -> AlchemonSheet:
	return _sheet(3, 8, 16, AlchemonType.Type.AMETAL, 6, 3.44, 54.0, 90.0)


func _cl() -> AlchemonSheet:
	return _sheet(4, 17, 35, AlchemonType.Type.AMETAL, 7, 3.16, 172.0, 239.0)


func _c(id: int, sheet: AlchemonSheet, level: int, max_hp: int, slot: int, is_player: bool = true) -> CombatantState:
	var c := CombatantState.new(id, sheet.id, max_hp, is_player, slot, 8, 273.15)
	c.level = level
	c.attack = 50
	c.defense = 60
	c.mechanical_speed = 70
	return c


func _state(list: Array[CombatantState]) -> CombatState:
	var st := CombatState.new()
	for c in list:
		st.combatants[c.id] = c
		if c.is_player:
			st.player_ids.append(c.id)
		else:
			st.enemy_ids.append(c.id)
		if c.slot >= 0:
			st.battlefield.assign_combatant(c.id, c.slot)
	return st


## Li (id 1, cátion, inativo) + F (id 2, ativo, nível maior). Parâmetros térmicos
## ajustados para contas simples: m*cp = 10 => dT = Q/10.
func _ionic_pair() -> CombatState:
	var li := _c(1, _li(), 5, 50, 0)
	var f := _c(2, _f(), 10, 100, 1)
	var st := _state([li, f])
	var res := BondRules.apply_bond(BondRules.COMPOUND, [li, f], [db.get_by_id(1), db.get_by_id(2)], st)
	assert_str(res["kind"]).is_equal("compound_formed")
	var th := st.compound_thermals[2] as CompoundThermal
	th.total_mass = 10.0
	th.specific_heat = 1.0
	th.melting_point = 300.0
	th.boiling_point = 400.0
	th.scission_temperature = 1000.0
	th.max_delta_t = 100000.0
	th.reset_temperature(250.0)
	return st


func _th(st: CombatState) -> CompoundThermal:
	return st.compound_thermals[2] as CompoundThermal


func _hit(st: CombatState, q: float, target_id: int = 2) -> void:
	var r := CombatResult.attack_hit(99, target_id, "x", 0, false)
	r.thermal_energy = q
	CombatResultApplier.apply(st, r, db)


# --- fórmulas ----------------------------------------------------------------

func test_scission_ionic_li_f() -> void:
	assert_float(AlchemonFormulas.scission_temperature_ionic(85.0, 3.0, 1)).is_equal_approx(935.0, 0.001)


func test_scission_covalent_o_o() -> void:
	assert_float(AlchemonFormulas.scission_temperature_covalent(90.0, 90.0, 2)).is_equal_approx(390.0, 0.001)


func test_formation_computes_thermal_properties_ionic() -> void:
	var li := _c(1, _li(), 5, 50, 0)
	var f := _c(2, _f(), 10, 100, 1)
	var st := _state([li, f])
	BondRules.apply_bond(BondRules.COMPOUND, [li, f], [db.get_by_id(1), db.get_by_id(2)], st)
	var th := _th(st)
	assert_bool(th.is_ionic).is_true()
	assert_float(th.total_mass).is_equal(26.0)
	assert_float(th.specific_heat).is_equal(ThermalRules.COMPOUND_CP_IONIC)
	assert_float(th.scission_temperature).is_equal_approx(935.0, 0.001)
	assert_float(th.temperature).is_equal_approx(273.15, 0.001)
	assert_array(th.member_ids).contains_exactly([1, 2])


func test_formation_computes_thermal_properties_covalent() -> void:
	var o := _o()
	var a := _c(1, o, 5, 50, 0)
	var b := _c(2, o, 10, 100, 1)
	var st := _state([a, b])
	var res := BondRules.apply_bond(BondRules.COMPOUND, [a, b], [o, o], st)
	assert_str(res["kind"]).is_equal("compound_formed")
	var th := st.compound_thermals[res["active_id"]] as CompoundThermal
	assert_bool(th.is_ionic).is_false()
	assert_float(th.specific_heat).is_equal(ThermalRules.COMPOUND_CP_COVALENT)
	assert_float(th.scission_temperature).is_equal_approx(390.0, 0.001)
	assert_float(th.total_mass).is_equal(32.0)


func test_ionic_resists_heat_more_than_covalent() -> void:
	var q := 1000.0
	var ionic := AlchemonFormulas.compound_delta_temperature(q, 30.0, ThermalRules.COMPOUND_CP_IONIC)
	var covalent := AlchemonFormulas.compound_delta_temperature(q, 30.0, ThermalRules.COMPOUND_CP_COVALENT)
	assert_float(ionic).is_less(covalent)


# --- aquecimento e transição -------------------------------------------------

func test_attack_changes_compound_temperature_not_members() -> void:
	var st := _ionic_pair()
	_hit(st, 100.0) # +10 K
	assert_float(_th(st).temperature).is_equal_approx(260.0, 0.001)
	assert_float(st.get_combatant(1).temperature).is_equal_approx(273.15, 0.001)
	assert_float(st.get_combatant(2).temperature).is_equal_approx(273.15, 0.001)


func test_below_melting_stays_solid_without_damage() -> void:
	var st := _ionic_pair()
	_hit(st, 100.0)
	assert_str(_th(st).physical_state).is_equal(AlchemonSheet.SOLIDO)
	assert_int(st.get_combatant(2).hp).is_equal(135)


func test_fusion_damages_active_only_and_keeps_bond_and_stats() -> void:
	var st := _ionic_pair()
	var active := st.get_combatant(2)
	var cation := st.get_combatant(1)
	var max_hp := active.max_hp
	var cation_hp := cation.hp
	_hit(st, 600.0) # 310 K > 300
	var expected := ThermalRules.transition_damage(AlchemonSheet.SOLIDO, AlchemonSheet.LIQUIDO, max_hp, 10)
	assert_str(_th(st).physical_state).is_equal(AlchemonSheet.LIQUIDO)
	assert_str(_th(st).previous_physical_state).is_equal(AlchemonSheet.SOLIDO)
	assert_int(active.hp).is_equal(135 - expected)
	assert_int(cation.hp).is_equal(cation_hp)
	assert_str(active.bond_kind).is_equal(BondRules.COMPOUND)
	assert_int(active.max_hp).is_equal(max_hp)
	assert_int(active.attack).is_equal(50)
	assert_int(active.defense).is_equal(60)
	assert_int(active.mechanical_speed).is_equal(70)


func test_boiling_condensation_solidification() -> void:
	var st := _ionic_pair()
	var active := st.get_combatant(2)
	_th(st).reset_temperature(350.0) # líquido
	_hit(st, 600.0) # 410 K => ebulição
	assert_str(_th(st).physical_state).is_equal(AlchemonSheet.GASOSO)
	assert_int(active.hp).is_equal(135 - ThermalRules.transition_damage(AlchemonSheet.LIQUIDO, AlchemonSheet.GASOSO, 135, 10))
	var hp := active.hp
	_hit(st, -200.0) # 390 K => condensação
	assert_str(_th(st).physical_state).is_equal(AlchemonSheet.LIQUIDO)
	assert_int(active.hp).is_equal(hp - ThermalRules.transition_damage(AlchemonSheet.GASOSO, AlchemonSheet.LIQUIDO, 135, 10))
	hp = active.hp
	_hit(st, -1000.0) # 290 K => solidificação
	assert_str(_th(st).physical_state).is_equal(AlchemonSheet.SOLIDO)
	assert_int(active.hp).is_equal(hp - ThermalRules.transition_damage(AlchemonSheet.LIQUIDO, AlchemonSheet.SOLIDO, 135, 10))


func test_one_attack_crossing_two_phases_applies_both_transitions() -> void:
	var st := _ionic_pair()
	_hit(st, 1500.0) # 250 -> 400 K: fusão + ebulição
	assert_str(_th(st).physical_state).is_equal(AlchemonSheet.GASOSO)
	var total := ThermalRules.transition_damage(AlchemonSheet.SOLIDO, AlchemonSheet.LIQUIDO, 135, 10) \
		+ ThermalRules.transition_damage(AlchemonSheet.LIQUIDO, AlchemonSheet.GASOSO, 135, 10)
	assert_int(st.get_combatant(2).hp).is_equal(135 - total)


func test_arena_temperature_does_not_affect_compound() -> void:
	var st := _ionic_pair()
	st.arena_temperature = 5000.0
	CombatResultApplier._apply_arena_heat(st, db)
	assert_str(st.get_combatant(2).bond_kind).is_equal(BondRules.COMPOUND)
	assert_float(_th(st).temperature).is_equal_approx(250.0, 0.001)
	assert_int(st.get_combatant(2).hp).is_equal(135)


# --- cisão -------------------------------------------------------------------

func test_scission_by_absolute_temperature() -> void:
	var st := _ionic_pair()
	_th(st).reset_temperature(900.0)
	_hit(st, 1000.0) # +100 => 1000 K
	assert_str(st.get_combatant(1).bond_kind).is_equal(BondRules.NONE)
	assert_str(st.get_combatant(2).bond_kind).is_equal(BondRules.NONE)
	assert_bool(st.compound_thermals.is_empty()).is_true()


func test_scission_by_thermal_surge_below_absolute_limit() -> void:
	var st := _ionic_pair()
	_th(st).max_delta_t = 20.0
	_hit(st, 300.0) # +30 K > 20, T=280 << 1000
	assert_str(st.get_combatant(2).bond_kind).is_equal(BondRules.NONE)


func test_no_scission_when_within_limits() -> void:
	var st := _ionic_pair()
	_th(st).max_delta_t = 20.0
	_hit(st, 150.0) # +15 K
	assert_str(st.get_combatant(2).bond_kind).is_equal(BondRules.COMPOUND)


func test_scission_removes_attribute_transfer_and_restores_slots() -> void:
	var st := _ionic_pair()
	var li := st.get_combatant(1)
	var f := st.get_combatant(2)
	# Como na fábrica: o inativo perde o slot e o ativo o assume.
	st.battlefield.free_slot(0)
	li.slot = -1
	li.has_thermal_shock = true # sem choque novo: Li sobrevive (morrer libera o slot)
	_th(st).max_delta_t = 5.0
	_hit(st, 100.0) # surto
	assert_int(f.max_hp).is_equal(100)
	assert_int(li.max_hp).is_equal(50)
	assert_int(li.slot).is_not_equal(-1)
	assert_int(st.battlefield.get_occupant(li.slot)).is_equal(li.id)


func test_survivors_inherit_compound_temperature() -> void:
	var st := _ionic_pair()
	_th(st).max_delta_t = 5.0
	_hit(st, 100.0) # 260 K
	assert_float(st.get_combatant(1).temperature).is_equal_approx(260.0, 0.001)
	assert_float(st.get_combatant(2).temperature).is_equal_approx(260.0, 0.001)


# --- choque térmico (uma vez por Alchemon) -----------------------------------

func test_first_scission_shocks_both_members() -> void:
	var st := _ionic_pair()
	var li := st.get_combatant(1)
	var f := st.get_combatant(2)
	_th(st).max_delta_t = 5.0
	_hit(st, 100.0)
	assert_bool(li.has_thermal_shock).is_true()
	assert_bool(f.has_thermal_shock).is_true()
	# Li: 30% de 50 = 15 (liberado) - 20 de choque => morre (HP nunca < 0). F: 135 -> 100 clamp -> 80.
	assert_int(f.hp).is_equal(100 - ThermalRules.THERMAL_SHOCK_DAMAGE)
	assert_int(li.hp).is_equal(maxi(15 - ThermalRules.THERMAL_SHOCK_DAMAGE, 0))


func test_member_already_shocked_is_not_shocked_again_and_new_member_is() -> void:
	var st := _ionic_pair()
	var li := st.get_combatant(1)
	var f := st.get_combatant(2)
	# F já sofreu choque antes; Li não.
	f.has_thermal_shock = true
	_th(st).max_delta_t = 5.0
	var hp_before := f.hp
	_hit(st, 100.0)
	var f_hp_after_break := mini(hp_before, 100) # clamp ao max_hp restaurado
	assert_int(f.hp).is_equal(f_hp_after_break)
	assert_bool(li.has_thermal_shock).is_true()


func test_shock_flag_survives_new_compound_with_other_partner() -> void:
	# A+B rompe; depois A+C: A não leva choque de novo, C leva.
	var f_sheet := _f()
	var li_sheet := _li()
	var cl_sheet := _sheet(5, 11, 23, AlchemonType.Type.METAL, 1, 0.93, 371.0, 1156.0)
	var a := _c(2, f_sheet, 10, 100, 1)
	var b := _c(1, li_sheet, 5, 50, 0)
	var st := _state([b, a])
	BondRules.apply_bond(BondRules.COMPOUND, [b, a], [li_sheet, f_sheet], st)
	_th(st).max_delta_t = 1.0
	_hit(st, 100.0)
	assert_bool(a.has_thermal_shock).is_true()
	assert_bool(b.has_thermal_shock).is_true()

	var c := _c(7, cl_sheet, 3, 60, -1)
	st.combatants[c.id] = c
	st.player_ids.append(c.id)
	a.thermal_overload_turns = 0
	c.thermal_overload_turns = 0
	a.hp = a.max_hp
	var res := BondRules.apply_bond(BondRules.COMPOUND, [c, a], [cl_sheet, f_sheet], st)
	assert_str(res["kind"]).is_equal("compound_formed")
	var th2 := st.compound_thermals[a.id] as CompoundThermal
	th2.max_delta_t = 1.0
	th2.total_mass = 10.0
	th2.specific_heat = 1.0
	var a_hp := a.hp
	_hit(st, 100.0)
	assert_str(a.bond_kind).is_equal(BondRules.NONE)
	assert_bool(c.has_thermal_shock).is_true()
	# A não foi chocado de novo: só perdeu o excedente do max_hp restaurado, sem -20.
	assert_int(a.hp).is_equal(mini(a_hp, a.max_hp))


func test_scission_runs_only_once_per_attack() -> void:
	var st := _ionic_pair()
	_th(st).max_delta_t = 5.0
	_th(st).reset_temperature(950.0) # também acima de T_cisão
	_hit(st, 100.0)
	var f := st.get_combatant(2)
	# Um único choque por Alchemon: nunca dois descontos de 20.
	assert_int(f.hp).is_equal(100 - ThermalRules.THERMAL_SHOCK_DAMAGE)


# --- Sobrecarga Térmica ------------------------------------------------------

func test_overload_starts_after_scission_and_blocks_new_compound() -> void:
	var st := _ionic_pair()
	var li := st.get_combatant(1)
	var f := st.get_combatant(2)
	li.hp = 200 # sobrevive ao choque
	li.max_hp = 200
	_th(st).max_delta_t = 5.0
	_hit(st, 100.0)
	assert_int(f.thermal_overload_turns).is_equal(ThermalRules.OVERLOAD_TURNS)
	var res := BondRules.apply_bond(BondRules.COMPOUND, [li, f], [db.get_by_id(1), db.get_by_id(2)], st)
	assert_str(res["kind"]).is_equal("cancelled")
	assert_str(res["reason"]).is_equal("thermal_overload")


func test_overload_lasts_two_full_rounds_after_the_scission_round() -> void:
	var st := _ionic_pair()
	var f := st.get_combatant(2)
	_th(st).max_delta_t = 5.0
	_hit(st, 100.0)
	ThermalRules.tick_overload(st) # fim da rodada da cisão: não conta
	assert_int(f.thermal_overload_turns).is_equal(2)
	ThermalRules.tick_overload(st)
	assert_int(f.thermal_overload_turns).is_equal(1)
	ThermalRules.tick_overload(st)
	assert_int(f.thermal_overload_turns).is_equal(0)


func test_overload_and_shock_flag_are_independent() -> void:
	var st := _ionic_pair()
	var f := st.get_combatant(2)
	_th(st).max_delta_t = 5.0
	_hit(st, 100.0)
	for i in 4:
		ThermalRules.tick_overload(st)
	assert_int(f.thermal_overload_turns).is_equal(0)
	assert_bool(f.has_thermal_shock).is_true()


func test_overload_does_not_modify_attributes_or_block_attack_damage() -> void:
	var st := _ionic_pair()
	var f := st.get_combatant(2)
	_th(st).max_delta_t = 5.0
	_hit(st, 100.0)
	assert_int(f.attack).is_equal(50)
	assert_int(f.defense).is_equal(60)
	assert_int(f.mechanical_speed).is_equal(70)
	var hp := f.hp
	var r := CombatResult.attack_hit(99, 2, "x", 5, false)
	CombatResultApplier.apply(st, r, db)
	assert_int(f.hp).is_equal(hp - 5)
