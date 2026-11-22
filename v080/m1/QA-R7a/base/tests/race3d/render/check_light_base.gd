extends SceneTree
## Render check of the base light of the mode "Modern" against Arcade (v0.8.0, contract §6 R1, D5, §4.9.2). Needs a
## real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_light_base.gd -- --graphics=modern --gfx-sync --audio-sync
## tools/run_render_checks.sh modern runs it. Prints "RENDER-CHECK <name> OK|FEHLER …"; exit code 0 when all pass.
##   tageslicht  S1 (Kiel – Hamburg km 2, 12:00, clear) in Arcade and in Modern („Mittel“) at the same simulation step:
##               the brightness of asphalt, grass and sky in the Modern picture lies within 10 % of Arcade's (median
##               of many probe points each – the probes the camera model puts on the lane centres 25–60 m ahead, on
##               the grass beside the road 30–90 m ahead, on the sky between the clouds' rows and the horizon)
##   schatten    the same view with „Schatten: Mittel“ and „Schatten: Aus“ (casters off, the flag of the light stays on
##               – D5): LIT surfaces are equally bright in both – the mean brightness below the horizon over the pixels
##               that no shadow touches in either picture (both within SHADOW_PIXEL of each other) differs by at most
##               2 %, and those pixels are at least MIN_LIT_SHARE of the ground (a change of the base light would turn
##               most of the ground into "different" pixels). With „Mittel“ guardrails, trees, houses and the car
##               cast shadows (pixels darker than with „Aus“), with „Aus“ nothing casts. (Until the assembly of M1 the
##               check compared the mean of the whole ground; with the shadows of trees, houses and vehicles that mean
##               rightly drops by more than 2 % – D5 means equally bright lit surfaces.)
## Both pictures of a pair show the same simulation step: the stage runs without traffic (--no-traffic), the HUD is
## hidden, the session is stopped after the step and the frame is drawn again.
## (The scene and the autoloads are accessed untyped: -s scripts compile before the autoloads exist.)

const RACE := "res://scenes/race/race.tscn"
const CHECKS := ["tageslicht", "schatten"]
const STEPS := 30
const PROBE_LIMIT := 0.10
const SHADOW_LIMIT := 0.02
const SHADOW_PIXEL := 0.04           ## a pixel this much darker in one picture than in the other is in a shadow
const MIN_LIT_SHARE := 0.75          ## at least this much of the ground must be lit (unshadowed) in both pictures

var _failed: Array[String] = []
var _wall0 := 0


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("RENDER-CHECK light_base FEHLER  braucht einen echten Renderer (Xvfb + --rendering-driver opengl3), nicht --headless")
		quit(1)
		return
	var cli := CliArgs.all()
	var had_no_traffic := cli.has("no-traffic")
	cli["no-traffic"] = true
	var only := str(cli.get("only", ""))
	for c: String in CHECKS:
		if only == "" or only.split(",").has(c):
			await call("_check_" + c)
	if not had_no_traffic:
		cli.erase("no-traffic")
	ModernMaterials.drop_shared()
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	print("RENDER-CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(), (Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)


# --- helpers ---------------------------------------------------------------------------------------------------

func _report(check: String, problems: Array[String], msg: String) -> void:
	var ok := problems.is_empty()
	print("RENDER-CHECK %-11s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems)])
	if not ok:
		_failed.append(check)


func _need(problems: Array[String], cond: bool, what: String) -> void:
	if not cond:
		problems.append(what)


func _launch(extra: Dictionary) -> Node:
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 2.0, "autopilot": true, "autopilot_refuel": "never",
		"seed": 11, "no_countdown": true, "start_speed_kmh": 120.0, "traffic_warmup": false}
	setup.merge(extra, true)
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	return sc


func _free(sc: Node) -> void:
	sc.queue_free()
	await process_frame
	await process_frame
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP


func _until(cond: Callable, max_frames: int = 4000) -> int:
	var n := 0
	while not bool(cond.call()) and n < max_frames:
		await process_frame
		n += 1
	return n


func _capture() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


## -- --save=<absolute folder>: keeps the judged pictures.
func _save(img: Image, name: String) -> void:
	var dir := str(CliArgs.all().get("save", ""))
	if dir == "" or img == null:
		return
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name + ".png"))


## Runs a stage to simulation step STEPS, stops the session there, hides the HUD and returns [scene, picture of that
## step]. Modern draws the frozen view once more (the picture of exactly that step).
func _picture(mode: String, extra: Dictionary = {}) -> Array:
	var setup := {"gfx": mode}
	setup.merge(extra, true)
	var sc: Node = await _launch(setup)
	await _until(func() -> bool: return int(sc.get("_sim_steps")) >= STEPS)
	sc.set_process(false)
	sc.set_physics_process(false)
	for c: Node in sc.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer >= 5:
			(c as CanvasLayer).visible = false        # HUD, pause menu, loading overlay
	var r: Variant = sc.get("renderer")
	if r is ModernRenderer:
		(r as ModernRenderer).render((r as ModernRenderer).view)
	await process_frame
	var img: Image = await _capture()
	return [sc, img]


