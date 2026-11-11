extends SceneTree
## Render check: the paint of the Modern road lies where Arcade draws it (v0.8.0, contract §6 R1, §4.9.2, A-3). Needs
## a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_road_parity.gd -- --graphics=modern --gfx-sync --audio-sync
## tools/run_render_checks.sh modern runs it. Prints "RENDER-CHECK <name> OK|FEHLER …"; exit code 0 when all pass.
##   gerade     S1 (Kiel – Hamburg km 2, a straight): the centre of every edge line and lane line found in the picture
##              lies within 1 px of where Arcade draws it (RoadRenderer._project and _draw_markings), 12 to 150 m ahead
##   kurve_400  Kiel – Hamburg km 7.9, a bend of R 400 m that starts at the camera: within 8 px of Arcade up to 150 m
##   kurve_136  Saragossa – Pau km 198.4 (T4, R 136 m): within 27 px of Arcade up to 100 m
##              (both bends with look_gain 0 – amendment A-3: curve pictures are compared with the tangent camera)
##              Everywhere the paint also lies within 1 px of the renderer's own camera model: the shader paints the
##              lines where the road coordinates say, the difference to Arcade is the camera's alone.
##   fenster    windows of 16:10 (1280×800 logical) and 21:9 (1680×720): the picture is filled to every edge – the sky
##              above the horizon row over the whole width, ground below it, no black or empty row or column
## Only the road is judged: the stage runs without traffic (--no-traffic); once it runs, the session is stopped, the
## HUD and every 3D node that is not a road mesh are hidden, and the renderer draws the frozen view once more (in the
## bends with look_gain 0). A line is measured across its own direction in the picture (bilinear samples along the
## normal of its projected tangent), so slanted lines in tight bends are measured as well as steep ones.
## (The scene and the autoloads are accessed untyped: -s scripts compile before the autoloads exist.)

const RACE := "res://scenes/race/race.tscn"
const CHECKS := ["gerade", "kurve_400", "kurve_136", "fenster"]
const Fair := preload("res://tests/race3d/fairness.gd")
const NEAR_M := 12.0
const MIN_CONTRAST := 0.05          ## a line is found when it stands this much above the asphalt beside it
const MIN_FOUND := 0.8              ## share of the predicted line samples that must be found in the picture

var _failed: Array[String] = []
var _wall0 := 0
var _cfg: Dictionary = {}


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("RENDER-CHECK road_parity FEHLER  braucht einen echten Renderer (Xvfb + --rendering-driver opengl3), nicht --headless")
		quit(1)
		return
	_cfg = ConfigLoader.load_merged()
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
	print("RENDER-CHECK %-10s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems)])
	if not ok:
		_failed.append(check)


func _need(problems: Array[String], cond: bool, what: String) -> void:
	if not cond:
		problems.append(what)


func _launch(extra: Dictionary) -> Node:
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 2.0, "autopilot": true, "autopilot_refuel": "never",
		"seed": 11, "gfx": "modern", "no_countdown": true, "start_speed_kmh": 0.0, "traffic_warmup": false}
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


## Starts a Modern stage, lets it run a few steps, then stops the session and hides everything but the road meshes and
## the backdrop. Returns [scene, renderer] (renderer null when the stage did not come up in Modern).
func _frozen_stage(extra: Dictionary) -> Array:
	var sc: Node = await _launch(extra)
	await _until(func() -> bool: return int(sc.get("_sim_steps")) >= 3)
	var r: Variant = sc.get("renderer")
	if not (r is ModernRenderer) or not (r as ModernRenderer).is_prepared():
		return [sc, null]
	var mr: ModernRenderer = r
	sc.set_process(false)
	sc.set_physics_process(false)
	_hide_all_but_road(sc, mr)
	return [sc, mr]


func _hide_all_but_road(sc: Node, r: ModernRenderer) -> void:
	for c: Node in sc.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer >= 5:
			(c as CanvasLayer).visible = false        # HUD, pause menu, loading overlay
	for c: Node in r.world.get_children():
		if c != r.streamer and c is Node3D:
			(c as Node3D).visible = false             # what layers put into the world (vehicles, glints …)
	for chunk: Node in r.streamer.get_children():
		for part: Node in chunk.get_children():
			if part is Node3D and String(part.name) != "Road":
				(part as Node3D).visible = false      # guardrails, terrain, props, signs …


## Draws the frozen view once more (after a change of the camera) and returns the picture of that frame.
func _redraw(r: ModernRenderer) -> Image:
	r.render(r.view)
	await process_frame
	return await _capture()


