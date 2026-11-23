class_name ChunkStreamer
extends Node3D
## Kernel of the mode "Modern" (v0.8.0): streams the world as chunks of road (chunk_segments segments = 96 m) strictly
## by path distance. It owns the chunk nodes and their transforms; the builders (ChunkBuilder) only fill them.
##
## Per update(cam_z, visibility_m):
##  * the path is kept integrated load_path_m + one chunk + clear_reach_m ahead of the camera (3,438 m with the
##    shipped values, at least landmark_path_m; it grows by a segment per frame), trimmed far behind it and re-based
##    when the camera is more than rebase_m from the floating origin (signal rebased(shift): every origin-relative
##    position the renderer keeps moves by shift; the chunk nodes are moved here),
##  * a chunk is wanted when its near edge is at most load_path_m of path ahead AND at most
##    visibility + one chunk length away by air; at most max_chunks are held (when the rule wants more, the
##    farthest by air wait); a chunk is freed once its far edge lies more than keep_behind_m behind the camera,
##  * a new chunk is collected on the main thread (ChunkContext.capture + ChunkBuilder.collect), built on the
##    WorkerThreadPool (ChunkBuilder.build) and committed on the main thread (ChunkBuilder.commit): per update one
##    chunk is collected or at most commits_per_frame are committed. The first update after a start or a camera
##    jump loads everything that is wanted at once (behind the loading overlay). With sync = true (--gfx-sync,
##    tests) every update builds and commits everything at once on the main thread, so the result depends on the
##    camera position only.
##  * a frame that neither collects nor commits computes a little of the sight corridor ahead (TerrainProfile.warm(),
##    contract A-17), so that collecting a chunk finds its rows ready – up to two chunks beyond landmark_path_m, because
##    the far landmarks of the props builder read the terrain (and with it the corridor) of their rows that far ahead;
##    loading computes that front at once (R7a measured main-thread spikes of up to 24 ms in the props hook without it).
## The path reaches that far because RoadPath3D.clearance needs every part of the road that can be loaded together
## with a chunk; it forces the Track generation ahead, which is harmless (the generator is sequential).
## Lead-in (FIX-ZS1, finding QA1-B1): while the path has its lead-in (RoadPath3D.has_lead_in(): the kept range starts
## at the start of the track), chunk -1 = rows -chunk_segments .. 0 is a chunk like any other – the road behind the
## start line where the camera stands during the countdown (9 m behind the car at z = 0). Its rows lie on the straight
## lead-in of the path and carry segment 0's data without its sprites (ChunkContext.capture), so every builder builds
## its normal road, guardrails and ground there and no prop or sign twice. It is loaded and freed by the same rules
## (wanted while it lies at most keep_behind_m behind the camera), so nothing changes once the camera is past that.
## Config: graphics.modern {chunk_segments, load_path_m, landmark_path_m, keep_behind_m, threaded_build,
## commits_per_frame, max_chunks, rebase_m}; levels: terrain_outer_m.
## Owner: race3d kernel. Docs: docs/renderer-modern.md.

signal rebased(shift: Vector3)

