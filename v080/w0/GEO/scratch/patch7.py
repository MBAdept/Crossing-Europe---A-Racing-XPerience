root = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-4/'
p = root + 'scripts/race3d/chunk_streamer.gd'
s = open(p).read()

i0 = s.index("func _compute_wanted(cam_z: float, cam_seg: int, vis: float) -> Array[int]:")
i1 = s.index("## Collects chunk ci on the main thread.")
new = '''## The chunks the load rule wants, most important first: the chunk under the camera and those behind it, then by
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


'''
s = s[:i0] + new + s[i1:]
a = '''##  * a chunk is wanted when its near edge is at most load_path_m of path ahead AND at most
##    visibility + one chunk length away by air; at most max_chunks are held (nearest first); a chunk is freed
##    once its far edge lies more than keep_behind_m behind the camera,'''
b = '''##  * a chunk is wanted when its near edge is at most load_path_m of path ahead AND at most
##    visibility + one chunk length away by air; at most max_chunks are held (when the rule wants more, the
##    farthest by air – in the fog at the end of the visibility – wait); a chunk is freed once its far edge lies
##    more than keep_behind_m behind the camera,'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)

p = root + 'tests/race3d/fairness.gd'
s = open(p).read()
i0 = s.index("	# chunks the streamer's load rule wants along the stage (camera every chunk length), without the cap")
i1 = s.index('	return {"name": geo["name"], "sides": sides, "free": free, "min_clear_m": min_clear, "chunks_max": chunks_max,')
new = '''	# chunks the streamer's load rule wants along the stage (camera every chunk length): without the cap, and what
	# the cap of max_chunks leaves out
	var st := ChunkStreamer.new()
	st.setup(path, null, geo["track"], cfg, {}, true)
	var chunks_max := 0
	var cap_hits := 0
	var cap_nearest := INF
	var positions := 0
	var cam := 0
	while cam < n - 2:
		positions += 1
		var cam_z := float(cam) * seg
		st.max_chunks = 1000
		var wanted := st.wanted_for(cam_z, vis)
		chunks_max = maxi(chunks_max, wanted.size())
		if wanted.size() > max_chunks:
			cap_hits += 1
			st.max_chunks = max_chunks
			var kept := st.wanted_for(cam_z, vis)
			var cp := path.centre_at(cam_z)
			for ci: int in wanted:
				if kept.has(ci):
					continue
				var a := ci * chunk_n
				var b := mini(a + chunk_n, n - 1)
				for row: int in [a, (a + b) / 2, b]:
					var p := path.point(row)
					cap_nearest = minf(cap_nearest, Vector2(p.x - cp.x, p.z - cp.z).length())
		cam += chunk_n
	st.free()
'''
s = s[:i0] + new + s[i1:]
a = '''## cap_nearest_m (nearest distance by air of a chunk left out by the cap; INF = none)}.'''
b = '''## cap_nearest_m (nearest distance by air of a chunk the streamer leaves out because of the cap; INF = none)}.'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)
print('patched')
