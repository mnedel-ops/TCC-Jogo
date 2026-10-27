extends Node

## Owns the player's persistent progress at runtime and wires it to the save file.
## Holds the SAME resource objects every scene already uses (they load the same
## .tres path, and Godot returns one shared instance), so loading a save here
## updates the whole game with no changes in the consumers.
##
## Dev tip: the first save makes later runs load it, so edits to the starter
## .tres will seem ignored. Use delete_save() or Project > Open User Data Folder.

signal saved
signal loaded

## Change BEFORE add_child (tests do) - _ready already loads from it.
var save_path := "user://saves/slot_1.json"

## false = the title menu (scenes/menu.tscn) decides: New Game / Load Game.
@export var load_on_start := false
## false = file is written ONLY by the Save button (GameMenu) or an explicit save_game().
@export var autosave := false

var party: PlayerPartyData = load("res://DATABASE/Alchemons/PlayerCurrentAlchemon.tres")
var storage: CapturedStorage = load("res://DATABASE/Alchemons/captured_storage.tres")
var bond: PlayerBondData = load("res://DATABASE/Alchemons/player_bond.tres")
var player: PlayerData = load("res://DATABASE/Player/player.tres")
var inventory: InventoryData = load("res://DATABASE/Inventory/inventory.tres")

## NPC ids (see Level.npc_id_for) the player already beat. Saved in the JSON.
## Dictionary used as a set: {id: true}. Never replace it, SaveGame fills it in place.
var defeated_npcs := {}

## Last saved spot: {level: scene path, x, y, z, yaw}. {} = never saved.
## Filled from the live scene on every save_game(), restored by load_game().
var world_position := {}

var _loading := false
var _resume := false          # true right after load_game(): SceneManager should start at world_position
var _starter_snapshot := {}   # starter .tres state, taken once, used by new_game()


func _ready() -> void:
	_give_uids()
	_starter_snapshot = SaveGame.serialize(party, storage, bond, player, {}, inventory)
	if load_on_start and has_save():
		load_game()
	CombatSignal.creatures_synced.connect(_autosave) # battle results already written to the creatures
	CombatSignal.party_changed.connect(_autosave)
	bond.changed.connect(_autosave)                 # PC makes/breaks a Component
	inventory.changed.connect(_on_inventory_changed)


func has_save() -> bool:
	return FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak")


func save_game() -> Error:
	var live := _capture_position()
	if not live.is_empty():
		world_position = live   # reassign is fine: only GameSession holds this dictionary
	var err := SaveGame.write_file(save_path, SaveGame.serialize(party, storage, bond, player, defeated_npcs, inventory, world_position))
	if err != OK:
		push_error("GameSession: save failed (%s)." % error_string(err))
	else:
		saved.emit()
	return err


## notify_scene = tell followers/UI the party changed. Off only in tests.
func load_game(notify_scene := true) -> Error:
	var data := SaveGame.read_file(save_path)
	if data.is_empty():
		return ERR_FILE_NOT_FOUND
	_loading = true   # apply() touches the bond -> its `changed` must not autosave
	var err := SaveGame.apply(data, party, storage, bond, player, defeated_npcs, inventory, world_position)
	_loading = false
	if err != OK:
		push_error("GameSession: load failed (%s). Starting from default data." % error_string(err))
		return err
	_resume = not world_position.is_empty()
	if notify_scene:
		CombatSignal.party_changed.emit.call_deferred()   # followers respawn
	loaded.emit()
	return OK


## Back to starter party / storage / coins / badges / no defeated NPCs.
## Does NOT touch the save file: the next Save press overwrites it.
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


## Once per load: where SceneManager must put the player. {} = normal start.
func take_resume_position() -> Dictionary:
	var pos := world_position.duplicate() if _resume else {}
	_resume = false
	return pos


func _capture_position() -> Dictionary:
	if not is_inside_tree():
		return {}
	var sm := get_tree().get_first_node_in_group("scene_manager")
	return sm.get_save_position() if sm != null and sm.has_method("get_save_position") else {}


func is_npc_defeated(id: String) -> bool:
	return defeated_npcs.has(id)


func mark_npc_defeated(id: String) -> void:
	if id == "" or defeated_npcs.has(id):
		return
	defeated_npcs[id] = true
	_autosave()


func delete_save() -> void:
	for p in [save_path, save_path + ".bak", save_path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## Item picked up / used. In battle skip: creatures_synced saves item + HP together at the end.
func _on_inventory_changed() -> void:
	if not CombatSignal.in_combat:
		_autosave()


func _autosave() -> void:
	if autosave and not _loading:
		save_game()


## Hand-authored starters in the .tres have no uid yet.
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

