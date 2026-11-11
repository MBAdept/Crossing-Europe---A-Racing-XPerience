class_name TerrainProfile
extends RefCounted
## Kernel of the mode "Modern" (v0.8.0): the terrain as a ruled ribbon beside the road – pure numbers, used by the
## terrain mesh builder, the prop placement (ChunkContext.ground()) and the fairness tests.
##
## Per cross-section (row k = boundary k of the RoadPath3D) and side (-1 left, +1 right) the ribbon is a polyline of
## rings: distances beyond the outer shoulder edge (ring_offsets) and heights relative to the road height of that
## cross-section (ring_heights); height() is the straight line between them – exactly what a mesh built from the
## rings shows.
##  * Distances: graphics.modern.terrain.rings_m (0/5/15/40/100/220/480 m; the last one is the outer ring, 1,000 m on
##    "Details: Hoch"). The ribbon is cut where it would leave its own ground: on the inside of a bend at
##    inside_bend_factor * radius, anywhere at the medial axis to another part of the road
##    (RoadPath3D.clearance() - clear_margin_m). A cut ribbon keeps its inner rings where they fit and spreads the
##    others (ring i at most limit * (i / last)^cap_power), so the last ring always has room to fall.
##  * Heights: verge and ditch (profile), then mild relief (value noise along the road, scaled by the hills level of
##    the section, none in City Limits, tunnels and on bridges), the last ring on the valley floor
##    (RoadPath3D.floor_y(): below every road nearby, so it cannot hide anything). On a bridge the rings lie on the
##    water (TrackSegment.water_level).
##  * Sight corridor (fairness rule F7): on the inside of a bend up to the sagitta of a corridor_chord_m chord
##    (measured from the paved edge with the radius of that edge, the sharpest curvature within half a chord of
##    path), elsewhere corridor_min_m from the paved edge. Inside it the ground is never above the road: relief is
##    only added to a ring whose inner neighbour already lies outside the corridor.
## Everything is a pure function of the road around the row, so two chunks that share a row get the same numbers.
## Config: graphics.modern.terrain (all keys optional, defaults below). Owner: race3d kernel.
## Docs: docs/renderer-modern.md.

const DEFAULT_RINGS: Array[float] = [0.0, 5.0, 15.0, 40.0, 100.0, 220.0, 480.0]
## Verge and ditch: [metres beyond the shoulder, height relative to the road] – never above the road.
const DEFAULT_PROFILE: Array = [[0.0, 0.0], [5.0, -0.35], [15.0, -0.6], [40.0, -1.1], [100.0, -2.6], [220.0, -4.0]]
const DEFAULT_HILL_FACTORS: Array[float] = [0.4, 0.7, 1.0, 1.5]
const COARSE := 8                      ## rows between two evaluations of the corridor curvature and the relief level

var path: RoadPath3D
var track: Track
var scenery_db: Dictionary = {}
var rings := PackedFloat32Array()      ## ring distances beyond the shoulder (m), unclamped
var inside_bend_factor := 0.8
var clear_margin_m := 6.0              ## the ribbon ends this far before the medial axis to another road part
var min_width_m := 3.0                 ## smallest ribbon width beyond the shoulder
var cap_power := 1.6
var corridor_chord_m := 300.0
var corridor_min_m := 8.0              ## from the paved edge
var relief_m := 3.0                    ## relief amplitude at hills level 2 (m)
var relief_wavelength_m := 260.0
var relief_from_m := 30.0              ## relief fades in between these distances beyond the shoulder
var relief_full_m := 100.0
var relief_ramp_m := 120.0             ## the relief level changes over this path length
var hill_factors := PackedFloat32Array()

