extends SceneTree
# Do sky reflections reach metallic surfaces in a SubViewport (Compatibility)? Custom light() vs built-in.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var mats := ModernMaterials.new()
	var sv := SubViewport.new()
	sv.size = Vector2i(960, 320)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.24, 0.44, 0.78)
	sm.sky_horizon_color = Color(0.7, 0.79, 0.9)
	sm.ground_bottom_color = Color(0.2, 0.19, 0.17)
	sm.ground_horizon_color = Color(0.62, 0.68, 0.74)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	var mode := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			mode = a.substr(7)
	if mode.begins_with("color"):
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.62, 0.69, 0.8)
		env.ambient_light_energy = 0.75
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.adjustment_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, 205.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sv.add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.2, 9)
	cam.fov = 30
	sv.add_child(cam)
	# row of spheres: StandardMaterial metal 1 rough 0.1 | metal 0.7 rough 0.45 | vpbr equivalents
	var defs := [[1.0, 0.1], [0.7, 0.45], [0.0, 0.5]]
	for i in defs.size():
		var s := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.6; sp.height = 1.2
		s.mesh = sp
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#9ea3a8")
		m.metallic = defs[i][0]
		m.roughness = defs[i][1]
		s.material_override = m
		s.position = Vector3(-3.6 + i * 1.4, 1.2, 0)
		sv.add_child(s)
	# vpbr spheres built as ArrayMesh with vertex data
	for i in defs.size():
		var sp2 := SphereMesh.new()
		sp2.radius = 0.6; sp2.height = 1.2
		var arr := sp2.get_mesh_arrays()
		var n := (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var cols := PackedColorArray(); cols.resize(n)
		var uv := PackedVector2Array(); uv.resize(n)
		var uv2 := PackedVector2Array(); uv2.resize(n)
		for k in n:
			cols[k] = Color("#9ea3a8")
			uv[k] = Vector2(defs[i][1], defs[i][0])
			uv2[k] = Vector2(-1, 0)
		arr[Mesh.ARRAY_COLOR] = cols
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_TEX_UV2] = uv2
		arr[Mesh.ARRAY_TANGENT] = null
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var s2 := MeshInstance3D.new()
		s2.mesh = am
		var vm: ShaderMaterial = mats.material("vpbr")
		if mode.ends_with("nolight"):
			var sh := Shader.new()
			var code: String = vm.shader.code
			sh.code = code.substr(0, code.find("float d_ggx"))
			vm = ShaderMaterial.new()
			vm.shader = sh
		s2.material_override = vm
		s2.position = Vector3(0.6 + i * 1.4, 1.2, 0)
		sv.add_child(s2)
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	sv.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit(0)