## Arcade's rows for the view of `r` (the frozen RoadRenderer._project on the same track, projection and view).
## RoadRenderer needs the autoloads: loaded at run time and used untyped (amendment A-1).
func _arcade_rows(r: ModernRenderer) -> Dictionary:
	var ar: Object = (load("res://scripts/race/road_renderer.gd") as GDScript).new()
	ar.call("setup", r.track, r.proj, r.cfg, {})
	ar.set("view", {"camera_z": float(r.view["camera_z"]), "camera_x": float(r.view["camera_x"]), "camera_y": float(r.view["camera_y"])})
	var vis := maxf(float(r.view.get("visibility_m", 900.0)), 400.0)
	ar.set("_vis", vis)
	ar.set("_fog_start", vis * 0.45)
	ar.call("_project")
	var out := {"base": int(floor(float(r.view["camera_z"]) / r.track.seg_len)), "sx": (ar.get("_sx") as PackedFloat32Array).duplicate(),
		"sy": (ar.get("_sy") as PackedFloat32Array).duplicate(), "ss": (ar.get("_ss") as PackedFloat32Array).duplicate(),
		"dz": (ar.get("_dz") as PackedFloat32Array).duplicate(), "n": int(ar.get("_n"))}
	ar.free()
	return out


## Luminance of the picture at a sub-pixel position (bilinear), 0 outside.
func _lum(img: Image, p: Vector2) -> float:
	var x := p.x - 0.5
	var y := p.y - 0.5
	var x0 := int(floor(x))
	var y0 := int(floor(y))
	if x0 < 0 or y0 < 0 or x0 + 1 >= img.get_width() or y0 + 1 >= img.get_height():
		return 0.0
	var fx := x - float(x0)
	var fy := y - float(y0)
	var a := img.get_pixel(x0, y0).get_luminance()
	var b := img.get_pixel(x0 + 1, y0).get_luminance()
	var c := img.get_pixel(x0, y0 + 1).get_luminance()
	var d := img.get_pixel(x0 + 1, y0 + 1).get_luminance()
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


## Centre of a bright line near `at` (screen px), measured along `normal` (unit, screen) within ±half px: the
## brightness-weighted centroid of what stands above the asphalt beside the line. Returns [offset along the normal,
## contrast] or [NAN, 0] when there is no line.
func _line_offset(img: Image, at: Vector2, normal: Vector2, half: float) -> Array:
	var step := 0.25
	var ts := PackedFloat32Array()
	var ls := PackedFloat32Array()
	var t := -half
	while t <= half + 1.0e-4:
		ts.append(t)
		ls.append(_lum(img, at + normal * t))
		t += step
	var sorted := ls.duplicate()
	sorted.sort()
	var bg := sorted[int(float(sorted.size()) * 0.2)]
	var ip := 0
	for i in ls.size():
		if ls[i] > ls[ip]:
			ip = i
	var peak := ls[ip]
	if peak - bg < MIN_CONTRAST:
		return [NAN, peak - bg]
	var thr := bg + 0.5 * (peak - bg)   # the core of the line: a paved strip beside it stays below
	var lo := ip
	while lo > 0 and ls[lo - 1] > thr:
		lo -= 1
	var hi := ip
	while hi < ls.size() - 1 and ls[hi + 1] > thr:
		hi += 1
	if lo == 0 or hi == ls.size() - 1:
		return [NAN, -1.0]   # the bright part touches the end of the window: not a line of known width
	var sw := 0.0
	var swt := 0.0
	for i in range(lo, hi + 1):
		var w := ls[i] - bg
		sw += w
		swt += w * ts[i]
	return [swt / sw, peak - bg]


## The lines Arcade paints on segment `seg` (RoadRenderer._draw_markings, no city, no fuel lane): [[left edge in m from
## the centreline, width, dashed, smallest width in px across the line at which it is judged]]. An edge line has a
## paved strip or the shoulder beside it, which a line of one pixel blends into: it is judged while it is at least
## 1.5 px wide; a lane line has asphalt on both sides.
func _lines_of(seg: TrackSegment, lw: float, edge_w: float, lane_w: float) -> Array:
	var la := -seg.lanes * lw * 0.5
	var ma := -la
	var out: Array = [[la + 0.15, edge_w, false, 1.5], [ma - 0.15 - edge_w * 0.5, edge_w, false, 1.5]]
	var n := int(ceil(seg.lanes - 0.01))
	for i in range(1, n):
		var xa := la + float(i) * lw
		if xa > ma - 0.6:
			continue
		out.append([xa - lane_w * 0.5, lane_w, true, 0.6])
	return out


