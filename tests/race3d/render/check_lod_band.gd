extends SceneTree
## Render check of the level cross-fade of the props (mode "Modern", R7c – amendments A-16, A-22; German docs:
## docs/renderer-modern-gelaende.md §9). It needs a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_lod_band.gd -- --graphics=modern --gfx-sync --audio-sync
## tools/run_render_checks.sh modern runs it. Prints "RENDER-CHECK <name> OK|FEHLER …"; exit code 0 when all pass.
##
##   lod_ueberblenden  a city house (lod0 and lod1 as MultiMesh nodes with the materials of their own that
##                     builders/props.gd gives them) stands still in front of a still camera; the end of lod0 is
##                     moved through the house's distance in 0.5-m steps (the same as driving towards it, without the
##                     motion of the picture). With the band of the props builder (±12 %, at least 4 m) the largest
##                     change between two steps must stay below 35 % of the hard swap's (band 0.01 m) and the house
##                     must never lose more than 3 % of its pixels (no hole while the two levels share them) – the
##                     hard swap at 60 m changed 8–32 % of a house's pixels in one frame (AS5aR1, AS5aR2).
##   lod_baum          the same for a card tree, lod1 -> impostor (the billboard).
## "-- --save=<absolute folder>" keeps the pictures. (Scripts started with -s compile before the autoloads exist.)

const Props := preload("res://scripts/race3d/builders/props.gd")
const BACKGROUND := Color(0.42, 0.56, 0.74)
const STEP_M := 0.5
const MAX_SOFT_SHARE := 0.35          ## largest step change with the band / that of the hard swap
const MAX_COVER_LOSS := 0.03          ## share of the house's pixels it may lose inside the band

var _failed: Array[String] = []
var _lib: PropLibrary
var _cam: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("RENDER-CHECK lod_ueberblenden FEHLER  braucht einen echten Renderer (Xvfb + --rendering-driver opengl3), nicht --headless")
		quit(1)
		return
	_scene()
	_lib = PropLibrary.new()
	_lib.request(["props/city_german_old_barock", "props/tree_oak"], self)
	while _lib.pending() > 0:
		await process_frame
	await _check("lod_ueberblenden", "props/city_german_old_barock", "lod0", "lod1", 34.0, 18.0)
	await _check("lod_baum", "props/tree_oak", "lod1", PropLibrary.IMPOSTOR, 150.0, 12.0)
	_lib.clear(self)
	ModelDB.release_all()
	ModernMaterials.drop_shared()
	print("RENDER-CHECKS %s  (%d fehlgeschlagen)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size()])
	quit(0 if _failed.is_empty() else 1)


func _report(check: String, problems: Array[String], msg: String) -> void:
	var ok := problems.is_empty()
	print("RENDER-CHECK %-18s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems)])
	if not ok:
		_failed.append(check)


func _scene() -> void:
	var world := Node3D.new()
	world.name = "World"
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKGROUND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.45, 0.45)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0.0)
	sun.shadow_enabled = true
	world.add_child(sun)
	ModernMaterials.ensure_globals()
	ModernMaterials.set_global("ce_sun_dir", -sun.global_transform.basis.z)
	ModernMaterials.set_global("ce_sun_color", ModernMaterials.light_value(Color.WHITE, 1.0))
	ModernMaterials.set_global("ce_ambient", ModernMaterials.light_value(Color(0.45, 0.45, 0.45), 1.0))
	ModernMaterials.set_global("ce_night", 0.0)
	ModernMaterials.set_global("ce_fog_range", Vector2(2000.0, 4000.0))
	ModernMaterials.set_global("ce_headlight", Vector2(0.0, 0.0))
	_cam = Camera3D.new()
	_cam.near = 0.5
	_cam.far = 2000.0
	_cam.fov = 40.0
	world.add_child(_cam)
	_cam.current = true


