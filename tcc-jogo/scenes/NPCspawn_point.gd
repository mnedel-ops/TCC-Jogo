extends Marker3D
class_name NPCSpawnPoint
#Aqui define quem eh o NPC instanciado. Dps colocar pra alterar a sprite. 
@export var npc_scene: PackedScene
@export var alchemons_ids: Array[int] = []
@export_range(1, 100) var level: int = 1
@export var is_fighter :bool= false
## Shopkeeper: interact opens the shop box (Buy / Sell / Leave) instead of the balloon.
## `dialogue` is its greeting. Wins over is_fighter (a shopkeeper never fights).
@export var is_shopkeeper: bool = false
## Alchemon Center: interact asks "heal?" (Yes / No). Yes = wait a bit, then the
## party is fully healed. `dialogue` is the question. Never fights.
@export var is_healer: bool = false

@export_group("Dialogue")
## What the NPC says (balloon above its head, press interact). Normal NPC: its only line.
## Fighter: the line BEFORE the battle. Shopkeeper: the greeting above Buy / Sell / Leave.
@export_multiline var dialogue: String = ""
## Fighter only (is_fighter on): the line AFTER the player beat it. Ignored otherwise.
@export_multiline var dialogue_defeated: String = ""
## Healer only: line shown once the party is healed.
@export_multiline var dialogue_healed: String = ""
