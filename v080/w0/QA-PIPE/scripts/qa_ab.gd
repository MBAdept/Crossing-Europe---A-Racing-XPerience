extends SceneTree
## QA: renders the real-time models from the cameras of their Cycles sprites (for A/B pictures) and free views.
## Run under Xvfb:  godot --path . --rendering-driver opengl3 --audio-driver Dummy -s qa_ab.gd -- --out=<dir> [--jobs=<file.json>]
## jobs: [{"name", "set", "lod", "mode": "ortho"|"game"|"free", "night": bool, "size": [w, h], "width_m", "anchor": [ax, ay],
##         "elevation", "yaw" (model turned about Y, degrees), "pivot": [x, y, z] (model point at the anchor),
##         "lamp_a": [..], "lamp_b": [..], "cam_pos": [x,y,z], "cam_target": [x,y,z], "fov", "ground": bool, "sun": [x,y,z],
##         "impostor": bool, "caster": bool, "paint": "#rrggbb", "fade": 0..1, "bg": "#rrggbb"}]

var _args: Dictionary = {}
var _mats: ModernMaterials
var _sv: SubViewport
var _cam: Camera3D
var _sun: DirectionalLight3D
var _env: Environment
var _ground: MeshInstance3D
var _holder: Node3D


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_run.call_deferred()


func _build_rig(night: bool, size: Vector2i) -> void:
	if _sv != null:
		_sv.queue_free()
		await process_frame
	_sv = SubViewport.new()
	_sv.size = size
	_sv.own_world_3d = true
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv.msaa_3d = Viewport.MSAA_4X
	root.add_child(_sv)
	_env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	if night:
		sm.sky_top_color = Color(0.01, 0.014, 0.035)
		sm.sky_horizon_color = Color(0.03, 0.04, 0.075)
		sm.ground_bottom_color = Color(0.008, 0.008, 0.012)
		sm.ground_horizon_color = Color(0.03, 0.035, 0.06)
	else:
		sm.sky_top_color = Color(0.24, 0.44, 0.78)
		sm.sky_horizon_color = Color(0.7, 0.79, 0.9)
		sm.ground_bottom_color = Color(0.2, 0.19, 0.17)
		sm.ground_horizon_color = Color(0.62, 0.68, 0.74)
	sky.sky_material = sm
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.1, 0.12, 0.2) if night else Color(0.6, 0.64, 0.7)
	_env.ambient_light_energy = 0.55 if night else 1.0
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.adjustment_enabled = true
	_env.glow_enabled = true
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_env.glow_intensity = 0.7 if night else 0.25
	_env.glow_bloom = 0.0
	_env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = _env
	_sv.add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.light_energy = 0.1 if night else 0.8
	_sun.light_color = Color(0.62, 0.72, 1.0) if night else Color(1.0, 0.97, 0.92)
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
	ModernMaterials.set_global("ce_night", 1.0 if night else 0.0)
	ModernMaterials.set_global("ce_sun_color", ModernMaterials.light_value(_sun.light_color, _sun.light_energy))
	ModernMaterials.set_global("ce_ambient", ModernMaterials.light_value(_env.ambient_light_color, _env.ambient_light_energy))
	ModernMaterials.set_global("ce_time", 1.7)
	ModernMaterials.set_global("ce_wind", Vector4(1.0, 0.0, 0.3, 0.0))


func _v3(a: Variant, d: Vector3) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return d


