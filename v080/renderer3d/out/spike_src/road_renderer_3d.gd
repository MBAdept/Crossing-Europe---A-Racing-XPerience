class_name RoadRenderer3DSpike
extends Node3D
## Spike (v0.8.0 design study): minimal real-3D renderer behind the RoadRenderer interface
## (setup(track, proj, cfg, scenery_db), render(view), perf_stats()). True world-space road built from the real Track
## in chunks streamed around the camera, chase camera with the arcade projection (frustum with the horizon at
## render.horizon_y_frac), sun with shadows, sky, depth fog from view.visibility_m, boxes as vehicles driven by the
## view's car items, optional billboards of the existing prop sprites.

const CHUNK_SEGS := 32                 ## 96 m
const NEAR := 0.5
const FAR := 2600.0

var track: Track
var proj: RoadProjection
var cfg: Dictionary = {}
var scenery_db: Dictionary = {}
var view: Dictionary = {}
var path := RoadPath3D.new()
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var look_gain := 0.6                   ## camera yaw = gain x bearing of the centreline look_m ahead
var look_m := 100.0
var props_on := true
var shadows_on := true
var build_per_frame := 1

var _chunks: Dictionary = {}           ## chunk index -> MeshInstance3D
var _chunk_root: Node3D
var _car_root: Node3D
var _cars: Dictionary = {}             ## vehicle id -> Node3D
var _car_seen: Dictionary = {}
var _mat: StandardMaterial3D
var _car_mats: Dictionary = {}
var _light_mat: StandardMaterial3D
var _brake_mat: StandardMaterial3D
var _base: MeshInstance3D
var _base_mat: StandardMaterial3D
var _builder := RoadChunk3D.new()
var _prop_mats: Dictionary = {}        ## sprite set id -> [material, cell size m, anchor]
var _headlight: SpotLight3D
var _frames := 0
var _sum_us := 0
var _max_us := 0
var _build_us: Array[int] = []
var _build_quads: Array[int] = []
var _first_build_ms := 0.0
var _seg_len := 3.0
var _curve_r1 := 120.0
var _probe_done := false
var _backdrop: Node2D                  ## arcade backdrop as the 3D background (--backdrop3d)


func setup(t: Track, p: RoadProjection, config: Dictionary, scenery: Dictionary) -> void:
	track = t
	proj = p
	cfg = config
	scenery_db = scenery
	_seg_len = t.seg_len
	_curve_r1 = float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
	look_gain = CliArgs.get_float("look-gain", look_gain)
	look_m = CliArgs.get_float("look-m", look_m)
	props_on = not CliArgs.has("no-props3d")
	shadows_on = not CliArgs.has("no-shadows")
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 1.0
	env.fog_sky_affect = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	if CliArgs.has("glow3d"):
		env.glow_enabled = true
		env.glow_intensity = 0.6
		env.glow_bloom = 0.05
	if CliArgs.has("backdrop3d"):
		var layer := CanvasLayer.new()
		layer.layer = -10
		add_child(layer)
		_backdrop = load("res://spike/backdrop_layer.gd").new()
		layer.add_child(_backdrop)
		_backdrop.call("setup", proj)
		env.background_mode = Environment.BG_CANVAS
		env.background_canvas_max_layer = -10
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = shadows_on
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)
	cam = Camera3D.new()
	# arcade projection: focal px at the logical width, horizon at horizon_y (frustum shifted down)
	var size := NEAR * proj.screen.y / proj.focal
	cam.set_frustum(size, Vector2(0.0, size * (proj.horizon_y / proj.screen.y - 0.5)), NEAR, FAR)
	add_child(cam)
	cam.make_current()
	_chunk_root = Node3D.new()
	add_child(_chunk_root)
	_car_root = Node3D.new()
	add_child(_car_root)
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.vertex_color_is_srgb = true
	_mat.roughness = 0.95
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_light_mat = _emissive(Color(1.0, 0.12, 0.05), 1.5)
	_brake_mat = _emissive(Color(1.0, 0.1, 0.04), 5.0)
	# base plane far below the road (valley floor / haze)
	_base = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6000.0, 6000.0)
	_base.mesh = pm
	_base_mat = StandardMaterial3D.new()
	_base_mat.roughness = 1.0
	_base.material_override = _base_mat
	_base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_base)
	_headlight = SpotLight3D.new()
	_headlight.spot_range = 90.0
	_headlight.spot_angle = 28.0
	_headlight.light_energy = 0.0
	_headlight.light_color = Color(1.0, 0.95, 0.82)
	_headlight.shadow_enabled = false
	add_child(_headlight)


