extends GdUnitTestSuite
## The player's Component only exists in combat if it was MADE at the PC
## (PlayerBondData active). Enemies still auto-bond.

const DB_PATH := "res://DATABASE/Alchemons/AlchemonDataBaseComplete.tres"

var db: AlchemonDatabase


func before_test() -> void:
	db = load(DB_PATH)


## Two player species that DO form a bond together (so "no bond" is not just
## "pair can't bond").
func _bondable_party(only_kind: String = "") -> Array[AlchemonInstance]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var party: Array[AlchemonInstance] = []
	for a in db.alchemons:
		for b in db.alchemons:
			var sheets: Array[AlchemonSheet] = [a, b]
			var kind := AlchemyStation.determine_bond_kind(sheets)
			if kind != BondRules.NONE and (only_kind == "" or kind == only_kind):
				party.append(CreatureFactory.create(a.id, 5, rng))
				party.append(CreatureFactory.create(b.id, 5, rng))
				return party
	return party


func _kinds(state: CombatState, ids: Array) -> Array:
	var out := []
	for id in ids:
		out.append(state.get_combatant(id).bond_kind)
	return out


func test_no_bond_made_means_no_player_bond() -> void:
	var party := _bondable_party()
	assert_int(party.size()).is_equal(2)
	var enemies: Array[int] = [db.alchemons[0].id]
	for bond in [null, PlayerBondData.new()]:
		var st := CombatStateFactory.build(db, party, enemies, 3, bond)
		assert_array(_kinds(st, st.player_ids)).contains_exactly([BondRules.NONE, BondRules.NONE])
		assert_array(st.get_active_ids(st.player_ids)).has_size(2)


func test_made_bond_is_applied_to_player() -> void:
	var party := _bondable_party()
	var sheets: Array[AlchemonSheet] = [db.get_by_id(party[0].species_id), db.get_by_id(party[1].species_id)]
	var bond := PlayerBondData.new()
	bond.set_bond(AlchemyStation.determine_bond_kind(sheets), [0, 1])
	var enemies: Array[int] = [db.alchemons[0].id]
	var st := CombatStateFactory.build(db, party, enemies, 3, bond)
	assert_str(st.get_combatant(st.player_ids[0]).bond_kind).is_equal(bond.kind)
	assert_str(st.get_combatant(st.player_ids[1]).bond_kind).is_equal(bond.kind)


func test_stale_bond_is_skipped() -> void:
	var party := _bondable_party()
	var bond := PlayerBondData.new()
	bond.set_bond(BondRules.NONE + "_wrong", [0, 1])   # kind that no pair can have
	var enemies: Array[int] = [db.alchemons[0].id]
	var st := CombatStateFactory.build(db, party, enemies, 3, bond)
	assert_array(_kinds(st, st.player_ids)).contains_exactly([BondRules.NONE, BondRules.NONE])


func test_compound_inactive_members_are_not_selectable_or_targetable() -> void:
	var party := _bondable_party(BondRules.COMPOUND)
	assert_int(party.size()).is_equal(2)
	var bond := PlayerBondData.new()
	bond.set_bond(BondRules.COMPOUND, [0, 1])
	var enemies: Array[int] = [db.alchemons[0].id]
	var st := CombatStateFactory.build(db, party, enemies, 3, bond)
	var active := st.get_active_ids(st.player_ids)
	assert_int(active.size()).is_equal(1)
	for id in st.player_ids:
		var c := st.get_combatant(id)
		assert_bool(active.has(id)).is_equal(not (c.is_bond_cation or c.is_bond_inactive))
