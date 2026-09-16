class_name MovementComponent
extends Node

@export var body: CharacterBody3D      # arrasta o proprio Player aqui no Inspector
@export var mesh: MeshInstance3D       # arrasta Mesh aqui
@export var speed: float = 5.0

func process_movement(delta: float) -> void:
	if not body.is_on_floor():
		body.velocity += body.get_gravity() * delta

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := (body.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		body.velocity.x = direction.x * speed
		body.velocity.z = direction.z * speed
		if mesh:
			mesh.rotation.y = atan2(-direction.x, -direction.z)
	else:
		body.velocity.x = move_toward(body.velocity.x, 0, speed)
		body.velocity.z = move_toward(body.velocity.z, 0, speed)

	body.move_and_slide()
