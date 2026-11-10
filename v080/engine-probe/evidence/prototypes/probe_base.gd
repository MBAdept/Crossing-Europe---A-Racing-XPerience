extends Node
# Shared helpers for the engine capability probe.

var out_dir := "user://"
var suite_name := ""
var cur_test := ""
var report: Dictionary = {}
var world: Node3D
var cam: Camera3D
var wenv: WorldEnvironment
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var last_img: Image

func begin_test(t: String) -> void:
	cur_test = t
	report = {"test": t, "suite": suite_name, "variants": []}

func end_test() -> void:
	var path := out_dir.path_join("%s_%s.json" % [suite_name, cur_test])
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	if world != null:
		world.queue_free()
		world = null
	for c: Node in get_children():
		c.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func note(key: String, value: Variant) -> void:
	report[key] = value
	print("PROBE: ", key, " = ", value)

# ---------------------------------------------------------------- scene helpers

func mat(color: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m

func emat(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.02, 0.02, 0.02)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m

func add_mesh(parent: Node, mesh: Mesh, pos: Vector3, m: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if m != null:
		mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

func box(parent: Node, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return add_mesh(parent, b, pos, m)

func sphere(parent: Node, r: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return add_mesh(parent, s, pos, m)

func cyl(parent: Node, r: float, h: float, pos: Vector3, m: Material, top_r: float = -1.0) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.bottom_radius = r
	c.top_radius = r if top_r < 0.0 else top_r
	c.height = h
	return add_mesh(parent, c, pos, m)

func plane(parent: Node, size: Vector2, pos: Vector3, m: Material, sub: int = 0) -> MeshInstance3D:
	var p := PlaneMesh.new()
	p.size = size
	p.subdivide_width = sub
	p.subdivide_depth = sub
	return add_mesh(parent, p, pos, m)

func car(parent: Node, pos: Vector3, color: Color, lights: bool = false) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	var paint := mat(color, 0.25, 0.4)
	box(n, Vector3(1.8, 0.7, 4.4), Vector3(0, 0.65, 0), paint)
	box(n, Vector3(1.6, 0.55, 2.2), Vector3(0, 1.25, 0.2), mat(Color(0.08, 0.1, 0.12), 0.1, 0.0))
	var tyre := mat(Color(0.03, 0.03, 0.03), 0.9)
	for sx: float in [-0.85, 0.85]:
		for sz: float in [-1.4, 1.4]:
			var w := cyl(n, 0.33, 0.25, Vector3(sx, 0.33, sz), tyre)
			w.rotation_degrees = Vector3(0, 0, 90)
	if lights:
		var tail := emat(Color(1.0, 0.05, 0.02), 3.0)
		box(n, Vector3(0.45, 0.14, 0.05), Vector3(-0.6, 0.8, 2.21), tail)
		box(n, Vector3(0.45, 0.14, 0.05), Vector3(0.6, 0.8, 2.21), tail)
		var head := emat(Color(1.0, 0.95, 0.8), 4.0)
		box(n, Vector3(0.4, 0.14, 0.05), Vector3(-0.6, 0.7, -2.21), head)
		box(n, Vector3(0.4, 0.14, 0.05), Vector3(0.6, 0.7, -2.21), head)
	return n

func tree(parent: Node, pos: Vector3, h: float = 7.0) -> void:
	cyl(parent, 0.25, h * 0.45, pos + Vector3(0, h * 0.225, 0), mat(Color(0.28, 0.18, 0.1), 0.9))
	sphere(parent, h * 0.3, pos + Vector3(0, h * 0.68, 0), mat(Color(0.12, 0.36, 0.1), 0.9))

func base_scene(with_sky: bool = true, with_cars_lights: bool = false) -> void:
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.near = 0.2
	cam.far = 1500.0
	cam.position = Vector3(0.0, 2.6, 7.5)
	world.add_child(cam)
	cam.look_at(Vector3(0.0, 0.9, -30.0))
	cam.current = true
	env = Environment.new()
	if with_sky:
		sky_mat = ProceduralSkyMaterial.new()
		var sky := Sky.new()
		sky.sky_material = sky_mat
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.45, 0.6, 0.8)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.5, 0.55, 0.6)
		env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	wenv = WorldEnvironment.new()
	wenv.environment = env
	world.add_child(wenv)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, -48.0, 0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = false
	world.add_child(sun)
	# ground + road
	plane(world, Vector2(3000, 3000), Vector3(0, -0.05, -600), mat(Color(0.22, 0.42, 0.16), 0.95))
	plane(world, Vector2(15.0, 1400.0), Vector3(0, 0.0, -650), mat(Color(0.13, 0.13, 0.14), 0.75))
	var white := mat(Color(0.9, 0.9, 0.88), 0.6)
	for i: int in range(70):
		for lx: float in [-2.5, 2.5]:
			box(world, Vector3(0.15, 0.02, 3.0), Vector3(lx, 0.01, 4.0 - float(i) * 9.0), white)
	for sx: float in [-7.2, 7.2]:
		box(world, Vector3(0.2, 0.02, 1400.0), Vector3(sx, 0.01, -650), white)
		box(world, Vector3(0.08, 0.35, 700.0), Vector3(sx * 1.14, 0.6, -340), mat(Color(0.6, 0.62, 0.65), 0.4, 0.8))
		for i: int in range(60):
			box(world, Vector3(0.1, 0.8, 0.1), Vector3(sx * 1.14, 0.4, 5.0 - float(i) * 6.0), mat(Color(0.5, 0.5, 0.52), 0.5, 0.6))
	# cars
	var colors: Array[Color] = [Color(0.8, 0.05, 0.05), Color(0.1, 0.25, 0.75), Color(0.85, 0.85, 0.85), Color(0.9, 0.7, 0.05), Color(0.05, 0.05, 0.06), Color(0.1, 0.5, 0.2)]
	car(world, Vector3(0.0, 0.0, 0.0), Color(0.75, 0.02, 0.02), with_cars_lights)
	for i: int in range(10):
		var lane: float = [-5.0, 0.0, 5.0][i % 3]
		car(world, Vector3(lane, 0.0, -14.0 - float(i) * 17.0), colors[i % colors.size()], with_cars_lights)
	# truck
	box(world, Vector3(2.5, 3.0, 9.0), Vector3(5.0, 2.0, -42.0), mat(Color(0.85, 0.85, 0.8), 0.6))
	# trees + buildings
	for i: int in range(40):
		tree(world, Vector3(-13.0 - float(i % 4) * 5.0, 0.0, -6.0 - float(i) * 9.0), 6.0 + float(i % 3) * 1.5)
		tree(world, Vector3(13.0 + float((i + 2) % 4) * 6.0, 0.0, -2.0 - float(i) * 11.0), 7.0 + float(i % 2) * 2.0)
	for i: int in range(8):
		box(world, Vector3(14, 18 + (i % 3) * 9, 14), Vector3(-45.0 - float(i % 2) * 22.0, 9.0 + float(i % 3) * 4.5, -120.0 - float(i) * 34.0), mat(Color(0.6, 0.57, 0.52), 0.8))
	# glossy probes near the camera
	sphere(world, 0.6, Vector3(-3.4, 0.6, -3.0), mat(Color(0.9, 0.9, 0.9), 0.05, 1.0))
	sphere(world, 0.6, Vector3(3.4, 0.6, -3.0), mat(Color(0.9, 0.3, 0.1), 0.35, 0.0))

# ---------------------------------------------------------------- capture + stats

func frames(n: int) -> void:
	for i: int in range(n):
		await get_tree().process_frame

func grab() -> Image:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img.get_format() != Image.FORMAT_RGBA8 and img.get_format() != Image.FORMAT_RGB8:
		# HDR 2D: the viewport texture is linear half float
		img.convert(Image.FORMAT_RGBA8)
	return img

func stats() -> Dictionary:
	var vp := get_viewport()
	return {
		"draw_calls_total": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives_total": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)),
		"objects_total": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)),
		"vis_draw_calls": vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"vis_primitives": vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		"vis_objects": vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME),
		"shadow_draw_calls": vp.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"shadow_primitives": vp.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		"shadow_objects": vp.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_OBJECTS_IN_FRAME),
		"canvas_draw_calls": vp.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"video_mem_mb": snappedf(float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)) / 1048576.0, 0.1),
		"texture_mem_mb": snappedf(float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)) / 1048576.0, 0.1),
		"buffer_mem_mb": snappedf(float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)) / 1048576.0, 0.1),
	}