func _emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c * 0.4
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


## Benchmark (--bench3d=<chunks>): builds chunks one after the other along the stage from the camera on, like a drive
## would, and prints the cost of the track generation, the mesh and the prop instances per chunk.
func _bench(n: int) -> void:
	var cam_z := float(view["camera_z"])
	var cam_seg := int(floor(cam_z / _seg_len))
	if path.track == null:
		path.setup(track, maxi(0, cam_seg - 2 * CHUNK_SEGS), _curve_r1)
	var c0 := int(floor(float(cam_seg) / float(CHUNK_SEGS))) + 1
	var gen: Array[int] = []
	var mesh: Array[int] = []
	var props: Array[int] = []
	var quads := 0
	var inst := 0
	var b := RoadChunk3D.new()
	for i in n:
		var ci := c0 + i
		var a := ci * CHUNK_SEGS
		if a + CHUNK_SEGS >= track.segment_count - 2:
			break
		var t0 := Time.get_ticks_usec()
		track.update_window(float(a) * _seg_len - 30.0, float(CHUNK_SEGS) * _seg_len + 60.0)
		var t1 := Time.get_ticks_usec()
		var res := b.build(track, path, a, a + CHUNK_SEGS, scenery_db)
		var t2 := Time.get_ticks_usec()
		var mi := MeshInstance3D.new()
		mi.mesh = res["mesh"]
		add_child(mi)
		_add_props(mi, a, a + CHUNK_SEGS, res["origin"])
		var t3 := Time.get_ticks_usec()
		inst += mi.get_child_count()
		mi.free()
		gen.append(t1 - t0); mesh.append(t2 - t1); props.append(t3 - t2)
		quads += int(res["quads"])
	var out := {"chunks": gen.size(), "chunk_m": float(CHUNK_SEGS) * _seg_len, "quads_avg": quads / maxi(1, gen.size()), "multimeshes_avg": float(inst) / maxf(1.0, float(gen.size()))}
	for pair: Array in [["track_gen", gen], ["mesh", mesh], ["props", props]]:
		var arr: Array[int] = pair[1]
		arr.sort()
		var sum := 0
		for x in arr:
			sum += x
		out[str(pair[0]) + "_ms"] = {"avg": snappedf(float(sum) / float(arr.size()) / 1000.0, 0.001), "med": snappedf(float(arr[arr.size() / 2]) / 1000.0, 0.001),
			"p95": snappedf(float(arr[int(float(arr.size() - 1) * 0.95)]) / 1000.0, 0.001), "max": snappedf(float(arr[arr.size() - 1]) / 1000.0, 0.001)}
	print("BENCH3D ", JSON.stringify(out))
	get_tree().quit()


func render(v: Dictionary) -> void:
	view = v
	if CliArgs.has("bench3d") and _frames == 0:
		_frames = 1
		_bench(int(CliArgs.get_float("bench3d", 200.0)))
		return
	var t0 := Time.get_ticks_usec()
	_update()
	var us := Time.get_ticks_usec() - t0
	if _frames > 0:
		_sum_us += us
		_max_us = maxi(_max_us, us)
	else:
		_first_build_ms = float(us) / 1000.0
	_frames += 1
	if _frames % 90 == 0 and CliArgs.has("perf3d"):
		print("PERF3D ", JSON.stringify(perf_stats()))
	if not _probe_done and CliArgs.has("probe3d") and _frames == int(CliArgs.get_float("probe3d", 30.0)):
		_probe_done = true
		_probe()


