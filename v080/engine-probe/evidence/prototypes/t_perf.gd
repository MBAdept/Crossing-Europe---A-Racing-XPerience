extends "res://probe_base.gd"
# CPU-side proxies: cost per draw call (engine + Mesa, tiny window so that rasterising is negligible),
# cost of moving objects from GDScript.

func tiny_world() -> void:
	world = Node3D.new()
	add_child(world)
	cam = Camera3D.new()
	cam.position = Vector3(0, 30, 60)
	cam.far = 2000.0
	world.add_child(cam)
	cam.look_at(Vector3(0, 0, -60))
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3, 0.4, 0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.5)
	wenv = WorldEnvironment.new()
	wenv.environment = env
	world.add_child(wenv)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	world.add_child(sun)

func med(a: Array[float]) -> float:
	a.sort()
	return snappedf(a[a.size() / 2], 0.001)

func measure(n: int = 40) -> Dictionary:
	var vp_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	await frames(4)
	var cpu: Array[float] = []
	var setup: Array[float] = []
	var wall: Array[float] = []
	var t0 := Time.get_ticks_usec()
	for i: int in range(n):
		await get_tree().process_frame
		var t1 := Time.get_ticks_usec()
		wall.append(float(t1 - t0) / 1000.0)
		t0 = t1
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp_rid))
		setup.append(RenderingServer.get_frame_setup_time_cpu())
	return {"render_cpu_ms": med(cpu), "setup_cpu_ms": med(setup), "frame_wall_ms": med(wall), "draw_calls": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)), "objects": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))}

func test_drawcalls() -> void:
	tiny_world()
	note("window_size", get_window().size)
	var bm := BoxMesh.new()
	bm.size = Vector3(1, 1, 1)
	var m1 := mat(Color(0.8, 0.3, 0.2))
	var mats_many: Array[StandardMaterial3D] = []
	for i: int in range(16):
		mats_many.append(mat(Color.from_hsv(float(i) / 16.0, 0.7, 0.9), 0.3 + 0.04 * float(i), 0.1 * float(i % 3)))
	note("n0", await measure())
	var nodes: Array[MeshInstance3D] = []
	for target: int in [500, 1000, 2000, 4000]:
		while nodes.size() < target:
			var i := nodes.size()
			var mi := MeshInstance3D.new()
			mi.mesh = bm
			mi.material_override = m1
			mi.position = Vector3(float(i % 80) * 1.6 - 64.0, 0.5, -float(i / 80) * 1.6)
			world.add_child(mi)
			nodes.append(mi)
		note("same_material_n%d" % target, await measure())
	# 16 different materials interleaved (state changes)
	for i: int in range(nodes.size()):
		nodes[i].material_override = mats_many[i % 16]
	note("16_materials_n4000", await measure())
	# sun shadows on (4 splits)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 300.0
	note("16_materials_n4000_shadow_pssm4", await measure())
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	note("16_materials_n4000_shadow_pssm2", await measure())
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	note("16_materials_n4000_shadow_ortho", await measure())
	sun.shadow_enabled = false
	# moving all nodes from GDScript each frame
	var t0 := Time.get_ticks_usec()
	for rep: int in range(10):
		for i: int in range(nodes.size()):
			nodes[i].position = Vector3(float(i % 80) * 1.6 - 64.0, 0.5 + 0.01 * float(rep), -float(i / 80) * 1.6)
	note("gdscript_set_position_4000_nodes_us", float(Time.get_ticks_usec() - t0) / 10.0)
	t0 = Time.get_ticks_usec()
	for rep: int in range(10):
		for i: int in range(nodes.size()):
			nodes[i].transform = Transform3D(Basis.IDENTITY, Vector3(float(i % 80) * 1.6 - 64.0, 0.5 + 0.01 * float(rep), -float(i / 80) * 1.6))
	note("gdscript_set_transform_4000_nodes_us", float(Time.get_ticks_usec() - t0) / 10.0)
	# the same through RenderingServer instances (no nodes)
	for nd: MeshInstance3D in nodes:
		nd.queue_free()
	nodes.clear()
	await frames(3)
	var rids: Array[RID] = []
	var scenario := get_viewport().find_world_3d().scenario
	for i: int in range(4000):
		var rid := RenderingServer.instance_create2(bm.get_rid(), scenario)
		RenderingServer.instance_geometry_set_material_override(rid, mats_many[i % 16].get_rid())
		RenderingServer.instance_set_transform(rid, Transform3D(Basis.IDENTITY, Vector3(float(i % 80) * 1.6 - 64.0, 0.5, -float(i / 80) * 1.6)))
		rids.append(rid)
	note("rs_instances_16_materials_n4000", await measure())
	t0 = Time.get_ticks_usec()
	for rep: int in range(10):
		for i: int in range(4000):
			RenderingServer.instance_set_transform(rids[i], Transform3D(Basis.IDENTITY, Vector3(float(i % 80) * 1.6 - 64.0, 0.5 + 0.01 * float(rep), -float(i / 80) * 1.6)))
	note("gdscript_rs_instance_set_transform_4000_us", float(Time.get_ticks_usec() - t0) / 10.0)
	# all of them moving every frame: render cost with dirty transforms
	var moving: Array[float] = []
	var vp_rid := get_viewport().get_viewport_rid()
	for f: int in range(30):
		for i: int in range(4000):
			RenderingServer.instance_set_transform(rids[i], Transform3D(Basis.IDENTITY, Vector3(float(i % 80) * 1.6 - 64.0, 0.5 + 0.01 * float(f), -float(i / 80) * 1.6)))
		await get_tree().process_frame
		moving.append(RenderingServer.viewport_get_measured_render_time_cpu(vp_rid))
	note("render_cpu_ms_when_4000_instances_move_each_frame", med(moving))
	for rid: RID in rids:
		RenderingServer.free_rid(rid)
	# one MultiMesh with 4000 boxes
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = bm
	mm.instance_count = 4000
	for i: int in range(4000):
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(float(i % 80) * 1.6 - 64.0, 0.5, -float(i / 80) * 1.6)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m1
	world.add_child(mmi)
	note("multimesh_n4000", await measure())
	note("local_rendering_device_available", RenderingServer.create_local_rendering_device() != null)

