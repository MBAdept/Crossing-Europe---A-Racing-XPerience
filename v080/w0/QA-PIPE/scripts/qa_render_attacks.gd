extends SceneTree
## QA render attacks (Xvfb + OpenGL): runtime shader globals, sprite stand-ins through billboard.gdshader, mirrored
## nodes, MultiMesh with instance uniforms, threaded loading with the real renderer, release_all while drawing,
## texture memory. --out=<dir>  [--early-shader] (loads a Modern shader BEFORE the globals exist)

var _out := ""
var _sv: SubViewport
var _cam: Camera3D
var _sun: DirectionalLight3D
var _env: Environment
var _holder: Node3D
var _n_ok := 0
var _n_bad := 0


func _say(ok: bool, text: String) -> void:
	if ok:
		_n_ok += 1
	else:
		_n_bad += 1
	print("%s %s" % ["  ok   " if ok else "  FAIL ", text])


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	_run.call_deferred()


func _tex_mem() -> float:
	return float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)) / 1048576.0


func _rig(night: bool, size: Vector2i) -> void:
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
	sm.sky_top_color = Color(0.01, 0.014, 0.035) if night else Color(0.24, 0.44, 0.78)
	sm.sky_horizon_color = Color(0.03, 0.04, 0.075) if night else Color(0.7, 0.79, 0.9)
	sm.ground_bottom_color = Color(0.008, 0.008, 0.012) if night else Color(0.2, 0.19, 0.17)
	sm.ground_horizon_color = Color(0.03, 0.035, 0.06) if night else Color(0.62, 0.68, 0.74)
	sky.sky_material = sm
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.1, 0.12, 0.2) if night else Color(0.6, 0.64, 0.7)
	_env.ambient_light_energy = 0.55 if night else 1.0
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.adjustment_enabled = true
	var we := WorldEnvironment.new()
	we.environment = _env
	_sv.add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.light_energy = 0.1 if night else 0.8
	_sun.light_color = Color(0.62, 0.72, 1.0) if night else Color(1.0, 0.97, 0.92)
	_sun.shadow_enabled = true
	_sun.rotation_degrees = Vector3(-38.0, 205.0, 0.0)
	_sv.add_child(_sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6000.0, 6000.0)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.22, 0.33, 0.14)
	ground.material_override = gm
	_sv.add_child(ground)
	_cam = Camera3D.new()
	_sv.add_child(_cam)
	_holder = Node3D.new()
	_sv.add_child(_holder)
	ModernMaterials.set_global("ce_night", 1.0 if night else 0.0)
	ModernMaterials.set_global("ce_sun_color", ModernMaterials.light_value(_sun.light_color, _sun.light_energy))
	ModernMaterials.set_global("ce_ambient", ModernMaterials.light_value(_env.ambient_light_color, _env.ambient_light_energy))
	ModernMaterials.set_global("ce_sun_dir", -_sun.global_transform.basis.z * -1.0)
	ModernMaterials.set_global("ce_time", 1.7)
	ModernMaterials.set_global("ce_wind", Vector4(1.0, 0.0, 0.3, 0.0))
	for i in 10:
		await process_frame


func _shot(name: String) -> Image:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := _sv.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(_out.path_join(name + ".png"))
	return img


func _sprite_meta(sid: String) -> Dictionary:
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/manifest.json"))
	return man["sets"][sid]


