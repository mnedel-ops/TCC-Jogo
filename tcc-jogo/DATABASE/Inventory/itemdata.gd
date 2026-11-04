class_name ItemData
extends Resource

@export var index: int = 0
@export var nome: String = ""
@export_multiline var descricao: String = ""
@export var icone: Texture2D
@export var heal_amount: int = 0
@export var is_capture_method: bool = false
@export var capture_type: AlchemonType.Type = AlchemonType.Type.METAL
