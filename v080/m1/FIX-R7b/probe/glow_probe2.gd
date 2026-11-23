extends SceneTree
## FIX-R7b probe: red pixels of the Florianturm's aviation light at Dortmund 22:00 for variants of the glow material.

func _initialize() -> void:
	_run.call_deferred()


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


func _red(img: Image) -> String:
	var n := 0
	var x0 := 9999
	var x1 := -1
	var y0 := 9999
	var y1 := -1
	for y in range(100, 400):
		for x in range(400, 900):
			var c := img.get_pixel(x, y)
			if c.r8 >= 110 and c.r8 > 1.8 * c.g8 and c.r8 > 1.8 * c.b8:
				n += 1
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
	return "%d rote px, bbox %d..%d x %d..%d" % [n, x0, x1, y0, y1]


func _run() -> void:
	root.get_node("Settings").call("disarm_crash_guard")
	var setup := {"mode": "single", "race_id": "", "stage_id": "bremen_dortmund", "from_city": "bremen", "vehicle": "limousine",
		"start_world_minutes": 22.0 * 60.0, "weather": "normal", "start_km": 225.0, "autopilot": true, "autopilot_refuel": "never",
		"seed": 11, "gfx": "modern", "no_countdown": true, "start_speed_kmh": 0.0, "traffic_warmup": false}
	CliArgs.all()["no-traffic"] = true
	CliArgs.all()["gfx-sync"] = true
	var sc: Node = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	var n := 0
	while not bool(sc.call("is_live")) and n < 3000:
		await process_frame
		n += 1
	for i in 30:
		await process_frame
	for c: Node in sc.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer >= 5:
			(c as CanvasLayer).visible = false
	paused = true
	await process_frame
	var r: Object = sc.get("renderer")
	var world: Node = r.get("world")
	var glow: ShaderMaterial = null
	for c: Node in world.get_children():
		if str(c.name).begins_with("Landmark"):
			for gi: Node in c.get_children():
				var mi := gi as MeshInstance3D
				if mi != null and mi.material_override is ShaderMaterial and (mi.material_override as ShaderMaterial).shader.code.contains("#define CE_GLOW"):
					glow = mi.material_override
	var img := await _grab()
	img.save_png("/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7b/probe/g_a.png")
	print("PROBE a wie gebaut: ", _red(img))
	glow.set_shader_parameter("viewport_h", 7200.0)
	await process_frame
	img = await _grab()
	print("PROBE b viewport_h 7200: ", _red(img))
	glow.set_shader_parameter("viewport_h", 720.0)
	glow.set_shader_parameter("viewport_h", 720.0)
	var orig: String = glow.shader.code
	var variants := {
		"e viewport_h als Konstante": orig.replace("PROJECTION_MATRIX[1][1] * viewport_h * 0.5", "PROJECTION_MATRIX[1][1] * 720.0 * 0.5"),
		"f P11 als Konstante": orig.replace("PROJECTION_MATRIX[1][1] * viewport_h * 0.5", "1.974 * viewport_h * 0.5"),
		"g beides konstant": orig.replace("PROJECTION_MATRIX[1][1] * viewport_h * 0.5", "1.974 * 720.0 * 0.5"),
		"h UV2.y konstant": orig.replace("UV2.y / max(px_per_m, 1.0e-4)", "2.5 / max(px_per_m, 1.0e-4)"),
	}
	for k: String in variants:
		var shv := Shader.new()
		shv.code = variants[k]
		print("PROBE ersetzt ", k, " ", shv.code != orig)
		glow.shader = shv
		await process_frame
		await process_frame
		img = await _grab()
		print("PROBE ", k, ": ", _red(img))
	quit(0)
