extends SceneTree
## KRITIK-2 review renderer (scratch copy only, never committed). Based on the AS1-KRITIK renderer: one PNG per job of
## a JSON list with the game's materials (ModelFactory + ModernMaterials), extended by
##  * the race look of the vehicle layer (layers/vehicles.gd LOOK, PLAYER_FILL, sky mirrored by the clear coat) - the
##    look the cars have in a race; "look": "neutral" gives the shader defaults,
##  * the soft contact shadow the vehicle layer draws under every car (contact_shadow.gdshader),
##  * rigs "day", "night" (the contact-sheet rig) and "studio" (UI1's showroom studio: key, fill, two rims, AgX),
##  * the showroom camera of the Cycles showroom sprites, a section mode and a "body casts" mode.
##   xvfb-run ... godot --path . --rendering-driver opengl3 --audio-driver Dummy -s res://tools/kritik/kritik_render.gd
##       -- --jobs=<abs.json> --outdir=<abs dir>
## A job: {"name", "set", "lod", "cam": {...}, "mode", "rig": "day"|"night"|"studio" (or "night": true),
##   "lamp_a": [4], "lamp_b": [4], "msaa": 0|2|4|8, "sun": [x,y,z] (camera space, to the sun) | "sun_world": [x,y,z],
##   "sun_energy", "ambient_energy", "yaw": deg (model turned about "pivot": "center"|"rear"), "hide": [node names],
##   "only": [node names], "steer": deg (front wheels), "spin": deg (all wheels), "ground": [r,g,b], "size": [w,h],
##   "look": "race"|"neutral", "fill": float (player fill; default PLAYER_FILL for player sets in the race look),
##   "contact": bool (contact shadow, default true for shaded modes), "tonemap": "linear"|"agx",
##   "section": [nx, ny, nz, d] (mode section*: keep the part where dot(n, p) <= d, model space)}
## cam: {"type": "game", "dist": m, "lane": m, "ss": factor}
##      {"type": "orbit", "yaw": deg, "el": deg, "fov": deg, "fit": f, "aabb": [6] (optional), "target_dist": m (optional)}
##      {"type": "ortho", "el": deg, "width_m": m, "anchor": [fx, fy], "pivot_z": m}   (sprite camera of traffic)
##      {"type": "showroom"}   (camera of the Cycles showroom sprites, 768x480)

const VEHICLE_KINDS: Array[String] = ["vehicle", "heavy"]
const GAME_SIZE := Vector2i(1280, 720)
const GAME_FOCAL_PX := 711.0
const GAME_CAM_HEIGHT := 3.4
const SHADOW_MARGIN_M := 0.45

