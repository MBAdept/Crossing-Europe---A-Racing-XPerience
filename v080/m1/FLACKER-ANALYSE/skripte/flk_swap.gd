extends SceneTree
## FLACKER-ANALYSE (scratch only, ZS1 tree): a white traffic car seen from the chase camera (3.4 m, no pitch, focal 711
## logical px, horizon at 45 %) at about 40 m, lit by one shadowed sun like the race (preset "Mittel": 2 splits,
## split_1 0.3 x 120 m = 36 m, atlas 2048, soft low, bias 0.04 / 1.2, blur 1.2, MSAA 2x) with the vehicle LOOK of
## ZS1 (layers/vehicles.gd LOOK) and the day palette. Measures what a player could see change on the car:
##   lod   lod0 vs lod1 at the same distance (the swap at 38-42 m)
##   casc  the same lod0 at the same place, once in shadow cascade 1, once in cascade 2 (split moved across the car)
##   ref   the car with refused instance uniforms (the global shader buffer filled first)
## usage: xvfb-run … godot --path . --rendering-driver opengl3 -s res://flk_swap.gd -- --w=1280 --h=800 --set=traffic/wagon_white
##        --sun=behind|ahead|side --dist=40 --out=<dir>

const OUT_DEFAULT := "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-ANALYSE/swap"
const LOOK: Array = [["vpbr", "env_energy", 1.6], ["vpbr", "paint_base", 1.0], ["vpbr", "paint_knee", 0.7],
	["vpbr", "paint_knee_slope", 0.45], ["vpbr", "paint_desat", 0.08], ["vpbr", "flake_strength", 0.6],
	["vpbr", "lamp_off", 0.28], ["vpbr", "tail_level", 0.5], ["vpbr", "env_night", 0.35], ["vpbr", "fill_night", 0.3],
	["glass", "env_energy", 2.2]]

