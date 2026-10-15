class_name PlayerData
extends Resource

## Player profile shown on the Player page.
## Save/load can serialize this resource later.

@export var player_name := "Muleke"
@export var team_name := ""   # empty = "Equipe do <player_name>"
@export var money := 0
## Time played in previous sessions (seconds). Save this.
@export var play_time_seconds := 0.0
@export var portrait: Texture2D
@export var badges: Array[BadgeData] = []
## Slots drawn on the page (empty ones are dimmed). Grows if badges has more.
@export var badge_slots := 8


## Previous sessions + this run. Time.get_ticks_msec() keeps counting while the
## tree is paused (menu open), so no autoload needed for now.
func get_play_time() -> float:
	return play_time_seconds + Time.get_ticks_msec() / 1000.0


func get_team_name() -> String:
	return team_name if team_name != "" else "Equipe do %s" % player_name