var _args: Dictionary = {}
var _mats: ModernMaterials
var _sv: SubViewport
var _cam: Camera3D
var _sun: DirectionalLight3D
var _fill_light: DirectionalLight3D
var _rims: Array[OmniLight3D] = []
var _env: Environment
var _ground: MeshInstance3D
var _holder: Node3D
var _sky_mat: ProceduralSkyMaterial
var _first := true
var _rig := ""
var _diag: Dictionary = {}
var _look: Array = []
var _player_fill := 0.7
var _look_on := true
var _cs_mm: MultiMesh
var _cs_node: MultiMeshInstance3D


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
	_read_look()
	_build_rig()
	_build_diag()
	var meta := {}
	var t0 := Time.get_ticks_msec()
	var skip := _args.has("skip-existing")
	var n := 0
	for j: Variant in jobs:
		var job: Dictionary = j
		var path := outdir.path_join(str(job["name"]) + ".png")
		if skip and FileAccess.file_exists(path):
			continue
		var res: Dictionary = await _render(job)
		var img: Image = res["img"]
		img.convert(Image.FORMAT_RGB8)
		img.save_png(path)
		meta[str(job["name"])] = res["meta"]
		n += 1
	var mp := outdir.path_join("_meta_%s.json" % jobs_path.get_file().get_basename())
	if skip and FileAccess.file_exists(mp):
		var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(mp))
		if old is Dictionary:
			for k: Variant in old:
				if not meta.has(k):
					meta[k] = old[k]
	var fh := FileAccess.open(mp, FileAccess.WRITE)
	fh.store_string(JSON.stringify(meta, " ", true))
	fh.close()
	print("kritik_render: %d jobs in %.1f s" % [n, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)


## The race look of the shared vehicle materials: read from the vehicle layer's script (its LOOK and PLAYER_FILL).
func _read_look() -> void:
	_look = [["vpbr", "env_energy", 1.6], ["vpbr", "paint_base", 0.9], ["vpbr", "flake_strength", 0.6], ["glass", "env_energy", 2.2]]
	var path := "res://scripts/race3d/layers/vehicles.gd"
	if ResourceLoader.exists(path):
		var scr := load(path) as Script
		if scr != null:
			var cm := scr.get_script_constant_map()
			if cm.get("LOOK") is Array:
				_look = cm["LOOK"]
			if cm.has("PLAYER_FILL"):
				_player_fill = float(cm["PLAYER_FILL"])
	print("kritik_render: race look ", _look, " player fill ", _player_fill)


var _params_dirty := false
var _look_force := false


func _first_look_force() -> void:
	_look_force = true


func _set_look(on: bool) -> void:
	if on == _look_on and not _first and not _look_force:
		return
	_look_force = false
	_look_on = on
	for l: Variant in _look:
		var e: Array = l
		var neutral: Variant = {"env_energy": 0.0, "paint_base": 1.0, "flake_strength": 0.0}.get(str(e[1]), e[2])
		_mats.set_class_parameter(str(e[0]), str(e[1]), e[2] if on else neutral)


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
	# studio (UI1 showroom_3d.gd): fill from the other side, two rims in the menu accents
	_fill_light = DirectionalLight3D.new()
	_fill_light.rotation_degrees = Vector3(-18.0, 125.0, 0.0)
	_fill_light.light_energy = 0.26
	_fill_light.light_color = Color(0.82, 0.88, 1.0)
	_fill_light.visible = false
	_sv.add_child(_fill_light)
	for spec: Array in [[Vector3(-4.2, 1.5, -3.2), Color("#e0308f"), 2.6], [Vector3(4.2, 1.3, -3.4), Color("#22c8e8"), 2.4]]:
		var rim := OmniLight3D.new()
		rim.position = spec[0]
		rim.light_color = spec[1]
		rim.light_energy = float(spec[2])
		rim.omni_range = 8.5
		rim.omni_attenuation = 1.2
		rim.visible = false
		_sv.add_child(rim)
		_rims.append(rim)
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
	# contact shadow of the vehicle layer (one MultiMesh instance)
	_cs_mm = MultiMesh.new()
	_cs_mm.transform_format = MultiMesh.TRANSFORM_3D
	_cs_mm.use_custom_data = true
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5, 0.0, -0.5), Vector3(0.5, 0.0, -0.5), Vector3(0.5, 0.0, 0.5), Vector3(-0.5, 0.0, 0.5)])
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var qm := ArrayMesh.new()
	qm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_cs_mm.mesh = qm
	_cs_mm.instance_count = 1
	_cs_node = MultiMeshInstance3D.new()
	_cs_node.multimesh = _cs_mm
	_cs_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cs_node.material_override = _mats.material("contact_shadow")
	_cs_node.custom_aabb = AABB(Vector3(-100, -10, -100), Vector3(200, 20, 200))
	_sv.add_child(_cs_node)
	ModernMaterials.set_global("ce_time", 1.7)
	ModernMaterials.set_global("ce_fog_range", Vector2(4000.0, 9000.0))
	# the shared class materials must exist before the look is set on them (set_class_parameter on a class that has
	# no material yet does nothing - the vehicle layer creates them first as well)
	_mats.material("vpbr")
	_mats.material("glass")


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
	_diag["check"] = _shader("shader_type spatial;\nrender_mode cull_disabled, unshaded;\nvoid fragment(){ vec3 gn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX))); if (dot(gn, -VERTEX) < 0.0) { gn = -gn; } float ndv = clamp(dot(normalize(NORMAL), normalize(-VERTEX)), 0.0, 1.0); vec3 c = vec3(0.2 + 0.65 * ndv); if (!FRONT_FACING) { c = vec3(0.95, 0.12, 0.08); } if (dot(gn, NORMAL) < 0.0) { c = vec3(1.0, 0.0, 1.0); } ALBEDO = c; }\n")
	_diag["check_cb"] = _shader("shader_type spatial;\nrender_mode cull_back, unshaded;\nvoid fragment(){ vec3 gn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX))); if (dot(gn, -VERTEX) < 0.0) { gn = -gn; } float ndv = clamp(dot(normalize(NORMAL), normalize(-VERTEX)), 0.0, 1.0); vec3 c = vec3(0.2 + 0.65 * ndv); if (dot(gn, NORMAL) < 0.0) { c = vec3(1.0, 0.0, 1.0); } ALBEDO = c; }\n")
	_diag["wire"] = _shader("shader_type spatial;\nrender_mode unshaded, skip_vertex_transform, cull_disabled;\nuniform vec3 col = vec3(0.02, 0.02, 0.05);\nvoid vertex(){ VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz * 0.9985; }\nvoid fragment(){ ALBEDO = col; }\n")
	_diag["red"] = _shader("shader_type spatial;\nrender_mode cull_back, unshaded;\nvoid fragment(){ ALBEDO = vec3(1.0, 0.05, 0.05); }\n")
	_diag["lampmap"] = _shader("shader_type spatial;\nrender_mode cull_back, unshaded;\nvarying flat vec2 v_l;\nvoid vertex(){ v_l = UV2; }\nvoid fragment(){ vec3 c = vec3(0.16); if (v_l.x >= 0.0) { float ch = floor(v_l.x); if (ch < 0.5) c = vec3(0.6, 0.0, 0.0); else if (ch < 1.5) c = vec3(1.0, 0.25, 0.25); else if (ch < 2.5) c = vec3(1.0, 0.0, 0.5); else if (ch < 3.5) c = vec3(1.0, 0.6, 0.0); else if (ch < 4.5) c = vec3(1.0, 0.85, 0.0); else if (ch < 5.5) c = vec3(1.0, 1.0, 1.0); else if (ch < 6.5) c = vec3(0.6, 0.85, 1.0); else if (ch < 7.5) c = vec3(0.3, 1.0, 0.3); else if (ch < 8.5) c = vec3(0.0, 0.7, 0.7); else if (ch < 9.5) c = vec3(0.7, 0.3, 1.0); else c = vec3(0.3, 0.3, 1.0); c *= mix(0.35, 1.0, v_l.y); } ALBEDO = c; }\n")
	# section: keep the half-space dot(n, p) <= d (model space of the mesh); back faces dark red (inside of a hull)
	_diag["section"] = _shader("shader_type spatial;\nrender_mode cull_disabled;\nuniform vec4 plane = vec4(1.0, 0.0, 0.0, 0.0);\nvarying vec3 v_obj;\nvoid vertex(){ v_obj = VERTEX; }\nvoid fragment(){ if (dot(plane.xyz, v_obj) > plane.w) { discard; } ALBEDO = FRONT_FACING ? vec3(0.62) : vec3(0.5, 0.06, 0.05); ROUGHNESS = 0.6; SPECULAR = 0.3; }\n")
	_diag["section_col"] = _shader("shader_type spatial;\nrender_mode cull_disabled;\nuniform vec4 plane = vec4(1.0, 0.0, 0.0, 0.0);\nvarying vec3 v_obj;\nvoid vertex(){ v_obj = VERTEX; }\nvoid fragment(){ if (dot(plane.xyz, v_obj) > plane.w) { discard; } ALBEDO = FRONT_FACING ? (COLOR.a < 0.75 ? vec3(0.75, 0.75, 0.78) : COLOR.rgb) : vec3(0.5, 0.06, 0.05); ROUGHNESS = 0.6; SPECULAR = 0.3; }\n")


