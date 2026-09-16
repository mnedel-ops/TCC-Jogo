extends CharacterBody3D
class_name Player

#Componentes
@onready var movement: MovementComponent = $MovementComponent
@onready var interaction: InteractionComponent = $InteractionComponent
@onready var inventory: InventoryComponent = $InventoryComponent

@onready var interact_area: Area3D = $Mesh/InteractArea


func _physics_process(delta: float) -> void:
	movement.process_movement(delta)
	if Input.is_action_just_pressed("ui_interact"):
		var target := interaction.try_collect()
		if target:
			inventory.collect_from_area(target)
