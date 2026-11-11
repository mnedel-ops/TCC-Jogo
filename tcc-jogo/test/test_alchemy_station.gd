extends GdUnitTestSuite


func _sheet(id: int, type: AlchemonType.Type, valence: int, octet: int = 8) -> AlchemonSheet:
	var s := AlchemonSheet.new("S%d" % id, 30, id)
	s.element_type = type
	s.max_valence_electrons = valence
	s.octet_target = octet
	return s


func _kind(list: Array) -> String:
	var sheets: Array[AlchemonSheet] = []
	for s in list:
		sheets.append(s)
	return AlchemyStation.determine_bond_kind(sheets)


func test_ionic_pair_balances_electrons() -> void:
	var metal := _sheet(1, AlchemonType.Type.METAL, 2)
	var ametal := _sheet(2, AlchemonType.Type.AMETAL, 6)
	assert_str(_kind([metal, ametal])).is_equal(BondRules.COMPOUND)
	# Proporção calculada: metal +3 com ametal -2 forma X₂Y₃ (antes era rejeitado).
	assert_str(_kind([_sheet(3, AlchemonType.Type.METAL, 3), ametal])).is_equal(BondRules.COMPOUND)
	# Sem estado de oxidação positivo (valência 0) não doa elétron.
	assert_str(_kind([_sheet(4, AlchemonType.Type.METAL, 0), ametal])).is_equal(BondRules.NONE)


func test_ionic_with_three_and_four_members() -> void:
	var m1 := _sheet(1, AlchemonType.Type.METAL, 1)
	var m2 := _sheet(2, AlchemonType.Type.METAL, 1)
	var a := _sheet(3, AlchemonType.Type.AMETAL, 6)
	assert_str(_kind([m1, m2, a])).is_equal(BondRules.COMPOUND)
	var m3 := _sheet(4, AlchemonType.Type.METAL, 2)
	var m4 := _sheet(5, AlchemonType.Type.METAL, 2)
	var a2 := _sheet(6, AlchemonType.Type.AMETAL, 6)
	var a3 := _sheet(7, AlchemonType.Type.METALOIDE, 6)
	assert_str(_kind([m3, m4, a2, a3])).is_equal(BondRules.COMPOUND)
	assert_str(_kind([m3, m4, a2])).is_equal(BondRules.COMPOUND)


func test_full_octet_atom_cannot_join_ionic_bond() -> void:
	var metal := _sheet(1, AlchemonType.Type.METAL, 2)
	var ametal := _sheet(2, AlchemonType.Type.AMETAL, 6)
	var noble := _sheet(3, AlchemonType.Type.AMETAL, 8)
	assert_str(_kind([metal, ametal, noble])).is_equal(BondRules.NONE)


func test_covalent_molecules() -> void:
	var o1 := _sheet(1, AlchemonType.Type.AMETAL, 6)
	var o2 := _sheet(2, AlchemonType.Type.AMETAL, 6)
	var c := _sheet(3, AlchemonType.Type.METALOIDE, 4)
	assert_str(_kind([o1, o2])).is_equal(BondRules.COMPOUND)
	assert_str(_kind([o1, c, o2])).is_equal(BondRules.COMPOUND)
	var f1 := _sheet(4, AlchemonType.Type.AMETAL, 7)
	var f2 := _sheet(5, AlchemonType.Type.AMETAL, 7)
	# Quantidades são calculadas: C com dois flúores diferentes fecha em CF₂F'₂.
	assert_str(_kind([c, f1, f2])).is_equal(BondRules.COMPOUND)
	assert_str(_kind([o1, f1])).is_equal(BondRules.COMPOUND)
	# Mesmo gás nobre não liga com nada.
	assert_str(_kind([o1, _sheet(6, AlchemonType.Type.AMETAL, 8)])).is_equal(BondRules.NONE)


func test_octet_limit_and_size_limit() -> void:
	var metal := _sheet(1, AlchemonType.Type.METAL, 2)
	var big := _sheet(2, AlchemonType.Type.AMETAL, 6, 10)
	assert_str(_kind([metal, big])).is_equal(BondRules.NONE)
	var list: Array = []
	for i in AlchemyStation.MAX_BOND_SIZE + 1:
		list.append(_sheet(10 + i, AlchemonType.Type.AMETAL, 6))
	assert_str(_kind(list)).is_equal(BondRules.NONE)


func test_mixture_only_for_two_metals() -> void:
	var m1 := _sheet(1, AlchemonType.Type.METAL, 2)
	var m2 := _sheet(2, AlchemonType.Type.METAL, 2)
	var m3 := _sheet(3, AlchemonType.Type.METAL, 2)
	assert_str(_kind([m1, m2])).is_equal(BondRules.MIXTURE)
	assert_str(_kind([m1, m2, m3])).is_equal(BondRules.NONE)


func test_failure_reason_explains_rejection() -> void:
	var metal := _sheet(1, AlchemonType.Type.METAL, 3)
	var ametal := _sheet(2, AlchemonType.Type.AMETAL, 6)
	var sheets: Array[AlchemonSheet] = [_sheet(5, AlchemonType.Type.METAL, 7), ametal]
	assert_str(AlchemyStation.bond_failure_reason(sheets)).contains("balance")
	var lone: Array[AlchemonSheet] = [metal, metal]
	assert_str(AlchemyStation.bond_failure_reason(lone)).is_empty()


func test_three_member_compound_in_combat() -> void:
	var db := AlchemonDatabase.new()
	db.alchemons.append(_sheet(1, AlchemonType.Type.METAL, 1))
	db.alchemons.append(_sheet(2, AlchemonType.Type.METAL, 1))
	db.alchemons.append(_sheet(3, AlchemonType.Type.AMETAL, 6))
	db.alchemons.append(_sheet(9, AlchemonType.Type.METAL, 2))
	var party: Array[AlchemonInstance] = []
	for id in [1, 2, 3]:
		party.append(CreatureFactory.create(id, 5))
	var bond := PlayerBondData.new()
	bond.set_bond(BondRules.COMPOUND, [0, 1, 2])
	var enemies: Array[int] = [9]
	var st := CombatStateFactory.build(db, party, enemies, 3, bond)
	assert_int(st.player_ids.size()).is_equal(3)
	for id in st.player_ids:
		assert_str(st.get_combatant(id).bond_kind).is_equal(BondRules.COMPOUND)
	var active := st.get_active_ids(st.player_ids)
	assert_int(active.size()).is_equal(1)
	var lead := st.get_combatant(active[0])
	assert_int(lead.species_id).is_equal(3)
	assert_bool(lead.slot >= 0).is_true()
	assert_int(st.battlefield.get_occupant(lead.slot)).is_equal(lead.id)