func perf_stats() -> Dictionary:
	var b := _build_us.duplicate()
	b.sort()
	var q := 0
	for x in _build_quads:
		q += x
	var nb := maxi(1, b.size())
	var sum_b := 0
	for x in b:
		sum_b += x
	return {"frames": _frames, "avg_ms": snappedf(float(_sum_us) / maxf(1.0, float(_frames - 1)) / 1000.0, 0.001),
		"max_ms": float(_max_us) / 1000.0, "p95_ms": 0.0, "last_ms": 0.0, "first_frame_ms": _first_build_ms,
		"chunks_built": b.size(), "chunk_avg_ms": snappedf(float(sum_b) / float(nb) / 1000.0, 0.001),
		"chunk_med_ms": snappedf(float(b[b.size() / 2]) / 1000.0 if b.size() > 0 else 0.0, 0.001),
		"chunk_max_ms": float(b[b.size() - 1]) / 1000.0 if b.size() > 0 else 0.0,
		"chunk_quads_avg": q / nb, "chunks_live": _chunks.size(),
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"cars": _cars.size(), "v3d": _viewport_info()}


func _viewport_info() -> Dictionary:
	var vp := get_viewport().get_viewport_rid()
	var out := {}
	for t: Array in [["visible", RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE], ["shadow", RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW], ["canvas", RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS]]:
		out[str(t[0])] = [RenderingServer.viewport_get_render_info(vp, t[1], RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
			RenderingServer.viewport_get_render_info(vp, t[1], RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
			RenderingServer.viewport_get_render_info(vp, t[1], RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)]
	return out


func _update() -> void:
	var cam_z := float(view["camera_z"])
	var cam_x := float(view["camera_x"])
	var cam_y := float(view["camera_y"])
	var vis := float(view.get("visibility_m", 900.0))
	var pal: Dictionary = view["palette"]
	var cam_seg := int(floor(cam_z / _seg_len))
	if path.track == null:
		path.setup(track, maxi(0, cam_seg - 2 * CHUNK_SEGS), _curve_r1)
	# --- chunks
	var c0 := maxi(int(floor(float(path.first) / float(CHUNK_SEGS) + 0.999)), int(floor(float(cam_seg - 12) / float(CHUNK_SEGS))))
	var c1 := int(floor((cam_z + vis + 60.0) / _seg_len / float(CHUNK_SEGS)))
	c1 = mini(c1, (track.segment_count - 2) / CHUNK_SEGS)
	for ci: int in _chunks.keys():
		if ci < c0:
			(_chunks[ci] as Node).queue_free()
			_chunks.erase(ci)
	var built := 0
	var budget := build_per_frame if _frames > 0 else 1000
	for ci in range(c0, c1 + 1):
		if _chunks.has(ci):
			continue
		if built >= budget:
			break
		_build_chunk(ci)
		built += 1
	# --- camera: on the path, looking along the tangent plus a look-into-the-curve yaw
	var c := path.centre_at(cam_z)
	var a := path.heading_at(cam_z)
	var target := path.centre_at(cam_z + look_m) - c
	var bearing := atan2(target.dot(RoadPath3D.right_of(a)), target.dot(RoadPath3D.fwd_of(a)))
	var yaw := a + look_gain * bearing
	var pos := Vector3(c.x, cam_y, c.z) + RoadPath3D.right_of(a) * cam_x
	var f := RoadPath3D.fwd_of(yaw)
	var r := RoadPath3D.right_of(yaw)
	cam.global_transform = Transform3D(Basis(r, Vector3.UP, -f), pos)
	var shake: Vector2 = view.get("shake", Vector2.ZERO)
	var size := NEAR * proj.screen.y / proj.focal
	cam.frustum_offset = Vector2(-shake.x / proj.focal * NEAR, size * (proj.horizon_y / proj.screen.y - 0.5) + shake.y / proj.focal * NEAR)
	# --- light, sky, fog from the palette
	var lights := float(pal.get("lights", 0.0))
	var amb: Color = pal["ambient"]
	var sp: Vector2 = pal.get("sun_pos", Vector2(0.0, 1.0))
	var elev := deg_to_rad(lerpf(12.0, 62.0, clampf(sp.y, 0.0, 1.0)))
	var az := sp.x * 1.3
	var dir := Vector3(sin(az) * cos(elev), sin(elev), -cos(az) * cos(elev))     # towards the sun
	sun.look_at_from_position(pos + dir * 100.0, pos, Vector3.UP)
	var day := clampf(1.0 - lights * 1.2, 0.0, 1.0)
	var overcast := float(pal.get("overcast", 0.0))
	sun.light_energy = lerpf(0.0, CliArgs.get_float("sun-e", 0.2), day) * (1.0 - 0.75 * overcast)
	sun.light_color = pal.get("sun", Color.WHITE)
	sun.shadow_enabled = shadows_on and sun.light_energy > 0.15
	env.ambient_light_color = amb
	env.ambient_light_energy = lerpf(0.8, CliArgs.get_float("amb-e", 0.5), day) + 0.3 * overcast * day
	sky_mat.sky_top_color = pal["sky_top"]
	sky_mat.sky_horizon_color = pal["sky_bottom"]
	sky_mat.ground_horizon_color = pal["fog"]
	sky_mat.ground_bottom_color = pal["fog"]
	sky_mat.sky_energy_multiplier = 1.0
	env.fog_light_color = pal["fog"]
	env.fog_depth_begin = vis * float(ConfigLoader.lookup(cfg, "render.fog_start_frac", 0.45))
	env.fog_depth_end = vis
	if _backdrop != null:
		var scen_b: Dictionary = scenery_db.get(str(view.get("scenery", "")), {})
		var hz := clampf(1.0 - vis / maxf(1.0, float(ConfigLoader.lookup(cfg, "render.draw_distance_m", 900.0))), 0.0, 1.0)
		var by := proj.horizon_y
		var kend := mini(path.last(), cam_seg + int(vis / _seg_len))
		for k in range(cam_seg + 4, kend, 6):
			var pe := path.point(k)
			var de := (pe - pos).dot(f)
			if de > 30.0 and absf((pe - pos).dot(r)) < de * 0.9 + 60.0:
				by = minf(by, proj.horizon_y - (pe.y - 2.6 - cam_y) * proj.focal / de)
		by = maxf(by, proj.horizon_y - 120.0)
		_backdrop.call("update", pal, yaw, float(view.get("time", 0.0)), str(view.get("scenery", "")), scen_b.get("background", {}), hz * 0.9, by)
	# --- base plane under the lowest road of the window
	var lo := INF
	for k in range(cam_seg, mini(path.last(), cam_seg + int(vis / _seg_len)), 8):
		lo = minf(lo, path.point(k).y)
	_base.position = Vector3(pos.x, lo - 4.0, pos.z)
	var scen: Dictionary = scenery_db.get(str(view.get("scenery", "")), {})
	var gcols: Array = scen.get("grass", ["#5d9a3e"])
	_base_mat.albedo_color = Color(str(gcols[0])).darkened(0.15)
	# --- vehicles
	_car_seen.clear()
	for car: Dictionary in view.get("cars", []):
		_place_car(car, false)
	if view.has("player"):
		_place_car(view["player"], true)
	for id: int in _cars.keys():
		if not _car_seen.has(id):
			(_cars[id] as Node).queue_free()
			_cars.erase(id)


func _build_chunk(ci: int) -> void:
	var a := ci * CHUNK_SEGS
	var b := mini(a + CHUNK_SEGS, track.segment_count - 1)
	var res := _builder.build(track, path, a, b, scenery_db)
	var mi := MeshInstance3D.new()
	mi.mesh = res["mesh"]
	mi.material_override = _mat
	mi.position = res["origin"]
	_chunk_root.add_child(mi)
	_chunks[ci] = mi
	var us := int(res["us"])
	if props_on:
		var t0 := Time.get_ticks_usec()
		_add_props(mi, a, b, res["origin"])
		_add_signs(mi, a, b, res["origin"])
		us += Time.get_ticks_usec() - t0
	_build_us.append(us)
	_build_quads.append(int(res["quads"]))


## Billboards of the existing prop sprites (centre cell), one MultiMesh per sprite set and chunk: the cheap far-field
## stand-in / migration path for the 86 props until meshes exist.
func _add_props(parent: Node3D, a: int, b: int, origin: Vector3) -> void:
	var by_set: Dictionary = {}
	for k in range(a, b):
		var seg := track.get_segment(k)
		for sp: Dictionary in seg.sprites:
			if str(sp.get("kind", "prop")) != "prop" or bool(sp.get("landmark", false)) or bool(sp.get("overhead", false)):
				continue
			var set_id := str(sp.get("set", ""))
			if set_id == "" or not SpriteDB.has_set(set_id) or SpriteDB.texture(set_id) == null:
				set_id = str(sp.get("fallback", ""))
				if set_id == "" or not SpriteDB.has_set(set_id) or SpriteDB.texture(set_id) == null:
					continue
			if not by_set.has(set_id):
				by_set[set_id] = []
			(by_set[set_id] as Array).append(sp)
	for set_id: String in by_set:
		var info := _prop_info(set_id)
		var list: Array = by_set[set_id]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = info[0]
		mm.instance_count = list.size()
		var size: Vector2 = info[1]
		for i in list.size():
			var sp: Dictionary = list[i]
			var z := float(sp.get("z", 0.0))
			var sc := float(sp.get("scale", 1.0))
			var w := path.world(z, float(sp.get("x", 0.0)), float(sp.get("h", 0.0))) - origin
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(size.x * sc, size.y * sc, 1.0)), w))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)


