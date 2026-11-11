extends GdUnitTestSuite

# Elementos reais: [Z, símbolo, categoria, valência, eletroneg., oxidação, capacidade]
const M := AlchemonSheet.Category.METAL
const A := AlchemonSheet.Category.AMETAL
const MD := AlchemonSheet.Category.METALOIDE
const NG := AlchemonSheet.Category.GAS_NOBRE


func _el(z: int, sym: String, cat: int, val: int, en: float, ox: Array[int], cap: int) -> AlchemonSheet:
	var s := AlchemonSheet.new(sym, 30, z)
	s.atomic_number = z
	s.symbol = sym
	s.element_category = cat
	s.valence_electrons = val
	s.electronegativity = en
	s.oxidation_states = ox
	s.bonding_capacity = cap
	return s


func _h() -> AlchemonSheet: return _el(1, "H", A, 1, 2.20, [1, -1], 1)
func _c() -> AlchemonSheet: return _el(6, "C", A, 4, 2.55, [4, -4, 2], 4)
func _n() -> AlchemonSheet: return _el(7, "N", A, 5, 3.04, [-3, 5, 3], 3)
func _o() -> AlchemonSheet: return _el(8, "O", A, 6, 3.44, [-2], 2)
func _f() -> AlchemonSheet: return _el(9, "F", A, 7, 3.98, [-1], 1)
func _he() -> AlchemonSheet: return _el(2, "He", NG, 2, 0.0, [], 0)
func _na() -> AlchemonSheet: return _el(11, "Na", M, 1, 0.93, [1], 0)
func _mg() -> AlchemonSheet: return _el(12, "Mg", M, 2, 1.31, [2], 0)
func _al() -> AlchemonSheet: return _el(13, "Al", M, 3, 1.61, [3], 0)
func _cl() -> AlchemonSheet: return _el(17, "Cl", A, 7, 3.16, [-1, 1, 5, 7], 1)
func _fe() -> AlchemonSheet: return _el(26, "Fe", M, 2, 1.83, [3, 2], 0)
func _si() -> AlchemonSheet: return _el(14, "Si", MD, 4, 1.90, [4, -4], 4)


func _resolve(list: Array) -> CompoundData:
	var sheets: Array[AlchemonSheet] = []
	for s in list:
		sheets.append(s)
	return CompoundRules.resolve(sheets)


func _formula(list: Array) -> String:
	var d := _resolve(list)
	return d.chemical_formula if d != null else ""


# --- testes obrigatórios -------------------------------------------------

func test_required_combinations() -> void:
	assert_str(_formula([_na(), _cl()])).is_equal("NaCl")
	assert_str(_formula([_mg(), _cl()])).is_equal("MgCl₂")
	assert_str(_formula([_h(), _o()])).is_equal("H₂O")
	assert_str(_formula([_c(), _o()])).is_equal("CO₂")
	assert_str(_formula([_c(), _h()])).is_equal("CH₄")
	assert_str(_formula([_na(), _o()])).is_equal("Na₂O")


func test_na_na_rejected_as_ionic() -> void:
	assert_object(_resolve([_na(), _na()])).is_null()
	var sheets: Array[AlchemonSheet] = [_na(), _na()]
	assert_str(CompoundRules.failure_reason(sheets)).is_not_empty()


func test_o2_elemental_molecule() -> void:
	var d := _resolve([_o(), _o()])
	assert_object(d).is_not_null()
	assert_str(d.chemical_formula).is_equal("O₂")
	assert_int(d.bonds[0].order).is_equal(2)
	assert_int(d.bond_type).is_equal(CompoundData.BondType.COVALENT_NONPOLAR)


func test_allotropes_by_number_of_copies() -> void:
	var o3 := _resolve([_o(), _o(), _o()])
	assert_object(o3).is_not_null()
	assert_str(o3.chemical_formula).is_equal("O₃")
	assert_str(o3.compound_name).is_equal("Ozônio")
	assert_int(o3.bond_type).is_equal(CompoundData.BondType.COVALENT_NONPOLAR)
	assert_str(_formula([_el(15, "P", A, 5, 2.19, [-3, 3, 5], 3), _el(15, "P", A, 5, 2.19, [-3, 3, 5], 3),
			_el(15, "P", A, 5, 2.19, [-3, 3, 5], 3), _el(15, "P", A, 5, 2.19, [-3, 3, 5], 3)])).is_equal("P₄")
	assert_str(_formula([_o(), _o()])).is_equal("O₂")


