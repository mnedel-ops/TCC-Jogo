extends CharacterBody3D
class_name NPC

@onready var dialoguearea : Area3D = $DialogueCollision
@onready var is_zone : bool = false 
@onready var dialogueBox : Label = $Root/Dialogo

@export var figther : bool = false
@onready var combat_collision: Area3D = $CombatCollision

signal combat_start(index: int)
@export var alchemon:int

func _ready() -> void:
	dialoguearea.area_entered.connect(_on_area_entered)
	dialoguearea.area_exited.connect(_on_area_exited)
	dialogueBox.visible = false
	
	if figther:
		combat_collision.area_entered.connect(_on_combat_area_entered)
		combat_collision.area_exited.connect(_on_combat_area_exited)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_interact") and is_zone:
		talk()

#Func do dialogo
func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("player"):
		is_zone = true
func _on_area_exited(area: Area3D) -> void:
	if is_zone:
		is_zone = false
		dialogueBox.visible =false

func talk():
	print("Estamos conversando...")
	dialogueBox.visible = true
	

#Func do combate
func _on_combat_area_entered(area: Area3D) -> void:
	if area.is_in_group("player"):
		print("Vou te quebrar na porrada")
		combat_start.emit(alchemon)
func _on_combat_area_exited(area: Area3D) -> void:
	if area.is_in_group("player"):
		print("Cansei de te espancar. Vaza")