## Road signs: the arcade SignPainter draws each distinct sign once into a SubViewport; the texture sits on a quad
## in the cross-section plane of the road (facing the traffic). Gantries (side 0) are left out in the spike.
const SIGN_PPM := 64.0
const SIGN_PX := Vector2(384, 448)
var _sign_mats: Dictionary = {}


func _sign_material(sp: Dictionary) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s|%s|%s|%s" % [sp.get("sign", ""), sp.get("text", ""), sp.get("value", 0), sp.get("country", ""), sp.get("road", ""), sp.get("wall", false), sp.get("limit", 0)]
	if _sign_mats.has(key):
		return _sign_mats[key]
	var vp := SubViewport.new()
	vp.size = Vector2i(SIGN_PX)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var canvas: Node2D = load("res://spike/sign_canvas.gd").new()
	vp.add_child(canvas)
	var it := sp.duplicate()
	it.erase("_c")
	canvas.call("configure", it, GameData.countries, SIGN_PPM, SIGN_PX)
	var m := StandardMaterial3D.new()
	m.albedo_texture = vp.get_texture()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.6
	m.emission_enabled = true          # retro-reflective foil: never darker than a dim glow
	m.emission_texture = vp.get_texture()
	m.emission = Color.WHITE
	m.emission_energy_multiplier = 0.25
	_sign_mats[key] = m
	return m


