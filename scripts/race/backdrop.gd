class_name RaceBackdrop
extends RefCounted
## Sky and background panorama of the race view.
## Sky: three-stop gradient, sun with halo / moon / twinkling stars, horizon glow at dawn and dusk,
## drifting clouds, dense overcast for rain and snow.
## Background: layered silhouettes per scenery style (plain, hills, forest, mountains, alps, city,
## coast, industrial) with parallax. The panorama is periodic over a full turn: heading (radians,
## view["bg_offset"]) rotates it, nearer layers rotate slightly faster. When the scenery style
## changes the old layers sink below the horizon while the new ones rise (render.background_blend_s).
## Colours come from data/scenery.json ("background": {style, colors[far..near], snow_caps, height,
## features[turbines|spires|pylons|chimneys|cranes|domes|onion|slabs|towers], sea, roofs
## flat|gable|mansard|stepped|mixed, behind mountains|alps|hills}). Individual cities (docs/staedte.md):
## skyline styles "city" and "suburb" (outskirts: low houses and trees), roof shapes, a mountain or hill
## range behind the city ("behind") and landmark silhouettes (`landmarks`, drawn through `sprite_cb` by the
## renderer after the far layer, turning with the panorama). Owner: race module.

const TABLE_N := 2048
const STYLES := {
	"plain": [
		{"type": "ridge", "par": 1.0, "h": 13.0, "col": 0, "haze": 0.5, "seed": 11, "rough": 0.55},
		{"type": "trees", "par": 1.12, "h": 9.0, "col": 1, "haze": 0.3, "seed": 12, "tree": "round", "count": 170, "tree_h": 13.0},
	],
	"hills": [
		{"type": "ridge", "par": 1.0, "h": 62.0, "col": 0, "haze": 0.55, "seed": 21, "rough": 0.45},
		{"type": "ridge", "par": 1.1, "h": 36.0, "col": 1, "haze": 0.33, "seed": 22, "rough": 0.5},
		{"type": "trees", "par": 1.22, "h": 10.0, "col": 2, "haze": 0.15, "seed": 23, "tree": "round", "count": 220, "tree_h": 12.0},
	],
	"forest": [
		{"type": "ridge", "par": 1.0, "h": 46.0, "col": 0, "haze": 0.5, "seed": 31, "rough": 0.45},
		{"type": "trees", "par": 1.12, "h": 22.0, "col": 1, "haze": 0.32, "seed": 32, "tree": "conifer", "count": 420, "tree_h": 20.0},
		{"type": "trees", "par": 1.25, "h": 12.0, "col": 2, "haze": 0.12, "seed": 33, "tree": "conifer", "count": 300, "tree_h": 26.0},
	],
	"mountains": [
		{"type": "peaks", "par": 1.0, "h": 125.0, "col": 0, "haze": 0.5, "seed": 41, "rough": 0.62, "snow": 0.72},
		{"type": "peaks", "par": 1.08, "h": 72.0, "col": 1, "haze": 0.3, "seed": 42, "rough": 0.58, "snow": 0.92},
		{"type": "trees", "par": 1.22, "h": 16.0, "col": 2, "haze": 0.12, "seed": 43, "tree": "conifer", "count": 330, "tree_h": 18.0},
	],
	"alps": [
		{"type": "peaks", "par": 1.0, "h": 205.0, "col": 0, "haze": 0.36, "seed": 51, "rough": 0.68, "snow": 0.5},
		{"type": "peaks", "par": 1.07, "h": 120.0, "col": 1, "haze": 0.3, "seed": 52, "rough": 0.62, "snow": 0.68},
		{"type": "trees", "par": 1.2, "h": 20.0, "col": 2, "haze": 0.12, "seed": 53, "tree": "conifer", "count": 360, "tree_h": 22.0},
	],
	"city": [
		{"type": "skyline", "par": 1.0, "h": 125.0, "col": 0, "haze": 0.45, "seed": 61, "count": 150, "windows": true},
		{"type": "skyline", "par": 1.14, "h": 62.0, "col": 1, "haze": 0.18, "seed": 62, "count": 190, "windows": true},
	],
	"suburb": [
		{"type": "skyline", "par": 1.0, "h": 70.0, "col": 0, "haze": 0.5, "seed": 66, "count": 120, "windows": true},
		{"type": "trees", "par": 1.1, "h": 9.0, "col": 1, "haze": 0.28, "seed": 67, "tree": "round", "count": 210, "tree_h": 12.0},
		{"type": "houses", "par": 1.18, "h": 15.0, "col": 2, "haze": 0.14, "seed": 68, "count": 170},
	],
	"coast": [
		{"type": "sea", "par": 1.0, "h": 14.0, "col": 0, "haze": 0.25, "seed": 71},
		{"type": "ridge", "par": 1.1, "h": 24.0, "col": 1, "haze": 0.3, "seed": 72, "rough": 0.5, "mask": 0.5},
		{"type": "trees", "par": 1.2, "h": 6.0, "col": 2, "haze": 0.15, "seed": 73, "tree": "round", "count": 90, "tree_h": 9.0, "mask": 0.45},
	],
	"industrial": [
		{"type": "ridge", "par": 1.0, "h": 20.0, "col": 0, "haze": 0.5, "seed": 81, "rough": 0.5},
		{"type": "factory", "par": 1.1, "h": 70.0, "col": 1, "haze": 0.3, "seed": 82, "count": 60},
		{"type": "trees", "par": 1.22, "h": 7.0, "col": 2, "haze": 0.15, "seed": 83, "tree": "round", "count": 150, "tree_h": 10.0},
	],
}

var proj: RoadProjection
var batch: GeoBatch
var blend_s := 2.5

