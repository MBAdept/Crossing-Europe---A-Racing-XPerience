extends SceneTree
## KRITIK-FAHRBAHN: drives a stage with the autopilot (headless, Modern sound profile) and logs the AudioFeed once per
## second of stage time next to the Track / plan truth, plus every feed event (deduplicated).
##   godot --headless --path <tree> -s <this> -- --graphics=arcade --sound=modern --stage=kiel_hamburg \
##       [--from=kiel] [--start-km=0] [--timescale=8] [--max-seconds=900] [--weather=normal] [--vehicle=limousine]
## Output: "ROW {...}" per second, "EV {...}" per event, "SUMMARY {...}" at the end.

var _scene: Node
var _wall0 := 0
var _max_wall := 900.0
var _done := false
var _next_t := 0.0
var _seen := {}
var _modern: Object = null
var _feed: Object = null
var _counts := {}
var _frames := 0
var _feed_frames := 0
var _rows := 0


func _initialize() -> void:
	var args := CliArgs.all()
	var c := ConfigLoader.load_merged()
	var ts := clampf(float(args.get("timescale", 8.0)), 0.1, 40.0)
	_max_wall = float(args.get("max-seconds", 900.0))
	var setup := {
		"mode": "single",
		"race_id": "",
		"stage_id": str(args.get("stage", "kiel_hamburg")),
		"from_city": str(args.get("from", "")),
		"vehicle": str(args.get("vehicle", ConfigLoader.lookup(c, "vehicles.default", "limousine"))),
		"start_world_minutes": float(args.get("hour", 12.0)) * 60.0,
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


func _bump(key: String) -> void:
	_counts[key] = int(_counts.get(key, 0)) + 1


func _process(_delta: float) -> bool:
	if _done:
		return true
	_frames += 1
	if _modern == null:
		var am: Node = root.get_node_or_null("AudioManager")
		if am != null:
			var m: Variant = am.get("_modern")
			if m is Object and is_instance_valid(m):
				_modern = m
				_feed = _modern.get("feed")
	var wall := float(Time.get_ticks_msec() - _wall0) / 1000.0
	var stop_km := float(CliArgs.all().get("stop-km", 1.0e9))
	if float(_scene.get("pos_km")) > stop_km:
		print("STOP bei km %.2f" % float(_scene.get("pos_km")))
		_summary()
		_done = true
		quit(0)
		return true
	if wall > _max_wall:
		print("FEHLER: Zeitlimit bei km %.2f" % float(_scene.get("pos_km")))
		_summary()
		_done = true
		quit(1)
		return true
	if _feed != null:
		if bool(_feed.get("valid")):
			_feed_frames += 1
		var plan: Object = _scene.get("plan")
		var track: Object = _scene.get("track")
		for e: Dictionary in (_feed.get("events") as Array):
			var key := "%s|%.2f|%s|%s" % [str(e.get("name")), float(e.get("z", 0.0)), str(e.get("side", "")), str(e.get("set", ""))]
			if _seen.has(key):
				continue
			_seen[key] = true
			var ez := float(e.get("z", 0.0))
			var ekm := float(track.call("z_to_km", ez)) if track != null else 0.0
			var name := str(e.get("name"))
			_bump(name)
			if name == "pass_object":
				_bump("pass_" + str(e.get("kind")) + ("_delin" if str(e.get("set")) == "delineator" else ""))
				if bool(e.get("contact", false)):
					_bump("pass_contact")
				if str(e.get("set")) == "delineator":
					continue    # too many to print each
			if name == "joint":
				_bump("joint_" + str(e.get("kind")) + "_" + str(e.get("deck")))
			var row := e.duplicate()
			row["km"] = snappedf(ekm, 0.001)
			row["t"] = snappedf(float(_scene.get("stage_time")), 0.01)
			if plan != null:
				row["truth_bridge"] = str((plan.call("bridge_at", ekm) as Dictionary).get("type", ""))
				row["truth_tunnel"] = bool(plan.call("in_tunnel", ekm))
				row["truth_city"] = bool(plan.call("is_city", ekm))
			print("EV ", JSON.stringify(row))
	var st := float(_scene.get("stage_time")) if _scene.get("stage_time") != null else 0.0
	if st >= _next_t and _feed != null:
		_next_t = floorf(st) + 1.0
		_row(st)
	return false


func _row(st: float) -> void:
	var plan: Object = _scene.get("plan")
	var track: Object = _scene.get("track")
	var veh: Object = _scene.get("vehicle")
	var km := float(_scene.get("pos_km"))
	var z := float(_scene.get("pos_z"))
	var fs: Dictionary = _feed.call("state")
	var r := {"t": snappedf(st, 0.1), "km": snappedf(km, 0.001), "z": snappedf(z, 0.1),
		"v": snappedf(float(veh.get("speed")), 0.1), "x": snappedf(float(veh.get("x")), 0.01), "off": int(veh.get("off_road")),
		"rail": bool(veh.get("rail_contact")), "f": fs}
	if plan != null:
		r["truth"] = {"road": str(plan.call("road_at", km)), "city": bool(plan.call("is_city", km)),
			"center": bool(plan.call("in_city_center", km)), "tunnel": bool(plan.call("in_tunnel", km)),
			"bridge": str((plan.call("bridge_at", km) as Dictionary).get("type", "")),
			"fuel_lane": not (plan.call("fuel_lane_at", km) as Dictionary).is_empty(), "country": str(plan.call("country_at", km)),
			"scenery": str(plan.call("scenery_at", km))}
	if track != null:
		var seg: Variant = track.call("get_segment", int(floor(z / float(track.get("seg_len")))))
		if seg is Object:
			r["seg"] = {"road": str(seg.get("road")), "city": bool(seg.get("city")), "guardrail": bool(seg.get("guardrail")),
				"tunnel": bool(seg.get("tunnel")), "water": bool(seg.get("water")), "bridge": str(seg.get("bridge")),
				"cover": str(seg.get("cover")), "fuel_lane": float(seg.get("fuel_lane")), "lanes": float(seg.get("lanes"))}
		var zones: Variant = track.get("zones")
		if zones is Array:
			for zn: Dictionary in zones:
				if z >= float(zn.get("z0", 0.0)) and z < float(zn.get("z1", 0.0)):
					r["zone_" + str(zn.get("kind"))] = true
	_rows += 1
	print("ROW ", JSON.stringify(r))


func _summary() -> void:
	var track: Object = _scene.get("track")
	var br: Array = []
	if track != null:
		for b: Dictionary in (track.get("bridges") as Array):
			br.append({"type": b.get("type"), "z0": b.get("z0"), "z1": b.get("z1"),
				"km0": snappedf(float(track.call("z_to_km", float(b.get("z0")))), 0.001),
				"km1": snappedf(float(track.call("z_to_km", float(b.get("z1")))), 0.001)})
	var zs: Array = []
	if track != null:
		for zn: Dictionary in (track.get("zones") as Array):
			zs.append({"kind": zn.get("kind"), "z0": zn.get("z0"), "z1": zn.get("z1")})
	print("SUMMARY ", JSON.stringify({"counts": _counts, "frames": _frames, "feed_valid_frames": _feed_frames,
		"rows": _rows, "bridges": br, "zones": zs, "stage_time": _scene.get("stage_time"), "km": _scene.get("pos_km")}))


func _on_finished(result: Dictionary) -> void:
	print("ERGEBNIS ", JSON.stringify(result))
	_summary()
	_done = true
	quit(0)


func _on_aborted(reason: String) -> void:
	print("FEHLER: Etappe abgebrochen: ", reason)
	_summary()
	_done = true
	quit(1)
