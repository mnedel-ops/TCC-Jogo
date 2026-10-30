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

## Shopkeeper: opens the Buy / Sell / Leave box instead of the balloon.
var is_shopkeeper: bool = false
const SHOP_FALLBACK_GREETING := "Bem-vindo! O que deseja?"
var _shop: ShopDialogueBox

## Alchemon Center: asks "heal?", waits a bit, heals the party.
var is_healer: bool = false
var dialogue_healed: String = ""
const HEAL_PROMPT_FALLBACK := "Quer curar seus Alchemons?"
const HEAL_DONE_FALLBACK := "Pronto! Seus Alchemons estão curados."
const HEAL_WORKING_TEXT := "Curando..."
const HEAL_WAIT_SECONDS := 2.5
var _healing_busy := false   # question / wait running, balloon owns the input
var _locked_player: Player
## Leave is picked with the same key as ui_interact. This NPC polls that key in
## _process, same frame, and would reopen the shop. Frame stamp blocks it.
var _ui_closed_frame: int = -1

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
		_close_shop()
		return
	if _shop != null or _healing_busy:
		return   # shop box / heal balloon owns the input
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
		_close_shop()


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
	if is_shopkeeper:
		open_shop()
		return
	if is_healer:
		open_healer()
		return
	if _balloon.is_typing():
		_balloon.skip_typing()
	elif _balloon.is_open():
		_balloon.close()
	else:
		_balloon.show_text(get_dialogue())


#Func do Centro Alchemon
## Coroutine. Press 1: question. Yes: wait, heal, done text. Press again: close.
func open_healer() -> void:
	if _healing_busy or Engine.get_process_frames() == _ui_closed_frame:
		return
	if _balloon.is_open():   # leftover "healed" line: this press just closes it
		_balloon.close()
		return
	_healing_busy = true
	_lock_player(true)
	_balloon.ask(dialogue if dialogue != "" else HEAL_PROMPT_FALLBACK, ["Sim", "Não"])
	var pick: int = await _balloon.choice_made
	if pick == 0:
		_balloon.show_text(HEAL_WORKING_TEXT)
		await get_tree().create_timer(HEAL_WAIT_SECONDS).timeout
		if not CombatSignal.in_combat:
			GameSession.heal_party()
			_balloon.show_text(dialogue_healed if dialogue_healed != "" else HEAL_DONE_FALLBACK)
	else:
		_balloon.close()   # No, Cancel, or closed by someone else
	_healing_busy = false
	_ui_closed_frame = Engine.get_process_frames()
	_lock_player(false)


#Func da loja
func open_shop() -> void:
	if _shop != null or Engine.get_process_frames() == _ui_closed_frame:
		return
	_balloon.close()
	_lock_player(true)
	_shop = ShopDialogueBox.new()
	add_child(_shop)
	_shop.open(dialogue if dialogue != "" else SHOP_FALLBACK_GREETING)
	_shop.closed.connect(_close_shop)
	_shop.option_chosen.connect(_on_shop_option)


func _close_shop() -> void:
	if _shop == null:
		return
	_shop.queue_free()
	_shop = null
	_ui_closed_frame = Engine.get_process_frames()
	_lock_player(false)


## Hook for the real shop screens. Buy / Sell do nothing yet.
func _on_shop_option(_option: StringName) -> void:
	pass


## Player stands still while the box is open (same trick CombatHandler uses).
func _lock_player(locked: bool) -> void:
	if locked:
		_locked_player = null
		for n in get_tree().get_nodes_in_group("player"):
			if n is Player:
				_locked_player = n
				break
	if _locked_player == null or not is_instance_valid(_locked_player):
		return
	if locked:
		_locked_player.velocity = Vector3.ZERO
	_locked_player.set_physics_process(not locked)
	if not locked:
		_locked_player = null


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
