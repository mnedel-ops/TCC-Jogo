class_name AttackDatabase
extends Resource

const DEFAULT_PATH := "res://DATABASE/Attack/AttackDatabase.tres"

static var _default: AttackDatabase

@export var attacks: Array[AttackData] = []


static func default() -> AttackDatabase:
	if _default == null:
		_default = load(DEFAULT_PATH) as AttackDatabase
		if _default == null:
			_default = AttackDatabase.new()
	return _default


func get_by_id(id: int) -> AttackData:
	for a in attacks:
		if a != null and a.indexAttack == id:
			return a
	return null
