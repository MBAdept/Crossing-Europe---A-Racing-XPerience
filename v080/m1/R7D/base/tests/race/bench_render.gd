extends SceneTree
## Render benchmark: freezes the race scene at several stage positions and redraws the same view
## many times; prints median / min / p90 of RoadRenderer._draw (GDScript CPU time, ms).
##   godot --headless --path . -s res://tests/race/bench_render.gd -- [--stage=dev_testetappe] \
##       [--kms=5,30,50.5,79,112] [--hour=12] [--weather=normal] [--frames=120]
## Headless the rendering server is a dummy, so this measures exactly the work the race module adds.
## (No typed references to race classes here: -s scripts compile before autoloads exist.)

var _scene: Node
var _kms: Array[float] = []
var _idx := 0
var _frame := 0
var _frames := 120
var _samples: Array[int] = []
var _results: Array = []


func _initialize() -> void:
	var args := CliArgs.all()
	for part in str(args.get("kms", "5,30,50.5,79,112")).split(",", false):
		_kms.append(float(part))
	_frames = int(args.get("frames", 120))
	_start(str(args.get("stage", "dev_testetappe")), float(args.get("hour", 12.0)), str(args.get("weather", "normal")))


func _start(stage: String, hour: float, weather: String) -> void:
	var setup := {"mode": "single", "stage_id": stage, "from_city": "", "vehicle": "limousine",
		"start_world_minutes": hour * 60.0, "weather": weather, "start_km": _kms[0], "autopilot": true, "no_countdown": true}
	_scene = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	_scene.set("setup", setup)
	root.add_child(_scene)


func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 1:
		_jump(_kms[_idx])
		return false
	if _frame < 25:
		return false
	# the race scene keeps redrawing; sample the last draw time each frame
	var r: Object = _scene.get("renderer")
	var st: Dictionary = r.call("perf_stats")
	_samples.append(int(float(st["last_ms"]) * 1000.0))
	if _samples.size() >= _frames:
		_samples.sort()
		var med := float(_samples[_samples.size() / 2]) / 1000.0
		var mn := float(_samples[0]) / 1000.0
		var p90 := float(_samples[int(float(_samples.size()) * 0.9)]) / 1000.0
		print("BENCH km %6.1f  median %.2f ms  min %.2f  p90 %.2f  tris %d  cmds %d" % [_kms[_idx], med, mn, p90, int(st["triangles"]), int(st["commands"])])
		if CliArgs.has("phases"):
			print("      phases (avg since start) ", st.get("phases_avg_ms", {}))
		_results.append(med)
		_samples.clear()
		_idx += 1
		if _idx >= _kms.size():
			var total := 0.0
			for m: float in _results:
				total += m
			print("BENCH mean of medians %.2f ms" % (total / float(_results.size())))
			return true
		_jump(_kms[_idx])
		_frame = 2
	return false


## Freezes the simulation at km (car rolling at 160 km/h for the view, no physics steps).
func _jump(km: float) -> void:
	_scene.set_physics_process(false)
	var track: Object = _scene.get("track")
	var z := float(track.call("km_to_z", km))
	_scene.set("pos_z", z)
	_scene.set("pos_km", km)
	track.call("update_window", z - 8.0, 960.0)
	var veh: Object = _scene.get("vehicle")
	veh.set("speed", 160.0)
	_scene.set("running", true)
