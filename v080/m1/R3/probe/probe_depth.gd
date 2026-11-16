extends SceneTree
## R3 probe: is hint_depth_texture readable in fragment() of a transparent material in GL Compatibility?

var _vp: SubViewport

func _shader(code: String) -> ShaderMaterial:
	var s := Shader.new()
	s.code = code
	var m := ShaderMaterial.new()
	m.shader = s
	return m


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(256, 128)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 4)
	cam.near = 1.0
	cam.far = 100.0
	_vp.add_child(cam)
	cam.make_current()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	# an opaque wall at z = -2 (distance 6) covering the left half
	var wall := MeshInstance3D.new()
	var wm := QuadMesh.new()
	wm.size = Vector2(3.0, 6.0)
	wall.mesh = wm
	wall.position = Vector3(-1.6, 0.0, -2.0)
	wall.material_override = _shader("shader_type spatial;\nrender_mode unshaded;\nvoid fragment() { ALBEDO = vec3(0.0, 0.0, 0.3); }")
	_vp.add_child(wall)
	# three probe quads at z = 0 (distance 4)
	var codes := [
		"shader_type spatial;\nrender_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;\nvoid fragment() { ALBEDO = vec3(0.5, 0.0, 0.0); }",
		"shader_type spatial;\nrender_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;\nuniform sampler2D depth_tex : hint_depth_texture, filter_nearest;\nvoid fragment() { float d = texture(depth_tex, SCREEN_UV).r; ALBEDO = vec3(0.0, d, 0.0); }",
		"shader_type spatial;\nrender_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;\nuniform sampler2D depth_tex : hint_depth_texture, filter_nearest;\nvoid fragment() { float d = texture(depth_tex, SCREEN_UV).r; vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, d * 2.0 - 1.0, 1.0); vec4 v = INV_PROJECTION_MATRIX * ndc; float lin = -v.z / v.w; ALBEDO = vec3(0.0, 0.0, lin / 10.0); }",
	]
	var xs := [-2.0, 0.0, 2.0]
	var i := 0
	for code: String in codes:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1.6, 3.0)
		q.mesh = qm
		q.position = Vector3(float(xs[i]) * 0.9, 0.0, 0.0)
		q.material_override = _shader(code)
		_vp.add_child(q)
		i += 1
	for f in 5:
		await process_frame
	var im := _vp.get_texture().get_image()
	im.save_png("/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R3/probe/depth.png")
	for x: int in [20, 60, 128, 196, 236]:
		print("x=%d  %s" % [x, str(im.get_pixel(x, 64))])
	quit(0)
