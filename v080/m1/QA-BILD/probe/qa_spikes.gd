extends SceneTree
## QA-BILD probe: which hook of the Modern renderer causes the long render() frames? Wraps every entry of the
## renderer's _updaters (layers and builders with update()) in a timing proxy (no file of the game is changed) and
## prints every frame whose render() exceeds --spike-ms with the per-hook times, plus totals per hook at the end.
##   godot --headless --path . -s <this> -- --stage=kiel_hamburg --from=kiel [--timescale=8] [--max-steps=64]
##       [--spike-ms=20] [--quit-sim=330]

class Proxy extends RefCounted:
	var real: Object
	var label := ""
	var last_us := 0
	var sum_us := 0
	var max_us := 0
	var n := 0

	func update(view: Dictionary, dt: float) -> void:
		var t0 := Time.get_ticks_usec()
		real.call(&"update", view, dt)
		last_us = Time.get_ticks_usec() - t0
		sum_us += last_us
		max_us = maxi(max_us, last_us)
		n += 1


var _scene: Node
var _args := {}
var _wrapped := false
var _proxies: Array = []
var _prev_render_us := 0
var _prev_commits := 0
var _spike_ms := 20.0
var _quit_sim := 330.0
var _frame := 0
var _wall0 := 0
var _prev_keys := {}
var _pb := 0
var _pt := 0
var _pi := 0


func _initialize() -> void:
	_args = CliArgs.all()
	_spike_ms = float(_args.get("spike-ms", 20.0))
	_quit_sim = float(_args.get("quit-sim", 330.0))
	var ts := float(_args.get("timescale", 8.0))
	var setup := {"mode": "single", "race_id": "", "stage_id": str(_args.get("stage", "kiel_hamburg")),
		"from_city": str(_args.get("from", "kiel")), "vehicle": str(_args.get("vehicle", "limousine")),
		"start_world_minutes": float(_args.get("hour", 12.0)) * 60.0, "weather": str(_args.get("weather", "normal")), "start_km": float(_args.get("start-km", 0.0)), "autopilot": true, "autopilot_refuel": "auto",
		"no_countdown": true, "seed": int(_args.get("seed", 11)), "gfx": "modern"}
	Engine.time_scale = ts
	Engine.physics_ticks_per_second = maxi(1, int(round(60.0 * ts)))
	Engine.max_physics_steps_per_frame = int(_args.get("max-steps", 64))
	root.get_node("Settings").call("disarm_crash_guard")
	_scene = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	_scene.set("setup", setup)
	_scene.connect("stage_finished", func(_r: Dictionary) -> void: _end("finished"))
	root.add_child(_scene)
	_wall0 = Time.get_ticks_msec()


func _wrap(r: Object) -> void:
	var ups: Variant = r.get("_updaters")
	if not (ups is Array):
		print("QA-SPIKES no _updaters")
		_wrapped = true
		return
	var arr: Array = ups
	for i in arr.size():
		var p := Proxy.new()
		p.real = arr[i]
		var scr: Variant = (arr[i] as Object).get_script()
		p.label = (scr as Script).resource_path.get_file() if scr is Script else str(arr[i])
		arr[i] = p
		_proxies.append(p)
	_wrapped = true
	print("QA-SPIKES wrapped: ", ", ".join(_proxies.map(func(p: Proxy) -> String: return p.label)))


func _process(_d: float) -> bool:
	var r: Variant = _scene.get("renderer")
	if not (r is Object) or not bool(_scene.call("is_live")):
		return false
	var ro := r as Object
	if not _wrapped:
		_wrap(ro)
		_prev_render_us = int(ro.get("_render_us"))
		return false
	var ru := int(ro.get("_render_us"))
	var rms := float(ru - _prev_render_us) / 1000.0
	_prev_render_us = ru
	var st: Dictionary = (ro.get("streamer") as Object).call("stats")
	var c := int(st.get("commits", 0))
	var commit := c - _prev_commits
	_prev_commits = c
	_frame += 1
	var vl: Variant = ro.call("layer", "vehicles")
	var cur := {}
	if vl is Object and (vl as Object).has_method("snapshot"):
		var sn: Dictionary = (vl as Object).call("snapshot")
		for v: Dictionary in sn.get("vehicles", []):
			cur[str(v.get("set", "")) + "|" + str(v.get("lod", "")) + "|" + str(v.get("standin", ""))] = true
	var pf: Dictionary = (vl as Object).call("perf") if vl is Object and (vl as Object).has_method("perf") else {}
	var b := int(pf.get("vehicle_builds", -1))
	var tr := int(pf.get("vehicle_trims", -1))
	var inst := int(pf.get("vehicle_instances", -1))
	if rms > _spike_ms:
		var newk := []
		for k: String in cur.keys():
			if not _prev_keys.has(k):
				newk.append(k)
		print("QA-SPIKE-VEH new set|lod|standin: ", newk, " builds %d (+%d) trims %d (+%d) instances %d -> %d vehicles %d" % [
			b, b - _pb, tr, tr - _pt, _pi, inst, cur.size()])
	_prev_keys = cur
	_pb = b
	_pt = tr
	_pi = inst
	if rms > _spike_ms:
		var parts := []
		var acc := 0.0
		for p: Proxy in _proxies:
			acc += float(p.last_us) / 1000.0
			if p.last_us > 1000:
				parts.append("%s %.1f" % [p.label, float(p.last_us) / 1000.0])
		print("QA-SPIKE frame=%d render=%.1f ms hooks=%.1f ms (rest = env+streamer+camera %.1f ms) commit=%d km=%.2f :: %s" % [
			_frame, rms, acc, rms - acc, commit, float(_scene.get("pos_km")), ", ".join(parts)])
	if float(_scene.get("stage_time")) >= _quit_sim:
		_end("quit")
		return true
	return false


func _end(why: String) -> void:
	for p: Proxy in _proxies:
		print("QA-HOOK %-22s n %6d  avg %.3f ms  max %.1f ms" % [p.label, p.n, float(p.sum_us) / maxf(1.0, float(p.n)) / 1000.0, float(p.max_us) / 1000.0])
	var ps: Dictionary = (_scene.get("renderer") as Object).call("perf_stats")
	print("QA-END ", why, " frames=", _frame, " wall_s=", (Time.get_ticks_msec() - _wall0) / 1000.0, " render_ms_avg=", ps.get("render_ms_avg"),
		" render_ms_max=", ps.get("render_ms_max"), " vehicle_us_max=", ps.get("vehicle_us_max"), " commit_ms_max=", ps.get("chunk_commit_ms_max"))
	quit(0)