# Per-pixel cost proxies: a scene with few triangles that fills the screen, effects toggled one by one.
# llvmpipe shades on the CPU: ratios hint at relative shader cost, absolute values mean nothing for a GPU.
func test_fill() -> void:
	tiny_world()
	cam.position = Vector3(0, 2.5, 8)
	cam.look_at(Vector3(0, 0.8, -30))
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	plane(world, Vector2(400, 800), Vector3(0, 0, -300), mat(Color(0.2, 0.22, 0.2), 0.6))
	for i: int in range(40):
		box(world, Vector3(2, 1.5, 4.5), Vector3(float(i % 3) * 4.0 - 4.0, 0.75, -6.0 - float(i) * 9.0), mat(Color.from_hsv(float(i) / 40.0, 0.7, 0.8), 0.3, 0.4))
		box(world, Vector3(6, 12, 6), Vector3(-14.0 if i % 2 == 0 else 14.0, 6.0, -10.0 - float(i) * 12.0), mat(Color(0.6, 0.58, 0.55), 0.8))
	var vp := get_viewport()
	var res: Dictionary = {}
	var order: Array[String] = []
	var m: Callable = func(tag: String) -> void:
		await frames(6)
		var t: Array[float] = []
		var t0 := Time.get_ticks_usec()
		for i: int in range(24):
			await RenderingServer.frame_post_draw
			var t1 := Time.get_ticks_usec()
			t.append(float(t1 - t0) / 1000.0)
			t0 = t1
		t.sort()
		res[tag] = snappedf(t[6], 0.1)
		order.append(tag)
	for rep: int in range(2):
		var sfx := "" if rep == 0 else "_run2"
		await m.call("0_base_no_shadow" + sfx)
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 150.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		await m.call("1_shadow_ortho" + sfx)
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		await m.call("1_shadow_pssm4" + sfx)
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
		await m.call("1_shadow_pssm4_hard" + sfx)
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
		await m.call("1_shadow_pssm4_soft_ultra" + sfx)
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		env.fog_enabled = true
		env.fog_density = 0.003
		await m.call("2_plus_fog" + sfx)
		env.glow_enabled = true
		await m.call("3_plus_glow" + sfx)
		env.adjustment_enabled = true
		env.adjustment_saturation = 1.1
		await m.call("4_plus_adjustments" + sfx)
		env.ssao_enabled = true
		for q: int in [0, 2, 4]:
			RenderingServer.environment_set_ssao_quality(q, true, 0.5, 2, 50.0, 300.0)
			await m.call("5_plus_ssao_q%d" % q + sfx)
		env.ssao_enabled = false
		vp.msaa_3d = Viewport.MSAA_2X
		await m.call("6_glow_fog_msaa2x" + sfx)
		vp.msaa_3d = Viewport.MSAA_4X
		await m.call("6_glow_fog_msaa4x" + sfx)
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.scaling_3d_scale = 0.75
		await m.call("7_glow_fog_scale0.75" + sfx)
		vp.scaling_3d_scale = 0.5
		await m.call("7_glow_fog_scale0.5" + sfx)
		vp.scaling_3d_scale = 1.0
		var l1 := spot(world, Vector3(-0.6, 0.7, 6), Vector3(-0.9, 0.0, -45.0), 70.0, 28.0, 6.0)
		var l2 := spot(world, Vector3(0.6, 0.7, 6), Vector3(0.9, 0.0, -45.0), 70.0, 28.0, 6.0)
		await m.call("8_plus_2_spots" + sfx)
		var lamps: Array[OmniLight3D] = []
		for i: int in range(6):
			lamps.append(omni(world, Vector3(8.0 if i % 2 == 0 else -8.0, 6.0, -5.0 - float(i) * 10.0), 22.0, 3.0))
		await m.call("8_plus_6_omnis" + sfx)
		l1.shadow_enabled = true
		await m.call("8_plus_1_spot_shadow" + sfx)
		l1.queue_free()
		l2.queue_free()
		for l: OmniLight3D in lamps:
			l.queue_free()
		env.glow_enabled = false
		env.fog_enabled = false
		env.adjustment_enabled = false
		sun.shadow_enabled = false
	for tag: String in order:
		print("PROBE: fill ", tag, " = ", res[tag], " ms")
	report["fill_ms"] = res

