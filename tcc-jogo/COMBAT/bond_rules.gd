class_name BondRules
extends RefCounted


const NONE := "none"
const MIXTURE := "mixture"
const COMPOUND := "compound"

const MIXTURE_BONUS := 8
const COMPOUND_TRANSFER_RATIO := 0.7
const COMPOUND_RELEASE_HP_RATIO := 0.3
const COMPOUND_RELEASE_FALLBACK_ENERGY := 11

static func apply_bond(kind: String, participants: Array[CombatantState], sheets: Array[AlchemonSheet]) -> Dictionary:
	if participants.size() != sheets.size() or participants.size() < 2:
		return {"kind": "cancelled", "reason": "invalid_bond_group"}
	for c in participants:
		if c == null or not c.alive:
			return {"kind": "cancelled", "reason": "invalid_bond_target"}
		if c.bond_kind != NONE:
			return {"kind": "cancelled", "reason": "already_bonded"}

	match kind:
		MIXTURE:
			if participants.size() != 2:
				return {"kind": "cancelled", "reason": "invalid_bond_group"}
			_apply_mixture(participants[0], participants[1])
			return {"kind": "mixture_formed", "member_ids": [participants[0].id, participants[1].id]}
		COMPOUND:
			return _apply_compound_group(participants, sheets)
		_:
			return {"kind": "cancelled", "reason": "unsupported_bond_kind"}


static func _apply_mixture(a: CombatantState, b: CombatantState) -> void:
	a.max_hp += MIXTURE_BONUS
	a.hp += MIXTURE_BONUS
	a.max_valence_electrons += MIXTURE_BONUS
	a.valence_electrons += MIXTURE_BONUS
	a.bond_kind = MIXTURE
	a.bond_partner_id = b.id

	b.max_hp += MIXTURE_BONUS
	b.hp += MIXTURE_BONUS
	b.max_valence_electrons += MIXTURE_BONUS
	b.valence_electrons += MIXTURE_BONUS
	b.bond_kind = MIXTURE
	b.bond_partner_id = a.id


static func _apply_compound_group(participants: Array[CombatantState], sheets: Array[AlchemonSheet]) -> Dictionary:
	var has_metal := false
	for s in sheets:
		if s.element_type == AlchemonType.Type.METAL:
			has_metal = true
			break

	var active_index := _pick_active_index(participants, sheets, has_metal)
	if active_index == -1:
		return {"kind": "cancelled", "reason": "no_valid_active_member"}
	var active := participants[active_index]

	for i in participants.size():
		var c := participants[i]
		c.bond_kind = COMPOUND
		c.bond_partner_id = active.id
		if i == active_index:
			continue
		c.is_bond_inactive = true
		if sheets[i].element_type == AlchemonType.Type.METAL:
			c.is_bond_cation = true
		var hp_transfer := int(floor(c.max_hp * COMPOUND_TRANSFER_RATIO))
		var energy_transfer := int(floor(c.max_valence_electrons * COMPOUND_TRANSFER_RATIO))
		active.max_hp += hp_transfer
		active.hp += hp_transfer
		active.max_valence_electrons += energy_transfer
		active.valence_electrons += energy_transfer

	var member_ids: Array[int] = []
	for c in participants:
		member_ids.append(c.id)

	return {"kind": "compound_formed", "active_id": active.id, "member_ids": member_ids}


static func _pick_active_index(participants: Array[CombatantState], sheets: Array[AlchemonSheet], has_metal: bool) -> int:
	var best_index := -1
	var best_level := -1
	for i in participants.size():
		if has_metal and sheets[i].element_type == AlchemonType.Type.METAL:
			continue
		if participants[i].level > best_level:
			best_level = participants[i].level
			best_index = i
	return best_index

static func release_compound_partners(state: CombatState, fallen: CombatantState) -> void:
	if fallen.bond_kind != COMPOUND or fallen.is_bond_inactive or fallen.is_bond_cation:
		return
	var energy := fallen.valence_electrons
	if energy <= 0:
		energy = COMPOUND_RELEASE_FALLBACK_ENERGY
	for id in state.combatants:
		var c: CombatantState = state.combatants[id]
		if c == fallen or not c.alive:
			continue
		if c.bond_kind != COMPOUND or c.bond_partner_id != fallen.id:
			continue
		c.bond_kind = NONE
		c.bond_partner_id = -1
		c.is_bond_cation = false
		c.is_bond_inactive = false
		c.hp = clampi(int(floor(c.max_hp * COMPOUND_RELEASE_HP_RATIO)), 1, c.max_hp)
		c.max_valence_electrons = maxi(c.max_valence_electrons, energy)
		c.valence_electrons = energy
