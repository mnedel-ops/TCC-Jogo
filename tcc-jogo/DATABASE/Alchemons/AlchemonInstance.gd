class_name AlchemonInstance
extends Resource

@export var species_id: int
@export var level: int = 1
@export var experience: int = 0
@export var current_hp: int = -1
@export var individual_value: int = 1 #Pokemon IV

func init_from_template(template: AlchemonSheet) ->void:
	species_id = template.id
	if current_hp == -1:
		current_hp = template.max_hp
