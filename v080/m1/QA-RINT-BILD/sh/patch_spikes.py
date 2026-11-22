p = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-BILD/sh/qa_perf.gd'
s = open(p).read()
if '_track_spikes' not in s:
    s = s.replace('var _mat_iu := {}\n', 'var _mat_iu := {}\nvar _spikes: Array = []\nvar _last_hmax := {}\n', 1)
    s = s.replace('\tif wall >= _next_sample:', '\tif _inst_frame % 20 == 0 and live:\n\t\t_track_spikes()\n\tif wall >= _next_sample:', 1)
    fn = '''## Where the maxima of the renderer's hook times and of the chunk commit grow (km, wall): localises hitches.
func _track_spikes() -> void:
	var r: Variant = _scene.get("renderer")
	if r == null or not (r as Object).has_method("perf_stats"):
		return
	var p: Dictionary = (r as Object).call("perf_stats")
	var hm: Dictionary = (p.get("hooks_ms_max", {}) as Dictionary).duplicate()
	var st: Dictionary = p.get("streamer", {})
	hm["commit"] = float(st.get("commit_ms_max", 0.0))
	hm["collect"] = float(st.get("collect_ms_max", 0.0))
	for k: Variant in hm:
		var v := float(hm[k])
		if v > float(_last_hmax.get(k, 0.0)) + 0.5 and v >= 4.0:
			_spikes.append({"part": str(k), "ms": snappedf(v, 0.01), "km": snappedf(float(_scene.get("pos_km")), 0.01),
				"wall": snappedf(float(Time.get_ticks_msec() - _wall0) / 1000.0, 0.1)})
		_last_hmax[k] = maxf(v, float(_last_hmax.get(k, 0.0)))


func _scene_instances() -> int:'''
    s = s.replace('func _scene_instances() -> int:', fn, 1)
    s = s.replace('\tout["iu_samples"] = _inst_n', '\tout["iu_samples"] = _inst_n\n\tout["spikes"] = _spikes', 1)
    open(p, 'w').write(s)
print('ok', s.count('_track_spikes'))
