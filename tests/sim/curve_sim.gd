extends SceneTree
## Curve-only stage simulation (driving model diagnostics): the real StagePlan/Track of a stage, no traffic,
## no radar, no fuel, no police – just the VehicleModel and a driver that holds the right lane and drives
## at full throttle, braking ahead of curves to margin * the safe curve speed (look-ahead braking curve,
## like the autopilot). Isolates what the curves cost:
##   godot --headless --path . -s res://tests/sim/curve_sim.gd -- --stage=kassel_wuerzburg
##       [--vehicle=all|<id>] [--weather=normal] [--margin=0.96] [--no-brake] [--grip=7.6,8.3,9.0,9.7,10.4]
##       [--from=<city>] [--decel=15] [--lookahead=300] [--sections] [--trace=<km from>,<km to>]
##       [--set=driving.understeer.push_gain=3,driving.shoulder.grip_factor=0.5]
## --grip overrides lat_grip of agility ratings 1..5 (e.g. the values before v0.3.1 for a comparison),
## --set overrides numeric config values (tuning), --trace prints the driving state every 0.25 s,
## --no-brake drives flat out (understeer, shoulder and guardrail show what happens without braking).
## Output: one "CURVES {...}" JSON line per vehicle (time_s, avg_kmh, off_road_s, limit_s, rail_hits,
## understeer_s, understeer_max, brake_s) and with --sections the time per curviness level.
## Owner: gameplay module (diagnostics only, no autoloads).

const DT := 1.0 / 60.0

var cfg: Dictionary
var plan: StagePlan


func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + name:
			return "1"
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return default


func _initialize() -> void:
	cfg = ConfigLoader.load_merged()
	# --set=a.b.c=1.5,d.e=2: override numeric config values (tuning experiments)
	for kv in _arg("set", "").split(",", false):
		var parts := kv.split("=")
		if parts.size() == 2:
			var keys := parts[0].split(".")
			var node: Dictionary = cfg
			for i in keys.size() - 1:
				node = node[keys[i]]
			node[keys[keys.size() - 1]] = float(parts[1])
	var grips := _arg("grip", "")
	if grips != "":
		var vals := grips.split(",")
		for i in vals.size():
			var key := str(i + 1)
			var agi: Dictionary = cfg["vehicles"]["agility_ratings"]
			if agi.has(key):
				(agi[key] as Dictionary)["lat_grip"] = float(vals[i])
	var net: Dictionary = ConfigLoader.load_json("res://data/network.json")
	var countries: Dictionary = (ConfigLoader.load_json("res://data/countries.json") as Dictionary).get("countries", {})
	var cities := {}
	for c: Dictionary in net.get("cities", []):
		cities[str(c["id"])] = c
	var stage_id := _arg("stage", "kassel_wuerzburg")
	var stage: Dictionary = {}
	for s: Dictionary in net.get("stages", []):
		if str(s["id"]) == stage_id:
			stage = s
	if stage.is_empty():
		print("Etappe nicht gefunden: ", stage_id)
		quit(1)
		return
	plan = StagePlan.build(stage, _arg("from", ""), cities, countries, cfg)
	var ids: Array = []
	var which := _arg("vehicle", "all")
	if which == "all":
		ids = ConfigLoader.lookup(cfg, "vehicles.order", ["limousine"])
	else:
		ids = [which]
	for id in ids:
		print("CURVES ", JSON.stringify(run(str(id))))
	quit(0)


