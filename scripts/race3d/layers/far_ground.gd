extends Node3D
## Mode "Modern" (v0.8.0), dynamic layer "far_ground" (contract D16, amendment A-3; German docs:
## docs/renderer-modern-gelaende.md): the ground beyond the terrain ribbons.
##
## A disc of RADIUS_M around the camera at
##     far_y = min(lowest road of the loaded window - graphics.modern.terrain.far_ground_drop_m (4.0 m),
##                 lowest water surface of the loaded window - WATER_MARGIN_M (0.3 m))
## – below every road and every water surface that is loaded, so it can hide nothing (rule F7) and never covers the
## river under a high bridge (FIX-WASSER: the Elbe lies 9 m under the Köhlbrandbrücke, the plane at road - 4 m hid
## it) – and a rim at its edge that stands up to the camera's eye level, i.e. exactly up to the horizon row of the
## picture. Disc and rim show the ground the outer rings of the ribbons fade into (GroundLook.far_look,
## assets/shaders/modern/far_ground.gdshader), lit like level ground and fogged by depth. They close what the ribbons
## leave open: the ground beyond the outer rings, the 12 m gap at a medial axis and the hole at the centre of a tight
## bend.
## The loaded window = the rows from keep_behind_m behind the camera to min(load_path_m, visibility + two chunks)
## ahead: the road every 4th row (rows whose index is a multiple of 4, so the samples do not move with the camera),
## the water every row of a bridge (Track.bridges: only their rows carry TrackSegment.water; the terrain lays the
## rings of such a row on road height + water_level, TerrainProfile). Without deep water (deeper than the drop) the
## plane lies where it always did. The height follows its target by at most FOLLOW_SLOPE x the distance driven per
## frame – also when a bridge enters the window about a kilometre ahead; the first frame and a camera jump snap.
## The disc is cut into SECTORS nodes: their centres lie far from the camera, so the renderer draws them after the
## terrain in front of them (one big node around the camera would be drawn first and cost its fill everywhere).
## Below the silhouettes the picture reads as distant land, as in Arcade (RINT-B): the plane shows Arcade's colour of
## level ground with Arcade's fog of things on the ground (at most 70 % towards the fog), and the rim's top edge
## stands on the row of the backdrop's silhouettes (layer "backdrop" lift_rows: Arcade's crest rule) – the shader
## raises it with the depth along the axis of view, so the edge is straight on the screen.
## Sets the global ce_far_y. Duck-typed layer: setup(renderer), update(view, dt), rebased(shift), snapshot().
## --gfx-debug=far draws flat signal colours (cyan plane, yellow rim) for the terrain cover check.
## Owner: package terrain / props / far ground.

const SHADER := "res://assets/shaders/modern/far_ground.gdshader"
const RADIUS_M := 2400.0           ## inside the far plane of the camera (2,600 m), beyond every visibility
const SECTORS := 8
const STEPS := 4                   ## edges of a sector along the rim
const SAMPLE_STEP := 4             ## rows between two samples of the road height
const FOLLOW_SLOPE := 0.35         ## the plane's height changes by at most this much per metre driven
const SNAP_M := 150.0              ## a camera jump beyond this snaps the height
const GROUND_LAYERS := 2           ## render layer of ground meshes (builders/road.gd): no positional light reaches it
const WATER_MARGIN_M := 0.3        ## the plane stays at least this far below the lowest water surface of the window

var far_y := 0.0                   ## origin-relative height of the plane
var water_y := INF                 ## lowest water surface of the loaded window (origin-relative), INF without water
var material: ShaderMaterial

var _renderer: Node                ## untyped: packages talk to each other through the facade only
var _root: Node3D                  ## under renderer.world (origin-relative), moved every frame
var _drop := 4.0
var _load_m := 1500.0
var _behind_m := 150.0
var _chunk_m := 96.0
var _pattern_origin := Vector3.ZERO
var _look: Dictionary = {}
var _last_z := -1.0e12
var _target := 0.0
var _valid := false
var _key := Vector3i(-1, -1, -1)   ## camera row, visibility and first path row of the last _target
var _city: Dictionary = {}
var _styles: Dictionary = {}
var _rim_rows := -1.0              ## rows of the rim's top edge above the horizon row, as last given to the shader


