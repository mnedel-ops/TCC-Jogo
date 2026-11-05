class_name AlchemyStation
extends RefCounted

const MAX_VALENCE := 8
const MIN_BOND_SIZE := 2
const MAX_BOND_SIZE := 4


static func determine_bond_kind(sheets: Array[AlchemonSheet]) -> String:
	if bond_failure_reason(sheets) != "":
		return BondRules.NONE
	if is_mixture(sheets):
		return BondRules.MIXTURE
	return BondRules.COMPOUND


static func bond_failure_reason(sheets: Array[AlchemonSheet]) -> String:
	if sheets.size() < MIN_BOND_SIZE:
		return "Need at least %d Alchemons." % MIN_BOND_SIZE
	if sheets.size() > MAX_BOND_SIZE:
		return "Max %d Alchemons per Component." % MAX_BOND_SIZE
	for s in sheets:
		if s == null:
			return "Unknown species in selection."
		if s.octet_target > MAX_VALENCE or s.octet_target < 1:
			return "%s breaks the octet limit (max %d)." % [s.creature_name, MAX_VALENCE]
		if s.max_valence_electrons < 0 or s.max_valence_electrons > s.octet_target:
			return "%s has an invalid valence shell." % s.creature_name
	if is_mixture(sheets):
		return ""
	var metals: Array[AlchemonSheet] = []
	var non_metals: Array[AlchemonSheet] = []
	for s in sheets:
		if s.element_type == AlchemonType.Type.METAL:
			metals.append(s)
		else:
			non_metals.append(s)
	if non_metals.is_empty():
		return "Metals only bond as a Mixture (2 metals)."
	if metals.is_empty():
		return _covalent_failure(sheets)
	return _ionic_failure(metals, non_metals)


static func is_mixture(sheets: Array[AlchemonSheet]) -> bool:
	if sheets.size() != 2:
		return false
	return sheets[0].element_type == AlchemonType.Type.METAL and sheets[1].element_type == AlchemonType.Type.METAL


static func validate_stoichiometry(sheets: Array[AlchemonSheet]) -> bool:
	return not is_mixture(sheets) and bond_failure_reason(sheets) == ""


# Ligação iônica: metais doam todos os elétrons de valência, ametais/metaloides
# recebem até completar o octeto (nunca passam de 8). O composto é neutro quando
# elétrons doados == elétrons recebidos.
static func _ionic_failure(metals: Array[AlchemonSheet], non_metals: Array[AlchemonSheet]) -> String:
	var donated := 0
	for m in metals:
		if m.max_valence_electrons <= 0:
			return "%s has no valence electron to donate." % m.creature_name
		donated += m.max_valence_electrons
	var needed := 0
	for n in non_metals:
		var gap := n.octet_target - n.max_valence_electrons
		if gap <= 0:
			return "%s already has a full octet and cannot bond." % n.creature_name
		needed += gap
	if donated != needed:
		return "Electrons do not balance: %d donated, %d needed to complete the octet." % [donated, needed]
	return ""


# Ligação covalente: cada átomo faz (octeto − valência) ligações. É preciso uma
# molécula conectada e sem laços: grau par, nenhum grau zero, pelo menos n−1
# ligações e nenhum átomo com mais ligações que todos os outros juntos.
static func _covalent_failure(sheets: Array[AlchemonSheet]) -> String:
	var total := 0
	var biggest := 0
	for s in sheets:
		var capacity := s.octet_target - s.max_valence_electrons
		if capacity < 1:
			return "%s already has a full octet and cannot bond." % s.creature_name
		total += capacity
		biggest = maxi(biggest, capacity)
	if total % 2 != 0:
		return "Odd number of shared electrons: bonds cannot pair up."
	if total < 2 * (sheets.size() - 1):
		return "Not enough bonds to connect every Alchemon."
	if biggest > total - biggest:
		return "One Alchemon needs more bonds than the others can supply."
	return ""
