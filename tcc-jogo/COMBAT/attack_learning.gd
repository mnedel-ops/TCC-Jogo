class_name AttackLearning
extends RefCounted


static func pool_for(sheet: AlchemonSheet) -> Array[AttackData]:
	var out: Array[AttackData] = []
	if sheet == null:
		return out
	for a in sheet.attacks:
		if a == null or a in out:
			continue
		var pos := out.size()
		for i in out.size():
			if out[i].unlock_level > a.unlock_level:
				pos = i
				break
		out.insert(pos, a)
	return out


static func resolve(sheet: AlchemonSheet, attack_id: int) -> AttackData:
	var a := AttackDatabase.default().get_by_id(attack_id)
	if a != null:
		return a
	if sheet != null:
		for s in sheet.attacks:
			if s != null and s.indexAttack == attack_id:
				return s
	return null


static func unlocked_up_to(sheet: AlchemonSheet, level: int) -> Array[AttackData]:
	var out: Array[AttackData] = []
	for a in pool_for(sheet):
		if a.unlock_level <= level:
			out.append(a)
	return out


static func unlocked_at(sheet: AlchemonSheet, level: int) -> Array[AttackData]:
	var out: Array[AttackData] = []
	for a in pool_for(sheet):
		if a.unlock_level == level:
			out.append(a)
	return out


static func initial_attack_ids(sheet: AlchemonSheet, level: int) -> Array[int]:
	var unlocked := unlocked_up_to(sheet, level)
	var start := maxi(unlocked.size() - AlchemonInstance.MAX_ATTACKS, 0)
	var ids: Array[int] = []
	for i in range(start, unlocked.size()):
		ids.append(unlocked[i].indexAttack)
	return ids


static func sanitize_instance(instance: AlchemonInstance, sheet: AlchemonSheet) -> void:
	var clean: Array[int] = []
	for id in instance.attack_ids:
		if id in clean or resolve(sheet, id) == null:
			continue
		if clean.size() >= AlchemonInstance.MAX_ATTACKS:
			break
		clean.append(id)
	if clean.is_empty():
		clean = initial_attack_ids(sheet, instance.level)
	instance.attack_ids.assign(clean)


static func on_level_reached(c: CombatantState, sheet: AlchemonSheet, level: int) -> void:
	for a in unlocked_at(sheet, level):
		var id := a.indexAttack
		if id in c.attack_ids or id in c.pending_attack_ids:
			continue
		if c.attack_ids.size() < AlchemonInstance.MAX_ATTACKS:
			c.attack_ids.append(id)
			c.learned_attack_ids.append(id)
		elif c.is_player:
			c.pending_attack_ids.append(id)
		else:
			_replace_weakest(c, sheet, id)


static func resolve_pending(c: CombatantState, attack_id: int, replace_index: int) -> bool:
	var pending_pos := c.pending_attack_ids.find(attack_id)
	if pending_pos == -1:
		return false
	c.pending_attack_ids.remove_at(pending_pos)
	if replace_index < 0:
		return true
	return replace_attack(c, replace_index, attack_id)


static func replace_attack(c: CombatantState, index: int, attack_id: int) -> bool:
	if index < 0 or index >= c.attack_ids.size() or attack_id in c.attack_ids:
		return false
	c.attack_ids[index] = attack_id
	c.learned_attack_ids.append(attack_id)
	return true


static func _replace_weakest(c: CombatantState, sheet: AlchemonSheet, attack_id: int) -> void:
	var weakest := 0
	var weakest_power := 1 << 30
	for i in c.attack_ids.size():
		var a := resolve(sheet, c.attack_ids[i])
		var p := a.power if a != null else -1
		if p < weakest_power:
			weakest_power = p
			weakest = i
	replace_attack(c, weakest, attack_id)
