extends Node


signal saved
signal loaded

var save_path := "user://saves/slot_1.json"

@export var load_on_start := false
@export var autosave := false

var party: PlayerPartyData = load("res://DATABASE/Alchemons/PlayerCurrentAlchemon.tres")
var storage: CapturedStorage = load("res://DATABASE/Alchemons/captured_storage.tres")
var bond: PlayerBondData = load("res://DATABASE/Alchemons/player_bond.tres")
var player: PlayerData = load("res://DATABASE/Player/player.tres")
var inventory: InventoryData = load("res://DATABASE/Inventory/inventory.tres")
var database: AlchemonDatabase = load("res://DATABASE/Alchemons/AlchemonDataBaseComplete.tres")

var defeated_npcs := {}

var world_position := {}

var _loading := false
var _resume := false
var _starter_snapshot := {}


func _ready() -> void:
	_give_uids()
	_starter_snapshot = SaveGame.serialize(party, storage, bond, player, {}, inventory)
	if load_on_start and has_save():
		load_game()
	CombatSignal.creatures_synced.connect(_autosave)
	CombatSignal.party_changed.connect(_autosave)
	bond.changed.connect(_autosave)
	inventory.changed.connect(_on_inventory_changed)


func has_save() -> bool:
	return FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak")


func save_game() -> Error:
	var live := _capture_position()
	if not live.is_empty():
		world_position = live
	var err := SaveGame.write_file(save_path, SaveGame.serialize(party, storage, bond, player, defeated_npcs, inventory, world_position))
	if err != OK:
		push_error("GameSession: save failed (%s)." % error_string(err))
	else:
		saved.emit()
	return err


func load_game(notify_scene := true) -> Error:
	var data := SaveGame.read_file(save_path)
	if data.is_empty():
		return ERR_FILE_NOT_FOUND
	_loading = true
	var err := SaveGame.apply(data, party, storage, bond, player, defeated_npcs, inventory, world_position)
	_loading = false
	if err != OK:
		push_error("GameSession: load failed (%s). Starting from default data." % error_string(err))
		return err
	_resume = not world_position.is_empty()
	if notify_scene:
		CombatSignal.party_changed.emit.call_deferred()
	loaded.emit()
	return OK


func new_game() -> Error:
	var data := _starter_snapshot.duplicate(true)
	data["player"]["play_time"] = 0.0
	data["defeated_npcs"] = []
	data["position"] = {}
	_loading = true
	var err := SaveGame.apply(data, party, storage, bond, player, defeated_npcs, inventory, world_position)
	_loading = false
	if err != OK:
		push_error("GameSession: new game failed (%s)." % error_string(err))
		return err
	_resume = false
	loaded.emit()
	return OK


func take_resume_position() -> Dictionary:
	var pos := world_position.duplicate() if _resume else {}
	_resume = false
	return pos


func _capture_position() -> Dictionary:
	if not is_inside_tree():
		return {}
	var sm := get_tree().get_first_node_in_group("scene_manager")
	return sm.get_save_position() if sm != null and sm.has_method("get_save_position") else {}


func can_fight() -> bool:
	for inst in party.party:
		if inst != null and not inst.is_fainted():
			return true
	return false


func heal_party() -> void:
	for inst in party.party:
		if inst == null:
			continue
		var sheet := database.get_by_id(inst.species_id)
		inst.current_hp = inst.max_hp_for(sheet) if sheet != null else AlchemonInstance.UNSET
		inst.current_energy = AlchemonInstance.UNSET
	_autosave()


func is_npc_defeated(id: String) -> bool:
	return defeated_npcs.has(id)


func mark_npc_defeated(id: String) -> void:
	if id == "" or defeated_npcs.has(id):
		return
	defeated_npcs[id] = true
	_autosave()


func _on_inventory_changed() -> void:
	if not CombatSignal.in_combat:
		_autosave()


func _autosave() -> void:
	if autosave and not _loading:
		save_game()


func _give_uids() -> void:
	var seen := {}
	for list in [party.party, storage.instances]:
		for inst in list:
			if inst == null:
				continue
			inst.ensure_uid()
			while seen.has(inst.uid):
				inst.uid = CreatureFactory.new_uid()
			seen[inst.uid] = true