var _tables: Dictionary = {}       ## "seed:type:rough" -> PackedFloat32Array (0..1)
var _objects: Dictionary = {}      ## "seed:type" -> Array[Dictionary] (trees, buildings, factories)
var _stars := PackedVector3Array()
var _clouds: Array[Dictionary] = []
var _overcast: Array[Dictionary] = []
var _cur_id := ""
var _prev_id := ""
var _cur_bg: Dictionary = {}
var _prev_bg: Dictionary = {}
var _blend := 1.0
var _last_t := -1.0
var _base_y := 0.0                 ## screen row the silhouettes stand on (horizon or crest line)
## Landmark silhouettes of this frame (set by the renderer): [{entry, angle (panorama rad), alpha, s (px per m)}]
var landmarks: Array = []
## Draws one silhouette: (entry: Dictionary, pos: Vector2, px_per_m: float, alpha: float, haze: float)
var sprite_cb: Callable


func setup(p: RoadProjection, geo: GeoBatch, blend_seconds: float = 2.5) -> void:
	proj = p
	batch = geo
	blend_s = maxf(0.1, blend_seconds)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	_stars.clear()
	for i in 260:
		_stars.append(Vector3(rng.randf() * TAU, pow(rng.randf(), 0.8), rng.randf_range(0.7, 2.1)))
	_clouds.clear()
	for i in 16:
		var c := {"az": rng.randf() * TAU, "elev": rng.randf_range(0.18, 0.75), "w": rng.randf_range(70.0, 190.0), "puffs": []}
		var n := rng.randi_range(4, 7)
		for j in n:
			(c["puffs"] as Array).append(Vector4(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.12, 0.08), rng.randf_range(0.18, 0.34), rng.randf_range(0.1, 0.2)))
		_clouds.append(c)
	_overcast.clear()
	for i in 40:
		_overcast.append({"az": rng.randf() * TAU, "elev": rng.randf_range(0.35, 1.05), "rx": rng.randf_range(120.0, 260.0), "ry": rng.randf_range(30.0, 70.0), "shade": rng.randf()})


## Angle difference wrapped to -PI..PI.
static func wrap_angle(a: float) -> float:
	return fposmod(a + PI, TAU) - PI


# --- sky ------------------------------------------------------------------------------------

func draw_sky(pal: Dictionary, heading: float, t: float) -> void:
	var w := proj.screen.x
	var hy := proj.horizon_y
	var top: Color = pal["sky_top"]
	var mid: Color = pal["sky_mid"]
	var bot: Color = pal["sky_bottom"]
	var my := hy * 0.52
	batch.rect_v(Rect2(0, -40, w, my + 40), top, mid)
	batch.rect_v(Rect2(0, my, w, hy - my + 3), mid, bot)
	var f := proj.focal
	# stars
	var stars := float(pal.get("stars", 0.0))
	if stars > 0.02:
		for st in _stars:
			var x := w * 0.5 + wrap_angle(st.x - heading) * f
			if x < -2.0 or x > w + 2.0:
				continue
			var y := hy * 0.93 * (1.0 - st.y)
			var tw := 0.65 + 0.35 * sin(t * (1.3 + st.z) + st.x * 17.0)
			var a := stars * tw * clampf((hy - y) / (hy * 0.3), 0.15, 1.0)
			batch.rect(Rect2(x, y, st.z, st.z), Color(1.0, 1.0, 0.95, a))
	# horizon glow (dawn / dusk) around the sun azimuth
	var glow: Color = pal.get("glow", Color(0, 0, 0, 0))
	var sun_pos: Vector2 = pal.get("sun_pos", Vector2(0, 0.5))
	var sun_x := w * 0.5 + wrap_angle(sun_pos.x * 1.1 - heading) * f
	if glow.a > 0.02:
		var gc := Color(glow, glow.a * 0.85)
		batch.ellipse(Vector2(sun_x, hy), Vector2(w * 0.55, hy * 0.75), gc, Color(glow, 0.0), 24)
		batch.rect_v(Rect2(0, hy - 70.0, w, 72.0), Color(glow, 0.0), Color(glow, glow.a * 0.45))
	# moon
	if pal.get("moon_visible", false):
		var mp: Vector2 = pal["moon_pos"]
		var mx := w * 0.5 + wrap_angle(mp.x * 1.1 + 0.4 - heading) * f
		var myy := hy - (hy - 50.0) * mp.y - 20.0
		if mx > -60.0 and mx < w + 60.0:
			batch.ellipse(Vector2(mx, myy), Vector2(60, 60), Color(0.75, 0.8, 1.0, 0.12), Color(0.75, 0.8, 1.0, 0.0), 18)
			batch.ellipse(Vector2(mx, myy), Vector2(15, 15), Color("eef0ff"), Color("dfe3f5"), 18)
			batch.ellipse(Vector2(mx + 6.0, myy - 4.0), Vector2(13, 13), top.lerp(mid, 0.3), top.lerp(mid, 0.3), 18)
	# sun
	if pal.get("sun_visible", false):
		var sy := hy - (hy - 30.0) * pow(sun_pos.y, 0.8) + 6.0
		if sun_x > -120.0 and sun_x < w + 120.0:
			var sc: Color = pal["sun"]
			batch.ellipse(Vector2(sun_x, sy), Vector2(110, 110), Color(sc, 0.22), Color(sc, 0.0), 24)
			batch.ellipse(Vector2(sun_x, sy), Vector2(44, 44), Color(sc, 0.45), Color(sc, 0.0), 20)
			batch.ellipse(Vector2(sun_x, sy), Vector2(22, 22), Color(1, 1, 0.97), sc, 20)
	# clouds
	var overcast := float(pal.get("overcast", 0.0))
	var cl: Color = pal.get("cloud", Color.WHITE)
	var cd: Color = pal.get("cloud_dark", Color.GRAY)
	var cloud_alpha := 0.85 * (1.0 - overcast * 0.5) * (1.0 - float(pal.get("night", 0.0)) * 0.55)
	for c in _clouds:
		var x := w * 0.5 + wrap_angle(float(c["az"]) + t * 0.004 - heading) * f
		var cw := float(c["w"])
		if x < -cw or x > w + cw:
			continue
		var y := hy - float(c["elev"]) * (hy - 20.0)
		for pf: Vector4 in c["puffs"]:
			var center := Vector2(x + pf.x * cw, y + pf.y * cw)
			batch.ellipse(center, Vector2(pf.z, pf.w) * cw, Color(cl, cloud_alpha), Color(cd, cloud_alpha * 0.85), 10)
	if overcast > 0.01:
		batch.rect_v(Rect2(0, -40, w, hy * 0.65 + 40), Color(cd, 0.75 * overcast), Color(cd, 0.0))
		for c in _overcast:
			var x := w * 0.5 + wrap_angle(float(c["az"]) + t * 0.01 - heading) * f
			var rx := float(c["rx"])
			if x < -rx or x > w + rx:
				continue
			var y := hy * (1.0 - float(c["elev"]) * 0.85)
			var col := cd.lerp(cl, float(c["shade"]) * 0.6)
			batch.ellipse(Vector2(x, y), Vector2(rx, float(c["ry"])), Color(col, 0.55 * overcast), Color(col, 0.0), 14)


