extends SceneTree
## Render check of the class "thin" (N2 after wave 6: beams a landmark shader widens to a pixel – German docs:
## docs/modelle.md section 25, docs/renderer-modern.md 19.1). It needs a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_thin_render.gd -- --graphics=modern --gfx-sync --audio-sync
## tools/run_render_checks.sh modern runs it. Prints "RENDER-CHECK <name> OK|FEHLER …"; exit code 0 when all pass.
##
## The Riesenrad (landmarks/riesenrad: 968 beams of 0.14 – 0.55 m as "thin" – spokes, rims, lacing, pylons) with the
## materials builders/landmarks.gd gives it, in front of the game camera (3.4 m high, 711 px focal length at 720 px, no
## pitch) at 250 / 600 / 1 000 m, turned by its sprite's view angle as in a race. The camera moves towards it in
## FRAMES steps of STEP_M (one frame at 120 km/h). Each distance is drawn twice: as the game draws it, and with
## thin_px = 0 (no widening: the beams as plain geometry, what the model drew before N2).
##   duenn_<d>m   flimmern: the picture is cut into BLOCK × BLOCK pixel blocks and the darkening of the sky in each
##                ("ink": the luma the wheel takes away from the background) compared from frame to frame – the sum of
##                the changes over the sum of the ink must stay below MAX_FLICKER and below MAX_FLICKER_SHARE of the
##                plain beams'. Motion moves an edge inside its block (its ink changes a little); a beam under a pixel
##                that is hit in one frame and missed in the next makes its block jump – that is the shimmer. (The
##                share of pixels that change by more than 24 levels is printed too: at 250 m it counts every edge
##                of the gondolas and rims that moves, in both variants – prop_scene measured 6.5 / 8.8 / 4.5 % of a
##                tile at 250 / 600 / 1 000 m before N2, the sprite 2.1 / 0.6 / 0.1 %.)
##                deckung: the darkening of the sky over all frames ("ink": the sum of the luma the wheel takes away
##                from the background) within INK_TOL of the plain beams'. A pixel centre samples a beam without bias:
##                averaged over the frames the plain beams' ink is the true coverage – a widened beam must darken the
##                sky as much as the real one would (alpha = true width / drawn width), not more (a dark web) and not
##                less (gone).
## "-- --save=<absolute folder>" keeps the first frame of each variant. (Scripts started with -s compile before the
## autoloads exist.)

## loaded at run time: a preloaded builder would compile before the autoloads exist (SpriteDB …)
const LANDMARKS_SCRIPT := "res://scripts/race3d/builders/landmarks.gd"
const MODEL := "landmarks/riesenrad"
const BACKGROUND := Color(0.42, 0.56, 0.74)
const FOCAL_PX := 711.0              ## the game camera (contract D12) at a 720-px picture
const CAM_H := 3.4
const DISTS: Array[float] = [250.0, 600.0, 1000.0]
const FRAMES := 8
const STEP_M := 0.56                 ## one frame at 120 km/h
const BLOCK := 8
const MAX_FLICKER := 0.05            ## block ink changing from frame to frame / block ink
const MAX_FLICKER_SHARE := 0.6       ## … and at most this share of the plain beams'
const INK_TOL := 0.1                 ## ink of the widened beams within ±10 % of the plain beams' (measured: 0.97 – 0.99)

