class_name ChunkStreamer
extends Node3D
## Kernel of the mode "Modern" (v0.8.0): streams the world as chunks of road (chunk_segments segments = 96 m) strictly
## by path distance. It owns the chunk nodes and their transforms; the builders (ChunkBuilder) only fill them.
##
## Per update(cam_z, visibility_m):
##  * the path is extended landmark_path_m ahead of the camera, trimmed far behind it and re-based when the camera
##    is more than rebase_m from the floating origin (signal rebased(shift): every origin-relative position the
##    renderer keeps moves by shift; the chunk nodes are moved here),
##  * a chunk is wanted when its near edge is at most load_path_m of path ahead AND at most
##    visibility + one chunk length away by air; at most max_chunks are held (when the rule wants more, the
##    farthest by air – in the fog at the end of the visibility – wait); a chunk is freed once its far edge lies
##    more than keep_behind_m behind the camera,
##  * a new chunk is collected on the main thread (ChunkContext.capture + ChunkBuilder.collect), built on the
##    WorkerThreadPool (ChunkBuilder.build) and committed on the main thread (ChunkBuilder.commit), at most
##    commits_per_frame chunks per update. The first update after a start or a camera jump loads everything that is
##    wanted at once (behind the loading overlay). With sync = true (--gfx-sync, tests) every update builds and
##    commits everything at once on the main thread, so the result depends on the camera position only.
## Before a chunk is collected the road is integrated clear_reach_m beyond it (RoadPath3D.clearance needs every part
## of the road that can be loaded together with it); that forces the Track generation ahead, which is harmless.
## Config: graphics.modern {chunk_segments, load_path_m, landmark_path_m, keep_behind_m, threaded_build,
## commits_per_frame, max_chunks, rebase_m}; levels: terrain_outer_m.
## Owner: race3d kernel. Docs: docs/renderer-modern.md.

signal rebased(shift: Vector3)

const COLLECTED := 0
const BUILDING := 1
const BUILT := 2
const COMMITTED := 3


## One chunk on its way through collect -> build -> commit. The build task only touches `parts` and `build_us`.
class Chunk extends RefCounted:
	var index := 0
	var ctx: ChunkContext
	var inputs: Array = []
	var parts: Array = []
	var task := -1
	var state := 0
	var node: Node3D
	var build_us := 0

	func run(builders: Array) -> void:
		var t0 := Time.get_ticks_usec()
		var out: Array = []
		for i in builders.size():
			out.append((builders[i] as ChunkBuilder).build(ctx, inputs[i]))
		parts = out
		build_us = Time.get_ticks_usec() - t0


var path: RoadPath3D
var terrain: TerrainProfile
var track: Track
var cfg: Dictionary = {}
var levels: Dictionary = {}
var sync := false
var threaded := true
var chunk_segments := 32
var load_path_m := 1500.0
var landmark_path_m := 1900.0
var keep_behind_m := 150.0
var commits_per_frame := 1
var max_chunks := 16
var rebase_m := 2000.0

var _builders: Array = []              ## ChunkBuilder, in registration order
var _chunks: Dictionary = {}           ## chunk index -> Chunk
var _loaded := false
var _curve_r1 := 120.0
var _last_cam_seg := -1
var _last_vis := -1.0
var _wanted: Array[int] = []
var _builds := 0
var _build_us_sum := 0
var _build_us_max := 0
var _collect_us_max := 0
var _collect_us_sum := 0
var _collects := 0
var _commit_us_max := 0
var _commit_us_sum := 0
var _commits := 0
var _rebases := 0
var _restarts := 0


## game_cfg = the whole game configuration (ConfigLoader.load_merged()). The path may still be without a setup: the
## first update() starts it behind the camera.
func setup(p: RoadPath3D, t: TerrainProfile, tr: Track, game_cfg: Dictionary, lv: Dictionary, sync_mode: bool) -> void:
	clear()
	path = p
	terrain = t
	track = tr
	cfg = game_cfg
	levels = lv
	sync = sync_mode
	var m: Dictionary = ConfigLoader.lookup(cfg, "graphics.modern", {})
	chunk_segments = maxi(4, int(m.get("chunk_segments", 32)))
	load_path_m = maxf(100.0, float(m.get("load_path_m", 1500.0)))
	landmark_path_m = maxf(load_path_m, float(m.get("landmark_path_m", 1900.0)))
	keep_behind_m = maxf(0.0, float(m.get("keep_behind_m", 150.0)))
	commits_per_frame = maxi(1, int(m.get("commits_per_frame", 1)))
	max_chunks = maxi(2, int(m.get("max_chunks", 16)))
	rebase_m = maxf(200.0, float(m.get("rebase_m", 2000.0)))
	threaded = bool(m.get("threaded_build", true)) and not sync
	_curve_r1 = float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
	var chunk_m := float(chunk_segments) * tr.seg_len
	# two chunks can be alive together when their rows are at most this far apart along the path
	path.clear_reach_m = load_path_m + keep_behind_m + 2.0 * chunk_m
	if terrain != null and lv.has("terrain_outer_m"):
		terrain.set_outer_ring(float(lv["terrain_outer_m"]))
	_loaded = false
	_last_cam_seg = -1
	_last_vis = -1.0