# --- background silhouettes -----------------------------------------------------------------

## bg: scenery "background" dictionary; scenery_id: key for change detection; t: seconds (real).
## haze: 0..1 extra fading towards the fog colour (rain, snow, night visibility).
func draw_background(pal: Dictionary, scenery_id: String, bg: Dictionary, heading: float, t: float, haze: float, base_y: float = -1.0) -> void:
	_base_y = proj.horizon_y if base_y < 0.0 else base_y
	if _last_t < 0.0:
		_last_t = t
	var dt := clampf(t - _last_t, 0.0, 0.5)
	_last_t = t
	if scenery_id != _cur_id:
		if _cur_id == "" :
			_blend = 1.0
		else:
			_prev_id = _cur_id
			_prev_bg = _cur_bg
			_blend = 0.0
		_cur_id = scenery_id
		_cur_bg = bg
	_blend = minf(1.0, _blend + dt / blend_s)
	if _blend < 1.0 and not _prev_bg.is_empty():
		_draw_style(pal, _prev_bg, heading, t, haze, 1.0 - smoothstep(0.0, 1.0, _blend), false)
	_draw_style(pal, _cur_bg, heading, t, haze, smoothstep(0.0, 1.0, _blend), true)


func _draw_style(pal: Dictionary, bg: Dictionary, heading: float, t: float, haze: float, grow: float, current: bool = true) -> void:
	if grow <= 0.01:
		return
	var style := str(bg.get("style", "hills"))
	if bg.has("behind"):
		_draw_behind(pal, bg, heading, haze, grow)
	var layers: Array = STYLES.get(style, STYLES["hills"])
	var cols: Array = bg.get("colors", ["#8aa2bd", "#6f8f6a", "#4f7448"])
	var hmul := float(bg.get("height", 1.0)) * grow
	var snow_caps := bool(bg.get("snow_caps", style == "alps"))
	var fog: Color = pal["fog"]
	var amb: Color = pal["ambient"]
	var snowy := float(pal.get("snow", 0.0))
	var lights := float(pal.get("lights", 0.0))
	for li in layers.size():
		var L: Dictionary = layers[li]
		var ci := mini(int(L.get("col", li)), cols.size() - 1)
		var base := Color(str(cols[ci]))
		if L.get("type", "") == "sea" and bg.has("sea"):
			base = Color(str(bg["sea"]))
		var col := base * amb
		if snowy > 0.0 and L.get("type", "") != "sea":
			col = col.lerp(Color("e6ebf0") * amb, 0.55 * snowy)
		var hz := clampf(float(L.get("haze", 0.3)) + haze * (1.0 - float(L.get("haze", 0.3))), 0.0, 0.97)
		var top := col.lerp(fog, hz)
		var bottom := col.lerp(fog, minf(0.98, hz + 0.25))
		var par := float(L.get("par", 1.0))
		var h := float(L.get("h", 30.0)) * hmul
		match str(L.get("type", "ridge")):
			"ridge":
				_draw_table_layer(L, top, bottom, h, par, heading, float(L.get("mask", 0.0)))
			"peaks":
				_draw_table_layer(L, top, bottom, h, par, heading, 0.0)
				if snow_caps:
					var snow := Color("f2f5fa") * amb.lerp(Color.WHITE, 0.1)
					_draw_snow_caps(L, snow.lerp(fog, hz * 0.8), h, par, heading, float(L.get("snow", 0.75)))
			"trees":
				_draw_trees(L, top, bottom, h, par, heading, str(bg.get("trees", L.get("tree", "round"))), grow)
			"skyline":
				_draw_skyline(L, top, bottom, h, par, heading, lights, bool(L.get("windows", false)), t, str(bg.get("roofs", "flat")))
			"houses":
				_draw_houses(L, top, bottom, h, par, heading, lights)
			"factory":
				_draw_factories(L, top, bottom, h, par, heading, lights, t, fog)
			"sea":
				_draw_sea(top, bottom, h, pal, heading)
		if li == 0:
			_draw_features(bg.get("features", []), top.lerp(fog, 0.15), heading, t, lights, grow)
			if current and not landmarks.is_empty() and sprite_cb.is_valid():
				_draw_landmarks(heading, grow, haze)


