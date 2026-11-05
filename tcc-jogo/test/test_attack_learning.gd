extends GdUnitTestSuite


func _atk(id: int, lvl: int, power: int = 10) -> AttackData:
	var a := AttackData.new()
	a.indexAttack = id
	a.attack_name = "A%d" % id
	a.power = power
	a.unlock_level = lvl
	return a


func _sheet(list: Array) -> AlchemonSheet:
	var s := AlchemonSheet.new()
	for a in list:
		s.attacks.append(a)
	return s


func _combatant(is_player: bool = true) -> CombatantState:
	var c := CombatantState.new()
	c.level = 1
	c.individual_value = 1
	c.is_player = is_player
	return c


func test_pool_is_sorted_by_unlock_level() -> void:
	var s := _sheet([_atk(10, 8), _atk(11, 1), _atk(12, 4)])
	var ids: Array[int] = []
	for a in AttackLearning.pool_for(s):
		ids.append(a.indexAttack)
	assert_array(ids).contains_exactly([11, 12, 10])


func test_initial_attacks_respect_level_and_cap() -> void:
	var s := _sheet([_atk(10, 1), _atk(11, 3), _atk(12, 5), _atk(13, 7), _atk(14, 9), _atk(15, 11)])
	assert_array(AttackLearning.initial_attack_ids(s, 4)).contains_exactly([10, 11])
	assert_array(AttackLearning.initial_attack_ids(s, 20)).contains_exactly([12, 13, 14, 15])


func test_level_up_learns_new_attack_when_there_is_room() -> void:
	var s := _sheet([_atk(10, 1), _atk(11, 3)])
	var c := _combatant()
	c.attack_ids = [10]
	AlchemonGrowth.level_up(c, s, 1)
	assert_array(c.attack_ids).contains_exactly([10])
	AlchemonGrowth.level_up(c, s, 1)
	assert_array(c.attack_ids).contains_exactly([10, 11])
	assert_array(c.learned_attack_ids).contains_exactly([11])


func test_full_moveset_makes_player_attack_pending() -> void:
	var s := _sheet([_atk(10, 1), _atk(11, 1), _atk(12, 1), _atk(13, 1), _atk(14, 2)])
	var c := _combatant()
	c.attack_ids = [10, 11, 12, 13]
	AlchemonGrowth.level_up(c, s, 1)
	c.level = 1
	AlchemonGrowth.level_up(c, s, 1)
	assert_array(c.attack_ids).contains_exactly([10, 11, 12, 13])
	assert_array(c.pending_attack_ids).contains_exactly([14])


func test_resolve_pending_replaces_or_declines() -> void:
	var c := _combatant()
	c.attack_ids = [10, 11, 12, 13]
	c.pending_attack_ids = [14, 15]
	assert_bool(AttackLearning.resolve_pending(c, 14, 2)).is_true()
	assert_array(c.attack_ids).contains_exactly([10, 11, 14, 13])
	assert_bool(AttackLearning.resolve_pending(c, 15, -1)).is_true()
	assert_array(c.attack_ids).contains_exactly([10, 11, 14, 13])
	assert_array(c.pending_attack_ids).is_empty()
	assert_bool(AttackLearning.resolve_pending(c, 99, 0)).is_false()


func test_enemy_replaces_weakest_attack_automatically() -> void:
	var s := _sheet([_atk(10, 1, 5), _atk(11, 1, 30), _atk(12, 1, 20), _atk(13, 1, 25), _atk(14, 2, 40)])
	var c := _combatant(false)
	c.attack_ids = [10, 11, 12, 13]
	c.level = 1
	AlchemonGrowth.level_up(c, s, 1)
	assert_array(c.attack_ids).contains_exactly([14, 11, 12, 13])
	assert_array(c.pending_attack_ids).is_empty()


func test_sanitize_fills_empty_instance_and_drops_unknown_ids() -> void:
	var s := _sheet([_atk(10, 1), _atk(11, 5)])
	var inst := AlchemonInstance.new()
	inst.level = 2
	AttackLearning.sanitize_instance(inst, s)
	assert_array(inst.attack_ids).contains_exactly([10])
	inst.attack_ids = [10, 10, 777]
	AttackLearning.sanitize_instance(inst, s)
	assert_array(inst.attack_ids).contains_exactly([10])


func test_combat_uses_combatant_attack_list() -> void:
	var db := AlchemonDatabase.new()
	var s := _sheet([_atk(10, 1), _atk(11, 9)])
	s.id = 1
	db.alchemons.append(s)
	var inst := CreatureFactory.create(1, 1)
	var enemies: Array[int] = [1]
	var st := CombatStateFactory.build(db, [inst], enemies, 1)
	var c := st.get_combatant(st.player_ids[0])
	assert_array(c.attack_ids).contains_exactly([10])
	assert_array(inst.attack_ids).contains_exactly([10])
	assert_int(CombatRules.pick_random_attack_index(c)).is_equal(0)
