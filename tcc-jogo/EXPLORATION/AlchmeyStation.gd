class_name AlchemyStation
extends RefCounted
## Valida a seleção do jogador no PC. A química fica em CompoundRules; aqui só
## ficam os limites de seleção (criaturas) e a escolha Mistura × Composto.

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
	if is_mixture(sheets):
		for s in sheets:
			if s == null:
				return "Unknown species in selection."
		return ""
	return CompoundRules.failure_reason(sheets)


static func is_mixture(sheets: Array[AlchemonSheet]) -> bool:
	return CompoundRules.is_mixture(sheets)


static func validate_stoichiometry(sheets: Array[AlchemonSheet]) -> bool:
	return not is_mixture(sheets) and bond_failure_reason(sheets) == ""


## Composto resultante (fórmula, composição, ligação) ou null se não houver.
static func resolve_compound(sheets: Array[AlchemonSheet]) -> CompoundData:
	if bond_failure_reason(sheets) != "" or is_mixture(sheets):
		return null
	return CompoundRules.resolve(sheets)
