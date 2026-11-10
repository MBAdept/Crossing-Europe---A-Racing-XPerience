extends "res://probe_base.gd"

var bend_shader: Shader
var mats: Dictionary = {}

func bmat(color: Color, rough: float = 0.8, metal: float = 0.0, emission: Color = Color(0, 0, 0)) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = bend_shader
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("metallic", metal)
	m.set_shader_parameter("emission_color", emission)
	return m

# Replace every StandardMaterial3D override in the world by the bend shader with the same colours.
func convert_all(margin: float) -> void:
	for c: Node in world.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		var sm: StandardMaterial3D = mi.material_override as StandardMaterial3D
		if sm == null:
			continue
		var em := Color(0, 0, 0)
		if sm.emission_enabled:
			em = sm.emission * sm.emission_energy_multiplier
		mi.material_override = bmat(sm.albedo_color, sm.roughness, sm.metallic, em)
		mi.extra_cull_margin = margin

func set_margin(margin: float) -> void:
	for c: Node in world.find_children("*", "GeometryInstance3D", true, false):
		var gi: GeometryInstance3D = c
		gi.extra_cull_margin = margin

func setup_bend(shader_path: String) -> void:
	bend_shader = load(shader_path)
	base_scene(true, true)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 250.0
	# subdivided road + ground so that the bend is smooth (25 m chunks, 2 m quads along z)
	for c: Node in world.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is PlaneMesh:
			c.queue_free()
	var road_m := mat(Color(0.13, 0.13, 0.14), 0.75)
	var grass_m := mat(Color(0.22, 0.42, 0.16), 0.95)
	for i: int in range(48):
		var z: float = 12.5 - float(i) * 25.0
		for spec: Array in [[15.0, 0.0, road_m, 0.0], [300.0, -157.5, grass_m, -0.03], [300.0, 157.5, grass_m, -0.03]]:
			var p := PlaneMesh.new()
			p.size = Vector2(spec[0], 25.0)
			p.subdivide_depth = 11
			p.subdivide_width = 0 if float(spec[0]) < 20.0 else 11
			add_mesh(world, p, Vector3(spec[1], spec[3], z), spec[2])
	# extra far scenery left and right (rows of big boxes) to make culling visible
	for i: int in range(30):
		for sx: float in [-1.0, 1.0]:
			box(world, Vector3(10, 14, 10), Vector3(sx * (120.0 + float(i % 3) * 60.0), 7.0, -60.0 - float(i) * 30.0), mat(Color(0.75, 0.5, 0.3) if sx < 0.0 else Color(0.3, 0.5, 0.75), 0.8))

func set_globals(curve: float, hill: float) -> void:
	RenderingServer.global_shader_parameter_set("bend_origin", cam.global_position)
	RenderingServer.global_shader_parameter_set("bend_params", Vector4(curve, hill, 0.0, 0.0))

func add_globals() -> void:
	if not RenderingServer.global_shader_parameter_get_list().has(&"bend_origin"):
		RenderingServer.global_shader_parameter_add("bend_origin", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3.ZERO)
		RenderingServer.global_shader_parameter_add("bend_params", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4.ZERO)

func test_bend() -> void:
	add_globals()
	setup_bend("res://bend.gdshader")
	await frames(2)
	convert_all(0.0)
	set_globals(0.0, 0.0)
	await variant("0_straight_no_bend")
	set_globals(0.0016, 0.0)
	await variant("1_curve_right_r625_margin0")
	set_margin(2000.0)
	await variant("2_curve_right_r625_margin2000")
	set_globals(-0.0016, -0.0006)
	await variant("3_curve_left_crest_margin2000")
	set_globals(0.0010, 0.0008)
	await variant("4_curve_right_valley_margin2000")
	get_viewport().debug_draw = Viewport.DEBUG_DRAW_DIRECTIONAL_SHADOW_ATLAS
	await variant("4_shadow_atlas_debug", false)
	get_viewport().debug_draw = Viewport.DEBUG_DRAW_DISABLED
	# positional light on bent geometry: lamp placed at the bent position by script
	night()
	set_globals(0.0016, 0.0)
	var unbent := Vector3(-8.5, 7.0, -60.0)
	var d: float = cam.global_position.z - unbent.z
	var bent := unbent + Vector3(0.5 * 0.0016 * d * d, 0.0, 0.0)
	omni(world, bent, 30.0, 4.0)
	sphere(world, 0.4, unbent, bmat(Color(0, 0, 0), 0.5, 0.0, Color(4, 3, 1.6)))
	spot(world, Vector3(-0.6, 0.7, -2.3), Vector3(-0.9, 0.0, -45.0), 70.0, 28.0, 6.0)
	spot(world, Vector3(0.6, 0.7, -2.3), Vector3(0.9, 0.0, -45.0), 70.0, 28.0, 6.0)
	await variant("5_night_lamp_at_bent_position_margin2000")
	set_margin(0.0)
	await variant("6_night_lamp_margin0")

func test_bend_wrong() -> void:
	add_globals()
	setup_bend("res://bend_wrong.gdshader")
	await frames(2)
	convert_all(2000.0)
	set_globals(0.0016, 0.0)
	await variant("0_bend_relative_to_pass_camera")