var _args := {}
var _w := 1280
var _h := 800
var _focal := 711.0
var _mats: ModernMaterials
var _cam: Camera3D
var _sun: DirectionalLight3D
var _world: Node3D
var _car: Node3D
var _out := OUT_DEFAULT
var _results: Array[String] = []
var _sv: SubViewport


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_w = int(_args.get("w", "1280"))
	_h = int(_args.get("h", "800"))
	# logical focal 711 px at a logical height of 720 (stretch expand: 1280x800 keeps 711, 1920x1080 scales 1.5)
	_focal = 711.0 * (float(_h) / 720.0 if _w * 9 == _h * 16 else 1.0)
	_out = str(_args.get("out", OUT_DEFAULT))
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	_sv = SubViewport.new()
	_sv.size = Vector2i(_w, _h)
	_sv.msaa_3d = Viewport.MSAA_2X
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv.own_world_3d = true
	root.add_child(_sv)
	RenderingServer.directional_shadow_atlas_set_size(2048, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	ModelDB.load_manifest()
	_mats = ModernMaterials.shared()
	for l: Array in LOOK:
		_mats.material(str(l[0]))
		_mats.set_class_parameter(str(l[0]), str(l[1]), l[2])
	_build_world()
	var set_id := str(_args.get("set", "traffic/wagon_white"))
	var dist := float(_args.get("dist", "40"))
	var tag := "%s_%dx%d_%s_d%.0f" % [set_id.get_file(), _w, _h, str(_args.get("sun", "behind")), dist]
	var bg := await _shot()
	# lod swap at the same place (cascade 2 at 36 m split)
	_sun.directional_shadow_max_distance = 120.0
	var l0 := await _with_car(set_id, "lod0", dist)
	var l1 := await _with_car(set_id, "lod1", dist)
	var l2 := await _with_car(set_id, "lod2", dist)
	# cascade: split moved beyond the car (cascade 1 covers it) – max 150 m: split 45 m
	_sun.directional_shadow_max_distance = 150.0
	var c1 := await _with_car(set_id, "lod0", dist)
	var c1l1 := await _with_car(set_id, "lod1", dist)
	_sun.directional_shadow_max_distance = 120.0
	var bg2 := await _shot()
	var mask := _mask(bg2, [l0, l1], _car_rect(dist))
	_compare("lod0->lod1 (Kaskade 2)", l0, l1, mask, tag)
	_compare("lod1->lod2 (Kaskade 2)", l1, l2, mask, tag)
	_compare("Kaskade1->Kaskade2 lod0", c1, l0, mask, tag)
	_compare("Kaskade1->Kaskade2 lod1", c1l1, l1, mask, tag)
	_compare("lod0 K1 -> lod1 K2", c1, l1, mask, tag)
	# refused instance uniforms: fill the buffer, then build the car
	var dummies := _fill_buffer()
	for i in 4:
		await process_frame
	var rf := await _with_car(set_id, "lod0", dist)
	var rf1 := await _with_car(set_id, "lod1", dist)
	# the same refused car with globals that switch its dither off (fade = ce_wind.x = 1, xfade = ce_sun_color.r = 2):
	# what the paint itself reads
	ModernMaterials.set_global("ce_wind", Vector4(1.0, 0.0, 0.3, 0.5))
	ModernMaterials.set_global("ce_sun_color", Color(2.0, 2.0, 2.0))
	var rf_nd := await _with_car(set_id, "lod0", dist)
	ModernMaterials.set_global("ce_wind", Vector4(0.8, 0.6, 0.3, 0.5))
	ModernMaterials.set_global("ce_sun_color", ModernMaterials.light_value(_sun.light_color, _sun.light_energy))
	_compare("lod0 -> lod0 abgelehnt ohne Dither", l0, rf_nd, mask, tag)
	_compare("lod0 -> lod0 abgelehnt", l0, rf, mask, tag)
	_compare("lod1 -> lod1 abgelehnt", l1, rf1, mask, tag)
	for d: Node in dummies:
		d.queue_free()
	_sheet([l0, l1, l2, c1, rf, rf1, rf_nd], ["lod0 K2", "lod1 K2", "lod2 K2", "lod0 K1", "lod0 abgelehnt", "lod1 abgelehnt", "lod0 abgelehnt, Dither aus"], mask, tag)
	var f := FileAccess.open(_out + "/" + tag + ".txt", FileAccess.WRITE)
	f.store_string("\n".join(_results) + "\n")
	f.close()
	for r in _results:
		print("FLK ", r)
	quit(0)


func _build_world() -> void:
	_world = Node3D.new()
	_sv.add_child(_world)
	var pal := Palette.compute(13.0, "normal", ConfigLoader.lookup(ConfigLoader.load_merged(), "daytime", {}), false)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = pal.get("sky_bottom", Color(0.73, 0.87, 0.96))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var amb: Color = pal.get("ambient", Color.WHITE)
	env.ambient_light_color = amb
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.adjustment_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_split_1 = 0.3
	_sun.directional_shadow_max_distance = 120.0
	_sun.directional_shadow_fade_start = 0.85
	_sun.shadow_bias = 0.04
	_sun.shadow_normal_bias = 1.2
	_sun.shadow_blur = 1.2
	_sun.light_color = Color(1.0, 0.96, 0.9)
	_sun.light_energy = 0.75
	var sun_mode := str(_args.get("sun", "behind"))
	var elev := deg_to_rad(35.0)
	var az := deg_to_rad(150.0)       # behind the camera, a little to the right: the rear of the car is lit
	if sun_mode == "ahead":
		az = deg_to_rad(-20.0)        # ahead: the rear lies in its own shade (noon in the chase camera)
	elif sun_mode == "side":
		az = deg_to_rad(80.0)
	var to_sun := Vector3(sin(az) * cos(elev), sin(elev), -cos(az) * cos(elev))
	_sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	_world.add_child(_sun)
	ModernMaterials.set_global("ce_ambient", ModernMaterials.light_value(amb, 0.55))
	ModernMaterials.set_global("ce_sun_dir", to_sun)
	ModernMaterials.set_global("ce_sun_color", ModernMaterials.light_value(_sun.light_color, _sun.light_energy))
	ModernMaterials.set_global("ce_fog_color", pal.get("fog", Color(0.75, 0.8, 0.85)))
	ModernMaterials.set_global("ce_fog_range", Vector2(405.0, 900.0))
	ModernMaterials.set_global("ce_wind", Vector4(0.8, 0.6, 0.3, 0.5))
	ModernMaterials.set_global("ce_time", 100.0)
	# environment of the coat (layers/vehicles.gd _set_environment)
	var top: Color = pal.get("sky_top", Color(0.11, 0.36, 0.79))
	var bottom: Color = pal.get("sky_bottom", Color(0.73, 0.87, 0.96))
	var fog: Color = pal.get("fog", bottom)
	for cls: String in ["vpbr", "glass"]:
		_mats.set_class_parameter(cls, "env_zenith", top)
		_mats.set_class_parameter(cls, "env_horizon", bottom.lerp(fog, 0.35))
		_mats.set_class_parameter(cls, "env_ground", Color(0.30 * amb.r, 0.31 * amb.g, 0.32 * amb.b))
		_mats.set_class_parameter(cls, "env_tunnel", Palette.TUNNEL_AMBIENT * 0.45)
	_mats.set_class_parameter("vpbr", "coat_sun", 1.0)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400.0, 400.0)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.36, 0.36, 0.37)
	gm.roughness = 0.9
	ground.material_override = gm
	ground.position = Vector3(0.0, 0.0, -100.0)
	_world.add_child(ground)
	_cam = Camera3D.new()
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	var near := 1.0
	var size := near * float(_h) / _focal
	_cam.set_frustum(size, Vector2(0.0, -(0.5 - 0.45) * size), near, 2600.0)
	_cam.position = Vector3(0.0, 3.4, 0.0)
	_world.add_child(_cam)
	_cam.current = true


