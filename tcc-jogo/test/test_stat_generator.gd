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


# ---------------------------------------------------------------------------
# Integração: dados químicos -> atributos base -> instância -> progressão
# ---------------------------------------------------------------------------

const FERRO := "res://DATABASE/Alchemons/Ferro.tres"
const HIDROGENIO := "res://DATABASE/Alchemons/Hidrogenio.tres"
const SILICIO := "res://DATABASE/Alchemons/Silicio.tres"


func _sheet(path: String) -> AlchemonSheet:
	return (load(path) as AlchemonSheet).duplicate()


func test_regenerate_changes_hp_when_enthalpy_changes() -> void:
	var fe := _sheet(FERRO)
	fe.atomization_enthalpy = 850.0
	assert_bool(fe.regenerate_base_stats()).is_true()
	assert_int(fe.base_hp).is_equal(AlchemonStatGenerator.BASE_MAX)
	fe.atomization_enthalpy = 0.0
	assert_bool(fe.regenerate_base_stats()).is_true()
	assert_int(fe.base_hp).is_equal(AlchemonStatGenerator.BASE_MIN)


func test_regenerate_changes_attack_and_defense_when_ionization_changes() -> void:
	var fe := _sheet(FERRO)
	fe.regenerate_base_stats()
	var atk := fe.base_attack
	var def := fe.base_defense
	fe.first_ionization_energy = 1200.0
	fe.regenerate_base_stats()
	var s := AlchemonStatGenerator.generate_base_stats(56.0, 1200.0, 0.0, 1.83, fe.atomization_enthalpy, true)
	assert_int(fe.base_attack).is_equal(s["base_attack"])
	assert_int(fe.base_defense).is_equal(s["base_defense"])
	assert_int(fe.base_attack).is_less(atk)
	assert_int(fe.base_defense).is_greater(def)


func test_regenerate_changes_speed_when_mass_or_electronegativity_change() -> void:
	var fe := _sheet(FERRO)
	fe.regenerate_base_stats()
	var v := fe.base_mechanical_speed
	fe.atomic_mass = 10
	fe.regenerate_base_stats()
	assert_int(fe.base_mechanical_speed).is_greater(v)
	var v2 := fe.base_mechanical_speed
	fe.electronegativity = 0.8
	fe.regenerate_base_stats()
	assert_int(fe.base_mechanical_speed).is_less(v2)


func test_regeneration_keeps_chemical_data_untouched() -> void:
	var fe := _sheet(FERRO)
	var before := [fe.atomic_mass, fe.first_ionization_energy, fe.electron_affinity, fe.electronegativity, fe.atomization_enthalpy]
	fe.regenerate_base_stats()
	assert_array(before).is_equal([fe.atomic_mass, fe.first_ionization_energy, fe.electron_affinity, fe.electronegativity, fe.atomization_enthalpy])


func test_zero_enthalpy_is_valid() -> void:
	var he := AlchemonSheet.new("He", 30, 2)
	he.symbol = "He"
	he.atomic_mass = 4
	he.first_ionization_energy = 2372.3
	he.atomization_enthalpy = 0.0
	he.valence_electrons = 2
	he.octet_target = 2
	he.element_type = AlchemonType.Type.AMETAL
	assert_str(AlchemonStatGenerator.validate(he)).is_empty()


func test_noble_gas_without_electronegativity_or_affinity() -> void:
	var he := AlchemonSheet.new("He", 30, 2)
	he.symbol = "He"
	he.atomic_mass = 4
	he.first_ionization_energy = 2372.3
	he.atomization_enthalpy = 0.0
	he.valence_electrons = 2
	he.octet_target = 2
	he.element_type = AlchemonType.Type.AMETAL
	assert_bool(he.regenerate_base_stats()).is_true()
	assert_int(he.base_attack).is_equal(AlchemonStatGenerator.BASE_MIN)
	assert_int(he.base_defense).is_equal(AlchemonStatGenerator.BASE_MAX)
	assert_int(he.base_mechanical_speed).is_between(AlchemonStatGenerator.BASE_MIN, AlchemonStatGenerator.BASE_MAX)


func test_negative_electron_affinity_is_accepted() -> void:
	var si := _sheet(SILICIO)
	si.electron_affinity = -48.0
	assert_str(AlchemonStatGenerator.validate(si)).is_empty()
	si.regenerate_base_stats()
	assert_int(si.base_attack).is_equal(AlchemonStatGenerator.BASE_MIN)


func test_missing_data_returns_error_naming_element_and_property() -> void:
	var h := _sheet(HIDROGENIO)
	h.electron_affinity = AlchemonSheet.EA_UNSET
	var msg := AlchemonStatGenerator.validate(h)
	assert_str(msg).contains("H")
	assert_str(msg).contains("electron_affinity")
	var fe := _sheet(FERRO)
	fe.atomization_enthalpy = -1.0
	assert_str(AlchemonStatGenerator.validate(fe)).contains("atomization_enthalpy")
	fe.atomization_enthalpy = 400.0
	fe.atomic_mass = 0
	assert_str(AlchemonStatGenerator.validate(fe)).contains("atomic_mass")


func test_incomplete_sheet_is_not_silently_changed() -> void:
	var fe := _sheet(FERRO)
	var hp := fe.base_hp
	fe.first_ionization_energy = 0.0
	assert_bool(AlchemonStatGenerator.has_data(fe)).is_false()
	assert_bool(AlchemonStatGenerator.validate(fe) != "").is_true()
	assert_int(fe.base_hp).is_equal(hp)


func test_instance_stats_match_sheet_and_progression_formula() -> void:
	var fe := _sheet(FERRO)
	fe.regenerate_base_stats()
	var inst := AlchemonInstance.new()
	inst.individual_value = 10
	inst.level = 30
	inst.personality = AlchemonPersonality.NEUTRAL
	var st := inst.compute_stats(fe)
	assert_int(st["attack"]).is_equal(int(floor(0.01 * (2 * fe.base_attack + 10) * 30)) + 5)
	assert_int(st["defense"]).is_equal(int(floor(0.01 * (2 * fe.base_defense + 10) * 30)) + 5)
	assert_int(st["max_hp"]).is_equal(int(floor(0.01 * (2 * fe.base_hp + 10) * 30)) + 5)
	assert_int(st["mechanical_speed"]).is_equal(int(floor(0.01 * (2 * fe.base_mechanical_speed + 10) * 30)) + 5)


func test_database_regeneration_report() -> void:
	var db: AlchemonDatabase = load(DB_PATH).duplicate()
	var report := db.regenerate_all_base_stats()
	assert_dict(report["failed"]).is_empty()
	assert_int(report["updated"].size()).is_equal(db.alchemons.size())