func setup(renderer: Node) -> void:
	_renderer = renderer
	var cfg: Variant = renderer.get("cfg")
	var modern: Variant = ConfigLoader.lookup(cfg, "graphics.modern", {}) if cfg is Dictionary else {}
	var m: Dictionary = modern if modern is Dictionary else {}
	var terrain: Variant = m.get("terrain", {})
	if terrain is Dictionary:
		_drop = maxf(0.5, float((terrain as Dictionary).get("far_ground_drop_m", _drop)))
		var styles: Variant = (terrain as Dictionary).get("styles", {})
		_styles = styles if styles is Dictionary else {}
	_load_m = maxf(100.0, float(m.get("load_path_m", _load_m)))
	_behind_m = maxf(0.0, float(m.get("keep_behind_m", _behind_m)))
	var track: Track = renderer.get("track")
	if track != null:
		_chunk_m = float(maxi(4, int(m.get("chunk_segments", 32)))) * track.seg_len
		_city = GroundLook.city_info(track)
	ModernMaterials.ensure_globals()
	material = ShaderMaterial.new()
	material.shader = load(SHADER) as Shader
	material.set_shader_parameter("ground_noise", GroundLook.noise_texture())
	var proj: RoadProjection = renderer.get("proj")
	if proj != null:
		material.set_shader_parameter("focal_px", proj.focal)
	var flags: Variant = renderer.get("debug_flags")
	if flags is Array and (flags as Array).has("far"):
		material.set_shader_parameter("debug_flat", 1.0)
	if renderer.has_method(&"add_pool_material"):
		renderer.call(&"add_pool_material", material)      # light pools and the low beam like the terrain
	_root = Node3D.new()
	_root.name = "FarGround"
	_root.visible = false
	var mesh := sector_mesh()
	for i in SECTORS:
		var mi := MeshInstance3D.new()
		mi.name = "Sector%d" % i
		mi.mesh = mesh
		mi.material_override = material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.layers = GROUND_LAYERS
		mi.rotation.y = TAU * float(i) / float(SECTORS)
		_root.add_child(mi)
	var world: Variant = renderer.get("world")
	if world is Node3D:
		(world as Node3D).add_child(_root)
	else:
		add_child(_root)


