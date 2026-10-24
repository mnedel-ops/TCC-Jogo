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
		var stats := inst.compute_stats(sheet)
		var max_hp: int = stats.max_hp
		var hp := inst.hp_or_full(max_hp)
		var atk: int = stats.attack
		var label := Label.new()
		label.text = "%s  Lv%d  HP %d/%d  XP %d/%d  ATK %d" % [sheet.creature_name, inst.level, hp, max_hp, inst.experience, AlchemonGrowth.XP_TO_LEVEL_UP, atk]
		list.add_child(label)
