class_name AlchemonInstance
extends Resource

@export var species_id: int
@export var creature_name: String

@export var level: int = 1
@export var experience: int = 0
@export var max_hp: int = -1
@export var current_hp: int = -1
@export var individual_value: int = 1 #Pokemon IV

@export var defense: int = -1
@export var mechanical_speed: int = -1
@export var action_energy: int = -1

func init_from_template(template: AlchemonSheet) ->void:
	creature_name = template.creature_name
	species_id = template.id
	if max_hp == -1:
		max_hp = template.max_hp
		current_hp = max_hp
