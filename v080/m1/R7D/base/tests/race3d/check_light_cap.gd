extends SceneTree
## Headless check of the light cap of the mode "Modern" (contract D8, §6 R4 "the light cap holds along three night
## stages"), run by tools/run_tests.sh through its hook for tests/race3d/check_*.gd:
##   godot --headless --path . -s res://tests/race3d/check_light_cap.gd [-- --only=<check>]
##   deckel   three night stages driven by the autopilot with traffic, „Effekte: Voll“ (the largest omni pool):
##            Hamburg – Hannover km 71 at 22:00 in the snow (N1), Kiel – Hamburg from km 76 at 22:30 (City Limits of
##            Hamburg, the street lights of the Köhlbrandbrücke) and Dortmund – Frankfurt from km 220 at 21:30 in the rain
##            (City Limits of Frankfurt, C1). In every sampled frame: at most 8 visible OmniLight3D and 2 visible SpotLight3D in the whole scene,
##            none of them with a shadow, exactly one DirectionalLight3D (with its shadow flag, D5), the snapshot of the
##            lights layer agrees (omni ≤ 8, spot ≤ 2, pools ≤ 22); somewhere along each stage the pool of lamps is
##            actually used (street, tunnel or canopy lamps) and the low beam is on.
## Prints "CHECK <name> OK|FEHLER …"; exit code 0 when all pass.
## (The scene and the autoloads are accessed untyped: -s scripts compile before the autoloads exist.)

const RACE := "res://scenes/race/race.tscn"
const CHECKS := ["deckel"]
const DRIVE_S := 36.0               ## game seconds per stage
const SAMPLE_EVERY := 6             ## frames between two samples
const STAGES: Array = [
	{"name": "N1 Hamburg – Hannover km 71, 22 Uhr, Schnee", "stage_id": "hamburg_hannover", "from_city": "hamburg", "start_km": 71.0,
		"hour": 22.0, "weather": "snow", "vehicle": "kompakt", "seed": 13},
	{"name": "Kiel – Hamburg ab km 76, 22:30 (Stadtgrenze Hamburg, Köhlbrandbrücke)", "stage_id": "kiel_hamburg", "from_city": "kiel",
		"start_km": 76.0, "hour": 22.5, "weather": "normal", "vehicle": "limousine", "seed": 11},
	{"name": "C1 Dortmund – Frankfurt ab km 220, 21:30, Regen (City Limits Frankfurt)", "stage_id": "dortmund_frankfurt",
		"from_city": "dortmund", "start_km": 220.0, "hour": 21.5, "weather": "rain", "vehicle": "sportwagen", "seed": 15},
]