const COLLECTED := 0
const BUILDING := 1
const WARM_US := 250                   ## main-thread time per frame for the sight corridor ahead (_warm_corridor())
const WARM_CATCHUP_US := 2000          ## the same while the corridor lags behind the rows the next collect reads
const BUILT := 2
const COMMITTED := 3
const COMMITTING := 4      ## FIX-RINT (B-01): some builders committed, the node not yet in the tree
## FIX-RINT (QA-RINT-SYSTEM B-01): §4.10 allows 3 ms of chunk commit per frame ("Steam Deck", „Niedrig“, „Mittel“);
## whole chunks took 3.8–9.0 ms at most (mean 1.0–1.3 ms) in every measurement since the base. In the threaded mode a
## chunk is now committed builder by builder over several frames: a frame commits builders while its commit time is
## below COMMIT_BUDGET_MS (at least one builder per frame; the next one only when its mean commit time still fits). The
## chunk node stays out of the tree until every builder has committed – as during a whole commit before – and
## chunk_node() answers only then; the lamp layers wait for a lamp parent that has not entered the tree yet and forget
## one that left it or was freed (a chunk dropped half-done). Load and sync mode (flush()) commit whole chunks.
const COMMIT_BUDGET_MS := 2.0
## FIX-RINT (QA-RINT-BILD F-08): a chunk left behind the camera leaves the tree at once (its lamps are forgotten, nothing
## of it is drawn) but is freed in pieces – child by child while a frame has used less than FREE_BUDGET_MS. Freeing a
## whole chunk in one frame was the streamer's hitch: update_ms_max "free" up to 141.7 ms, the "streamer" spikes of
## 8–144 ms all fell there (Kiel – Hamburg, "Steam Deck", Xvfb, measured). clear() frees everything at once.
const FREE_BUDGET_MS := 1.0
## … and only TRASH_DELAY updates after it left the tree: freeing a mesh the renderer may still be drawing from (the
## frame before) made the driver wait for that frame – single frees of up to 134 ms on llvmpipe right after the drop
## (measured, update_ms_max "trash"; inferred: a GPU sync on delete).
const TRASH_DELAY := 4


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
	var commit_i := 0          ## next builder to commit (COMMITTING)
	var commit_k := 0          ## A-28 (RINT-M3): next step of that builder (ChunkBuilder.commit_steps())

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
var max_chunks := 18
var rebase_m := 2000.0
## Handed to every ChunkContext as ctx.services – MAIN THREAD ONLY (ChunkBuilder.collect / commit). The renderer sets
## {"renderer": ModernRenderer, "materials": ModernMaterials} before the first update(); without a renderer (tests)
## it stays {} and the builders work without it.
var services: Dictionary = {}

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
## RINT-M2 (A-18: collect() of every layer and builder at most 2 ms per frame on the Deck preset): main-thread time of
## each builder's collect() – id -> [sum us, max us, calls]
var _collect_by: Dictionary = {}
var _commit_us_max := 0
var _commit_us_sum := 0
var _commits := 0
var _commit_steps := 0
var _frame_commit_us := 0          ## FIX-RINT: commit time of the current frame (all steps of one update())
## FIX-RINT (B-01): main-thread time of each builder's commit() – id -> [sum us, max us, calls]
var _commit_by: Dictionary = {}
var _update_us_max: Dictionary = {}  ## FIX-RINT (F-08): part of update() -> longest µs
var _trash: Array[Node] = []         ## FIX-RINT (F-08): chunk nodes out of the tree, oldest first, freed in pieces
var _trash_age := PackedInt32Array() ## … the updates since each left the tree
var _rebases := 0
var _restarts := 0
var _warm_us_max := 0                  ## _warm_corridor(): main-thread time per frame
var _warm_us_sum := 0
var _warm_calls := 0


## game_cfg = the whole game configuration (ConfigLoader.load_merged()); the builders get it as ChunkContext.cfg.
## The path may still be without a setup: the first update() starts it behind the camera.
func setup(p: RoadPath3D, t: TerrainProfile, tr: Track, game_cfg: Dictionary, lv: Dictionary, sync_mode: bool) -> void:
	clear()
	path = p
	terrain = t
	track = tr
	cfg = game_cfg
	levels = lv
	sync = sync_mode
	var m: Dictionary = ConfigLoader.lookup(cfg, "graphics.modern", {})
	if m.is_empty() and cfg.has("load_path_m"):
		m = cfg      # only the graphics.modern section was passed
	chunk_segments = maxi(4, int(m.get("chunk_segments", 32)))
	load_path_m = maxf(100.0, float(m.get("load_path_m", 1500.0)))
	landmark_path_m = maxf(load_path_m, float(m.get("landmark_path_m", 1900.0)))
	keep_behind_m = maxf(0.0, float(m.get("keep_behind_m", 150.0)))
	commits_per_frame = maxi(1, int(m.get("commits_per_frame", 1)))
	max_chunks = maxi(2, int(m.get("max_chunks", 18)))
	rebase_m = maxf(200.0, float(m.get("rebase_m", 2000.0)))
	threaded = bool(m.get("threaded_build", true)) and not sync
	_curve_r1 = float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 1.0 / path.inv_r1))
	var chunk_m := float(chunk_segments) * tr.seg_len
	# two chunks can be alive together when their rows are at most this far apart along the path
	path.set_clear_reach(load_path_m + keep_behind_m + 2.0 * chunk_m)
	if terrain != null and lv.has("terrain_outer_m"):
		terrain.set_outer_ring(float(lv["terrain_outer_m"]))
	_loaded = false
	_last_cam_seg = -1
	_last_vis = -1.0


