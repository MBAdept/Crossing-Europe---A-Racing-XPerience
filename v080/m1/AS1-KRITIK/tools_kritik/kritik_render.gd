extends SceneTree
## AS1-KRITIK review renderer (scratch copy only, never committed). Renders one PNG per job of a JSON list
## with the game's materials (ModelFactory + ModernMaterials), like tools/models/contact_sheet.gd, plus
## diagnostic modes (clay, facets, normals, check, wire, caster) and exact cameras (game, orbit, ortho sprite).
##   xvfb-run ... godot --path . --rendering-driver opengl3 --audio-driver Dummy -s res://tools/kritik/kritik_render.gd
##       -- --jobs=<abs.json> --outdir=<abs dir>
## A job: {"name", "set", "lod", "cam": {...}, "mode", "night", "lamp_a": [4], "lamp_b": [4], "msaa": 0|2|4|8,
##   "sun": [x,y,z] (camera space, to the sun) | "sun_world": [x,y,z], "sun_energy", "ambient_energy",
##   "yaw": deg (model turned about "pivot": "center"|"rear"), "hide": [node names], "only": [node names],
##   "steer": deg (front wheels), "spin": deg (all wheels), "ground": [r,g,b], "size": [w,h]}
## cam: {"type": "game", "dist": m, "lane": m, "ss": factor}
##      {"type": "orbit", "yaw": deg, "el": deg, "fov": deg, "fit": f, "aabb": [6] (optional), "target_dist": m (optional)}
##      {"type": "ortho", "el": deg, "width_m": m, "anchor": [fx, fy], "pivot_z": m}   (sprite camera of traffic)

const VEHICLE_KINDS: Array[String] = ["vehicle", "heavy"]
const GAME_SIZE := Vector2i(1280, 720)
const GAME_FOCAL_PX := 711.0
const GAME_CAM_HEIGHT := 3.4

var _args: Dictionary = {}
var _mats: ModernMaterials
var _sv: SubViewport
var _cam: Camera3D
var _sun: DirectionalLight3D
var _env: Environment
var _ground: MeshInstance3D
var _holder: Node3D
var _sky_mat: ProceduralSkyMaterial
var _first := true
var _rig_night := false
var _diag: Dictionary = {}


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_run.call_deferred()


func _run() -> void:
	var jobs_path := str(_args.get("jobs", ""))
	var outdir := str(_args.get("outdir", ""))
	if jobs_path == "" or outdir == "":
		print("kritik_render: --jobs and --outdir needed")
		quit(1)
		return
	var jobs: Variant = JSON.parse_string(FileAccess.get_file_as_string(jobs_path))
	if not jobs is Array:
		print("kritik_render: bad job file")
		quit(1)
		return
	if not ModelDB.available():
		print("kritik_render: no model manifest")
		quit(1)
		return
	_mats = ModernMaterials.new()
	_build_rig()
	_build_diag()
	var meta := {}
	var t0 := Time.get_ticks_msec()
	for j: Variant in jobs:
		var job: Dictionary = j
		var res: Dictionary = await _render(job)
		var img: Image = res["img"]
		img.convert(Image.FORMAT_RGB8)
		var path := outdir.path_join(str(job["name"]) + ".png")
		img.save_png(path)
		meta[str(job["name"])] = res["meta"]
	var fh := FileAccess.open(outdir.path_join("_meta_%s.json" % jobs_path.get_file().get_basename()), FileAccess.WRITE)
	fh.store_string(JSON.stringify(meta, " ", true))
	fh.close()
	print("kritik_render: %d jobs in %.1f s" % [jobs.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)


func _build_rig() -> void:
	_sv = SubViewport.new()
	_sv.size = GAME_SIZE
	_sv.own_world_3d = true
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv.msaa_3d = Viewport.MSAA_2X
	root.add_child(_sv)
	_env = Environment.new()
	var sky := Sky.new()
	_sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = _sky_mat
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.adjustment_enabled = true
	_env.glow_enabled = true
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_env.glow_bloom = 0.0
	_env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = _env
	_sv.add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_sun.shadow_bias = 0.03
	_sun.shadow_normal_bias = 1.0
	_sv.add_child(_sun)
	_ground = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6000.0, 6000.0)
	_ground.mesh = pm
	_ground.material_override = StandardMaterial3D.new()
	_sv.add_child(_ground)
	_cam = Camera3D.new()
	_sv.add_child(_cam)
	_holder = Node3D.new()
	_sv.add_child(_holder)
	ModernMaterials.set_global("ce_time", 1.7)