# Median frame time (ms, wall clock) over n frames; llvmpipe = software rasteriser, so this is
# a CPU fill-rate proxy only.
func frame_ms(n: int = 12) -> Dictionary:
	var vp_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	await get_tree().process_frame
	var times: Array[float] = []
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var t0 := Time.get_ticks_usec()
	for i: int in range(n):
		await get_tree().process_frame
		var t1 := Time.get_ticks_usec()
		times.append(float(t1 - t0) / 1000.0)
		t0 = t1
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp_rid) + RenderingServer.get_frame_setup_time_cpu())
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp_rid))
	times.sort()
	cpu.sort()
	gpu.sort()
	return {"frame_ms_median": snappedf(times[n / 2], 0.01), "frame_ms_min": snappedf(times[0], 0.01), "render_cpu_ms_median": snappedf(cpu[n / 2], 0.01), "render_gpu_ms_median": snappedf(gpu[n / 2], 0.01)}

# Captures a variant: waits, screenshots, collects stats (and timing when asked).
func variant(vname: String, timing: bool = true, settle: int = 4) -> Image:
	await frames(settle)
	var img: Image = await grab()
	var path := out_dir.path_join("%s_%s_%s.png" % [suite_name, cur_test, vname])
	img.save_png(path)
	var entry: Dictionary = {"name": vname, "png": path}
	entry.merge(stats())
	if timing:
		entry.merge(await frame_ms())
	if last_img != null and last_img.get_size() == img.get_size():
		var m: Dictionary = img.compute_image_metrics(last_img, false)
		entry["diff_vs_prev_mean"] = snappedf(float(m["mean"]), 0.0001)
		entry["diff_vs_prev_max"] = snappedf(float(m["max"]), 0.0001)
	last_img = img
	var variants: Array = report["variants"]
	variants.append(entry)
	var line := "PROBE: variant %s" % vname
	for k: String in ["vis_draw_calls", "vis_primitives", "vis_objects", "shadow_draw_calls", "shadow_primitives", "canvas_draw_calls", "frame_ms_median", "render_cpu_ms_median", "render_gpu_ms_median", "diff_vs_prev_mean", "diff_vs_prev_max"]:
		if entry.has(k):
			line += " | %s=%s" % [k, str(entry[k])]
	print(line)
	return img

