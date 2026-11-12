class_name Showroom3D
extends Control
## Real-time 3D showroom of the vehicle selection in the graphics mode "Modern" (v0.8.0, contract §4.8, D36,
## docs/grafik-modi.md): the car's `show` model on a slowly turning turntable in its own small 3D world, lit like a
## studio – a key light with a soft shadow, a fill light, two rim lights in the accent colours of the menus and a
## procedural studio sky that only shows in the reflections. The menu background shows through (transparent
## SubViewport).
##
## Lives as a child inside CarShowcase (same place, same show_vehicle() call – VehicleScreen is untouched), which
## loads this script at run time and only in Modern: an Arcade start never compiles it (it names ModelDB,
## ModelFactory and ModernMaterials). CarShowcase keeps drawing the sprite while a model loads and for every set
## the manifest does not mark `showroom: true`.
##
## Models come from ModelDB / ModelFactory at the level "show" (threaded loading: ModelDB.request with this node as
## the owner, built once pending() is 0); the materials are ModernMaterials.shared(). Leaving the screen or the mode
## signs off (ModelDB.release_all(self)); leaving Modern additionally drops the caches and the shared materials
## (GameFlow). The SubViewport is sized in PHYSICAL pixels (control size × the window's stretch scale): with the
## stretch mode canvas_items a viewport of the logical size would be scaled up softly in a 1080p window.
##
## The process-wide ce_* shader globals are set to a dry daylight studio whenever a car is shown (a Modern race may
## have left night, rain or a tunnel in them).
## Debug: --showroom-force[=id,…] treats the player cars (all with a show level, or the listed ids) as if the
## manifest marked them `showroom: true`; --showroom-still stops the turntable (screenshots).

const SHOW_LEVEL := "show"
const TURN_DEG_S := 11.0              ## turntable speed
## Turntable angle at the start: the camera sees the car from its front right, like the Cycles showroom sprites
## (catalog.py turns the car by 142°; here the car turns, not the camera, and its front is −Z).
const START_YAW_DEG := -142.0
const CAM_ELEVATION_DEG := 11.0       ## as the sprite camera
const CAM_FOV_DEG := 26.0
const FILL := 0.88                    ## share of the picture width the turntable may use (the 2D platform: 0.84)
const SLIDE_PX := 120.0
const TURNTABLE_R := 2.8              ## m (a 4.85 m car fits with 0.15 m to spare)

## Sets treated as `showroom: true` whatever the manifest says (tests, --showroom-force). Static: CarShowcase asks
## before an instance exists.
static var force_sets: Array = []

var set_id := ""                      ## set being shown (or loading)
var viewport: SubViewport
var turn := true                      ## false: frozen turntable (screenshots, tests)
var ready_to_show := false            ## the car of set_id is built and on the turntable
var built_sets: Array[String] = []    ## every set built so far (tests)
var _view: TextureRect
var _pivot: Node3D
var _car: Node3D
var _cam: Camera3D
var _key: DirectionalLight3D
var _env: Environment
var _anim := 1.0
var _dir := 1.0
var _yaw := START_YAW_DEG
var _loading := ""                    ## set whose files ModelDB is still loading
var _requested := false               ## this node signed on at ModelDB (release_all(self) on exit)


## True when `id` (a sprite set, "showroom/<car>") gets the 3D showroom: the manifest marks it `showroom: true` (or it
## is forced) and its model has the level "show". Reads the manifest only – loads no mesh.
static func can_show(id: String) -> bool:
	var r := ModelDB.resolve(id)
	var model: Dictionary = r.get("model", {})
	if model.is_empty():
		return false
	if not bool(r.get("showroom", false)) and not is_forced(id):
		return false
	return not ModelDB.lod(model, SHOW_LEVEL).is_empty()


## Forced by force_sets or by the command line (--showroom-force = every set, --showroom-force=limousine,kompakt).
static func is_forced(id: String) -> bool:
	if force_sets.has(id):
		return true
	if not CliArgs.has("showroom-force"):
		return false
	var only := CliArgs.get_string("showroom-force", "")
	if only == "" or only == "true":
		return true
	for v: String in only.split(",", false):
		if id == v.strip_edges() or id == "showroom/" + v.strip_edges():
			return true
	return false


## Render size of the SubViewport: the control's size in physical pixels (the window's stretch scale), at least
## 16 px each way.
static func physical_size(control_size: Vector2, stretch_scale: Vector2) -> Vector2i:
	return Vector2i((control_size * stretch_scale).round()).max(Vector2i(16, 16))


