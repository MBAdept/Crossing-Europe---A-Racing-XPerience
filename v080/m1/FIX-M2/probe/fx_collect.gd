extends SceneTree
## FIX-M2 probe (headless): which main-thread collects of the chunk streamer are slow, and does the props library
## load sets synchronously there? Drives a stage with the autopilot; every frame compares the streamer's collect
## count and the props library's set count. Prints "FX-COLLECT km=… collects=… collect_ms_max=… new_sets=[…] wall=…"
## for every frame with a new collect or a new library set.
##   godot --headless --path . -s <this> -- --graphics=modern --gfx-preset=medium --stage=kiel_hamburg --from=kiel
##       --start-km=50 --quit-km=92 [--timescale=4]

const RACE := "res://scenes/race/race.tscn"

var _sc: Node
var _a := {}
var _done := false
var _last_sets := -1
var _last_collects := -1
var _known := {}
var _t_prev := 0
var _last_sum := 0


func _initialize() -> void:
	_a = CliArgs.all()
	root.get_node("Settings").call("disarm_crash_guard")
	var ts := float(_a.get("timescale", 4.0))
	var setup := {"mode": "single", "race_id": "", "stage_id": str(_a.get("stage", "kiel_hamburg")),
		"from_city": str(_a.get("from", "kiel")), "vehicle": "limousine", "start_world_minutes": 720.0, "weather": "normal",
		"start_km": float(_a.get("start-km", 0.0)), "autopilot": true, "autopilot_refuel": "never", "no_countdown": true,
		"seed": 11, "gfx": "modern", "start_speed_kmh": 120.0}
	Engine.time_scale = ts
	Engine.physics_ticks_per_second = maxi(1, int(round(60.0 * ts)))
	Engine.max_physics_steps_per_frame = clampi(int(ceil(ts)) * 2, 8, 128)
	_sc = (load(RACE) as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)


func _process(_d: float) -> bool:
	if _done:
		return true
	var now := Time.get_ticks_usec()
	var frame_ms := float(now - _t_prev) / 1000.0
	_t_prev = now
	if not bool(_sc.call("is_live")):
		return false
	var r: Node = _sc.get("renderer")
	var st: Object = r.get("streamer")
	var pb: Object = r.call("builder", "props")
	var lib: Object = pb.get("library") if pb != null else null
	var stats: Dictionary = st.call("stats")
	var sets: Dictionary = lib.get("sets") if lib != null else {}
	var view: Dictionary = r.get("view")
	var km := float(view.get("camera_z", 0.0)) / 1000.0
	if _last_sets < 0:
		_last_sets = sets.size()
		_last_collects = int(st.get("_collects"))
		_last_sum = int(st.get("_collect_us_sum"))
		for k: Variant in sets:
			_known[k] = true
		var pf: Dictionary = r.call("perf_stats")
		print("FX-START km=%.2f sets=%d prepare_ms=%s prewarm_ms=%s" % [km, sets.size(), str(pf.get("prepare_ms", "?")), str(pf.get("prewarm_ms", "?"))])
	var new_sets: Array = []
	if sets.size() != _last_sets:
		for k: Variant in sets:
			if not _known.has(k):
				new_sets.append(str(k))
				_known[k] = true
		_last_sets = sets.size()
	var collects := int(st.get("_collects"))
	var sum := int(st.get("_collect_us_sum"))
	if not new_sets.is_empty() or collects != _last_collects:
		print("FX-COLLECT km=%.3f n=%d this_ms=%.2f collect_ms_max=%.1f frame_ms=%.1f new_sets=%s" % [km, collects - _last_collects,
			float(sum - _last_sum) / 1000.0, float(stats.get("collect_ms_max", 0.0)), frame_ms, JSON.stringify(new_sets)])
		_last_collects = collects
		_last_sum = sum
	if km >= float(_a.get("quit-km", 92.0)):
		_done = true
		print("FX-END ", JSON.stringify(stats))
		print("FX-PERF ", JSON.stringify(r.call("perf_stats")).left(2000))
		quit(0)
	return false
