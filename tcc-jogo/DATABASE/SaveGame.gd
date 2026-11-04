class_name SaveGame
extends RefCounted


const FORMAT_VERSION := 1


static func serialize(party: PlayerPartyData, storage: CapturedStorage, bond: PlayerBondData, player: PlayerData, defeated: Dictionary = {}, inventory: InventoryData = null, position: Dictionary = {}) -> Dictionary:
	var party_list: Array = []
	for inst in party.party:
		if inst != null:
			party_list.append(inst.to_dict())
	var storage_list: Array = []
	for inst in storage.instances:
		if inst != null:
			storage_list.append(inst.to_dict())

	var bond_uids: Array = []
	if bond.is_active():
		for i in bond.member_indices:
			if i >= 0 and i < party.party.size() and party.party[i] != null:
				bond_uids.append(party.party[i].uid)

	var earned: Array = []
	for b in player.badges:
		earned.append(b != null and b.earned)

	return {
		"format_version": FORMAT_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"party": party_list,
		"storage": storage_list,
		"bond": {"kind": bond.kind, "member_uids": bond_uids},
		"defeated_npcs": defeated.keys(),
		"inventory": inventory.items.duplicate() if inventory != null else [],
		"position": position.duplicate(),
		"player": {
			"name": player.player_name,
			"team_name": player.team_name,
			"money": player.money,
			"play_time": player.get_play_time(),
			"badges_earned": earned,
		},
	}


static func apply(data: Dictionary, party: PlayerPartyData, storage: CapturedStorage, bond: PlayerBondData, player: PlayerData, defeated: Dictionary = {}, inventory: InventoryData = null, position: Dictionary = {}) -> Error:
	data = _migrate(data)
	var version := int(data.get("format_version", 0))
	if version < 1 or version > FORMAT_VERSION:
		push_warning("SaveGame: unsupported format_version %d (this build reads 1..%d)." % [version, FORMAT_VERSION])
		return ERR_FILE_UNRECOGNIZED
	if not (data.get("party") is Array) or not (data.get("storage") is Array):
		return ERR_INVALID_DATA

	var new_defeated := {}
	var raw_defeated = data.get("defeated_npcs", [])
	if raw_defeated is Array:
		for id in raw_defeated:
			if id is String and id != "":
				new_defeated[id] = true

	var new_items: Array[int] = []
	var has_items: bool = data.get("inventory") is Array
	if has_items:
		for n in data["inventory"]:
			if n is float or n is int:
				new_items.append(int(n))

	var new_position := _read_position(data.get("position"))

	var seen := {}
	var new_party := _load_list(data["party"], seen)
	var new_storage := _load_list(data["storage"], seen)

	defeated.clear()
	defeated.merge(new_defeated)
	position.clear()
	position.merge(new_position)
	if inventory != null and has_items:
		inventory.items.clear()
		inventory.items.append_array(new_items)
		inventory.emit_changed()
	party.party.clear()
	party.party.append_array(new_party)
	storage.instances.clear()
	storage.instances.append_array(new_storage)

	var b: Dictionary = data.get("bond", {}) if data.get("bond") is Dictionary else {}
	var indices: Array[int] = []
	var ok := str(b.get("kind", BondRules.NONE)) != BondRules.NONE
	for uid in b.get("member_uids", []):
		var idx := _index_of_uid(new_party, str(uid))
		if idx == -1:
			ok = false
			break
		indices.append(idx)
	if ok and indices.size() >= 2:
		bond.set_bond(str(b["kind"]), indices)
	else:
		bond.clear()

	if data.get("player") is Dictionary:
		var p: Dictionary = data["player"]
		player.player_name = str(p.get("name", player.player_name))
		player.team_name = str(p.get("team_name", ""))
		player.money = maxi(int(p.get("money", 0)), 0)
		player.play_time_seconds = float(p.get("play_time", 0.0)) - Time.get_ticks_msec() / 1000.0
		var earned = p.get("badges_earned", [])
		if earned is Array:
			for i in mini(earned.size(), player.badges.size()):
				if player.badges[i] != null:
					player.badges[i].earned = bool(earned[i])

	party.emit_changed()
	storage.emit_changed()
	return OK


static func _load_list(raw: Array, seen: Dictionary) -> Array[AlchemonInstance]:
	var out: Array[AlchemonInstance] = []
	for entry in raw:
		if not (entry is Dictionary):
			continue
		var inst := AlchemonInstance.from_dict(entry)
		if inst == null:
			continue
		inst.ensure_uid()
		while seen.has(inst.uid):
			inst.uid = CreatureFactory.new_uid()
		seen[inst.uid] = true
		out.append(inst)
	return out


static func _index_of_uid(list: Array[AlchemonInstance], uid: String) -> int:
	for i in list.size():
		if list[i].uid == uid:
			return i
	return -1


static func _migrate(data: Dictionary) -> Dictionary:
	return data


static func write_file(path: String, data: Dictionary) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if err != OK:
		return err
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	err = DirAccess.rename_absolute(tmp, path)
	if err != OK and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		err = DirAccess.rename_absolute(tmp, path)
	return err


static func read_file(path: String) -> Dictionary:
	for p in [path, path + ".bak"]:
		if not FileAccess.file_exists(p):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
		if parsed is Dictionary:
			if p != path:
				push_warning("SaveGame: %s unreadable, recovered from backup." % path)
			return parsed
	return {}


static func _read_position(raw) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var level = raw.get("level")
	if not (level is String) or level == "":
		return {}
	var out := {"level": level}
	for k in ["x", "y", "z", "yaw"]:
		var v = raw.get(k, 0.0)
		if not (v is float or v is int) or not is_finite(float(v)):
			return {}
		out[k] = float(v)
	return out
