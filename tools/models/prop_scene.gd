extends SceneTree
## Review scene of the prop models (docs/modelle.md section 14): the models of the manifest beside a road, seen
## through the GAME camera (contract D12: 3.4 m high, no pitch, focal length 711 px at 720 px, horizon at 45 %),
## with the level of detail the props builder picks by distance (lod0 to 60 m, lod1 to 200 m, then the impostor
## or the last level). Needs OpenGL - run it through tools/models_prop_scene.sh (Xvfb):
##   godot --path . --rendering-driver opengl3 --audio-driver Dummy -s res://tools/models/prop_scene.gd --
##       --out=<abs.png> --models=<id>,<id>... [--dist=15,40,100,250] [--x=9] [--night] [--zoom=2]
##       [--mode=dist|road|lods] [--tile=360x300] [--sun=x,y,z]
## --mode=dist  one row per model, one tile per distance: a crop of the 1280x720 game picture around the model,
##              magnified by --zoom with whole pixels (what the player sees, pixel for pixel)
## --mode=lods  one row per model: lod0 / lod1 / impostor side by side at the switch distances (60 m and 200 m)
##              in the same crop - colour or size jumps between the levels show here; the mean colour of each
##              tile is printed ("STUFEN <model> …")
## --mode=road  the whole game picture: the models in rows along both roadsides every --every m (yaw and scale
##              varied like the props builder does for vegetation)
## Variants (model ids without a set of their own) are reachable: the scene loads the manifest with a set for
## every model id.

const FOCAL_PX := 711.0
const GAME := Vector2i(1280, 720)
const CAM_H := 3.4
const LOD0_M := 60.0
const LOD1_M := 200.0

var _args: Dictionary = {}
var _mats: ModernMaterials
var _sv: SubViewport
var _cam: Camera3D
var _sun: DirectionalLight3D
var _env: Environment
var _holder: Node3D
var _label_sv: SubViewport
var _label: Label
var _sky_mat: ProceduralSkyMaterial


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_run.call_deferred()


func _run() -> void:
	var out := str(_args.get("out", ""))
	if out == "" or not _args.has("models"):
		print("prop_scene: --out=<Datei.png> und --models=<id,...> angeben")
		quit(1)
		return
	if not _load_manifest_with_model_sets():
		print("prop_scene: kein gültiges Modell-Manifest")
		quit(1)
		return
	_mats = ModernMaterials.new()
	_build_rig()
	var models: Array = str(_args["models"]).split(",", false)
	var mode := str(_args.get("mode", "dist"))
	var img: Image
	if mode == "road":
		img = await _road(models)
	elif mode == "lods":
		img = await _lods(models)
	else:
		img = await _dist(models)
	var err := img.save_png(out)
	print("prop_scene: %s -> %s%s" % [mode, out, "" if err == OK else "  FEHLER %d" % err])
	quit(0 if err == OK else 1)


## The shipped manifest plus a set "<model id>" for every model that has none (variants) - added to the loaded
## tables of this process only (a review tool; the manifest file is never touched).
func _load_manifest_with_model_sets() -> bool:
	if not ModelDB.load_manifest():
		return false
	for mid: String in ModelDB.model_ids():
		if not ModelDB._sets.has(mid):
			ModelDB._sets[mid] = {"model": mid}
	return true


# --- rig ---------------------------------------------------------------------------------------------------------