func _table(seed: int, kind: String, rough: float) -> PackedFloat32Array:
	var key := "%d:%s:%.2f" % [seed, kind, rough]
	if _tables.has(key):
		return _tables[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7717 + 3
	var n := TABLE_N
	var a := PackedFloat32Array()
	a.resize(n)
	# periodic midpoint displacement
	var step := n / 8
	for i in range(0, n, step):
		a[i] = rng.randf()
	var amp := 0.5
	while step > 1:
		var half := step / 2
		for i in range(0, n, step):
			var j := (i + step) % n
			a[i + half] = (a[i] + a[j]) * 0.5 + rng.randf_range(-amp, amp)
		amp *= rough
		step = half
	var lo := 1e9
	var hi := -1e9
	for v in a:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	for i in n:
		var v := (a[i] - lo) / maxf(0.0001, hi - lo)
		if kind == "peaks":
			v = pow(v, 1.35)
		elif kind == "ridge":
			v = 0.15 + 0.85 * smoothstep(0.0, 1.0, v)
		a[i] = v
	_tables[key] = a
	return a


static func _sample(a: PackedFloat32Array, u: float) -> float:
	var x := fposmod(u, 1.0) * float(a.size())
	var i := int(x)
	var fr := x - float(i)
	return lerpf(a[i % a.size()], a[(i + 1) % a.size()], fr)


func _u_at(x: float, par: float, heading: float) -> float:
	return ((x - proj.screen.x * 0.5) / proj.focal + heading * par) / TAU


func _mask(u: float, seed: int, cover: float) -> float:
	if cover <= 0.0:
		return 1.0
	var v := 0.5 + 0.5 * sin(TAU * (u * 2.0 + float(seed) * 0.13)) * 0.8 + 0.2 * sin(TAU * (u * 5.0 + float(seed) * 0.37))
	return smoothstep(1.0 - cover - 0.08, 1.0 - cover + 0.08, v)


func _draw_table_layer(L: Dictionary, top: Color, bottom: Color, h: float, par: float, heading: float, mask_cover: float) -> void:
	var a := _table(int(L.get("seed", 1)), str(L.get("type", "ridge")), float(L.get("rough", 0.5)))
	var n := a.size()
	var hy := _base_y
	var step := 8.0
	var seed := int(L.get("seed", 1))
	# u(x) is linear in x: u = u0 + x * du
	var du := 1.0 / (proj.focal * TAU)
	var u0 := (-proj.screen.x * 0.5 / proj.focal + heading * par) / TAU
	var x := -step
	var y0 := 0.0
	var first := true
	while x < proj.screen.x + step:
		var u := u0 + x * du
		var fx := (u - floorf(u)) * float(n)
		var i := int(fx)
		var v := lerpf(a[i % n], a[(i + 1) % n], fx - float(i))
		if mask_cover > 0.0:
			v *= _mask(u, seed, mask_cover)
		var y1 := hy - h * v
		if not first and (y0 < hy - 0.3 or y1 < hy - 0.3):
			batch.quad4(Vector2(x - step, y0), Vector2(x, y1), Vector2(x, hy + 2.0), Vector2(x - step, hy + 2.0), top, top, bottom, bottom)
		first = false
		y0 = y1
		x += step


func _draw_snow_caps(L: Dictionary, snow: Color, h: float, par: float, heading: float, line: float) -> void:
	var a := _table(int(L.get("seed", 1)), "peaks", float(L.get("rough", 0.5)))
	var hy := _base_y
	var step := 5.0
	var x := -step
	while x < proj.screen.x + step:
		var x1 := x + step
		var v0 := _sample(a, _u_at(x, par, heading))
		var v1 := _sample(a, _u_at(x1, par, heading))
		var u0 := _u_at(x, par, heading)
		var u1 := _u_at(x1, par, heading)
		var l0 := line + 0.06 * sin(u0 * 97.0) + 0.035 * sin(u0 * 331.0)
		var l1 := line + 0.06 * sin(u1 * 97.0) + 0.035 * sin(u1 * 331.0)
		if v0 > l0 or v1 > l1:
			var n0 := 0.05 * sin(u0 * 523.0 + v0 * 9.0)
			var n1 := 0.05 * sin(u1 * 523.0 + v1 * 9.0)
			var b0 := maxf(l0, v0 - 0.2 + n0)
			var b1 := maxf(l1, v1 - 0.2 + n1)
			batch.quad(Vector2(x, hy - h * v0), Vector2(x1, hy - h * v1), Vector2(x1, hy - h * minf(v1, b1)), Vector2(x, hy - h * minf(v0, b0)), snow)
		x = x1


func _tree_list(L: Dictionary) -> Array:
	var key := "%d:trees" % int(L.get("seed", 1))
	if _objects.has(key):
		return _objects[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(L.get("seed", 1)) * 131 + 7
	var out: Array = []
	var n := int(L.get("count", 200))
	for i in n:
		out.append(Vector3(rng.randf(), rng.randf_range(0.55, 1.0), rng.randf_range(0.7, 1.3)))
	_objects[key] = out
	return out


func _draw_trees(L: Dictionary, top: Color, bottom: Color, h: float, par: float, heading: float, tree: String, grow: float) -> void:
	# base strip (hedge/forest floor), then individual tree crowns on top
	_draw_table_layer({"seed": int(L.get("seed", 1)) + 500, "type": "ridge", "rough": 0.4}, top, bottom, h * 0.55, par, heading, float(L.get("mask", 0.0)))
	var hy := _base_y
	var period := TAU * proj.focal
	var shift := heading * par * proj.focal
	var th := float(L.get("tree_h", 14.0)) * grow
	var mask_cover := float(L.get("mask", 0.0))
	for tr3: Vector3 in _tree_list(L):
		var x := fposmod(tr3.x * period - shift + proj.screen.x * 0.5, period) - 0.0
		if x > proj.screen.x + 20.0:
			x -= period
		if x < -20.0 or x > proj.screen.x + 20.0:
			continue
		if mask_cover > 0.0 and _mask(tr3.x, int(L.get("seed", 1)), mask_cover) < 0.5:
			continue
		var th2 := th * tr3.y
		var base_y := hy - h * 0.35
		if tree == "conifer":
			var w2 := th2 * 0.32 * tr3.z
			batch.tri3(Vector2(x, base_y - th2), Vector2(x + w2, base_y + 1.0), Vector2(x - w2, base_y + 1.0), top, bottom, bottom)
		else:
			# round crown as an octagon-like blob (two quads)
			var r := th2 * 0.45 * tr3.z
			var cy := base_y - th2 * 0.55
			var mid := top.lerp(bottom, 0.35)
			batch.quad4(Vector2(x - r * 0.55, cy - th2 * 0.45), Vector2(x + r * 0.55, cy - th2 * 0.45), Vector2(x + r, cy), Vector2(x - r, cy), top, top, mid, mid)
			batch.quad4(Vector2(x - r, cy), Vector2(x + r, cy), Vector2(x + r * 0.9, base_y + 1.0), Vector2(x - r * 0.9, base_y + 1.0), mid, mid, bottom, bottom)


func _building_list(L: Dictionary) -> Array:
	var key := "%d:buildings" % int(L.get("seed", 1))
	if _objects.has(key):
		return _objects[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(L.get("seed", 1)) * 977 + 1
	var out: Array = []
	var n := int(L.get("count", 150))
	var u := 0.0
	var avg := 1.0 / float(n)
	while u < 1.0:
		var w := avg * rng.randf_range(0.5, 1.4)
		var tall := rng.randf() < 0.12
		var hgt := rng.randf_range(0.65, 1.0) if tall else rng.randf_range(0.15, 0.55)
		out.append({"u": u, "w": w * rng.randf_range(0.75, 1.0), "h": hgt, "antenna": tall and rng.randf() < 0.5,
			"tone": rng.randf_range(-0.06, 0.06), "seed": rng.randi()})
		u += w
	_objects[key] = out
	return out


func _draw_skyline(L: Dictionary, top: Color, bottom: Color, h: float, par: float, heading: float, lights: float, windows: bool, t: float, roofs: String = "flat") -> void:
	var hy := _base_y
	var period := TAU * proj.focal
	var shift := heading * par * proj.focal
	var win := Color(1.0, 0.85, 0.5, 0.85 * lights)
	for b: Dictionary in _building_list(L):
		var x0 := fposmod(float(b["u"]) * period - shift + proj.screen.x * 0.5, period)
		var bw := float(b["w"]) * period
		if x0 > proj.screen.x:
			x0 -= period
		if x0 + bw < 0.0 or x0 > proj.screen.x:
			continue
		var bh := float(b["h"]) * h
		var tone := float(b["tone"])
		var ct := Color(top.r + tone, top.g + tone, top.b + tone, top.a)
		batch.quad4(Vector2(x0, hy - bh), Vector2(x0 + bw, hy - bh), Vector2(x0 + bw, hy + 2.0), Vector2(x0, hy + 2.0), ct, ct, bottom, bottom)
		if roofs != "flat" and not bool(b["antenna"]) and float(b["h"]) < 0.62:
			_roof(roofs, int(b["seed"]), x0, bw, hy - bh, ct)
		if bool(b["antenna"]) and bh > 6.0:
			batch.rect(Rect2(x0 + bw * 0.5 - 0.6, hy - bh - bh * 0.18, 1.2, bh * 0.18), ct)
			if lights > 0.2 and fmod(t + float(int(b["seed"]) % 7) * 0.3, 1.6) < 0.8:
				batch.rect(Rect2(x0 + bw * 0.5 - 1.2, hy - bh - bh * 0.18 - 1.5, 2.4, 2.4), Color(1, 0.15, 0.1, lights))
		if windows and lights > 0.15 and bw > 6.0 and bh > 8.0:
			var rng_v := int(b["seed"])
			var cols := int(bw / 5.0)
			var rows := int(bh / 6.0)
			for r in rows:
				for c in cols:
					rng_v = (rng_v * 1103515245 + 12345) & 0x7fffffff
					if rng_v % 100 < 28:
						batch.rect(Rect2(x0 + 2.0 + c * 5.0, hy - bh + 3.0 + r * 6.0, 2.0, 2.5), win)


## Roof on a skyline building (x0, width bw, eave row y): gable, mansard, stepped (Dutch) gable or mixed.
func _roof(kind: String, seed: int, x0: float, bw: float, y: float, col: Color) -> void:
	var k := kind
	if kind == "mixed":
		k = ["flat", "gable", "gable", "mansard"][seed % 4]
	var rh := minf(bw * 0.42, 22.0)
	match k:
		"gable":
			batch.tri(Vector2(x0, y), Vector2(x0 + bw, y), Vector2(x0 + bw * 0.5, y - rh * 0.8), col)
		"mansard":
			batch.quad(Vector2(x0 + bw * 0.12, y - rh * 0.55), Vector2(x0 + bw * 0.88, y - rh * 0.55), Vector2(x0 + bw, y), Vector2(x0, y), col)
		"stepped":
			var n := 3
			for i in n:
				var f := float(i) / float(n)
				var w := bw * (1.0 - f) * 0.5
				batch.rect(Rect2(x0 + bw * 0.5 - w, y - rh * (f + 1.0 / float(n)) * 0.9, w * 2.0, rh * 0.9 / float(n) + 0.5), col)


func _house_list(L: Dictionary) -> Array:
	var key := "%d:houses" % int(L.get("seed", 1))
	if _objects.has(key):
		return _objects[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(L.get("seed", 1)) * 547 + 9
	var out: Array = []
	for i in int(L.get("count", 160)):
		out.append(Vector4(rng.randf(), rng.randf_range(0.6, 1.0), rng.randf_range(0.7, 1.3), float(rng.randi() % 1000)))
	_objects[key] = out
	return out


## Low houses with pitched roofs between trees (outskirts, style "suburb"); lit windows at night.
func _draw_houses(L: Dictionary, top: Color, bottom: Color, h: float, par: float, heading: float, lights: float) -> void:
	var hy := _base_y
	var period := TAU * proj.focal
	var shift := heading * par * proj.focal
	var roof := top.darkened(0.18)
	var win := Color(1.0, 0.85, 0.5, 0.9 * lights)
	for hv: Vector4 in _house_list(L):
		var x := fposmod(hv.x * period - shift + proj.screen.x * 0.5, period)
		if x > proj.screen.x + 20.0:
			x -= period
		if x < -20.0 or x > proj.screen.x + 20.0:
			continue
		var hw := h * 0.55 * hv.z
		var hh := h * 0.55 * hv.y
		batch.quad4(Vector2(x - hw, hy - hh), Vector2(x + hw, hy - hh), Vector2(x + hw, hy + 1.0), Vector2(x - hw, hy + 1.0), top, top, bottom, bottom)
		batch.tri(Vector2(x - hw * 1.12, hy - hh), Vector2(x + hw * 1.12, hy - hh), Vector2(x, hy - hh - h * 0.42 * hv.y), roof)
		if lights > 0.15 and int(hv.w) % 3 != 0:
			batch.rect(Rect2(x - hw * 0.5, hy - hh * 0.65, hw * 0.35, hh * 0.3), win)


## Mountain or hill range behind a city skyline ("behind": mountains|alps|hills, or {style, height}).
func _draw_behind(pal: Dictionary, bg: Dictionary, heading: float, haze: float, grow: float) -> void:
	var b: Variant = bg.get("behind")
	var style := str(b.get("style", "hills")) if b is Dictionary else str(b)
	var hmul := (float((b as Dictionary).get("height", 1.0)) if b is Dictionary else 1.0) * grow
	var layers: Array = STYLES.get(style, STYLES["hills"])
	var L: Dictionary = layers[0]
	var cols: Array = bg.get("colors", ["#8aa2bd"])
	var fog: Color = pal["fog"]
	var col := Color(str(cols[0])).darkened(0.05) * (pal["ambient"] as Color)
	var hz := clampf(0.55 + haze * 0.45, 0.0, 0.97)
	var top := col.lerp(fog, hz)
	var bottom := col.lerp(fog, minf(0.98, hz + 0.2))
	var h := float(L.get("h", 60.0)) * hmul
	_draw_table_layer(L, top, bottom, h, 0.97, heading, 0.0)
	if style == "alps" or style == "mountains":
		var snow := Color("eef2f8") * (pal["ambient"] as Color)
		_draw_snow_caps(L, snow.lerp(fog, hz * 0.85), h, 0.97, heading, float(L.get("snow", 0.6)))


## Skyline landmarks (renderer list): sprite or procedural silhouette at its panorama angle, hazy, growing
## with the background blend.
func _draw_landmarks(heading: float, grow: float, haze: float) -> void:
	var hz := clampf(0.5 + haze * 0.4, 0.0, 0.95)
	for e: Dictionary in landmarks:
		var x := proj.screen.x * 0.5 + wrap_angle(float(e["angle"]) - heading) * proj.focal
		if x < -400.0 or x > proj.screen.x + 400.0:
			continue
		sprite_cb.call(e["entry"], Vector2(x, _base_y + 1.0), float(e["s"]) * grow, float(e["alpha"]) * grow, hz)


func _factory_list(L: Dictionary) -> Array:
	var key := "%d:factories" % int(L.get("seed", 1))
	if _objects.has(key):
		return _objects[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(L.get("seed", 1)) * 313 + 5
	var out: Array = []
	var n := int(L.get("count", 60))
	for i in n:
		var r := rng.randf()
		var kind := "hall"
		if r < 0.35:
			kind = "chimney"
		elif r < 0.45:
			kind = "tower"
		out.append({"u": rng.randf(), "kind": kind, "w": rng.randf_range(0.6, 1.4), "h": rng.randf_range(0.5, 1.0), "seed": rng.randi()})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["u"]) < float(b["u"]))
	_objects[key] = out
	return out


func _draw_factories(L: Dictionary, top: Color, bottom: Color, h: float, par: float, heading: float, lights: float, t: float, fog: Color) -> void:
	var hy := _base_y
	var period := TAU * proj.focal
	var shift := heading * par * proj.focal
	for f: Dictionary in _factory_list(L):
		var x := fposmod(float(f["u"]) * period - shift + proj.screen.x * 0.5, period)
		if x > proj.screen.x + 60.0:
			x -= period
		if x < -60.0 or x > proj.screen.x + 60.0:
			continue
		var fw := float(f["w"])
		var fh := float(f["h"])
		match str(f["kind"]):
			"hall":
				var w := 46.0 * fw
				var hh := h * 0.32 * fh
				batch.quad4(Vector2(x - w * 0.5, hy - hh), Vector2(x + w * 0.5, hy - hh), Vector2(x + w * 0.5, hy + 2.0), Vector2(x - w * 0.5, hy + 2.0), top, top, bottom, bottom)
				var teeth := maxi(2, int(w / 9.0))
				var tw := w / float(teeth)
				for i in teeth:
					var x0 := x - w * 0.5 + tw * i
					batch.tri(Vector2(x0, hy - hh), Vector2(x0 + tw, hy - hh), Vector2(x0 + tw, hy - hh - tw * 0.55), top)
			"chimney":
				var cw := 3.2 * fw
				var ch := h * (0.7 + 0.3 * fh)
				batch.quad4(Vector2(x - cw * 0.5, hy - ch), Vector2(x + cw * 0.5, hy - ch), Vector2(x + cw * 0.75, hy + 2.0), Vector2(x - cw * 0.75, hy + 2.0), top, top, bottom, bottom)
				# smoke drifting away
				var smoke := Color(fog.lerp(Color(0.85, 0.85, 0.85), 0.3), 0.32)
				for k in 5:
					var age := fposmod(t * 0.35 + float(k) * 0.2 + float(int(f["seed"]) % 10) * 0.07, 1.0)
					var r := 3.0 + age * 14.0
					batch.ellipse(Vector2(x + age * 26.0, hy - ch - 2.0 - age * 22.0), Vector2(r, r * 0.7), Color(smoke, smoke.a * (1.0 - age)), Color(smoke, 0.0), 8)
				if lights > 0.2 and fmod(t + float(int(f["seed"]) % 5) * 0.4, 2.0) < 1.0:
					batch.rect(Rect2(x - 1.5, hy - ch - 1.5, 3.0, 3.0), Color(1, 0.12, 0.08, lights))
			"tower":
				var tw2 := 18.0 * fw
				var th := h * 0.55 * fh
				var waist := hy - th * 0.68
				batch.quad4(Vector2(x - tw2 * 0.36, waist), Vector2(x + tw2 * 0.36, waist), Vector2(x + tw2 * 0.5, hy + 2.0), Vector2(x - tw2 * 0.5, hy + 2.0), top, top, bottom, bottom)
				batch.quad4(Vector2(x - tw2 * 0.4, hy - th), Vector2(x + tw2 * 0.4, hy - th), Vector2(x + tw2 * 0.36, waist), Vector2(x - tw2 * 0.36, waist), top, top, top, top)
				var steam := Color(Color(0.93, 0.94, 0.95).lerp(fog, 0.4), 0.45)
				for k in 3:
					var age := fposmod(t * 0.18 + float(k) * 0.33, 1.0)
					batch.ellipse(Vector2(x + age * 10.0, hy - th - 6.0 - age * 26.0), Vector2(tw2 * (0.35 + age * 0.5), 8.0 + age * 8.0), Color(steam, steam.a * (1.0 - age)), Color(steam, 0.0), 10)


func _draw_sea(top: Color, bottom: Color, h: float, pal: Dictionary, heading: float) -> void:
	var hy := _base_y
	var w := proj.screen.x
	# open sea on part of the panorama (the coast line turns with the road)
	var period := TAU * proj.focal
	var shift := heading * proj.focal
	batch.rect_v(Rect2(0, hy - h, w, h + 2.0), top.lightened(0.12), bottom)
	batch.rect(Rect2(0, hy - h - 1.0, w, 1.5), top.lightened(0.3))
	# a few ships on the horizon
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	for i in 9:
		var x := fposmod(rng.randf() * period - shift + w * 0.5, period)
		var sw := rng.randf_range(10.0, 26.0)
		if x > w + 30.0:
			x -= period
		if x < -30.0 or x > w + 30.0:
			continue
		var col := top.darkened(0.45)
		batch.quad(Vector2(x - sw * 0.5, hy - h - 2.0), Vector2(x + sw * 0.5, hy - h - 2.0), Vector2(x + sw * 0.42, hy - h + 1.0), Vector2(x - sw * 0.42, hy - h + 1.0), col)
		batch.rect(Rect2(x - sw * 0.12, hy - h - 5.0, sw * 0.24, 3.0), col)
	# glitter towards the sun
	if pal.get("sun_visible", false):
		var sp: Vector2 = pal["sun_pos"]
		var sx := w * 0.5 + wrap_angle(sp.x * 1.1 - heading) * proj.focal
		var sc: Color = pal["sun"]
		batch.ellipse(Vector2(sx, hy - h * 0.45), Vector2(150, h * 0.5), Color(sc, 0.55), Color(sc, 0.0), 16)


## Small silhouettes on the far layer: wind turbines (rotating), church spires, power pylons.
func _draw_features(features: Array, col: Color, heading: float, t: float, lights: float, grow: float) -> void:
	if features.is_empty():
		return
	var hy := _base_y
	var period := TAU * proj.focal
	var shift := heading * proj.focal
	for fi in features.size():
		var kind := str(features[fi])
		var rng := RandomNumberGenerator.new()
		rng.seed = 900 + fi * 31
		var n := 26 if kind == "turbines" else 18
		for i in n:
			var u := rng.randf()
			var scale := rng.randf_range(0.6, 1.1) * grow
			var x := fposmod(u * period - shift + proj.screen.x * 0.5, period)
			if x > proj.screen.x + 30.0:
				x -= period
			if x < -30.0 or x > proj.screen.x + 30.0:
				continue
			match kind:
				"turbines":
					var th := 34.0 * scale
					batch.quad(Vector2(x - 0.6, hy - th), Vector2(x + 0.6, hy - th), Vector2(x + 1.0, hy + 1.0), Vector2(x - 1.0, hy + 1.0), col)
					var hub := Vector2(x, hy - th)
					var rot := t * 1.4 + float(i)
					for b in 3:
						var a := rot + TAU * float(b) / 3.0
						batch.line(hub, hub + Vector2(cos(a), sin(a)) * th * 0.45, 1.1, col)
					if lights > 0.3 and fmod(t + float(i) * 0.17, 1.5) < 0.6:
						batch.rect(Rect2(x - 1.2, hy - th - 1.2, 2.4, 2.4), Color(1, 0.1, 0.05, lights))
				"spires":
					var sh := 24.0 * scale
					batch.rect(Rect2(x - 3.0 * scale, hy - sh * 0.45, 6.0 * scale, sh * 0.45 + 1.0), col)
					batch.tri(Vector2(x, hy - sh), Vector2(x + 3.4 * scale, hy - sh * 0.45), Vector2(x - 3.4 * scale, hy - sh * 0.45), col)
					batch.rect(Rect2(x - 9.0 * scale, hy - sh * 0.25, 7.0 * scale, sh * 0.25 + 1.0), col)
				"pylons":
					var ph := 26.0 * scale
					batch.tri(Vector2(x, hy - ph), Vector2(x + 4.0 * scale, hy + 1.0), Vector2(x - 4.0 * scale, hy + 1.0), Color(col, 0.75))
					batch.rect(Rect2(x - 6.0 * scale, hy - ph * 0.8, 12.0 * scale, 1.2), col)
					batch.rect(Rect2(x - 4.5 * scale, hy - ph * 0.62, 9.0 * scale, 1.2), col)
				"chimneys":
					var ch := 30.0 * scale
					batch.rect(Rect2(x - 1.5, hy - ch, 3.0, ch + 1.0), col)
				"cranes":
					# harbour crane: legs, machine house, jib reaching out
					var ch := 30.0 * scale
					batch.quad(Vector2(x - 5.0 * scale, hy + 1.0), Vector2(x - 3.0 * scale, hy - ch * 0.55), Vector2(x - 1.8 * scale, hy - ch * 0.55), Vector2(x - 3.4 * scale, hy + 1.0), col)
					batch.quad(Vector2(x + 3.4 * scale, hy + 1.0), Vector2(x + 1.8 * scale, hy - ch * 0.55), Vector2(x + 3.0 * scale, hy - ch * 0.55), Vector2(x + 5.0 * scale, hy + 1.0), col)
					batch.rect(Rect2(x - 4.0 * scale, hy - ch * 0.72, 8.0 * scale, ch * 0.18), col)
					var dir := 1.0 if i % 2 == 0 else -1.0
					batch.line(Vector2(x, hy - ch * 0.7), Vector2(x + dir * 20.0 * scale, hy - ch * 0.95), 1.4, col)
					batch.line(Vector2(x, hy - ch * 0.98), Vector2(x + dir * 20.0 * scale, hy - ch * 0.95), 0.9, col)
					batch.line(Vector2(x, hy - ch * 0.7), Vector2(x, hy - ch * 1.02), 1.2, col)
				"domes":
					var dh := 22.0 * scale
					batch.rect(Rect2(x - 5.0 * scale, hy - dh * 0.55, 10.0 * scale, dh * 0.55 + 1.0), col)
					batch.ellipse(Vector2(x, hy - dh * 0.55), Vector2(5.0 * scale, 4.6 * scale), col, col, 10)
					batch.rect(Rect2(x - 0.8 * scale, hy - dh * 0.55 - 7.0 * scale, 1.6 * scale, 3.0 * scale), col)
				"onion":
					var oh := 20.0 * scale
					batch.rect(Rect2(x - 3.0 * scale, hy - oh * 0.6, 6.0 * scale, oh * 0.6 + 1.0), col)
					batch.ellipse(Vector2(x, hy - oh * 0.6 - 2.4 * scale), Vector2(3.4 * scale, 3.0 * scale), col, col, 10)
					batch.tri(Vector2(x - 2.4 * scale, hy - oh * 0.6 - 4.0 * scale), Vector2(x + 2.4 * scale, hy - oh * 0.6 - 4.0 * scale), Vector2(x, hy - oh * 0.6 - 9.0 * scale), col)
					batch.rect(Rect2(x - 10.0 * scale, hy - oh * 0.3, 7.0 * scale, oh * 0.3 + 1.0), col)
				"slabs":
					# prefabricated high-rise slabs (Plattenbau)
					var sh := 34.0 * scale
					var sw := 26.0 * scale
					batch.rect(Rect2(x - sw * 0.5, hy - sh, sw, sh + 1.0), col)
					if lights > 0.15:
						var wc := Color(1.0, 0.86, 0.55, 0.7 * lights)
						for r in 6:
							for c in 5:
								if (i * 7 + r * 3 + c * 5) % 4 == 0:
									batch.rect(Rect2(x - sw * 0.5 + 2.0 + c * sw / 5.0, hy - sh + 3.0 + r * sh / 6.5, 2.0, 2.0), wc)
				"towers":
					# cluster of modern high-rises
					for j in 3:
						var tw := (7.0 + 2.0 * float(j)) * scale
						var th := (62.0 - 14.0 * float(j)) * scale
						var tx := x + (float(j) - 1.0) * 12.0 * scale
						batch.rect(Rect2(tx - tw * 0.5, hy - th, tw, th + 1.0), col)
						if j == 0:
							batch.rect(Rect2(tx - 0.5, hy - th - 8.0 * scale, 1.0, 8.0 * scale), col)
						if lights > 0.3 and fmod(t + float(i) * 0.3, 1.8) < 0.9:
							batch.rect(Rect2(tx - 1.2, hy - th - 1.5, 2.4, 2.4), Color(1, 0.15, 0.1, lights))