## Drives the whole stage once; returns the statistics.
func run(vehicle_id: String) -> Dictionary:
	var weather := _arg("weather", "normal")
	var margin := float(_arg("margin", "0.96"))
	var decel := float(_arg("decel", "15"))
	var lookahead := float(_arg("lookahead", "300"))
	var no_brake := _arg("no-brake", "") != ""
	var trace := _arg("trace", "").split(",")
	var trace_from := float(trace[0]) if trace.size() == 2 else 0.0
	var trace_to := float(trace[1]) if trace.size() == 2 else 0.0
	var track := Track.new()
	track.setup(plan, cfg, {})
	var env := EnvironmentModel.new()
	env.setup(cfg)
	var grip := env.grip(weather)
	var vf := env.vmax_factor(12.0, weather)
	var v := VehicleModel.new()
	v.setup(cfg, vehicle_id)
	var z := 0.0
	var t := 0.0
	var st := {"vehicle": vehicle_id, "stage": plan.stage_id, "weather": weather, "off_road_s": 0.0, "limit_s": 0.0,
		"rail_hits": 0, "understeer_s": 0.0, "understeer_max": 0.0, "brake_s": 0.0, "min_kmh": INF}
	var per_level := {}
	v.x = track.lane_center_x(0.0, track.lane_count_at(0.0) - 1)
	while z < track.length_z and t < 7200.0:
		track.update_window(z - 6.6, 960.0)
		var want := 1000.0
		if not no_brake:
			want = v.safe_curve_speed(track.curve_at(z), track.grip_at(z, grip)) * margin
			var d := 10.0
			while d <= lookahead:
				var c := track.curve_at(z + d)
				if absf(c) > 0.001:
					var vt := v.safe_curve_speed(c, track.grip_at(z + d, grip)) * margin / 3.6
					want = minf(want, sqrt(vt * vt + 2.0 * decel * maxf(0.0, d - 12.0)) * 3.6)
				d += 10.0
		var tx := track.lane_center_x(z + 12.0, track.lane_count_at(z + 12.0) - 1)
		var err := tx - v.x
		var input := {"steer": 0.0 if absf(err) < 0.05 else clampf(err * 0.7, -1.0, 1.0), "throttle": 0.0, "brake": 0.0}
		if v.speed < want - 1.0:
			input["throttle"] = 1.0
		elif v.speed > want + 2.0:
			input["brake"] = clampf((v.speed - want) / 12.0, 0.3, 1.0)
		elif v.speed < want:
			input["throttle"] = 0.6
		var e := track.road_edges_at(z)
		var seg := track.segment_at(z)
		v.update(DT, input, {"curve": track.curve_at(z), "grade": track.grade_at(z), "left_edge": e.x, "right_edge": e.y,
			"shoulder_m": track.shoulder_w, "guardrail": seg.guardrail or seg.tunnel, "grip": track.grip_at(z, grip)}, {"vmax_factor": vf})
		z += v.speed / 3.6 * DT
		t += DT
		if v.off_road > 0:
			st["off_road_s"] = float(st["off_road_s"]) + DT
		if v.off_road > 1:
			st["limit_s"] = float(st["limit_s"]) + DT
		if v.rail_hit:
			st["rail_hits"] = int(st["rail_hits"]) + 1
		if v.understeer > 0.0:
			st["understeer_s"] = float(st["understeer_s"]) + DT
		st["understeer_max"] = maxf(float(st["understeer_max"]), v.understeer)
		if float(input["brake"]) > 0.0:
			st["brake_s"] = float(st["brake_s"]) + DT
		if t > 20.0:
			st["min_kmh"] = minf(float(st["min_kmh"]), v.speed)
		var lvl := str(int(plan.section_at(track.z_to_km(z)).get("curviness", 0)))
		per_level[lvl] = float(per_level.get(lvl, 0.0)) + DT
		if trace_to > trace_from and track.z_to_km(z) >= trace_from and track.z_to_km(z) <= trace_to and fmod(t, 0.25) < DT:
			print("T %7.2f km %6.2f v %5.1f want %6.1f safe %6.1f x %6.2f c %5.2f us %4.2f push %5.2f lat %5.2f off %d thr %.1f brk %.2f" % [t,
				track.z_to_km(z), v.speed, want, v.safe_curve_speed(track.curve_at(z), track.grip_at(z, grip)), v.x, track.curve_at(z), v.understeer,
				v.push_speed, v.lat_speed, v.off_road, float(input["throttle"]), float(input["brake"])])
	st["time_s"] = t
	st["avg_kmh"] = Units.avg_speed_kmh(plan.length_km, t, track.time_scale)
	if _arg("sections", "") != "":
		st["time_per_curviness_s"] = per_level
	return st
