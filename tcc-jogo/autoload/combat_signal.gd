extends Node
signal combat_start(alchemonA: int, alchemonB: int)
signal combat_ended
signal player_party(alchemonA:int, alchemonB: int)
## World position of the enemy that started the fight. Set BEFORE emitting
## combat_start. Vector3.INF = unknown (manager falls back to the player).
var enemy_position: Vector3 = Vector3.INF
