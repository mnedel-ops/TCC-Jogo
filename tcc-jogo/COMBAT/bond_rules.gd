class_name BondRules
extends RefCounted


const NONE := "none"
const MIXTURE := "mixture"
const COMPOUND := "compound"

const MIXTURE_BONUS := 8
const COMPOUND_TRANSFER_RATIO := 0.7
const COMPOUND_RELEASE_HP_RATIO := 0.3
const COMPOUND_RELEASE_FALLBACK_ENERGY := 11

## Se `state` vier preenchido, os dados térmicos do Composto são guardados nele
## (state.compound_thermals). O resultado traz sempre a chave "thermal" no Composto.
static func apply_bond(kind: String, participants: Array[CombatantState], sheets: Array[AlchemonSheet], state: CombatState = null) -> Dictionary:
	if participants.size() != sheets.size() or participants.size() < 2:
		return {"kind": "cancelled", "reason": "invalid_bond_group"}
	for c in participants:
		if c == null or not c.alive:
			return {"kind": "cancelled", "reason": "invalid_bond_target"}
		if c.bond_kind != NONE:
			return {"kind": "cancelled", "reason": "already_bonded"}
		if kind == COMPOUND and ThermalRules.is_overloaded(c):
			return {"kind": "cancelled", "reason": "thermal_overload"}

	match kind:
		MIXTURE:
			if participants.size() != 2:
				return {"kind": "cancelled", "reason": "invalid_bond_group"}
			_apply_mixture(participants[0], participants[1])
			return {"kind": "mixture_formed", "member_ids": [participants[0].id, participants[1].id]}
		COMPOUND:
			var result := _apply_compound_group(participants, sheets)
			if result.get("kind", "") == "compound_formed":
				var active: CombatantState = null
				for c in participants:
					if c.id == int(result["active_id"]):
						active = c
				var start_temperature := state.arena_temperature if state != null else active.temperature
				var thermal := build_compound_thermal(participants, sheets, active, start_temperature)
				result["thermal"] = thermal
				if state != null:
					state.compound_thermals[active.id] = thermal
			return result
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
	state.compound_thermals.erase(fallen.id)
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


static func break_compound(state: CombatState, member: CombatantState) -> bool:
	if member == null or member.bond_kind != COMPOUND:
		return false
	var active_id := member.bond_partner_id
	var active: CombatantState = state.get_combatant(active_id)
	var group: Array[CombatantState] = []
	for id in state.combatants:
		var c: CombatantState = state.combatants[id]
		if c.bond_kind == COMPOUND and c.bond_partner_id == active_id:
			group.append(c)
	if group.is_empty():
		return false
	state.compound_thermals.erase(active_id)

	if active != null and active.bond_kind == COMPOUND and active.bond_partner_id == active_id:
		for c in group:
			if c == active:
				continue
			active.max_hp = maxi(active.max_hp - int(floor(c.max_hp * COMPOUND_TRANSFER_RATIO)), 1)
			active.max_valence_electrons = maxi(active.max_valence_electrons - int(floor(c.max_valence_electrons * COMPOUND_TRANSFER_RATIO)), 0)
		if active.alive:
			active.hp = clampi(active.hp, 1, active.max_hp)
		active.valence_electrons = clampi(active.valence_electrons, 0, active.max_valence_electrons)

	var energy := COMPOUND_RELEASE_FALLBACK_ENERGY
	if active != null and active.valence_electrons > 0:
		energy = active.valence_electrons

	for c in group:
		var was_inactive := c.is_bond_inactive
		c.bond_kind = NONE
		c.bond_partner_id = -1
		c.is_bond_cation = false
		c.is_bond_inactive = false
		if c == active or not was_inactive or not c.alive:
			continue
		c.hp = clampi(int(floor(c.max_hp * COMPOUND_RELEASE_HP_RATIO)), 1, c.max_hp)
		c.max_valence_electrons = maxi(c.max_valence_electrons, energy)
		c.valence_electrons = energy
	return true


# ---------------------------------------------------------------------------
# Térmica do Composto
# ---------------------------------------------------------------------------