func _build_rig() -> void:
	var night := _args.has("night")
	_sv = SubViewport.new()
	_sv.size = GAME
	_sv.own_world_3d = true
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv.msaa_3d = Viewport.MSAA_2X
	root.add_child(_sv)
	_env = Environment.new()
	var sky := Sky.new()
	_sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = _sky_mat
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.adjustment_enabled = true
	_env.glow_enabled = true
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_env.glow_bloom = 0.0
	_env.glow_hdr_threshold = 1.0
	# depth fog as the race does it (F4): begin 0.45 x visibility, end = visibility (900 m)
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_DEPTH
	_env.fog_depth_begin = 405.0
	_env.fog_depth_end = 900.0
	_env.fog_depth_curve = 1.0
	var we := WorldEnvironment.new()
	we.environment = _env
	_sv.add_child(we)
	_sun = DirectionalLight3D.new()
	var sd := str(_args.get("sun", "-0.55,0.62,0.55")).split(",")
	var to_sun := Vector3(float(sd[0]), float(sd[1]), float(sd[2])).normalized()
	_sun.look_at_from_position(Vector3.ZERO, -to_sun, Vector3.UP if absf(to_sun.y) < 0.99 else Vector3.FORWARD)
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_sun.directional_shadow_max_distance = 200.0
	_sun.shadow_bias = 0.03
	_sun.shadow_normal_bias = 1.0
	_sv.add_child(_sun)
	if night:
		_sky_mat.sky_top_color = Color(0.01, 0.014, 0.035)
		_sky_mat.sky_horizon_color = Color(0.03, 0.04, 0.075)
		_sky_mat.ground_bottom_color = Color(0.008, 0.008, 0.012)
		_sky_mat.ground_horizon_color = Color(0.03, 0.035, 0.06)
		_env.ambient_light_color = Color(0.1, 0.12, 0.2)
		_env.ambient_light_energy = 0.55
		_env.glow_intensity = 0.7
		_env.fog_light_color = Color(0.03, 0.04, 0.07)
		_sun.light_energy = 0.1
		_sun.light_color = Color(0.62, 0.72, 1.0)
	else:
		_sky_mat.sky_top_color = Color(0.24, 0.44, 0.78)
		_sky_mat.sky_horizon_color = Color(0.7, 0.79, 0.9)
		_sky_mat.ground_bottom_color = Color(0.2, 0.19, 0.17)
		_sky_mat.ground_horizon_color = Color(0.62, 0.68, 0.74)
		_env.ambient_light_color = Color(0.6, 0.64, 0.7)
		_env.ambient_light_energy = 1.0
		_env.glow_intensity = 0.25
		_env.fog_light_color = Color(0.7, 0.77, 0.86)
		_sun.light_energy = 0.8
		_sun.light_color = Color(1.0, 0.97, 0.92)
	ModernMaterials.set_global("ce_night", 1.0 if night else 0.0)
	ModernMaterials.set_global("ce_sun_color", ModernMaterials.light_value(_sun.light_color, _sun.light_energy))
	ModernMaterials.set_global("ce_ambient", ModernMaterials.light_value(_env.ambient_light_color, _env.ambient_light_energy))
	ModernMaterials.set_global("ce_sun_dir", to_sun)
	ModernMaterials.set_global("ce_time", float(str(_args.get("time", "1.7"))))
	ModernMaterials.set_global("ce_wind", Vector4(1.0, 0.0, 0.3, 0.0))
	# ground: grass, a two-lane road along -Z under the camera
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4000.0, 4000.0)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.2, 0.31, 0.12)
	gm.roughness = 0.95
	ground.material_override = gm
	_sv.add_child(ground)
	var road := MeshInstance3D.new()
	var rm := PlaneMesh.new()
	rm.size = Vector2(9.0, 4000.0)
	road.mesh = rm
	road.position = Vector3(0.0, 0.01, -1990.0)
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(0.17, 0.17, 0.18)
	am.roughness = 0.9
	road.material_override = am
	_sv.add_child(road)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_FRUSTUM
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.near = 1.0
	_cam.far = 2600.0
	_cam.size = 1.0 * float(GAME.y) / FOCAL_PX
	_cam.frustum_offset = Vector2(0.0, -0.05 * _cam.size)
	_cam.position = Vector3(0.0, CAM_H, 0.0)
	_sv.add_child(_cam)
	_holder = Node3D.new()
	_sv.add_child(_holder)
	_label_sv = SubViewport.new()
	_label_sv.size = GAME
	_label_sv.transparent_bg = true
	_label_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_label_sv)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 4)
	_label_sv.add_child(_label)


# --- placing ------------------------------------------------------------------------------------------------------

func _level_for(mid: String, dist: float) -> String:
	var m := ModelDB.model(mid)
	var names: Array[String] = []
	for l: Variant in m.get("lods", []):
		var n := str((l as Dictionary).get("name", ""))
		if n != "show":
			names.append(n)
	if dist <= LOD0_M:
		return names[0]
	if dist <= LOD1_M:
		return names[mini(1, names.size() - 1)]
	return "impostor" if m.has("impostor") else names[mini(2, names.size() - 1)]