func _add_signs(parent: Node3D, a: int, b: int, origin: Vector3) -> void:
	for k in range(a, b):
		var seg := track.get_segment(k)
		for sp: Dictionary in seg.sprites:
			if str(sp.get("kind", "")) != "sign" or int(sp.get("side", 1)) == 0:
				continue
			var z := float(sp.get("z", seg.z))
			var sc := float(sp.get("scale", 1.0))
			var w := SIGN_PX.x / SIGN_PPM * sc
			var h := SIGN_PX.y / SIGN_PPM * sc
			var q := QuadMesh.new()
			q.size = Vector2(w, h)
			var mi := MeshInstance3D.new()
			mi.mesh = q
			mi.material_override = _sign_material(sp)
			var hd := path.heading_at(z)
			var pos := path.world(z, float(sp.get("x", 0.0)), h * 0.5) - origin
			# the quad's front (+Z) looks back along the road, towards the traffic
			mi.transform = Transform3D(Basis(RoadPath3D.right_of(hd), Vector3.UP, -RoadPath3D.fwd_of(hd)), pos)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mi)


## [quad mesh with the cell's UVs and a Y-billboard material, cell size in metres]
func _prop_info(set_id: String) -> Array:
	if _prop_mats.has(set_id):
		return _prop_mats[set_id]
	var tex := SpriteDB.texture(set_id)
	var reg := SpriteDB.region(set_id, "c", "base")
	var ppm := SpriteDB.pixels_per_meter(set_id)
	var anchor := SpriteDB.anchor(set_id)
	var ts := tex.get_size()
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# unit quad whose origin is the sprite's ground anchor
	var q := ArrayMesh.new()
	var x0 := -anchor.x
	var x1 := 1.0 - anchor.x
	var y1 := anchor.y
	var y0 := anchor.y - 1.0
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(x0, y1, 0), Vector3(x1, y1, 0), Vector3(x1, y0, 0), Vector3(x0, y0, 0)])
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	var u0 := reg.position.x / ts.x
	var u1 := reg.end.x / ts.x
	var v0 := reg.position.y / ts.y
	var v1 := reg.end.y / ts.y
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	q.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	q.surface_set_material(0, m)
	var res := [q, Vector2(reg.size.x / ppm, reg.size.y / ppm)]
	_prop_mats[set_id] = res
	return res


