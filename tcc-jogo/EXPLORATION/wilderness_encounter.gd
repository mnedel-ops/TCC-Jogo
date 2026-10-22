@tool
class_name WildernessEncounter
extends Area3D

@export_range(1, 100) var min_level: int = 2
@export_range(1, 100) var max_level: int = 4

## Wilderness Encounter: bush area that can start a random fight.
## Check 1: chance that a fight happens. Check 2: which Alchemon from the list.
## Shape is per instance: edit `polygon` (and `height`) in the Inspector.

## Area outline. x = world X, y = world -Z (area lies flat on the ground).
@export var polygon: PackedVector2Array = PackedVector2Array([
		Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)]):
	set(value):
		polygon = value
		_apply_shape()

## Thickness of the area. Should cover the player's Y.
@export_range(0.5, 20.0, 0.1) var height: float = 4.0:
	set(value):
		height = value
		_apply_shape()

## Possible enemy species ids. One is picked at random.
@export var alchemons: Array[int] = []

@export_range(0.0, 1.0, 0.01) var encounter_chance: float = 0.3
## Seconds between rolls while the player stays inside.
@export_range(0.1, 10.0, 0.1) var check_interval: float = 1.0
## Seconds after a fight ends before rolling again.
@export_range(0.0, 30.0, 0.1) var cooldown: float = 3.0
## true = only roll while the player is moving (like walking in grass).
@export var require_movement: bool = true

var _inside: int = 0            # player areas inside (player may have several)
var _timer: float = 0.0
var _cooldown_left: float = 0.0
var _mover: CharacterBody3D = null


func _ready() -> void:
	_apply_shape()
	if Engine.is_editor_hint():
		return
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	CombatSignal.combat_ended.connect(_on_combat_ended)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _inside <= 0 or CombatSignal.in_combat:
		return
	if _cooldown_left > 0.0:
		_cooldown_left -= delta
		return
	if require_movement and _mover != null and _mover.velocity.length_squared() < 0.01:
		return
	_timer += delta
	if _timer >= check_interval:
		_timer = 0.0
		_roll()


func _apply_shape() -> void:
	var shape := get_node_or_null("CollisionPolygon3D") as CollisionPolygon3D
	if shape == null:
		return
	shape.polygon = polygon
	shape.depth = height


func _on_area_entered(area: Area3D) -> void:
	if not area.is_in_group("player"):
		return
	_inside += 1   # count even during combat: characters get moved around
	if _inside == 1:
		_mover = _find_body(area)
		if not CombatSignal.in_combat and _cooldown_left <= 0.0:
			_roll()   # roll on entry too


func _on_area_exited(area: Area3D) -> void:
	if not area.is_in_group("player"):
		return
	_inside = maxi(_inside - 1, 0)
	if _inside == 0:
		_timer = 0.0
		_mover = null


func _on_combat_ended() -> void:
	_cooldown_left = cooldown
	_timer = 0.0


func _roll() -> void:
	if alchemons.is_empty():
		push_warning("WildernessEncounter '%s': alchemons list empty." % name)
		return
	if randf() >= encounter_chance:          # check 1: fight or not
		return
	var species_id: int = alchemons[randi() % alchemons.size()]   # check 2: who
	print("Wilderness Encounter: species ", species_id)
	CombatSignal.enemy_node = null
	CombatSignal.is_trainer_battle = false
	CombatSignal.enemy_level = randi_range(mini(min_level, max_level), maxi(min_level, max_level))
	CombatSignal.combat_start.emit(species_id, -1)


func _find_body(from: Node) -> CharacterBody3D:
	var n := from
	while n != null and not n is CharacterBody3D:
		n = n.get_parent()
	return n as CharacterBody3D
