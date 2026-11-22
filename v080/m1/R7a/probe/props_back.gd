extends SceneTree
## R7a probe (headless): what the sight corridor of A-17 gives back against the corridor of the base (constant band of
## a 300-m chord's sagitta, sharpest curvature within ±150 m – reproduced here with TerrainProfile._kappa(), which is
## unchanged), on the same tracks:
##  * props that the props builder drops in a bend corridor (its drop_reason(): decorative or vegetation, not a
##    landmark, not a cover set) – old / new / came back / newly dropped, by class and city/rural;
##  * city fence pieces (builders/city.gd: segment and side, Arcade's gaps) – old (middle) / new (middle or ends);
##  * per position: the props within 150 m ahead of the camera (as FIX-M2's qa_props.gd).
##   godot --headless --path . -s <this> [-- --full] [--stage=<id>,…]
const Fair := preload("res://tests/race3d/fairness.gd")
const Props := preload("res://scripts/race3d/builders/props.gd")

const POSITIONS := [["T4", "saragossa_pau", "saragossa", 199.7], ["T3", "saragossa_pau", "saragossa", 173.5],
	["T1", "kassel_wuerzburg", "kassel", 47.5], ["T2", "kassel_wuerzburg", "kassel", 61.9], ["C1", "dortmund_frankfurt", "dortmund", 221.8],
	["S4", "kiel_hamburg", "kiel", 80.4], ["S0", "kiel_hamburg", "kiel", 0.0], ["Lyon", "montpellier_lyon", "montpellier", 297.4],
	["Bern", "lyon_bern", "lyon", 302.7], ["Muenchen", "muenchen_nuernberg", "nuernberg", 161.7],
	["Nuernberg", "wuerzburg_nuernberg", "wuerzburg", 102.7], ["Belgrad", "slavonski_brod_belgrad", "slavonski_brod", 187.4],
	["Hannover", "hamburg_hannover", "hamburg", 142.4]]


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var full := false
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a == "--full":
			full = true
		elif a.begins_with("--stage="):
			only = Array(a.substr(8).split(",", false))
	var dirs: Array[Dictionary] = []
	if full:
		dirs = Fair.directions(net, [])
	else:
		var names: Array = []
		for p: Array in POSITIONS:
			var nm := "%s__%s" % [p[1], p[2]]
			if not names.has(nm):
				names.append(nm)
		if not only.is_empty():
			names = only
		dirs = Fair.directions(net, names)
		var keep: Array[Dictionary] = []
		for d: Dictionary in dirs:
			if names.has(str(d["name"])) or not only.is_empty():
				keep.append(d)
		dirs = keep
	var lib: PropLibrary = Props.new()._lib()
	var cover: Array = ConfigLoader.lookup(cfg, "graphics.modern.props.bend_cover", [])
	var tc: Dictionary = ConfigLoader.lookup(cfg, "graphics.modern.terrain", {})
	var tot := {}
	var t0 := Time.get_ticks_msec()
	for dir: Dictionary in dirs:
		var geo := Fair.build_geo(cfg, net, dir, net["scenery"])
		var track: Track = geo["track"]
		var path: RoadPath3D = geo["path"]
		path.set_clear_reach(1500.0 + 150.0 + 192.0)
		var tp := TerrainProfile.new()
		tp.setup(path, track, tc, net["scenery"])
		var n := int(geo["nz"])
		var res := _scan(track, tp, lib, cover, net["scenery"], 0, n)
		for key: String in res:
			tot[key] = int(tot.get(key, 0)) + int(res[key])
		print("BACK %-40s %s" % [dir["name"], _fmt(res)])
		for p: Array in POSITIONS:
			if "%s__%s" % [p[1], p[2]] != str(dir["name"]):
				continue
			var car := track.km_to_z(float(p[3]))
			var cam := car - 9.0
			var k0 := maxi(0, int(floor(cam / track.seg_len)))
			var k1 := mini(n - 1, int(ceil((cam + 150.0) / track.seg_len)))
			var r := _scan(track, tp, lib, cover, net["scenery"], k0, k1, cam, cam + 150.0)
			print("POS %-9s %s km %.1f (150 m ahead): %s" % [p[0], dir["name"], float(p[3]), _fmt(r)])
		geo["path"] = null
	print("BACK TOTAL %d directions: %s  (%.0f s)" % [dirs.size(), _fmt(tot), (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)


static func _fmt(r: Dictionary) -> String:
	return "props %d, corridor old %d new %d, back %d (trees %d, plants %d, rocks %d, buildings %d, city buildings %d), newly dropped %d; fences arcade %d, old drawn %d, new drawn %d" % [
		int(r.get("props", 0)), int(r.get("old", 0)), int(r.get("new", 0)), int(r.get("back", 0)), int(r.get("back_tree", 0)),
		int(r.get("back_plant", 0)), int(r.get("back_rock", 0)), int(r.get("back_building", 0)), int(r.get("back_city_building", 0)),
		int(r.get("newly", 0)), int(r.get("fence", 0)), int(r.get("fence_old", 0)), int(r.get("fence_new", 0))]


## The corridor of the base: the sagitta of a corridor_chord_m chord from the paved edge with the sharpest curvature
## of that side within half a chord (TerrainProfile._kappa(), unchanged), at least corridor_min_m from the paved edge.
static func _old_width(tp: TerrainProfile, track: Track, k: int, side: int) -> float:
	var kap := tp._kappa(k)
	var s := track.get_segment(k)
	var half := s.lanes * track.lane_w * 0.5
	var paved := half if side < 0 else half + s.fuel_lane * track.lane_w
	var k_c := kap.x if side < 0 else kap.y
	var corr := tp.corridor_min_m
	if k_c > 1.0e-7:
		var k_edge := k_c / maxf(0.05, 1.0 - k_c * paved)
		corr = maxf(corr, tp.corridor_chord_m * tp.corridor_chord_m * 0.125 * k_edge)
	return maxf(0.0, corr - track.shoulder_w)


static func _setof(lib: PropLibrary, id: String) -> Dictionary:
	if id == "":
		return {}
	if not lib.sets.has(id):
		if not lib._have_sprites:
			lib._load_sprite_manifest()
		lib.sets[id] = lib._resolve(id)
	return lib.sets[id]


static func _paved(track: Track, k: int, side: int) -> float:
	var s := track.get_segment(k)
	var half := s.lanes * track.lane_w * 0.5
	return half if side < 0 else half + s.fuel_lane * track.lane_w


## ChunkContext.in_bend_corridor() on the whole track, old or new corridor.
static func _in_bend(tp: TerrainProfile, track: Track, z: float, x: float, old: bool) -> bool:
	var f := z / track.seg_len
	var k := maxi(int(floor(f)), 0)
	var u := clampf(f - float(k), 0.0, 1.0)
	var side := -1 if x < 0.0 else 1
	var e := lerpf(_paved(track, k, side), _paved(track, k + 1, side), u)
	var m := absf(x) - e - track.shoulder_w
	var c0 := _old_width(tp, track, k, side) if old else tp.corridor_width(k, side)
	var c1 := _old_width(tp, track, k + 1, side) if old else tp.corridor_width(k + 1, side)
	var cw := lerpf(c0, c1, u)
	var cmin := maxf(0.0, tp.corridor_min_m - track.shoulder_w)
	return cw > cmin + 0.5 and m > 0.0 and m <= cw


static func _scan(track: Track, tp: TerrainProfile, lib: PropLibrary, cover: Array, scen: Dictionary, k0: int, k1: int,
		z_from: float = -INF, z_to: float = INF) -> Dictionary:
	var r := {}
	for k in range(k0, k1):
		var s := track.get_segment(k)
		for j in s.sprites.size():
			var it: Dictionary = s.sprites[j]
			if str(it.get("kind", "prop")) != "prop":
				continue
			var set_id := str(it.get("set", ""))
			var e := _setof(lib, set_id)
			if e.is_empty() or int(e["kind"]) == PropLibrary.NONE:
				e = _setof(lib, str(it.get("fallback", "")))
				if e.is_empty() or int(e["kind"]) == PropLibrary.NONE:
					continue
			var side := int(it.get("side", 1))
			if side == 0:
				continue
			var x := float(it.get("x", 0.0))
			var z := float(it.get("z", s.z))
			if z < z_from or z > z_to:
				continue
			var beyond := absf(x) - (_paved(track, k, side) + track.shoulder_w)
			if beyond > tp.limit(k, side) - Props.RIBBON_MARGIN_M:
				continue
			r["props"] = int(r.get("props", 0)) + 1
			var decorative := not it.has("offset")
			if not (decorative or bool(e["veg"])) or bool(it.get("landmark", false)) or cover.has(str(e["set"])):
				continue
			var was := _in_bend(tp, track, z, x, true)
			var now := _in_bend(tp, track, z, x, false)
			if was:
				r["old"] = int(r.get("old", 0)) + 1
			if now:
				r["new"] = int(r.get("new", 0)) + 1
			if was and not now:
				r["back"] = int(r.get("back", 0)) + 1
				var cls := str(e["cls"])
				var key := "back_" + (cls if cls in ["tree", "plant", "rock"] else "building" if cls == "building" else "other")
				if s.city and cls == "building":
					key = "back_city_building"
				r[key] = int(r.get(key, 0)) + 1
			if now and not was:
				r["newly"] = int(r.get("newly", 0)) + 1
		# city fences (builders/city.gd)
		if s.city and not s.tunnel and not s.water:
			var fd: Variant = (scen.get(s.scenery, {}) as Dictionary).get("fence")
			if fd is Dictionary:
				var every := float((fd as Dictionary).get("gap_every_m", 24.0))
				var gap := float((fd as Dictionary).get("gap_m", 3.5))
				var off := float((fd as Dictionary).get("x", 0.6))
				var z0 := float(k) * track.seg_len
				var z1 := z0 + track.seg_len
				if (z0 + z1) * 0.5 < z_from or (z0 + z1) * 0.5 > z_to:
					continue
				for side: int in [-1, 1]:
					if every > 0.0 and fposmod(s.z + (every * 0.5 if side > 0 else 0.0), every) < gap:
						continue
					r["fence"] = int(r.get("fence", 0)) + 1
					var xa := float(side) * (_paved(track, k, side) + track.shoulder_w + off)
					var xb := float(side) * (_paved(track, k + 1, side) + track.shoulder_w + off)
					if not _in_bend(tp, track, (z0 + z1) * 0.5, (xa + xb) * 0.5, true):
						r["fence_old"] = int(r.get("fence_old", 0)) + 1
					if not (_in_bend(tp, track, (z0 + z1) * 0.5, (xa + xb) * 0.5, false) or _in_bend(tp, track, z0, xa, false)
							or _in_bend(tp, track, z1, xb, false)):
						r["fence_new"] = int(r.get("fence_new", 0)) + 1
	return r
