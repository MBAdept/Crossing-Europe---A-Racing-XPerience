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
##
## RIVERS (package R5, lead decision of wave 3 – QA-WASSER / FIX-WASSER-R: beyond the ribbons the plane showed a strip
## of meadow at the horizon instead of Arcade's far shore, the Kiel Canal read like a lake). For every bridge of the
## loaded window (Track.bridges) the layer lays, anchored on the path at the bridge and freed when it leaves the window:
##   far water  the river beyond the ribbons: a band between the two lines across the road where the bridge's water
##              meets its banks (z0 + slope, z1 - slope), out to RIVER_REACH_M on both sides (on the inside of a curving
##              bridge at most 0.8 × its radius; never over a lower part of the loaded road), FAR_WATER_BELOW under the
##              water of the bridge builder, in the same material (assets/shaders/modern/water.gdshader, the shared
##              class "water" of builders/bridge.gd);
##   far land   while the plane lies below deep water (a bridge deeper than the drop): land at the plane's old height
##              (lowest road of the window - far_ground_drop_m: below every loaded road, F7) everywhere but the bands
##              of the deep bridges – before the first, between two, after the last – in a ShaderMaterial of its own on
##              far_ground.gdshader with the plane's parameters: the same distant land as ever, the plane underneath
##              keeps the ZS1 rule (at most lowest water - 0.3 m; test_far_ground_water, render check K1);
##   far banks  between them along both bank lines: embankments from the land down to the water in the bridge's bank
##              colour (grass) or its quay colour (stone), in the water material.
## The geometry is built once per bridge in origin-relative world coordinates and moved by rebased(); only its heights
## follow the window (land and banks by FOLLOW_SLOPE like the plane).
## Owner: package terrain / props / far ground; the rivers: package R5.

const SHADER := "res://assets/shaders/modern/far_ground.gdshader"
const RADIUS_M := 2400.0           ## inside the far plane of the camera (2,600 m), beyond every visibility
const SECTORS := 8
const STEPS := 4                   ## edges of a sector along the rim
const SAMPLE_STEP := 4             ## rows between two samples of the road height
const FOLLOW_SLOPE := 0.35         ## the plane's height changes by at most this much per metre driven
const SNAP_M := 150.0              ## a camera jump beyond this snaps the height
const GROUND_LAYERS := 2           ## render layer of ground meshes (builders/road.gd): no positional light reaches it
const WATER_MARGIN_M := 0.3        ## the plane stays at least this far below the lowest water surface of the window
const RIVER_REACH_M := 3000.0      ## the far water and the far land reach this far from the bridge (beyond the far plane)
const RIVER_MIN_REACH_M := 300.0
const RIVER_CLEAR_M := 60.0        ## the far water stops this far before a lower part of the loaded road
const BRIDGE_WATER_LIFT := 0.15    ## builders/bridge.gd WATER_LIFT: its water above the terrain's water rows …
const FAR_WATER_BELOW := 0.05      ## … and the far water this much lower (the near water wins where both lie)
const DEEP_MARGIN_M := 0.05        ## a bridge is "deep" when its water lies below the plane's old height
const K_GRASS := 3.0               ## kinds of water.gdshader (builders/bridge.gd)
const K_STONE := 1.0

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
var land_y := INF                  ## height of the far land (origin-relative), INF without a deep bridge in the window
var _rivers: Dictionary = {}       ## bridge index -> {"node": Node3D, "water", "banks": MeshInstance3D, "h_w", "deep", …}
var _land: MeshInstance3D          ## far land (only while a deep bridge is in the window)
var _land_material: ShaderMaterial
var _land_sig := ""
var _land_target := 0.0
var _shift := Vector3.ZERO         ## sum of the rebase shifts since the river geometry was built (per node: own offset)


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
		if _land_material != null:
			_copy_land_parameters()
	update_rivers(path, track, cam_z, vis, moved)


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


# --- rivers (package R5) -----------------------------------------------------------------------------------------