## Adds a builder (before the first update). Its parts appear in every chunk in registration order.
func register(builder: ChunkBuilder) -> void:
	if builder != null:
		_builders.append(builder)


func builders() -> Array:
	return _builders


func chunk_count() -> int:
	return _chunks.size()


## Number of chunks that are not committed yet.
func pending_count() -> int:
	var n := 0
	for c: Chunk in _chunks.values():
		if c.state != COMMITTED:
			n += 1
	return n


## Frees every chunk (waits for running builds).
func clear() -> void:
	for c: Chunk in _chunks.values():
		_drop(c)
	_chunks.clear()
	_wanted.clear()
	_loaded = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for c: Variant in _chunks.values():
			var ch := c as Chunk
			if ch != null and ch.task >= 0:
				WorkerThreadPool.wait_for_task_completion(ch.task)
				ch.task = -1


func update(cam_z: float, visibility_m: float) -> void:
	if track == null or path == null or terrain == null:
		return
	var seg_len := track.seg_len
	var cam_seg := clampi(int(floor(cam_z / seg_len)), 0, track.segment_count - 1)
	if not path.is_ready() or path.track != track or cam_seg > path.last() \
			or (cam_seg < path.first and track.get_segment(cam_seg).index == cam_seg):
		_restart(cam_z, cam_seg)
	# every frame a little: the path always reaches as far as the farthest chunk that can be collected needs it
	# (clearance, valley floor, late signs), so collecting a chunk never has to generate road
	var ahead := int(_ahead_m() / seg_len)
	path.ensure(cam_seg + ahead)
	if path.last() < cam_seg:
		# the road between the old path and the camera is gone from the track window (a jump ahead)
		_restart(cam_z, cam_seg)
		path.ensure(cam_seg + ahead)
	if cam_seg < path.first:
		# the camera is behind everything the track still holds: stream from the oldest road there is
		cam_seg = path.first
		cam_z = float(cam_seg) * seg_len
	if path.origin_distance(cam_seg) > rebase_m:
		_rebase(cam_seg)
	var moved := cam_seg != _last_cam_seg or absf(visibility_m - _last_vis) > 0.5
	if moved:
		_last_cam_seg = cam_seg
		_last_vis = visibility_m
		_free_behind(cam_z)
		_wanted = _compute_wanted(cam_z, cam_seg, visibility_m)
		_trim(cam_seg)
	var at_once := sync or not _loaded
	# collect: everything at once at load / in sync mode, else one chunk per update
	var collected := false
	for ci: int in _wanted:
		if _chunks.has(ci):
			continue
		if not _make_room(ci, cam_seg):
			break
		if _collect(ci, threaded):
			collected = true
			if not at_once:
				break
	if at_once:
		flush()
		_loaded = true
		return
	if collected:
		return   # one main-thread job per frame: a frame that collected a chunk commits none
	# threaded mode: commit finished builds, nearest first
	var done := 0
	while done < commits_per_frame:
		var best: Chunk = null
		var best_d := 0
		for c: Chunk in _chunks.values():
			if c.state == BUILDING and WorkerThreadPool.is_task_completed(c.task):
				_finish_task(c)
			if c.state == COLLECTED:
				_build_now(c)
			if c.state == BUILT:
				var d := absi(c.index * chunk_segments + chunk_segments / 2 - cam_seg)
				if best == null or d < best_d:
					best = c
					best_d = d
		if best == null:
			break
		_commit(best)
		done += 1


## Builds and commits everything that is collected, now (load, sync mode, tests).
func flush() -> void:
	for c: Chunk in _chunks.values():
		if c.state == BUILDING:
			_finish_task(c)
		if c.state == COLLECTED:
			_build_now(c)
	var keys := _chunks.keys()
	keys.sort()
	for ci: int in keys:
		var c: Chunk = _chunks[ci]
		if c.state == BUILT:
			_commit(c)


## True when nothing is being built or waiting for its commit.
func is_idle() -> bool:
	return pending_count() == 0