func _car_material(key: String, player: bool) -> StandardMaterial3D:
	if _car_mats.has(key):
		return _car_mats[key]
	var m := StandardMaterial3D.new()
	var h := float(absi(hash(key)) % 1000) / 1000.0
	m.albedo_color = Color(0.85, 0.1, 0.08) if player else Color.from_hsv(h, 0.55, 0.8)
	m.metallic = 0.3
	m.roughness = 0.35
	_car_mats[key] = m
	return m


func _place_car(car: Dictionary, player: bool) -> void:
	var id := -1 if player else int(car.get("id", 0))
	var set_id := str(car.get("set", ""))
	var obj: Dictionary = SpriteDB.object_size(set_id) if SpriteDB.has_set(set_id) else {}
	var length := float(car.get("length", obj.get("length_m", 4.6)))
	var width := float(car.get("width", obj.get("width_m", 1.85)))
	var height := float(obj.get("height_m", 1.45))
	var node: Node3D = _cars.get(id)
	if node == null:
		node = Node3D.new()
		var body := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(width, height * 0.62, length)
		body.mesh = bm
		body.position = Vector3(0.0, height * 0.31 + 0.12, 0.0)
		body.material_override = _car_material(set_id, player)
		node.add_child(body)
		if height < 2.2:
			var cabin := MeshInstance3D.new()
			var cb := BoxMesh.new()
			cb.size = Vector3(width * 0.86, height * 0.4, length * 0.5)
			cabin.mesh = cb
			cabin.position = Vector3(0.0, height * 0.8, length * 0.06)
			cabin.material_override = _car_material("glass", false)
			node.add_child(cabin)
		for sx: float in [-1.0, 1.0]:
			var lamp := MeshInstance3D.new()
			var lb := BoxMesh.new()
			lb.size = Vector3(width * 0.26, 0.14, 0.06)
			lamp.mesh = lb
			lamp.position = Vector3(sx * width * 0.34, height * 0.48, length * 0.5 + 0.02)
			lamp.material_override = _light_mat
			lamp.name = "Lamp%d" % (0 if sx < 0.0 else 1)
			lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(lamp)
		_car_root.add_child(node)
		_cars[id] = node
	_car_seen[id] = true
	var zc := float(car["z"]) + length * 0.5
	var x := float(car.get("x", 0.0))
	var p0 := path.world(zc - length * 0.5, x, 0.0)
	var p1 := path.world(zc + length * 0.5, x, 0.0)
	var fwd := (p1 - p0).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var upv := right.cross(fwd).normalized()
	node.transform = Transform3D(Basis(right, upv, -fwd), (p0 + p1) * 0.5)
	node.visible = bool(car.get("visible", true))
	var brake := float(car.get("brake", 0.0)) > 0.5
	var tail := float(car.get("tail", 0.0)) > 0.3
	for i in 2:
		var lamp: MeshInstance3D = node.get_node("Lamp%d" % i)
		lamp.visible = brake or tail
		lamp.material_override = _brake_mat if brake else _light_mat
	if player:
		var lights := float((view["palette"] as Dictionary).get("lights", 0.0))
		_headlight.light_energy = 6.0 * clampf(lights * 1.4, 0.0, 1.0)
		_headlight.visible = lights > 0.05
		_headlight.global_transform = Transform3D(Basis(right, upv, -fwd), p1 + upv * 0.7).rotated_local(Vector3.RIGHT, deg_to_rad(-4.0))