## Rig: "day" / "night" (the contact-sheet rig) or "studio" (UI1's showroom). True if something changed.
func _set_rig(rig: String, job: Dictionary) -> bool:
	var changed := rig != _rig or _first
	_rig = rig
	var studio := rig == "studio"
	_fill_light.visible = studio
	for r: OmniLight3D in _rims:
		r.visible = studio and not bool(job.get("no_rims", false))
	if rig == "night":
		_sky_mat.sky_top_color = Color(0.01, 0.014, 0.035)
		_sky_mat.sky_horizon_color = Color(0.03, 0.04, 0.075)
		_sky_mat.ground_bottom_color = Color(0.008, 0.008, 0.012)
		_sky_mat.ground_horizon_color = Color(0.03, 0.035, 0.06)
		_sky_mat.sky_curve = 0.15
		_sky_mat.ground_curve = 0.02
	elif studio:
		_sky_mat.sky_top_color = Color(0.09, 0.1, 0.2)
		_sky_mat.sky_horizon_color = Color(0.92, 0.94, 1.0)
		_sky_mat.sky_curve = 0.09
		_sky_mat.ground_horizon_color = Color(0.3, 0.22, 0.42)
		_sky_mat.ground_bottom_color = Color(0.02, 0.02, 0.05)
		_sky_mat.ground_curve = 0.05
	else:
		_sky_mat.sky_top_color = Color(0.24, 0.44, 0.78)
		_sky_mat.sky_horizon_color = Color(0.7, 0.79, 0.9)
		_sky_mat.ground_bottom_color = Color(0.2, 0.19, 0.17)
		_sky_mat.ground_horizon_color = Color(0.62, 0.68, 0.74)
		_sky_mat.sky_curve = 0.15
		_sky_mat.ground_curve = 0.02
	if studio:
		_env.ambient_light_color = Color(0.46, 0.48, 0.6)
		_env.ambient_light_energy = float(job.get("ambient_energy", 0.42))
		_sun.light_energy = float(job.get("sun_energy", 1.05))
		_sun.light_color = Color(1.0, 0.97, 0.92)
		_env.glow_intensity = 0.25
	else:
		var night := rig == "night"
		_env.ambient_light_color = Color(0.1, 0.12, 0.2) if night else Color(0.6, 0.64, 0.7)
		_env.ambient_light_energy = float(job.get("ambient_energy", 0.55 if night else 1.0))
		_env.glow_intensity = 0.7 if night else 0.25
		_sun.light_energy = float(job.get("sun_energy", 0.1 if night else 0.8))
		_sun.light_color = Color(0.62, 0.72, 1.0) if night else Color(1.0, 0.97, 0.92)
	ModernMaterials.set_global("ce_night", 1.0 if rig == "night" else 0.0)
	ModernMaterials.set_global("ce_sun_color", ModernMaterials.light_value(_sun.light_color, _sun.light_energy))
	ModernMaterials.set_global("ce_ambient", ModernMaterials.light_value(_env.ambient_light_color, _env.ambient_light_energy))
	# the environment the clear coat, metals and glass mirror (as the vehicle layer / contact sheet derive it)
	var amb := _env.ambient_light_color
	var ground := Color(0.30 * amb.r, 0.31 * amb.g, 0.32 * amb.b)
	for cls: String in ["vpbr", "glass"]:
		_mats.set_class_parameter(cls, "env_zenith", _sky_mat.sky_top_color)
		_mats.set_class_parameter(cls, "env_horizon", _sky_mat.sky_horizon_color)
		_mats.set_class_parameter(cls, "env_ground", ground)
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