func _v4(a: Variant) -> Vector4:
	if a is Array and (a as Array).size() >= 4:
		return Vector4(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	return Vector4.ZERO


func _run() -> void:
	var out_dir := str(_args.get("out", ""))
	var jobs: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(_args.get("jobs", ""))))
	if out_dir == "" or not jobs is Array:
		print("qa_ab: --out=<dir> --jobs=<file.json>")
		quit(1)
		return
	_mats = ModernMaterials.new()
	var last_key := ""
	var n := 0
	for j: Dictionary in jobs:
		var night := bool(j.get("night", false))
		var sz: Array = j.get("size", [640, 420])
		var size := Vector2i(int(sz[0]), int(sz[1]))
		var key := "%s|%s" % [str(night), str(size)]
		if key != last_key:
			await _build_rig(night, size)
			last_key = key
			for i in 12:
				await process_frame
		for c: Node in _holder.get_children():
			c.free()
		var set_id := str(j.get("set", ""))
		var r := ModelDB.resolve(set_id)
		var m: Dictionary = r.get("model", {})
		var vehicle := str(m.get("kind", "")) in ["vehicle", "heavy"]
		var gm: StandardMaterial3D = _ground.material_override
		gm.albedo_color = Color(str(j.get("bg", "#333336" if vehicle else "#38541f")))
		gm.roughness = 0.85 if vehicle else 0.95
		_ground.visible = bool(j.get("ground", true))
		var node: Node3D = null
		if bool(j.get("impostor", false)):
			node = ModelFactory.build_impostor(set_id, _mats)
		else:
			node = ModelFactory.build(set_id, str(j.get("lod", "")), _mats)
		if node == null:
			print("qa_ab: %s: kein Modell für %s / %s" % [str(j.get("name", "")), set_id, str(j.get("lod", ""))])
			continue
		var turn := Node3D.new()
		_holder.add_child(turn)
		turn.add_child(node)
		var pivot := _v3(j.get("pivot", null), Vector3.ZERO)
		node.position = -pivot
		turn.rotation.y = deg_to_rad(float(j.get("yaw", 0.0)))
		if j.has("lamp_a") or j.has("lamp_b"):
			ModelFactory.set_lamps(node, _v4(j.get("lamp_a", null)), _v4(j.get("lamp_b", null)))
		if j.has("paint"):
			ModelFactory.apply_paint(node, {"paint": str(j["paint"]), "metal": float(j.get("metal", 0.3))})
		if j.has("fade"):
			ModelFactory.set_instance_parameter(node, "fade", float(j["fade"]))
		if j.has("sun_mask"):
			ModelFactory.set_instance_parameter(node, "sun", float(j["sun_mask"]))
		if bool(j.get("caster", false)):
			for c: Node in node.get_children():
				var mi := c as MeshInstance3D
				mi.visible = mi.name == "shadow"
				if mi.name == "shadow":
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if night and not vehicle and bool(j.get("omni", true)):
			for l: Variant in m.get("lights", []):
				var ld: Dictionary = l
				if str(ld.get("role", "")) != "lights":
					continue
				var om := OmniLight3D.new()
				var lp: Array = ld.get("pos", [0, 0, 0])
				om.position = Vector3(float(lp[0]), float(lp[1]) - 0.4, float(lp[2]))
				om.light_color = Color(str(ld.get("color", "#fff0cf")))
				om.light_energy = 3.0
				om.omni_range = 18.0
				node.add_child(om)
		var mode := str(j.get("mode", "free"))
		var radius := 10.0
		var bb: Array = m.get("aabb", [-1, 0, -1, 1, 2, 1])
		radius = (Vector3(float(bb[3]), float(bb[4]), float(bb[5])) - Vector3(float(bb[0]), float(bb[1]), float(bb[2]))).length() * 0.5
		if mode == "ortho":
			# camera of the sprite rig (tools/blender/cesprites/rig.py frame_ortho), in model axes
			var th := deg_to_rad(float(j.get("elevation", 6.0)))
			var wm := float(j.get("width_m", 10.0))
			var hm := wm * float(size.y) / float(size.x)
			var an: Array = j.get("anchor", [0.5, 0.95])
			var rr := Vector3(1, 0, 0)
			var uu := Vector3(0, cos(th), -sin(th))
			var ff := Vector3(0, -sin(th), -cos(th))
			var dist := 400.0
			_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			_cam.keep_aspect = Camera3D.KEEP_WIDTH
			_cam.size = wm
			_cam.near = 1.0
			_cam.far = 2000.0
			_cam.basis = Basis(rr, uu, -ff)
			_cam.position = -(float(an[0]) - 0.5) * wm * rr - (0.5 - float(an[1])) * hm * uu - dist * ff
		elif mode == "game":
			# the game camera (contract D12): behind the car, no pitch, horizon at 0.45 H, focal 711 px at 720 px height
			var near := 1.0
			var h_logical := 720.0
			var fsize := near * h_logical / 711.0
			_cam.keep_aspect = Camera3D.KEEP_HEIGHT
			_cam.set_frustum(fsize, Vector2(0.0, -0.05 * fsize), near, 2600.0)
			_cam.basis = Basis.IDENTITY
			_cam.position = Vector3(float(j.get("cam_x", 0.0)), float(j.get("cam_h", 3.4)), float(j.get("cam_dist", 9.0)))
		else:
			_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			_cam.keep_aspect = Camera3D.KEEP_HEIGHT
			_cam.fov = float(j.get("fov", 30.0))
			var cp := _v3(j.get("cam_pos", null), Vector3(4, 2, 6))
			var ct := _v3(j.get("cam_target", null), Vector3(0, 0.7, 0))
			_cam.position = cp
			_cam.look_at(ct, Vector3.UP)
			_cam.near = maxf(0.05, cp.distance_to(ct) * 0.02)
			_cam.far = cp.distance_to(ct) * 4.0 + 2000.0
		var sv := _v3(j.get("sun", null), Vector3(-0.55, 0.92, 0.55))
		var to_sun := (_cam.basis * sv).normalized()
		if bool(j.get("sun_world", false)):
			to_sun = sv.normalized()
		_sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
		ModernMaterials.set_global("ce_sun_dir", to_sun)
		_sun.directional_shadow_max_distance = maxf(30.0, radius * 6.0) if mode != "ortho" else 600.0
		for i in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := _sv.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		var path := out_dir.path_join(str(j.get("name", "job%d" % n)) + ".png")
		img.save_png(path)
		n += 1
	print("qa_ab: %d Bilder -> %s" % [n, out_dir])
	quit(0)