## Whether a pixel shows the probed material: blue sky, green grass, grey asphalt (what an Arcade sprite, a cloud, a
## line or a shadow covers is left out – in both pictures alike).
static func _is(kind: String, c: Color) -> bool:
	match kind:
		"sky":
			return c.b > c.r + 0.15 and c.b > 0.5
		"grass":
			return c.g > c.r + 0.05 and c.g > c.b + 0.1
		_:
			return absf(c.r - c.b) < 0.12 and absf(c.g - c.b) < 0.1 and c.get_luminance() < 0.6 and c.get_luminance() > 0.12


## Per-channel medians of both pictures over the probe points that show the material `kind` in both:
## [median Arcade, median Modern, number of points].
func _medians(kind: String, a: Image, m: Image, points: Array[Vector2]) -> Array:
	var ch: Array[Array] = [[], [], [], [], [], []]    # plain arrays: a packed array inside an Array is copied on write
	for p: Vector2 in points:
		var x := int(p.x)
		var y := int(p.y)
		if x < 0 or y < 0 or x >= a.get_width() or y >= a.get_height():
			continue
		var ca := a.get_pixel(x, y)
		var cm := m.get_pixel(x, y)
		if not (_is(kind, ca) and _is(kind, cm)):
			continue
		for i in 3:
			ch[i].append(ca[i])
			ch[3 + i].append(cm[i])
	var n := ch[0].size()
	if n == 0:
		return [Color.BLACK, Color.BLACK, 0]
	var med := PackedFloat32Array()
	for i in 6:
		var s: Array = ch[i].duplicate()
		s.sort()
		med.append(float(s[n / 2]))
	return [Color(med[0], med[1], med[2]), Color(med[3], med[4], med[5]), n]


## Probe points of the frozen view of `r` (the camera model = Arcade's projection on a straight, D12).
func _probes(r: ModernRenderer) -> Dictionary:
	var cam_z := float(r.view["camera_z"])
	var lw := r.track.lane_w
	var asphalt: Array[Vector2] = []
	var grass: Array[Vector2] = []
	var sky: Array[Vector2] = []
	var d := 25.0
	while d <= 60.0:
		var seg := r.track.get_segment(int((cam_z + d) / r.track.seg_len))
		var la := -seg.lanes * lw * 0.5
		for i in int(ceil(seg.lanes - 0.01)):
			for off: float in [-0.9, -0.45, 0.45, 0.9]:   # beside the lane centre (Modern's oil streak), not on a line
				var p := r.world_to_screen(cam_z + d, la + (float(i) + 0.5) * lw + off, 0.0)
				if p.z > 0.0:
					asphalt.append(Vector2(p.x, p.y))
		d += 1.5
	d = 30.0
	while d <= 90.0:
		var edges := r.track.road_edges_at(cam_z + d)
		for x: float in [edges.x - 3.2, edges.x - 4.5, edges.y + r.track.shoulder_w + 2.0, edges.y + r.track.shoulder_w + 6.0, edges.y + r.track.shoulder_w + 12.0]:
			var p := r.world_to_screen(cam_z + d, x, 0.0)
			if p.z > 0.0:
				grass.append(Vector2(p.x, p.y))
		d += 2.0
	# the sky well above the treetops of Arcade's scenery sprites (Modern draws trees as models, a later package)
	var hy := r.proj.horizon_y
	for y: float in [hy * 0.35, hy * 0.5, hy * 0.62, hy * 0.72]:
		for x in range(20, 1260, 20):
			sky.append(Vector2(float(x), y))
	return {"asphalt": asphalt, "grass": grass, "sky": sky}


# --- tageslicht -------------------------------------------------------------------------------------------------

func _check_tageslicht() -> void:
	var p: Array[String] = []
	CliArgs.all()["gfx-preset"] = "medium"
	var got_a: Array = await _picture("arcade")
	var arcade: Image = got_a[1]
	await _free(got_a[0])
	var got_m: Array = await _picture("modern")
	var sc: Node = got_m[0]
	var modern: Image = got_m[1]
	CliArgs.all().erase("gfx-preset")
	var r: Variant = sc.get("renderer")
	if not (r is ModernRenderer):
		_report("tageslicht", ["Modern-Etappe läuft"] as Array[String], "S1")
		await _free(sc)
		return
	_save(arcade, "tageslicht_arcade")
	_save(modern, "tageslicht_modern")
	var probes := _probes(r)
	var parts: Array[String] = []
	for kind: String in ["asphalt", "grass", "sky"]:
		var pts: Array[Vector2] = probes[kind]
		var med: Array = _medians(kind, arcade, modern, pts)
		var ca: Color = med[0]
		var cm: Color = med[1]
		var n := int(med[2])
		var la := ca.get_luminance()
		var lm := cm.get_luminance()
		var dev := (lm - la) / maxf(la, 1.0e-3)
		parts.append("%s %s / %s (%+.1f %%, %d von %d Proben)" % [kind, cm.to_html(false), ca.to_html(false), dev * 100.0, n, pts.size()])
		_need(p, n >= 40, "%s: genug Proben, die in beiden Bildern %s zeigen (%d)" % [kind, kind, n])
		_need(p, absf(dev) <= PROBE_LIMIT, "%s höchstens 10 %% neben Arcade (%+.1f %%)" % [kind, dev * 100.0])
	await _free(sc)
	_report("tageslicht", p, "S1 12 Uhr, Modern / Arcade: %s" % "; ".join(parts))


