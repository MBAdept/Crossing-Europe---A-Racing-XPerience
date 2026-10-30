extends SceneTree
## End-to-end run of a complete race through the real GameFlow: race selection -> vehicle ->
## start time -> (route choices) -> stage screen -> stage driven by the autopilot -> result ->
## ... -> ferry -> race result. Prints one line per leg and checks the race rules on the way
## (next stage starts time.stage_pause_hours after the previous one ended; race time = sum of legs).
##   godot --headless --path . -s res://tests/race/run_race.gd -- --race=kiel_nuernberg --autopilot \
##       --no-countdown [--pick=0|1] [--vehicle=limousine] [--hour=8] [--timescale=40] [--max-legs=60]
## Exit code 0 = race result reached and all checks passed.
## Note: autoload classes are accessed untyped (this script compiles before the autoloads exist).

var _gf: Node
var _ui_data: GDScript
var _state := "start"
var _wall0 := 0
var _max_wall := 3000.0
var _pick := 0
var _legs_done := 0
var _max_legs := 60
var _last_result: Variant = null
var _sum_time := 0.0
var _prev_end_min := -1.0
var _errors: Array[String] = []
var _pause_h := 12.0


func _initialize() -> void:
	var args := CliArgs.all()
	var ts := clampf(float(args.get("timescale", 40.0)), 1.0, 120.0)
	Engine.time_scale = ts
	Engine.physics_ticks_per_second = maxi(60, int(round(60.0 * ts)))
	_pick = int(args.get("pick", 0))
	_max_legs = int(args.get("max-legs", 60))
	_max_wall = float(args.get("max-seconds", 3000.0))
	_pause_h = float(ConfigLoader.lookup(ConfigLoader.load_merged(), "time.stage_pause_hours", 12.0))
	_ui_data = load("res://scripts/ui/ui_data.gd")
	_wall0 = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	if (Time.get_ticks_msec() - _wall0) / 1000.0 > _max_wall:
		print("FEHLER: Zeitlimit überschritten im Zustand ", _state)
		quit(1)
		return true
	if _gf == null:
		_gf = root.get_node_or_null("/root/GameFlow")
		return false
	var args := CliArgs.all()
	match _state:
		"start":
			_gf.call("new_race")
			_gf.call("select_race", str(args.get("race", "kiel_nuernberg")))
			_gf.call("select_vehicle", str(args.get("vehicle", "limousine")))
			_gf.call("select_start_time", float(args.get("hour", 8.0)))
			print("RENNEN ", _gf.get("race").get("race_id"), " Fahrzeug ", _gf.get("race").get("vehicle"))
			_state = "flow"
		"flow":
			_flow_step()
		"racing":
			var r: Variant = _gf.get("last_result")
			if r != null and not is_same(r, _last_result) and _gf.call("current_screen_name") == "result":
				_last_result = r
				_on_leg_result(r)
				_state = "flow"
	return false


func _flow_step() -> void:
	var scr := str(_gf.call("current_screen_name"))
	var race: Object = _gf.get("race")
	match scr:
		"route_choice":
			var opts: Array = _ui_data.call("next_options", race.get("race_id"), race.get("current_city"), race.get("waypoint_index"), race.call("visited"))
			var names := []
			for o in opts:
				names.append("%s→%s (%.0f km)" % [o["from"], o["to"], float(o.get("length_km", 0.0))])
			var choice: Dictionary = opts[mini(_pick, opts.size() - 1)]
			print("  ROUTENWAHL in ", race.get("current_city"), ": ", ", ".join(names), "  -> ", choice["to"])
			_gf.call("choose_leg", choice)
		"stage_screen":
			var setup: Dictionary = _gf.call("stage_setup")
			var start_min := float(setup["start_world_minutes"])
			if _prev_end_min >= 0.0 and absf(start_min - (_prev_end_min + _pause_h * 60.0)) > 0.01:
				_errors.append("Etappe %s startet %.1f min statt Ende + %.0f h" % [setup["stage_id"], start_min, _pause_h])
			_gf.call("start_pending_stage")
			_state = "racing"
		"ferry":
			var leg: Dictionary = _gf.get("pending_leg")
			var before := float(race.get("total_time_s"))
			_gf.call("ferry_done")
			var after := float(race.get("total_time_s"))
			print("  FÄHRE %s→%s  +%.0f s  (Rennzeit %s)" % [leg["from"], leg["to"], after - before, Units.format_race_time(after)])
			_sum_time += after - before
			_prev_end_min = float(race.get("world_minutes")) - _pause_h * 60.0
		"race_result":
			var total := float(race.get("total_time_s"))
			if absf(total - _sum_time) > 0.05:
				_errors.append("Rennzeit %.2f ≠ Summe der Etappen %.2f" % [total, _sum_time])
			print("RENNERGEBNIS  Etappen %d  Zeit %s  Route %s" % [_legs_done, Units.format_race_time(total), " – ".join(race.get("route"))])
			for e in _errors:
				print("FEHLER: ", e)
			print("RACE-RUN ", "OK" if _errors.is_empty() else "FEHLER", "  wall %.0f s" % ((Time.get_ticks_msec() - _wall0) / 1000.0))
			_gf.call("finish_race")
			quit(0 if _errors.is_empty() else 1)
		"result":
			_gf.call("result_continue")
		_:
			pass


func _on_leg_result(r: Dictionary) -> void:
	_legs_done += 1
	_sum_time += float(r["time_s"])
	_prev_end_min = float(r["end_world_minutes"])
	print("  ETAPPE %2d %-28s %s  Ø %3.0f km/h  %-6s Start %s  Koll %d  Tank %d  Blitz %d  Stopp %d  Abschl %d" % [_legs_done, str(r["stage_name"]),
		Units.format_race_time(float(r["time_s"])), float(r["avg_speed_kmh"]), str(r["weather"]),
		Units.format_clock(float(r["start_world_minutes"])), int(r["collisions"]), int(r["refuels"]), int(r["radar_flashes"]),
		int(r["police_stops"]), int(r["tow_events"])])
	if _legs_done >= _max_legs:
		print("FEHLER: zu viele Etappen")
		quit(1)