func _apply_mode(node: Node3D, mode: String, job: Dictionary) -> void:
	if mode == "shaded" or mode == "":
		return
	var sec_mat: ShaderMaterial = null
	if mode.begins_with("section"):
		sec_mat = (_diag[mode] as ShaderMaterial).duplicate()
		var p: Array = job.get("section", [1, 0, 0, 0])
		sec_mat.set_shader_parameter("plane", Vector4(float(p[0]), float(p[1]), float(p[2]), float(p[3])))
	for c: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.name == "shadow":
			if mode == "caster":
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.material_override = _diag["red"]
			elif mode == "caster_only":
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				mi.material_override = _diag["clay"]
			elif mode == "body_caster":
				mi.visible = false
			continue
		if mode == "caster_only":
			mi.visible = false
			continue
		if mode == "body_caster":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			continue
		var mesh := mi.mesh
		match mode:
			"clay", "caster", "wire":
				mi.material_override = _diag["clay"]
			"clay_noglass":
				for s in mesh.get_surface_count():
					mi.set_surface_override_material(s, _diag["discard"] if str(mesh.surface_get_name(s)) == "glass" else _diag["clay"])
			"noglass":
				for s in mesh.get_surface_count():
					if str(mesh.surface_get_name(s)) == "glass":
						mi.set_surface_override_material(s, _diag["discard"])
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
			"section", "section_col":
				# the plane is given in model space: express it in this node's local space
				var pl: Array = job.get("section", [1, 0, 0, 0])
				var n_m := Vector3(float(pl[0]), float(pl[1]), float(pl[2]))
				var tr := mi.transform
				var n_l := tr.basis.transposed() * n_m
				var d_l := float(pl[3]) - n_m.dot(tr.origin)
				var mloc := sec_mat.duplicate() as ShaderMaterial
				mloc.set_shader_parameter("plane", Vector4(n_l.x, n_l.y, n_l.z, d_l))
				for s in mesh.get_surface_count():
					mi.set_surface_override_material(s, _diag["discard"] if str(mesh.surface_get_name(s)) == "glass" else mloc)
		if mode == "wire":
			var w := MeshInstance3D.new()
			w.name = String(mi.name) + "_wire"
			w.mesh = _edges_mesh(mesh)
			w.transform = mi.transform
			w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.get_parent().add_child(w)