## The bridges of the loaded window (indices into Track.bridges, sorted by road position).
func window_bridges(path: RoadPath3D, track: Track, cam_z: float, visibility_m: float) -> Array[int]:
	var out: Array[int] = []
	if track == null:
		return out
	var w := window_rows(path, cam_z, visibility_m)
	var seg := path.seg_len
	for bi in track.bridges.size():
		var br: Dictionary = track.bridges[bi]
		var a := int(floor(float(br.get("z0", 0.0)) / seg))
		var b := int(ceil(float(br.get("z1", 0.0)) / seg))
		if b >= w.x and a <= w.y and a >= path.first and b <= path.last():
			out.append(bi)
	return out


## Every frame: river geometry for the bridges of the window (built once each, freed when they leave), the far land
## while one of them lies deeper than the plane's old height, the heights of land and banks.
func update_rivers(path: RoadPath3D, track: Track, cam_z: float, vis: float, moved: float) -> void:
	var list := window_bridges(path, track, cam_z, vis)
	for bi: int in _rivers.keys():
		if not list.has(bi):
			var r: Dictionary = _rivers[bi]
			if is_instance_valid(r["node"]):
				(r["node"] as Node).queue_free()
			_rivers.erase(bi)
	if list.is_empty():
		_set_land([], 0.0)
		return
	var bridge_b: Variant = _renderer.call(&"builder", "bridge") if _renderer.has_method(&"builder") else null
	var land_old := lowest_road(path, cam_z, vis) - _drop
	var deep: Array = []
	for bi: int in list:
		if not _rivers.has(bi):
			var r := build_river(path, track, bi, bridge_b)
			if r.is_empty():
				continue
			_rivers[bi] = r
		var rv: Dictionary = _rivers[bi]
		if float(rv["h_w"]) < land_old - DEEP_MARGIN_M:
			deep.append(bi)
	# the land follows its target like the plane (no jump when a part of the road enters the window)
	if land_y == INF or moved > SNAP_M:
		_land_target = land_old
		land_y = land_old
	else:
		_land_target = land_old
		land_y = move_toward(land_y, _land_target, maxf(moved * FOLLOW_SLOPE, 0.0))
	_set_land(deep, land_y)
	for bi: int in _rivers:
		var rv: Dictionary = _rivers[bi]
		var banks: Variant = rv.get("banks")
		var is_deep := deep.has(bi)
		if banks is MeshInstance3D and is_instance_valid(banks):
			var h := land_y - float(rv["h_w"])
			(banks as MeshInstance3D).visible = is_deep and h > 0.2
			(banks as MeshInstance3D).scale = Vector3(1.0, maxf(h, 0.01), 1.0)
			(banks as MeshInstance3D).position.y = float(rv["h_w"]) - float(rv["y0"])


