extends "res://tests/race3d/render/check_weather.gd"
## Render checks of the open motorway in the mode "Modern" (R7d "Freie Strecke", contract A-27): the new sky, fields,
## road surface and cloud shadows must not make harder to see what the player reacts to. Needs a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 60 -s res://tests/race3d/render/check_freie_strecke.gd -- --graphics=modern --gfx-sync --audio-sync
## tools/run_render_checks.sh modern runs it. Prints "RENDER-CHECK <name> OK|FEHLER …"; exit code 0 when all pass.
## Every picture: the stage without traffic, HUD hidden, the session stopped after STEPS simulation steps (the helpers
## of check_weather.gd), Arcade and Modern at the same step, preset „Mittel“.
##   markierung  the contrast of the edge lines against the asphalt beside them (Weber: line / asphalt − 1) at 20, 60
##               and 120 m ahead (at 120 m, where a line is under two pixels wide, integrated over its width: see
##               _mark_contrast()), in Modern at least MARK_MIN of Arcade's – Kiel – Hamburg km 2 (asphalt) by day, by
##               night, wet by day and wet by night, km 45 (a concrete section) by day and wet by night
##   schatten    the cloud shadows (layers/backdrop.gd debug_shadow_cover: 1 = under a cloud everywhere, 0 = nowhere),
##               S1 at noon: the player's car does not change (at most CAR_CHANGED of its pixels), the asphalt keeps at
##               least ROAD_MIN of its brightness, the contrast of the edge lines at least SHADE_MARK_MIN of the lit one,
##               while the grass beside the road does get darker (the shadow is there); under rain (a closed deck,
##               diffuse light) nothing changes
##   fern        F4 – never more fog than Arcade: the share of fog in the far ground, measured with the fog colour white
##               against black, is at most Arcade's 0.7 in every row beyond the terrain ribbon – by day, at dusk, in rain
## "-- --save=<absolute folder>" keeps the judged pictures; "-- --only=<check>[,…]" runs a subset.
## render-check-timeout: 1800
## (The scene and the autoloads are accessed untyped: -s scripts compile before the autoloads exist.)

const OWN_CHECKS := ["markierung", "schatten", "fern"]
const MARK_DIST := [20.0, 60.0, 120.0]
const MARK_MIN := 0.9
const ROAD_MIN := 0.85
const SHADE_MARK_MIN := 0.95
const CAR_CHANGED := 0.01

