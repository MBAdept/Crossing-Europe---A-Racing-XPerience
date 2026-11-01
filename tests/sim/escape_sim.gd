extends RefCounted
## Police chases on the real network with the curve physics. For every radar zone of every stage direction a
## player drives a curve-limited speed profile through the zone (flashed where the profile first reaches the
## trigger speed) and tries to escape: the real PoliceSystem gets the police car's curve limit per step (the
## braking envelope of PoliceSystem.curve_speed_mps, as SessionRules.police_curve_cap_kmh computes it in the
## race session). The player profile: top speed of the car (grade, weather, night), margin × its own safe
## curve speed (grip of the road: Track.grip_at), braking with brake_mps2 before curves, the real acceleration
## curve after them; no traffic, no fuel stops.
## Used by tests/unit/race/test_police_curves.gd (every chase must be escapable) and tests/sim/run_sims.gd
## (table (e3)). Owner: gameplay module (tests only).

const Fx := preload("res://tests/sim/fixtures.gd")


## Per-segment road data of a stage direction (built once, shared by all cars and conditions).
static func road_arrays(track: Track) -> Dictionary:
	var n := track.segment_count
	var curve := PackedFloat32Array()
	var grade := PackedFloat32Array()
	var tunnel := PackedByteArray()
	curve.resize(n)
	grade.resize(n)
	tunnel.resize(n)
	for k in n:
		var s := track.get_segment(k)
		curve[k] = s.curve
		grade[k] = track.grade_at(s.z)
		tunnel[k] = 1 if s.tunnel else 0
	return {"curve": curve, "grade": grade, "tunnel": tunnel, "seg": track.seg_len, "n": n}


## Speed profile of the player (m/s per segment): forward pass with the car's acceleration curve, limited by the
## backward braking envelope (brake_mps2) of min(top speed, margin × safe curve speed).
static func player_profile(road: Dictionary, v: VehicleModel, weather_grip: float, vmax_factor: float, margin: float, brake_mps2: float) -> PackedFloat32Array:
	var n := int(road["n"])
	var seg := float(road["seg"])
	var curve: PackedFloat32Array = road["curve"]
	var grade: PackedFloat32Array = road["grade"]
	var tunnel: PackedByteArray = road["tunnel"]
	var vtop := PackedFloat32Array()
	vtop.resize(n)
	var vb := PackedFloat32Array()
	vb.resize(n)
	for k in n:
		var top := v.max_speed(grade[k], vmax_factor)
		vtop[k] = top
		var g := 1.0 if tunnel[k] == 1 else weather_grip
		vb[k] = minf(top, v.safe_curve_speed(curve[k], g) * margin) / 3.6
	for k in range(n - 2, -1, -1):
		vb[k] = minf(vb[k], sqrt(vb[k + 1] * vb[k + 1] + 2.0 * brake_mps2 * seg))
	var prof := PackedFloat32Array()
	prof.resize(n)
	prof[0] = vb[0]
	for k in range(1, n):
		var prev := prof[k - 1]
		var acc := v.accelerate(prev * 3.6, vtop[k], seg / maxf(prev, 1.0)) / 3.6
		prof[k] = minf(vb[k], acc)
	return prof


## Curve limit of the police car per segment (km/h): exact braking envelope (police.curve_brake_mps2) of its curve
## speed – what SessionRules.police_curve_cap_kmh samples every police.curve_step_m.
static func police_cap(road: Dictionary, police: PoliceSystem, weather_grip: float) -> PackedFloat32Array:
	var n := int(road["n"])
	var seg := float(road["seg"])
	var curve: PackedFloat32Array = road["curve"]
	var tunnel: PackedByteArray = road["tunnel"]
	var cap := PackedFloat32Array()
	cap.resize(n)
	var b2 := 2.0 * police.curve_brake_mps2 * seg
	var next := INF
	for k in range(n - 1, -1, -1):
		var vs := police.curve_speed_mps(curve[k], 1.0 if tunnel[k] == 1 else weather_grip)
		next = minf(vs, sqrt(next * next + b2)) if next < INF else vs
		cap[k] = next * 3.6 if next < INF else INF
	return cap


## One chase: the player drives prof from just before radar r with a fresh PoliceSystem (road cap per step).
## Returns {result: none | escaped | caught | running, chase_s, best_margin (best 12-s average minus the escape
## threshold, km/h, after 12 s), escape_kmh (the threshold when it ended), avg, min_gap_m, flash_kmh}.
static func chase(cfg: Dictionary, plan: StagePlan, track: Track, road: Dictionary, prof: PackedFloat32Array, cap: PackedFloat32Array, r: Dictionary) -> Dictionary:
	var police := PoliceSystem.new()
	police.setup(cfg, plan)
	var seg := float(road["seg"])
	var n := int(road["n"])
	var k := maxi(0, track.segment_index_at(track.km_to_z(float(r["km"]) - 1.0)))
	var k_end := mini(n - 2, track.segment_index_at(track.km_to_z(float(r["end_km"]))) + 3000)
	var out := {"result": "none", "chase_s": 0.0, "best_margin": -INF, "escape_kmh": 0.0, "avg": 0.0, "min_gap_m": INF, "flash_kmh": 0.0}
	var flashed := false
	while k < k_end:
		var vv := maxf(0.5 * (prof[k] + prof[k + 1]), 0.5)
		var dt := seg / vv
		var was := police.state
		police.update(dt, track.z_to_km(float(k + 1) * seg), vv * 3.6, cap[k + 1])
		k += 1
		if not flashed and police.state == PoliceSystem.State.CHASE:
			flashed = true
			out["flash_kmh"] = vv * 3.6
		if police.state == PoliceSystem.State.CHASE:
			out["min_gap_m"] = minf(float(out["min_gap_m"]), police.gap_m)
			if police.chase_time >= 12.0:
				out["best_margin"] = maxf(float(out["best_margin"]), police.avg_speed - police.escape_kmh)
		if was == PoliceSystem.State.CHASE and police.state != PoliceSystem.State.CHASE:
			out["result"] = "escaped" if police.state == PoliceSystem.State.IDLE else "caught"
			out["chase_s"] = police.chase_time
			out["escape_kmh"] = police.escape_kmh
			out["avg"] = police.avg_speed
			break
	if flashed and str(out["result"]) == "none":
		out["result"] = "running"
	return out


