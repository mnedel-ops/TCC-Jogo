class_name PlayerBondData
extends Resource

## The "Component" the player made at the PC: one bond (Mixture/Compound).
## Carried into EVERY fight. CombatStateFactory applies it. Player never
## auto-bonds in combat. NPCs still auto-bond (CombatStateFactory._try_bond).
##
## member_indices = positions in PlayerPartyData.party (= battle slot order).
## PC clears this when the party changes, so indices never go stale.

@export var kind: String = BondRules.NONE
@export var member_indices: Array[int] = []


func is_active() -> bool:
	return kind != BondRules.NONE and member_indices.size() >= 2


func set_bond(p_kind: String, indices: Array[int]) -> void:
	kind = p_kind
	member_indices = indices.duplicate()
	emit_changed()


func clear() -> void:
	kind = BondRules.NONE
	member_indices.clear()
	emit_changed()
