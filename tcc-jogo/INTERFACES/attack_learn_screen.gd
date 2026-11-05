class_name AttackLearnScreen
extends CanvasLayer


signal chosen(replace_index: int)


func _init() -> void:
	layer = 60


func ask(creature_name: String, new_attack: AttackData, known: Array[AttackData]) -> void:
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
	title.text = "%s quer aprender %s!" % [creature_name, new_attack.attack_name]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)

	var info := Label.new()
	info.text = "%s  |  Poder %d  |  Custo %d\nMas ja conhece %d ataques. Qual esquecer?" % [
		AlchemonType.type_name(new_attack.element_type), new_attack.power, new_attack.energy_cost, known.size()]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(info)
	box.add_child(HSeparator.new())

	var first: Button = null
	for i in known.size():
		var a := known[i]
		var b := Button.new()
		b.text = "Esquecer %s" % (a.attack_name if a != null else "???")
		if a != null:
			b.text += "  (%s, Poder %d, Custo %d)" % [AlchemonType.type_name(a.element_type), a.power, a.energy_cost]
		b.pressed.connect(_pick.bind(i))
		box.add_child(b)
		if first == null:
			first = b

	var skip := Button.new()
	skip.text = "Nao aprender %s" % new_attack.attack_name
	skip.pressed.connect(_pick.bind(-1))
	box.add_child(skip)
	(first if first != null else skip).grab_focus.call_deferred()


func _pick(index: int) -> void:
	chosen.emit(index)
