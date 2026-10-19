extends Node
signal combat_start(alchemonA: int, alchemonB: int)
signal combat_ended
signal player_party(alchemonA:int, alchemonB: int)

## Enemy NPC that started the fight. Set BEFORE emitting combat_start.
## null = unknown (manager centers on player, enemy does not move).
var enemy_node: Node3D = null
## Level of the enemies in the next fight. Set BEFORE emitting combat_start.
## -1 = not set (enemies use DEFAULT_ENEMY_LEVEL).
var enemy_level: int = -1
## true from combat_start until characters are back home. NPCs must not start
## a fight while true (they leave/enter their combat area when moved).
var in_combat: bool = false
