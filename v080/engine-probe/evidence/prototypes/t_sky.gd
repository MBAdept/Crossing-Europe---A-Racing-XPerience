extends "res://probe_base.gd"

func gloss_road() -> void:
	# wet-looking road section on top of the base road
	plane(world, Vector2(15.0, 200.0), Vector3(0, 0.015, -90.0), mat(Color(0.06, 0.06, 0.065), 0.08, 0.0))

func test_sky() -> void:
	base_scene(true, true)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	cam.position = Vector3(0.0, 2.2, 7.5)
	cam.look_at(Vector3(0.0, 6.0, -30.0))
	var sky: Sky = env.sky
	await variant("0_procedural_default")
	sky_mat.sky_top_color = Color(0.1, 0.3, 0.75)
	sky_mat.sky_horizon_color = Color(0.7, 0.8, 0.9)
	sky_mat.sun_angle_max = 12.0
	sun.rotation_degrees = Vector3(-12.0, 168.0, 0.0)
	await variant("1_procedural_low_sun_ahead")
	var phys := PhysicalSkyMaterial.new()
	sky.sky_material = phys
	await variant("2_physical_low_sun", true, 12)
	sun.rotation_degrees = Vector3(-55.0, 150.0, 0.0)
	await variant("2_physical_high_sun", true, 12)
	sun.rotation_degrees = Vector3(-2.0, 175.0, 0.0)
	phys.turbidity = 6.0
	await variant("2_physical_sunset_turbidity6", true, 12)
	# custom shader sky
	var sm := ShaderMaterial.new()
	sm.shader = load("res://sky_clouds.gdshader")
	sky.sky_material = sm
	sun.rotation_degrees = Vector3(-30.0, 160.0, 0.0)
	await variant("3_custom_clouds_day", true, 12)
	sm.set_shader_parameter("cloud_cover", 0.75)
	sm.set_shader_parameter("top_color", Color(0.25, 0.3, 0.4))
	sm.set_shader_parameter("horizon_color", Color(0.55, 0.58, 0.62))
	sm.set_shader_parameter("cloud_color", Color(0.6, 0.62, 0.66))
	await variant("3_custom_overcast", true, 12)
	sm.set_shader_parameter("cloud_cover", 0.35)
	sm.set_shader_parameter("night", 1.0)
	sm.set_shader_parameter("top_color", Color(0.1, 0.2, 0.6))
	sm.set_shader_parameter("horizon_color", Color(0.4, 0.5, 0.8))
	sm.set_shader_parameter("cloud_color", Color(1, 1, 1))
	night()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	sun.rotation_degrees = Vector3(-25.0, 165.0, 0.0)
	sun.light_energy = 0.25
	await variant("4_custom_night_stars_moon", true, 12)
	env.glow_enabled = true
	await variant("4_custom_night_stars_moon_glow", true, 12)

# Cost of an animated sky: radiance (ambient/reflection) updates per frame vs. static.
func test_skycost() -> void:
	base_scene(true, true)
	gloss_road()
	var sky: Sky = env.sky
	var sm := ShaderMaterial.new()
	sm.shader = load("res://sky_clouds.gdshader")
	sky.sky_material = sm
	sm.set_shader_parameter("use_time", 0.0)
	await frames(20)
	note("process_mode_default", sky.process_mode)
	note("radiance_size_default", sky.radiance_size)
	await variant("0_custom_sky_TIME_in_shader_auto", true, 10)
	for pm: int in [Sky.PROCESS_MODE_QUALITY, Sky.PROCESS_MODE_INCREMENTAL, Sky.PROCESS_MODE_REALTIME]:
		sky.process_mode = pm
		await variant("1_process_mode_%d" % pm, true, 12)
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	for rs: int in [Sky.RADIANCE_SIZE_32, Sky.RADIANCE_SIZE_64, Sky.RADIANCE_SIZE_128, Sky.RADIANCE_SIZE_256]:
		sky.radiance_size = rs
		await variant("2_realtime_radiance_%d" % [[32, 64, 128, 256][rs]], true, 12)
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	# no sky lighting at all: ambient colour, no sky reflections
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.65)
	env.ambient_light_energy = 0.7
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	await variant("3_realtime_sky_but_ambient_color_no_reflection", true, 12)
	env.background_mode = Environment.BG_COLOR
	await variant("4_bg_color_no_sky", true, 12)

func test_physical() -> void:
	base_scene(true, true)
	cam.look_at(Vector3(0.0, 6.0, -30.0))
	var sky: Sky = env.sky
	var phys := PhysicalSkyMaterial.new()
	sky.sky_material = phys
	sun.rotation_degrees = Vector3(-50.0, 150.0, 0.0)
	for e: float in [1.0, 4.0, 16.0]:
		phys.energy_multiplier = e
		await variant("energy_multiplier_%d" % int(e), false, 14)
	phys.energy_multiplier = 1.0
	sun.light_energy = 8.0
	await variant("sun_energy_8", false, 14)

# Fixed per-frame cost of sky radiance updates (run in a tiny window so that screen fill is negligible).
func test_skycost2() -> void:
	base_scene(true, true)
	var sky: Sky = env.sky
	var sm := ShaderMaterial.new()
	sm.shader = load("res://sky_clouds.gdshader")
	sky.sky_material = sm
	await frames(20)
	note("viewport_size", get_viewport().get_visible_rect().size)
	for pm: int in [Sky.PROCESS_MODE_REALTIME, Sky.PROCESS_MODE_QUALITY, Sky.PROCESS_MODE_INCREMENTAL, Sky.PROCESS_MODE_REALTIME, Sky.PROCESS_MODE_QUALITY]:
		sky.process_mode = pm
		await frames(12)
		var t: Dictionary = await frame_ms(40)
		note("process_mode_%d" % pm, t)
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	await frames(12)
	note("realtime_but_no_sky_ambient_no_reflection", await frame_ms(40))
	env.background_mode = Environment.BG_COLOR
	await frames(12)
	note("bg_color", await frame_ms(40))