## One sector of the disc (in the XZ plane, y = 0) with its part of the rim (y = 0 .. 1; the node is scaled in y to
## the rim's height). UV.x = 0 on the disc, 1 on the rim.
static func sector_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var span := TAU / float(SECTORS)
	verts.append(Vector3.ZERO)
	uvs.append(Vector2.ZERO)
	norms.append(Vector3.UP)
	for s in STEPS + 1:
		var a := span * float(s) / float(STEPS)
		verts.append(Vector3(cos(a) * RADIUS_M, 0.0, sin(a) * RADIUS_M))
		uvs.append(Vector2.ZERO)
		norms.append(Vector3.UP)
	for s in STEPS:
		idx.append_array(PackedInt32Array([0, s + 2, s + 1]))
	var rim0 := verts.size()
	for s in STEPS + 1:
		var a := span * float(s) / float(STEPS)
		for q in 2:
			verts.append(Vector3(cos(a) * RADIUS_M, float(q), sin(a) * RADIUS_M))
			uvs.append(Vector2(1.0, float(q)))
			norms.append(Vector3.UP)
	for s in STEPS:
		var a := rim0 + s * 2
		idx.append_array(PackedInt32Array([a, a + 1, a + 3, a, a + 3, a + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# the node is scaled in y by the rim's height: bounds for any height the roads of a stage can give, and for the
	# rim raised to the silhouettes' row by the shader (at most 120 rows: about 400 m at the rim)
	mesh.custom_aabb = AABB(Vector3(-RADIUS_M, -1.0, -RADIUS_M), Vector3(2.0 * RADIUS_M, 400.0, 2.0 * RADIUS_M))
	return mesh


func update(view: Dictionary, _dt: float) -> void:
	if _renderer == null or _root == null:
		return
	var path: RoadPath3D = _renderer.get("path")
	var cam: Camera3D = _renderer.get("camera")
	var track: Track = _renderer.get("track")
	if path == null or not path.is_ready() or cam == null or track == null:
		return
	var cam_z := float(view.get("camera_z", 0.0))
	var vis := float(view.get("visibility_m", 900.0))
	var key := Vector3i(int(floor(cam_z / path.seg_len)), int(vis), path.first)
	if key != _key:
		# the samples sit on fixed rows: nothing changes until the camera reaches the next row
		_key = key
		_target = target_height(path, track, cam_z, vis)
	var moved := absf(cam_z - _last_z)
	if not _valid or moved > SNAP_M:
		far_y = _target
		_valid = true
	else:
		far_y = move_toward(far_y, _target, maxf(moved * FOLLOW_SLOPE, 0.0))
	_last_z = cam_z
	var eye := cam.global_position if cam.is_inside_tree() else cam.position
	_root.position = Vector3(eye.x, far_y, eye.z)
	_root.scale = Vector3(1.0, maxf(eye.y - far_y, 0.5), 1.0)
	_root.visible = true
	ModernMaterials.set_global("ce_far_y", far_y)
	# the rim reaches up to the row the backdrop's silhouettes stand on (the backdrop layer is updated first)
	var rows := 0.0
	var bd: Variant = _renderer.call(&"layer", "backdrop") if _renderer.has_method(&"layer") else null
	if bd is Object and is_instance_valid(bd):
		var lift: Variant = (bd as Object).get("lift_rows")
		rows = maxf(float(lift), 0.0) if lift != null else 0.0
	if absf(rows - _rim_rows) > 0.01:
		_rim_rows = rows
		material.set_shader_parameter("rim_rows", rows)
	var look := GroundLook.far_look(track, _renderer.get("scenery_db"), cam_z, _city, _styles)
	if look != _look:
		_look = look
		var c: Color = look["color"]
		var a: Color = look["accent"]
		material.set_shader_parameter("far_color", Vector3(c.r, c.g, c.b))
		material.set_shader_parameter("far_accent", Vector3(a.r, a.g, a.b))
		material.set_shader_parameter("far_amount", float(look["amount"]))
		material.set_shader_parameter("far_nature", float(look["nature"]))


## Height the plane follows (origin-relative) with the camera at road position cam_z: far_ground_drop_m below the
## lowest road of the loaded window and WATER_MARGIN_M below its lowest water surface, whichever is lower (sets
## water_y).
func target_height(path: RoadPath3D, track: Track, cam_z: float, visibility_m: float) -> float:
	water_y = lowest_water(path, track, cam_z, visibility_m)
	return minf(lowest_road(path, cam_z, visibility_m) - _drop, water_y - WATER_MARGIN_M)


## Rows of the loaded window around road position cam_z, Vector2i(first, last): from keep_behind_m and one chunk
## behind the camera to min(load_path_m, visibility + two chunks) ahead, inside the integrated path.
func window_rows(path: RoadPath3D, cam_z: float, visibility_m: float) -> Vector2i:
	var seg := path.seg_len
	var ahead := minf(_load_m, visibility_m + 2.0 * _chunk_m)
	var k0 := maxi(path.first, int(floor((cam_z - _behind_m - _chunk_m) / seg)))
	var k1 := mini(path.last(), int(ceil((cam_z + ahead) / seg)))
	return Vector2i(k0, k1)


## Lowest water surface (origin-relative) of the loaded window: every row of every bridge of the track inside the
## window that carries water, at the height the terrain lays its rings there (road height + water_level,
## TerrainProfile). INF when no water row is in the window (most of a stage: then far_y is the old rule exactly).
func lowest_water(path: RoadPath3D, track: Track, cam_z: float, visibility_m: float) -> float:
	var lo := INF
	if track == null:
		return lo
	var w := window_rows(path, cam_z, visibility_m)
	var seg := path.seg_len
	for br: Dictionary in track.bridges:
		var a := maxi(w.x, int(floor(float(br.get("z0", 0.0)) / seg)))
		var b := mini(w.y, int(ceil(float(br.get("z1", 0.0)) / seg)))
		for k in range(a, b + 1):
			var s := track.get_segment(k)
			if s != null and s.index == k and s.water:
				lo = minf(lo, path.height(k) + minf(s.water_level, 0.0))
	return lo


## Lowest road height (origin-relative) of the loaded window around road position cam_z: every SAMPLE_STEP-th row
## from keep_behind_m behind the camera to min(load_path_m, visibility + two chunks) ahead, inside the integrated path.
func lowest_road(path: RoadPath3D, cam_z: float, visibility_m: float) -> float:
	var w := window_rows(path, cam_z, visibility_m)
	var k0 := w.x
	var k1 := w.y
	k0 = maxi(path.first, (k0 / SAMPLE_STEP) * SAMPLE_STEP)
	var lo := INF
	var k := k0
	while k <= k1:
		lo = minf(lo, path.height(k))
		k += SAMPLE_STEP
	if lo == INF:
		lo = path.height(clampi(int(cam_z / path.seg_len), path.first, path.last()))
	return lo


func rebased(shift: Vector3) -> void:
	_pattern_origin -= shift
	if material != null:
		material.set_shader_parameter("pattern_origin", _pattern_origin)


func snapshot() -> Dictionary:
	return {"far_ground": {"y": snappedf(far_y, 0.001), "target": snappedf(_target, 0.001), "drop": _drop, "radius": RADIUS_M,
		"sectors": SECTORS, "visible": _root != null and _root.visible, "rim_rows": snappedf(maxf(_rim_rows, 0.0), 0.01),
		"water_y": snappedf(water_y, 0.001) if water_y < INF else null}}


func _exit_tree() -> void:
	if is_instance_valid(_root) and _root.get_parent() != self:
		_root.queue_free()      # it hangs under renderer.world, not under this layer
