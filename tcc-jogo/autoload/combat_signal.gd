extends Node
signal combat_start(alchemonA: int, alchemonB: int)
signal combat_ended
signal battle_finished(player_won: bool, was_trainer: bool)
signal creatures_synced
signal party_changed
signal player_party(alchemonA:int, alchemonB: int)

var enemy_node: Node3D = null
var enemy_level: int = -1
var in_combat: bool = false
var is_trainer_battle: bool = false
