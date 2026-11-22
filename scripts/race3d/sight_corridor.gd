class_name SightCorridor
extends RefCounted
## Kernel of the mode "Modern" (v0.8.0): the sight corridor of bends from the real geometry (fairness rule F7,
## contract A-17). For every row and side it is the envelope of all sight lines (chords) along the actual path – a
## camera in any lane looking at a vehicle in any lane up to L metres of path ahead:
##   L(camera row) = min(chord_max_m, F2 need at the car's row / 0.6 + camera offset)
## The F2 need is the one of tests/race3d/fairness.gd speed_profile() and tests/sim/modern_sight.gd: the stopping
## distance (1 s reaction + full braking) at the fastest drivable speed of all cars at once (the best lateral grip and
## the highest top speed, curves 5 % above their limit, braking envelope backwards), the largest of dry, rain and
## snow – so the corridor does not depend on the weather of the race. The camera stands camera_offset_m behind the
## car (render.camera_distance_m).
## The band so runs out at the start and the end of a bend, follows the real geometry of a short bend (the sight
## lines from the straights before and after it cut its corner), keeps a straight before a bend free beyond the sight
## lines that reach into the bend, and in slow mountain bends (short L) it is narrow.
##
## Method, per camera row a (every cam_step rows, aligned to absolute row numbers, so that every start of the stream
## gets the same numbers): the camera stands at the outermost lane centre on either side – the sight lines of the
## lanes in between lie inside the convex hull of those of the outermost ones. The targets are the outermost lane
## centres of every row up to L and of the exact end. Walking the targets from the far end back towards the camera,
## the sight lines with the largest bearing to the right and to the left seen so far are the outermost ones that still
## reach the cross-section of the row just passed; their crossings with that cross-section (every row_step-th row) are
## the corridor's edges there (both lines on both sides: beyond a quarter turn of the road the order of the crossings
## flips). Rows in between are interpolated; MARGIN_M covers the sampling of the cameras (measured against an
## exhaustive reference in tests/unit/race3d/test_sight_corridor.gd). A sight line never counts beyond the medial axis
## to another part of the road (RoadPath3D.clearance(), applied when a row is read): the ground there belongs to that
## part, and the terrain ribbon and the props end before it anyway. Targets that turned more than MAX_TURN from the camera's heading are left out.
## Computed lazily and incrementally while rows are asked for (ensure()), each camera once per stage; the results are
## plain per-row numbers that TerrainProfile snapshots into every ChunkContext (worker-safe).
## Values: metres beyond the outer shoulder edge (shoulder_w beyond the paved edge); NONE + MARGIN_M where no sight
## line leaves the road. Owner: race3d kernel. Docs: docs/renderer-modern.md 5.3.

const CAM_STEP := 1                    ## a camera on every row (coarser steps miss kinks of the envelope: unit test)
const ROW_STEP := 1                    ## corridor samples: every row
const MARGIN_M := 0.05                 ## added to every value (rounding; the method is exact against the unit test's reference)
const SIMPLE_TURN := 1.2               ## rad: a fan whose road turns less needs one camera and one target point per side
const MAX_TURN := 2.6                  ## rad: targets whose heading differs more from the camera's are left out
const BLOCK := 32                      ## camera rows per computation step
const NONE := -6.0                     ## no sight line beyond the shoulder (below every lane centre)
const WEATHERS: Array[String] = ["normal", "rain", "snow"]
const F2_RATIO := 0.6
const REACTION_S := 1.0
const CURVE_TOLERANCE := 1.05

var chord_max_m := 300.0               ## L at most (graphics.modern.terrain.corridor_chord_m)
var camera_offset_m := 9.0             ## camera behind the car (render.camera_distance_m)
var cam_step := CAM_STEP               ## set before the first row is asked for (tests)
var row_step := ROW_STEP
var simple_turn := SIMPLE_TURN
var path: RoadPath3D
var track: Track

var _env: Array[Dictionary] = []       ## per weather {safe1 (m/s at curve 1), vtop (m/s), brake (m/s²)}
var _look := 0                         ## rows of braking look-ahead that can still lower a speed
var _cam_rows := 3                     ## rows between the camera and the car
var _nb := 102                         ## rows a fan can reach
var _lane_w := 3.75
var _shoulder := 2.5
var _seg := 3.0
var _started := false
var _lo := 0                           ## row of index 0 of _wl / _wr
var _wl := PackedFloat32Array()        ## raw crossings beyond the shoulder (left, right) at the sampled rows
var _wr := PackedFloat32Array()
var _cam_next := 0                     ## next camera row to compute
var _n_lo := 0                         ## row of index 0 of _need
var _need := PackedFloat32Array()      ## F2 need (m) per row, the largest of the weathers
var _n_hi := -1                        ## last row of _need that is final
## measurements: cameras computed, of them skipped as straight, microseconds spent
var cameras := 0
var skipped := 0
var usec := 0


