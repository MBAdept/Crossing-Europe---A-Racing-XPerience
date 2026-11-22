import sys
p = sys.argv[1]
s = open(p).read()


def rep(old, new):
    global s
    assert old in s, old[:80]
    s = s.replace(old, new, 1)


rep('''	var ahead := int(_ahead_m() / seg_len)
	path.ensure(cam_seg + ahead)
''', '''	var ahead := int(_ahead_m() / seg_len)
	var tu := Time.get_ticks_usec()
	path.ensure(cam_seg + ahead)
''')
rep('''	if path.origin_distance(cam_seg) > rebase_m:
		_rebase(cam_seg)
	var moved := cam_seg != _last_cam_seg or absf(visibility_m - _last_vis) > 0.5
	if moved:
		_last_cam_seg = cam_seg
		_last_vis = visibility_m
		_free_behind(cam_z)
		_wanted = _compute_wanted(cam_z, cam_seg, visibility_m)
		_trim(cam_seg)
''', '''	if path.origin_distance(cam_seg) > rebase_m:
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
''')
rep('''		if _collect(ci, threaded):
			collected = true
			if not at_once:
				break
	if at_once:
''', '''		if _collect(ci, threaded):
			collected = true
			if not at_once:
				break
	tu = _part_us("collect", tu)
	if at_once:
''')
rep('''	_commit_us_max = maxi(_commit_us_max, _frame_commit_us)
''', '''	_commit_us_max = maxi(_commit_us_max, _frame_commit_us)
	_part_us("commit", tu)


## FIX-RINT (QA-RINT-BILD F-08): the longest time of each part of update() – "path" (generation, rebase), "free"
## (chunks behind the camera), "wanted", "collect", "commit" (with the builds finished on the main thread) – for
## stats()["update_ms_max"]: the streamer's hitches of up to 17 ms (Kiel – Hamburg, Deck) name their part.
func _part_us(part: String, t0: int) -> int:
	var now := Time.get_ticks_usec()
	_update_us_max[part] = maxi(int(_update_us_max.get(part, 0)), now - t0)
	return now
''')
rep('''var _commit_by: Dictionary = {}
''', '''var _commit_by: Dictionary = {}
var _update_us_max: Dictionary = {}  ## FIX-RINT (F-08): part of update() -> longest µs
''')
rep('''		"collect_by": _collect_by_ms(), "commit_by": _by_ms(_commit_by)}''', '''		"collect_by": _collect_by_ms(), "commit_by": _by_ms(_commit_by), "update_ms_max": _update_ms_max()}


func _update_ms_max() -> Dictionary:
	var out := {}
	for k: Variant in _update_us_max:
		out[str(k)] = snappedf(float(_update_us_max[k]) / 1000.0, 0.001)
	return out''')
rep('''	_commit_by.clear()
''', '''	_commit_by.clear()
	_update_us_max.clear()
''')
open(p, 'w').write(s)
print("ok")
