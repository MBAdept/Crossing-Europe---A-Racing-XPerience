extends Node3D
## Synthesis probe 2: (T1) VPBR-L vertex format through a compressed .res + instance uniforms + runtime global uniform,
## (T7) mirrored MultiMeshInstance3D node, (T3) frustum camera with constant focal at 16:9 / 16:10 / 21:9.

var results := {}

func quad(st: Dictionary, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, code: float, rough: float, metal: float, lamp: Vector2) -> void:
	var n := (b - a).cross(d - a).normalized()
	# Godot front faces are clockwise: write a, b, c, d so that the given normal faces the viewer
	var base: int = st["v"].size()
	for p: Vector3 in [a, b, c, d]:
		st["v"].append(p)
		st["n"].append(n)
		st["c"].append(Color(col.r, col.g, col.b, code))
		st["uv"].append(Vector2(rough, metal))
		st["uv2"].append(lamp)
	for i in [0, 2, 1, 0, 3, 2]:
		st["i"].append(base + i)

func build_mesh() -> ArrayMesh:
	var st := {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "uv": PackedVector2Array(), "uv2": PackedVector2Array(), "i": PackedInt32Array()}
	var none := Vector2(-1.0, 0.0)
	# five tiles in a row on the XY plane facing +Z; x from -2.5 .. 2.5; the tile at +x (E) is the asymmetric marker
	var cols := [Color(0.8, 0.8, 0.8), Color(0.2, 0.6, 0.2), Color(0.8, 0.8, 0.8), Color(1.0, 0.1, 0.05), Color(1.0, 0.9, 0.5)]
	var codes := [0.0, 1.0, 0.25, 1.0, 1.0]
	var lamps := [none, none, none, Vector2(1.5, 1.0), Vector2(12.5, 1.0)]
	for k in 5:
		var x0 := -2.5 + float(k)
		quad(st, Vector3(x0, 0, 0), Vector3(x0 + 0.9, 0, 0), Vector3(x0 + 0.9, 0.9, 0), Vector3(x0, 0.9, 0), cols[k], codes[k], 0.6, 0.0, lamps[k])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = st["v"]
	arr[Mesh.ARRAY_NORMAL] = st["n"]
	arr[Mesh.ARRAY_COLOR] = st["c"]
	arr[Mesh.ARRAY_TEX_UV] = st["uv"]
	arr[Mesh.ARRAY_TEX_UV2] = st["uv2"]
	arr[Mesh.ARRAY_INDEX] = st["i"]
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, null, "vpbr", Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
	var mesh := im.get_mesh()
	mesh.resource_scene_unique_id = "mesh0"
	var err := ResourceSaver.save(mesh, "user://probe_vpbr.res", ResourceSaver.FLAG_COMPRESS)
	var back: ArrayMesh = ResourceLoader.load("user://probe_vpbr.res", "", ResourceLoader.CACHE_MODE_IGNORE)
	var fmt := back.surface_get_format(0)
	var a2 := back.surface_get_arrays(0)
	var c2: PackedColorArray = a2[Mesh.ARRAY_COLOR]
	var u2: PackedVector2Array = a2[Mesh.ARRAY_TEX_UV2]
	var u1: PackedVector2Array = a2[Mesh.ARRAY_TEX_UV]
	var codes_back := []
	var lamps_back := []
	for k in 5:
		codes_back.append(snappedf(c2[k * 4].a, 0.001))
		lamps_back.append([snappedf(u2[k * 4].x, 0.001), snappedf(u2[k * 4].y, 0.001)])
	results["t1_save_err"] = err
	results["t1_compress_flag"] = (fmt & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES) != 0
	results["t1_codes_back"] = codes_back
	results["t1_lamps_back"] = lamps_back
	results["t1_uv_back"] = [snappedf(u1[0].x, 0.001), snappedf(u1[0].y, 0.001)]
	results["t1_surface_name"] = back.surface_get_name(0)
	return back

func px(img: Image, p: Vector2) -> String:
	var c := img.get_pixelv(Vector2i(p))
	return "%d,%d,%d" % [roundi(c.r * 255.0), roundi(c.g * 255.0), roundi(c.b * 255.0)]

func grab() -> Image:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()

