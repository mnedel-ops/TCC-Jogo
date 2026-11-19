extends GdUnitTestSuite


func _keys_of(entries: Array[Dictionary]) -> Array:
	var out: Array = []
	for e in entries:
		out.append_array(e["keys"])
	return out


func test_exploration_shows_menu_and_interact() -> void:
	var h := CommandHints.hints_for(false)
	assert_int(h.size()).is_equal(2)
	assert_array(_keys_of(h)).is_equal(["TAB", "E"])
	assert_str(h[0]["label"]).is_equal("Menu")
	assert_str(h[1]["label"]).is_equal("Interagir")


func test_combat_shows_navigate_and_confirm() -> void:
	var h := CommandHints.hints_for(true)
	assert_int(h.size()).is_equal(2)
	assert_array(_keys_of(h)).is_equal(["W", "A", "S", "D", "E"])
	assert_str(h[0]["label"]).is_equal("Navegar")
	assert_str(h[1]["label"]).is_equal("Confirmar")


func test_every_entry_has_keys_and_label() -> void:
	for in_combat in [false, true]:
		for e in CommandHints.hints_for(in_combat):
			assert_bool((e["keys"] as Array).is_empty()).is_false()
			assert_str(e["label"]).is_not_empty()