## p may still be empty (the streamer sets it up later); nothing is computed before the first row is asked for.
func setup(p: RoadPath3D, t: Track, terrain_cfg: Dictionary) -> void:
	path = p
	track = t
	chord_max_m = maxf(0.0, float(terrain_cfg.get("corridor_chord_m", 300.0)))
	var cfg: Dictionary = t.cfg if t != null else {}
	camera_offset_m = maxf(0.0, float(ConfigLoader.lookup(cfg, "render.camera_distance_m", 9.0)))
	if t != null:
		_seg = t.seg_len
		_lane_w = t.lane_w
		_shoulder = t.shoulder_w
	_cam_rows = int(round(camera_offset_m / _seg))
	_nb = int(ceil(chord_max_m / _seg)) + 1
	_env = envelopes(cfg)
	var look_m := 0.0
	for e: Dictionary in _env:
		look_m = maxf(look_m, float(e["vtop"]) * float(e["vtop"]) / (2.0 * maxf(float(e["brake"]), 0.1)))
	_look = int(ceil(look_m / _seg)) + 2
	reset()


## Forgets everything (a new start of the stream).
func reset() -> void:
	_started = false
	_wl.clear()
	_wr.clear()
	_need.clear()
	_n_hi = -1
	cameras = 0
	skipped = 0
	usec = 0