## The geometry of the river of bridge bi (origin-relative, as of now): {"node", "water", "banks", "h_w", "y0", …};
## {} when the bridge's rows are not in the path or no water material is to be had.
func build_river(path: RoadPath3D, track: Track, bi: int, bridge_b: Variant) -> Dictionary:
	var br: Dictionary = track.bridges[bi]
	var seg := path.seg_len
	var z0 := float(br.get("z0", 0.0))
	var z1 := float(br.get("z1", 0.0))
	var slope := float(br.get("slope", seg))
	var zw0 := z0 + slope
	var zw1 := maxf(z1 - slope, zw0 + 0.5)
	var k0 := int(floor(z0 / seg))
	var k1 := int(ceil(z1 / seg))
	if k0 < path.first or k1 > path.last():
		return {}
	# the lowest water surface of the bridge, as the terrain lays it (road height + water_level)
	var lo := INF
	for k in range(k0, k1 + 1):
		var s := track.get_segment(k)
		if s != null and s.index == k and s.water:
			lo = minf(lo, path.height(k) + minf(s.water_level, 0.0))
	if lo == INF:
		lo = path.height(k0) - float(br.get("depth", 3.0))
	var h_w := lo + BRIDGE_WATER_LIFT - FAR_WATER_BELOW
	var mats: Variant = _renderer.get("materials")
	var water_mat: Variant = null
	if bridge_b is Object and (bridge_b as Object).has_method(&"get_water_material"):
		water_mat = (bridge_b as Object).call(&"get_water_material", mats if mats is ModernMaterials else null)
	elif mats is ModernMaterials:
		water_mat = (mats as ModernMaterials).material("water")
	if not (water_mat is ShaderMaterial):
		return {}
	var info: Dictionary = {}
	if bridge_b is Object and (bridge_b as Object).has_method(&"bridge_info"):
		var seg0 := track.get_segment(k0 + 1)
		var scen: Variant = (_renderer.get("scenery_db") as Dictionary).get(seg0.scenery, {}) if _renderer.get("scenery_db") is Dictionary else {}
		info = (bridge_b as Object).call(&"bridge_info", br, scen, seg0.city)
	var water_col: Color = info.get("water", Color(str(CityData.WATER_COLOR.get(str(br.get("type", "river")), "#4b6878"))))
	var bank_col: Color = info.get("bank", RoadRenderer.QUAY.get(str(br.get("type", "river")), RoadRenderer.QUAY["river"]))
	var bank_kind := K_GRASS if str(br.get("bank", "")) != "" else K_STONE
	# the band: the lines across the road at the water's two ends; reach on each side
	var p0 := path.world(zw0, 0.0, 0.0)
	var p1 := path.world(zw1, 0.0, 0.0)
	var a0 := path.heading_at(zw0)
	var a1 := path.heading_at(zw1)
	var r0 := RoadPath3D.right_of(a0)
	var r1 := RoadPath3D.right_of(a1)
	var reach := river_reach(path, track, k0, k1, (p0 + p1) * 0.5, RoadPath3D.right_of((a0 + a1) * 0.5),
		RoadPath3D.fwd_of((a0 + a1) * 0.5), (zw1 - zw0) * 0.5, lo, a1 - a0, zw1 - zw0)
	var y0 := lo
	var node := Node3D.new()
	node.name = "River%d" % bi
	# far water: one strip per side from the centre line out to the reach
	var wv := PackedVector3Array()
	var wn := PackedVector3Array()
	var wc := PackedColorArray()
	var wuv := PackedVector2Array()
	var wuv2 := PackedVector2Array()
	var wc0 := PackedFloat32Array()
	var widx := PackedInt32Array()
	for side: int in [-1, 1]:
		var s_far := float(side) * float(reach[0 if side < 0 else 1])
		var pts := [p0, p1, p1 + r1 * s_far, p0 + r0 * s_far]
		var uvs := [Vector2(0.0, zw0), Vector2(0.0, zw1), Vector2(s_far, zw1), Vector2(s_far, zw0)]
		var o := wv.size()
		for q in 4:
			var p: Vector3 = pts[q]
			wv.append(Vector3(p.x, 0.0, p.z))
			wn.append(Vector3.UP)
			wc.append(water_col)
			wuv.append(uvs[q])
			wuv2.append(Vector2(0.0, 100.0))
			wc0.append_array(PackedFloat32Array([r0.x, r0.z, 0.0, 0.0]))
		# front faces clockwise seen from above
		var nn := (wv[o + 1] - wv[o]).cross(wv[o + 3] - wv[o])
		if nn.y >= 0.0:
			widx.append_array(PackedInt32Array([o, o + 3, o + 2, o, o + 2, o + 1]))
		else:
			widx.append_array(PackedInt32Array([o, o + 1, o + 2, o, o + 2, o + 3]))
	var water := _mesh_node("FarWater", wv, wn, wc, wuv, wuv2, wc0, widx, water_mat)
	water.position = Vector3(0.0, h_w - y0, 0.0)
	node.add_child(water)
	# far banks: from the land (y = 1, scaled to the land's height) down to the water (y = 0) along both bank lines
	var bv := PackedVector3Array()
	var bn := PackedVector3Array()
	var bc := PackedColorArray()
	var buv := PackedVector2Array()
	var buv2 := PackedVector2Array()
	var bc0 := PackedFloat32Array()
	var bidx := PackedInt32Array()
	var top0 := path.world(z0, 0.0, 0.0)
	var top1 := path.world(z1, 0.0, 0.0)
	var rt0 := RoadPath3D.right_of(path.heading_at(z0))
	var rt1 := RoadPath3D.right_of(path.heading_at(z1))
	var bank_h := maxf(0.5, float(br.get("depth", 3.0)))
	for end: int in [0, 1]:
		var top := top0 if end == 0 else top1
		var rt := rt0 if end == 0 else rt1
		var toe := p0 if end == 0 else p1
		var rw := r0 if end == 0 else r1
		for side: int in [-1, 1]:
			var s_far := float(side) * float(reach[0 if side < 0 else 1])
			var pts := [top, top + rt * s_far, toe + rw * s_far, toe]
			var ys := [1.0, 1.0, 0.0, 0.0]
			var o := bv.size()
			for q in 4:
				var p: Vector3 = pts[q]
				bv.append(Vector3(p.x, ys[q], p.z))
				bn.append(Vector3.UP)
				bc.append(bank_col)
				buv.append(Vector2(s_far if q == 1 or q == 2 else 0.0, float(ys[q]) * bank_h))
				buv2.append(Vector2(bank_kind, float(ys[q]) * bank_h))
				bc0.append_array(PackedFloat32Array([rw.x, rw.z, 0.0, 0.0]))
			# the face looks across the river (towards the other bank): its normal points from the top towards the toe
			var toward := (toe - top)
			toward.y = 0.0
			var nn := (bv[o + 1] - bv[o]).cross(bv[o + 3] - bv[o])
			if nn.dot(Vector3(toward.x, 0.5, toward.z)) >= 0.0:
				bidx.append_array(PackedInt32Array([o, o + 3, o + 2, o, o + 2, o + 1]))
			else:
				bidx.append_array(PackedInt32Array([o, o + 1, o + 2, o, o + 2, o + 3]))
	var banks := _mesh_node("FarBanks", bv, bn, bc, buv, buv2, bc0, bidx, water_mat)
	banks.visible = false
	node.add_child(banks)
	node.position = Vector3(0.0, y0, 0.0)
	var world: Variant = _renderer.get("world")
	if world is Node3D:
		(world as Node3D).add_child(node)
	else:
		add_child(node)
	return {"node": node, "water": water, "banks": banks, "h_w": h_w, "y0": y0, "reach": reach, "z0": z0, "z1": z1,
		"p0": p0, "p1": p1, "r0": r0, "r1": r1, "top0": top0, "top1": top1, "rt0": rt0, "rt1": rt1}


