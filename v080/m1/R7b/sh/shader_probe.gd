extends SceneTree
## scratch: compile every variant of landmark.gdshader once (Xvfb), on a procedural mesh and a quad
const L := preload("res://scripts/race3d/builders/landmarks.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var b = L.new()
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 40, 200)
	var pm: Dictionary = L.proc_mesh({"proc": "skyscrapers", "height_m": 250.0})
	var tv: Dictionary = L.proc_mesh({"proc": "lighthouse", "height_m": 51.0})
	var n := 0
	for v: String in ["picture", "atlas", "atlas_cutout", "vcol", "glow"]:
		for blend: bool in [false, true]:
			var mi := MeshInstance3D.new()
			mi.mesh = pm["mesh"] if v == "vcol" else (tv["glow_mesh"] if v == "glow" else PropLibrary.standin_mesh(10, 10, 0.5, 1.0))
			var m: ShaderMaterial = b._material(v, blend)
			m.set_shader_parameter("lm_fade", Vector4(0.6, 0.2, 0.8, 0.1))
			mi.material_override = m
			mi.position = Vector3(float(n) * 30.0 - 150.0, 0, 0)
			root.add_child(mi)
			n += 1
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	print("PROBE done %d" % n)
	quit(0)