func _shader(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _build_diag() -> void:
	_diag["clay"] = _shader("shader_type spatial;\nrender_mode cull_back;\nvoid fragment(){ ALBEDO = vec3(0.62); ROUGHNESS = 0.55; SPECULAR = 0.35; METALLIC = 0.0; }\n")
	_diag["discard"] = _shader("shader_type spatial;\nrender_mode cull_back, unshaded;\nvoid fragment(){ discard; }\n")
	_diag["facets"] = _shader("shader_type spatial;\nrender_mode cull_back;\nvoid fragment(){ vec3 gn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX))); if (dot(gn, -VERTEX) < 0.0) { gn = -gn; } NORMAL = gn; ALBEDO = vec3(0.62); ROUGHNESS = 0.6; SPECULAR = 0.3; }\n")
	_diag["normals"] = _shader("shader_type spatial;\nrender_mode cull_back, unshaded;\nvoid fragment(){ vec3 n = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz; ALBEDO = n * 0.5 + 0.5; }\n")
	# check: grey = fine (shaded by N.V), red = back side of a triangle visible (hole / open edge / inverted face),
	# magenta = vertex normal points against the triangle's facing (dark patch or a hole under cull_back)
	_diag["check"] = _shader("shader_type spatial;\nrender_mode cull_disabled, unshaded;\nvoid fragment(){ vec3 gn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX))); if (dot(gn, -VERTEX) < 0.0) { gn = -gn; } float ndv = clamp(dot(normalize(NORMAL), normalize(-VERTEX)), 0.0, 1.0); vec3 c = vec3(0.2 + 0.65 * ndv); if (!FRONT_FACING) { c = vec3(0.95, 0.12, 0.08); } if (dot(gn, NORMAL) < 0.0) { c = vec3(1.0, 0.0, 1.0); } ALBEDO = c; }\n")
	_diag["check_cb"] = _shader("shader_type spatial;\nrender_mode cull_back, unshaded;\nvoid fragment(){ vec3 gn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX))); if (dot(gn, -VERTEX) < 0.0) { gn = -gn; } float ndv = clamp(dot(normalize(NORMAL), normalize(-VERTEX)), 0.0, 1.0); vec3 c = vec3(0.2 + 0.65 * ndv); if (dot(gn, NORMAL) < 0.0) { c = vec3(1.0, 0.0, 1.0); } ALBEDO = c; }\n")
	_diag["wire"] = _shader("shader_type spatial;\nrender_mode unshaded, skip_vertex_transform, cull_disabled;\nuniform vec3 col = vec3(0.02, 0.02, 0.05);\nvoid vertex(){ VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz * 0.9985; }\nvoid fragment(){ ALBEDO = col; }\n")
	_diag["red"] = _shader("shader_type spatial;\nrender_mode cull_back, unshaded;\nvoid fragment(){ ALBEDO = vec3(1.0, 0.05, 0.05); }\n")
	# lamps: only the lamp channels, coloured by channel, everything else dark grey (layout of the lamps)
	_diag["lampmap"] = _shader("shader_type spatial;\nrender_mode cull_back, unshaded;\nvarying flat vec2 v_l;\nvoid vertex(){ v_l = UV2; }\nvoid fragment(){ vec3 c = vec3(0.16); if (v_l.x >= 0.0) { float ch = floor(v_l.x); if (ch < 0.5) c = vec3(0.6, 0.0, 0.0); else if (ch < 1.5) c = vec3(1.0, 0.25, 0.25); else if (ch < 2.5) c = vec3(1.0, 0.0, 0.5); else if (ch < 3.5) c = vec3(1.0, 0.6, 0.0); else if (ch < 4.5) c = vec3(1.0, 0.85, 0.0); else if (ch < 5.5) c = vec3(1.0, 1.0, 1.0); else if (ch < 6.5) c = vec3(0.6, 0.85, 1.0); else if (ch < 7.5) c = vec3(0.3, 1.0, 0.3); else if (ch < 8.5) c = vec3(0.0, 0.7, 0.7); else if (ch < 9.5) c = vec3(0.7, 0.3, 1.0); else c = vec3(0.3, 0.3, 1.0); c *= mix(0.35, 1.0, v_l.y); } ALBEDO = c; }\n")


func _set_night(night: bool, job: Dictionary) -> bool:
	var changed := night != _rig_night or _first
	_rig_night = night
	if night:
		_sky_mat.sky_top_color = Color(0.01, 0.014, 0.035)
		_sky_mat.sky_horizon_color = Color(0.03, 0.04, 0.075)
		_sky_mat.ground_bottom_color = Color(0.008, 0.008, 0.012)
		_sky_mat.ground_horizon_color = Color(0.03, 0.035, 0.06)
	else:
		_sky_mat.sky_top_color = Color(0.24, 0.44, 0.78)
		_sky_mat.sky_horizon_color = Color(0.7, 0.79, 0.9)
		_sky_mat.ground_bottom_color = Color(0.2, 0.19, 0.17)
		_sky_mat.ground_horizon_color = Color(0.62, 0.68, 0.74)
	_env.ambient_light_color = Color(0.1, 0.12, 0.2) if night else Color(0.6, 0.64, 0.7)
	_env.ambient_light_energy = float(job.get("ambient_energy", 0.55 if night else 1.0))
	_env.glow_intensity = 0.7 if night else 0.25
	_sun.light_energy = float(job.get("sun_energy", 0.1 if night else 0.8))
	_sun.light_color = Color(0.62, 0.72, 1.0) if night else Color(1.0, 0.97, 0.92)
	ModernMaterials.set_global("ce_night", 1.0 if night else 0.0)
	ModernMaterials.set_global("ce_sun_color", ModernMaterials.light_value(_sun.light_color, _sun.light_energy))
	ModernMaterials.set_global("ce_ambient", ModernMaterials.light_value(_env.ambient_light_color, _env.ambient_light_energy))
	return changed


func _v3(a: Variant, d: Vector3) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return d


func _v4(a: Variant) -> Vector4:
	if a is Array and (a as Array).size() >= 4:
		return Vector4(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	return Vector4.ZERO


## Line mesh of the triangle edges of a mesh (wire mode).
func _edges_mesh(mesh: Mesh) -> ArrayMesh:
	var verts := PackedVector3Array()
	var seen := {}
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: Variant = arr[Mesh.ARRAY_INDEX]
		var ii: PackedInt32Array
		if idx == null:
			ii = PackedInt32Array()
			for k in v.size():
				ii.append(k)
		else:
			ii = idx
		for t in range(0, ii.size(), 3):
			for e in 3:
				var a := ii[t + e]
				var b := ii[t + (e + 1) % 3]
				var pa := v[a]
				var pb := v[b]
				# weld by position (the exporter splits vertices at code borders)
				var ka := "%d,%d,%d" % [roundi(pa.x * 2000.0), roundi(pa.y * 2000.0), roundi(pa.z * 2000.0)]
				var kb := "%d,%d,%d" % [roundi(pb.x * 2000.0), roundi(pb.y * 2000.0), roundi(pb.z * 2000.0)]
				var key := (ka + "|" + kb) if ka < kb else (kb + "|" + ka)
				if seen.has(key):
					continue
				seen[key] = true
				verts.append(pa)
				verts.append(pb)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	var lm := ArrayMesh.new()
	lm.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, out)
	lm.surface_set_material(0, _diag["wire"])
	return lm


func _apply_mode(node: Node3D, mode: String) -> void:
	if mode == "shaded" or mode == "":
		return
	for c: Node in node.get_children():
		var mi := c as MeshInstance3D
		if mi == null:
			continue
		if mi.name == "shadow":
			if mode == "caster":
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.material_override = _diag["red"]
			elif mode == "caster_only":
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				mi.material_override = _diag["clay"]
			continue
		if mode == "caster_only":
			mi.visible = false
			continue
		var mesh := mi.mesh
		match mode:
			"clay", "caster", "wire":
				mi.material_override = _diag["clay"]
			"clay_noglass":
				for s in mesh.get_surface_count():
					mi.set_surface_override_material(s, _diag["discard"] if str(mesh.surface_get_name(s)) == "glass" else _diag["clay"])
			"facets":
				mi.material_override = _diag["facets"]
			"normals":
				mi.material_override = _diag["normals"]
			"mask":
				mi.material_override = _diag["red"]
			"check":
				mi.material_override = _diag["check"]
			"check_cb":
				mi.material_override = _diag["check_cb"]
			"check_noglass":
				for s in mesh.get_surface_count():
					mi.set_surface_override_material(s, _diag["discard"] if str(mesh.surface_get_name(s)) == "glass" else _diag["check"])
			"lampmap":
				for s in mesh.get_surface_count():
					mi.set_surface_override_material(s, _diag["discard"] if str(mesh.surface_get_name(s)) == "glass" else _diag["lampmap"])
		if mode == "wire":
			var w := MeshInstance3D.new()
			w.name = String(mi.name) + "_wire"
			w.mesh = _edges_mesh(mesh)
			w.transform = mi.transform
			w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(w)


func _render(job: Dictionary) -> Dictionary:
	for c: Node in _holder.get_children():
		c.free()
	var meta := {}
	var set_id := str(job.get("set", ""))
	var lod := str(job.get("lod", "lod0"))
	var mode := str(job.get("mode", "shaded"))
	var night := bool(job.get("night", false))
	var rig_changed := _set_night(night, job)
	var gm: StandardMaterial3D = _ground.material_override
	gm.albedo_color = Color(0.2, 0.2, 0.21)
	if job.has("ground"):
		var g: Array = job["ground"]
		gm.albedo_color = Color(float(g[0]), float(g[1]), float(g[2]))
	gm.roughness = 0.85
	_ground.visible = not bool(job.get("no_ground", false))
	var r := ModelDB.resolve(set_id)
	var m: Dictionary = r.get("model", {})
	var node: Node3D = null
	if set_id == "":
		node = Node3D.new()
	else:
		node = ModelFactory.build(set_id, lod, _mats)
	if node == null:
		print("kritik_render: no model for ", set_id, " ", lod)
		meta["missing"] = true
		var empty := Image.create(64, 64, false, Image.FORMAT_RGB8)
		return {"img": empty, "meta": meta}
	var pivot := Node3D.new()
	_holder.add_child(pivot)
	pivot.add_child(node)
	ModelFactory.set_lamps(node, _v4(job.get("lamp_a", [0, 0, 0, 0])), _v4(job.get("lamp_b", [0, 0, 0, 0])))
	_apply_mode(node, mode)
	var hide: Array = job.get("hide", [])
	var only: Array = job.get("only", [])
	for c: Node in node.get_children():
		var n3 := c as Node3D
		if n3 == null:
			continue
		var base_name := String(n3.name).replace("_wire", "")
		if hide.has(base_name) or (not only.is_empty() and not only.has(base_name) and base_name != "shadow"):
			n3.visible = false
	# wheels: steer the front ones, spin all
	var wheels: Array = node.get_meta("wheels", [])
	for wp: Variant in wheels:
		var w := node.get_node(wp as NodePath) as Node3D
		var b := w.basis
		if job.has("spin"):
			b = b * Basis(Vector3.RIGHT, deg_to_rad(float(job["spin"])))
		if job.has("steer") and String(w.name).find("wheel_0") >= 0:
			b = Basis(Vector3.UP, deg_to_rad(float(job["steer"]))) * b
		w.basis = b
	# articulated vehicles: turn the trailer parts about the trailer pivot (kingpin) of "groups"
	if job.has("articulate") and m.has("groups"):
		var tp: Array = (m["groups"] as Dictionary).get("trailer", {}).get("pivot", [0, 0, 0])
		var pv := Vector3(float(tp[0]), float(tp[1]), float(tp[2]))
		var rot := Transform3D(Basis(Vector3.UP, deg_to_rad(float(job["articulate"]))), Vector3.ZERO)
		var about := Transform3D(Basis.IDENTITY, pv) * rot * Transform3D(Basis.IDENTITY, -pv)
		for c: Node in node.get_children():
			var n3 := c as Node3D
			if n3 != null and String(n3.name).begins_with("trailer"):
				n3.transform = about * n3.transform
	# model yaw about its centre or the rear (sprite pivot of traffic)
	var obj: Dictionary = m.get("object", {})
	var length := float(obj.get("length_m", 4.5))
	var yaw := deg_to_rad(float(job.get("yaw", 0.0)))
	if str(job.get("pivot", "center")) == "rear":
		var pz := length * 0.5
		pivot.position = Vector3(0, 0, pz)
		node.position = Vector3(0, 0, -pz)
	pivot.rotation = Vector3(0.0, yaw, 0.0)
	# camera
	var cam: Dictionary = job.get("cam", {"type": "orbit"})
	var ctype := str(cam.get("type", "orbit"))
	var size := GAME_SIZE
	if job.has("size"):
		size = Vector2i(int(job["size"][0]), int(job["size"][1]))
	var msaa := int(job.get("msaa", 2))
	_sv.msaa_3d = {0: Viewport.MSAA_DISABLED, 2: Viewport.MSAA_2X, 4: Viewport.MSAA_4X, 8: Viewport.MSAA_8X}.get(msaa, Viewport.MSAA_2X)
	_cam.h_offset = 0.0
	_cam.v_offset = 0.0
	var bb: Array = cam.get("aabb", m.get("aabb", [-1, 0, -1, 1, 2, 1]))
	var lo := Vector3(float(bb[0]), float(bb[1]), float(bb[2]))
	var hi := Vector3(float(bb[3]), float(bb[4]), float(bb[5]))
	var centre := (lo + hi) * 0.5
	var radius := (hi - lo).length() * 0.5
	if ctype == "game":
		var ss := float(cam.get("ss", 1.0))
		size = Vector2i(roundi(GAME_SIZE.x * ss), roundi(GAME_SIZE.y * ss))
		var near := 1.0
		var fsize := near * float(GAME_SIZE.y) / GAME_FOCAL_PX
		_cam.keep_aspect = Camera3D.KEEP_HEIGHT
		_cam.set_frustum(fsize, Vector2(0.0, -0.05 * fsize), near, 2600.0)
		_cam.basis = Basis.IDENTITY
		_cam.position = Vector3(-float(cam.get("lane", 0.0)), GAME_CAM_HEIGHT, float(cam.get("dist", 9.0)))
	elif ctype == "ortho":
		var el := deg_to_rad(float(cam.get("el", 9.0)))
		var wm := float(cam.get("width_m", 5.0))
		var hm := wm * float(size.y) / float(size.x)
		var anc: Array = cam.get("anchor", [0.5, 0.95])
		var f := Vector3(0.0, -sin(el), -cos(el))
		var u := Vector3(0.0, cos(el), -sin(el))
		var rr := Vector3(1, 0, 0)
		var p0 := Vector3(0, 0, float(cam.get("pivot_z", length * 0.5)))
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_cam.keep_aspect = Camera3D.KEEP_WIDTH
		_cam.size = wm
		_cam.near = 0.05
		_cam.far = 400.0
		_cam.position = p0 - (float(anc[0]) - 0.5) * wm * rr - (0.5 - float(anc[1])) * hm * u - 60.0 * f
		_cam.basis = Basis.looking_at(f, Vector3.UP)
	else:
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		_cam.fov = float(cam.get("fov", 30.0))
		_cam.keep_aspect = Camera3D.KEEP_HEIGHT
		var cy := deg_to_rad(float(cam.get("yaw", 30.0)))
		var ce := deg_to_rad(float(cam.get("el", 12.0)))
		var dir := Vector3(sin(cy) * cos(ce), sin(ce), cos(cy) * cos(ce))
		var basis := Basis.looking_at(-dir, Vector3.UP)
		var tan_v := tan(deg_to_rad(_cam.fov * 0.5))
		var tan_h := tan_v * float(size.x) / float(size.y)
		var dist := 0.5
		for i in 8:
			var corner := Vector3(lo.x if i & 1 == 0 else hi.x, lo.y if i & 2 == 0 else hi.y, lo.z if i & 4 == 0 else hi.z) - centre
			var c := basis.inverse() * corner
			dist = maxf(dist, maxf(absf(c.x) / tan_h, absf(c.y) / (tan_v * 0.92)) + c.z)
		dist *= float(cam.get("fit", 1.06))
		if cam.has("target_dist"):
			dist = float(cam["target_dist"])
		_cam.position = centre + dir * dist
		_cam.basis = basis
		_cam.near = maxf(0.03, dist * 0.005)
		_cam.far = dist * 4.0 + 2000.0
	_sv.size = size
	# sun: camera space by default (upper left, from the viewer's side, as the sprite rig), or world space
	var to_sun: Vector3
	if job.has("sun_world"):
		to_sun = _v3(job["sun_world"], Vector3(0.4, 0.8, 0.4)).normalized()
	else:
		to_sun = (_cam.basis * _v3(job.get("sun", [-0.55, 0.92, 0.55]), Vector3(-0.55, 0.92, 0.55))).normalized()
	_sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	ModernMaterials.set_global("ce_sun_dir", to_sun)
	_sun.directional_shadow_max_distance = float(job.get("shadow_dist", 120.0 if ctype == "game" else maxf(30.0, radius * 6.0)))
	for i in (16 if (_first or rig_changed) else 5):
		await process_frame
	_first = false
	await RenderingServer.frame_post_draw
	var img := _sv.get_texture().get_image()
	# screen rectangle of the model's bounding box (for crops) and draw calls of this frame
	var rect := Rect2()
	for i in 8:
		var corner := Vector3(lo.x if i & 1 == 0 else hi.x, lo.y if i & 2 == 0 else hi.y, lo.z if i & 4 == 0 else hi.z)
		var wp := pivot.global_transform * (node.transform * corner)
		var sp := _cam.unproject_position(wp)
		rect = Rect2(sp, Vector2.ZERO) if i == 0 else rect.expand(sp)
	meta["rect"] = [rect.position.x, rect.position.y, rect.end.x, rect.end.y]
	meta["size"] = [size.x, size.y]
	meta["draw_calls_visible"] = _sv.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	meta["draw_calls_shadow"] = _sv.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	meta["prims_visible"] = _sv.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	meta["cam_pos"] = [_cam.position.x, _cam.position.y, _cam.position.z]
	return {"img": img, "meta": meta}