var _pairs: Dictionary = {}          ## "<km> <weather> <hour>" -> [arcade Image, modern Image, horizon row, fog colour]
var _lines: Array[String] = []


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("RENDER-CHECK freie_strecke FEHLER  braucht einen echten Renderer (Xvfb + --rendering-driver opengl3), nicht --headless")
		quit(1)
		return
	root.get_node("Settings").call("disarm_crash_guard")
	var cli := CliArgs.all()
	var had_no_traffic := cli.has("no-traffic")
	cli["no-traffic"] = true
	cli["gfx-preset"] = "medium"
	var only := str(cli.get("only", ""))
	for c: String in OWN_CHECKS:
		if only == "" or only.split(",").has(c):
			await call("_check_" + c)
	if not had_no_traffic:
		cli.erase("no-traffic")
	cli.erase("gfx-preset")
	ModernMaterials.drop_shared()
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	print("RENDER-CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(), (Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)


# --- helpers -------------------------------------------------------------------------------------------------------

## Arcade and Modern at the same place and step: [arcade image, modern image, horizon row, fog colour, line points]
## – the line points (world_to_screen of the Modern renderer: on a straight Arcade's lines lie within 1 px of them,
## check_road_parity.gd) are {d: [[centre px, asphalt px], …]} for both edge lines at the distances of MARK_DIST.
func _pair(km: float, weather: String, hour: float) -> Array:
	var key := "%.1f %s %.1f" % [km, weather, hour]
	if _pairs.has(key):
		return _pairs[key]
	var extra := {"weather": weather, "start_world_minutes": hour * 60.0, "start_km": km}
	var sa: Node = await _stage("arcade", extra)
	var ia: Image = await _shot(sa)
	await _free(sa)
	var sm: Node = await _stage("modern", extra)
	var out: Array = [ia, null, 330, Color.GRAY, {}]
	var r: Variant = sm.get("renderer")
	if r is ModernRenderer:
		var mr: ModernRenderer = r
		var wl: Object = _weather_layer(sm)
		if wl != null:
			wl.set("debug_particles", false)     # the precipitation is check_weather's; here the ground and the paint
		var im: Image = await _shot(sm)
		out[1] = im
		out[2] = int(mr.proj.horizon_y) + 2
		out[3] = ModernMaterials.global_value("ce_fog_color")
		out[4] = _line_points(mr)
	await _free(sm)
	_save(ia, "fs_%s_arcade" % key.replace(" ", "_"))
	if out[1] != null:
		_save(out[1], "fs_%s_modern" % key.replace(" ", "_"))
	_pairs[key] = out
	return out


## Screen points of both edge lines (centre of the paint and the asphalt 1 m inside it) at each distance of MARK_DIST.
func _line_points(r: ModernRenderer) -> Dictionary:
	var out := {}
	var cam_z := float(r.view["camera_z"])
	var edge_w := 0.3
	for d: float in MARK_DIST:
		var z := cam_z + d
		var seg := r.track.get_segment(int(floor(z / r.track.seg_len)))
		var half := seg.lanes * r.track.lane_w * 0.5
		var pts: Array = []
		for side: float in [-1.0, 1.0]:
			var centre := side * (half - 0.15 - edge_w * 0.5)
			var asph := side * (half - 0.15 - edge_w - 1.0)
			var pc := r.world_to_screen(z, centre, 0.0)
			var pa := r.world_to_screen(z, asph, 0.0)
			if pc.z > 0.0 and pa.z > 0.0:
				pts.append([Vector2(pc.x, pc.y), Vector2(pa.x, pa.y)])
		out[d] = pts
	return out


## Weber contrast of the edge lines at one distance, over 3 rows, the mean of both lines, against the median of 5
## pixels of the asphalt 1 m inside each line. A line of a few pixels (`integrate` false): its brightest pixel within
## ±3 px of the predicted centre. A line of a pixel or two (`integrate` true, 120 m: 0.3 m are 1.8 px): what the whole
## line adds above the asphalt over ±4 px, in pixels × contrast – Arcade draws such a line one solid pixel wide, Modern
## spreads its coverage over the two pixels it touches; the peak would compare the anti-aliasing, not the contrast.
func _mark_contrast(img: Image, pts: Array, integrate: bool = false) -> float:
	var sum := 0.0
	var n := 0
	for pt: Array in pts:
		var c: Vector2 = pt[0]
		var a: Vector2 = pt[1]
		for dy: int in [-1, 0, 1]:
			var y: int = int(round(c.y)) + dy
			if y < 0 or y >= img.get_height():
				continue
			var ls: Array[float] = []
			for dx in range(-2, 3):
				var x := int(round(a.x)) + dx
				var ya: int = int(round(a.y)) + dy
				if x >= 0 and x < img.get_width() and ya >= 0 and ya < img.get_height():
					ls.append(img.get_pixel(x, ya).get_luminance())
			if ls.is_empty():
				continue
			ls.sort()
			var bg := maxf(ls[ls.size() / 2], 0.004)
			if integrate:
				var area := 0.0
				for dx in range(-4, 5):
					var x := int(round(c.x)) + dx
					if x >= 0 and x < img.get_width():
						area += maxf(img.get_pixel(x, y).get_luminance() - bg, 0.0)
				sum += area / bg
			else:
				var peak := 0.0
				for dx in range(-3, 4):
					var x := int(round(c.x)) + dx
					if x >= 0 and x < img.get_width():
						peak = maxf(peak, img.get_pixel(x, y).get_luminance())
				sum += peak / bg - 1.0
			n += 1
	return sum / float(maxi(n, 1))


# --- markierung ------------------------------------------------------------------------------------------------------

func _check_markierung() -> void:
	var p: Array[String] = []
	var rows: Array[String] = []
	for c: Array in [[2.0, "normal", 12.0], [2.0, "normal", 22.0], [2.0, "rain", 12.0], [2.0, "rain", 22.0],
			[45.0, "normal", 12.0], [45.0, "rain", 22.0]]:
		var pr: Array = await _pair(float(c[0]), str(c[1]), float(c[2]))
		var tag := "km %.0f %s %05.2f" % [float(c[0]), str(c[1]), float(c[2])]
		if pr[1] == null:
			_need(p, false, "%s: Modern läuft nicht" % tag)
			continue
		var pts: Dictionary = pr[4]
		var parts: Array[String] = []
		for d: float in MARK_DIST:
			var lp: Array = pts.get(d, [])
			if lp.is_empty():
				_need(p, false, "%s: Randlinien bei %.0f m im Bild" % [tag, d])
				continue
			var thin := d >= 100.0
			var ca := _mark_contrast(pr[0], lp, thin)
			var cm := _mark_contrast(pr[1], lp, thin)
			var k := cm / maxf(ca, 1.0e-3)
			parts.append("%.0f m %.2f/%.2f = %.2f×" % [d, cm, ca, k])
			_need(p, k >= MARK_MIN, "%s, %.0f m: Kontrast der Randlinien %.2f× Arcade (mindestens %.2f)" % [tag, d, k, MARK_MIN])
		rows.append("%s: %s" % [tag, ", ".join(parts)])
	_report("markierung", p, "Weber-Kontrast der Randlinien Modern/Arcade – " + "; ".join(rows))


# --- schatten --------------------------------------------------------------------------------------------------------

func _backdrop(sc: Node) -> Object:
	var r: Variant = sc.get("renderer")
	return (r as ModernRenderer).layer("backdrop") if r is ModernRenderer else null


## Pixels of the player's car: what changes when the 3D world's layer nodes are hidden, inside the screen rectangle of
## the car body above 0.3 m (its shadow on the road stays out), shrunk by 2 px.
func _car_mask(r: ModernRenderer, lit: Image, bare: Image) -> PackedByteArray:
	var w := lit.get_width()
	var h := lit.get_height()
	var rect := Rect2()
	var vl: Object = r.layer("vehicles")
	var cars: Variant = vl.get("_cars") if vl != null else null
	var car: Variant = (cars as Dictionary).get(-999999) if cars is Dictionary else null
	if car != null:
		var first := true
		for g: Variant in car.get("body"):
			var gi := g as GeometryInstance3D
			if gi == null or not gi.is_inside_tree():
				continue
			var ab := gi.global_transform * gi.get_aabb()
			var lo_y := ab.position.y + 0.3
			for i in 8:
				var v := ab.get_endpoint(i)
				v.y = maxf(v.y, lo_y)
				if r.camera.is_position_behind(v):
					continue
				var s := r.camera.unproject_position(v)
				if first:
					rect = Rect2(s, Vector2.ZERO)
					first = false
				else:
					rect = rect.expand(s)
	var raw := PackedByteArray()
	raw.resize(w * h)
	for y in range(maxi(int(rect.position.y), 0), mini(int(rect.end.y) + 1, h)):
		for x in range(maxi(int(rect.position.x), 0), mini(int(rect.end.x) + 1, w)):
			if absf(lit.get_pixel(x, y).get_luminance() - bare.get_pixel(x, y).get_luminance()) > PIXEL_STEP:
				raw[y * w + x] = 1
	var mask := PackedByteArray()
	mask.resize(w * h)
	for y in range(2, h - 2):
		for x in range(2, w - 2):
			var all := true
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if raw[(y + dy) * w + x + dx] == 0:
						all = false
						break
				if not all:
					break
			if all:
				mask[y * w + x] = 1
	return mask


func _check_schatten() -> void:
	var p: Array[String] = []
	var msg: Array[String] = []
	# noon, clear: a cloud everywhere against no cloud anywhere
	var sc: Node = await _stage("modern", {"weather": "normal", "start_world_minutes": 12.0 * 60.0})
	var r: Variant = sc.get("renderer")
	var bd: Object = _backdrop(sc)
	if not (r is ModernRenderer) or bd == null:
		_need(p, false, "Modern mit Hintergrund-Ebene")
		await _free(sc)
		_report("schatten", p, "")
		return
	var mr: ModernRenderer = r
	bd.set("debug_shadow_cover", 0.0)
	var lit: Image = await _shot(sc)
	bd.set("debug_shadow_cover", 1.0)
	var shade: Image = await _shot(sc)
	_save(lit, "fs_schatten_aus")
	_save(shade, "fs_schatten_an")
	var pts := _line_points(mr)
	# the road: asphalt in the middle of every lane at 25 … 100 m
	var cam_z := float(mr.view["camera_z"])
	var worst := 9.0
	var n_road := 0
	for d: float in [25.0, 45.0, 70.0, 100.0]:
		var seg := mr.track.get_segment(int(floor((cam_z + d) / mr.track.seg_len)))
		var half := seg.lanes * mr.track.lane_w * 0.5
		for lane in int(ceil(seg.lanes - 0.01)):
			var x := -half + (float(lane) + 0.5) * mr.track.lane_w
			var s := mr.world_to_screen(cam_z + d, x + 0.9, 0.0)    # beside the middle of the lane (no oil strip)
			if s.z <= 0.0 or s.x < 4.0 or s.y < 4.0 or s.x > lit.get_width() - 5 or s.y > lit.get_height() - 5:
				continue
			var a := lit.get_pixel(int(s.x), int(s.y)).get_luminance()
			var b := shade.get_pixel(int(s.x), int(s.y)).get_luminance()
			if a > 0.02:
				worst = minf(worst, b / a)
				n_road += 1
	_need(p, n_road >= 6, "genug Fahrbahnproben (%d)" % n_road)
	_need(p, worst >= ROAD_MIN, "Fahrbahn unter der Wolke mindestens %.2f so hell (%.3f)" % [ROAD_MIN, worst])
	msg.append("Fahrbahn %.3f× (%d Proben)" % [worst, n_road])
	# the paint keeps its contrast
	for d: float in [20.0, 60.0]:
		var ca := _mark_contrast(lit, pts.get(d, []))
		var cb := _mark_contrast(shade, pts.get(d, []))
		var k := cb / maxf(ca, 1.0e-3)
		_need(p, k >= SHADE_MARK_MIN, "Kontrast der Randlinien bei %.0f m unter der Wolke %.3f× (mindestens %.2f)" % [d, k, SHADE_MARK_MIN])
		msg.append("Linien %.0f m %.3f×" % [d, k])
	# the grass beside the road gets darker: the shadow is there
	var g_lit := 0.0
	var g_sh := 0.0
	for side: float in [-1.0, 1.0]:
		for d: float in [30.0, 50.0]:
			var seg := mr.track.get_segment(int(floor((cam_z + d) / mr.track.seg_len)))
			var s := mr.world_to_screen(cam_z + d, side * (seg.lanes * mr.track.lane_w * 0.5 + 9.0), 0.0)
			if s.z > 0.0 and s.x > 2.0 and s.x < lit.get_width() - 3 and s.y > 2.0 and s.y < lit.get_height() - 3:
				g_lit += lit.get_pixel(int(s.x), int(s.y)).get_luminance()
				g_sh += shade.get_pixel(int(s.x), int(s.y)).get_luminance()
	var g := g_sh / maxf(g_lit, 1.0e-3)
	_need(p, g <= 0.93, "Gras unter der Wolke dunkler (%.3f×)" % g)
	msg.append("Gras %.3f×" % g)
	# the car: its pixels are what changes when the layers' nodes are hidden – both pictures without the sun's shadows
	# (else the car's shadow on the road, which the cloud does darken, would count as the car)
	var env0: Object = mr.get("_environment")
	var sun: Variant = env0.get("sun") if env0 != null else null
	var had_shadow := false
	if sun is DirectionalLight3D:
		had_shadow = (sun as DirectionalLight3D).shadow_enabled
		(sun as DirectionalLight3D).shadow_enabled = false
	bd.set("debug_shadow_cover", 0.0)
	var lit_ns: Image = await _shot(sc)
	var hidden: Array[Node3D] = []
	for c: Node in mr.world.get_children():
		if c != mr.streamer and c is Node3D and (c as Node3D).visible:
			(c as Node3D).visible = false
			hidden.append(c)
	var bare: Image = await _shot(sc)
	for c: Node3D in hidden:
		c.visible = true
	if sun is DirectionalLight3D:
		(sun as DirectionalLight3D).shadow_enabled = had_shadow
	var mask := _car_mask(mr, lit_ns, bare)
	var n_car := 0
	var changed := 0
	for i in mask.size():
		if mask[i] == 1:
			n_car += 1
			var x := i % lit.get_width()
			var y := i / lit.get_width()
			if absf(lit.get_pixel(x, y).get_luminance() - shade.get_pixel(x, y).get_luminance()) > PIXEL_STEP:
				changed += 1
	_need(p, n_car >= 2000, "Pixel des eigenen Autos gefunden (%d)" % n_car)
	_need(p, float(changed) <= CAR_CHANGED * float(n_car), "das Auto bleibt unter der Wolke, wie es ist (%d von %d Pixeln anders)" % [changed, n_car])
	msg.append("Auto %d/%d Pixel anders" % [changed, n_car])
	bd.set("debug_shadow_cover", -1.0)
	await _free(sc)
	# rain: a closed deck – diffuse light, no cloud shadows
	sc = await _stage("modern", {"weather": "rain", "start_world_minutes": 12.0 * 60.0})
	bd = _backdrop(sc)
	var wl: Object = _weather_layer(sc)
	if wl != null:
		wl.set("debug_particles", false)
	if bd != null:
		bd.set("debug_shadow_cover", 0.0)
		var a: Image = await _shot(sc)
		bd.set("debug_shadow_cover", 1.0)
		var b: Image = await _shot(sc)
		bd.set("debug_shadow_cover", -1.0)
		var d := _diff(a, b, int((sc.get("renderer") as ModernRenderer).proj.horizon_y))
		_need(p, d.x <= 50, "Regen: keine Wolkenschatten (%d Pixel anders)" % d.x)
		msg.append("Regen %d Pixel anders" % d.x)
	await _free(sc)
	_report("schatten", p, "S1 12:00, Wolke überall gegen nirgends: " + ", ".join(msg))


# --- fern (F4) -------------------------------------------------------------------------------------------------------

## The fog of the ground, measured: the same frame with the fog colour white and black (EnvironmentRig
## debug_fog_color – it sends the global every frame). Both ground shaders take Arcade's law for things on the ground:
## towards tone × fog × 1.25 by f = 0.7 × t, t = (depth − begin) / (end − begin) of ce_fog_range. The far ground mixes
## in display values: C = (1 − f) · shown + f · 1.25 · tone · fog, so per channel (C_white − C_black) / C_black =
## 1.25 f / ((1 − f) · ambient). The terrain ribbon gives the engine a FOG of (linear) tone × fog × 1.25 at f: solved
## for f by a few fixed-point steps from the linear values (tone = shown / ambient, the ground law). Every ground row from
## 60 m to the horizon, beside the road (the paved width + 4 m left out), the median over the row: f at most Arcade's
## law of that depth + FOG_TOL. At least one of the pictures has rows with real fog (law ≥ 0.2) – else nothing was
## measured.
const FOG_TOL := 0.06
const RIBBON_END_M := 480.0          ## the outer ring of the terrain ribbon at „Details: Mittel“ (terrain_outer_m)


static func _lin(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


static func _srgb(x: float) -> float:
	return 12.92 * x if x <= 0.0031308 else 1.055 * pow(x, 1.0 / 2.4) - 0.055


## The fog share of one channel: white / black value of the pixel, the ambient display factor, the law of the shader.
static func _fog_share(cw: float, cb: float, amb: float, ribbon: bool) -> float:
	if not ribbon:
		var x := (cw - cb) / maxf(cb, 1.0e-3)
		return clampf(x * amb / (1.25 + x * amb), 0.0, 1.0)
	var lw := _lin(cw)
	var lb := _lin(cb)
	var a := 0.3
	for i in 8:
		var shown := _srgb(minf(lb / maxf(1.0 - a, 0.01), 1.0))
		var w := _lin(minf(shown / maxf(amb, 0.05) * 1.25, 1.0))
		a = clampf((lw - lb) / maxf(w, 1.0e-4), 0.0, 0.99)
	return a


func _check_fern() -> void:
	var p: Array[String] = []
	var rows: Array[String] = []
	var measured := 0
	for c: Array in [["normal", 12.0], ["normal", 19.5], ["rain", 12.0], ["rain", 22.0], ["snow", 12.0]]:
		var tag := "%s %05.2f" % [str(c[0]), float(c[1])]
		var sc: Node = await _stage("modern", {"weather": str(c[0]), "start_world_minutes": float(c[1]) * 60.0})
		var r: Variant = sc.get("renderer")
		if not (r is ModernRenderer):
			_need(p, false, "%s: Modern läuft nicht" % tag)
			await _free(sc)
			continue
		var mr: ModernRenderer = r
		var wl: Object = _weather_layer(sc)
		if wl != null:
			wl.set("debug_particles", false)
			wl.set("debug_spray", false)
		var env: Object = mr.get("_environment")
		var rng_v: Variant = ModernMaterials.global_value("ce_fog_range")
		var amb_v: Variant = ModernMaterials.global_value("ce_ambient_display")
		var amb := Color(1, 1, 1)
		if amb_v is Color:
			amb = amb_v
		elif amb_v is Vector4:
			amb = Color((amb_v as Vector4).x, (amb_v as Vector4).y, (amb_v as Vector4).z)
		elif amb_v is Vector3:
			amb = Color((amb_v as Vector3).x, (amb_v as Vector3).y, (amb_v as Vector3).z)
		if env == null or not (rng_v is Vector2):
			_need(p, false, "%s: Umgebung und Nebelbereich" % tag)
			await _free(sc)
			continue
		var rng: Vector2 = rng_v
		env.set("debug_fog_color", Color(1.0, 1.0, 1.0, 1.0))
		var iw: Image = await _shot(sc)
		env.set("debug_fog_color", Color(0.0, 0.0, 0.0, 1.0))
		var ib: Image = await _shot(sc)
		env.set("debug_fog_color", null)
		_save(iw, "fs_fern_%s_weiss" % tag.replace(" ", "_"))
		var cam_z := float(mr.view["camera_z"])
		var hy := mr.proj.horizon_y
		var worst := -1.0
		var worst_at := ""
		var fogged := 0
		var n_rows := 0
		for y in range(int(hy) + 2, iw.get_height()):
			var depth := mr.proj.depth_at_row(float(y))
			if depth < 60.0:
				break
			if depth > RIBBON_END_M - 20.0 and depth < RIBBON_END_M + 60.0:
				continue          # where the ribbon fades into the far ground: neither law alone
			var ribbon := depth < RIBBON_END_M
			var law := 0.7 * clampf((depth - rng.x) / maxf(rng.y - rng.x, 1.0), 0.0, 1.0)
			var seg := mr.track.get_segment(int(floor((cam_z + depth) / mr.track.seg_len)))
			var half := seg.lanes * mr.track.lane_w * 0.5 + mr.track.shoulder_w + 4.0
			var el := mr.world_to_screen(cam_z + depth, -half, 0.0)
			var er := mr.world_to_screen(cam_z + depth, half, 0.0)
			var fs: Array[float] = []
			for x in range(4, iw.get_width() - 4, 2):
				if el.z > 0.0 and er.z > 0.0 and float(x) > minf(el.x, er.x) and float(x) < maxf(el.x, er.x):
					continue
				var cw := iw.get_pixel(x, y)
				var cb := ib.get_pixel(x, y)
				var f_sum := 0.0
				var k := 0
				for ch in 3:
					if cb[ch] > 0.03 and cw[ch] < 0.995:
						f_sum += _fog_share(cw[ch], cb[ch], amb[ch], ribbon)
						k += 1
				if k > 0:
					fs.append(f_sum / float(k))
			if fs.size() < 40:
				continue
			fs.sort()
			var f := fs[fs.size() / 2]
			n_rows += 1
			if law >= 0.2:
				fogged += 1
			if f - law > worst:
				worst = f - law
				worst_at = "%.0f m: %.2f gegen %.2f" % [depth, f, law]
		measured += fogged
		rows.append("%s (Nebel %.0f–%.0f m): %d Zeilen, %d mit Nebel, größter Überschuss %+.3f (%s)" % [tag, rng.x, rng.y, n_rows, fogged, worst, worst_at])
		_need(p, n_rows >= 20, "%s: Bodenzeilen gemessen (%d)" % [tag, n_rows])
		_need(p, worst <= FOG_TOL, "%s: nie mehr Nebel als Arcades Gesetz (+%.2f; %s)" % [tag, FOG_TOL, worst_at])
		await _free(sc)
	_need(p, measured >= 5, "Zeilen mit echtem Nebel gemessen (%d)" % measured)
	_report("fern", p, "F4, Nebelanteil des Bodens gemessen (Nebelfarbe weiß gegen schwarz) gegen Arcades 0,7 × t – " + "; ".join(rows))
