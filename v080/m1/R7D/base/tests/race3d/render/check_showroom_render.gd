extends SceneTree
## v0.8.0 (UI1): the 3D showroom of the vehicle selection on a real renderer (Xvfb, software OpenGL):
##   tools/run_render_checks.sh modern showroom
## The vehicle screen in Modern with the limousine forced as a showroom car (the manifest marks no car yet), at the
## stretch scale of a 1280 × 720 window (1.0) and of a 1920 × 1080 window (1.5 – on the 1280 × 720 screen of
## tools/run_render_checks.sh through Window.content_scale_factor, on a large enough screen with a real window of that
## size). Checks per scale: the SubViewport renders in PHYSICAL pixels (control size × stretch scale – 660 × 400 and
## 990 × 600; a viewport of the logical size would be scaled up softly at 1080p), the picture is transparent around
## the car (the menu background shows through), car and turntable cover a plausible share of it and are not cut at an
## edge; the picture changes while the turntable turns. Prints "RENDER-CHECK <name> OK|FEHLER …"; exit code 0 when all
## pass. Scripts of the game are reached at run time (a -s script compiles before the autoloads exist).

const SHOWROOM := "res://scripts/ui/widgets/showroom_3d.gd"
const MODEL_DB := "res://scripts/core/model_db.gd"
const MATERIALS := "res://scripts/race3d/modern_materials.gd"
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]

var _gf: Node
var _failed: Array[String] = []
var _wall0 := 0


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _check(check: String, ok: bool, msg: String) -> void:
	print("RENDER-CHECK %-16s %s  %s" % [check, "OK    " if ok else "FEHLER", msg])
	if not ok:
		_failed.append(check)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _stage() -> Node:
	var shell: Node = _gf.get("shell")
	var screen: Node = shell.get("current_screen") if shell != null else null
	var sc: Node = screen.get("_show") if screen != null else null
	var st: Variant = sc.get("stage3d") if sc != null else null
	return st if st is Node and is_instance_valid(st) else null


## Share of opaque pixels and their bounding box in a picture with alpha.
static func coverage(img: Image) -> Dictionary:
	var n := 0
	var lo := Vector2i(img.get_width(), img.get_height())
	var hi := Vector2i(-1, -1)
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			if img.get_pixel(x, y).a > 0.5:
				n += 1
				lo = lo.min(Vector2i(x, y))
				hi = hi.max(Vector2i(x, y))
	var total := float((img.get_width() / 2) * (img.get_height() / 2))
	return {"share": float(n) / maxf(total, 1.0), "lo": lo, "hi": hi}


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("RENDER-CHECK showroom FEHLER  braucht einen echten Renderer (Xvfb + --rendering-driver opengl3), nicht --headless")
		quit(1)
		return
	_gf = root.get_node_or_null("GameFlow")
	(_gf.get("attract") as Node).set("enabled", false)
	root.get_node("Settings").set("graphics_mode", "modern")
	(load(SHOWROOM) as GDScript).set("force_sets", ["showroom/limousine"])
	for size in SIZES:
		# a window of that size where the screen allows it, else the same stretch scale through content_scale_factor
		root.content_scale_factor = 1.0
		DisplayServer.window_set_size(size)
		await _frames(6)
		var got := DisplayServer.window_get_size()
		var how := "Fenster %dx%d" % [got.x, got.y]
		var expect := float(size.y) / 720.0
		if absf(root.get_stretch_transform().get_scale().x - expect) > 0.01:
			# the window did not grow (Xvfb screen smaller than the window: the viewport keeps its size)
			DisplayServer.window_set_size(SIZES[0])
			await _frames(4)
			root.content_scale_factor = expect / root.get_stretch_transform().get_scale().x
			how = "Fenster %dx%d (Bildschirm zu klein), content_scale_factor %.2f" % [SIZES[0].x, SIZES[0].y, root.content_scale_factor]
			await _frames(4)
		_gf.set("draft", {"race_id": "", "vehicle": "limousine"})
		_gf.set("mode", "race")
		_gf.call("go", "vehicle", {"mode": "race"}, true)
		var st: Node = null
		for i in 600:
			st = _stage()
			if st != null and bool(st.get("ready_to_show")):
				break
			await process_frame
		var tag := "%dx%d" % [size.x, size.y]
		if st == null or not bool(st.get("ready_to_show")):
			_check("showroom_" + tag, false, "kein 3D-Showroom")
			continue
		st.set("turn", false)
		await _frames(30)   # slide-in done, shadow and sky radiance settled
		var vp: SubViewport = st.get("viewport")
		var scale: Vector2 = root.get_stretch_transform().get_scale()
		var want := Vector2i(((st as Control).size * scale).round())
		_check("pixel_" + tag, vp.size == want and (size.y < 1000 or vp.size.x >= 960),
			"%s, Streckfaktor %.2f, SubViewport %s (soll %s)" % [how, scale.x, vp.size, want])
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		var cov := coverage(img)
		var share := float(cov["share"])
		var lo: Vector2i = cov["lo"]
		var hi: Vector2i = cov["hi"]
		var corners_clear := img.get_pixel(1, 1).a < 0.05 and img.get_pixel(img.get_width() - 2, 1).a < 0.05
		var inside := lo.x > 4 and lo.y > 4 and hi.x < img.get_width() - 5 and hi.y < img.get_height() - 5
		_check("bild_" + tag, share > 0.12 and share < 0.75 and corners_clear and hi.x > lo.x and inside,
			"deckend %.0f %% des Bilds, Ecken durchsichtig %s, Auto und Drehteller x %d–%d, y %d–%d von %d × %d (nicht angeschnitten %s)" % [
				share * 100.0, corners_clear, lo.x, hi.x, lo.y, hi.y, img.get_width(), img.get_height(), inside])
		# the turntable turns: another angle, another picture
		st.set("turn", true)
		await _frames(45)
		await RenderingServer.frame_post_draw
		var img2 := vp.get_texture().get_image()
		var diff := 0
		for y in range(0, img.get_height(), 4):
			for x in range(0, img.get_width(), 4):
				if not img.get_pixel(x, y).is_equal_approx(img2.get_pixel(x, y)):
					diff += 1
		_check("dreht_" + tag, diff > 50, "%d geänderte Stichproben nach 45 Bildern" % diff)
		if OS.get_cmdline_user_args().has("--save"):
			img.save_png(ProjectSettings.globalize_path("user://showroom_%s.png" % tag))
	(load(SHOWROOM) as GDScript).set("force_sets", [])
	root.content_scale_factor = 1.0
	_gf.call("go", "title", {}, true)
	await _frames(3)
	# the game stays Modern here, so GameFlow keeps the caches: drop them as leaving Modern would
	(load(MODEL_DB) as GDScript).call("release_all")
	(load(MATERIALS) as GDScript).call("drop_shared")
	await _frames(3)
	print("RENDER-CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(),
		(Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)