## Stand-in of a sprite-only set: a billboard of the base cell (and the light layer) of the Arcade sprite sheet.
func _stand_in(sid: String, mats: ModernMaterials) -> MeshInstance3D:
	var s := _sprite_meta(sid)
	var tex := load("res://assets/sprites/" + str(s["file"])) as Texture2D
	var cell: Array = s["cell"]
	var layers: Array = s["layers"]
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var base := Rect2(0.0, 0.0, float(cell[0]) / w, float(cell[1]) / h)
	var lights := Rect2()
	if layers.has("lights"):
		lights = Rect2(0.0, float(cell[1]) * float(layers.find("lights")) / h, float(cell[0]) / w, float(cell[1]) / h)
	var width_m := float(s["image_width_m"])
	var height_m := width_m * float(cell[1]) / float(cell[0])
	var an: Array = s["anchor"]
	var mi := MeshInstance3D.new()
	mi.mesh = ModelFactory.billboard_mesh(width_m, height_m * float(an[1]), float(an[0]))
	# the quad's y = 0 is the ground line of the picture: only the part above the anchor row is shown here
	var mat := mats.billboard(tex, Rect2(base.position, Vector2(base.size.x, base.size.y * float(an[1]))),
		Rect2(lights.position, Vector2(lights.size.x, lights.size.y * float(an[1]))) if lights.size.x > 0.0 else Rect2())
	mi.material_override = mat
	return mi


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	print("== E1 nothing declared in the project")
	var declared: Array = []
	for p: Dictionary in ProjectSettings.get_property_list():
		if str(p["name"]).begins_with("shader_globals/"):
			declared.append(p["name"])
	_say(declared.is_empty(), "project.godot declares no shader globals (%s)" % str(declared))
	if OS.get_cmdline_user_args().has("--early-shader"):
		print("== E2 a Modern shader loaded BEFORE ModernMaterials registered the globals")
		var sh := load("res://assets/shaders/modern/vpbr.gdshader") as Shader
		var m := ShaderMaterial.new()
		m.shader = sh
		await _rig(false, Vector2i(640, 420))
		var mi0 := MeshInstance3D.new()
		mi0.mesh = SphereMesh.new()
		mi0.material_override = m
		_holder.add_child(mi0)
		_cam.position = Vector3(0, 1, 4)
		_cam.look_at(Vector3(0, 0.3, 0))
		await _shot("e2_early_shader_before_globals")
		ModernMaterials.ensure_globals()
		await _shot("e2_early_shader_after_globals")
		mi0.queue_free()
	var t_mem0 := _tex_mem()
	print("== E3 ModernMaterials twice")
	var mats := ModernMaterials.new()
	var mats_b := ModernMaterials.new()
	_say(true, "two ModernMaterials instances created (look for 'already exists' errors above/below)")
	mats_b = null
	await _rig(false, Vector2i(960, 540))
	var mem_rig := _tex_mem()

	print("== D threaded loading with the real renderer")
	var sets: Array = []
	for sid in ModelDB.set_ids():
		if ModelDB.has_model(sid):
			sets.append(sid)
	var t0 := Time.get_ticks_msec()
	ModelDB.request(sets)
	var frames := 0
	var worst := 0.0
	var last := Time.get_ticks_usec()
	while ModelDB.pending() > 0 and frames < 2000:
		await process_frame
		frames += 1
		var now := Time.get_ticks_usec()
		worst = maxf(worst, float(now - last) / 1000.0)
		last = now
	print("   request(%d sets): %d frames, %d ms, longest frame %.1f ms, loads %d, texture memory %.1f -> %.1f MB" % [sets.size(), frames, Time.get_ticks_msec() - t0, worst, ModelDB.loads, mem_rig, _tex_mem()])
	_say(ModelDB.pending() == 0, "pending() == 0")
	var loads_before := ModelDB.loads
	# a small scene: every model once
	var x := -60.0
	var nodes: Array = []
	for sid: String in ["landmarks/michel", "props/farmhouse", "props/tree_oak", "props/streetlight", "traffic/sedan_red", "traffic/sedan_blue", "player/limousine"]:
		var n := ModelFactory.build(sid, "lod0", mats)
		n.position = Vector3(x, 0.0, -40.0 if sid == "landmarks/michel" else 0.0)
		_holder.add_child(n)
		nodes.append(n)
		x += 20.0
	var imp := ModelFactory.build_impostor("props/tree_oak", mats)
	imp.position = Vector3(-35.0, 0.0, 14.0)
	_holder.add_child(imp)
	_say(ModelDB.loads == loads_before, "building every model after request() loads nothing more (%d)" % ModelDB.loads)
	_cam.position = Vector3(10.0, 12.0, 95.0)
	_cam.look_at(Vector3(5.0, 8.0, 0.0))
	_cam.fov = 60.0
	_cam.far = 3000.0
	await _shot("d_all_models_day")
	var mem_models := _tex_mem()
	print("   texture memory with all six models shown: %.1f MB (rig alone %.1f MB)" % [mem_models, mem_rig])

	print("== C release_all() while the models are drawn")
	ModelDB.release_all()
	await _shot("c_after_release_all_still_drawn")
	_say(true, "frames after release_all() rendered")
	for n: Node in _holder.get_children():
		n.free()
	mats.clear()
	for i in 6:
		await process_frame
	var mem_after := _tex_mem()
	print("   texture memory after release_all(), freeing the nodes and ModernMaterials.clear(): %.1f MB (rig alone %.1f MB)" % [mem_after, mem_rig])
	_say(absf(mem_after - mem_rig) <= maxf(0.5, mem_rig * 0.05), "texture memory is back at the baseline (within 5 %)")

	print("== S sprite-only sets through billboard.gdshader (stand-ins), mirrored node")
	mats = ModernMaterials.new()
	for night: bool in [false, true]:
		await _rig(night, Vector2i(1280, 540))
		var xx := -45.0
		for sid: String in ["props/barn", "props/church", "props/tree_pine", "props/fuel_station"]:
			var b := _stand_in(sid, mats)
			b.position = Vector3(xx, 0.0, 0.0)
			_holder.add_child(b)
			xx += 28.0
		var mirrored := _stand_in("props/barn", mats)
		mirrored.position = Vector3(-45.0, 0.0, 30.0)
		mirrored.scale = Vector3(-1.0, 1.0, 1.0)
		_holder.add_child(mirrored)
		var real := ModelFactory.build("props/farmhouse", "lod0", mats)
		real.position = Vector3(70.0, 0.0, 0.0)
		_holder.add_child(real)
		_cam.position = Vector3(10.0, 6.0, 110.0)
		_cam.look_at(Vector3(10.0, 8.0, 0.0))
		_cam.fov = 50.0
		_cam.far = 3000.0
		await _shot("s_stand_ins_%s" % ("night" if night else "day"))
		# the same from the side: billboards turn to the camera
		_cam.position = Vector3(-120.0, 6.0, 60.0)
		_cam.look_at(Vector3(0.0, 8.0, 0.0))
		await _shot("s_stand_ins_%s_side" % ("night" if night else "day"))

	print("== M MultiMesh layers: tree lod1 (2 surfaces) x 60, a mirrored MultiMesh node, instance uniforms on the node")
	await _rig(false, Vector2i(1280, 540))
	var parts := ModelFactory.multimesh_parts("props/tree_oak", "lod1", mats)
	print("   multimesh_parts(props/tree_oak, lod1): %d parts %s" % [parts.size(), str(parts.map(func(p: Dictionary) -> String: return "%s%s" % [str(p["node"]), " (shadow)" if p["shadow"] else ""]))])
	for side: float in [1.0, -1.0]:
		for part: Dictionary in parts:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part["mesh"]
			mm.instance_count = 30
			for i in 30:
				mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, float(i) * 1.3), Vector3(14.0, 0.0, -float(i) * 18.0)))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			if bool(part["shadow"]):
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			else:
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.scale = Vector3(side, 1.0, 1.0)
			_holder.add_child(mmi)
	# street lights as one MultiMesh per side, the left one mirrored; "fade" as an instance uniform of the node
	var lp := ModelFactory.multimesh_parts("props/streetlight", "lod0", mats)
	for side: float in [1.0, -1.0]:
		var mm2 := MultiMesh.new()
		mm2.transform_format = MultiMesh.TRANSFORM_3D
		mm2.mesh = lp[0]["mesh"]
		mm2.instance_count = 20
		for i in 20:
			mm2.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(8.0, 0.0, -float(i) * 30.0)))
		var mmi2 := MultiMeshInstance3D.new()
		mmi2.multimesh = mm2
		mmi2.scale = Vector3(side, 1.0, 1.0)
		if side < 0.0:
			mmi2.set_instance_shader_parameter("fade", 0.5)
		_holder.add_child(mmi2)
	_cam.position = Vector3(0.0, 3.4, 30.0)
	_cam.look_at(Vector3(0.0, 4.0, -100.0))
	_cam.fov = 55.0
	_cam.far = 3000.0
	await _shot("m_multimesh_trees_lights")
	print("QA render_attacks: %d ok, %d FAIL" % [_n_ok, _n_bad])
	quit(0)
