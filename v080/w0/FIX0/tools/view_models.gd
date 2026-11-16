extends SceneTree
## Fix-wave helper (scratch, not part of the repository): renders models through ModelFactory / ModernMaterials
## for a list of jobs and writes one PNG per job plus a sheet.
##   godot --path . --rendering-driver opengl3 --audio-driver Dummy -s view_models.gd -- --jobs=<file.json> --out=<dir> [--sheet=<png>] [--cols=4]
## job: {"name", "set", "lod", "night": bool, "lamp_a": [4], "lamp_b": [4], "size": [w, h], "target": [x, y, z],
##       "yaw": deg (0 = from behind, +Z side), "el": deg, "dist": m, "fov": deg, "text", "glow": bool, "ground": bool}

var _args := {}
var _mats: ModernMaterials


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_run.call_deferred()


func _rig(night: bool, size: Vector2i, glow: bool) -> Dictionary:
	var sv := SubViewport.new()
	sv.size = size
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.msaa_3d = Viewport.MSAA_4X
	root.add_child(sv)
	var env := Environment.new()
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
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.1, 0.12, 0.2) if night else Color(0.6, 0.64, 0.7)
	env.ambient_light_energy = 0.55 if night else 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.adjustment_enabled = true
	env.glow_enabled = glow
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_intensity = 0.7 if night else 0.25
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.1 if night else 0.8
	sun.light_color = Color(0.62, 0.72, 1.0) if night else Color(1.0, 0.97, 0.92)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.0
	sv.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6000.0, 6000.0)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.2, 0.2, 0.21)
	gm.roughness = 0.85
	ground.material_override = gm
	sv.add_child(ground)
	var cam := Camera3D.new()
	sv.add_child(cam)
	var holder := Node3D.new()
	sv.add_child(holder)
	var label := Label.new()
	label.position = Vector2(6.0, float(size.y) - 24.0)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 5)
	sv.add_child(label)
	ModernMaterials.set_global("ce_night", 1.0 if night else 0.0)
	ModernMaterials.set_global("ce_sun_color", ModernMaterials.light_value(sun.light_color, sun.light_energy))
	ModernMaterials.set_global("ce_ambient", ModernMaterials.light_value(env.ambient_light_color, env.ambient_light_energy))
	ModernMaterials.set_global("ce_time", 1.7)
	return {"sv": sv, "cam": cam, "sun": sun, "holder": holder, "label": label, "ground": ground}


func _v4(a: Variant) -> Vector4:
	if a is Array and (a as Array).size() == 4:
		return Vector4(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	return Vector4.ZERO


func _run() -> void:
	var jobs: Array = JSON.parse_string(FileAccess.get_file_as_string(str(_args["jobs"])))
	var out := str(_args["out"])
	DirAccess.make_dir_recursive_absolute(out)
	_mats = ModernMaterials.new()
	var tiles: Array = []
	var first := true
	for j: Variant in jobs:
		var job: Dictionary = j
		var sz: Array = job.get("size", [480, 320])
		var size := Vector2i(int(sz[0]), int(sz[1]))
		var night := bool(job.get("night", false))
		var rig := _rig(night, size, bool(job.get("glow", true)))
		var node: Node3D = null
		if str(job.get("lod", "")) == "impostor":
			node = ModelFactory.build_impostor(str(job["set"]), _mats)
		else:
			node = ModelFactory.build(str(job["set"]), str(job.get("lod", "")), _mats)
		if node != null:
			(rig["holder"] as Node3D).add_child(node)
			ModelFactory.set_lamps(node, _v4(job.get("lamp_a")), _v4(job.get("lamp_b")))
			if job.has("paint"):
				ModelFactory.apply_paint(node, {"paint": str(job["paint"]), "metal": 0.3})
			if job.get("caster", false):
				for c: Node in node.get_children():
					var mi := c as MeshInstance3D
					mi.visible = mi.name == "shadow"
		(rig["ground"] as MeshInstance3D).visible = bool(job.get("ground", true))
		var t: Array = job.get("target", [0.0, 0.7, 0.0])
		var target := Vector3(float(t[0]), float(t[1]), float(t[2]))
		var yaw := deg_to_rad(float(job.get("yaw", 0.0)))
		var el := deg_to_rad(float(job.get("el", 8.0)))
		var dir := Vector3(sin(yaw) * cos(el), sin(el), cos(yaw) * cos(el))
		var cam: Camera3D = rig["cam"]
		cam.fov = float(job.get("fov", 30.0))
		cam.position = target + dir * float(job.get("dist", 8.0))
		cam.look_at(target, Vector3.UP)
		cam.near = 0.05
		cam.far = 3000.0
		var sunv: Array = job.get("sun", [-0.55, 0.92, 0.55])
		var to_sun := (cam.basis * Vector3(float(sunv[0]), float(sunv[1]), float(sunv[2]))).normalized()
		(rig["sun"] as DirectionalLight3D).basis = Basis.looking_at(-to_sun, Vector3.UP)
		ModernMaterials.set_global("ce_sun_dir", to_sun)
		(rig["label"] as Label).text = str(job.get("text", job.get("name", "")))
		for i in (16 if first else 5):
			await process_frame
		first = false
		await RenderingServer.frame_post_draw
		var img: Image = (rig["sv"] as SubViewport).get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.save_png(out.path_join(str(job["name"]) + ".png"))
		tiles.append(img)
		(rig["sv"] as SubViewport).queue_free()
		await process_frame
	if _args.has("sheet") and not tiles.is_empty():
		var cols := mini(int(str(_args.get("cols", "4"))), tiles.size())
		var w := 0
		var h := 0
		for im: Image in tiles:
			w = maxi(w, im.get_width())
			h = maxi(h, im.get_height())
		var rows := int(ceil(float(tiles.size()) / float(cols)))
		var sheet := Image.create(cols * w, rows * h, false, Image.FORMAT_RGB8)
		sheet.fill(Color(0.1, 0.1, 0.1))
		for i in tiles.size():
			var im: Image = tiles[i]
			sheet.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i((i % cols) * w, (i / cols) * h))
		sheet.save_png(str(_args["sheet"]))
	print("VIEW %d Bilder -> %s" % [tiles.size(), out])
	quit(0)