func test_unknown_allotropes_rejected() -> void:
	assert_object(_resolve([_h(), _h(), _h()])).is_null()
	assert_object(_resolve([_n(), _n(), _n(), _n()])).is_null()
	assert_object(_resolve([_o(), _o(), _o(), _o()])).is_null()


# --- complementares ------------------------------------------------------

func test_ionic_proportions() -> void:
	assert_str(_formula([_al(), _o()])).is_equal("Al₂O₃")
	assert_str(_formula([_mg(), _o()])).is_equal("MgO")
	assert_str(_formula([_fe(), _cl()])).is_equal("FeCl₃")
	assert_str(_formula([_na(), _mg(), _cl()])).is_equal("NaMgCl₃")


func test_covalent_molecules() -> void:
	assert_str(_formula([_n(), _h()])).is_equal("NH₃")
	assert_str(_formula([_c(), _cl()])).is_equal("CCl₄")
	assert_str(_formula([_si(), _o()])).is_equal("SiO₂")
	assert_str(_formula([_c(), _h(), _o()])).is_equal("CH₂O")


func test_elemental_molecules() -> void:
	assert_str(_formula([_h(), _h()])).is_equal("H₂")
	var n2 := _resolve([_n(), _n()])
	assert_str(n2.chemical_formula).is_equal("N₂")
	assert_int(n2.bonds[0].order).is_equal(3)


func test_rejections() -> void:
	assert_object(_resolve([_c(), _c()])).is_null()
	assert_object(_resolve([_he(), _cl()])).is_null()
	assert_object(_resolve([_na(), _cl(), _he()])).is_null()
	assert_object(_resolve([_na(), _mg()])).is_null()
	assert_object(_resolve([])).is_null()


func test_bond_types() -> void:
	assert_int(_resolve([_na(), _cl()]).bond_type).is_equal(CompoundData.BondType.IONIC)
	assert_int(_resolve([_h(), _o()]).bond_type).is_equal(CompoundData.BondType.COVALENT_POLAR)
	assert_int(_resolve([_c(), _h()]).bond_type).is_equal(CompoundData.BondType.COVALENT_NONPOLAR)


func test_known_names() -> void:
	assert_str(_resolve([_h(), _o()]).compound_name).is_equal("Água")
	assert_str(_resolve([_na(), _cl()]).compound_name).is_equal("Cloreto de sódio")


# --- propriedades --------------------------------------------------------

func test_order_and_duplicates_do_not_matter() -> void:
	assert_str(_formula([_cl(), _mg()])).is_equal("MgCl₂")
	assert_str(_formula([_cl(), _mg(), _cl()])).is_equal("MgCl₂")
	assert_str(_formula([_o(), _h(), _o()])).is_equal("H₂O")


func test_ionic_total_charge_is_zero() -> void:
	for pair in [[_na(), _cl()], [_mg(), _cl()], [_al(), _o()], [_fe(), _o()]]:
		var d := _resolve(pair)
		assert_int(d.total_charge).is_equal(0)
		assert_int(d.atom_count()).is_less_equal(CompoundRules.MAX_ATOMS)


func test_covalent_valences_are_closed() -> void:
	var sheets: Array[AlchemonSheet] = [_c(), _h(), _o()]
	var d := CompoundRules.resolve(sheets)
	var degree := {}
	for b in d.bonds:
		degree[b.a] = int(degree.get(b.a, 0)) + int(b.order)
		degree[b.b] = int(degree.get(b.b, 0)) + int(b.order)
	assert_int(degree[6]).is_equal(4 * int(d.composition[6]))
	assert_int(degree[8]).is_equal(2 * int(d.composition[8]))
	assert_int(degree[1]).is_equal(1 * int(d.composition[1]))


func test_legacy_sheet_fallback() -> void:
	# Sheet antiga (sem campos químicos): metal valência 2 + ametal valência 6 -> 1:1
	var metal := AlchemonSheet.new("Metal", 30, 2)
	metal.element_type = AlchemonType.Type.METAL
	metal.max_valence_electrons = 2
	var ametal := AlchemonSheet.new("Ametal", 30, 3)
	ametal.element_type = AlchemonType.Type.AMETAL
	ametal.max_valence_electrons = 6
	var d := _resolve([metal, ametal])
	assert_object(d).is_not_null()
	assert_int(d.atom_count()).is_equal(2)