## Adds a builder. Its parts appear in every chunk in registration order; chunks that exist already are dropped
## and built again with it.
func register(builder: ChunkBuilder) -> void:
	if builder == null:
		return
	if not _chunks.is_empty():
		clear()
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
	_free_trash(-1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_free_trash(-1)
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
	var tu := Time.get_ticks_usec()
	_free_trash(int(FREE_BUDGET_MS * 1000.0))
	tu = _part_us("trash", tu)
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
	tu = _part_us("path", tu)
	var moved := cam_seg != _last_cam_seg or absf(visibility_m - _last_vis) > 0.5
	if moved:
		_last_cam_seg = cam_seg
		_last_vis = visibility_m
		_free_behind(cam_z)
		tu = _part_us("free", tu)
		_wanted = _compute_wanted(cam_z, cam_seg, visibility_m)
		_trim(cam_seg)
		tu = _part_us("wanted", tu)
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
	tu = _part_us("collect", tu)
	if at_once:
		flush()
		_loaded = true
		terrain.warm(_warm_front(cam_seg, maxf(load_path_m, landmark_path_m)), -1)
		return
	if not collected and not _commit_pending():
		_warm_corridor(cam_seg)   # A-17: a frame with nothing to collect or commit computes some sight corridor ahead
		tu = _part_us("warm", tu)  # A-28 (RINT-M3, NACH-R7a NR7a-03): booked as its own part, not as "commit"
	if collected:
		return   # one main-thread job per frame: a frame that collected a chunk commits none
	# threaded mode: commit finished builds, nearest first – a chunk begun in an earlier frame first –, under the
	# frame's time budget (B-01)
	var done := 0
	var t0 := Time.get_ticks_usec()
	var budget_us := int(COMMIT_BUDGET_MS * 1000.0)
	_frame_commit_us = 0
	while done < commits_per_frame:
		var best: Chunk = null
		var best_d := 0
		for c: Chunk in _chunks.values():
			if c.state == BUILDING and WorkerThreadPool.is_task_completed(c.task):
				_finish_task(c)
			if c.state == COLLECTED:
				_build_now(c)
			if c.state == BUILT or c.state == COMMITTING:
				var d := -1 if c.state == COMMITTING else absi(c.index * chunk_segments + chunk_segments / 2 - cam_seg)
				if best == null or d < best_d:
					best = c
					best_d = d
		if best == null:
			break
		_commit_step(best, t0, budget_us)
		if best.state != COMMITTED:
			break          # the frame's budget ended inside the chunk
		done += 1
		if Time.get_ticks_usec() - t0 >= budget_us:
			break
	_commit_us_max = maxi(_commit_us_max, _frame_commit_us)
	_part_us("commit", tu)


## FIX-RINT (QA-RINT-BILD F-08): the longest time of each part of update() – "path" (generation, rebase), "free"
## (chunks behind the camera), "wanted", "collect", "commit" (with the builds finished on the main thread) – for
## stats()["update_ms_max"]: the streamer's hitches of up to 17 ms (Kiel – Hamburg, Deck) name their part.
func _part_us(part: String, t0: int) -> int:
	var now := Time.get_ticks_usec()
	_update_us_max[part] = maxi(int(_update_us_max.get(part, 0)), now - t0)
	return now


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
		if c.state == BUILT or c.state == COMMITTING:
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
## restarts, corridor (_corridor_stats(): the sight corridor's main-thread time).
func stats() -> Dictionary:
	return {"chunks": _chunks.size(), "pending": pending_count(), "builds": _builds, "corridor": _corridor_stats(),
		"build_ms_avg": float(_build_us_sum) / maxf(1.0, float(_builds)) / 1000.0, "build_ms_max": float(_build_us_max) / 1000.0,
		"collect_ms_avg": float(_collect_us_sum) / maxf(1.0, float(_collects)) / 1000.0, "collect_ms_max": float(_collect_us_max) / 1000.0,
		"commit_ms_avg": float(_commit_us_sum) / maxf(1.0, float(_commits)) / 1000.0, "commit_ms_max": float(_commit_us_max) / 1000.0,
		"commits": _commits, "commit_steps": _commit_steps, "rebases": _rebases, "restarts": _restarts,
		"collect_by": _collect_by_ms(), "commit_by": _by_ms(_commit_by), "update_ms_max": _update_ms_max()}


func _update_ms_max() -> Dictionary:
	var out := {}
	for k: Variant in _update_us_max:
		out[str(k)] = snappedf(float(_update_us_max[k]) / 1000.0, 0.001)
	return out


## collect() per builder: id -> {"avg_ms", "max_ms", "n"} (RINT-M2, A-18).
func _collect_by_ms() -> Dictionary:
	return _by_ms(_collect_by)


## id -> [sum us, max us, calls] as id -> {"avg_ms", "max_ms", "n"}.
static func _by_ms(by: Dictionary) -> Dictionary:
	var out := {}
	for id: Variant in by:
		var a: Array = by[id]
		out[str(id)] = {"avg_ms": snappedf(float(a[0]) / maxf(1.0, float(a[2])) / 1000.0, 0.001),
			"max_ms": snappedf(float(a[1]) / 1000.0, 0.001), "n": int(a[2])}
	return out


## Forgets the timing maxima (after the load, so that perf_stats() shows the drive).
func reset_stats() -> void:
	_reset_corridor_stats()
	_builds = 0
	_build_us_sum = 0
	_build_us_max = 0
	_collect_us_max = 0
	_collect_us_sum = 0
	_collects = 0
	_collect_by.clear()
	_commit_us_max = 0
	_commit_us_sum = 0
	_commits = 0
	_commit_steps = 0
	_frame_commit_us = 0
	_commit_by.clear()
	_update_us_max.clear()


## The chunk node of a chunk index (null when it is not committed – also while it is being committed, B-01).
func chunk_node(ci: int) -> Node3D:
	var c: Chunk = _chunks.get(ci)
	return c.node if c != null and c.state == COMMITTED else null


## The chunk indices wanted for a camera position (what update() computes; no side effects besides extending the path).
func wanted_for(cam_z: float, visibility_m: float) -> Array[int]:
	var cam_seg := clampi(int(floor(cam_z / track.seg_len)), 0, track.segment_count - 1)
	path.ensure(cam_seg + int(landmark_path_m / track.seg_len))
	return _compute_wanted(cam_z, cam_seg, visibility_m)


## How far ahead of the camera (m of path) the path is kept integrated: the farthest row a chunk can have when it
## is collected plus what clearance() looks at beyond it – at least landmark_path_m.
func _ahead_m() -> float:
	return maxf(landmark_path_m, load_path_m + float(chunk_segments) * track.seg_len + path.clear_reach_m)


## A frame without a collect and without a commit computes a little of the sight corridor (TerrainProfile.warm(),
## A-17) of the rows the next chunks and the far landmarks will read, so that nobody waits for them on the main
## thread: up to two chunks beyond landmark_path_m, at most WARM_US per frame (SightCorridor.warm() stops before the
## step that would overrun it, one step at least) – WARM_CATCHUP_US while the corridor does not yet reach two chunks
## beyond the farthest chunk that can be wanted. update() calls it before its commit loop when _commit_pending() says
## that loop has nothing to do (FIX-R7a, QR7a-02: so it never adds to a frame that commits, also when commits run in
## budgeted steps over several frames).
func _warm_corridor(cam_seg: int) -> void:
	var far := _warm_front(cam_seg, maxf(load_path_m, landmark_path_m))
	var need := _warm_front(cam_seg, load_path_m)
	var sight: Variant = terrain.get("sight")
	var behind: bool = sight != null and int(sight.call(&"front")) < need
	var t0 := Time.get_ticks_usec()
	terrain.warm(far, t0 + (WARM_CATCHUP_US if behind else WARM_US))
	var us := Time.get_ticks_usec() - t0
	_warm_us_max = maxi(_warm_us_max, us)
	_warm_us_sum += us
	_warm_calls += 1


## True when the commit loop of update() has work in this frame: a chunk is collected for a build on the main
## thread, built, its build task finished, or it is half committed (it has a node but is not committed yet – a commit
## that runs in steps over several frames). A task that finishes between this test and the loop is the only case
## in which a frame both warms and commits.
func _commit_pending() -> bool:
	for c: Chunk in _chunks.values():
		if c.state == COLLECTED or c.state == BUILT or (c.node != null and c.state != COMMITTED):
			return true
		if c.state == BUILDING and c.task >= 0 and WorkerThreadPool.is_task_completed(c.task):
			return true
	return false


## The row two chunks beyond the chunk that holds the point reach_m ahead of camera row cam_seg (+ 4 rows).
func _warm_front(cam_seg: int, reach_m: float) -> int:
	var n := chunk_segments
	return (int(floor((float(cam_seg) * track.seg_len + reach_m) / (float(n) * track.seg_len))) + 2) * n + 4


## stats()["corridor"]: warm_ms_avg / _max (_warm_corridor() per frame that ran it), warm_calls; sync_ms_max / _sum,
## sync_calls (rows a reader needed before warm() had them – computed at once on the main thread: SightCorridor
## sync_us_*). Reset with the other numbers (reset_stats()), so that perf_stats() of a drive does not show the load.
func _corridor_stats() -> Dictionary:
	var sight: Variant = terrain.get("sight") if terrain != null else null
	var sync_max := float(sight.get("sync_us_max")) if sight != null else 0.0
	var sync_sum := float(sight.get("sync_us_sum")) if sight != null else 0.0
	var sync_calls := int(sight.get("sync_calls")) if sight != null else 0
	return {"warm_ms_avg": float(_warm_us_sum) / maxf(1.0, float(_warm_calls)) / 1000.0, "warm_ms_max": float(_warm_us_max) / 1000.0,
		"warm_calls": _warm_calls, "sync_ms_max": sync_max / 1000.0, "sync_ms_sum": sync_sum / 1000.0, "sync_calls": sync_calls}


func _reset_corridor_stats() -> void:
	_warm_us_max = 0
	_warm_us_sum = 0
	_warm_calls = 0
	var sight: Variant = terrain.get("sight") if terrain != null else null
	if sight != null and sight.has_method(&"reset_sync_stats"):
		sight.call(&"reset_sync_stats")


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
	# the lowest chunk the path holds: -1 = the lead-in before the start line while the path has it
	var c_min := -1 if path.has_lead_in() else int(ceil(float(path.first) / float(n)))
	var c_lo := maxi(c_min, int(floor((cam_z - keep_behind_m) / chunk_m)))
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
## Chunk -1 is the lead-in (rows before the start line): only while the path has it and segment 0 is still there.
func _collect(ci: int, start_task: bool) -> bool:
	var n := chunk_segments
	var a := ci * n
	var b := mini(a + n, track.segment_count - 1)
	if b <= a:
		return false
	if a < 0:
		if not path.has_lead_in() or track.get_segment(0).index != 0:
			return false
	elif track.get_segment(a).index != a:
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
	ctx.services = services
	ctx.capture(ci, a, b, path, terrain, track)
	c.ctx = ctx
	for bld: ChunkBuilder in _builders:
		var tb := Time.get_ticks_usec()
		c.inputs.append(bld.collect(ctx))
		var ub := Time.get_ticks_usec() - tb
		var st: Variant = _collect_by.get(bld.id())
		if st == null:
			_collect_by[bld.id()] = [ub, ub, 1]
		else:
			var acc: Array = st
			acc[0] = int(acc[0]) + ub
			acc[1] = maxi(int(acc[1]), ub)
			acc[2] = int(acc[2]) + 1
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


## The whole chunk at once (load, sync mode, flush()) – or the rest of a chunk that _commit_step() began.
func _commit(c: Chunk) -> void:
	var t0 := Time.get_ticks_usec()
	var node := c.node
	if node == null:
		node = Node3D.new()
		node.name = "Chunk%d" % c.index
		node.position = path.point(c.ctx.seg_a)
	for i in range(c.commit_i, _builders.size()):
		var steps := _steps_of(c, i)
		for k in range(c.commit_k if i == c.commit_i else 0, steps):
			_commit_piece(c, i, k, node)
	c.commit_i = _builders.size()
	c.commit_k = 0
	if node.get_parent() == null:
		add_child(node)
	c.node = node
	c.state = COMMITTED
	_commits += 1
	var us := Time.get_ticks_usec() - t0
	_commit_us_max = maxi(_commit_us_max, us)
	_commit_us_sum += us


## B-01: commits builders of chunk c (BUILT or begun) while the frame's commit time since frame_t0 is below budget_us –
## at least one per frame. The node enters the tree when the last builder is done. A-28 (RINT-M3): the unit is one
## commit step of a builder (ChunkBuilder.commit_steps(): road, terrain and roadside split a large mesh into pieces),
## so a single large builder no longer takes the whole frame's budget at once.
func _commit_step(c: Chunk, frame_t0: int, budget_us: int) -> void:
	var t0 := Time.get_ticks_usec()
	if c.node == null:
		var node := Node3D.new()
		node.name = "Chunk%d" % c.index
		node.position = path.point(c.ctx.seg_a)
		c.node = node
		c.commit_i = 0
		c.commit_k = 0
		c.state = COMMITTING
	var first := _frame_commit_us == 0     # at least one step per frame
	while c.commit_i < _builders.size():
		# the next step only when the mean commit time of a step of that builder so far still fits (one step may
		# exceed the budget alone)
		if not first and Time.get_ticks_usec() - frame_t0 + _commit_estimate(c.commit_i) > budget_us:
			break
		_commit_piece(c, c.commit_i, c.commit_k, c.node)
		c.commit_k += 1
		if c.commit_k >= _steps_of(c, c.commit_i):
			c.commit_i += 1
			c.commit_k = 0
		first = false
	if c.commit_i >= _builders.size():
		add_child(c.node)
		c.state = COMMITTED
		_commits += 1
	var us := Time.get_ticks_usec() - t0
	_commit_steps += 1
	_commit_us_sum += us
	_frame_commit_us += us


## Mean time of one commit step of builder i so far in µs (0 before its first commit).
func _commit_estimate(i: int) -> int:
	var a: Variant = _commit_by.get((_builders[i] as ChunkBuilder).id())
	if a is Array and int((a as Array)[2]) > 0:
		return int((a as Array)[0]) / int((a as Array)[2])
	return 0


## A-28: the number of commit steps of builder i for chunk c (at least 1).
func _steps_of(c: Chunk, i: int) -> int:
	return maxi(1, (_builders[i] as ChunkBuilder).commit_steps(c.parts[i]))


## One commit step k of builder i; commit_by counts steps (sum, max, number) per builder id.
func _commit_piece(c: Chunk, i: int, k: int, node: Node3D) -> void:
	var b0 := Time.get_ticks_usec()
	var b := _builders[i] as ChunkBuilder
	b.commit_step(c.ctx, c.parts[i], node, k)
	var us := Time.get_ticks_usec() - b0
	var id := b.id()
	var a: Array = _commit_by.get(id, [0, 0, 0])
	a[0] = int(a[0]) + us
	a[1] = maxi(int(a[1]), us)
	a[2] = int(a[2]) + 1
	_commit_by[id] = a


func _drop(c: Chunk) -> void:
	if c.task >= 0:
		WorkerThreadPool.wait_for_task_completion(c.task)
		c.task = -1
	if c.node != null:
		if c.state == COMMITTING:
			# A-28 (RINT-M3, NACH-RINT N-01): the node never entered the tree – what its committed builders registered
			# with a layer (reflectors, lamps, flares) would never hear tree_exiting: released now
			var r: Variant = services.get("renderer")
			if r is Object and is_instance_valid(r) and (r as Object).has_method(&"release_chunk"):
				(r as Object).call(&"release_chunk", c.node)
		if c.node.get_parent() != null:
			c.node.get_parent().remove_child(c.node)
		_trash.append(c.node)          # F-08: freed in pieces by _free_trash()
		_trash_age.append(0)
		c.node = null


## F-08: frees nodes of dropped chunks – the last child of the last node first, while this call has used less than
## budget_us (at least one piece); budget_us < 0: everything now.
func _free_trash(budget_us: int) -> void:
	var t0 := Time.get_ticks_usec()
	var first := true
	if budget_us >= 0:
		for i in _trash_age.size():
			_trash_age[i] += 1
	while not _trash.is_empty():
		if budget_us >= 0 and (_trash_age[0] < TRASH_DELAY or (not first and Time.get_ticks_usec() - t0 >= budget_us)):
			return
		var n: Node = _trash[0]
		if not is_instance_valid(n):
			_trash.remove_at(0)
			_trash_age.remove_at(0)
			continue
		first = false
		var k := n.get_child_count()
		if k > 0 and budget_us >= 0:
			var ch := n.get_child(k - 1)
			n.remove_child(ch)
			ch.free()
		else:
			_trash.remove_at(0)
			_trash_age.remove_at(0)
			n.free()
