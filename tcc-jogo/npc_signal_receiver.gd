extends Node
signal combat_start(index: int)

func _on_npc_combat_start(index: int) -> void:
	print("Recebi um sinal.", index)
	combat_start.emit(index)


func _on_npc_2_combat_start(index:int) -> void:
	print("Recebi um sinal", index)
	combat_start.emit(index)
