class_name RoadPath3D
extends RefCounted
## Kernel of the mode "Modern" (v0.8.0): the true world-space centreline of a Track.
##
## The heading is integrated per segment from the curve value (curvature = curve / road.curve_radius_at_1_m,
## midpoint rule), one boundary per segment start: boundary k = start of segment k. World axes are Godot's:
## +X right, +Y up, heading 0 looks along -Z, a positive curve turns right:
##   fwd(a) = (sin a, 0, -cos a), right(a) = (cos a, 0, sin a). Heading 0 = heading of the first integrated segment.
## Road coordinates (z along the road in visible metres, x lateral + right, h above the road) map to the world
## through world() / frame_at(); heights are the Track's segment heights as they are.
##
## The world is only locally consistent (some stages cross themselves a few km of path apart): everything is
## streamed by path distance, nothing may be cached in world space. Positions are kept in doubles relative to the
## first boundary; only values relative to the floating origin leave the class (rebase(), 32-bit vectors).
## The three builder rules that keep the fallback mapping possible: take every position from this class or from a
## ChunkContext, never assume a chunk transform is static, place rigid instances through ChunkContext.frame().
##
## ensure() reads the Track's segments and so forces the generation ahead of the camera; that is harmless, the
## generator is sequential and its window is only cut behind the camera. A boundary can only be integrated while
## its segment is still inside the Track window.
## Owner: race3d kernel. Docs: docs/renderer-modern.md.

const CLEAR_ROW_STEP := 8      ## clearance() is evaluated on every 8th boundary (24 m) and interpolated in between …
const CLEAR_SCAN_STEP := 8     ## … against every 8th boundary of the rest of the loaded road

var track: Track
var seg_len := 3.0
var inv_r1 := 1.0 / 120.0                ## curvature (1/m) of curve value 1
var first := 0                           ## segment index of the first kept boundary
var origin_index := 0                    ## boundary the floating origin was last moved to
var floor_window_m := 900.0              ## floor_y(): path distance to both sides (graphics.modern.terrain)
var floor_drop_m := 4.5                  ## floor_y(): metres below the lowest road
var clear_reach_m := 1900.0              ## clearance(): path distance to both sides that counts as "loaded together"
var clear_max_m := 1000.0                ## clearance(): value of a free side

var _px := PackedFloat64Array()          ## boundary positions (m, x / z relative to the first boundary of setup())
var _pz := PackedFloat64Array()
var _th := PackedFloat64Array()          ## heading (rad, not wrapped)
var _py := PackedFloat64Array()          ## road height
var _ox := 0.0                           ## floating origin (same space as _px / _pz)
var _oz := 0.0
var _count := 1                          ## boundaries of the whole track (Track.segment_count)
var _clear_cache: Dictionary = {}        ## coarse row -> Vector2(left, right)
var _li := 0                             ## _locate(): lower array index, upper array index, fraction
var _lj := 0
var _lt := 0.0
var _warned := false


static func right_of(a: float) -> Vector3:
	return Vector3(cos(a), 0.0, sin(a))


static func fwd_of(a: float) -> Vector3:
	return Vector3(sin(a), 0.0, -cos(a))


## Starts the path at boundary start_index (or at the oldest segment the track still holds).
func setup(t: Track, start_index: int, curve_radius_at_1: float) -> void:
	track = t
	seg_len = t.seg_len
	inv_r1 = 1.0 / maxf(1.0, curve_radius_at_1)
	_count = maxi(1, t.segment_count)
	first = clampi(start_index, 0, _count - 1)
	var s := t.get_segment(first)
	if s.index != first:
		first = s.index
	_px.clear()
	_pz.clear()
	_th.clear()
	_py.clear()
	_px.append(0.0)
	_pz.append(0.0)
	_th.append(0.0)
	_py.append(s.y)
	_ox = 0.0
	_oz = 0.0
	origin_index = first
	_clear_cache.clear()
	_warned = false


func is_ready() -> bool:
	return track != null and not _px.is_empty()