## Parity probe: road points projected by the arcade renderer's projection (parabola, row by row as in
## RoadRenderer._project) against the 3D camera (Camera3D.unproject_position) – pixels.
func _probe() -> void:
	var cam_z := float(view["camera_z"])
	var cam_x := float(view["camera_x"])
	var cam_y := float(view["camera_y"])
	var kc := _seg_len * _seg_len / _curve_r1
	var base := int(floor(cam_z / _seg_len))
	var frac := (cam_z - float(base) * _seg_len) / _seg_len
	var x := 0.0
	var dx := -track.get_segment(base).curve * kc * frac
	var out: Array = []
	var want: Array[float] = [9.0, 20.0, 40.0, 60.0, 100.0, 150.0, 200.0, 300.0, 400.0, 600.0]
	var wi := 0
	var vp := get_viewport().get_visible_rect().size
	var sc := vp.x / proj.screen.x
	for k in range(0, int(700.0 / _seg_len)):
		var seg := track.get_segment(base + k)
		var zw := float(base + k) * _seg_len
		var dz := zw - cam_z
		if wi < want.size() and dz >= want[wi]:
			var rowp: Array = []
			for lat: float in [-5.6, 0.0, 5.6]:
				var pa := proj.project(x - cam_x + lat, seg.y - cam_y, dz)
				var w := path.world(zw, lat, 0.0)
				var behind := cam.is_position_behind(w)
				var p3 := cam.unproject_position(w) / sc
				rowp.append({"lat": lat, "arcade": [snappedf(pa.x, 0.1), snappedf(pa.y, 0.1)], "modern": [snappedf(p3.x, 0.1), snappedf(p3.y, 0.1)],
					"dx": snappedf(p3.x - pa.x, 0.1), "dy": snappedf(p3.y - pa.y, 0.1), "behind": behind})
			out.append({"d": snappedf(dz, 0.1), "curve": snappedf(seg.curve, 0.001), "pts": rowp})
			wi += 1
		x += dx
		dx += seg.curve * kc
	print("PROBE3D ", JSON.stringify({"cam_z": cam_z, "km": track.z_to_km(cam_z), "look_gain": look_gain, "viewport": [vp.x, vp.y], "rows": out}))
