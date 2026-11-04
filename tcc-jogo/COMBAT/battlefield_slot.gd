class_name BattlefieldSlot
extends RefCounted


const PLAYER_SLOT_1 := 0
const PLAYER_SLOT_2 := 1
const ENEMY_SLOT_1 := 2
const ENEMY_SLOT_2 := 3

const SLOT_COUNT := 4


static func get_side_slots(is_player: bool) -> Array[int]:
	if is_player:
		return [PLAYER_SLOT_1, PLAYER_SLOT_2]
	else:
		return [ENEMY_SLOT_1, ENEMY_SLOT_2]
