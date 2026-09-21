extends Node
@onready var player: Player = $".."

func _ready() -> void:
	CombatSignal.combat_start.connect(_on_combat_start)
	CombatSignal.combat_ended.connect(_on_combat_end)
	
	
func _on_combat_start(alchemonA: int, alchemonB: int):
	player.set_physics_process(false)

func _on_combat_end():
	player.set_physics_process(true)
