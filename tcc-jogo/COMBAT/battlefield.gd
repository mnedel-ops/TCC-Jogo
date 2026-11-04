class_name Battlefield
extends RefCounted


var slot_occupancy: Array[int] = []


func _init() -> void:
	slot_occupancy.resize(BattlefieldSlot.SLOT_COUNT)
	slot_occupancy.fill(-1)


func assign_combatant(combatant_id: int, slot: int) -> void:
	if slot < 0 or slot >= BattlefieldSlot.SLOT_COUNT:
		push_error("Invalid slot: %d" % slot)
		return
	if slot_occupancy[slot] != -1:
		push_error("Slot %d already occupied by %d" % [slot, slot_occupancy[slot]])
		return
	slot_occupancy[slot] = combatant_id


func get_occupant(slot: int) -> int:
	if slot < 0 or slot >= BattlefieldSlot.SLOT_COUNT:
		return -1
	return slot_occupancy[slot]


func get_combatant_slot(combatant_id: int) -> int:
	return slot_occupancy.find(combatant_id)


func free_slot(slot: int) -> void:
	if slot >= 0 and slot < BattlefieldSlot.SLOT_COUNT:
		slot_occupancy[slot] = -1


func get_occupied_slots() -> Array[int]:
	var occupied: Array[int] = []
	for slot in range(BattlefieldSlot.SLOT_COUNT):
		if slot_occupancy[slot] != -1:
			occupied.append(slot)
	return occupied


func get_occupied_side_slots(is_player: bool) -> Array[int]:
	var side_slots := BattlefieldSlot.get_side_slots(is_player)
	var occupied: Array[int] = []
	for slot in side_slots:
		if slot_occupancy[slot] != -1:
			occupied.append(slot)
	return occupied


func get_side_combatants(is_player: bool) -> Array[int]:
	var combatants: Array[int] = []
	for slot in BattlefieldSlot.get_side_slots(is_player):
		if slot_occupancy[slot] != -1:
			combatants.append(slot_occupancy[slot])
	return combatants


func get_opposing_combatants(is_player: bool) -> Array[int]:
	return get_side_combatants(not is_player)


func is_occupied(slot: int) -> bool:
	if slot < 0 or slot >= BattlefieldSlot.SLOT_COUNT:
		return false
	return slot_occupancy[slot] != -1


func is_available(slot: int) -> bool:
	return not is_occupied(slot)


func _to_string() -> String:
	return "Battlefield(slots=[P1:%d, P2:%d, E1:%d, E2:%d])" % slot_occupancy