## How far the far water may reach to the left and right of a bridge ([left, right], metres): RIVER_REACH_M, on the
## inside of a curving bridge at most 0.8 × its radius, and never over a part of the loaded road (outside the bridge
## and its approaches) that lies lower than the water + 2 m: it stops RIVER_CLEAR_M before it.
func river_reach(path: RoadPath3D, track: Track, k0: int, k1: int, centre: Vector3, right: Vector3, fwd: Vector3, half: float,
		water_h: float, turn: float, length: float) -> Array:
	var reach := [RIVER_REACH_M, RIVER_REACH_M]
	if absf(turn) > 1.0e-4:
		var radius := length / absf(turn)
		var inside := 1 if turn > 0.0 else 0          # a right turn has its centre on the right
		reach[inside] = minf(float(reach[inside]), maxf(RIVER_MIN_REACH_M, 0.8 * radius))
	var k := path.first
	var margin := int(ceil(250.0 / path.seg_len))
	while k <= path.last():
		if k >= k0 - margin and k <= k1 + margin:
			k += 4
			continue
		if path.height(k) < water_h + 2.0:
			var p := path.point(k) - centre
			var t := p.dot(fwd)
			if absf(t) < half + 40.0:
				var s := p.dot(right)
				var side := 0 if s < 0.0 else 1
				reach[side] = minf(float(reach[side]), maxf(RIVER_MIN_REACH_M, absf(s) - RIVER_CLEAR_M))
		k += 4
	return reach


