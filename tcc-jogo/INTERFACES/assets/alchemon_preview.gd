class_name AlchemonPreview
extends SubViewportContainer

## Spinning 3D preview of one species, in its own world (SubViewport) so it
## never touches the game scene. Same setup as the Table page.
## set_sheet() swaps the model. `spinning` = false freezes it.

@export var spin_speed := 0.8            # rad/s
@export var preview_size := 1.6          # model is scaled so its biggest side = this
var spinning := true

var _sheet: AlchemonSheet
var _pivot: Node3D
var _model_holder: Node3D


func _ready() -> void:
	stretch = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 140)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)

	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.8)
	env.ambient_light_energy = 0.6

	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.environment = env
	cam.transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.9, 3.4)).looking_at(Vector3(0, 0.1, 0), Vector3.UP)
	vp.add_child(cam)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	vp.add_child(light)

	_pivot = Node3D.new()
	vp.add_child(_pivot)
	_model_holder = Node3D.new()
	_pivot.add_child(_model_holder)
	_apply_sheet()   # set_sheet may have been called before we entered the tree


func _process(delta: float) -> void:
	if spinning and _pivot != null and is_visible_in_tree():
		_pivot.rotate_y(delta * spin_speed)


func set_sheet(sheet: AlchemonSheet) -> void:
	_sheet = sheet
	if _model_holder != null:
		_apply_sheet()


func _apply_sheet() -> void:
	var sheet := _sheet
	for c in _model_holder.get_children():
		_model_holder.remove_child(c)
		c.queue_free()
	_model_holder.scale = Vector3.ONE
	_model_holder.position = Vector3.ZERO

	var model: Node3D = null
	if sheet != null and sheet.model != null:
		var inst := sheet.model.instantiate()
		if inst is Node3D:
			model = inst
		else:
			inst.queue_free()
	if model == null:
		model = _make_placeholder_box(sheet)
	_model_holder.add_child(model)
	_fit_model()


## Placeholder until a species has a real `model`: a box tinted by element type.
func _make_placeholder_box(sheet: AlchemonSheet) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	var t: int = sheet.element_type if sheet != null else -1
	match t:
		AlchemonType.Type.METAL: mat.albedo_color = Color(0.62, 0.68, 0.78)
		AlchemonType.Type.AMETAL: mat.albedo_color = Color(0.45, 0.78, 0.45)
		_: mat.albedo_color = Color(0.9, 0.62, 0.3)
	mi.material_override = mat
	return mi


## Scale + center the model so any size fits the preview.
func _fit_model() -> void:
	var box := AABB()
	var first := true
	var to_local := _model_holder.global_transform.affine_inverse()
	for n in _model_holder.find_children("*", "VisualInstance3D", true, false):
		var vi := n as VisualInstance3D
		var a: AABB = (to_local * vi.global_transform) * vi.get_aabb()
		box = a if first else box.merge(a)
		first = false
	if first:
		return
	var biggest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if biggest <= 0.0001:
		return
	var f := preview_size / biggest
	_model_holder.scale = Vector3.ONE * f
	_model_holder.position = -box.get_center() * f