## Plain data for debug_snapshot() and tests: {"chunks": [{index, seg_a, seg_b, state, pos, parts: {<builder id>:
## ChunkBuilder.debug()}}] sorted by index, "pending", "path": {first, last, origin_index}}.
func snapshot() -> Dictionary:
	var list: Array = []
	var keys := _chunks.keys()
	keys.sort()
	for ci: int in keys:
		var c: Chunk = _chunks[ci]
		var parts := {}
		if c.state >= BUILT:
			for i in _builders.size():
				var b := _builders[i] as ChunkBuilder
				parts[b.id()] = b.debug(c.parts[i])
		var pos := c.node.position if c.node != null else Vector3.ZERO
		list.append({"index": c.index, "seg_a": c.ctx.seg_a, "seg_b": c.ctx.seg_b,
			"state": "committed" if c.state == COMMITTED else "pending",
			"pos": [snappedf(pos.x, 0.001), snappedf(pos.y, 0.001), snappedf(pos.z, 0.001)], "parts": parts})
	return {"chunks": list, "pending": pending_count(),
		"path": {"first": path.first if path != null else 0, "last": path.last() if path != null and path.is_ready() else 0,
			"origin_index": path.origin_index if path != null else 0}}


## Timing and counters for perf_stats(): chunks, pending, builds, build_ms_avg / _max (ChunkBuilder.build of all
## builders per chunk), collect_ms_avg / _max (snapshot on the main thread), commit_ms_avg / _max, commits, rebases,
## restarts.
func stats() -> Dictionary:
	return {"chunks": _chunks.size(), "pending": pending_count(), "builds": _builds,
		"build_ms_avg": float(_build_us_sum) / maxf(1.0, float(_builds)) / 1000.0, "build_ms_max": float(_build_us_max) / 1000.0,
		"collect_ms_avg": float(_collect_us_sum) / maxf(1.0, float(_collects)) / 1000.0, "collect_ms_max": float(_collect_us_max) / 1000.0,
		"commit_ms_avg": float(_commit_us_sum) / maxf(1.0, float(_commits)) / 1000.0, "commit_ms_max": float(_commit_us_max) / 1000.0,
		"commits": _commits, "rebases": _rebases, "restarts": _restarts}


## Forgets the timing maxima (after the load, so that perf_stats() shows the drive).
func reset_stats() -> void:
	_builds = 0
	_build_us_sum = 0
	_build_us_max = 0
	_collect_us_max = 0
	_collect_us_sum = 0
	_collects = 0
	_commit_us_max = 0
	_commit_us_sum = 0
	_commits = 0


## The chunk node of a chunk index (null when it is not committed).
func chunk_node(ci: int) -> Node3D:
	var c: Chunk = _chunks.get(ci)
	return c.node if c != null else null


## The chunk indices wanted for a camera position (what update() computes; no side effects besides extending the path).
func wanted_for(cam_z: float, visibility_m: float) -> Array[int]:
	var cam_seg := clampi(int(floor(cam_z / track.seg_len)), 0, track.segment_count - 1)
	path.ensure(cam_seg + int(landmark_path_m / track.seg_len))
	return _compute_wanted(cam_z, cam_seg, visibility_m)


## How far ahead of the camera (m of path) the path is kept integrated: the farthest row a chunk can have when it
## is collected plus what clearance() looks at beyond it – at least landmark_path_m.
func _ahead_m() -> float:
	return maxf(landmark_path_m, load_path_m + float(chunk_segments) * track.seg_len + path.clear_reach_m)


# --- internals ------------------------------------------------------------------------------------------------

func _restart(cam_z: float, _cam_seg: int) -> void:
	clear()
	var chunk_m := float(chunk_segments) * track.seg_len
	var c_lo := maxi(0, int(floor((cam_z - keep_behind_m) / chunk_m)))
	path.setup(track, c_lo * chunk_segments, _curve_r1)
	terrain.trim(1 << 40)
	_restarts += 1
	_last_cam_seg = -1


func _rebase(cam_seg: int) -> void:
	var shift := path.rebase(cam_seg)
	for c: Chunk in _chunks.values():
		if c.node != null:
			c.node.position = path.point(c.ctx.seg_a) if c.ctx.seg_a >= path.first else c.node.position + shift
	_rebases += 1
	rebased.emit(shift)


func _trim(cam_seg: int) -> void:
	var seg_len := track.seg_len
	var keep := int((keep_behind_m + path.clear_reach_m) / seg_len) + 3 * chunk_segments
	var to := cam_seg - keep
	if to > path.first + 2 * chunk_segments:
		path.trim(to)
		terrain.trim(to)


func _free_behind(cam_z: float) -> void:
	var chunk_m := float(chunk_segments) * track.seg_len
	for ci: int in _chunks.keys():
		if float(ci + 1) * chunk_m < cam_z - keep_behind_m:
			_drop(_chunks[ci])
			_chunks.erase(ci)


