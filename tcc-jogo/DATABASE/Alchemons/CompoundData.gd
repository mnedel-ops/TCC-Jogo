class_name CompoundData
extends Resource


enum BondType { IONIC, COVALENT_POLAR, COVALENT_NONPOLAR }

const _SUB := ["₀", "₁", "₂", "₃", "₄", "₅", "₆", "₇", "₈", "₉"]

@export var compound_name: String = ""
@export var chemical_formula: String = ""
# element_key -> quantidade (ex.: {12: 1, 17: 2} para MgCl2)
@export var composition: Dictionary = {}
@export var bond_type: BondType = BondType.IONIC
@export var total_charge: int = 0
# Covalente: [{"a": element_key, "b": element_key, "order": 1..3}, ...]
@export var bonds: Array[Dictionary] = []


func atom_count() -> int:
	var total := 0
	for q in composition.values():
		total += int(q)
	return total


func is_ionic() -> bool:
	return bond_type == BondType.IONIC


func bond_type_label() -> String:
	match bond_type:
		BondType.IONIC:
			return "iônica"
		BondType.COVALENT_POLAR:
			return "covalente polar"
	return "covalente apolar"


static func subscript(n: int) -> String:
	if n <= 1:
		return ""
	var out := ""
	for ch in str(n):
		out += _SUB[int(ch)]
	return out


func to_dict() -> Dictionary:
	return {
		"name": compound_name,
		"formula": chemical_formula,
		"composition": composition.duplicate(),
		"bond_type": int(bond_type),
		"charge": total_charge,
		"bonds": bonds.duplicate(true),
	}