func _place(mid: String, lod: String, pos: Vector3, yaw: float = 0.0, scale: float = 1.0, mirror: bool = false) -> Node3D:
	var node: Node3D
	if lod == "impostor":
		node = ModelFactory.build_impostor(mid, _mats)
	else:
		node = ModelFactory.build(mid, lod, _mats)
	if node == null:
		print("prop_scene: FEHLER %s %s lässt sich nicht bauen" % [mid, lod])
		return null
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	holder.scale = Vector3(-scale if mirror else scale, scale, scale)
	holder.add_child(node)
	_holder.add_child(holder)
	return holder


func _clear() -> void:
	for c: Node in _holder.get_children():
		c.free()


func _frame() -> Image:
	for _i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := _sv.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


## Screen rect (px) of a model's bounds placed at pos.
func _screen_rect(mid: String, pos: Vector3, scale: float = 1.0) -> Rect2:
	var m := ModelDB.model(mid)
	var bb: Array = m.get("aabb", [-1, 0, -1, 1, 2, 1])
	var r := Rect2()
	var first := true
	for i in 8:
		var p := Vector3(float(bb[0] if i & 1 == 0 else bb[3]), float(bb[1] if i & 2 == 0 else bb[4]),
			float(bb[2] if i & 4 == 0 else bb[5])) * scale + pos
		if _cam.is_position_behind(p):
			continue
		var s := _cam.unproject_position(p)
		if first:
			r = Rect2(s, Vector2.ZERO)
			first = false
		else:
			r = r.expand(s)
	return r


func _caption(img: Image, text: String, at: Vector2i) -> Image:
	_label.text = text
	_label.position = Vector2(at)
	await process_frame
	await RenderingServer.frame_post_draw
	var lab := _label_sv.get_texture().get_image()
	lab.convert(Image.FORMAT_RGBA8)
	img.convert(Image.FORMAT_RGBA8)
	img.blend_rect(lab, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	return img


## Crop of the game picture around a rect, magnified by zoom (nearest), centred into a tile.
func _crop(img: Image, rect: Rect2, tile: Vector2i, zoom: int) -> Image:
	var need := Vector2(tile) / float(zoom)
	var c := rect.get_center()
	var x0 := int(clampf(c.x - need.x * 0.5, 0.0, float(GAME.x) - need.x))
	var y0 := int(clampf(c.y - need.y * 0.5, 0.0, float(GAME.y) - need.y))
	var part := img.get_region(Rect2i(x0, y0, int(need.x), int(need.y)))
	part.resize(int(need.x) * zoom, int(need.y) * zoom, Image.INTERPOLATE_NEAREST)
	var out := Image.create(tile.x, tile.y, false, Image.FORMAT_RGB8)
	out.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), Vector2i.ZERO)
	return out


# --- modes --------------------------------------------------------------------------------------------------------

func _tile_size() -> Vector2i:
	var p := str(_args.get("tile", "360x300")).split("x")
	return Vector2i(int(p[0]), int(p[1]))


func _dist(models: Array) -> Image:
	var dists: Array = str(_args.get("dist", "15,40,100,250")).split(",", false)
	var x := float(str(_args.get("x", "9")))
	var tile := _tile_size()
	var sheet := Image.create(tile.x * dists.size(), tile.y * models.size(), false, Image.FORMAT_RGB8)
	for r in models.size():
		var mid := str(models[r])
		for c in dists.size():
			var d := float(str(dists[c]))
			_clear()
			var lod := _level_for(mid, d)
			var pos := Vector3(x, 0.0, -d)
			_place(mid, lod, pos)
			var img := await _frame()
			var rect := _screen_rect(mid, pos)
			# zoom: as large as the tile allows, at most --zoom, whole pixels
			var zmax := int(str(_args.get("zoom", "4")))
			var zoom := clampi(int(floor(minf(float(tile.x) / maxf(8.0, rect.size.x * 1.15), float(tile.y) / maxf(8.0, rect.size.y * 1.15)))), 1, zmax)
			var t := _crop(img, rect, tile, zoom)
			t = await _caption_tile(t, "%s · %d m · %s · %d×" % [mid, int(d), lod, zoom])
			sheet.blit_rect(t, Rect2i(Vector2i.ZERO, tile), Vector2i(c * tile.x, r * tile.y))
			print("SZENE %s %d m %s %.0fx%.0f px" % [mid, int(d), lod, rect.size.x, rect.size.y])
	return sheet