var _profile_x := PackedFloat32Array()
var _profile_h := PackedFloat32Array()
var _n := 7
var _seed := 0
var _kappa_cache: Dictionary = {}      ## coarse row -> Vector2(sharpest curvature to the left, to the right) (1/m)
var _amp_cache: Dictionary = {}        ## coarse row -> relief level (0..)
var _rows: Dictionary = {}             ## row -> PackedFloat32Array (single-row queries)
# result of _compute(): ring distances / heights (left rings, then right rings) and the row's widths
var _cx := PackedFloat32Array()
var _ch := PackedFloat32Array()
var _c_edge := Vector2.ZERO            ## outer shoulder edge from the centreline (left, right; both positive)
var _c_limit := Vector2.ZERO           ## ribbon width beyond the shoulder
var _c_corr := Vector2.ZERO            ## sight corridor beyond the shoulder


func setup(p: RoadPath3D, t: Track, terrain_cfg: Dictionary, scenery: Dictionary) -> void:
	path = p
	track = t
	scenery_db = scenery
	rings.clear()
	var list: Variant = terrain_cfg.get("rings_m", DEFAULT_RINGS)
	if not (list is Array) or (list as Array).size() < 3:
		list = DEFAULT_RINGS
	var prev := -1.0
	for v: Variant in list:
		var m := maxf(float(v), prev + 0.5) if prev >= 0.0 else 0.0
		rings.append(m)
		prev = m
	_n = rings.size()
	inside_bend_factor = clampf(float(terrain_cfg.get("inside_bend_factor", 0.8)), 0.1, 0.95)
	clear_margin_m = maxf(0.0, float(terrain_cfg.get("clear_margin_m", 6.0)))
	min_width_m = maxf(0.5, float(terrain_cfg.get("min_width_m", 3.0)))
	cap_power = clampf(float(terrain_cfg.get("cap_power", 1.6)), 1.0, 4.0)
	corridor_chord_m = maxf(0.0, float(terrain_cfg.get("corridor_chord_m", 300.0)))
	corridor_min_m = maxf(0.0, float(terrain_cfg.get("corridor_min_m", 8.0)))
	relief_m = maxf(0.0, float(terrain_cfg.get("relief_m", 3.0)))
	relief_wavelength_m = maxf(30.0, float(terrain_cfg.get("relief_wavelength_m", 260.0)))
	relief_from_m = maxf(0.0, float(terrain_cfg.get("relief_from_m", 30.0)))
	relief_full_m = maxf(relief_from_m + 1.0, float(terrain_cfg.get("relief_full_m", 100.0)))
	relief_ramp_m = maxf(0.0, float(terrain_cfg.get("relief_ramp_m", 120.0)))
	hill_factors.clear()
	var hf: Variant = terrain_cfg.get("hill_factors", DEFAULT_HILL_FACTORS)
	for v: Variant in (hf if hf is Array and (hf as Array).size() > 0 else DEFAULT_HILL_FACTORS):
		hill_factors.append(maxf(0.0, float(v)))
	_profile_x.clear()
	_profile_h.clear()
	var prof: Variant = terrain_cfg.get("profile", DEFAULT_PROFILE)
	for e: Variant in (prof if prof is Array and (prof as Array).size() > 0 else DEFAULT_PROFILE):
		if e is Array and (e as Array).size() >= 2:
			_profile_x.append(float((e as Array)[0]))
			_profile_h.append(minf(0.0, float((e as Array)[1])))   # the profile itself never rises above the road
	if path != null:
		path.floor_window_m = maxf(0.0, float(terrain_cfg.get("floor_window_m", 900.0)))
		path.floor_drop_m = maxf(0.0, float(terrain_cfg.get("floor_drop_m", 4.5)))
		_fit_clear_max()
	_seed = int(t.plan.seed) if t != null and t.plan != null else 0
	_kappa_cache.clear()
	_amp_cache.clear()
	_rows.clear()
	_cx.resize(_n * 2)
	_ch.resize(_n * 2)


## Number of rings per side (the first one is the shoulder edge).
func ring_count() -> int:
	return _n


## Sets the distance of the outer ring ("Details": 480 m, 1,000 m on "Hoch"). Before the first row is asked for.
func set_outer_ring(m: float) -> void:
	rings[_n - 1] = maxf(m, rings[_n - 2] + 1.0)
	_fit_clear_max()
	_rows.clear()


