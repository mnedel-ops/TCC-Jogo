class_name AlchemonsComponent
extends Node

@export var party: PlayerPartyData
@export var database: AlchemonDatabase
@export var panel: Control
@export var list: VBoxContainer

func open() -> void:
	panel.visible = true
	refresh()

func close() -> void:
	panel.visible = false

func refresh() -> void:
	for child in list.get_children():
		child.queue_free()
	if party == null or database == null:
		return
	for inst in party.party:
		var sheet := database.get_by_id(inst.species_id)
		if sheet == null:
			continue
		var hp := sheet.max_hp if inst.current_hp <= 0 else inst.current_hp
		var atk := AlchemonFormulas.compute_attack(sheet.base_attack, inst.individual_value, inst.level)
		var label := Label.new()
		label.text = "%s  Lv%d  HP %d/%d  XP %d/%d  ATK %d" % [sheet.creature_name, inst.level, hp, sheet.max_hp, inst.experience, AlchemonGrowth.XP_TO_LEVEL_UP, atk]
		list.add_child(label)
