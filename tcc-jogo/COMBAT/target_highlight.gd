class_name TargetHighlight
extends RefCounted

## Highlights every MeshInstance3D under a creature with a translucent overlay.
## Overlay = no change to the creature's own materials, clearing it restores it.

static var _material: StandardMaterial3D


static func _get_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.albedo_color = Color(1.0, 0.85, 0.2, 0.55)
	return _material


static func set_on(root: Node3D, on: bool) -> void:
	if root == null or not is_instance_valid(root):
		return
	for m in root.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_overlay = _get_material() if on else null
