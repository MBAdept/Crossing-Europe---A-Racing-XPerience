import sys
wt = sys.argv[1]
p = wt + '/scripts/race3d/modern_renderer.gd'
s = open(p, encoding='utf-8').read()
pairs = [
('''var _render_us := 0
var _render_us_max := 0
''', '''var _render_us := 0
var _render_us_max := 0
## FIX1 (QA QB-10): GDScript time of every part of render() – environment, streamer, camera and each hook with
## update() – so that a spike of the Leistungstest can be put down to a layer or builder (perf_stats() "hooks_ms_avg",
## "hooks_ms_max"). Index 0..2 = env, streamer, camera; then _updaters in order.
var _part_ids: Array[String] = []
var _part_us_sum := PackedInt64Array()
var _part_us_max := PackedInt64Array()
var _part_frames := 0
'''),
('''	for h: Object in _hooks:
		if h != _environment and h.has_method(&"update"):
			_updaters.append(h)
		if h.has_method(&"rebased"):
			_rebase_listeners.append(h)''', '''	for h: Object in _hooks:
		if h != _environment and h.has_method(&"update"):
			_updaters.append(h)
		if h.has_method(&"rebased"):
			_rebase_listeners.append(h)
	_part_ids = ["environment", "streamer", "camera"]
	for h: Object in _updaters:
		var sc: Variant = h.get_script()
		_part_ids.append(str((sc as Script).resource_path).get_file().get_basename() if sc is Script else str(h))
	_part_us_sum.resize(_part_ids.size())
	_part_us_sum.fill(0)
	_part_us_max.resize(_part_ids.size())
	_part_us_max.fill(0)
	_part_frames = 0'''),
('''func _draw_world(dt: float) -> void:
	if _env_updates:
		_environment.call(&"update", view, dt)
	streamer.update(float(view.get("camera_z", 0.0)), visibility_m)''', '''func _draw_world(dt: float) -> void:
	var t := Time.get_ticks_usec()
	if _env_updates:
		_environment.call(&"update", view, dt)
	t = _part_time(0, t)
	streamer.update(float(view.get("camera_z", 0.0)), visibility_m)
	t = _part_time(1, t)'''),
('''	camera.set_frustum(float(_cam_fr["size"]), _cam_fr["offset"], float(_cam_fr["near"]), float(_cam_fr["far"]))
	for l: Object in _updaters:
		l.call(&"update", view, dt)
	if _stage == Stage.WARMUP:''', '''	camera.set_frustum(float(_cam_fr["size"]), _cam_fr["offset"], float(_cam_fr["near"]), float(_cam_fr["far"]))
	t = _part_time(2, t)
	for i in _updaters.size():
		(_updaters[i] as Object).call(&"update", view, dt)
		t = _part_time(3 + i, t)
	if _prepared:
		_part_frames += 1
	if _stage == Stage.WARMUP:'''),
('''## The warm-up nodes stand on the road in front of the camera, turned like a vehicle ahead.''', '''## Adds the time since t0 to part i (only once the stage is prepared: the preparation's frames are counted in "load");
## returns the time now.
func _part_time(i: int, t0: int) -> int:
	var now := Time.get_ticks_usec()
	if _prepared and i < _part_us_sum.size():
		var us := now - t0
		_part_us_sum[i] += us
		if us > _part_us_max[i]:
			_part_us_max[i] = us
	return now


## The warm-up nodes stand on the road in front of the camera, turned like a vehicle ahead.'''),
('''		"quality_lowered": _lowered, "streamer": st, "load": _load_stats}''', '''		"quality_lowered": _lowered, "streamer": st, "load": _load_stats}
	var hooks_avg := {}
	var hooks_max := {}
	for i in _part_ids.size():
		hooks_avg[_part_ids[i]] = snappedf(float(_part_us_sum[i]) / maxf(1.0, float(_part_frames)) / 1000.0, 0.0001)
		hooks_max[_part_ids[i]] = snappedf(float(_part_us_max[i]) / 1000.0, 0.001)
	out["hooks_ms_avg"] = hooks_avg
	out["hooks_ms_max"] = hooks_max'''),
]
for old, new in pairs:
    assert s.count(old) == 1, old[:80]
    s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)

p = wt + '/scripts/race3d/benchmark.gd'
s = open(p, encoding='utf-8').read()
old = '''		"video_mem_mb": snappedf(_avg("video_mem") / 1048576.0, 0.1),
	}'''
new = '''		"video_mem_mb": snappedf(_avg("video_mem") / 1048576.0, 0.1),
		# FIX1 (QA QB-10): the longest render() of the scene and which part of the renderer carried each longest time
		"script_ms_max": snappedf(float(p1.get("render_ms_max", 0.0)), 0.01),
		"hooks_ms_max": p1.get("hooks_ms_max", {}),
	}'''
assert s.count(old) == 1
s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)
print('ok')