## Measures every edge and lane line of the road between NEAR_M and `far_m` ahead in the picture of the frozen view.
## Returns {samples, found, arcade_max, arcade_at, model_max, model_at}.
func _measure(r: ModernRenderer, img: Image, far_m: float) -> Dictionary:
	var rows := _arcade_rows(r)
	var cam_z := float(r.view["camera_z"])
	var seg_len := r.track.seg_len
	var lw := r.track.lane_w
	var edge_w := float(ConfigLoader.lookup(_cfg, "render.edge_line_m", 0.3))
	var lane_w := float(ConfigLoader.lookup(_cfg, "render.lane_line_m", 0.15))
	var dash := ConfigLoader.lookup(_cfg, "render.stripes.dash", {}) as Dictionary
	var size := Vector2(img.get_size())
	var horizon := r.proj.horizon_y * size.y / r.proj.screen.y
	var out := {"samples": 0, "found": 0, "arcade_max": 0.0, "arcade_at": "", "model_max": 0.0, "model_at": ""}
	var base: int = rows["base"]
	var sx: PackedFloat32Array = rows["sx"]
	var ss: PackedFloat32Array = rows["ss"]
	for k in range(1, int(rows["n"]) + 1):
		var idx := base + k
		var z := float(idx) * seg_len
		var d := z - cam_z
		if d < NEAR_M or d > far_m:
			continue
		var seg := r.track.get_segment(idx)
		var prev := r.track.get_segment(idx - 1)
		if seg.city or seg.tunnel or seg.fuel_lane > 0.02 or prev.fuel_lane > 0.02 or absf(seg.lanes - prev.lanes) > 0.001:
			continue
		var d_on := Vector2i(2, 4)
		var dv: Variant = dash.get(seg.road, [2, 4])
		if dv is Array and (dv as Array).size() >= 2:
			d_on = Vector2i(int((dv as Array)[0]), int((dv as Array)[1]))
		var cyc := d_on.x + d_on.y
		# a lane line is judged where both segments around the row carry paint (the middle of a dash)
		var dash_mid := (idx % cyc) >= 1 and (idx % cyc) < d_on.x and ((idx - 1) % cyc) < d_on.x
		for line: Array in _lines_of(seg, lw, edge_w, lane_w):
			var xl: float = line[0]
			var w: float = line[1]
			if bool(line[2]) and not dash_mid:
				continue
			var centre := xl + 0.5 * w
			var p := r.world_to_screen(z, centre, 0.0)
			if p.z <= 0.0 or p.x < 12.0 or p.x > size.x - 12.0 or p.y < horizon + 4.0 or p.y > size.y - 6.0:
				continue
			# direction of the line in the picture and its width across that direction
			var p_a := r.world_to_screen(z - 1.0, centre, 0.0)
			var p_b := r.world_to_screen(z + 1.0, centre, 0.0)
			var tangent := Vector2(p_b.x - p_a.x, p_b.y - p_a.y)
			if tangent.length() < 1.0e-3:
				continue
			var normal := Vector2(-tangent.y, tangent.x).normalized()
			var e_l := r.world_to_screen(z, xl, 0.0)
			var e_r := r.world_to_screen(z, xl + w, 0.0)
			var across := absf(Vector2(e_r.x - e_l.x, e_r.y - e_l.y).dot(normal))
			if across < float(line[3]):
				continue   # thinner than the line can be told from what lies beside it
			out["samples"] = int(out["samples"]) + 1
			var half := clampf(across * 0.5 + 5.0, 6.0, 40.0)
			var got: Array = _line_offset(img, Vector2(p.x, p.y), normal, half)
			if is_nan(float(got[0])):
				if CliArgs.has("verbose"):
					print("    nicht gefunden: %.0f m, Linie %+.2f m, Bildpunkt %.1f/%.1f, Normale %s, Fenster ±%.1f px, Kontrast %.3f" % [
						d, centre, p.x, p.y, str(normal), half, float(got[1])])
				continue
			out["found"] = int(out["found"]) + 1
			var at := Vector2(p.x, p.y) + normal * float(got[0])
			# Arcade: the strip of this row runs from sx + xl·s to sx + (xl + max(w, 1/s))·s (RoadRenderer._line)
			var s := ss[k]
			var ax := sx[k] + (xl + 0.5 * maxf(w, 1.0 / s)) * s
			var dev_a := absf(at.x - ax)
			var dev_m := absf(float(got[0]))
			var where := "%.0f m, %+.2f m (%.1f px)" % [d, centre, at.x]
			if dev_a > float(out["arcade_max"]):
				out["arcade_max"] = dev_a
				out["arcade_at"] = where
			if dev_m > float(out["model_max"]):
				out["model_max"] = dev_m
				out["model_at"] = where
	return out


