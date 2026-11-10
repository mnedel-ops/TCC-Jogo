class_name SaveGame
extends RefCounted


const FORMAT_VERSION := 1


static func serialize(party: PlayerPartyData, storage: CapturedStorage, bond: PlayerBondData, player: PlayerData, defeated: Dictionary = {}, inventory: InventoryData = null, position: Dictionary = {}) -> Dictionary:
	_ensure_unique_uids(party.party, storage.instances)

	var party_list: Array = []
	for inst in party.party:
		if inst != null:
			party_list.append(inst.to_dict())
	var storage_list: Array = []
	for inst in storage.instances:
		if inst != null:
			storage_list.append(inst.to_dict())

	# Composto: quem participa é gravado pelo uid (seguro contra reordenação) e
	# também pela posição na party (reserva, p/ saves antigos sem uid).
	var bond_uids: Array = []
	var bond_indices: Array = []
	if bond.is_active():
		for i in bond.member_indices:
			if i >= 0 and i < party.party.size() and party.party[i] != null:
				bond_uids.append(party.party[i].uid)
				bond_indices.append(i)

	var earned: Array = []
	for b in player.badges:
		earned.append(b != null and b.earned)

	return {
		"format_version": FORMAT_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"party": party_list,
		"storage": storage_list,
		"bond": {"kind": bond.kind, "member_uids": bond_uids, "member_indices": bond_indices},
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
	var new_bond := _read_bond(data.get("bond"), new_party, new_storage)

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

	var indices: Array[int] = new_bond["indices"]
	if indices.size() >= 2:
		bond.set_bond(new_bond["kind"], indices)
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


# Garante que toda criatura da party/storage tem uid, e que ele é único.
static func _ensure_unique_uids(party_list: Array, storage_list: Array) -> void:
	var seen := {}
	for list in [party_list, storage_list]:
		for inst in list:
			if inst == null:
				continue
			inst.ensure_uid()
			while seen.has(inst.uid):
				inst.uid = CreatureFactory.new_uid()
			seen[inst.uid] = true


# Reconstrói o composto salvo. Devolve {"kind": String, "indices": Array[int]}
# (indices vazio = sem composto). Pode mover pra party um membro que esteja no storage.
static func _read_bond(raw, party_list: Array[AlchemonInstance], storage_list: Array[AlchemonInstance]) -> Dictionary:
	var none := {"kind": BondRules.NONE, "indices": [] as Array[int]}
	if not (raw is Dictionary):
		return none
	var kind := str(raw.get("kind", BondRules.NONE))
	var uids = raw.get("member_uids", [])
	if kind == BondRules.NONE or not (uids is Array) or uids.size() < 2:
		return none

	var indices: Array[int] = []
	var blank := false
	for uid in uids:
		var u := str(uid)
		if u == "":
			blank = true
			break
		var idx := _index_of_uid(party_list, u)
		if idx == -1:
			var si := _index_of_uid(storage_list, u)
			if si != -1:
				party_list.append(storage_list.pop_at(si))
				idx = party_list.size() - 1
		if idx == -1 or indices.has(idx):
			return none
		indices.append(idx)
	if not blank:
		return {"kind": kind, "indices": indices}

	# Save antigo: criaturas sem uid. Usa as posições gravadas; sem elas, o PC
	# sempre deixa na party só os membros do composto, então é a party inteira.
	var saved = raw.get("member_indices", [])
	var legacy: Array[int] = []
	if saved is Array and saved.size() == uids.size():
		for n in saved:
			if (n is int or n is float) and int(n) >= 0 and int(n) < party_list.size() and not legacy.has(int(n)):
				legacy.append(int(n))
	if legacy.size() != uids.size() and party_list.size() == uids.size():
		legacy.clear()
		for n in party_list.size():
			legacy.append(n)
	if legacy.size() != uids.size():
		return none
	return {"kind": kind, "indices": legacy}


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