func diff(a: Image, b: Image) -> Dictionary:
	var m: Dictionary = a.compute_image_metrics(b, false)
	return {"mean": snappedf(float(m["mean"]), 0.0001), "max": snappedf(float(m["max"]), 0.0001), "psnr": snappedf(float(m["peak_snr"]), 0.01)}

# Night setup: dark sky/ambient, weak moon light.
func night() -> void:
	if sky_mat != null:
		sky_mat.sky_top_color = Color(0.01, 0.015, 0.04)
		sky_mat.sky_horizon_color = Color(0.04, 0.05, 0.09)
		sky_mat.ground_bottom_color = Color(0.01, 0.01, 0.015)
		sky_mat.ground_horizon_color = Color(0.04, 0.05, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.10, 0.12, 0.2)
	env.ambient_light_energy = 0.35
	sun.light_color = Color(0.55, 0.65, 1.0)
	sun.light_energy = 0.12

func spot(parent: Node, pos: Vector3, target: Vector3, range_m: float, angle: float, energy: float, color: Color = Color(1, 0.95, 0.85)) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.spot_range = range_m
	l.spot_angle = angle
	l.light_energy = energy
	l.light_color = color
	l.spot_attenuation = 1.0
	parent.add_child(l)
	l.position = pos
	l.look_at_from_position(pos, target, Vector3.UP)
	return l

func omni(parent: Node, pos: Vector3, range_m: float, energy: float, color: Color = Color(1.0, 0.75, 0.4)) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.omni_range = range_m
	l.light_energy = energy
	l.light_color = color
	l.position = pos
	parent.add_child(l)
	return l
