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
## The band so runs out at the start and the end of a bend, follows the real arc of a short bend, keeps the inside of
## the road before a bend free beyond the sight lines that reach into it, and in slow mountain bends (short L) it is
## narrow.
##
## Method (per camera row a, every CAM_STEP rows, aligned to absolute row numbers so that every start of the stream
## gets the same numbers): the camera stands at the outermost lane centre on either side (the sight lines of the lanes
## in between lie inside their convex hull); the targets are the outermost lane centres of every TGT_STEP-th row up to
## L. Walking the targets from the far end back, the largest bearing to the right (and to the left) seen so far gives
## the outermost sight line that still crosses the cross-section of the row just reached; its crossing with that
## cross-section is the corridor's edge there. Rows between the sampled ones are interpolated, every row takes the
## largest value of itself and its neighbours (ChunkContext interpolates between rows), plus MARGIN_M. A sight line
## never counts beyond the medial axis to another part of the road (RoadPath3D.clearance()): there the ground belongs
## to that part, and the terrain ribbon and the props end before it anyway.
## Computed lazily and incrementally while the rows are asked for (ensure()), each camera once per stage; the
## results are plain per-row arrays that TerrainProfile snapshots into every ChunkContext (worker-safe).
## Values: metres beyond the outer shoulder edge (shoulder_w beyond the paved edge); NONE where no sight line leaves
## the road. Owner: race3d kernel. Docs: docs/renderer-modern.md 5.3.

const CAM_STEP := 4                    ## camera rows: every 4th (12 m)
const TGT_STEP := 2                    ## target rows and corridor samples: every 2nd (6 m)
const MARGIN_M := 0.3                  ## added to every value (sampling of cameras and targets, measured in the unit test)
const MAX_TURN := 2.6                  ## rad: targets whose heading differs more from the camera's are left out
const BLOCK := 64                      ## camera rows per computation step
const NONE := -6.0                     ## no sight line beyond the shoulder (below every lane centre)
const WEATHERS: Array[String] = ["normal", "rain", "snow"]
const F2_RATIO := 0.6
const REACTION_S := 1.0
const CURVE_TOLERANCE := 1.05

var chord_max_m := 300.0               ## L at most (graphics.modern.terrain.corridor_chord_m)
var camera_offset_m := 9.0             ## camera behind the car (render.camera_distance_m)
var path: RoadPath3D
var track: Track

var _env: Array[Dictionary] = []       ## per weather {safe1 (m/s at curve 1), vtop (m/s), brake (m/s²)}
var _look := 0                         ## rows of braking look-ahead that can still lower a speed
var _cam_rows := 3                     ## rows between the camera and the car
var _nb := 102                         ## rows a fan can reach
var _lane_w := 3.75
var _shoulder := 2.5
var _seg := 3.0
var _inv_r1 := 1.0 / 120.0
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
	_inv_r1 = 1.0 / maxf(1.0, float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0)))
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
## passes; NONE + MARGIN_M or less where none leaves the road. Main thread (reads the path and the track).
func width(k: int, side: int) -> float:
	ensure(k + TGT_STEP + 1)
	var best := NONE
	for q in range(k - 1, k + 2):
		best = maxf(best, _interp(q, side))
	return best + MARGIN_M


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
	if path == null or not path.is_ready():
		return
	if not _started:
		_start()
	if k < _lo:
		return
	var t0 := Time.get_ticks_usec()
	while _cam_next <= k and _cam_next <= path.end_index():
		var c1 := mini(_cam_next + BLOCK - CAM_STEP, path.end_index())
		_compute_block(_cam_next, c1)
		_cam_next = (int(floor(float(c1) / float(CAM_STEP))) + 1) * CAM_STEP
	usec += Time.get_ticks_usec() - t0


func _start() -> void:
	_started = true
	var first := path.first
	if path.has_lead_in():
		first = -(_nb + 32)          # cameras on the straight lead-in before the start line see the first bend too
	_cam_next = int(floor(float(first) / float(CAM_STEP))) * CAM_STEP
	if _cam_next < first:
		_cam_next += CAM_STEP
	_lo = _cam_next
	_wl.clear()
	_wr.clear()
	_n_lo = _cam_next
	_n_hi = _cam_next - 1
	_need.clear()


func _interp(q: int, side: int) -> float:
	var k0 := int(floor(float(q) / float(TGT_STEP))) * TGT_STEP
	var u := float(q - k0) / float(TGT_STEP)
	var a := _raw(k0, side)
	if u <= 0.0:
		return a
	return lerpf(a, _raw(k0 + TGT_STEP, side), u)


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

## Computes the fans of the cameras c0 .. c1 (multiples of CAM_STEP).
func _compute_block(c0: int, c1: int) -> void:
	var end := path.end_index()
	var hi := mini(c1 + _nb + 1, end)
	path.ensure(hi)
	_ensure_need(c1 + _cam_rows)
	var g := path.rows_local(c0, hi)
	var o: PackedVector3Array = g["o"]
	var hd: PackedFloat64Array = g["heading"]
	var count := hi - c0 + 1
	# lane extremes (signed lateral offsets of the outermost lane centres) and shoulder edges per row
	var xl := PackedFloat32Array()
	var xr := PackedFloat32Array()
	var el := PackedFloat32Array()
	var er := PackedFloat32Array()
	var turn := PackedFloat32Array()        # prefix sums of the absolute heading change
	xl.resize(count)
	xr.resize(count)
	el.resize(count)
	er.resize(count)
	turn.resize(count)
	var acc := 0.0
	for q in count:
		var s := track.get_segment(maxi(c0 + q, 0))
		var half := s.lanes * _lane_w * 0.5
		var paved_r := half + s.fuel_lane * _lane_w
		var a := -half + _lane_w * 0.5
		var b := paved_r - _lane_w * 0.5
		if a > b:
			a = (a + b) * 0.5
			b = a
		xl[q] = a
		xr[q] = b
		el[q] = half + _shoulder
		er[q] = paved_r + _shoulder
		if q > 0:
			acc += absf(hd[q] - hd[q - 1])
		turn[q] = acc
	_grow(hi)