func _caption_tile(t: Image, text: String) -> Image:
	var big := Image.create(GAME.x, GAME.y, false, Image.FORMAT_RGBA8)
	t.convert(Image.FORMAT_RGBA8)
	big.blit_rect(t, Rect2i(Vector2i.ZERO, t.get_size()), Vector2i.ZERO)
	big = await _caption(big, text, Vector2i(6, t.get_height() - 22))
	var out := big.get_region(Rect2i(Vector2i.ZERO, t.get_size()))
	out.convert(Image.FORMAT_RGB8)
	return out


func _lods(models: Array) -> Image:
	var x := float(str(_args.get("x", "9")))
	var tile := _tile_size()
	var cols := [["lod0", LOD0_M], ["lod1", LOD0_M], ["lod1", LOD1_M], ["impostor", LOD1_M]]
	var sheet := Image.create(tile.x * cols.size(), tile.y * models.size(), false, Image.FORMAT_RGB8)
	for r in models.size():
		var mid := str(models[r])
		var means: Array[String] = []
		for c in cols.size():
			var lod := str(cols[c][0])
			var d := float(cols[c][1])
			_clear()
			var pos := Vector3(x, 0.0, -d)
			var n := _place(mid, lod, pos)
			var img := await _frame()
			var rect := _screen_rect(mid, pos)
			var zoom := clampi(int(floor(minf(float(tile.x) / maxf(8.0, rect.size.x * 1.15), float(tile.y) / maxf(8.0, rect.size.y * 1.15)))), 1, 8)
			if n == null:
				means.append("%s fehlt" % lod)
			else:
				var mean_s: String = await _mean_in(img, rect)
				means.append("%s@%dm %s" % [lod, int(d), mean_s])
			var t := _crop(img, rect, tile, zoom)
			t = await _caption_tile(t, "%s · %s · %d m · %d×" % [mid, lod, int(d), zoom])
			sheet.blit_rect(t, Rect2i(Vector2i.ZERO, tile), Vector2i(c * tile.x, r * tile.y))
		print("STUFEN %s  %s" % [mid, "  ".join(means)])
	return sheet


## Mean colour (0..255) and covered pixel count of what differs from the background inside rect: the model's own
## pixels (measured against a frame without the model).
func _mean_in(img: Image, rect: Rect2) -> String:
	var hold := _holder.get_children()
	for c: Node in hold:
		(c as Node3D).visible = false
	var bg := await _frame()
	for c: Node in hold:
		(c as Node3D).visible = true
	var sum := Vector3.ZERO
	var n := 0
	var r := Rect2i(rect.grow(2.0)).intersection(Rect2i(Vector2i.ZERO, GAME))
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var a := img.get_pixel(x, y)
			var b := bg.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.03:
				sum += Vector3(a.r, a.g, a.b)
				n += 1
	if n == 0:
		return "(0 px)"
	sum /= float(n)
	return "rgb(%d,%d,%d) %d px" % [int(sum.x * 255.0), int(sum.y * 255.0), int(sum.z * 255.0), n]


func _road(models: Array) -> Image:
	var every := float(str(_args.get("every", "30")))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var z := 12.0
	var i := 0
	while z < 700.0:
		for side: int in [-1, 1]:
			var mid := str(models[i % models.size()])
			i += 1
			var m := ModelDB.model(mid)
			var veg := ["tree", "plant"].has(str(m.get("kind", "")))
			var x := float(side) * rng.randf_range(7.0, 22.0)
			var pos := Vector3(x, 0.0, -z - rng.randf_range(0.0, every * 0.5))
			var d := pos.length()
			var yaw := rng.randf() * TAU if veg else 0.0
			var sc := rng.randf_range(0.85, 1.15) if veg else 1.0
			var mirror := side < 0 and (m.get("tags", []) as Array).has("mirror_left")
			_place(mid, _level_for(mid, d), pos, yaw, sc, mirror)
		z += every
	var img := await _frame()
	return img
