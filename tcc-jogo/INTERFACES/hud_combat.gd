class_name CombatBalloons
extends CanvasLayer

const BALLOON_SCENE: PackedScene = preload("res://INTERFACES/baloon_hud.tscn")

var anchors: Dictionary = {}      # BattlefieldSlot -> Node3D
var _balloons: Dictionary = {}    # combatant id -> CombatBalloon

func update_all(entries: Array[Dictionary]) -> void:
	for e in entries:
		var b: CombatBalloon = _balloons.get(e.id)
		if b == null:
			var anchor: Node3D = anchors.get(e.slot)
			if anchor == null:
				push_warning("Sem anchor pro slot %d" % e.slot)
				continue
			b = BALLOON_SCENE.instantiate()
			add_child(b)
			b.bind(anchor)
			_balloons[e.id] = b
		b.update_entry(e)