## Camera distance at which a car of footprint radius `radius_m` fills FILL of the picture width (aspect = w / h).
static func fit_distance(radius_m: float, aspect: float, fov_deg: float = CAM_FOV_DEG) -> float:
	var half_v := deg_to_rad(fov_deg) * 0.5
	var half_h := atan(tan(half_v) * maxf(aspect, 0.1))
	return maxf(radius_m, 0.5) / maxf(sin(half_h * FILL), 0.05)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	turn = not CliArgs.has("showroom-still")
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	viewport.positional_shadow_atlas_size = 0
	add_child(viewport)
	_build_world()
	_view = TextureRect.new()
	_view.texture = viewport.get_texture()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_view)
	resized.connect(_fit)
	get_viewport().size_changed.connect(_fit)
	_fit()
	visible = false


func _exit_tree() -> void:
	release()


## Frees the car and signs off at ModelDB (the caches go when nobody else holds them).
func release() -> void:
	if _car != null and is_instance_valid(_car):
		_car.free()
	_car = null
	ready_to_show = false
	_loading = ""
	if _requested:
		_requested = false
		ModelDB.release_all(self)


func _fit() -> void:
	if viewport == null or not is_inside_tree():
		return
	var px := physical_size(size, get_viewport().get_stretch_transform().get_scale())
	if viewport.size != px:
		viewport.size = px
	_frame()


func _build_world() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_CLEAR_COLOR      # the viewport stays transparent
	var sky_mat := ProceduralSkyMaterial.new()              # studio: dark ceiling, bright soft-box band, dark floor
	sky_mat.sky_top_color = Color(0.09, 0.1, 0.2)
	sky_mat.sky_horizon_color = Color(0.92, 0.94, 1.0)
	sky_mat.sky_curve = 0.09
	sky_mat.ground_horizon_color = Color(0.3, 0.22, 0.42)
	sky_mat.ground_bottom_color = Color(0.02, 0.02, 0.05)
	sky_mat.ground_curve = 0.05
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.46, 0.48, 0.6)
	_env.ambient_light_energy = 0.42
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX
	_env.tonemap_exposure = 1.0
	var we := WorldEnvironment.new()
	we.environment = _env
	viewport.add_child(we)
	# key: upper left in front of the car, soft shadow onto the turntable
	_key = DirectionalLight3D.new()
	_key.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	_key.light_energy = 1.05
	_key.light_color = Color(1.0, 0.97, 0.92)
	_key.shadow_enabled = true
	_key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_key.directional_shadow_max_distance = 30.0
	_key.shadow_bias = 0.03
	_key.shadow_normal_bias = 1.0
	_key.shadow_blur = 1.5
	viewport.add_child(_key)
	# fill from the other side, no shadow
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18.0, 125.0, 0.0)
	fill.light_energy = 0.26
	fill.light_color = Color(0.82, 0.88, 1.0)
	viewport.add_child(fill)
	# two rim lights behind the car in the menu accents (magenta left, cyan right)
	for spec: Array in [[Vector3(-4.2, 1.5, -3.2), UiTheme.ACCENT, 2.6], [Vector3(4.2, 1.3, -3.4), UiTheme.ACCENT_2, 2.4]]:
		var rim := OmniLight3D.new()
		rim.position = spec[0]
		rim.light_color = spec[1]
		rim.light_energy = float(spec[2])
		rim.omni_range = 8.5
		rim.omni_attenuation = 1.2
		viewport.add_child(rim)
	# turntable: dark glossy disc with a glowing cyan edge (the look of the 2D platform)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = TURNTABLE_R
	cyl.bottom_radius = TURNTABLE_R + 0.08
	cyl.height = 0.08
	cyl.radial_segments = 96
	disc.mesh = cyl
	disc.position.y = -0.04
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.035, 0.045, 0.1)
	dm.metallic = 0.5
	dm.roughness = 0.3
	disc.material_override = dm
	viewport.add_child(disc)
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = TURNTABLE_R - 0.05
	tor.outer_radius = TURNTABLE_R + 0.05
	tor.rings = 128
	tor.ring_segments = 8
	ring.mesh = tor
	ring.position.y = 0.0
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(0.0, 0.6, 0.78)   # below white: the AgX tonemapper (true car colours) pales bright cyan
	ring.material_override = rm
	viewport.add_child(ring)
	_pivot = Node3D.new()
	viewport.add_child(_pivot)
	_cam = Camera3D.new()
	_cam.fov = CAM_FOV_DEG
	_cam.near = 0.1
	_cam.far = 200.0
	viewport.add_child(_cam)
	_frame()


## Camera framing: the turntable fills FILL of the picture width (every car looks the same size as its sprite does).
func _frame() -> void:
	if _cam == null or viewport == null:
		return
	var height := 1.45
	if _car != null and is_instance_valid(_car):
		height = float(ModelDB.object_size(set_id).get("height_m", 1.45))
	var aspect := float(viewport.size.x) / maxf(float(viewport.size.y), 1.0)
	var dist := fit_distance(TURNTABLE_R + 0.1, aspect)
	var el := deg_to_rad(CAM_ELEVATION_DEG)
	var target := Vector3(0.0, height * 0.42, 0.0)
	_cam.position = target + Vector3(0.0, sin(el), cos(el)) * dist
	_cam.look_at(target, Vector3.UP)
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	# the turntable a little below the centre, where the 2D platform of the sprites lies (0.78 of the height)
	_cam.v_offset = 0.07 * dist * tan(deg_to_rad(CAM_FOV_DEG) * 0.5)