# --- schatten ---------------------------------------------------------------------------------------------------

func _check_schatten() -> void:
	var p: Array[String] = []
	CliArgs.all()["gfx-preset"] = "medium"
	var got_on: Array = await _picture("modern")
	var r_on: Variant = (got_on[0] as Node).get("renderer")
	var on_ok := r_on is ModernRenderer
	var casters_on := int((r_on as ModernRenderer).levels.get("shadow_casters", -1)) if on_ok else -1
	var flag_on := on_ok and bool(((r_on as ModernRenderer).env.get("sun") as DirectionalLight3D).shadow_enabled)
	var hy := int((r_on as ModernRenderer).proj.horizon_y) if on_ok else 324
	await _free(got_on[0])
	CliArgs.all()["gfx"] = "shadows=0"
	var got_off: Array = await _picture("modern")
	var r_off: Variant = (got_off[0] as Node).get("renderer")
	var off_ok := r_off is ModernRenderer
	var casters_off := int((r_off as ModernRenderer).levels.get("shadow_casters", -1)) if off_ok else -1
	var flag_off := off_ok and bool(((r_off as ModernRenderer).env.get("sun") as DirectionalLight3D).shadow_enabled)
	var casting_off := 0
	if off_ok:
		casting_off = _casting((r_off as ModernRenderer).world)
	await _free(got_off[0])
	CliArgs.all().erase("gfx")
	CliArgs.all().erase("gfx-preset")
	var on: Image = got_on[1]
	var off: Image = got_off[1]
	_save(on, "schatten_mittel")
	_save(off, "schatten_aus")
	_need(p, on_ok and off_ok, "beide Bilder in Modern")
	_need(p, casters_on > 0 and casters_off == 0, "Mittel mit, Aus ohne Schattenwerfer (%d / %d)" % [casters_on, casters_off])
	_need(p, flag_on and flag_off, "das Licht behält in beiden Stufen seinen Schatten (D5)")
	_need(p, casting_off == 0, "mit „Aus“ wirft kein Knoten Schatten (%d)" % casting_off)
	var sum_on := 0.0
	var sum_off := 0.0
	var all_on := 0.0
	var all_off := 0.0
	var darker := 0
	var darker_off := 0
	var lit := 0
	var n := 0
	for y in range(hy + 2, on.get_height()):
		for x in range(0, on.get_width()):
			var a := on.get_pixel(x, y).get_luminance()
			var b := off.get_pixel(x, y).get_luminance()
			all_on += a
			all_off += b
			n += 1
			if a < b - SHADOW_PIXEL:
				darker += 1           # a real shadow with „Mittel“
			elif b < a - SHADOW_PIXEL:
				darker_off += 1       # the stronger contact shadows of „Aus“
			else:
				sum_on += a
				sum_off += b
				lit += 1
	var m_on := sum_on / float(maxi(lit, 1))
	var m_off := sum_off / float(maxi(lit, 1))
	var dev := (m_on - m_off) / maxf(m_off, 1.0e-3)
	var dev_all := (all_on - all_off) / maxf(all_off, 1.0e-3)
	var lit_share := float(lit) / float(maxi(n, 1))
	_need(p, absf(dev) <= SHADOW_LIMIT, "beleuchtete Flächen höchstens ±2 %% verschieden (%+.2f %%)" % (dev * 100.0))
	_need(p, lit_share >= MIN_LIT_SHARE, "mindestens %.0f %% des Bodens in beiden Bildern unbeschattet (%.1f %%)" % [100.0 * MIN_LIT_SHARE, 100.0 * lit_share])
	_need(p, darker >= 100, "mit „Mittel“ sind Schatten zu sehen (%d Bildpunkte dunkler)" % darker)
	_report("schatten", p, "S1 12 Uhr, beleuchtete Flächen (%.1f %% des Bodens): Mittel %.4f, Aus %.4f (%+.2f %%); ganzer Boden %+.2f %%; %d Bildpunkte im Schatten der Werfer (%.2f %%), %d mit „Aus“ dunkler (Kontaktschatten, %.2f %%); Schattenlicht in beiden Stufen an" % [
		100.0 * lit_share, m_on, m_off, dev * 100.0, dev_all * 100.0, darker, 100.0 * float(darker) / float(maxi(n, 1)), darker_off,
		100.0 * float(darker_off) / float(maxi(n, 1))])


## Number of geometry nodes under `node` that cast a shadow.
func _casting(node: Node) -> int:
	var c := 0
	if node is GeometryInstance3D and (node as GeometryInstance3D).visible and (node as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		c += 1
	for ch: Node in node.get_children():
		c += _casting(ch)
	return c
