extends SceneTree
## KRITIK-R (R6 fuel lane): Kiel – Hamburg with the autopilot (as KRITIK-FAHRBAHN trigger_log.gd: headless, Modern
## sound, time scale 8), and in km --from-km..--to-km EVERY frame: km, x, off_road, the feed's wheel surfaces, the
## segment's fuel lane and road edges. Prints "FR {...}" per frame and "FUEL {...}" at the end.
##   godot --headless --path <tree> -s <this> -- --graphics=arcade --sound=modern [--from-km=13.0] [--to-km=15.2]

var _scene: Node
var _feed: Object = null
var _done := false
var _rows := 0
var _rumble_r := 0
var _rumble_r_fuel := 0
var _shoulder_r_fuel := 0
var _from := 13.0
var _to := 15.2


func _initialize() -> void:
	var args := CliArgs.all()
	_from = float(args.get("from-km", 13.0))
	_to = float(args.get("to-km", 15.2))
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 720.0, "weather": "normal", "start_km": 0.0, "autopilot": true, "autopilot_speeding": false,
		"autopilot_refuel": "auto", "no_countdown": true, "seed": 0}
	Engine.time_scale = 8.0
	Engine.physics_ticks_per_second = 480
	Engine.max_physics_steps_per_frame = 16
	_scene = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	_scene.set("setup", setup)
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	if _done:
		return true
	if _feed == null:
		var am: Node = root.get_node_or_null("AudioManager")
		if am != null:
			var m: Variant = am.get("_modern")
			if m is Object and is_instance_valid(m):
				_feed = (m as Object).get("feed")
		return false
	var km := float(_scene.get("pos_km"))
	if km > _to:
		print("FUEL ", JSON.stringify({"rows": _rows, "rumble_right": _rumble_r, "rumble_right_with_fuel_lane": _rumble_r_fuel,
			"shoulder_right_with_fuel_lane": _shoulder_r_fuel}))
		_done = true
		quit(0)
		return true
	if km >= _from and bool(_feed.get("valid")):
		var veh: Object = _scene.get("vehicle")
		var track: Object = _scene.get("track")
		var z := float(_scene.get("pos_z"))
		var seg: Variant = track.call("get_segment", int(floor(z / float(track.get("seg_len")))))
		var fl := float((seg as Object).get("fuel_lane")) if seg is Object else 0.0
		var e: Vector2 = track.call("road_edges_at", z)
		var fs: Dictionary = _feed.call("state")
		_rows += 1
		if str(fs["surface_r"]) == "rumble":
			_rumble_r += 1
			if fl > 0.0:
				_rumble_r_fuel += 1
		if str(fs["surface_r"]) == "shoulder" and fl > 0.0:
			_shoulder_r_fuel += 1
		print("FR ", JSON.stringify({"km": snappedf(km, 0.0001), "x": snappedf(float(veh.get("x")), 0.01), "off": int(veh.get("off_road")),
			"l": fs["surface_l"], "r": fs["surface_r"], "fuel_lane": snappedf(fl, 0.01), "edge_r": snappedf(e.y, 0.01)}))
	return false