## Middle of a model's footprint (x, z of its manifest "aabb" [min x, y, z, max x, y, z]; y stays on the ground).
static func footprint_centre(model: Dictionary) -> Vector3:
	var a: Variant = model.get("aabb", [])
	if not a is Array or (a as Array).size() < 6:
		return Vector3.ZERO
	return Vector3((float(a[0]) + float(a[3])) * 0.5, 0.0, (float(a[2]) + float(a[5])) * 0.5)


## The studio look of the shared vehicle materials (RINT-B): a Modern race leaves its own on them (the race LOOK – the
## analytic sky of the race palette, e.g. a night sky in the car's paint), so the showroom sets its own every time it
## shows a car: ModernMaterials.STUDIO_LOOK (the one place of the vehicle LOOK, A-13). The next stage sets the race
## look again.
static func studio_look() -> void:
	ModernMaterials.shared().apply_look(ModernMaterials.STUDIO_LOOK)


## Studio values of the ce_* globals (dry daylight, no tunnel) – a Modern race may have left others.
static func studio_globals() -> void:
	ModernMaterials.set_global("ce_night", 0.0)
	ModernMaterials.set_global("ce_wet", 0.0)
	ModernMaterials.set_global("ce_snow", 0.0)
	ModernMaterials.set_global("ce_tunnel", 0.0)
	ModernMaterials.set_global("ce_sun_dir", Vector3(-0.45, 0.8, 0.4).normalized())
	ModernMaterials.set_global("ce_sun_color", ModernMaterials.light_value(Color(1.0, 0.97, 0.92), 1.05))
	ModernMaterials.set_global("ce_ambient", ModernMaterials.light_value(Color(0.46, 0.48, 0.6), 0.42))


## Shows the car of set `id` (a "showroom/<car>" set). True when it will be shown in 3D (now, or once its files are
## loaded – ready_to_show); false when the set does not get the 3D showroom (CarShowcase then draws the sprite).
## `dir`: direction of the slide-in (+1 from the right, −1 from the left).
func show_vehicle(id: String, dir: float = 1.0) -> bool:
	if not can_show(id):
		_clear_car()
		set_id = ""
		visible = false
		return false
	_dir = dir
	if id == set_id and (ready_to_show or _loading == id):
		return true
	_clear_car()
	set_id = id
	_requested = true
	ModelDB.request([id], [SHOW_LEVEL], self)   # threaded: the menu does not stall while ~100 k triangles load
	_loading = id
	_poll_loading()
	return true


## True while the files of the car being shown are still loading (CarShowcase leaves the place empty meanwhile).
func is_loading() -> bool:
	return _loading != ""


func _clear_car() -> void:
	if _car != null and is_instance_valid(_car):
		_car.free()
	_car = null
	ready_to_show = false
	_loading = ""
	visible = false


## Builds the car once its files are there (ModelDB.pending() == 0). A model that cannot be built (a file missing
## or broken) leaves the sprite: CarShowcase sees visible == false.
func _poll_loading() -> void:
	if _loading == "" or ModelDB.pending() > 0:
		return
	var id := _loading
	_loading = ""
	var car := ModelFactory.build(id, SHOW_LEVEL, ModernMaterials.shared())
	if car == null:
		push_warning("Showroom: Modell von %s lässt sich nicht bauen – das Sprite bleibt" % id)
		_redraw_parent()
		return
	studio_globals()
	studio_look()
	ModelFactory.set_lamps(car, Vector4(0.0, 0.0, 0.0, 0.0), Vector4(1.0, 0.0, 0.0, 0.0))   # headlights on
	car.position = -footprint_centre(ModelDB.resolve(id).get("model", {}))   # turns about the middle of its footprint
	_car = car
	_pivot.add_child(car)
	if not built_sets.has(id):
		built_sets.append(id)
	ready_to_show = true
	visible = true
	_anim = 0.0
	_yaw = START_YAW_DEG
	_frame()
	_redraw_parent()


func _redraw_parent() -> void:
	var p := get_parent()
	if p is CanvasItem:
		(p as CanvasItem).queue_redraw()


func _process(delta: float) -> void:
	if _loading != "":
		_poll_loading()
	if not visible or _car == null:
		return
	_anim = minf(1.0, _anim + delta * 4.0)
	if turn:
		_yaw = fposmod(_yaw + TURN_DEG_S * delta, 360.0)
	_pivot.rotation_degrees.y = _yaw
	var e := 1.0 - pow(1.0 - _anim, 3.0)
	_view.position.x = (1.0 - e) * SLIDE_PX * _dir
	_view.modulate.a = e
