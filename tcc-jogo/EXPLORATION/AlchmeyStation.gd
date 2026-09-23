class_name AlchemyStation
extends RefCounted

static func determine_bond_kind(sheets: Array[AlchemonSheet]) -> String:
	if sheets.size() < 2:
		return BondRules.NONE
	if is_mixture(sheets):
		return BondRules.MIXTURE
	if validate_stoichiometry(sheets):
		return BondRules.COMPOUND
	return BondRules.NONE

static func is_mixture(sheets: Array[AlchemonSheet]) -> bool:
	if sheets.size() != 2:
		return false
	return sheets[0].element_type == AlchemonType.Type.METAL and sheets[1].element_type == AlchemonType.Type.METAL

static func validate_stoichiometry(sheets: Array[AlchemonSheet]) -> bool:
	if sheets.size() != 2:
		return false
	
	var metal: Array[AlchemonSheet]= []
	var non_metal: Array[AlchemonSheet]= []
	
	for s in sheets:
		if s.element_type ==AlchemonType.Type.METAL:
			metal.append(s)
		else:
			non_metal.append(s)
			
		if metal.is_empty():
			return _validate_covalent(sheets)
		if non_metal.is_empty():
			return false
		return _validate_ionic(metal, non_metal)

static func _validate_ionic(metals: Array[AlchemonSheet], non_metals: Array[AlchemonSheet]) -> bool:
	var donated := 0
	for m in metals:
		donated += m.max_valence_electrons
	var needed := 0
	for n in non_metals:
		needed += maxi(n.octet_target - n.max_valence_electrons, 0)
	return needed > 0 and donated == needed
	
static func _validate_covalent(sheets: Array[AlchemonSheet]) -> bool:
	var target_sum := 0
	var valence_sum := 0
	for s in sheets:
		target_sum += s.octet_target
		valence_sum += s.max_valence_electrons

	var shared := target_sum - valence_sum
	if shared < 0 or shared % 2 != 0:
		return false
	var bonds := shared / 2
	return bonds >= sheets.size() - 1
