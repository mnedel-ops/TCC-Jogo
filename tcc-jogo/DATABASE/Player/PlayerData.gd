class_name PlayerData
extends Resource


@export var player_name := "Muleke"
@export var team_name := ""
@export var money := 500
@export var play_time_seconds := 0.0
@export var portrait: Texture2D
@export var badges: Array[BadgeData] = []
@export var badge_slots := 8


func get_play_time() -> float:
	return play_time_seconds + Time.get_ticks_msec() / 1000.0


func add_money(amount: int) -> void:
	money = maxi(money + amount, 0)
	emit_changed()


func get_team_name() -> String:
	return team_name if team_name != "" else "Equipe do %s" % player_name


func award_badge(badge: BadgeData) -> bool:
	if badge == null:
		return false
	var slot: BadgeData = badge
	var found := false
	for b in badges:
		if b != null and (b == badge or b.badge_name == badge.badge_name):
			slot = b
			found = true
			break
	if slot.earned:
		return false
	if not found:
		push_warning("PlayerData: badge '%s' is not in player.tres badges. Added now, but it will not be saved." % badge.badge_name)
		badges.append(slot)
	slot.earned = true
	emit_changed()
	return true