## The far land: one strip before the first deep bridge, one between each two, one after the last – everywhere but
## the bands of the deep bridges – at height y (origin-relative); none without a deep bridge.
func _set_land(deep: Array, y: float) -> void:
	var sig := ""
	for bi: int in deep:
		sig += "%d," % bi
	if sig == "":
		if _land != null and is_instance_valid(_land):
			_land.visible = false
		land_y = INF if deep.is_empty() else land_y
		return
	if sig != _land_sig or _land == null or not is_instance_valid(_land):
		_land_sig = sig
		if _land != null and is_instance_valid(_land):
			_land.queue_free()
		_land = _build_land(deep)
	if _land != null:
		_land.visible = true
		_land.position.y = y


func _build_land(deep: Array) -> MeshInstance3D:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var idx := PackedInt32Array()
	var sorted: Array = deep.duplicate()
	sorted.sort_custom(func(a: int, b: int) -> bool: return float((_rivers[a] as Dictionary)["z0"]) < float((_rivers[b] as Dictionary)["z0"]))
	var lines: Array = []         # [point, right, forward-sign] of every land border, in order along the road
	for bi: int in sorted:
		var rv: Dictionary = _rivers[bi]
		lines.append([rv["top0"], rv["rt0"]])
		lines.append([rv["top1"], rv["rt1"]])
	var reach := RIVER_REACH_M
	# before the first bank line: back along the road
	var first: Array = lines[0]
	var back := RoadPath3D.fwd_of(atan2((first[1] as Vector3).z, (first[1] as Vector3).x)) * -reach
	_land_quad(v, n, idx, first[0], first[1], (first[0] as Vector3) + back, first[1], reach)
	# between two deep bridges
	for q in range(1, lines.size() - 1, 2):
		_land_quad(v, n, idx, lines[q][0], lines[q][1], lines[q + 1][0], lines[q + 1][1], reach)
	# after the last bank line: forward
	var last: Array = lines[lines.size() - 1]
	var ahead := RoadPath3D.fwd_of(atan2((last[1] as Vector3).z, (last[1] as Vector3).x)) * reach
	_land_quad(v, n, idx, last[0], last[1], (last[0] as Vector3) + ahead, last[1], reach)
	var c := PackedColorArray()
	c.resize(v.size())
	c.fill(Color.WHITE)
	var uv := PackedVector2Array()
	uv.resize(v.size())
	uv.fill(Vector2.ZERO)
	if _land_material == null:
		_land_material = ShaderMaterial.new()
		_land_material.shader = material.shader
		_copy_land_parameters()
	var mi := _mesh_node("FarLand", v, n, c, uv, PackedVector2Array(), PackedFloat32Array(), idx, _land_material)
	mi.layers = GROUND_LAYERS
	var world: Variant = _renderer.get("world")
	if world is Node3D:
		(world as Node3D).add_child(mi)
	else:
		add_child(mi)
	return mi


## A land quad between the line through a (direction ra) and the line through b (direction rb), both reaching `reach`
## to either side (heights 0: the node carries the land's height).
static func _land_quad(v: PackedVector3Array, n: PackedVector3Array, idx: PackedInt32Array, a: Vector3, ra: Vector3, b: Vector3, rb: Vector3,
		reach: float) -> void:
	var pts := [a - ra * reach, a + ra * reach, b + rb * reach, b - rb * reach]
	var o := v.size()
	for q in 4:
		var p: Vector3 = pts[q]
		v.append(Vector3(p.x, 0.0, p.z))
		n.append(Vector3.UP)
	var nn := (v[o + 1] - v[o]).cross(v[o + 3] - v[o])
	if nn.y >= 0.0:
		idx.append_array(PackedInt32Array([o, o + 3, o + 2, o, o + 2, o + 1]))
	else:
		idx.append_array(PackedInt32Array([o, o + 1, o + 2, o, o + 2, o + 3]))


