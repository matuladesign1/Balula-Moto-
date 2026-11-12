class_name VehiclePreview
extends SubViewportContainer
## Aperçu 3D d'un véhicule. On peut le faire tourner avec le doigt ou la souris.

var _viewport: SubViewport
var _pivot: Node3D
var _cam: Camera3D
var _model: VehicleModel = null
var _yaw := 0.7
var _idle := 0.0
var _pending: Array = []   # véhicule demandé avant que l'aperçu soit prêt


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(320, 240)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#223555")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d3dcea")
	env.ambient_light_energy = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_energy = 1.0
	_viewport.add_child(sun)

	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.8
	cyl.bottom_radius = 2.8
	cyl.height = 0.06
	cyl.radial_segments = 32
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#2c3d5c")
	mat.roughness = 1.0
	cyl.material = mat
	disc.mesh = cyl
	disc.position = Vector3(0, -0.03, 0)
	_viewport.add_child(disc)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)

	_cam = Camera3D.new()
	_cam.fov = 38.0
	_viewport.add_child(_cam)
	_cam.look_at_from_position(Vector3(0.0, 1.6, 5.2), Vector3(0.0, 0.7, 0.0))
	if not _pending.is_empty():
		var p: Array = _pending
		_pending = []
		show_vehicle(p[0], p[1], p[2])


## Affiche un véhicule du catalogue avec sa personnalisation et ses améliorations.
func show_vehicle(def: Dictionary, custom: Dictionary, upgrades: Dictionary) -> void:
	if _model != null:
		_model.queue_free()
		_model = null
	if _pivot == null:
		_pending = [def, custom, upgrades]
		return
	if def.is_empty():
		return
	_model = VehicleModel.create(def, custom, upgrades, true)
	_pivot.add_child(_model)
	var s := _model.collision_size
	var span := maxf(s.z, s.x * 1.6)
	_cam.look_at_from_position(Vector3(0.0, 0.6 + span * 0.35, span * 1.5 + 2.4), Vector3(0.0, s.y * 0.42, 0.0))


func _process(delta: float) -> void:
	if _idle > 0.0:
		_idle -= delta
	else:
		_yaw += delta * 0.55
	if _pivot != null:
		_pivot.rotation.y = _yaw


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		if (m.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_yaw += m.relative.x * 0.012
			_idle = 2.5