## Index of the last integrated boundary.
func last() -> int:
	return first + _px.size() - 1


## Index of the last boundary the track has.
func end_index() -> int:
	return _count - 1


func has(index: int) -> bool:
	return index >= first and index <= last()


## Integrates the boundaries up to `index` (midpoint rule per segment). Reads the segments from the track, which
## generates them on demand.
func ensure(index: int) -> void:
	var n := _px.size()
	var k := first + n - 1
	index = mini(index, _count - 1)
	if k >= index:
		return
	var x := _px[n - 1]
	var z := _pz[n - 1]
	var a := _th[n - 1]
	var s := track.get_segment(k)
	while k < index:
		if s.index != k:
			if not _warned:
				_warned = true
				push_warning("RoadPath3D: Segment %d liegt nicht mehr im Fenster der Strecke – Pfad endet dort" % k)
			return
		var nxt := track.get_segment(k + 1)
		var da := s.curve * inv_r1 * seg_len
		var mid := a + da * 0.5
		x += sin(mid) * seg_len
		z -= cos(mid) * seg_len
		a += da
		_px.append(x)
		_pz.append(z)
		_th.append(a)
		_py.append(nxt.y)
		s = nxt
		k += 1


## Road centre at boundary k (origin-relative, with the road height). Indices outside the kept range are clamped.
func point(k: int) -> Vector3:
	if k > first + _px.size() - 1:
		ensure(k)
	var i := clampi(k - first, 0, _px.size() - 1)
	return Vector3(_px[i] - _ox, _py[i], _pz[i] - _oz)


func heading(k: int) -> float:
	if k > first + _px.size() - 1:
		ensure(k)
	return _th[clampi(k - first, 0, _px.size() - 1)]


## Road height at boundary k.
func height(k: int) -> float:
	if k > first + _px.size() - 1:
		ensure(k)
	return _py[clampi(k - first, 0, _px.size() - 1)]


func _locate(z: float) -> void:
	var f := z / seg_len
	var k := int(floor(f))
	if k + 1 > first + _px.size() - 1:
		ensure(k + 1)
	var n := _px.size()
	_li = clampi(k - first, 0, maxi(0, n - 2))
	_lj = mini(_li + 1, n - 1)
	_lt = clampf(f - float(first + _li), 0.0, 1.0)


## Road centre (with height) at road position z, linear inside the segment – the same straight edge a mesh built
## from the boundaries has.
func centre_at(z: float) -> Vector3:
	_locate(z)
	return Vector3(lerpf(_px[_li], _px[_lj], _lt) - _ox, lerpf(_py[_li], _py[_lj], _lt), lerpf(_pz[_li], _pz[_lj], _lt) - _oz)


func heading_at(z: float) -> float:
	_locate(z)
	return lerpf(_th[_li], _th[_lj], _lt)


## Road height at road position z.
func height_at(z: float) -> float:
	_locate(z)
	return lerpf(_py[_li], _py[_lj], _lt)


## World point (origin-relative) of road coordinates: z along the road, x lateral (+ right), h above the road.
## Bilinear between the two boundaries (the right vectors are interpolated like the mesh rows), so the point lies on
## the road surface a chunk builds from the same rows (ChunkContext.local()).
func world(z: float, x: float, h: float) -> Vector3:
	_locate(z)
	var a0 := _th[_li]
	var a1 := _th[_lj]
	var rx := lerpf(cos(a0), cos(a1), _lt)
	var rz := lerpf(sin(a0), sin(a1), _lt)
	return Vector3(lerpf(_px[_li], _px[_lj], _lt) - _ox + rx * x, lerpf(_py[_li], _py[_lj], _lt) + h,
		lerpf(_pz[_li], _pz[_lj], _lt) - _oz + rz * x)


## Rigid frame at road coordinates: +X right, +Y up, -Z road forward (yaw only – no pitch, no roll).
func frame_at(z: float, x: float = 0.0, h: float = 0.0) -> Transform3D:
	var p := world(z, x, h)
	var a := lerpf(_th[_li], _th[_lj], _lt)
	return Transform3D(Basis(right_of(a), Vector3.UP, -fwd_of(a)), p)