## The chunks the load rule wants, most important first: the chunk under the camera and those behind it, then by
## distance by air. When the rule wants more than max_chunks, the farthest by air are left out – they lie in the
## fog at the end of the visibility.
func _compute_wanted(cam_z: float, cam_seg: int, vis: float) -> Array[int]:
	var n := chunk_segments
	var seg_len := track.seg_len
	var chunk_m := float(n) * seg_len
	var end_seg := track.segment_count - 1
	var c_lo := maxi(int(ceil(float(path.first) / float(n))), int(floor((cam_z - keep_behind_m) / chunk_m)))
	var c_hi := mini(int(floor((cam_z + load_path_m) / chunk_m)), (end_seg - 1) / n)
	var cam_p := path.centre_at(cam_z)
	var lim := vis + chunk_m
	var lim2 := lim * lim
	var list: Array = []          # [distance², chunk index]
	for ci in range(c_lo, c_hi + 1):
		var a := ci * n
		var b := mini(a + n, end_seg)
		if b <= a:
			break
		var d2 := -1.0 + float(ci - c_lo) * 1.0e-6     # at or behind the camera: always wanted, nearest first
		if a > cam_seg:
			d2 = INF
			for k: int in [a, (a + b) / 2, b]:
				var p := path.point(k)
				d2 = minf(d2, (p.x - cam_p.x) * (p.x - cam_p.x) + (p.z - cam_p.z) * (p.z - cam_p.z))
			if d2 > lim2:
				continue
		list.append([d2, ci])
	list.sort_custom(func(u: Array, v: Array) -> bool: return float(u[0]) < float(v[0]) or (float(u[0]) == float(v[0]) and int(u[1]) < int(v[1])))
	var out: Array[int] = []
	for e: Array in list:
		if out.size() >= max_chunks:
			break
		out.append(int(e[1]))
	return out


## Makes sure one more chunk fits: when max_chunks are held, a chunk that is no longer wanted goes (the farthest
## ahead first).
func _make_room(_ci: int, _cam_seg: int) -> bool:
	if _chunks.size() < max_chunks:
		return true
	var victim := -1
	for k: int in _chunks.keys():
		if k > victim and not _wanted.has(k):
			victim = k
	if victim < 0:
		return false
	_drop(_chunks[victim])
	_chunks.erase(victim)
	return true


## Collects chunk ci on the main thread. False when its road is no longer in the track window (far behind the camera).
func _collect(ci: int, start_task: bool) -> bool:
	var n := chunk_segments
	var a := ci * n
	var b := mini(a + n, track.segment_count - 1)
	if b <= a or track.get_segment(a).index != a:
		return false
	var t0 := Time.get_ticks_usec()
	# signs are inserted into segments that were generated earlier: the road must be generated generation_lead_m
	# beyond the chunk before its sprites are copied (update() keeps the path much farther ahead anyway)
	path.ensure(b + int(track.generation_lead_m() / track.seg_len) + 2)
	var c := Chunk.new()
	c.index = ci
	var ctx := ChunkContext.new()
	ctx.cfg = cfg
	ctx.scenery_db = terrain.scenery_db
	ctx.levels = levels
	ctx.sync = sync
	ctx.capture(ci, a, b, path, terrain, track)
	c.ctx = ctx
	for bld: ChunkBuilder in _builders:
		c.inputs.append(bld.collect(ctx))
	c.state = COLLECTED
	_chunks[ci] = c
	var us := Time.get_ticks_usec() - t0
	_collect_us_max = maxi(_collect_us_max, us)
	_collect_us_sum += us
	_collects += 1
	if start_task:
		c.task = WorkerThreadPool.add_task(c.run.bind(_builders), false, "Modern chunk %d" % ci)
		c.state = BUILDING
	return true


func _build_now(c: Chunk) -> void:
	c.run(_builders)
	c.state = BUILT
	_count_build(c)


func _finish_task(c: Chunk) -> void:
	if c.task >= 0:
		WorkerThreadPool.wait_for_task_completion(c.task)
		c.task = -1
	c.state = BUILT
	_count_build(c)


func _count_build(c: Chunk) -> void:
	_builds += 1
	_build_us_sum += c.build_us
	_build_us_max = maxi(_build_us_max, c.build_us)


func _commit(c: Chunk) -> void:
	var t0 := Time.get_ticks_usec()
	var node := Node3D.new()
	node.name = "Chunk%d" % c.index
	node.position = path.point(c.ctx.seg_a)
	for i in _builders.size():
		(_builders[i] as ChunkBuilder).commit(c.ctx, c.parts[i], node)
	add_child(node)
	c.node = node
	c.state = COMMITTED
	_commits += 1
	var us := Time.get_ticks_usec() - t0
	_commit_us_max = maxi(_commit_us_max, us)
	_commit_us_sum += us


func _drop(c: Chunk) -> void:
	if c.task >= 0:
		WorkerThreadPool.wait_for_task_completion(c.task)
		c.task = -1
	if c.node != null:
		if c.node.get_parent() != null:
			c.node.get_parent().remove_child(c.node)
		c.node.free()
		c.node = null