## All radar zones of all stage directions (non-dev) × vehicles × conditions for one driver. opts: vehicles (Array),
## conditions (Array of {weather, hour}), margin (1.0), brake_mps2 (70 km/h/s), stages (Array of ids, all if
## empty). Returns {radars, total: {key: n}, flashed: {key: n}, fails: {key: n}, failures: [..], escape_s: {key: [..]}}
## with key = "<vehicle> <weather> <hour>".
static func sweep(cfg: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var o := opts.duplicate()
	o["drivers"] = {"d": {"margin": float(opts.get("margin", 1.0)),
		"brake_mps2": float(opts.get("brake_mps2", float(ConfigLoader.lookup(cfg, "driving.brake_decel_kmh_s", 70.0)) / 3.6))}}
	return sweep_drivers(cfg, o)["d"]


## Like sweep() for several drivers at once (the tracks are built once): opts.drivers = {name: {margin,
## brake_mps2}}. Returns {name: result of sweep()}.
static func sweep_drivers(cfg: Dictionary, opts: Dictionary) -> Dictionary:
	var net: Variant = ConfigLoader.load_json("res://data/network.json")
	var ctry: Variant = ConfigLoader.load_json("res://data/countries.json")
	var countries: Dictionary = (ctry as Dictionary).get("countries", {}) if ctry is Dictionary else {}
	var cities := {}
	for c: Dictionary in (net as Dictionary).get("cities", []):
		cities[str(c["id"])] = c
	var vehicles: Array = opts.get("vehicles", Fx.VEHICLES)
	var conditions: Array = opts.get("conditions", [{"weather": "normal", "hour": 12.0}, {"weather": "rain", "hour": 2.0}])
	var drivers: Dictionary = opts.get("drivers", {})
	var only: Array = opts.get("stages", [])
	var env := EnvironmentModel.new()
	env.setup(cfg)
	var out := {}
	for d: String in drivers:
		out[d] = {"total": {}, "flashed": {}, "fails": {}, "failures": [], "escape_s": {}, "radars": 0}
	for st: Dictionary in (net as Dictionary).get("stages", []):
		if bool(st.get("dev", false)) or (not only.is_empty() and not only.has(str(st["id"]))):
			continue
		for from_id: String in [str(st["from"]), str(st["to"])]:
			var plan := StagePlan.build(st, from_id, cities, countries, cfg)
			if plan.radars.is_empty():
				continue
			var track := Track.new()
			track.setup(plan, cfg, {})
			var road := road_arrays(track)
			var police := PoliceSystem.new()
			police.setup(cfg, plan)
			for d: String in drivers:
				out[d]["radars"] = int(out[d]["radars"]) + plan.radars.size()
			for cond: Dictionary in conditions:
				var weather := str(cond.get("weather", "normal"))
				var hour := float(cond.get("hour", 12.0))
				var grip := env.grip(weather)
				var cap := police_cap(road, police, grip)
				for vid: String in vehicles:
					var v := Fx.vehicle(cfg, vid)
					var key := "%s %s %d" % [vid, weather, roundi(hour)]
					for d: String in drivers:
						var dr: Dictionary = drivers[d]
						var res_d: Dictionary = out[d]
						# braking at most the full braking of the weather (v0.5.0: rain ~78 %, snow ~half of 70 km/h/s)
						var brake := minf(float(dr.get("brake_mps2", 70.0 / 3.6)), v.brake_decel_mps2(grip))
						var prof := player_profile(road, v, grip, env.vmax_factor(hour, weather), float(dr.get("margin", 1.0)), brake)
						for r: Dictionary in plan.radars:
							var res := chase(cfg, plan, track, road, prof, cap, r)
							res_d["total"][key] = int(res_d["total"].get(key, 0)) + 1
							if str(res["result"]) == "none":
								continue
							res_d["flashed"][key] = int(res_d["flashed"].get(key, 0)) + 1
							if str(res["result"]) == "escaped":
								if not res_d["escape_s"].has(key):
									res_d["escape_s"][key] = []
								res_d["escape_s"][key].append(float(res["chase_s"]))
							else:
								res_d["fails"][key] = int(res_d["fails"].get(key, 0)) + 1
								res["stage"] = plan.stage_id
								res["from"] = from_id
								res["radar_km"] = float(r["km"])
								res["key"] = key
								res_d["failures"].append(res)
	return out
