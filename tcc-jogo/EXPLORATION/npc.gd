extends CharacterBody3D
class_name NPC

@onready var dialoguearea : Area3D = $DialogueCollision
@onready var is_zone : bool = false 

const BALLOON_SCENE: PackedScene = preload("res://INTERFACES/dialogue_balloon.tscn")
## Set by Level from the NPCSpawnPoint marker.
## dialogue = the only line of a normal NPC, or the line BEFORE the fight of a trainer.
var dialogue: String = ""
## Trainer only: line said after the player beat it.
var dialogue_defeated: String = ""
## Marker said is_fighter. Stays true after the defeat (figther goes false).
var is_trainer: bool = false
var _balloon: DialogueBalloon

@export var figther : bool = false
@onready var combat_collision: Area3D = $CombatCollision
@onready var is_combat_zone : bool = false 

@export var alchemon1:int =1
@export var alchemon2: int =1
var alchemon_level: int = -1
## Stable id set by Level ("scene_1/SpawnPoint"). Key in the save's defeated list.
var npc_id: String = ""


func _ready() -> void:
	dialoguearea.area_entered.connect(_on_area_entered)
	dialoguearea.area_exited.connect(_on_area_exited)
	_create_balloon()
	
	if figther:
		combat_collision.area_entered.connect(_on_combat_area_entered)
		combat_collision.area_exited.connect(_on_combat_area_exited)


func _process(delta: float) -> void:
	if CombatSignal.in_combat:
		_balloon.close()
		return
	if Input.is_action_just_pressed("ui_interact") and is_zone and not (figther and is_combat_zone):
		talk()

#Func do dialogo
func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("player"):
		is_zone = true
func _on_area_exited(area: Area3D) -> void:
	if is_zone:
		is_zone = false
		_balloon.close()


## Balloons live in screen space, so they need a CanvasLayer (this node is 3D).
func _create_balloon() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_balloon = BALLOON_SCENE.instantiate()
	layer.add_child(_balloon)
	_balloon.bind(self)


## Normal NPC: always `dialogue`. Trainer: `dialogue` until beaten, then `dialogue_defeated`.
func get_dialogue() -> String:
	if is_trainer and not figther and dialogue_defeated != "":
		return dialogue_defeated
	return dialogue if dialogue != "" else "..."


## 1st press opens the balloon, press while typing = show all text, next press closes.
func talk() -> void:
	if _balloon.is_typing():
		_balloon.skip_typing()
	elif _balloon.is_open():
		_balloon.close()
	else:
		_balloon.show_text(get_dialogue())


#Func do combate
func mark_defeated() -> void:
	figther = false
	GameSession.mark_npc_defeated(npc_id)


func _on_combat_area_entered(area: Area3D) -> void:
	if not figther:
		return
	if CombatSignal.in_combat:
		return # characters being moved around by the battle, ignore
	if area.is_in_group("player") and is_combat_zone !=true:
		is_combat_zone = true
		print("Vou te quebrar na porrada")
		print_debug(alchemon1, alchemon2)

		CombatSignal.enemy_node = self
		CombatSignal.enemy_level = alchemon_level
		CombatSignal.is_trainer_battle = true
		CombatSignal.combat_start.emit(alchemon1, alchemon2)
		
func _on_combat_area_exited(area: Area3D) -> void: #nao acho que precise deste
	if area.is_in_group("player"):
		is_combat_zone = false
		print("Cansei de te espancar. Vaza")
