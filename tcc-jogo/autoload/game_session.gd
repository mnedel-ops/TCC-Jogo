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

@export var load_on_start := true
@export var autosave := true

var party: PlayerPartyData = load("res://DATABASE/Alchemons/PlayerCurrentAlchemon.tres")
var storage: CapturedStorage = load("res://DATABASE/Alchemons/captured_storage.tres")
var bond: PlayerBondData = load("res://DATABASE/Alchemons/player_bond.tres")
var player: PlayerData = load("res://DATABASE/Player/player.tres")

var _loading := false


func _ready() -> void:
	_give_uids()
	if load_on_start and has_save():
		load_game()
	CombatSignal.creatures_synced.connect(_autosave) # battle results already written to the creatures
	CombatSignal.party_changed.connect(_autosave)
	bond.changed.connect(_autosave)                 # PC makes/breaks a Component


func has_save() -> bool:
	return FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak")


func save_game() -> Error:
	var err := SaveGame.write_file(save_path, SaveGame.serialize(party, storage, bond, player))
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
	var err := SaveGame.apply(data, party, storage, bond, player)
	_loading = false
	if err != OK:
		push_error("GameSession: load failed (%s). Starting from default data." % error_string(err))
		return err
	if notify_scene:
		CombatSignal.party_changed.emit.call_deferred()   # followers respawn
	loaded.emit()
	return OK


func delete_save() -> void:
	for p in [save_path, save_path + ".bak", save_path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


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