## Per weather the envelope of all cars (as tests/race3d/fairness.gd envelopes()): [{safe1, vtop, brake}].
static func envelopes(cfg: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var env := EnvironmentModel.new()
	env.setup(cfg)
	for w: String in WEATHERS:
		var grip := env.grip(w)
		var safe1 := 0.0
		var vtop := 0.0
		var brake := 0.0
		for id: Variant in ConfigLoader.lookup(cfg, "vehicles.order", ["limousine"]):
			var v := VehicleModel.new()
			v.setup(cfg, str(id))
			safe1 = maxf(safe1, v.safe_curve_speed(1.0, grip) / 3.6)
			vtop = maxf(vtop, v.max_speed(0.0, env.vmax_factor(12.0, w)) / 3.6)
			brake = maxf(brake, v.brake_decel_mps2(grip))
		out.append({"safe1": safe1, "vtop": vtop, "brake": brake})
	return out


## Corridor of row k on `side` (-1 left, +1 right): metres beyond the outer shoulder edge up to which a sight line
## passes (NONE + MARGIN_M where none leaves the road). Main thread (reads the path and the track).
func width(k: int, side: int) -> float:
	ensure(k + row_step)
	return _clamped(k, side) + MARGIN_M


## The largest width() of row k and its two neighbours (whether a sight line leaves the road near the row: the
## builders interpolate between rows).
func width_near(k: int, side: int) -> float:
	ensure(k + 1 + row_step)
	return maxf(maxf(_clamped(k - 1, side), _clamped(k, side)), _clamped(k + 1, side)) + MARGIN_M


## The crossings of row k, never beyond the medial axis to another part of the road (applied when a row is read, so
## that computing the fans never needs the path farther ahead than the rows they reach).
func _clamped(k: int, side: int) -> float:
	var w := _interp(k, side)
	if w <= 0.0:
		return w
	var s := track.get_segment(maxi(k, 0))
	var half := s.lanes * _lane_w * 0.5
	var edge := (half if side < 0 else half + s.fuel_lane * _lane_w) + _shoulder
	return minf(w, path.clearance(k, side) - edge)


## L (m) of a camera at row a: the sight line length the corridor covers there.
func chord_at(a: int) -> float:
	_ensure_need(a + _cam_rows)
	return minf(chord_max_m, _need_at(a + _cam_rows) / F2_RATIO + camera_offset_m)


## F2 need (m) at row k: stopping distance at the fastest drivable speed, the largest of dry, rain and snow.
func need_at(k: int) -> float:
	_ensure_need(k)
	return _need_at(k)


## Forgets the rows before before_index (with RoadPath3D.trim()); a huge value resets.
func trim(before_index: int) -> void:
	if before_index >= (1 << 39):
		reset()
		return
	if not _started:
		return
	var cut := mini(before_index - 8 - _lo, _wl.size())
	if cut > 0:
		_wl = _wl.slice(cut)
		_wr = _wr.slice(cut)
		_lo += cut
	var cn := mini(before_index - 8 - _n_lo, _need.size())
	if cn > 0:
		_need = _need.slice(cn)
		_n_lo += cn


## Makes the rows up to k final: every camera at or before k computed.
func ensure(k: int) -> void:
	warm(k, -1)


## Computes the cameras up to row k, until the clock (Time.get_ticks_usec()) passes deadline_us (< 0: no limit).
## Returns true when the rows up to k are final. The streamer calls it every frame for the rows ahead of the chunks it
## will collect, so that a chunk finds its rows ready.
func warm(k: int, deadline_us: int) -> bool:
	if path == null or not path.is_ready():
		return false
	if not _started:
		_start()
	var end := path.end_index()
	if _cam_next > k or _cam_next > end:
		return true
	var t0 := Time.get_ticks_usec()
	while _cam_next <= k and _cam_next <= end:
		_camera(_cam_next)
		_cam_next += cam_step
		if deadline_us >= 0 and Time.get_ticks_usec() >= deadline_us:
			break
	usec += Time.get_ticks_usec() - t0
	return _cam_next > k or _cam_next > end


## The next row whose cameras are not computed yet.
func front() -> int:
	return _cam_next if _started else -(1 << 40)


func _start() -> void:
	_started = true
	row_step = maxi(1, row_step)
	cam_step = maxi(row_step, (cam_step / row_step) * row_step)   # cameras on sampled rows
	var first := path.first
	if path.has_lead_in():
		first = -(_nb + 32)          # cameras on the straight lead-in before the start line see the first bend too
	_cam_next = int(ceil(float(first) / float(cam_step))) * cam_step
	_lo = _cam_next
	_wl.clear()
	_wr.clear()
	_n_lo = _cam_next
	_n_hi = _cam_next - 1
	_need.clear()
	_g0 = 0
	_g1 = -1


func _interp(q: int, side: int) -> float:
	var k0 := int(floor(float(q) / float(row_step))) * row_step
	var u := float(q - k0) / float(row_step)
	var a := _raw(k0, side)
	if u <= 0.0:
		return a
	return lerpf(a, _raw(k0 + row_step, side), u)


func _raw(k: int, side: int) -> float:
	var i := k - _lo
	if i < 0 or i >= _wl.size():
		return NONE
	return _wl[i] if side < 0 else _wr[i]


func _grow(to_row: int) -> void:
	var n := to_row - _lo + 1
	if n > _wl.size():
		var old := _wl.size()
		_wl.resize(n)
		_wr.resize(n)
		for i in range(old, n):
			_wl[i] = NONE
			_wr[i] = NONE


# --- F2 need -------------------------------------------------------------------------------------------------------

func _need_at(k: int) -> float:
	var i := clampi(k - _n_lo, 0, maxi(0, _need.size() - 1))
	return _need[i] if not _need.is_empty() else 0.0


## Makes the need final up to row k: the braking envelope runs backwards from _look rows further on, where no speed
## can be lowered any more (or from the last segment), exactly as speed_profile() does over the whole stage.
func _ensure_need(k: int) -> void:
	if k <= _n_hi:
		return
	var last := track.segment_count - 1
	var lo := _n_hi + 1
	if lo > last:
		_n_hi = k     # rows beyond the track answer with the last value (_need_at clamps)
		return
	var hi := mini(maxi(k, lo + 63), last)
	if k > last:
		hi = last
	var top := mini(hi + _look, last)
	var count := top - lo + 1
	var curv := PackedFloat32Array()
	curv.resize(count)
	for q in count:
		var r := lo + q
		curv[q] = absf(track.get_segment(r).curve) if r >= 0 else 0.0
	var best := PackedFloat32Array()
	best.resize(hi - lo + 1)
	for e: Dictionary in _env:
		var safe1 := float(e["safe1"])
		var vtop := float(e["vtop"])
		var a := float(e["brake"])
		var v := 0.0
		for q in range(count - 1, -1, -1):
			var vr := minf(vtop, CURVE_TOLERANCE * safe1 / sqrt(maxf(curv[q], 1.0e-4)))
			# at `top` nothing further on can lower the speed of a row up to `hi` any more (or it is the last segment)
			v = vr if q == count - 1 else minf(vr, sqrt(v * v + 2.0 * a * _seg))
			if q <= hi - lo:
				var nd := v * REACTION_S + v * v / (2.0 * a)
				if nd > best[q]:
					best[q] = nd
	if _need.is_empty():
		_n_lo = lo
	var off := lo - _n_lo
	if _need.size() < off + best.size():
		_need.resize(off + best.size())
	for q in best.size():
		_need[off + q] = best[q]
	_n_hi = hi
	if k > last:
		_n_hi = k     # rows beyond the track answer with the last value (_need_at clamps)




# --- fans ----------------------------------------------------------------------------------------------------------

## The plan of the rows _g0 .. _g1 relative to row _g0 (RoadPath3D.rows_local()): centres, unit right vectors,
## headings, the outermost lane centres as points, shoulder edges, prefix sums of the turning.
var _g0 := 0
var _g1 := -1
var _gx := PackedFloat32Array()
var _gz := PackedFloat32Array()
var _gnx := PackedFloat32Array()
var _gnz := PackedFloat32Array()
var _gh := PackedFloat64Array()
var _glx := PackedFloat32Array()
var _glz := PackedFloat32Array()
var _grx := PackedFloat32Array()
var _grz := PackedFloat32Array()
var _gel := PackedFloat32Array()
var _ger := PackedFloat32Array()
var _gtu := PackedFloat32Array()


## Makes the plan of the rows a fan from camera row c reaches available (one block of BLOCK cameras at a time).
func _geometry(c: int) -> void:
	var end := path.end_index()
	if c >= _g0 and mini(c + _nb + 1, end) <= _g1:
		return
	var hi := mini(c + BLOCK + _nb + 1, end)
	path.ensure(hi)
	var g := path.rows_local(c, hi)
	var o: PackedVector3Array = g["o"]
	var hd: PackedFloat64Array = g["heading"]
	var count := hi - c + 1
	_gx.resize(count)
	_gz.resize(count)
	_gnx.resize(count)
	_gnz.resize(count)
	_gh.resize(count)
	_glx.resize(count)
	_glz.resize(count)
	_grx.resize(count)
	_grz.resize(count)
	_gel.resize(count)
	_ger.resize(count)
	_gtu.resize(count)
	var acc := 0.0
	for q in count:
		var s := track.get_segment(maxi(c + q, 0))
		var half := s.lanes * _lane_w * 0.5
		var paved_r := half + s.fuel_lane * _lane_w
		var a := -half + _lane_w * 0.5
		var b := paved_r - _lane_w * 0.5
		if a > b:
			a = (a + b) * 0.5
			b = a
		var th := hd[q]
		var nx := cos(th)
		var nz := sin(th)
		_gx[q] = o[q].x
		_gz[q] = o[q].z
		_gnx[q] = nx
		_gnz[q] = nz
		_gh[q] = th
		_glx[q] = o[q].x + nx * a
		_glz[q] = o[q].z + nz * a
		_grx[q] = o[q].x + nx * b
		_grz[q] = o[q].z + nz * b
		_gel[q] = half + _shoulder
		_ger[q] = paved_r + _shoulder
		if q > 0:
			acc += absf(th - hd[q - 1])
		_gtu[q] = acc
	_g0 = c
	_g1 = hi
	_grow(hi)


## The fan of the camera at row c (both outermost lanes).
func _camera(c: int) -> void:
	cameras += 1
	_geometry(c)
	var L := chord_at(c)
	var n := L / _seg
	var qc := c - _g0
	var count := _g1 - _g0 + 1
	var dn := mini(int(floor(n)), _g1 - c)
	if dn < 1:
		skipped += 1
		return
	# a straight fan never leaves the road: a curve deviates from its chord by at most length * turning / 2
	var turning := _gtu[mini(qc + dn + 1, count - 1)] - _gtu[qc]
	if L * minf(turning, PI * 0.5) * 0.5 < _lane_w * 0.5 + _shoulder - 0.25:
		skipped += 1
		return
	var th := _gh[qc]
	# the far end at exactly L (between two rows)
	var ft := n - float(dn)
	var q0 := qc + dn
	var has_end := ft > 1.0e-4 and q0 + 1 < count and absf(lerpf(_gh[q0], _gh[q0 + 1], ft) - th) <= MAX_TURN
	if turning < simple_turn:
		_camera_simple(c, qc, dn, has_end, ft)
		return
	var elx := 0.0
	var elz := 0.0
	var erx := 0.0
	var erz := 0.0
	if has_end:
		elx = lerpf(_glx[q0], _glx[q0 + 1], ft)
		elz = lerpf(_glz[q0], _glz[q0 + 1], ft)
		erx = lerpf(_grx[q0], _grx[q0 + 1], ft)
		erz = lerpf(_grz[q0], _grz[q0 + 1], ft)
	var lo_row := c - _lo
	for ci in 2:
		var cx := _glx[qc] if ci == 0 else _grx[qc]
		var cz := _glz[qc] if ci == 0 else _grz[qc]
		# the outermost sight lines so far (world vectors from the camera): v lies right of u when u × v > 0
		var urx := 0.0
		var urz := 0.0
		var ulx := 0.0
		var ulz := 0.0
		var any := false
		if has_end:
			urx = elx - cx
			urz = elz - cz
			ulx = urx
			ulz = urz
			var vx := erx - cx
			var vz := erz - cz
			if urx * vz - urz * vx > 0.0:
				urx = vx
				urz = vz
			else:
				ulx = vx
				ulz = vz
			any = true
		var d := dn
		while d >= 1:
			var q := qc + d
			if absf(_gh[q] - th) <= MAX_TURN:
				var vx := _glx[q] - cx
				var vz := _glz[q] - cz
				if not any:
					urx = vx
					urz = vz
					ulx = vx
					ulz = vz
					any = true
				else:
					if urx * vz - urz * vx > 0.0:
						urx = vx
						urz = vz
					if ulx * vz - ulz * vx < 0.0:
						ulx = vx
						ulz = vz
				vx = _grx[q] - cx
				vz = _grz[q] - cz
				if urx * vz - urz * vx > 0.0:
					urx = vx
					urz = vz
				if ulx * vz - ulz * vx < 0.0:
					ulx = vx
					ulz = vz
			if any and d % row_step == 0:
				# crossings of both outermost lines with the cross-section of this row: C + s u = P + x r
				# (beyond a quarter turn of the road the order of the crossings flips, so both count on both sides)
				var njx := _gnx[q]
				var njz := _gnz[q]
				var dx := cx - _gx[q]
				var dz := cz - _gz[q]
				var sd := dx * njz - dz * njx
				var xr := -INF
				var xl := -INF
				var den := njx * urz - njz * urx
				if den * den > 0.0025 * (urx * urx + urz * urz) and sd / den > 0.0:
					var x := (dx * urz - dz * urx) / den
					xr = x
					xl = -x
				den = njx * ulz - njz * ulx
				if den * den > 0.0025 * (ulx * ulx + ulz * ulz) and sd / den > 0.0:
					var x2 := (dx * ulz - dz * ulx) / den
					xr = maxf(xr, x2)
					xl = maxf(xl, -x2)
				if xr > -INF:
					var wi := lo_row + d
					var w := xr - _ger[q]
					if w > _wr[wi]:
						_wr[wi] = w
					var w2 := xl - _gel[q]
					if w2 > _wl[wi]:
						_wl[wi] = w2
			d -= 1


## The fan of a camera whose road turns less than SIMPLE_TURN up to L: every crossing is then a convex combination of
## the lateral positions of its two ends, so the right edge comes from the rightmost lane centres at both ends and the
## left edge from the leftmost ones – one camera point and one target point per side.
func _camera_simple(c: int, qc: int, dn: int, has_end: bool, ft: float) -> void:
	var q0 := qc + dn
	var lo_row := c - _lo
	for si in 2:
		var right := si == 1
		var sgn := 1.0 if right else -1.0
		var cx := _grx[qc] if right else _glx[qc]
		var cz := _grz[qc] if right else _glz[qc]
		var ux := 0.0
		var uz := 0.0
		var any := false
		if has_end:
			ux = (lerpf(_grx[q0], _grx[q0 + 1], ft) if right else lerpf(_glx[q0], _glx[q0 + 1], ft)) - cx
			uz = (lerpf(_grz[q0], _grz[q0 + 1], ft) if right else lerpf(_glz[q0], _glz[q0 + 1], ft)) - cz
			any = true
		var d := dn
		while d >= 1:
			var q := qc + d
			var vx := (_grx[q] if right else _glx[q]) - cx
			var vz := (_grz[q] if right else _glz[q]) - cz
			if not any:
				ux = vx
				uz = vz
				any = true
			elif (ux * vz - uz * vx) * sgn > 0.0:
				ux = vx
				uz = vz
			if d % row_step == 0:
				var njx := _gnx[q]
				var njz := _gnz[q]
				var dx := cx - _gx[q]
				var dz := cz - _gz[q]
				var den := njx * uz - njz * ux
				if den * den > 0.0025 * (ux * ux + uz * uz) and (dx * njz - dz * njx) / den > 0.0:
					var x := (dx * uz - dz * ux) / den * sgn
					var w := x - (_ger[q] if right else _gel[q])
					var wi := lo_row + d
					if right:
						if w > _wr[wi]:
							_wr[wi] = w
					elif w > _wl[wi]:
						_wl[wi] = w
			d -= 1