# Runtime mesh streaming: cost of building road/terrain chunk meshes from GDScript.
func test_chunkgen() -> void:
	tiny_world()
	var m := mat(Color(0.2, 0.2, 0.22), 0.7)
	for spec: Array in [[12, 25], [24, 50], [4, 25]]:
		var nx: int = spec[0]
		var nz: int = spec[1]
		var t_fill := 0
		var t_mesh := 0
		var t_node := 0
		var count := 60
		var verts_n := 0
		for c: int in range(count):
			var t0 := Time.get_ticks_usec()
			var verts := PackedVector3Array()
			var norms := PackedVector3Array()
			var uvs := PackedVector2Array()
			var idx := PackedInt32Array()
			verts.resize((nx + 1) * (nz + 1))
			norms.resize((nx + 1) * (nz + 1))
			uvs.resize((nx + 1) * (nz + 1))
			idx.resize(nx * nz * 6)
			var k := 0
			for iz: int in range(nz + 1):
				var z: float = -float(iz)
				var curve: float = 0.0004 * z * z
				for ix: int in range(nx + 1):
					var x: float = float(ix) * 1.25 - 7.5
					verts[k] = Vector3(x + curve, sin(z * 0.05) * 0.5, z - float(c) * float(nz))
					norms[k] = Vector3.UP
					uvs[k] = Vector2(float(ix) / float(nx), float(iz) * 0.1)
					k += 1
			var q := 0
			for iz: int in range(nz):
				for ix: int in range(nx):
					var a: int = iz * (nx + 1) + ix
					idx[q] = a
					idx[q + 1] = a + 1
					idx[q + 2] = a + nx + 1
					idx[q + 3] = a + 1
					idx[q + 4] = a + nx + 2
					idx[q + 5] = a + nx + 1
					q += 6
			var t1 := Time.get_ticks_usec()
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_NORMAL] = norms
			arrays[Mesh.ARRAY_TEX_UV] = uvs
			arrays[Mesh.ARRAY_INDEX] = idx
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			am.surface_set_material(0, m)
			var t2 := Time.get_ticks_usec()
			var mi := MeshInstance3D.new()
			mi.mesh = am
			world.add_child(mi)
			var t3 := Time.get_ticks_usec()
			t_fill += t1 - t0
			t_mesh += t2 - t1
			t_node += t3 - t2
			verts_n = verts.size()
		note("chunk_%dx%d_quads" % [nx, nz], {"vertices": verts_n, "triangles": nx * nz * 2, "gdscript_fill_ms": snappedf(float(t_fill) / float(count) / 1000.0, 0.001), "arraymesh_create_ms": snappedf(float(t_mesh) / float(count) / 1000.0, 0.001), "node_add_ms": snappedf(float(t_node) / float(count) / 1000.0, 0.001)})
		await frames(2)
	# freeing nodes
	var t4 := Time.get_ticks_usec()
	var n_free := 0
	for c: Node in world.get_children():
		if c is MeshInstance3D:
			c.queue_free()
			n_free += 1
	await frames(2)
	note("queue_free_per_chunk_ms_incl_2_frames", snappedf(float(Time.get_ticks_usec() - t4) / float(n_free) / 1000.0, 0.001))
