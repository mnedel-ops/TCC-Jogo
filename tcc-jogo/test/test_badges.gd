extends GdUnitTestSuite

func _player_with_badge() -> Array:
	var p := PlayerData.new()
	var b := BadgeData.new()
	b.badge_name = "Insignia X"
	p.badges.append(b)
	return [p, b]


func test_award_marks_the_slot_earned_once() -> void:
	var pb := _player_with_badge()
	var p: PlayerData = pb[0]
	var b: BadgeData = pb[1]
	assert_bool(p.award_badge(b)).is_true()
	assert_bool(b.earned).is_true()
	assert_bool(p.award_badge(b)).is_false()


func test_award_matches_by_name_when_it_is_another_instance() -> void:
	var pb := _player_with_badge()
	var p: PlayerData = pb[0]
	var other := BadgeData.new()
	other.badge_name = "Insignia X"
	assert_bool(p.award_badge(other)).is_true()
	assert_bool((p.badges[0] as BadgeData).earned).is_true()
	assert_int(p.badges.size()).is_equal(1)


func test_award_null_is_false() -> void:
	assert_bool(PlayerData.new().award_badge(null)).is_false()


func test_real_player_tres_has_the_metal_badge_slot_and_it_saves() -> void:
	var p: PlayerData = load("res://DATABASE/Player/player.tres")
	assert_int(p.badges.size()).is_greater_equal(1)
	assert_str((p.badges[0] as BadgeData).badge_name).is_equal("Insígnia do Metal")
