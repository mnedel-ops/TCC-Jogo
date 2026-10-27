extends GdUnitTestSuite

const DB_PATH := "res://DATABASE/Alchemons/AlchemonDataBaseComplete.tres"
const TMP_SAVE := "user://test_saves/slot.json"

var db: AlchemonDatabase


func before_test() -> void:
	db = load(DB_PATH)


func after_test() -> void:
	for p in [TMP_SAVE, TMP_SAVE + ".bak", TMP_SAVE + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _species() -> int:
	return db.alchemons[0].id


func _inst(species_id: int = -99, level: int = 5) -> AlchemonInstance:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return CreatureFactory.create(species_id if species_id != -99 else _species(), level, rng)


# ---------------------------------------------------------------- identity

func test_uid_is_unique_and_set() -> void:
	var a := _inst()
	var b := _inst()
	assert_str(a.uid).is_not_empty()
	assert_str(a.uid).is_not_equal(b.uid)


func test_ensure_uid_keeps_existing() -> void:
	var a := _inst()
	var before := a.uid
	a.ensure_uid()
	assert_str(a.uid).is_equal(before)


# ---------------------------------------------------------------- serialization

func test_dict_roundtrip_through_real_json() -> void:
	var a := _inst()
	a.creature_name = "Fofo"
	a.experience = 42
	a.current_hp = 11
	a.current_energy = 3
	a.attack_ids = [0, 2]
	a.personality = "bold"
	var text := JSON.stringify(a.to_dict())
	var b := AlchemonInstance.from_dict(JSON.parse_string(text))
	assert_str(b.uid).is_equal(a.uid)
	assert_int(b.species_id).is_equal(a.species_id)
	assert_str(b.creature_name).is_equal("Fofo")
	assert_int(b.level).is_equal(a.level)
	assert_int(b.experience).is_equal(42)
	assert_int(b.individual_value).is_equal(a.individual_value)
	assert_str(b.personality).is_equal("bold")
	assert_int(b.current_hp).is_equal(11)
	assert_int(b.current_energy).is_equal(3)
	assert_array(b.attack_ids).contains_exactly([0, 2])


func test_from_dict_sanitizes_bad_data() -> void:
	var b := AlchemonInstance.from_dict({
		"species_id": 1, "level": -5, "xp": -9, "iv": -3,
		"personality": "nonsense", "hp": -50,
		"attacks": [1, 2, 3, 4, 5, 6],
	})
	assert_int(b.level).is_equal(1)
	assert_int(b.experience).is_equal(0)
	assert_int(b.individual_value).is_equal(0)
	assert_str(b.personality).is_equal(AlchemonPersonality.NEUTRAL)
	assert_int(b.current_hp).is_equal(AlchemonInstance.UNSET)
	assert_int(b.attack_ids.size()).is_equal(AlchemonInstance.MAX_ATTACKS)


func test_from_dict_without_species_is_rejected() -> void:
	assert_object(AlchemonInstance.from_dict({"level": 3})).is_null()


# ---------------------------------------------------------------- derived stats

func test_stats_are_derived_not_stored() -> void:
	var a := _inst()
	assert_that(a.get("defense")).is_null()        # no stored derived stat can leak
	assert_that(a.get("max_hp")).is_null()


func test_neutral_stats_match_formulas() -> void:
	var sheet: AlchemonSheet = db.get_by_id(_species())
	var a := _inst()
	a.personality = AlchemonPersonality.NEUTRAL
	var s := a.compute_stats(sheet)
	assert_int(s.attack).is_equal(AlchemonFormulas.compute_stat(sheet.base_attack, a.individual_value, a.level))
	assert_int(s.max_hp).is_equal(AlchemonFormulas.compute_max_hp(sheet.max_hp, a.individual_value, a.level))


func test_personality_changes_only_its_two_stats() -> void:
	var sheet: AlchemonSheet = db.get_by_id(_species())
	var a := _inst(-99, 50)
	a.personality = AlchemonPersonality.NEUTRAL
	var base := a.compute_stats(sheet)
	a.personality = "bold"   # up attack, down defense
	var s := a.compute_stats(sheet)
	assert_int(s.attack).is_greater(base.attack)
	assert_int(s.defense).is_less(base.defense)
	assert_int(s.mechanical_speed).is_equal(base.mechanical_speed)
	assert_int(s.max_hp).is_equal(base.max_hp)


func test_hp_unset_means_full_and_zero_means_fainted() -> void:
	var a := _inst()
	assert_int(a.hp_or_full(30)).is_equal(30)
	a.current_hp = 0
	assert_bool(a.is_fainted()).is_true()
	assert_int(a.hp_or_full(30)).is_equal(0)
	a.current_hp = 99
	assert_int(a.hp_or_full(30)).is_equal(30)


# ---------------------------------------------------------------- battle boundary

func _build(party: Array[AlchemonInstance], enemy_ids: Array[int] = []) -> CombatState:
	var enemies: Array[int] = []
	if enemy_ids.is_empty():
		enemies.append(_species())
	else:
		enemies.append_array(enemy_ids)
	return CombatStateFactory.build(db, party, enemies, 3)


func test_combatant_is_linked_to_its_creature() -> void:
	var a := _inst()
	var state := _build([a])
	var c := state.get_combatant(state.player_ids[0])
	assert_str(c.source_uid).is_equal(a.uid)
	assert_int(c.level).is_equal(a.level)
	assert_int(c.individual_value).is_equal(a.individual_value)


func test_battle_hp_is_written_back() -> void:
	var a := _inst()
	var state := _build([a])
	state.get_combatant(state.player_ids[0]).hp = 4
	CreatureSync.apply_battle([a], state, db)
	assert_int(a.current_hp).is_equal(4)


func test_xp_and_level_are_written_back() -> void:
	var a := _inst(-99, 5)
	var state := _build([a])
	var sheet: AlchemonSheet = db.get_by_id(_species())
	AlchemonGrowth.grant_experience(state.get_combatant(state.player_ids[0]), sheet, 250)
	CreatureSync.apply_battle([a], state, db)
	assert_int(a.level).is_equal(7)
	assert_int(a.experience).is_equal(50)


func test_bond_bonus_does_not_leak_into_creature() -> void:
	# Old code copied post-bond HP/stats into the instance permanently.
	var a := _inst()
	var b := _inst()
	var state := _build([a, b])
	var ca := state.get_combatant(state.player_ids[0])
	var cb := state.get_combatant(state.player_ids[1])
	BondRules._apply_mixture(ca, cb)   # +8 max HP, +8 HP on both
	var sheet: AlchemonSheet = db.get_by_id(_species())
	assert_int(ca.hp).is_greater(a.max_hp_for(sheet))
	CreatureSync.apply_battle([a, b], state, db)
	assert_int(a.current_hp).is_less_equal(a.max_hp_for(sheet))
	assert_int(b.current_hp).is_less_equal(b.max_hp_for(sheet))


func test_results_match_by_uid_not_by_position() -> void:
	# Old code matched party[i] <-> player_ids[i]; an unusable member in the
	# middle shifted every result onto the wrong creature.
	var ghost := _inst(987654)     # species that does not exist -> skipped by the factory
	var real := _inst()
	var state := _build([ghost, real])
	assert_int(state.player_ids.size()).is_equal(1)
	state.get_combatant(state.player_ids[0]).hp = 3
	ghost.current_hp = 25
	CreatureSync.apply_battle([ghost, real], state, db)
	assert_int(real.current_hp).is_equal(3)
	assert_int(ghost.current_hp).is_equal(25)


func test_fainted_policy_today_revives_at_battle_start() -> void:
	var a := _inst()
	a.current_hp = 0
	var state := _build([a])
	var c := state.get_combatant(state.player_ids[0])
	if CreatureSync.REVIVE_FAINTED_ON_BATTLE_START:
		assert_int(c.hp).is_equal(c.max_hp)
	else:
		assert_int(state.player_ids.size()).is_equal(0)


func test_capture_keeps_the_individual_that_was_fought() -> void:
	var state := _build([_inst()])
	var enemy_id := state.enemy_ids[0]
	var fought: AlchemonInstance = state.enemy_instances[enemy_id]
	state.get_combatant(enemy_id).hp = 5
	var r := CombatResult.capture_success(state.player_ids[0], enemy_id)
	CombatResultApplier.apply(state, r, db)
	assert_int(state.captured_instances.size()).is_equal(1)
	var got := state.captured_instances[0]
	assert_str(got.uid).is_equal(fought.uid)
	assert_int(got.individual_value).is_equal(fought.individual_value)
	assert_str(got.personality).is_equal(fought.personality)
	assert_int(got.current_hp).is_equal(5)


func test_capture_never_stores_a_fainted_creature() -> void:
	var state := _build([_inst()])
	var enemy_id := state.enemy_ids[0]
	state.get_combatant(enemy_id).hp = 1
	CombatResultApplier.apply(state, CombatResult.capture_success(state.player_ids[0], enemy_id), db)
	assert_int(state.captured_instances[0].current_hp).is_greater_equal(1)


# ---------------------------------------------------------------- save layer

func _world(n_party: int = 2, n_store: int = 2) -> Dictionary:
	var party := PlayerPartyData.new()
	var storage := CapturedStorage.new()
	for i in n_party:
		party.party.append(_inst())
	for i in n_store:
		storage.instances.append(_inst())
	return {"party": party, "storage": storage, "bond": PlayerBondData.new(), "player": PlayerData.new()}


func _apply(data: Dictionary, w: Dictionary) -> Error:
	return SaveGame.apply(data, w.party, w.storage, w.bond, w.player)


func test_save_roundtrip_via_disk() -> void:
	var w := _world()
	w.party.party[0].creature_name = "Primeiro"
	w.party.party[1].current_hp = 2
	w.player.money = 321
	var pair: Array[int] = [0, 1]
	w.bond.set_bond(BondRules.MIXTURE, pair)
	var data := SaveGame.serialize(w.party, w.storage, w.bond, w.player)
	assert_int(SaveGame.write_file(TMP_SAVE, data)).is_equal(OK)

	var w2 := _world(0, 0)
	assert_int(_apply(SaveGame.read_file(TMP_SAVE), w2)).is_equal(OK)
	assert_int(w2.party.party.size()).is_equal(2)
	assert_int(w2.storage.instances.size()).is_equal(2)
	assert_str(w2.party.party[0].uid).is_equal(w.party.party[0].uid)
	assert_str(w2.party.party[0].creature_name).is_equal("Primeiro")
	assert_int(w2.party.party[1].current_hp).is_equal(2)
	assert_int(w2.player.money).is_equal(321)
	assert_str(w2.bond.kind).is_equal(BondRules.MIXTURE)
	assert_array(w2.bond.member_indices).contains_exactly([0, 1])


func test_bond_is_saved_by_uid_so_reordering_is_safe() -> void:
	var w := _world(3, 0)
	var pair: Array[int] = [1, 2]
	w.bond.set_bond(BondRules.MIXTURE, pair)
	var data := SaveGame.serialize(w.party, w.storage, w.bond, w.player)
	# swap party order inside the file
	var p: Array = data["party"]
	var first = p[0]
	p[0] = p[2]
	p[2] = first
	var w2 := _world(0, 0)
	_apply(data, w2)
	# creatures that were at 1 and 2 are now at 1 and 0
	assert_array(w2.bond.member_indices).contains_exactly([1, 0])


func test_unknown_future_version_is_refused_and_changes_nothing() -> void:
	var w := _world(1, 0)
	var keep: String = w.party.party[0].uid
	var err := _apply({"format_version": 999, "party": [], "storage": []}, w)
	assert_int(err).is_not_equal(OK)
	assert_str(w.party.party[0].uid).is_equal(keep)


func test_malformed_save_changes_nothing() -> void:
	var w := _world(1, 0)
	var err := _apply({"format_version": 1, "party": "oops"}, w)
	assert_int(err).is_not_equal(OK)
	assert_int(w.party.party.size()).is_equal(1)


func test_duplicate_uids_get_repaired_on_load() -> void:
	var d := _inst().to_dict()
	var data := {"format_version": 1, "party": [d, d.duplicate()], "storage": []}
	var w := _world(0, 0)
	assert_int(_apply(data, w)).is_equal(OK)
	assert_str(w.party.party[0].uid).is_not_equal(w.party.party[1].uid)


func test_corrupt_main_file_recovers_from_backup() -> void:
	var w := _world(1, 0)
	var data := SaveGame.serialize(w.party, w.storage, w.bond, w.player)
	SaveGame.write_file(TMP_SAVE, data)
	SaveGame.write_file(TMP_SAVE, data)   # second write creates the .bak
	var f := FileAccess.open(TMP_SAVE, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	var got := SaveGame.read_file(TMP_SAVE)
	assert_int(int(got.get("format_version", 0))).is_equal(1)
	assert_int((got["party"] as Array).size()).is_equal(1)


func test_missing_file_reads_as_empty() -> void:
	assert_bool(SaveGame.read_file("user://does_not_exist.json").is_empty()).is_true()


func test_full_loop_fight_capture_save_reload() -> void:
	var w := _world(1, 0)
	var mine: AlchemonInstance = w.party.party[0]
	var state := _build([mine])
	var enemy_id := state.enemy_ids[0]
	var fought: AlchemonInstance = state.enemy_instances[enemy_id]
	state.get_combatant(state.player_ids[0]).hp = 6
	CombatResultApplier.apply(state, CombatResult.capture_success(state.player_ids[0], enemy_id), db)
	# what the controller does at the end of a battle:
	for got in state.captured_instances:
		w.storage.add_instance(got)
	CreatureSync.apply_battle(w.party.party, state, db)

	SaveGame.write_file(TMP_SAVE, SaveGame.serialize(w.party, w.storage, w.bond, w.player))
	var w2 := _world(0, 0)
	assert_int(_apply(SaveGame.read_file(TMP_SAVE), w2)).is_equal(OK)

	# (capture XP may level the creature up and add HP, so compare with what it ended at)
	assert_int(mine.current_hp).is_greater_equal(6)
	assert_int(w2.party.party[0].current_hp).is_equal(mine.current_hp)
	assert_int(w2.party.party[0].level).is_equal(mine.level)
	assert_int(w2.storage.instances.size()).is_equal(1)
	var kept: AlchemonInstance = w2.storage.find_by_uid(fought.uid)
	assert_object(kept).is_not_null()
	assert_int(kept.individual_value).is_equal(fought.individual_value)
	assert_str(kept.personality).is_equal(fought.personality)


# ---------------------------------------------------------------- GameSession (real .tres + autoload wiring)

func _session(path: String) -> Node:
	var s: Node = load("res://autoload/game_session.gd").new()
	s.save_path = path
	s.load_on_start = false
	# Deep copies: the real autoload shares the originals and would hear their signals / autosave.
	s.party = s.party.duplicate(true)
	s.storage = s.storage.duplicate(true)
	s.bond = s.bond.duplicate(true)
	s.player = s.player.duplicate(true)
	s.inventory = s.inventory.duplicate(true)
	add_child(s)
	return auto_free(s)


func test_session_gives_starters_uids_and_saves_and_loads() -> void:
	var s := _session(TMP_SAVE)
	assert_int(s.party.party.size()).is_greater(0)
	for inst in s.party.party:
		assert_str(inst.uid).is_not_empty()     # hand-authored .tres starters got identities
	var uid: String = s.party.party[0].uid
	var lvl: int = s.party.party[0].level
	s.party.party[0].level = 9
	assert_int(s.save_game()).is_equal(OK)
	s.party.party[0].level = lvl                 # "forget" the progress
	assert_int(s.load_game(false)).is_equal(OK)   # false: the real autoload must not hear party_changed and autosave
	assert_int(s.party.party[0].level).is_equal(9)
	assert_str(s.party.party[0].uid).is_equal(uid)


# ---------------------------------------------------------------- defeated NPCs / new game

func test_defeated_npcs_roundtrip_via_disk() -> void:
	var w := _world()
	var defeated := {"scene_1/SpawnPoint": true, "scene_2/SpawnPoint3": true}
	assert_int(SaveGame.write_file(TMP_SAVE, SaveGame.serialize(w.party, w.storage, w.bond, w.player, defeated))).is_equal(OK)

	var w2 := _world(0, 0)
	var loaded := {"stale/Npc": true}   # must be replaced, not merged
	assert_int(SaveGame.apply(SaveGame.read_file(TMP_SAVE), w2.party, w2.storage, w2.bond, w2.player, loaded)).is_equal(OK)
	assert_int(loaded.size()).is_equal(2)
	assert_bool(loaded.has("scene_1/SpawnPoint")).is_true()
	assert_bool(loaded.has("stale/Npc")).is_false()


func test_old_save_without_defeated_key_loads_empty() -> void:
	var w := _world()
	var data := SaveGame.serialize(w.party, w.storage, w.bond, w.player)
	data.erase("defeated_npcs")
	var loaded := {"x/y": true}
	assert_int(SaveGame.apply(data, w.party, w.storage, w.bond, w.player, loaded)).is_equal(OK)
	assert_bool(loaded.is_empty()).is_true()


func test_session_new_game_resets_progress() -> void:
	var s := _session(TMP_SAVE)
	var starter_money: int = s.player.money
	var starter_party: int = s.party.party.size()
	s.player.money = 9999
	s.party.party.clear()
	s.mark_npc_defeated("scene_1/SpawnPoint")
	assert_bool(s.is_npc_defeated("scene_1/SpawnPoint")).is_true()
	assert_int(s.new_game()).is_equal(OK)
	assert_int(s.player.money).is_equal(starter_money)
	assert_int(s.party.party.size()).is_equal(starter_party)
	assert_bool(s.is_npc_defeated("scene_1/SpawnPoint")).is_false()
	assert_float(s.player.get_play_time()).is_less(5.0)


func test_session_defeated_survives_save_load() -> void:
	var s := _session(TMP_SAVE)
	s.mark_npc_defeated("scene_1/SpawnPoint")
	assert_int(s.save_game()).is_equal(OK)
	s.defeated_npcs.clear()
	assert_int(s.load_game(false)).is_equal(OK)
	assert_bool(s.is_npc_defeated("scene_1/SpawnPoint")).is_true()


func test_inventory_roundtrip_via_disk() -> void:
	var w := _world()
	var bag := InventoryData.new()
	bag.items = [3, 3, 5]
	assert_int(SaveGame.write_file(TMP_SAVE, SaveGame.serialize(w.party, w.storage, w.bond, w.player, {}, bag))).is_equal(OK)

	var bag2 := InventoryData.new()
	bag2.items = [9]   # must be replaced
	assert_int(SaveGame.apply(SaveGame.read_file(TMP_SAVE), w.party, w.storage, w.bond, w.player, {}, bag2)).is_equal(OK)
	assert_array(bag2.items).is_equal([3, 3, 5])
	assert_int(bag2.get_quantity(3)).is_equal(2)


func test_old_save_without_inventory_keeps_bag() -> void:
	var w := _world()
	var data := SaveGame.serialize(w.party, w.storage, w.bond, w.player)
	data.erase("inventory")
	var bag := InventoryData.new()
	bag.items = [4]
	assert_int(SaveGame.apply(data, w.party, w.storage, w.bond, w.player, {}, bag)).is_equal(OK)
	assert_array(bag.items).is_equal([4])


func test_session_inventory_saved_and_new_game_resets() -> void:
	var s := _session(TMP_SAVE)
	var starter: Array = s.inventory.items.duplicate()
	s.inventory.add_item(7)
	assert_int(s.save_game()).is_equal(OK)
	s.inventory.items.clear()
	assert_int(s.load_game(false)).is_equal(OK)
	assert_bool(s.inventory.items.has(7)).is_true()
	assert_int(s.new_game()).is_equal(OK)
	assert_array(s.inventory.items).is_equal(starter)


func test_no_file_until_player_saves_and_save_replaces() -> void:
	DirAccess.remove_absolute(TMP_SAVE)
	var s := _session(TMP_SAVE)
	s.mark_npc_defeated("scene_1/SpawnPoint")
	s.inventory.add_item(7)
	s.party.changed.emit()
	assert_bool(FileAccess.file_exists(TMP_SAVE)).is_false()   # autosave is off

	assert_int(s.save_game()).is_equal(OK)                      # Save button
	s.player.money += 50
	assert_int(s.save_game()).is_equal(OK)                      # save again = same file, new content
	var data := SaveGame.read_file(TMP_SAVE)
	assert_int(int(data["player"]["money"])).is_equal(s.player.money)


func test_position_roundtrip_and_resume_once() -> void:
	var s := _session(TMP_SAVE)
	s.world_position = {"level": "res://scenes/scene_2.tscn", "x": 1.5, "y": 0.25, "z": -7.0, "yaw": 1.2}
	assert_int(s.save_game()).is_equal(OK)    # no scene manager in the test tree: keeps the dict
	s.world_position = {}
	assert_int(s.load_game(false)).is_equal(OK)
	assert_str(s.world_position["level"]).is_equal("res://scenes/scene_2.tscn")
	assert_float(s.world_position["x"]).is_equal(1.5)
	assert_float(s.world_position["yaw"]).is_equal_approx(1.2, 0.0001)
	assert_bool(s.take_resume_position().is_empty()).is_false()
	assert_bool(s.take_resume_position().is_empty()).is_true()   # consumed: a door/reload must not teleport again


func test_new_game_forgets_position() -> void:
	var s := _session(TMP_SAVE)
	s.world_position = {"level": "res://scenes/scene_2.tscn", "x": 1.0, "y": 0.0, "z": 1.0, "yaw": 0.0}
	assert_int(s.new_game()).is_equal(OK)
	assert_bool(s.world_position.is_empty()).is_true()
	assert_bool(s.take_resume_position().is_empty()).is_true()


func test_bad_or_missing_position_loads_as_empty() -> void:
	var w := _world()
	for bad in [null, 5, {}, {"level": ""}, {"level": "res://a.tscn", "x": "no", "y": 0, "z": 0}]:
		var data := SaveGame.serialize(w.party, w.storage, w.bond, w.player)
		data["position"] = bad
		var pos := {"level": "stale"}
		assert_int(SaveGame.apply(data, w.party, w.storage, w.bond, w.player, {}, null, pos)).is_equal(OK)
		assert_bool(pos.is_empty()).is_true()
	var old := SaveGame.serialize(w.party, w.storage, w.bond, w.player)
	old.erase("position")
	var pos2 := {"level": "stale"}
	assert_int(SaveGame.apply(old, w.party, w.storage, w.bond, w.player, {}, null, pos2)).is_equal(OK)
	assert_bool(pos2.is_empty()).is_true()