## A side with nothing near must give room for the whole ribbon: clearance() of a free side lies beyond the outer
## ring, its margin and the widest road.
func _fit_clear_max() -> void:
	if path != null:
		path.set_clear_max(maxf(path.clear_max_m, rings[_n - 1] + clear_margin_m + 30.0))


## Forgets cached rows before before_index (call it with the path's trim()).
func trim(before_index: int) -> void:
	for cache: Dictionary in [_kappa_cache, _amp_cache, _rows]:
		for key: int in cache.keys():
			if key < before_index - COARSE:
				cache.erase(key)


## Outer shoulder edge of row k on one side: metres from the centreline (positive on both sides).
func edge(k: int, side: int) -> float:
	var r := _row(k)
	return r[0] if side < 0 else r[1]


## Width of the ribbon of row k beyond the shoulder (the distance of its last ring).
func limit(k: int, side: int) -> float:
	var r := _row(k)
	return r[2] if side < 0 else r[3]


## Sight corridor of row k beyond the shoulder (m): inside it height() is never above 0 (fairness rule F7).
func corridor_width(k: int, side: int) -> float:
	var r := _row(k)
	return r[4] if side < 0 else r[5]


## Ring distances of row k beyond the shoulder (clamped, strictly increasing).
func ring_offsets(k: int, side: int) -> PackedFloat32Array:
	var o := 6 + (0 if side < 0 else _n)
	return _row(k).slice(o, o + _n)


## Heights of those rings relative to the road height of row k.
func ring_heights(k: int, side: int) -> PackedFloat32Array:
	var o := 6 + 2 * _n + (0 if side < 0 else _n)
	return _row(k).slice(o, o + _n)


## Ground height at lateral_m beyond the shoulder of row k, relative to the road height of that cross-section:
## the straight line between the rings; beyond the last ring its height (the valley floor).
func height(k: int, side: int, lateral_m: float) -> float:
	var r := _row(k)
	var ox := 6 + (0 if side < 0 else _n)
	return interp(r, ox, r, ox + 2 * _n, _n, lateral_m)


## Piecewise-linear height at lateral m from n ring distances xs[ox..] and heights hs[oh..].
static func interp(xs: PackedFloat32Array, ox: int, hs: PackedFloat32Array, oh: int, n: int, m: float) -> float:
	if m <= xs[ox]:
		return hs[oh]
	for i in range(1, n):
		var x1 := xs[ox + i]
		if m <= x1:
			var x0 := xs[ox + i - 1]
			return lerpf(hs[oh + i - 1], hs[oh + i], (m - x0) / maxf(x1 - x0, 1.0e-6))
	return hs[oh + n - 1]


## The rows a..b in one pass (chunk snapshots, scans): {"rings": n, "x": ring distances, "h": ring heights – both
## n values per row and side, index ((row - a) * 2 + (0 left | 1 right)) * n + ring –, "edge": shoulder edges,
## "limit": ribbon widths, "corridor": sight corridors – Vector2(left, right) per row –, "floor": RoadPath3D.floor_y()
## per row}.
func rows(a: int, b: int) -> Dictionary:
	var count := maxi(0, b - a + 1)
	var x := PackedFloat32Array()
	var h := PackedFloat32Array()
	var edges := PackedVector2Array()
	var limits := PackedVector2Array()
	var corr := PackedVector2Array()
	x.resize(count * 2 * _n)
	h.resize(count * 2 * _n)
	edges.resize(count)
	limits.resize(count)
	corr.resize(count)
	var floors := path.floor_rows(a, b)
	var n2 := 2 * _n
	for q in count:
		_compute(a + q, floors[q])
		var o := q * n2
		for i in n2:
			x[o + i] = _cx[i]
			h[o + i] = _ch[i]
		edges[q] = _c_edge
		limits[q] = _c_limit
		corr[q] = _c_corr
	return {"rings": _n, "x": x, "h": h, "edge": edges, "limit": limits, "corridor": corr, "floor": floors}