## One model at distance d (straight ahead, a little to the right) as the two levels a (near) and b (far); the end
## of level a is moved from d - span to d + span in STEP_M steps, once with the props builder's band and once hard.
func _check(check: String, model_id: String, a: String, b: String, d: float, span: float) -> void:
	var p: Array[String] = []
	var world := root.get_node("World") as Node3D
	var holder := Node3D.new()
	world.add_child(holder)
	var pos := Vector3(4.0, 0.0, -d)
	var nodes := 0
	for rep: String in [a, b]:
		for pv: Variant in _lib.mesh_parts(model_id, rep):
			var part: Dictionary = pv
			if bool(part["shadow"]):
				continue
			var one := PackedFloat32Array()
			Props._put(one, Transform3D(Basis.IDENTITY, pos))
			one.append_array(PackedFloat32Array(Props.MODEL_COLOR))
			one.append_array(PackedFloat32Array([1.0, 1.0, 1.0, 1.5]))
			holder.add_child(Props._mmi(part, one, 1, false))
			nodes += 1
	if nodes < 2:
		_report(check, ["Stufen %s / %s von %s nicht ladbar" % [a, b, model_id]] as Array[String], "")
		holder.free()
		return
	_cam.global_position = Vector3(0.0, 3.0, 0.0)
	_cam.look_at(pos + Vector3(0.0, 6.0, 0.0), Vector3.UP)
	var steps := int(round(2.0 * span / STEP_M)) + 1
	var res := {}
	for mode: String in ["hart", "band"]:
		var fade := Vector3(0.0, 0.005, 0.005) if mode == "hart" else Props.LOD_FADE
		var prev: Image = null
		var worst := 0.0
		var covers: Array[float] = []
		for k in steps:
			var end_a := d - span + float(k) * STEP_M
			var w := clampf(end_a * fade.x, fade.y, fade.z)
			_set_band(model_id, a, Vector4(-2.0, -1.0, end_a - w, end_a + w))
			_set_band(model_id, b, Vector4(end_a - w, end_a + w, Props.LOD_ENDLESS, 2.0 * Props.LOD_ENDLESS))
			var img := await _frame()
			covers.append(float(_cover(img)))
			if prev != null:
				worst = maxf(worst, _changed(prev, img))
			prev = img
			if k == steps / 2 and _save_dir() != "":
				img.save_png(_save_dir().path_join("%s_%s_mitte.png" % [check, mode]))
		var ref := minf(covers[0], covers[covers.size() - 1])
		var low := ref
		for c: float in covers:
			low = minf(low, c)
		res[mode] = {"worst": worst, "loss": 1.0 - low / maxf(1.0, ref), "cover": ref}
	var hard: Dictionary = res["hart"]
	var soft: Dictionary = res["band"]
	if float(hard["worst"]) < 0.02:
		p.append("der harte Wechsel ändert kaum etwas (%.1f %%) – Prüfung ohne Aussage" % (100.0 * float(hard["worst"])))
	if float(soft["worst"]) > MAX_SOFT_SHARE * float(hard["worst"]):
		p.append("Überblenden: größter Schritt %.1f %% gegen hart %.1f %%" % [100.0 * float(soft["worst"]), 100.0 * float(hard["worst"])])
	if float(soft["loss"]) > MAX_COVER_LOSS:
		p.append("Loch im Band: %.1f %% der Pixel fehlen" % (100.0 * float(soft["loss"])))
	_report(check, p, "%s bei %.0f m: größte Änderung je 0,5 m hart %.1f %%, mit Band %.1f %%; Deckung im Band −%.1f %% (%d px)" % [
		model_id.get_file(), d, 100.0 * float(hard["worst"]), 100.0 * float(soft["worst"]), 100.0 * float(soft["loss"]),
		int(soft["cover"])])
	holder.free()


func _set_band(model_id: String, rep: String, band: Vector4) -> void:
	for m: ShaderMaterial in _lib.rep_materials(model_id, rep):
		m.set_shader_parameter("lod_band", band)


func _frame() -> Image:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


## Pixels that differ from the background.
func _cover(img: Image) -> int:
	var n := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			if absf(c.r - BACKGROUND.r) + absf(c.g - BACKGROUND.g) + absf(c.b - BACKGROUND.b) > 0.03:
				n += 1
	return n


## Share of the object's pixels (in either picture) whose colour changes by more than 40 levels.
func _changed(a: Image, b: Image) -> float:
	var obj := 0
	var ch := 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var in_a := absf(ca.r - BACKGROUND.r) + absf(ca.g - BACKGROUND.g) + absf(ca.b - BACKGROUND.b) > 0.03
			var in_b := absf(cb.r - BACKGROUND.r) + absf(cb.g - BACKGROUND.g) + absf(cb.b - BACKGROUND.b) > 0.03
			if not (in_a or in_b):
				continue
			obj += 1
			if maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b))) > 40.0 / 255.0:
				ch += 1
	return float(ch) / maxf(1.0, float(obj))


func _save_dir() -> String:
	var dir := str(CliArgs.all().get("save", ""))
	if dir.is_absolute_path():
		DirAccess.make_dir_recursive_absolute(dir)
		return dir
	return ""