var _failed: Array[String] = []
var _lib: PropLibrary
var _cam: Camera3D
var _thin: Array[ShaderMaterial] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("RENDER-CHECK duenn FEHLER  braucht einen echten Renderer (Xvfb + --rendering-driver opengl3), nicht --headless")
		quit(1)
		return
	_scene()
	_lib = PropLibrary.new()
	_lib.request([MODEL], self)
	while _lib.pending() > 0:
		await process_frame
	var holder := _wheel()
	if holder == null or _thin.is_empty():
		_report("duenn", ["%s hat keine Fläche 'thin' (Export N2?)" % MODEL] as Array[String], "")
	else:
		for d: float in DISTS:
			await _check(holder, d)
		holder.free()
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
	world.add_child(sun)
	ModernMaterials.ensure_globals()
	ModernMaterials.set_global("ce_sun_dir", -sun.global_transform.basis.z)
	ModernMaterials.set_global("ce_sun_color", ModernMaterials.light_value(Color.WHITE, 1.0))
	ModernMaterials.set_global("ce_ambient", ModernMaterials.light_value(Color(0.45, 0.45, 0.45), 1.0))
	ModernMaterials.set_global("ce_night", 0.0)
	ModernMaterials.set_global("ce_snow", 0.0)
	ModernMaterials.set_global("ce_fog_range", Vector2(4000.0, 8000.0))
	ModernMaterials.set_global("ce_headlight", Vector2(0.0, 0.0))
	_cam = Camera3D.new()
	_cam.near = 0.5
	_cam.far = 3000.0
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	world.add_child(_cam)
	_cam.current = true


## The model's lod0 with the landmark builder's opaque materials (the builder's own model_materials()), turned by the
## sprite's view angle; collects the materials of the "thin" surfaces.
func _wheel() -> Node3D:
	var b = (load(LANDMARKS_SCRIPT) as GDScript).new()
	var md: Dictionary = _lib.models.get(MODEL, {})
	var reps: Array = md.get("reps", [])
	if reps.is_empty():
		return null
	var holder := Node3D.new()
	(root.get_node("World") as Node3D).add_child(holder)
	for pv: Variant in _lib.mesh_parts(MODEL, str(reps[0])):
		var part: Dictionary = pv
		if bool(part.get("shadow", false)) or bool(part.get("billboard", false)):
			continue
		var mesh: Mesh = part["mesh"]
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.transform = part.get("transform", Transform3D.IDENTITY)
		holder.add_child(mi)
		for si in mesh.get_surface_count():
			var cls: String = b.surface_class(mesh, si)
			var pair: Array = b.model_materials(cls, mesh.surface_get_material(si), Color.WHITE, md)
			if pair.is_empty():
				continue
			var m: ShaderMaterial = pair[0]
			m.set_shader_parameter("lm_fade", Vector4(1.0, 0.0, 0.0, 0.0))
			mi.set_surface_override_material(si, m)
			if cls == "thin":
				m.set_shader_parameter("viewport_h", float(root.get_visible_rect().size.y))
				_thin.append(m)
	var yaw := deg_to_rad(float(ModelDB.model(MODEL).get("view_yaw_deg", 0.0)))
	holder.rotation.y = -yaw
	return holder