func _ready() -> void:
	RenderingServer.global_shader_parameter_add("ce_night", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.6
	env.adjustment_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-20, 0, 0)
	sun.light_energy = 0.4
	add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 6.0
	cam.position = Vector3(0, 0.45, 5)
	add_child(cam)
	var mesh := build_mesh()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://vpbr.gdshader")
	# row 1 (y = +1.6): instance A blue paint, lamps off; row 2 (y = 0): instance B red paint + yellow paint2, brake on
	var a := MeshInstance3D.new(); a.mesh = mesh; a.material_override = mat; a.position = Vector3(0, 1.6, 0); add_child(a)
	a.set_instance_shader_parameter("paint", Color(0.05, 0.1, 0.9))
	a.set_instance_shader_parameter("paint2", Color(0.9, 0.9, 0.9))
	var b := MeshInstance3D.new(); b.mesh = mesh; b.material_override = mat; b.position = Vector3(0, 0.0, 0); add_child(b)
	b.set_instance_shader_parameter("paint", Color(0.9, 0.05, 0.05))
	b.set_instance_shader_parameter("paint2", Color(0.9, 0.8, 0.05))
	b.set_instance_shader_parameter("lamp_a", Vector4(0, 1, 0, 0))
	# row 3 (y = -1.6): MultiMeshInstance3D with node scale.x = -1 (mirrored), one instance
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D.IDENTITY)
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.material_override = mat
	mmi.position = Vector3(0, -1.6, 0); mmi.scale = Vector3(-1, 1, 1); add_child(mmi)
	mmi.set_instance_shader_parameter("paint", Color(0.05, 0.8, 0.8))
	mmi.set_instance_shader_parameter("paint2", Color(0.6, 0.2, 0.8))
	var img: Image = await grab()
	img.save_png("user://t1_day.png")
	var W := float(img.get_width()); var H := float(img.get_height())
	var ppu := H / 6.0
	var at := func(x: float, y: float) -> Vector2: return Vector2(W * 0.5 + x * ppu, H * 0.5 - (y - 0.45) * ppu)
	var rows := {"A": 1.6, "B": 0.0, "M": -1.6}
	for r: String in rows:
		var line := []
		for k in 5:
			var xc := -2.5 + float(k) + 0.45
			line.append(px(img, at.call(xc, float(rows[r]) + 0.45)))
		results["t1_row_" + r] = line
	RenderingServer.global_shader_parameter_set("ce_night", 1.0)
	b.set_instance_shader_parameter("lamp_a", Vector4(0, 0, 0, 0))
	b.set_instance_shader_parameter("fade", 0.5)
	img = await grab()
	img.save_png("user://t1_night_flag.png")
	var line2 := []
	for k in 5:
		line2.append(px(img, at.call(-2.5 + float(k) + 0.45, 1.6 + 0.45)))
	results["t1_row_A_night_global"] = line2
	# fraction of row B pixels that survive fade 0.5 (tile 1, fixed green)
	var cnt := 0; var tot := 0
	var p0: Vector2 = at.call(-1.5 + 0.1, 0.8); var p1: Vector2 = at.call(-1.5 + 0.8, 0.1)
	for yy in range(int(p0.y), int(p1.y)):
		for xx in range(int(p0.x), int(p1.x)):
			tot += 1
			if img.get_pixel(xx, yy).g > 0.2:
				cnt += 1
	results["t1_fade_half_coverage"] = snappedf(float(cnt) / float(maxi(1, tot)), 0.01)
	# --- T7b: same multimesh, mirrored vs. not mirrored at the same height: lighting of the fixed green tile
	RenderingServer.global_shader_parameter_set("ce_night", 0.0)
	a.visible = false; b.visible = false
	var t7 := {}
	for sc: float in [-1.0, 1.0]:
		mmi.scale = Vector3(sc, 1, 1)
		img = await grab()
		# green tile centre: x = -1.05 unmirrored, +1.05 mirrored
		t7["scale_%+d_green" % int(sc)] = px(img, at.call(-1.05 * sc, -1.6 + 0.45))
		t7["scale_%+d_paint" % int(sc)] = px(img, at.call(-2.05 * sc, -1.6 + 0.45))
	results["t7_mirrored_vs_plain"] = t7
	# --- T3: frustum camera with constant focal -------------------------------------------
	var focal := 711.0; var cam_h := 3.4; var near := 1.0
	for sz: Vector2i in [Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(1680, 720)]:
		var sv := SubViewport.new(); sv.size = sz; sv.own_world_3d = true; add_child(sv)
		var c3 := Camera3D.new(); sv.add_child(c3)
		var hsize := near * float(sz.y) / focal
		c3.keep_aspect = Camera3D.KEEP_HEIGHT
		for sgn: float in [-1.0, 1.0]:
			c3.set_frustum(hsize, Vector2(0.0, sgn * 0.05 * hsize), near, 2600.0)
			c3.position = Vector3(0, cam_h, 0)
			await get_tree().process_frame
			var maxerr := 0.0
			for dz: float in [6.0, 20.0, 100.0, 600.0]:
				for dx: float in [-12.0, 0.0, 7.5]:
					for hh: float in [0.0, 1.5]:
						var got := c3.unproject_position(Vector3(dx, hh, -dz))
						var want := Vector2(float(sz.x) * 0.5 + dx * focal / dz, 0.45 * float(sz.y) + (cam_h - hh) * focal / dz)
						maxerr = maxf(maxerr, got.distance_to(want))
			results["t3_%dx%d_offset_sign_%+d_maxerr_px" % [sz.x, sz.y, int(sgn)]] = snappedf(maxerr, 0.001)
		sv.queue_free()
	print(JSON.stringify(results, " "))
	var f := FileAccess.open("user://results2.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(results, " "))
	f.close()
	get_tree().quit()
