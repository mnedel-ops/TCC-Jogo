extends CharacterBody3D
class_name NPC

@onready var dialoguearea : Area3D = $DialogueCollision
@onready var is_zone : bool = false 

var dialogue: String = ""
var dialogue_defeated: String = ""
var is_trainer: bool = false
var is_gym_trainer: bool = false
var badge: BadgeData
var _badge_message := ""
var _message_token := 0
var _dialogue_box: DialogueBox

var is_shopkeeper: bool = false
const SHOP_FALLBACK_GREETING := "Bem-vindo! O que deseja?"
var _shop: ShopDialogueBox

var is_healer: bool = false
var dialogue_healed: String = ""
const HEAL_PROMPT_FALLBACK := "Quer curar seus Alchemons?"
const HEAL_DONE_FALLBACK := "Pronto! Seus Alchemons estão curados."
const HEAL_WORKING_TEXT := "Curando..."
const HEAL_WAIT_SECONDS := 2.5
var _healing_busy := false
var _locked_player: Player
var _ui_closed_frame: int = -1

@export var figther : bool = false
@onready var combat_collision: Area3D = $CombatCollision
@onready var is_combat_zone : bool = false 

@export var alchemon1:int =1
@export var alchemon2: int =1
var alchemon_level: int = -1
var npc_id: String = ""


func _ready() -> void:
	dialoguearea.area_entered.connect(_on_area_entered)
	dialoguearea.area_exited.connect(_on_area_exited)
	_create_dialogue_box()
	
	if figther:
		combat_collision.area_entered.connect(_on_combat_area_entered)
		combat_collision.area_exited.connect(_on_combat_area_exited)


func _process(delta: float) -> void:
	if CombatSignal.in_combat:
		_dialogue_box.close()
		_close_shop()
		return
	if _badge_message != "":
		_show_badge_message()
	if _shop != null or _healing_busy:
		return
	if Input.is_action_just_pressed("ui_interact") and is_zone and not (figther and is_combat_zone):
		talk()

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("player"):
		is_zone = true
func _on_area_exited(area: Area3D) -> void:
	if is_zone:
		is_zone = false
		_dialogue_box.close()
		_close_shop()


func _create_dialogue_box() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_dialogue_box = DialogueBox.new()
	layer.add_child(_dialogue_box)


func get_dialogue() -> String:
	if is_trainer and not figther and dialogue_defeated != "":
		return dialogue_defeated
	return dialogue if dialogue != "" else "..."


func talk() -> void:
	if is_shopkeeper:
		open_shop()
		return
	if is_healer:
		open_healer()
		return
	if _dialogue_box.is_typing():
		_dialogue_box.skip_typing()
	elif _dialogue_box.is_open():
		_dialogue_box.close()
	else:
		_dialogue_box.show_text(get_dialogue())


func _show_badge_message() -> void:
	var text := _badge_message
	_badge_message = ""
	_message_token += 1
	var token := _message_token
	_dialogue_box.show_text(text)
	await get_tree().create_timer(4.0).timeout
	if token == _message_token and _dialogue_box.is_open():
		_dialogue_box.close()


func open_healer() -> void:
	if _healing_busy or Engine.get_process_frames() == _ui_closed_frame:
		return
	if _dialogue_box.is_open():
		_dialogue_box.close()
		return
	_healing_busy = true
	_lock_player(true)
	_dialogue_box.ask(dialogue if dialogue != "" else HEAL_PROMPT_FALLBACK, ["Sim", "Não"])
	var pick: int = await _dialogue_box.choice_made
	if pick == 0:
		_dialogue_box.show_text(HEAL_WORKING_TEXT)
		await get_tree().create_timer(HEAL_WAIT_SECONDS).timeout
		if not CombatSignal.in_combat:
			GameSession.heal_party()
			_dialogue_box.show_text(dialogue_healed if dialogue_healed != "" else HEAL_DONE_FALLBACK)
	else:
		_dialogue_box.close()
	_healing_busy = false
	_ui_closed_frame = Engine.get_process_frames()
	_lock_player(false)


func open_shop() -> void:
	if _shop != null or Engine.get_process_frames() == _ui_closed_frame:
		return
	_dialogue_box.close()
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


func _on_shop_option(_option: StringName) -> void:
	pass


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


func mark_defeated() -> void:
	figther = false
	if is_gym_trainer and GameSession.player.award_badge(badge):
		_badge_message = "Você recebeu a %s!" % badge.badge_name
	GameSession.mark_npc_defeated(npc_id)


func _on_combat_area_entered(area: Area3D) -> void:
	if not figther:
		return
	if CombatSignal.in_combat:
		return
	if area.is_in_group("player") and is_combat_zone !=true:
		if not GameSession.can_fight():
			return
		is_combat_zone = true
		print("Vou te quebrar na porrada")
		print_debug(alchemon1, alchemon2)

		CombatSignal.enemy_node = self
		CombatSignal.enemy_level = alchemon_level
		CombatSignal.is_trainer_battle = true
		CombatSignal.combat_start.emit(alchemon1, alchemon2)
		
func _on_combat_area_exited(area: Area3D) -> void:
	if area.is_in_group("player"):
		is_combat_zone = false
		print("Cansei de te espancar. Vaza")