func _check(holder: Node3D, d: float) -> void:
	var name := "duenn_%dm" % int(d)
	holder.position = Vector3(0.0, 0.0, -d)
	var h := float(root.get_visible_rect().size.y)
	_cam.fov = rad_to_deg(2.0 * atan(0.5 * h / (FOCAL_PX * h / 720.0)))
	var box := _screen_box(holder)
	var res := {}
	for widened: bool in [true, false]:
		for m: ShaderMaterial in _thin:
			m.set_shader_parameter("thin_px", 1.5 if widened else 0.0)
		var prev: Image = null
		var prev_blocks := PackedFloat32Array()
		var px := 0.0
		var jump := 0.0
		var ink := 0.0
		for k in FRAMES:
			_cam.global_position = Vector3(0.0, CAM_H, -float(k) * STEP_M)
			_cam.rotation = Vector3.ZERO
			var img := await _frame()
			var blocks := _blocks(img, box)
			var total := 0.0
			for v: float in blocks:
				total += v
			ink += total
			if prev != null:
				px += _changed(prev, img, box)
				var dsum := 0.0
				for i in blocks.size():
					dsum += absf(blocks[i] - prev_blocks[i])
				jump += dsum / maxf(1.0, total)
			elif _save_dir() != "":
				img.save_png(_save_dir().path_join("%s_%s.png" % [name, "breit" if widened else "roh"]))
			prev = img
			prev_blocks = blocks
		res[widened] = {"flicker": jump / float(FRAMES - 1), "px": px / float(FRAMES - 1), "ink": ink / float(FRAMES)}
	for m: ShaderMaterial in _thin:
		m.set_shader_parameter("thin_px", 1.5)
	var on: Dictionary = res[true]
	var off: Dictionary = res[false]
	var ratio := float(on["ink"]) / maxf(1.0, float(off["ink"]))
	var p: Array[String] = []
	if float(on["flicker"]) > MAX_FLICKER:
		p.append("flimmert: Blöcke ändern sich um %.1f %% je Bild (höchstens %.0f %%)" % [100.0 * float(on["flicker"]), 100.0 * MAX_FLICKER])
	if float(on["flicker"]) > MAX_FLICKER_SHARE * float(off["flicker"]):
		p.append("kaum ruhiger als die unverbreiterten Stäbe (%.1f gegen %.1f %%)" % [100.0 * float(on["flicker"]), 100.0 * float(off["flicker"])])
	if absf(ratio - 1.0) > INK_TOL:
		p.append("Deckung %.2f × die der unverbreiterten Stäbe (erlaubt %.2f – %.2f)" % [ratio, 1.0 - INK_TOL, 1.0 + INK_TOL])
	_report(name, p, "Riesenrad %.0f m (%d × %d px): Blöcke je Bild verbreitert %.1f %%, roh %.1f %% (Pixel > 24: %.2f / %.2f %%); Deckung %.2f × roh" % [
		d, box.size.x, box.size.y, 100.0 * float(on["flicker"]), 100.0 * float(off["flicker"]), 100.0 * float(on["px"]),
		100.0 * float(off["px"]), ratio])


## Screen rectangle of the model (its AABB projected), 2 px larger, clipped to the picture.
func _screen_box(holder: Node3D) -> Rect2i:
	_cam.global_position = Vector3(0.0, CAM_H, 0.0)
	_cam.rotation = Vector3.ZERO
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c: Node in holder.get_children():
		if not c is MeshInstance3D:
			continue
		var mi := c as MeshInstance3D
		var bb := mi.get_aabb()
		for i in 8:
			var pt := mi.global_transform * bb.get_endpoint(i)
			var s := _cam.unproject_position(pt)
			lo = lo.min(s)
			hi = hi.max(s)
	var size := root.get_visible_rect().size
	var x0 := clampi(int(floor(lo.x)) - 2, 0, int(size.x) - 1)
	var y0 := clampi(int(floor(lo.y)) - 2, 0, int(size.y) - 1)
	var x1 := clampi(int(ceil(hi.x)) + 2, 0, int(size.x))
	var y1 := clampi(int(ceil(hi.y)) + 2, 0, int(size.y))
	return Rect2i(x0, y0, maxi(1, x1 - x0), maxi(1, y1 - y0))


func _frame() -> Image:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


static func _luma(c: Color) -> float:
	return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0


## Luma the picture takes away from the background (brighter than the wheel's steel) per BLOCK × BLOCK block of the
## box, row by row.
func _blocks(img: Image, box: Rect2i) -> PackedFloat32Array:
	var bg := _luma(BACKGROUND)
	var nx := (box.size.x + BLOCK - 1) / BLOCK
	var ny := (box.size.y + BLOCK - 1) / BLOCK
	var out := PackedFloat32Array()
	out.resize(nx * ny)
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var i := ((y - box.position.y) / BLOCK) * nx + (x - box.position.x) / BLOCK
			out[i] += bg - _luma(img.get_pixel(x, y))
	return out


## Share of the box's pixels whose colour changes by more than 24 levels.
func _changed(a: Image, b: Image, box: Rect2i) -> float:
	var ch := 0
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b))) > 24.0 / 255.0:
				ch += 1
	return float(ch) / maxf(1.0, float(box.size.x * box.size.y))


func _save_dir() -> String:
	var dir := str(CliArgs.all().get("save", ""))
	if dir.is_absolute_path():
		DirAccess.make_dir_recursive_absolute(dir)
		return dir
	return ""