func _judge(check: String, label: String, r: ModernRenderer, img: Image, far_m: float, limit_px: float, extra: Array[String]) -> void:
	var p: Array[String] = extra
	_save(img, check)
	var m := _measure(r, img, far_m)
	var samples := int(m["samples"])
	var found := int(m["found"])
	_need(p, samples >= 20, "genug Linienproben im Bild (%d)" % samples)
	_need(p, float(found) >= MIN_FOUND * float(samples), "Linien im Bild gefunden (%d von %d)" % [found, samples])
	_need(p, float(m["arcade_max"]) <= limit_px, "höchstens %.0f px neben Arcade (%.2f px bei %s)" % [limit_px, float(m["arcade_max"]), str(m["arcade_at"])])
	_need(p, float(m["model_max"]) <= 1.0, "höchstens 1 px neben dem Kameramodell (%.2f px bei %s)" % [float(m["model_max"]), str(m["model_at"])])
	_report(check, p, "%s: %d von %d Linienproben (Rand- und Leitlinien, %.0f–%.0f m) gefunden; neben Arcade höchstens %.2f px (%s), neben dem Kameramodell höchstens %.2f px" % [
		label, found, samples, NEAR_M, far_m, float(m["arcade_max"]), str(m["arcade_at"]), float(m["model_max"])])


## Start position (km) that puts the camera at the start of the first bend of |curve| ≈ want that lasts `need_m`.
func _bend_start_km(stage_id: String, from_city: String, km_from: float, want: float, need_m: float) -> float:
	var net := Fair.load_network()
	var dirs := Fair.directions(net, ["%s__%s" % [stage_id, from_city]])
	if dirs.is_empty():
		return -1.0
	var geo := Fair.build_geo(_cfg, net, dirs[0])
	var track: Track = geo["track"]
	var curve: PackedFloat32Array = geo["curve"]
	var need := int(ceil(need_m / track.seg_len)) + 2
	var proj := Fair.make_projection(_cfg)
	var k := int(track.km_to_z(km_from) / track.seg_len)
	while k < int(geo["nz"]) - need:
		var ok := true
		for j in need:
			if absf(absf(curve[k + j]) - want) > 0.06 or signf(curve[k + j]) != signf(curve[k]):
				ok = false
				break
		if ok:
			# the player stands cam_distance ahead of the camera
			return track.z_to_km(float(k) * track.seg_len + proj.cam_distance + 0.2)
		k += 1
	return -1.0


# --- gerade ----------------------------------------------------------------------------------------------------

func _check_gerade() -> void:
	var extra: Array[String] = []
	var st: Array = await _frozen_stage({"start_km": 2.0})
	var sc: Node = st[0]
	var r: ModernRenderer = st[1]
	if r == null:
		_report("gerade", ["Modern-Etappe läuft"] as Array[String], "S1")
		await _free(sc)
		return
	var img: Image = await _redraw(r)
	_need(extra, absf(rad_to_deg(r.chase.look_yaw(r.path, float(r.view["camera_z"])))) < 0.05, "S1 ist eine Gerade (Blickwinkel %.3f°)" % rad_to_deg(r.chase.look_yaw(r.path, float(r.view["camera_z"]))))
	_judge("gerade", "S1 (Kiel – Hamburg km 2, Gerade)", r, img, 150.0, 1.0, extra)
	await _free(sc)


# --- kurve_400 / kurve_136 ---------------------------------------------------------------------------------------

func _bend(check: String, stage_id: String, from_city: String, km_from: float, radius: float, far_m: float, limit_px: float) -> void:
	var r1 := float(ConfigLoader.lookup(_cfg, "road.curve_radius_at_1_m", 120.0))
	var km := _bend_start_km(stage_id, from_city, km_from, r1 / radius, far_m + 12.0)
	if km < 0.0:
		_report(check, ["Kurve mit R %.0f m gefunden" % radius] as Array[String], stage_id)
		return
	var st: Array = await _frozen_stage({"stage_id": stage_id, "from_city": from_city, "start_km": km})
	var sc: Node = st[0]
	var r: ModernRenderer = st[1]
	if r == null:
		_report(check, ["Modern-Etappe läuft"] as Array[String], stage_id)
		await _free(sc)
		return
	var gain := r.chase.look_gain
	r.chase.look_gain = 0.0      # A-3: curve pictures are compared with the tangent camera
	var img: Image = await _redraw(r)
	var extra: Array[String] = []
	var seg := r.track.get_segment(int(floor(float(r.view["camera_z"]) / r.track.seg_len)) + 2)
	_need(extra, absf(r1 / maxf(absf(seg.curve), 1.0e-4) - radius) < radius * 0.2, "Kurve mit R %.0f m an der Kamera (R %.0f m)" % [radius, r1 / maxf(absf(seg.curve), 1.0e-4)])
	_judge(check, "%s km %.2f (R %.0f m, look_gain 0)" % [stage_id, km, radius], r, img, far_m, limit_px, extra)
	r.chase.look_gain = gain
	await _free(sc)


