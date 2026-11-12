class_name AlchemyStation
extends RefCounted
## Valida a seleção do jogador no PC. A química fica em CompoundRules; aqui só
## ficam os limites de seleção (criaturas) e a escolha Composto × Mistura
## (composto = iônico ou covalente; todo o resto é mistura).

const MAX_VALENCE := 8
const MIN_BOND_SIZE := 2
const MAX_BOND_SIZE := 4


## Composto (iônico/covalente) se a combinação fecha; senão MISTURA (par de 2).
## NONE só para seleção inválida (tamanho, espécie desconhecida, ficha incoerente)
## ou grupo de 3+ que não forma composto (mistura é sempre de 2).
static func determine_bond_kind(sheets: Array[AlchemonSheet]) -> String:
	if _selection_problem(sheets) != "":
		return BondRules.NONE
	if CompoundRules.resolve(sheets) != null:
		return BondRules.COMPOUND
	if is_mixture(sheets):
		return BondRules.MIXTURE
	return BondRules.NONE


## "" se forma composto ou mistura; senão o motivo da rejeição.
static func bond_failure_reason(sheets: Array[AlchemonSheet]) -> String:
	var problem := _selection_problem(sheets)
	if problem != "":
		return problem
	if CompoundRules.resolve(sheets) != null or is_mixture(sheets):
		return ""
	return "Not a compound, and a Mixture takes exactly 2 Alchemons. " + CompoundRules.failure_reason(sheets)


static func _selection_problem(sheets: Array[AlchemonSheet]) -> String:
	if sheets.size() < MIN_BOND_SIZE:
		return "Need at least %d Alchemons." % MIN_BOND_SIZE
	if sheets.size() > MAX_BOND_SIZE:
		return "Max %d Alchemons per Component." % MAX_BOND_SIZE
	for s in sheets:
		if s == null:
			return "Unknown species in selection."
		var problem := s.chemistry_problem()
		if problem != "":
			return problem
	return ""


## Mistura = nenhum dos 2 tipos de composto (iônico/covalente) se formou.
static func is_mixture(sheets: Array[AlchemonSheet]) -> bool:
	return CompoundRules.is_mixture(sheets)


static func validate_stoichiometry(sheets: Array[AlchemonSheet]) -> bool:
	return _selection_problem(sheets) == "" and CompoundRules.resolve(sheets) != null


## Composto resultante (fórmula, composição, ligação) ou null se não houver.
static func resolve_compound(sheets: Array[AlchemonSheet]) -> CompoundData:
	if _selection_problem(sheets) != "":
		return null
	return CompoundRules.resolve(sheets)
