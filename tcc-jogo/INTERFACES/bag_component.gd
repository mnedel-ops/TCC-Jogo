class_name BagComponent
extends Node

@export var mochila: InventoryData
@export var inventoryui:Control
@export var inventory_database: ItemDatabase
@export var item_list : VBoxContainer

func open_bag() -> void:
	if mochila == null:
		return
	print(mochila.items)
	inventoryui.visible=true
	refresh()
	
func _on_menu_pause_menu_closed() -> void:
	inventoryui.visible = false

func refresh() -> void:
	if not is_instance_valid(item_list):
		return
	for child in item_list.get_children():
		child.queue_free()
	if mochila == null or inventory_database == null:
		return
	for stack in mochila.get_stacked_view(inventory_database):
		var label := Label.new()
		label.text = "%s, %d" % [stack.nome, stack.quantidade]
		item_list.add_child(label)
