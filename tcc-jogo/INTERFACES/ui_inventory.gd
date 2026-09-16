extends Control

@export var mochila: InventoryData
@export var inventory_database: ItemDatabase
@onready var item_list: VBoxContainer = $Panel/ItemList

var is_open := false

func _ready() -> void:
	if mochila:
		mochila.changed.connect(refresh)
	close()
	refresh()

func open() -> void:
	visible = true
	is_open = true
	refresh()

func close() -> void:
	visible = false
	is_open = false

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

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_options"):
		if is_open:
			close()
		else:
			open()
