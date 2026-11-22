extends SceneTree
## scratch: the opaque and the translucent variant of the landmark materials at keep = 1 must look the same
## (lit vcol on the domed church, picture on a test texture), sun with shadow + ambient as in the race.
const L := preload("res://scripts/race3d/builders/landmarks.gd")

func _initialize() -> void:
	_run.call_deferred()

func _shot(variant: String, blend: bool, mesh: Mesh) -> Image:
	var b = L.new()
	var root3 := Node3D.new()
	root.add_child(root3)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.6, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.45, 0.45)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	root3.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0.0)
	sun.shadow_enabled = true
	root3.add_child(sun)
	var cam := Camera3D.new()
	root3.add_child(cam)
	cam.look_at_from_position(Vector3(40, 40, 160), Vector3(0, 35, -20))
	cam.make_current()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m: ShaderMaterial = b._material(variant, blend)
	m.set_shader_parameter("lm_fade", Vector4(1.0, 0.0, 0.0, 0.0))
	mi.material_override = m
	root3.add_child(mi)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	root3.queue_free()
	await process_frame
	return img

func _run() -> void:
	ModernMaterials.ensure_globals()
	ModernMaterials.set_global("ce_sun_dir", Vector3(0.3, 0.7, 0.5).normalized())
	ModernMaterials.set_global("ce_sun_color", ModernMaterials.light_value(Color.WHITE, 1.0))
	ModernMaterials.set_global("ce_ambient", ModernMaterials.light_value(Color(0.45, 0.45, 0.45), 1.0))
	ModernMaterials.set_global("ce_fog_range", Vector2(5000.0, 9000.0))
	var pm: Dictionary = L.proc_mesh({"proc": "domed_church", "height_m": 80.0, "wall": "#f0ece2", "dome": "#6f9c86"})
	var a: Image = await _shot("vcol", false, pm["mesh"])
	var b2: Image = await _shot("vcol", true, pm["mesh"])
	var da := a.get_data()
	var db := b2.get_data()
	var n := 0
	var sum := 0.0
	var mx := 0
	var step := 3 if a.get_format() == Image.FORMAT_RGB8 else 4
	for i in range(0, da.size(), step):
		var d := maxi(absi(da[i] - db[i]), maxi(absi(da[i + 1] - db[i + 1]), absi(da[i + 2] - db[i + 2])))
		if d > 0:
			n += 1
		sum += d
		mx = maxi(mx, d)
	a.save_png("/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7b/shots/blend_opaque.png")
	b2.save_png("/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7b/shots/blend_blend.png")
	print("BLENDPROBE pixels differing %d of %d, mean %.3f, max %d" % [n, da.size() / step, sum / float(da.size() / step), mx])
	quit(0)
