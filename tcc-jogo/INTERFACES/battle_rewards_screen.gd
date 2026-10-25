class_name BattleRewardsScreen
extends CanvasLayer

## Shown after the last turn: EXP gained, level-ups, coins. Waits for ANY
## key / mouse / gamepad button, then emits `dismissed`. Pure presentation:
## it only displays a BattleRewards. Built in code (no .tscn), like the PC UI.

signal dismissed

## Ignore input right after opening, so the key the player was mashing during
## the last attack cannot skip the screen by accident.
const INPUT_DELAY := 0.6

var _accepting := false
var _done := false


func _init() -> void:
	layer = 50   # above the combat HUD balloons


func show_rewards(rewards: BattleRewards) -> void:
	_build(rewards)
	await get_tree().create_timer(INPUT_DELAY).timeout
	_accepting = true
	_prompt.visible = true


var _prompt: Label


func _build(r: BattleRewards) -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Victory!" if r.player_won else "Defeat..."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	box.add_child(HSeparator.new())

	for line in lines_for(r):
		var l := Label.new()
		l.text = line.text
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if line.highlight:
			l.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
		box.add_child(l)

	box.add_child(HSeparator.new())
	_prompt = Label.new()
	_prompt.text = "Press any key to continue"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.modulate = Color(1, 1, 1, 0.7)
	_prompt.visible = false
	box.add_child(_prompt)


## Text of the screen, one {text, highlight} per line. Static + pure so it is
## unit-testable without building any nodes.
static func lines_for(r: BattleRewards) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var any_xp := false
	for e in r.entries:
		if e.xp_gained <= 0:
			continue
		any_xp = true
		out.append({"text": "%s gained %d EXP" % [e.name, e.xp_gained], "highlight": false})
		if e.level_after > e.level_before:
			out.append({"text": "%s leveled up to %d!" % [e.name, e.level_after], "highlight": true})
	if not any_xp:
		out.append({"text": "No EXP gained.", "highlight": false})
	if r.money > 0:
		out.append({"text": "You received %d coins!" % r.money, "highlight": true})
	return out


func _input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()   # nothing underneath may react while this is open
	if not _accepting or _done:
		return
	var pressed := false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo
	elif event is InputEventMouseButton or event is InputEventJoypadButton:
		pressed = event.pressed
	if pressed:
		_done = true
		dismissed.emit()