var _failed: Array[String] = []
var _settings: Node
var _wall0 := 0


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	_settings = root.get_node("Settings")
	_settings.call("disarm_crash_guard")
	var cli := CliArgs.all()
	var cli_graphics: Variant = cli.get("graphics", null)
	cli.erase("graphics")
	var only := str(cli.get("only", ""))
	for c: String in CHECKS:
		if only == "" or only.split(",").has(c):
			await call("_check_" + c)
	_speed(1.0)
	_settings.call("disarm_crash_guard")
	if cli_graphics != null:
		cli["graphics"] = cli_graphics
	print("CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(), (Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)


func _report(check: String, problems: Array[String], msg: String) -> void:
	var ok := problems.is_empty()
	print("CHECK %-10s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems)])
	if not ok:
		_failed.append(check)


func _need(problems: Array[String], cond: bool, what: String) -> void:
	if not cond:
		problems.append(what)


func _speed(ts: float) -> void:
	Engine.time_scale = ts
	Engine.physics_ticks_per_second = maxi(1, int(round(60.0 * ts)))
	Engine.max_physics_steps_per_frame = clampi(int(ceil(ts)) * 2, 8, 128)


func _until(cond: Callable, max_frames: int = 6000) -> int:
	var n := 0
	while not bool(cond.call()) and n < max_frames:
		await process_frame
		n += 1
	return n


## Visible lights of each class under `node`: {"omni", "spot", "dir", "shadowed" (positional with a shadow),
## "dir_shadow" (directional lights with the shadow flag)}.
func _lights(node: Node, acc: Dictionary) -> void:
	if node is Light3D and (node as Light3D).is_visible_in_tree():
		if node is OmniLight3D:
			acc["omni"] += 1
		elif node is SpotLight3D:
			acc["spot"] += 1
		elif node is DirectionalLight3D:
			acc["dir"] += 1
			if (node as Light3D).shadow_enabled:
				acc["dir_shadow"] += 1
		if not (node is DirectionalLight3D) and (node as Light3D).shadow_enabled:
			acc["shadowed"] += 1
	for c: Node in node.get_children():
		_lights(c, acc)


func _check_deckel() -> void:
	var p: Array[String] = []
	var parts: Array[String] = []
	CliArgs.all()["gfx-preset"] = "high"
	_speed(4.0)
	for st: Dictionary in STAGES:
		var setup := {"mode": "single", "race_id": "", "stage_id": st["stage_id"], "from_city": st["from_city"], "vehicle": st["vehicle"],
			"start_world_minutes": float(st["hour"]) * 60.0, "weather": st["weather"], "start_km": st["start_km"], "autopilot": true,
			"autopilot_refuel": "never", "seed": st["seed"], "gfx": "modern", "no_countdown": true, "start_speed_kmh": 120.0,
			"traffic_warmup": true}
		var sc: Node = (load(RACE) as PackedScene).instantiate()
		sc.set("setup", setup)
		root.add_child(sc)
		await _until(func() -> bool: return int(sc.get("_sim_steps")) >= 3)
		var r: Variant = sc.get("renderer")
		if not (r is ModernRenderer) or not (r as ModernRenderer).healthy():
			p.append("%s: Modern-Etappe läuft" % st["name"])
			sc.queue_free()
			await process_frame
			continue
		var mr: ModernRenderer = r
		var t0 := float(mr.view.get("time", 0.0))
		var frames := 0
		var samples := 0
		var max_omni := 0
		var max_spot := 0
		var max_pools := 0
		var lamp_frames := 0
		var beam_frames := 0
		var bad: Array[String] = []
		while float(mr.view.get("time", 0.0)) - t0 < DRIVE_S and frames < 20000:
			await process_frame
			frames += 1
			if frames % SAMPLE_EVERY != 0:
				continue
			samples += 1
			var acc := {"omni": 0, "spot": 0, "dir": 0, "shadowed": 0, "dir_shadow": 0}
			_lights(sc, acc)
			var snap: Dictionary = (mr.layer("lights").call("snapshot") as Dictionary).get("lights", {})
			max_omni = maxi(max_omni, int(acc["omni"]))
			max_spot = maxi(max_spot, int(acc["spot"]))
			max_pools = maxi(max_pools, int(snap.get("pools", 0)))
			if int(snap.get("pools_lamps", 0)) > 0 or int(snap.get("omni", 0)) > 0:
				lamp_frames += 1
			if float(snap.get("beam", 0.0)) > 0.1:
				beam_frames += 1
			if int(acc["omni"]) > 8 or int(acc["spot"]) > 2 or int(acc["shadowed"]) > 0 or int(acc["dir"]) != 1 or int(acc["dir_shadow"]) != 1 \
					or int(snap.get("omni", 0)) > 8 or int(snap.get("spot", 0)) > 2 or int(snap.get("pools", 0)) > 22:
				if bad.size() < 3:
					bad.append("km %.2f: %s / Schnappschuss %s" % [float(mr.view.get("camera_z", 0.0)) / 1000.0, str(acc), str(snap)])
		_need(p, bad.is_empty(), "%s: Deckel gehalten (%s)" % [st["name"], "; ".join(bad)])
		_need(p, samples >= 20, "%s: genug Proben (%d)" % [st["name"], samples])
		_need(p, lamp_frames > 0, "%s: Lampen-Pool benutzt" % st["name"])
		_need(p, beam_frames * 2 >= samples, "%s: Abblendlicht an" % st["name"])
		parts.append("%s: %d Proben, höchstens %d Punktlichter / %d Spots / %d Kegel, Lampen in %d Proben" % [st["name"], samples, max_omni,
			max_spot, max_pools, lamp_frames])
		sc.queue_free()
		await process_frame
		await process_frame
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	CliArgs.all().erase("gfx-preset")
	_speed(1.0)
	_report("deckel", p, "„Hoch“ (Punktlicht-Pool 8): " + "; ".join(parts))