func _check_kurve_400() -> void:
	await _bend("kurve_400", "kiel_hamburg", "kiel", 7.0, 400.0, 150.0, 8.0)


func _check_kurve_136() -> void:
	await _bend("kurve_136", "saragossa_pau", "saragossa", 198.0, 136.0, 100.0, 27.0)


# --- fenster ---------------------------------------------------------------------------------------------------

func _check_fenster() -> void:
	var p: Array[String] = []
	var size0 := root.size
	var notes: Array[String] = []
	# window sizes inside the 1280×720 screen of Xvfb that give the logical pictures 1280×800 and 1680×720
	for case: Array in [[Vector2i(1152, 720), Vector2(1280, 800)], [Vector2i(1260, 540), Vector2(1680, 720)]]:
		var win: Vector2i = case[0]
		var want: Vector2 = case[1]
		root.size = win
		for i in 5:
			await process_frame
		var st: Array = await _frozen_stage({"start_km": 2.0})
		var sc: Node = st[0]
		var r: ModernRenderer = st[1]
		if r == null:
			p.append("Modern-Etappe läuft (%s)" % str(want))
			await _free(sc)
			continue
		# everything but the HUD stays visible here: the whole picture is judged
		for c: Node in r.world.get_children():
			if c is Node3D:
				(c as Node3D).visible = true
		for chunk: Node in r.streamer.get_children():
			for part: Node in chunk.get_children():
				if part is Node3D:
					(part as Node3D).visible = true
		var img: Image = await _redraw(r)
		var logical := root.get_visible_rect().size
		_need(p, img.get_size() == win and logical.is_equal_approx(want), "Fenster %s: Bild %s, logisch %s" % [str(want), str(img.get_size()), str(logical)])
		var w := img.get_width()
		var h := img.get_height()
		var hy := int(r.proj.horizon_y / r.proj.screen.y * float(h))
		var bad: Array[String] = []
		# the top row and the row halfway down to the horizon: sky (blue or a cloud) over the whole width – the
		# backdrop's silhouettes stand right above the horizon row; below it: ground
		_save(img, "fenster_%dx%d" % [int(want.x), int(want.y)])
		for y: int in [1, hy / 2]:
			for x in range(0, w, 3):
				var c := img.get_pixel(x, y)
				if c.get_luminance() < 0.15 or c.b < c.r - 0.02:
					bad.append("Himmel bei %d,%d: %s" % [x, y, c.to_html(false)])
					break
		for y: int in [mini(h - 2, hy + 8), h - 2]:
			for x in range(0, w, 3):
				var c := img.get_pixel(x, y)
				if c.get_luminance() < 0.04:
					bad.append("Boden bei %d,%d: %s" % [x, y, c.to_html(false)])
					break
		# the left and the right column from top to bottom
		for x: int in [1, w - 2]:
			for y in range(0, h, 3):
				var c := img.get_pixel(x, y)
				if c.get_luminance() < 0.04:
					bad.append("Spalte %d bei Zeile %d: %s" % [x, y, c.to_html(false)])
					break
		_need(p, bad.is_empty(), "%dx%d ohne Lücke (%s)" % [int(want.x), int(want.y), "; ".join(bad)])
		var cam_err := 0.0
		var cam_z := float(r.view["camera_z"])
		for d: float in [15.0, 80.0, 300.0]:
			var a := r.camera.unproject_position(r.road_to_world(cam_z + d, 3.0, 0.5))
			var b := r.world_to_screen(cam_z + d, 3.0, 0.5)
			cam_err = maxf(cam_err, Vector2(a.x - b.x, a.y - b.y).length())
		_need(p, cam_err < 0.02, "Kamera = ChaseCamera3D bei %dx%d (%.4f px)" % [int(want.x), int(want.y), cam_err])
		notes.append("%dx%d im Fenster %dx%d, Horizont in Zeile %d" % [int(want.x), int(want.y), win.x, win.y, hy])
		await _free(sc)
	root.size = size0
	for i in 3:
		await process_frame
	_report("fenster", p, "Modern füllt 16:10 und 21:9 bis an jeden Rand: %s" % "; ".join(notes))
