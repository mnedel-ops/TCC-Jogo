class_name BondRules
extends RefCounted

## Efeito MECANICO de um laco em combate (GDD sec 9). A decisao quimica
## (Mistura vs Composto vs impossivel, Regra do Octeto) ja aconteceu na
## PC antes da batalha - ver AlchemyStation.determine_bond_kind(). Aqui
## so aplica o resultado: bonus fixo pra Mistura; transferencia de
## atributo + Cation invisivel/Anion ativo pra Composto.
##
## BondRules NUNCA calcula eletron nem decide se um grupo e quimicamente
## possivel - recebe o `kind` pronto e o grupo INTEIRO de Alchemons
## envolvidos, todos ja presentes (a PC garantiu isso antes de liberar o
## grupo pra batalha - combate nao reavalia quantidade/estequiometria).

const NONE := "none"
const MIXTURE := "mixture"
const COMPOUND := "compound"

const MIXTURE_BONUS := 8              # flat, GDD sec 9.1, aplicado em HP e Energia
const COMPOUND_TRANSFER_RATIO := 0.7  # GDD sec 9.2, % dos atributos de cada doador que o membro ativo absorve
const COMPOUND_RELEASE_HP_RATIO := 0.3       # pops out with 70% less HP
const COMPOUND_RELEASE_FALLBACK_ENERGY := 11 # placeholder when active had 0 energy

## Aplica um vinculo de tipo `kind` (ja resolvido pela AlchemyStation) ao
## grupo de combatentes correspondente. Retorna um Dictionary de
## resultado (nunca lanca erro) - "cancelled" com "reason" se o grupo em
## si estiver invalido (morto, ja bondado, tamanho errado pro kind).
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


## Membro ativo (GDD 9.2): o Anion, numa ligacao ionica (metal presente -
## metal nunca e o ativo); o de maior nivel, numa ligacao covalente (sem
## metal). Todo mundo que nao e o ativo transfere COMPOUND_TRANSFER_RATIO
## das suas estatisticas pro ativo e sai da lista de acao
## (is_bond_inactive) - metais especificamente tambem ganham
## is_bond_cation (ficam visiveis e invulneraveis em campo, GDD 9.2).
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
			continue  # cation nunca e o ativo
		if participants[i].level > best_level:
			best_level = participants[i].level
			best_index = i
	return best_index

## Active member of a compound fell: every bonded partner leaves the bond
## and becomes a normal, targetable combatant.
## HP = 30% of its max_hp (min 1). Energy = what the fallen one had left;
## 0 -> COMPOUND_RELEASE_FALLBACK_ENERGY (placeholder).
static func release_compound_partners(state: CombatState, fallen: CombatantState) -> void:
	if fallen.bond_kind != COMPOUND or fallen.is_bond_inactive or fallen.is_bond_cation:
		return   # only the active member triggers a release
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
