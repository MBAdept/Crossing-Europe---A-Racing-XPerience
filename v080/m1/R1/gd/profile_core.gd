extends SceneTree
## Scratch: where does the GDScript time of ModernRenderer.render() go? Drives a Modern stage headless in real-time
## steps and then times every hook's update() with the last view.

var _scene: Node
var _frames := 0
var _hour := 12.0


func _initialize() -> void:
	var args := CliArgs.all()
	_hour = float(args.get("hour", 12.0))
	var setup := {"mode": "single", "race_id": "", "stage_id": str(args.get("stage", "kiel_hamburg")), "from_city": str(args.get("from", "kiel")),
		"vehicle": "limousine", "start_world_minutes": _hour * 60.0, "weather": str(args.get("weather", "normal")),
		"start_km": float(args.get("start-km", 2.0)), "autopilot": true, "autopilot_refuel": "never", "no_countdown": true, "seed": 11,
		"gfx": "modern", "start_speed_kmh": 150.0, "traffic_warmup": true}
	_scene = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	_scene.set("setup", setup)
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < int(CliArgs.all().get("frames", 1200)):
		return false
	var r: Object = _scene.get("renderer")
	var perf: Dictionary = r.call("perf_stats")
	print("PERF render_ms_avg=%.3f max=%.3f frames=%d commit_max=%.3f collect_max=%.3f build_avg=%.3f chunks=%d" % [
		float(perf["render_ms_avg"]), float(perf["render_ms_max"]), int(perf["frames"]), float(perf["chunk_commit_ms_max"]),
		float((perf["streamer"] as Dictionary).get("collect_ms_max", 0.0)), float(perf["chunk_build_ms_avg"]), int(perf["chunks"])])
	var view: Dictionary = r.get("view")
	var hooks: Array = r.get("_hooks")
	var n := 2000
	for h: Object in hooks:
		if not h.has_method(&"update"):
			continue
		var t0 := Time.get_ticks_usec()
		for i in n:
			h.call(&"update", view, 1.0 / 60.0)
		var us := float(Time.get_ticks_usec() - t0) / float(n)
		var nm := str(h.get("name")) if h is Node else str(h.call("id"))
		print("HOOK %-14s %.1f µs" % [nm, us])
	var streamer: Object = r.get("streamer")
	var t1 := Time.get_ticks_usec()
	for i in n:
		streamer.call("update", float(view["camera_z"]), 900.0)
	print("STREAMER update %.1f µs" % (float(Time.get_ticks_usec() - t1) / float(n)))
	var chase: Object = r.get("chase")
	var path: Object = r.get("path")
	t1 = Time.get_ticks_usec()
	for i in n:
		chase.call("transform", view, path)
		chase.call("frustum", Vector2(1280, 720), Vector2.ZERO)
		chase.call("look_yaw", path, float(view["camera_z"]))
	print("CAMERA %.1f µs" % (float(Time.get_ticks_usec() - t1) / float(n)))
	quit(0)
	return true
