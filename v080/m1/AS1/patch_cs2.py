import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
a = s.index("func _build_rig() -> void:")
b = s.index("## Camera of the Cycles showroom sprites")
new = r'''func _build_rig() -> void:
	_sv = SubViewport.new()
	_sv.size = _tile
	_sv.own_world_3d = true
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv.msaa_3d = Viewport.MSAA_4X
	root.add_child(_sv)
	_env = Environment.new()
	var sky := Sky.new()
	_sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = _sky_mat
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	# as the race will do it (contract D6 / D7): ambient colour from the palette, sky only for reflections,
	# linear tonemapper, post path pinned on
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.adjustment_enabled = true
	# glow only adds light around what is brighter than white; the default blend mode (soft light) would
	# change the contrast of the whole picture and crush the dark tones of the night sheet
	_env.glow_enabled = true
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_env.glow_bloom = 0.0
	_env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = _env
	_sv.add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-38.0, 205.0, 0.0)
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_sun.shadow_bias = 0.03
	_sun.shadow_normal_bias = 1.0
	_sv.add_child(_sun)
	_ground = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6000.0, 6000.0)
	_ground.mesh = pm
	_ground.material_override = StandardMaterial3D.new()
	_sv.add_child(_ground)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	_sv.add_child(_cam)
	_holder = Node3D.new()
	_sv.add_child(_holder)
	# the caption has its own transparent viewport: it is blended onto the finished tile
	_label_sv = SubViewport.new()
	_label_sv.size = _tile
	_label_sv.transparent_bg = true
	_label_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_label_sv)
	_label = Label.new()
	_label.position = Vector2(8.0, float(_tile.y) - 26.0)
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 5)
	_label_sv.add_child(_label)
	_set_night(_night)
	ModernMaterials.set_global("ce_time", 1.7)
	ModernMaterials.set_global("ce_wind", Vector4(1.0, 0.0, 0.3, 0.0))


## Day or night rig: sky, ambient light, sun / moon, glow, ce_night. True if something changed (the sky radiance
## then needs some frames).
func _set_night(night: bool) -> bool:
	var changed := night != _rig_night or _first
	_rig_night = night
	if night:
		_sky_mat.sky_top_color = Color(0.01, 0.014, 0.035)
		_sky_mat.sky_horizon_color = Color(0.03, 0.04, 0.075)
		_sky_mat.ground_bottom_color = Color(0.008, 0.008, 0.012)
		_sky_mat.ground_horizon_color = Color(0.03, 0.035, 0.06)
	else:
		_sky_mat.sky_top_color = Color(0.24, 0.44, 0.78)
		_sky_mat.sky_horizon_color = Color(0.7, 0.79, 0.9)
		_sky_mat.ground_bottom_color = Color(0.2, 0.19, 0.17)
		_sky_mat.ground_horizon_color = Color(0.62, 0.68, 0.74)
	# daylight close to the Cycles rig of the sprites (sun 2.4 W/m2 = energy 0.76 here, sky about 0.35)
	_env.ambient_light_color = Color(0.1, 0.12, 0.2) if night else Color(0.6, 0.64, 0.7)
	_env.ambient_light_energy = float(str(_args.get("ambient-energy", "0.55" if night else "1.0")))
	_env.glow_intensity = 0.7 if night else 0.25
	_sun.light_energy = float(str(_args.get("sun-energy", "0.1" if night else "0.8")))
	_sun.light_color = Color(0.62, 0.72, 1.0) if night else Color(1.0, 0.97, 0.92)
	ModernMaterials.set_global("ce_night", 1.0 if night else 0.0)
	ModernMaterials.set_global("ce_sun_color", ModernMaterials.light_value(_sun.light_color, _sun.light_energy))
	ModernMaterials.set_global("ce_ambient", ModernMaterials.light_value(_env.ambient_light_color, _env.ambient_light_energy))
	return changed


## The Cycles sprite of a showroom set on the ground colour of the tile rendered before it (the real-time picture
## of the same car from the same camera).
func _sprite_tile(t: Dictionary) -> Image:
	var img := Image.create(_tile.x, _tile.y, false, Image.FORMAT_RGBA8)
	var bg := Color(0.3, 0.3, 0.32)
	if _last_image != null:
		bg = _last_image.get_pixel(12, _last_image.get_height() - 60)
	bg.a = 1.0
	img.fill(bg)
	var sprite := Image.load_from_file(ProjectSettings.globalize_path(str(t["sprite"])))
	if sprite != null:
		sprite.convert(Image.FORMAT_RGBA8)
		if sprite.get_size() != _tile:
			sprite.resize(_tile.x, _tile.y, Image.INTERPOLATE_LANCZOS)
		img.blend_rect(sprite, Rect2i(Vector2i.ZERO, _tile), Vector2i.ZERO)
	return img


func _caption(img: Image, text: String) -> Image:
	_label.text = text
	await process_frame
	await RenderingServer.frame_post_draw
	var lab := _label_sv.get_texture().get_image()
	lab.convert(Image.FORMAT_RGBA8)
	img.convert(Image.FORMAT_RGBA8)
	img.blend_rect(lab, Rect2i(Vector2i.ZERO, _tile), Vector2i.ZERO)
	return img


func _render(t: Dictionary) -> Image:
	if t.has("sprite"):
		return await _caption(_sprite_tile(t), str(t["text"]))
	for c: Node in _holder.get_children():
		c.free()
	var m := ModelDB.model(str(t.get("model", "")))
	var vehicle := VEHICLE_KINDS.has(str(m.get("kind", ""))) or t.has("strip")
	var night := bool(t.get("is_night", _night))
	var rig_changed := _set_night(night)
	ModernMaterials.set_global("ce_night", float(t.get("night", 1.0 if night else 0.0)))
	var gm: StandardMaterial3D = _ground.material_override
	gm.albedo_color = Color(0.2, 0.2, 0.21) if vehicle else Color(0.22, 0.33, 0.14)
	gm.roughness = 0.85 if vehicle else 0.95
	var node: Node3D = null
	var text := str(t["text"])
	if t.has("strip"):
		node = _channel_strip()
	elif str(t["lod"]) == "impostor":
		node = ModelFactory.build_impostor(str(t["set"]), _mats)
	else:
		node = ModelFactory.build(str(t["set"]), str(t["lod"]), _mats)
	if node == null:
		text += "  (fehlt)"
	else:
		_holder.add_child(node)
		if t.has("lamp_a"):
			ModelFactory.set_lamps(node, t["lamp_a"], t["lamp_b"])
		if t.get("show_caster", false):
			# show the caster itself instead of the body
			for c: Node in node.get_children():
				var mi := c as MeshInstance3D
				mi.visible = mi.name == "shadow"
				if mi.name == "shadow":
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var bb: Array = t.get("aabb", m.get("aabb", [-1, 0, -1, 1, 2, 1]))
	var lo := Vector3(float(bb[0]), float(bb[1]), float(bb[2]))
	var hi := Vector3(float(bb[3]), float(bb[4]), float(bb[5]))
	var centre := (lo + hi) * 0.5
	var radius := (hi - lo).length() * 0.5
	var chase := t.has("chase")
	_sv.size = GAME_SIZE if chase else _tile
	_cam.h_offset = 0.0
	_cam.v_offset = 0.0
	if chase:
		# the game camera (contract D12): frustum with a constant focal length, no pitch, horizon at 45 %
		var near := 1.0
		var size := near * float(GAME_SIZE.y) / GAME_FOCAL_PX
		_cam.keep_aspect = Camera3D.KEEP_HEIGHT
		_cam.set_frustum(size, Vector2(0.0, -0.05 * size), near, 2600.0)
		_cam.basis = Basis.IDENTITY
		_cam.position = Vector3(-float(t.get("lane", 0.0)), GAME_CAM_HEIGHT, float(t["chase"]))
	elif t.get("showroom", false):
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		_showroom_camera(m)
	else:
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		_cam.fov = 30.0
		_cam.keep_aspect = Camera3D.KEEP_HEIGHT
		var yaw := deg_to_rad(float(t.get("yaw", 30.0)))
		var el := deg_to_rad(float(t.get("el", 12.0)))
		var dir := Vector3(sin(yaw) * cos(el), sin(el), cos(yaw) * cos(el))
		# tight fit of the bounding box: the distance every corner needs, horizontally and vertically
		var basis := Basis.looking_at(-dir, Vector3.UP)
		var tan_v := tan(deg_to_rad(_cam.fov * 0.5))
		var tan_h := tan_v * float(_tile.x) / float(_tile.y)
		var dist := 0.5
		for i in 8:
			var corner := Vector3(lo.x if i & 1 == 0 else hi.x, lo.y if i & 2 == 0 else hi.y, lo.z if i & 4 == 0 else hi.z) - centre
			var c := basis.inverse() * corner          # camera space: x right, y up, z towards the camera
			dist = maxf(dist, maxf(absf(c.x) / tan_h, absf(c.y) / (tan_v * 0.84)) + c.z)
		dist *= 1.06
		_cam.position = centre + dir * dist
		_cam.basis = basis
		_cam.near = maxf(0.05, dist * 0.01)
		_cam.far = dist * 4.0 + 2000.0
	# night: the lamps of props light their surroundings as the renderer's omni pool will
	if night and not vehicle:
		for l: Variant in m.get("lights", []):
			var ld: Dictionary = l
			if str(ld.get("role", "")) != "lights" or _holder.get_child_count() > 8:
				continue
			var om := OmniLight3D.new()
			var lp: Array = ld.get("pos", [0, 0, 0])
			om.position = Vector3(float(lp[0]), float(lp[1]) - 0.4, float(lp[2]))
			om.light_color = Color(str(ld.get("color", "#fff0cf")))
			om.light_energy = 3.0
			om.omni_range = 18.0
			_holder.add_child(om)
	# sun as in the sprite rig: fixed relative to the camera - upper left, slightly from the viewer's side
	var sv := Vector3(-0.55, 0.92, 0.55)
	if _args.has("sun"):
		var sp := str(_args["sun"]).split(",")
		sv = Vector3(float(sp[0]), float(sp[1]), float(sp[2]))
	var to_sun := (_cam.basis * sv).normalized()
	_sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	ModernMaterials.set_global("ce_sun_dir", to_sun)
	_sun.directional_shadow_max_distance = 120.0 if chase else maxf(30.0, radius * 6.0)
	for i in (16 if (_first or rig_changed) else 4):
		await process_frame
	_first = false
	await RenderingServer.frame_post_draw
	var img := _sv.get_texture().get_image()
	if chase:
		# cut the vehicle out of the 1280 x 720 picture: the largest whole-number magnification that shows it all
		var r := Rect2()
		for i in 8:
			var corner := Vector3(lo.x if i & 1 == 0 else hi.x, lo.y if i & 2 == 0 else hi.y, lo.z if i & 4 == 0 else hi.z)
			var sp := _cam.unproject_position(corner)
			r = Rect2(sp, Vector2.ZERO) if i == 0 else r.expand(sp)
		var k := clampi(int(floor(minf(float(_tile.x) / (r.size.x * 1.25), float(_tile.y) / (r.size.y * 1.35)))), 1, 12)
		var cw := _tile.x / k
		var ch := _tile.y / k
		var c2 := r.get_center()
		var x0 := clampi(int(round(c2.x - cw * 0.5)), 0, GAME_SIZE.x - cw)
		var y0 := clampi(int(round(c2.y - ch * 0.5)), 0, GAME_SIZE.y - ch)
		img = img.get_region(Rect2i(x0, y0, cw, ch))
		img.resize(_tile.x, _tile.y, Image.INTERPOLATE_NEAREST)
		text += " · %d-fach vergrößert" % k
	return await _caption(img, text)


'''
s = s[:a] + new + s[b:]
open(p, 'w', encoding='utf-8').write(s)
print("ok")