## Moves the floating origin to boundary to_index. Returns the shift that this applies to every origin-relative
## position (new = old + shift); heights do not change.
func rebase(to_index: int) -> Vector3:
	ensure(to_index)
	var i := clampi(to_index - first, 0, _px.size() - 1)
	var shift := Vector3(_ox - _px[i], 0.0, _oz - _pz[i])
	_ox = _px[i]
	_oz = _pz[i]
	origin_index = first + i
	return shift


## Distance (m, in plan) of boundary k from the floating origin.
func origin_distance(k: int) -> float:
	var i := clampi(k - first, 0, _px.size() - 1)
	return Vector2(_px[i] - _ox, _pz[i] - _oz).length()


## Sets the value clearance() gives for a free side (at least the widest terrain ribbon plus its margins).
func set_clear_max(m: float) -> void:
	if m != clear_max_m:
		clear_max_m = m
		_clear_cache.clear()


## Sets how far along the path (both directions) clearance() looks: the largest path distance between two parts of
## the road that can be loaded at the same time.
func set_clear_reach(m: float) -> void:
	if m != clear_reach_m:
		clear_reach_m = m
		_clear_cache.clear()


## Forgets the boundaries before before_index (at least two are kept).
func trim(before_index: int) -> void:
	var n := mini(before_index - first, _px.size() - 2)
	if n <= 0:
		return
	_px = _px.slice(n)
	_pz = _pz.slice(n)
	_th = _th.slice(n)
	_py = _py.slice(n)
	first += n
	for key: int in _clear_cache.keys():
		if key < first:
			_clear_cache.erase(key)


## Free lateral width (m, from the centreline) on one side (-1 left, +1 right) of boundary k before the cross-section
## reaches ground that is nearer to another part of the road: the medial axis against every boundary within
## clear_reach_m of path (both directions, as far as they are kept), clear_max_m when nothing is near. On the inside
## of a bend this is its radius (the cross-sections meet in the centre). A pure function of the road around k –
## two chunks that share a row get the same value. Evaluated on every CLEAR_ROW_STEP-th boundary, linear in between.
func clearance(k: int, side: int) -> float:
	k = clampi(k, first, _count - 1)
	var k0 := (k / CLEAR_ROW_STEP) * CLEAR_ROW_STEP
	var k1 := mini(k0 + CLEAR_ROW_STEP, _count - 1)
	if k0 < first:
		k0 = k1 if k1 >= first else first
	var c0 := _clearance_row(k0)
	if k0 >= k or k1 <= k0:
		return c0.x if side < 0 else c0.y
	var c1 := _clearance_row(k1)
	var t := float(k - k0) / float(k1 - k0)
	return lerpf(c0.x, c1.x, t) if side < 0 else lerpf(c0.y, c1.y, t)


func _clearance_row(kc: int) -> Vector2:
	var hit: Variant = _clear_cache.get(kc)
	if hit != null:
		return hit
	var reach := int(clear_reach_m / seg_len)
	ensure(kc + reach)
	var n := _px.size()
	var i := clampi(kc - first, 0, n - 1)
	var x0 := _px[i]
	var z0 := _pz[i]
	var ux := cos(_th[i])
	var uz := sin(_th[i])
	var left := clear_max_m
	var right := clear_max_m
	var j1 := mini(i + reach, n - 1)
	var j := i - (mini(i, reach) / CLEAR_SCAN_STEP) * CLEAR_SCAN_STEP
	while j <= j1:
		var vx := _px[j] - x0
		var vz := _pz[j] - z0
		var a := vx * ux + vz * uz
		var b2 := vx * vx + vz * vz
		# the point of the cross-section that is as far from boundary j as from this row lies b² / 2a from the centre
		if a > 0.0:
			if b2 < 2.0 * a * right:
				right = b2 / (2.0 * a)
		elif a < 0.0:
			if b2 < -2.0 * a * left:
				left = b2 / (-2.0 * a)
		j += CLEAR_SCAN_STEP
	var out := Vector2(left, right)
	_clear_cache[kc] = out
	return out


