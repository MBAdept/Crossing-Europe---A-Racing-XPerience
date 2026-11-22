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
## to another part of the road (RoadPath3D.clearance()): the ground there belongs to that part, and the terrain ribbon
## and the props end before it anyway. Targets that turned more than MAX_TURN from the camera's heading are left out.
## Computed lazily and incrementally while rows are asked for (ensure()), each camera once per stage; the results are
## plain per-row numbers that TerrainProfile snapshots into every ChunkContext (worker-safe).
## Values: metres beyond the outer shoulder edge (shoulder_w beyond the paved edge); NONE + MARGIN_M where no sight
## line leaves the road. Owner: race3d kernel. Docs: docs/renderer-modern.md 5.3.

const CAM_STEP := 2                    ## camera rows: every 2nd (6 m)
const ROW_STEP := 2                    ## corridor samples: every 2nd row (6 m), linear in between
const MARGIN_M := 0.3                  ## added to every value (sampling of the cameras, measured in the unit test)
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
	return _interp(k, side) + MARGIN_M


## The largest width() of row k and its two neighbours (whether a sight line leaves the road near the row: the
## builders interpolate between rows).
func width_near(k: int, side: int) -> float:
	ensure(k + 1 + row_step)
	return maxf(maxf(_interp(k - 1, side), _interp(k, side)), _interp(k + 1, side)) + MARGIN_M


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
		var c1 := mini(_cam_next + BLOCK - cam_step, path.end_index())
		_compute_block(_cam_next, c1)
		_cam_next = (int(floor(float(c1) / float(cam_step))) + 1) * cam_step
	usec += Time.get_ticks_usec() - t0


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


func _interp(q: int, side: int) -> float:
	var k0 := int(floor(float(q) / float(row_step))) * row_step
	var u := float(q - k0) / float(row_step)
	var a := _raw(k0, side)
	if u <= 0.0:
		return a
	return lerpf(a, _raw(k0 + row_step, side), u)


