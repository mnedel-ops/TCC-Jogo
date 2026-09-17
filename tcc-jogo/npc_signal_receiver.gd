extends Node
signal combat_start(index: int)

func _on_npc_combat_start(index: int, id2:int) -> void:
	print("Recebi um sinal.", index,id2)
	combat_start.emit(index, id2)


func _on_npc_2_combat_start(index:int, id2:int) -> void:
	print("Recebi um sinal", index,id2)
	combat_start.emit(index,id2)