## The far land's material: far_ground.gdshader with the plane's parameters (never the debug colours: the terrain
## cover check counts only the plane itself).
func _copy_land_parameters() -> void:
	for p: String in ["far_color", "far_accent", "far_amount", "far_nature", "ground_noise", "pattern_origin", "focal_px"]:
		_land_material.set_shader_parameter(p, material.get_shader_parameter(p))
	_land_material.set_shader_parameter("debug_flat", 0.0)


static func _mesh_node(node_name: String, v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, uv: PackedVector2Array,
		uv2: PackedVector2Array, c0: PackedFloat32Array, idx: PackedInt32Array, mat: Material) -> MeshInstance3D:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_TEX_UV] = uv
	var flags := 0
	if not uv2.is_empty():
		arr[Mesh.ARRAY_TEX_UV2] = uv2
	if not c0.is_empty():
		arr[Mesh.ARRAY_CUSTOM0] = c0
		flags = Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = GROUND_LAYERS
	# the far geometry reaches kilometres: bounds for the culling that hold for every height it is moved to
	var aabb := mesh.get_aabb()
	mesh.custom_aabb = AABB(aabb.position - Vector3(0.0, 50.0, 0.0), aabb.size + Vector3(0.0, 100.0, 0.0))
	return mi


func rebased(shift: Vector3) -> void:
	_pattern_origin -= shift
	if material != null:
		material.set_shader_parameter("pattern_origin", _pattern_origin)
	if _land_material != null:
		_land_material.set_shader_parameter("pattern_origin", _pattern_origin)
	# the river geometry is origin-relative: it moves with the shift (positions + shift, heights unchanged)
	for bi: int in _rivers:
		var rv: Dictionary = _rivers[bi]
		if is_instance_valid(rv["node"]):
			(rv["node"] as Node3D).position += Vector3(shift.x, 0.0, shift.z)
		for key: String in ["p0", "p1", "top0", "top1"]:
			rv[key] = (rv[key] as Vector3) + Vector3(shift.x, 0.0, shift.z)
	if _land != null and is_instance_valid(_land):
		_land.position += Vector3(shift.x, 0.0, shift.z)


func snapshot() -> Dictionary:
	var rivers: Array = []
	for bi: int in _rivers:
		var rv: Dictionary = _rivers[bi]
		var banks: Variant = rv.get("banks")
		rivers.append({"bridge": bi, "h_w": snappedf(float(rv["h_w"]), 0.001), "reach": rv["reach"],
			"banks": banks is MeshInstance3D and is_instance_valid(banks) and (banks as MeshInstance3D).visible})
	return {"far_ground": {"y": snappedf(far_y, 0.001), "target": snappedf(_target, 0.001), "drop": _drop, "radius": RADIUS_M,
		"sectors": SECTORS, "visible": _root != null and _root.visible, "rim_rows": snappedf(maxf(_rim_rows, 0.0), 0.01),
		"water_y": snappedf(water_y, 0.001) if water_y < INF else null, "rivers": rivers,
		"land_y": snappedf(land_y, 0.001) if land_y < INF else null,
		"land": _land != null and is_instance_valid(_land) and _land.visible}}


func _exit_tree() -> void:
	if is_instance_valid(_root) and _root.get_parent() != self:
		_root.queue_free()      # it hangs under renderer.world, not under this layer
	for bi: int in _rivers:
		var node: Variant = (_rivers[bi] as Dictionary).get("node")
		if is_instance_valid(node) and (node as Node).get_parent() != self:
			(node as Node).queue_free()
	_rivers.clear()
	if _land != null and is_instance_valid(_land) and _land.get_parent() != self:
		_land.queue_free()