func _row(k: int) -> PackedFloat32Array:
	var hit: Variant = _rows.get(k)
	if hit != null:
		return hit
	_compute(k, path.floor_y(k))
	var r := PackedFloat32Array()
	r.resize(6 + 4 * _n)
	r[0] = _c_edge.x
	r[1] = _c_edge.y
	r[2] = _c_limit.x
	r[3] = _c_limit.y
	r[4] = _c_corr.x
	r[5] = _c_corr.y
	for i in 2 * _n:
		r[6 + i] = _cx[i]
		r[6 + 2 * _n + i] = _ch[i]
	_rows[k] = r
	return r


## Fills _cx / _ch / _c_* for row k. floor_abs = RoadPath3D.floor_y(k).
func _compute(k: int, floor_abs: float) -> void:
	var s := track.get_segment(k)
	var sp := track.get_segment(maxi(k - 1, 0))
	if sp.index != k - 1:
		sp = s
	var lw := track.lane_w
	var sh := track.shoulder_w
	var half := s.lanes * lw * 0.5
	var paved_l := half
	var paved_r := half + s.fuel_lane * lw
	_c_edge = Vector2(paved_l + sh, paved_r + sh)
	var k_ahead := s.curve * path.inv_r1
	var k_behind := sp.curve * path.inv_r1
	var kap := _kappa(k)
	var road_y := path.height(k)
	var floor_rel := minf(floor_abs - road_y, 0.0)
	var water := s.water
	var water_h := minf(s.water_level, 0.0)
	var z := float(k) * path.seg_len
	var amp := 0.0
	if relief_m > 0.0 and not water and not s.tunnel:
		amp = relief_m * _amp(k)
		if amp > 0.0 and not scenery_db.is_empty():
			var sc: Variant = scenery_db.get(s.scenery)
			if sc is Dictionary:
				amp *= maxf(0.0, float((sc as Dictionary).get("relief", 1.0)))
	var outer := rings[_n - 1]
	var last := float(_n - 1)
	for si in 2:
		var side := -1.0 if si == 0 else 1.0
		var e := _c_edge.x if si == 0 else _c_edge.y
		var paved := paved_l if si == 0 else paved_r
		# ribbon width: outer ring, medial axis to other road parts, inside of the bend
		var lim := minf(outer, path.clearance(k, -1 if si == 0 else 1) - clear_margin_m - e)
		var k_in := maxf(maxf(side * k_ahead, side * k_behind), 0.0)
		if k_in > 1.0e-6:
			lim = minf(lim, inside_bend_factor / k_in - e)
		# also by the sharpest curvature of this side within the corridor window: where the curvature changes along
		# a bend, rows clamped by their own curvature alone let the inside tips of neighbouring rows overlap
		var k_near := kap.x if si == 0 else kap.y
		if k_near > 1.0e-6:
			lim = minf(lim, inside_bend_factor / k_near - e)
		lim = maxf(lim, min_width_m)
		# sight corridor beyond the shoulder
		var k_c := kap.x if si == 0 else kap.y
		var corr := corridor_min_m
		if k_c > 1.0e-7:
			var k_edge := k_c / maxf(0.05, 1.0 - k_c * paved)
			corr = maxf(corr, corridor_chord_m * corridor_chord_m * 0.125 * k_edge)
		corr = maxf(0.0, corr - sh)
		if si == 0:
			_c_limit.x = lim
			_c_corr.x = corr
		else:
			_c_limit.y = lim
			_c_corr.y = corr
		var o := si * _n
		var prev_x := 0.0
		for i in _n:
			var m := 0.0
			if i > 0:
				m = minf(rings[i], lim * pow(float(i) / last, cap_power)) if i < _n - 1 else lim
			_cx[o + i] = m
			var hh := 0.0
			if i == _n - 1:
				hh = minf(floor_rel, water_h) if water else floor_rel
			elif i > 0:
				if water:
					hh = water_h
				else:
					hh = _base(m)
					if amp > 0.0 and prev_x >= corr:
						hh += amp * smoothstep(relief_from_m, relief_full_m, m) * _noise(z, si, i)
					hh = maxf(hh, floor_rel)
			_ch[o + i] = hh
			prev_x = m


