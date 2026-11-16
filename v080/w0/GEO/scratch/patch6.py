root = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-4/'
p = root + 'scripts/race3d/chunk_streamer.gd'
s = open(p).read()

# --- keep the path integrated far enough every frame (no generation bursts when a chunk is collected) ------------
a = '''	if not path.is_ready() or path.track != track or cam_seg > path.last() \\
			or (cam_seg < path.first and track.get_segment(cam_seg).index == cam_seg):
		_restart(cam_z, cam_seg)
	path.ensure(cam_seg + int(landmark_path_m / seg_len))
	if path.last() < cam_seg:
		# the road between the old path and the camera is gone from the track window (a jump ahead)
		_restart(cam_z, cam_seg)
		path.ensure(cam_seg + int(landmark_path_m / seg_len))
'''
b = '''	if not path.is_ready() or path.track != track or cam_seg > path.last() \\
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
'''
assert a in s
s = s.replace(a, b)

a = '''	var at_once := sync or not _loaded
	# collect: everything at once at load / in sync mode, else one chunk per update
	for ci: int in _wanted:
		if _chunks.has(ci):
			continue
		if not _make_room(ci, cam_seg):
			break
		if _collect(ci, threaded) and not at_once:
			break
	if at_once:
		flush()
		_loaded = true
		return
'''
b = '''	var at_once := sync or not _loaded
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
'''
assert a in s
s = s.replace(a, b)

a = '''## The chunk indices wanted for a camera position (what update() computes; no side effects besides extending the path).
func wanted_for(cam_z: float, visibility_m: float) -> Array[int]:
	var cam_seg := clampi(int(floor(cam_z / track.seg_len)), 0, track.segment_count - 1)
	path.ensure(cam_seg + int(landmark_path_m / track.seg_len))
	return _compute_wanted(cam_z, cam_seg, visibility_m)
'''
b = '''## The chunk indices wanted for a camera position (what update() computes; no side effects besides extending the path).
func wanted_for(cam_z: float, visibility_m: float) -> Array[int]:
	var cam_seg := clampi(int(floor(cam_z / track.seg_len)), 0, track.segment_count - 1)
	path.ensure(cam_seg + int(landmark_path_m / track.seg_len))
	return _compute_wanted(cam_z, cam_seg, visibility_m)


## How far ahead of the camera (m of path) the path is kept integrated: the farthest row a chunk can have when it
## is collected plus what clearance() looks at beyond it – at least landmark_path_m.
func _ahead_m() -> float:
	return maxf(landmark_path_m, load_path_m + float(chunk_segments) * track.seg_len + path.clear_reach_m)
'''
assert a in s
s = s.replace(a, b)

# --- collect statistics ------------------------------------------------------------------------------------------
a = '''var _collect_us_max := 0
'''
b = '''var _collect_us_max := 0
var _collect_us_sum := 0
var _collects := 0
'''
assert a in s
s = s.replace(a, b)
a = '''	_collect_us_max = maxi(_collect_us_max, Time.get_ticks_usec() - t0)
'''
b = '''	var us := Time.get_ticks_usec() - t0
	_collect_us_max = maxi(_collect_us_max, us)
	_collect_us_sum += us
	_collects += 1
'''
assert a in s
s = s.replace(a, b)
a = '''		"collect_ms_max": float(_collect_us_max) / 1000.0, "commit_ms_max": float(_commit_us_max) / 1000.0,
		"commits": _commits, "rebases": _rebases, "restarts": _restarts}
'''
b = '''		"collect_ms_avg": float(_collect_us_sum) / maxf(1.0, float(_collects)) / 1000.0, "collect_ms_max": float(_collect_us_max) / 1000.0,
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
'''
assert a in s
s = s.replace(a, b)
a = '''var _commit_us_max := 0
'''
b = '''var _commit_us_max := 0
var _commit_us_sum := 0
'''
assert a in s
s = s.replace(a, b)
a = '''	_commits += 1
	_commit_us_max = maxi(_commit_us_max, Time.get_ticks_usec() - t0)
'''
b = '''	_commits += 1
	var us := Time.get_ticks_usec() - t0
	_commit_us_max = maxi(_commit_us_max, us)
	_commit_us_sum += us
'''
assert a in s
s = s.replace(a, b)
a = '''## Timing and counters for perf_stats(): chunks, pending, builds, build_ms_avg, build_ms_max, collect_ms_max,
## commit_ms_max, commits, rebases, restarts.'''
b = '''## Timing and counters for perf_stats(): chunks, pending, builds, build_ms_avg / _max (ChunkBuilder.build of all
## builders per chunk), collect_ms_avg / _max (snapshot on the main thread), commit_ms_avg / _max, commits, rebases,
## restarts.'''
assert a in s
s = s.replace(a, b)
a = '''	# signs are inserted into segments that were generated earlier: the road must be generated generation_lead_m
	# beyond the chunk before its sprites are copied (clearance() below reaches much farther anyway)
	path.ensure(b + int(track.generation_lead_m() / track.seg_len) + 2)
'''
b = '''	# signs are inserted into segments that were generated earlier: the road must be generated generation_lead_m
	# beyond the chunk before its sprites are copied (update() keeps the path much farther ahead anyway)
	path.ensure(b + int(track.generation_lead_m() / track.seg_len) + 2)
'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)
print('patched')