func _render(job: Dictionary) -> Dictionary:
	for c: Node in _holder.get_children():
		c.free()
	var meta := {}
	var set_id := str(job.get("set", ""))
	var lod := str(job.get("lod", "lod0"))
	var mode := str(job.get("mode", "shaded"))
	var rig := str(job.get("rig", "night" if bool(job.get("night", false)) else "day"))
	var rig_changed := _set_rig(rig, job)
	var look_race := str(job.get("look", "race")) == "race"
	if job.has("params") or _params_dirty:
		_first_look_force()
	_set_look(look_race)
	_params_dirty = false
	if job.has("params"):
		# [[class, uniform, value], ...] on top of the look (e.g. flake_strength 0 for a reference)
		for pv: Variant in job["params"]:
			var e: Array = pv
			_mats.set_class_parameter(str(e[0]), str(e[1]), e[2])
		_params_dirty = true
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX if str(job.get("tonemap", "agx" if rig == "studio" else "linear")) == "agx" else Environment.TONE_MAPPER_LINEAR
	var gm: StandardMaterial3D = _ground.material_override
	gm.albedo_color = Color(0.2, 0.2, 0.21) if rig != "studio" else Color(0.035, 0.045, 0.1)
	gm.metallic = 0.0 if rig != "studio" else 0.5
	gm.roughness = 0.85 if rig != "studio" else 0.3
	if job.has("ground"):
		var g: Array = job["ground"]
		gm.albedo_color = Color(float(g[0]), float(g[1]), float(g[2]))
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
	# fill light of the player car in the race (vehicle layer PLAYER_FILL)
	var fill := float(job.get("fill", _player_fill if (look_race and rig != "studio" and set_id.begins_with("player/")) else 0.0))
	for gi: Node in node.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).set_instance_shader_parameter(&"fill", fill)
	_apply_mode(node, mode, job)
	var hide: Array = job.get("hide", [])
	var only: Array = job.get("only", [])
	for c: Node in node.get_children():
		var n3 := c as Node3D
		if n3 == null:
			continue
		var base_name := String(n3.name).replace("_wire", "")
		if hide.has(base_name) or (not only.is_empty() and not only.has(base_name) and base_name != "shadow"):
			n3.visible = false
	var wheels: Array = node.get_meta("wheels", [])
	for wp: Variant in wheels:
		var w := node.get_node(wp as NodePath) as Node3D
		var b := w.basis
		if job.has("spin"):
			b = b * Basis(Vector3.RIGHT, deg_to_rad(float(job["spin"])))
		if job.has("steer") and String(w.name).find("wheel_0") >= 0:
			b = Basis(Vector3.UP, deg_to_rad(float(job["steer"]))) * b
		w.basis = b
	var obj: Dictionary = m.get("object", {})
	var length := float(obj.get("length_m", 4.5))
	var width := float(obj.get("width_m", 1.8))
	var yaw := deg_to_rad(float(job.get("yaw", 0.0)))
	if str(job.get("pivot", "center")) == "rear":
		var pz := length * 0.5
		pivot.position = Vector3(0, 0, pz)
		node.position = Vector3(0, 0, -pz)
	pivot.rotation = Vector3(0.0, yaw, 0.0)
	# contact shadow (vehicle layer: strength 0.55 with casters, x0.6 with the lights on at night)
	var shaded := mode in ["shaded", "", "noglass", "body_caster"]
	var contact := bool(job.get("contact", shaded)) and set_id != "" and rig != "studio"
	_cs_node.visible = contact
	if contact:
		var strength := 0.55 * (0.6 if rig == "night" else 1.0)
		var sx := 2.0 * (width * 0.5 + SHADOW_MARGIN_M)
		var sz := 2.0 * (length * 0.5 + SHADOW_MARGIN_M)
		var pose := pivot.transform * node.transform
		_cs_mm.set_instance_transform(0, pose * Transform3D(Basis.from_scale(Vector3(sx, 1.0, sz)), Vector3(0.0, 0.02, 0.0)))
		_cs_mm.set_instance_custom_data(0, Color(strength, width * 0.5, length * 0.5, SHADOW_MARGIN_M))
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
		_cam.projection = Camera3D.PROJECTION_FRUSTUM
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
	elif ctype == "showroom":
		# camera of the Cycles showroom sprites (contact_sheet.gd _showroom_camera): 142 deg, 56 mm, 11 deg, shift
		var height := float(obj.get("height_m", 1.45))
		var sel := deg_to_rad(11.0)
		var dist := 1.72 * length
		var target := Vector3(0.0, height * 0.4, 0.0)
		var a := deg_to_rad(142.0)
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		_cam.position = target + Vector3(sin(a) * cos(sel), sin(sel), cos(a) * cos(sel)) * dist
		_cam.look_at(target, Vector3.UP)
		_cam.keep_aspect = Camera3D.KEEP_WIDTH
		_cam.fov = rad_to_deg(2.0 * atan(18.0 / 56.0))
		_cam.near = 0.1
		_cam.far = 500.0
		_cam.v_offset = -0.03 * 2.0 * dist * (18.0 / 56.0)
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
	# sun / key light: camera space by default (upper left, from the viewer's side, as the sprite rig), or world
	# space; the studio key is fixed in the world (UI1: rotation -52, -28)
	var to_sun: Vector3
	if rig == "studio" and not job.has("sun_world"):
		_sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
		to_sun = -_sun.global_transform.basis.z
	else:
		if job.has("sun_world"):
			to_sun = _v3(job["sun_world"], Vector3(0.4, 0.8, 0.4)).normalized()
		else:
			to_sun = (_cam.basis * _v3(job.get("sun", [-0.55, 0.92, 0.55]), Vector3(-0.55, 0.92, 0.55))).normalized()
		_sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	ModernMaterials.set_global("ce_sun_dir", to_sun)
	_sun.directional_shadow_max_distance = float(job.get("shadow_dist", 120.0 if ctype == "game" else maxf(30.0, radius * 6.0)))
	for i in int(job.get("settle", 16 if (_first or rig_changed) else 5)):
		await process_frame
	_first = false
	await RenderingServer.frame_post_draw
	var img := _sv.get_texture().get_image()
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
	meta["prims_shadow"] = _sv.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	meta["cam_pos"] = [_cam.position.x, _cam.position.y, _cam.position.z]
	return {"img": img, "meta": meta}