func _base(m: float) -> float:
	var n := _profile_x.size()
	if n == 0:
		return 0.0
	if m <= _profile_x[0]:
		return _profile_h[0]
	for i in range(1, n):
		if m <= _profile_x[i]:
			return lerpf(_profile_h[i - 1], _profile_h[i], (m - _profile_x[i - 1]) / maxf(_profile_x[i] - _profile_x[i - 1], 1.0e-6))
	return _profile_h[n - 1]


## Sharpest curvature towards the left / the right (1/m, >= 0) within half a corridor chord of path around row k.
## Evaluated on every COARSE-th row over 12-m steps of the heading; a row in between takes the larger neighbour.
func _kappa(k: int) -> Vector2:
	var k0 := (k / COARSE) * COARSE
	var a := _kappa_coarse(k0)
	if k0 == k:
		return a
	var b := _kappa_coarse(k0 + COARSE)
	return Vector2(maxf(a.x, b.x), maxf(a.y, b.y))


func _kappa_coarse(kc: int) -> Vector2:
	var hit: Variant = _kappa_cache.get(kc)
	if hit != null:
		return hit
	var half := int(ceil(corridor_chord_m * 0.5 / path.seg_len / 4.0)) * 4
	var j0 := maxi(kc - half, path.first)
	var j1 := mini(kc + half, path.end_index())
	path.ensure(j1)
	j1 = mini(j1, path.last())
	var l := 0.0
	var r := 0.0
	var j := j0
	while j + 4 <= j1:
		var c := (path.heading(j + 4) - path.heading(j)) / (4.0 * path.seg_len)
		if c > r:
			r = c
		elif -c > l:
			l = -c
		j += 4
	var out := Vector2(l, r)
	_kappa_cache[kc] = out
	return out


## Relief level of row k (0 = flat): the hills level of the section, none in City Limits, tunnels, on bridges, at
## the start and behind the finish – averaged over relief_ramp_m of path and linear between the coarse rows.
func _amp(k: int) -> float:
	var k0 := (k / COARSE) * COARSE
	var a := _amp_coarse(k0)
	if k0 == k:
		return a
	return lerpf(a, _amp_coarse(k0 + COARSE), float(k - k0) / float(COARSE))


func _amp_coarse(kc: int) -> float:
	var hit: Variant = _amp_cache.get(kc)
	if hit != null:
		return hit
	var z := float(kc) * path.seg_len
	var sum := 0.0
	for q in 5:
		sum += _amp_raw(z + (float(q) - 2.0) * relief_ramp_m * 0.25)
	var out := sum / 5.0
	_amp_cache[kc] = out
	return out


func _amp_raw(z: float) -> float:
	if z < 60.0 or z > track.length_z - 60.0:
		return 0.0
	var plan := track.plan
	var km := track.z_to_km(z)
	if plan.is_city(km) or track.near_bridge(z, 45.0):
		return 0.0
	var margin_km := track.z_to_km(60.0)
	if plan.in_tunnel(km) or plan.in_tunnel(km - margin_km) or plan.in_tunnel(km + margin_km):
		return 0.0
	var level := int(plan.section_at(km).get("hills", 1))
	return hill_factors[clampi(level, 0, hill_factors.size() - 1)]


## Smooth value noise 0..1 along the road, one stream per side and ring.
func _noise(z: float, si: int, ring: int) -> float:
	var f := z / relief_wavelength_m + float(ring) * 0.37 + float(si) * 0.61
	var c := int(floor(f))
	var t := f - float(c)
	t = t * t * (3.0 - 2.0 * t)
	return lerpf(_hash01(c, si, ring), _hash01(c + 1, si, ring), t)


func _hash01(c: int, si: int, ring: int) -> float:
	var h := (c * 73856093) ^ ((si + 1) * 19349663) ^ ((ring + 1) * 83492791) ^ (_seed * 2654435761)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0