## Valley floor at boundary k: the lowest road within floor_window_m of path to both sides, minus floor_drop_m.
## It only ever lies below the road, so ground that ends on it cannot hide anything.
func floor_y(k: int) -> float:
	var w := int(round(floor_window_m / seg_len))
	ensure(k + w)
	var n := _py.size()
	var i0 := clampi(k - w - first, 0, n - 1)
	var i1 := clampi(k + w - first, 0, n - 1)
	var lo := _py[i0]
	for i in range(i0 + 1, i1 + 1):
		if _py[i] < lo:
			lo = _py[i]
	return lo - floor_drop_m


## floor_y() of the boundaries a..b in one pass (sliding minimum): the same values, for chunk snapshots and scans.
func floor_rows(a: int, b: int) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	var count := b - a + 1
	if count <= 0:
		return out
	out.resize(count)
	var w := int(round(floor_window_m / seg_len))
	ensure(b + w)
	var n := _py.size()
	var lo_i := clampi(a - w - first, 0, n - 1)
	var hi_i := clampi(b + w - first, 0, n - 1)
	var dq := PackedInt32Array()
	dq.resize(hi_i - lo_i + 2)
	var head := 0
	var tail := 0
	var i := lo_i
	for r in range(a, b + 1):
		var need_i := clampi(r + w - first, lo_i, hi_i)
		while i <= need_i:
			var y := _py[i]
			while tail > head and _py[dq[tail - 1]] >= y:
				tail -= 1
			dq[tail] = i
			tail += 1
			i += 1
		var w0 := clampi(r - w - first, 0, n - 1)
		while tail - head > 1 and dq[head] < w0:
			head += 1
		out[r - a] = _py[dq[head]] - floor_drop_m
	return out


## The boundaries a..b relative to boundary a, computed in doubles (exact small numbers for a chunk):
## {"origin": origin-relative position of boundary a, "o": centres, "r": unit right vectors, "f": unit forward
## vectors, "heading": headings (rad)}.
func rows_local(a: int, b: int) -> Dictionary:
	ensure(b)
	var count := maxi(0, b - a + 1)
	var o := PackedVector3Array()
	var r := PackedVector3Array()
	var f := PackedVector3Array()
	var hd := PackedFloat64Array()
	o.resize(count)
	r.resize(count)
	f.resize(count)
	hd.resize(count)
	var n := _px.size()
	var ia := clampi(a - first, 0, n - 1)
	var ax := _px[ia]
	var ay := _py[ia]
	var az := _pz[ia]
	for q in count:
		var i := clampi(a + q - first, 0, n - 1)
		var th := _th[i]
		o[q] = Vector3(_px[i] - ax, _py[i] - ay, _pz[i] - az)
		r[q] = Vector3(cos(th), 0.0, sin(th))
		f[q] = Vector3(sin(th), 0.0, -cos(th))
		hd[q] = th
	return {"origin": Vector3(ax - _ox, ay, az - _oz), "o": o, "r": r, "f": f, "heading": hd}


## The boundaries k0..k1 as plain double arrays (origin-relative x and z, road height y, heading) for tools, tests
## and scans that need more precision or speed than point() gives: {"x", "z", "y", "heading"}.
func arrays(k0: int, k1: int) -> Dictionary:
	ensure(k1)
	k0 = clampi(k0, first, last())
	k1 = clampi(k1, k0, last())
	var count := k1 - k0 + 1
	var x := PackedFloat64Array()
	var z := PackedFloat64Array()
	x.resize(count)
	z.resize(count)
	var i0 := k0 - first
	for q in count:
		x[q] = _px[i0 + q] - _ox
		z[q] = _pz[i0 + q] - _oz
	return {"first": k0, "x": x, "z": z, "y": _py.slice(i0, i0 + count), "heading": _th.slice(i0, i0 + count)}
