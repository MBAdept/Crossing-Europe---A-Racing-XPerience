extends SceneTree
## Headless integration run: drives a whole stage with the autopilot as fast as possible and prints
## the result JSON plus frame-time statistics.
##   godot --headless --path . -s res://tests/race/run_stage.gd -- --stage=dev_testetappe \
##       [--from=<city>] [--vehicle=limousine] [--hour=8] [--weather=normal] [--timescale=40] \
##       [--start-km=0] [--max-seconds=900] [--autopilot-speeding] [--autopilot-refuel=auto|always|never]
## Output lines: "ERGEBNIS {...}" (stage_finished result), "PERF {...}" (render/simulation timing),
## "RUN {...}" (wall clock, simulated seconds). Exit code 0 = finished, 1 = aborted/timeout.
## Every simulation step keeps dt = 1/60 s (physics ticks scaled with the time scale), so the run is
## as deterministic as a real-time drive.

var _scene: Node
var _wall0 := 0
var _max_wall := 900.0
var _done := false
var _last_report := 0


func _initialize() -> void:
	var args := CliArgs.all()
	var c := ConfigLoader.load_merged()
	var ts := clampf(float(args.get("timescale", 40.0)), 0.1, 200.0)
	_max_wall = float(args.get("max-seconds", 900.0))
	var setup := {
		"mode": "single",
		"race_id": "",
		"stage_id": str(args.get("stage", "dev_testetappe")),
		"from_city": str(args.get("from", "")),
		"vehicle": str(args.get("vehicle", ConfigLoader.lookup(c, "vehicles.default", "limousine"))),
		"start_world_minutes": float(args.get("hour", 8.0)) * 60.0,
		"weather": str(args.get("weather", "normal")),
		"start_km": float(args.get("start-km", 0.0)),
		"autopilot": true,
		"autopilot_speeding": args.has("autopilot-speeding"),
		"autopilot_refuel": str(args.get("autopilot-refuel", "auto")),
		"no_countdown": true,
		"seed": int(args.get("seed", 0)),
	}
	Engine.time_scale = ts
	Engine.physics_ticks_per_second = maxi(1, int(round(60.0 * ts)))
	Engine.max_physics_steps_per_frame = clampi(int(ceil(ts)) * 2, 8, 128)
	_scene = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	_scene.set("setup", setup)
	_scene.connect("stage_finished", _on_finished)
	_scene.connect("stage_aborted", _on_aborted)
	root.add_child(_scene)
	_wall0 = Time.get_ticks_msec()
	print("RUN-START ", JSON.stringify(setup), " timescale=", ts)


func _process(_delta: float) -> bool:
	if _done:
		return true
	var wall := float(Time.get_ticks_msec() - _wall0) / 1000.0
	if int(wall) >= _last_report + 10:
		_last_report = int(wall)
		print("... km %.1f  t %.1f s  speed %.0f km/h" % [float(_scene.get("pos_km")), float(_scene.call("total_time")), float((_scene.get("vehicle") as VehicleModel).speed)])
	if wall > _max_wall:
		print("FEHLER: Zeitlimit überschritten bei km %.2f" % float(_scene.get("pos_km")))
		_report(false)
		quit(1)
		return true
	return false


func _on_finished(result: Dictionary) -> void:
	print("ERGEBNIS ", JSON.stringify(result))
	_report(true)
	_done = true
	quit(0)


func _on_aborted(reason: String) -> void:
	print("FEHLER: Etappe abgebrochen: ", reason)
	_done = true
	quit(1)


func _report(ok: bool) -> void:
	var perf: Dictionary = _scene.call("perf_stats")
	print("PERF ", JSON.stringify(perf))
	var wall := float(Time.get_ticks_msec() - _wall0) / 1000.0
	var sim := float(_scene.get("stage_time"))
	print("RUN ", JSON.stringify({"ok": ok, "wall_s": wall, "sim_s": sim, "speedup": sim / maxf(0.001, wall),
		"collisions": (_scene.get("stats") as Dictionary).get("collisions", 0)}))