## Calcula e devolve as propriedades térmicas do vínculo recém-formado.
## Massa = soma das massas. Calor específico e limite de surto vêm do tipo de
## ligação. Fusão/ebulição = média ponderada pela massa (o Composto não herda de
## um só participante). Cisão: fórmula iônica ou covalente do GDD.
static func build_compound_thermal(participants: Array[CombatantState], sheets: Array[AlchemonSheet], active: CombatantState, start_temperature: float) -> CompoundThermal:
	var th := CompoundThermal.new()
	th.active_id = active.id
	for c in participants:
		th.member_ids.append(c.id)

	var metals: Array[AlchemonSheet] = []
	var nonmetals: Array[AlchemonSheet] = []
	var mass := 0.0
	var melt_weighted := 0.0
	var boil_weighted := 0.0
	for sh in sheets:
		var m := float(sh.atomic_mass)
		mass += m
		melt_weighted += m * sh.melting_point
		boil_weighted += m * sh.boiling_point
		if sh.is_metal():
			metals.append(sh)
		else:
			nonmetals.append(sh)

	th.total_mass = maxf(mass, 0.0001)
	th.melting_point = melt_weighted / th.total_mass
	th.boiling_point = maxf(boil_weighted / th.total_mass, th.melting_point)

	# Tipo da ligação: o que CompoundRules realmente formou; sem isso, metal+ametal = iônico.
	var data := CompoundRules.resolve(sheets)
	th.is_ionic = data.is_ionic() if data != null else (not metals.is_empty() and not nonmetals.is_empty())

	if th.is_ionic and not metals.is_empty() and not nonmetals.is_empty():
		th.specific_heat = ThermalRules.COMPOUND_CP_IONIC
		th.max_delta_t = ThermalRules.COMPOUND_MAX_DELTA_T_IONIC
		var anion_boil := 0.0
		var anion_en := INF
		for n in nonmetals:
			anion_boil = maxf(anion_boil, n.boiling_point)
			anion_en = minf(anion_en, n.chem_electronegativity())
		var cation_en := 0.0
		var charge := 0
		for mt in metals:
			cation_en = maxf(cation_en, mt.chem_electronegativity())
			charge = maxi(charge, _cation_charge(mt))
		th.scission_temperature = AlchemonFormulas.scission_temperature_ionic(anion_boil, anion_en - cation_en, charge)
	else:
		th.is_ionic = false
		th.specific_heat = ThermalRules.COMPOUND_CP_COVALENT
		th.max_delta_t = ThermalRules.COMPOUND_MAX_DELTA_T_COVALENT
		var boil_max := 0.0
		for sh in sheets:
			boil_max = maxf(boil_max, sh.boiling_point)
		th.scission_temperature = AlchemonFormulas.scission_temperature_covalent(boil_max, boil_max, _shared_pairs(data))

	th.reset_temperature(start_temperature)
	return th


## Carga do cátion = primeiro estado de oxidação positivo (o preferido).
static func _cation_charge(metal: AlchemonSheet) -> int:
	for q in metal.chem_oxidation_states():
		if q > 0:
			return q
	return maxi(metal.chem_valence(), 1)


## Pares compartilhados da ligação efetivamente formada (maior ordem de ligação).
static func _shared_pairs(data: CompoundData) -> int:
	var best := 1
	if data != null:
		for b in data.bonds:
			best = maxi(best, int(b.get("order", 1)))
	return best


## Cisão por temperatura. Ordem: registra a temperatura, desfaz o vínculo (e a
## transferência de atributos), devolve slots, marca choque (uma vez por
## Alchemon) e inicia a Sobrecarga. Cada sobrevivente herda a temperatura interna
## do Composto e volta à própria massa/calor específico. O dano do choque é
## aplicado por quem chama, nos ids de "shocked_ids".
## Devolve {} se `member` não está num Composto com dados térmicos.
static func thermal_scission(state: CombatState, database: AlchemonDatabase, member: CombatantState) -> Dictionary:
	var th := state.get_compound_thermal(member)
	if th == null:
		return {}
	var temperature := th.temperature
	var active_id := member.bond_partner_id
	var group_ids: Array[int] = []
	for id in state.combatants:
		var c: CombatantState = state.combatants[id]
		if c.bond_kind == COMPOUND and c.bond_partner_id == active_id:
			group_ids.append(id)
	if not break_compound(state, member):
		return {}

	var survivors: Array[CombatantState] = []
	var shocked_ids: Array[int] = []
	for id in group_ids:
		var c := state.get_combatant(id)
		if c == null or not c.alive:
			continue
		survivors.append(c)
		c.temperature = temperature
		var sheet := database.get_by_id(c.species_id)
		if sheet != null:
			c.physical_state = sheet.state_at(temperature)
			c.previous_physical_state = c.physical_state
		if not c.has_thermal_shock:
			c.has_thermal_shock = true
			shocked_ids.append(id)
	_restore_slots(state, survivors)
	for c in survivors:
		c.thermal_overload_turns = ThermalRules.OVERLOAD_TURNS
		c.thermal_overload_fresh = true
	return {"member_ids": group_ids, "shocked_ids": shocked_ids, "temperature": temperature}


## Quem ficou sem slot (inativo do Composto) volta para um slot livre do seu lado.
static func _restore_slots(state: CombatState, members: Array[CombatantState]) -> void:
	for c in members:
		if c.slot >= 0:
			continue
		for s in BattlefieldSlot.get_side_slots(c.is_player):
			if state.battlefield.is_available(s):
				state.battlefield.assign_combatant(c.id, s)
				c.slot = s
				break