func _with_car(set_id: String, lod: String, dist: float) -> Image:
	if _car != null:
		_car.queue_free()
		_car = null
		await process_frame
	_car = ModelFactory.build(set_id, lod, _mats, true)
	_car.position = Vector3(0.0, 0.0, -dist)
	_world.add_child(_car)
	for gi: GeometryInstance3D in ModelFactory.geometry_of(_car):
		if gi.name == "shadow":
			gi.visible = true
		gi.set_instance_shader_parameter(&"fade", 1.0)
		gi.set_instance_shader_parameter(&"sun", 1.0)
		gi.set_instance_shader_parameter(&"lamp_a", Vector4.ZERO)
		gi.set_instance_shader_parameter(&"lamp_b", Vector4.ZERO)
	var img := await _shot()
	_car.queue_free()
	_car = null
	await process_frame
	return img


func _shot() -> Image:
	for i in 4:
		await process_frame
	return _sv.get_texture().get_image()


## Fills Godot's global shader buffer with hidden dummy instances (vpbr material: 16 slots each) so that the next car
## built is refused.
func _fill_buffer() -> Array:
	var out: Array = []
	var qm := QuadMesh.new()
	qm.size = Vector2(0.01, 0.01)
	qm.material = _mats.material("vpbr")
	for i in 300:
		var mi := MeshInstance3D.new()
		mi.mesh = qm
		mi.position = Vector3(0.0, -50.0, 0.0)
		_world.add_child(mi)
		out.append(mi)
	return out


## Screen rectangle of a car of 2 m x 1.8 m x 5 m whose centre stands at `dist` (plus 2 px).
func _car_rect(dist: float) -> Rect2i:
	var lo := Vector2(1.0e9, 1.0e9)
	var hi := Vector2(-1.0e9, -1.0e9)
	for cx: float in [-1.1, 1.1]:
		for cy: float in [0.0, 1.9]:
			for cz: float in [-2.6, 2.6]:
				var p := _cam.unproject_position(Vector3(cx, cy, -dist + cz))
				lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
				hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var r := Rect2i(Vector2i(lo.floor()) - Vector2i(2, 2), Vector2i((hi - lo).ceil()) + Vector2i(5, 5))
	return r.intersection(Rect2i(0, 0, _w, _h))


func _mask(bg: Image, imgs: Array, rect: Rect2i) -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(_w * _h)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var b := bg.get_pixel(x, y)
			var on := 0
			for im: Image in imgs:
				var c := im.get_pixel(x, y)
				if absf(c.r - b.r) + absf(c.g - b.g) + absf(c.b - b.b) > 6.0 / 255.0:
					on = 1
					break
			m[y * _w + x] = on
	return m


func _bbox(mask: PackedByteArray) -> Rect2i:
	var x0 := _w
	var y0 := _h
	var x1 := -1
	var y1 := -1
	for y in _h:
		for x in _w:
			if mask[y * _w + x] != 0:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	if x1 < 0:
		return Rect2i(0, 0, 1, 1)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


func _compare(label: String, a: Image, b: Image, mask: PackedByteArray, tag: String) -> void:
	var n := 0
	var big := 0
	var sa := Vector3.ZERO
	var sb := Vector3.ZERO
	var dmax := 0
	for y in _h:
		for x in _w:
			if mask[y * _w + x] == 0:
				continue
			n += 1
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			sa += Vector3(ca.r, ca.g, ca.b)
			sb += Vector3(cb.r, cb.g, cb.b)
			var d := roundi(maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b))) * 255.0)
			dmax = maxi(dmax, d)
			if d > 24:
				big += 1
	var ma := sa / maxf(1.0, float(n)) * 255.0
	var mb := sb / maxf(1.0, float(n)) * 255.0
	_results.append("%s | %s: Autopixel %d, >24 Stufen %.1f %%, Mittel (%.0f,%.0f,%.0f) -> (%.0f,%.0f,%.0f), Differenz Mittel %.1f, max %d" % [
		tag, label, n, 100.0 * float(big) / maxf(1.0, float(n)), ma.x, ma.y, ma.z, mb.x, mb.y, mb.z, (mb - ma).length(), dmax])


func _sheet(imgs: Array, labels: Array, mask: PackedByteArray, tag: String) -> void:
	var r := _bbox(mask).grow(3)
	r = r.intersection(Rect2i(0, 0, _w, _h))
	var zoom := maxi(2, 200 / maxi(1, r.size.y))
	var tw := r.size.x * zoom
	var th := r.size.y * zoom
	var sheet := Image.create(tw * imgs.size(), th, false, Image.FORMAT_RGB8)
	for i in imgs.size():
		var crop := (imgs[i] as Image).get_region(r)
		crop.convert(Image.FORMAT_RGB8)
		crop.resize(tw, th, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(crop, Rect2i(0, 0, tw, th), Vector2i(i * tw, 0))
	sheet.save_png(_out + "/" + tag + ".png")
	_results.append("%s | Bogen: %s (Spalten: %s; Ausschnitt %s, Zoom %d)" % [tag, _out + "/" + tag + ".png", ", ".join(labels), str(r), zoom])
