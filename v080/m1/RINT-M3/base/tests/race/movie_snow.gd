extends SceneTree
## Demo drive for a video (Godot Movie Maker, docs/gameplay.md "Wetter"): snow on the autobahn with slow traffic,
## the car slides on after every lane change. The real race scene with random traffic (built up around the start),
## driven through the real input actions: the Autopilot picks speed and lane, the steering is a keyboard player's –
## full lock towards the new lane, letting go when the slide of a dry road (lateral speed × 0.12 s) would carry the
## car there; on snow it slides on towards the next lane, then the player counter-steers.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 \
##       --write-movie /tmp/schnee.avi --fixed-fps 30 --quit-after 1100 -s res://tests/race/movie_snow.gd -- \
##       --start-speed=120 [--stage=hamburg_hannover] [--km=70] [--hour=7.5] [--weather=snow] [--vehicle=limousine]
##       [--seed=5] [--lane=1]
## (the video of v0.5.0: rush hour, flying start with 120 km/h; --start-speed and --lane are read by the race session.
## QA v0.5.0: the old defaults Hamburg – Bremen km 26, seed 3 showed no truck within 150 m and no car pulling out in
## the first 35 s – Hamburg – Hannover km 70, seed 5 shows a truck at 55 km/h and four cars/trucks pulling out with
## their indicator)
## Prints a line per second of game time (speed, lane, lateral offset, slide, collisions so far). Accessed untyped
## (this script compiles before the autoloads the scene uses). Owner: race module (tools for demos).

var _sc: Node
var _ap: Autopilot
var _frame := 0
var _counter := false
var _last_change := 0           ## physics frame of the last lane change (keep right only after 2.5 s in a lane)


func _initialize() -> void:
	var args := CliArgs.all()
	var setup := {"mode": "single", "race_id": "", "stage_id": str(args.get("stage", "hamburg_hannover")), "from_city": str(args.get("from", "")),
		"vehicle": str(args.get("vehicle", "limousine")), "start_world_minutes": float(args.get("hour", 7.5)) * 60.0,
		"weather": str(args.get("weather", "snow")), "start_km": float(args.get("km", 70.0)), "autopilot": false,
		"no_countdown": true, "traffic_warmup": true, "seed": int(args.get("seed", 5))}
	_sc = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)
	_ap = Autopilot.new()
	_ap.target_kmh = float(args.get("target", 300.0))
	_ap.obey_radar = false
	_ap.refuel_mode = "never"


func _physics_process(_delta: float) -> bool:
	if _sc == null or not _sc.is_inside_tree() or _sc.get("track") == null:
		return false
	_frame += 1
	var hz := Engine.physics_ticks_per_second
	var veh: Object = _sc.get("vehicle")
	var track: Object = _sc.get("track")
	var z: float = _sc.get("pos_z")
	var lane_before := int(_ap.get("_lane"))
	if _frame % (hz / 2) == 0 and _frame - _last_change > hz * 5 / 2 and absf(float(veh.get("x")) - float(track.call("lane_center_x", z, lane_before))) < 0.5:
		_keep_right(track, z)
	var out := _ap.drive(_sc)
	if int(_ap.get("_lane")) != lane_before:
		_last_change = _frame
	var tx := float(track.call("lane_center_x", z + 12.0, _ap.get("_lane")))
	var x := float(veh.get("x"))
	var lat := float(veh.get("lat_speed"))
	var err := tx - x
	# keyboard player: full lock until a dry-road slide would carry the car to the lane; when it slides on past the
	# lane he only reacts once it is clearly off (1.4 m) and then steers against the slide
	var steer := 0.0
	var past := absf(lat) > 0.2 and signf(lat) != signf(err)
	if past:
		if absf(err) > 1.4:
			_counter = true
		if _counter:
			steer = signf(err)
	else:
		_counter = false
		if absf(err) > absf(lat) * 0.12 + 0.3:
			steer = signf(err)
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	if steer < 0.0:
		Input.action_press("steer_left", -steer)
	elif steer > 0.0:
		Input.action_press("steer_right", steer)
	Input.action_release("accelerate")
	Input.action_release("brake")
	if float(out["throttle"]) > 0.0:
		Input.action_press("accelerate", float(out["throttle"]))
	if float(out["brake"]) > 0.0:
		Input.action_press("brake", float(out["brake"]))
	if _frame % hz == 0:
		print("t %5.1f s  km %6.2f  %3.0f km/h  Spur %d  x %+.2f (Ziel %+.2f)  quer %+.1f m/s  Kollisionen %d  %s" % [
			float(_frame) / hz, float(_sc.get("pos_km")), float(veh.get("speed")), int(_ap.get("_lane")), x, tx, lat,
			int((_sc.get("stats") as Dictionary).get("collisions", 0)), str(_ap.get("last_reason"))])
	return false


## Keeps right like a law-abiding driver (the Autopilot alone stays in a free left lane): back one lane to the right
## when it is free from 20 m behind to 250 m ahead – the next slow car then makes it pull out again.
func _keep_right(track: Object, z: float) -> void:
	var lane := int(_ap.get("_lane"))
	var lanes := int(track.call("lane_count_at", z))
	if lane >= lanes - 1:
		return
	var x := float(track.call("lane_center_x", z, lane + 1))
	for c in (_sc.get("traffic") as Object).get("cars"):
		if c.z > z - 20.0 and c.z < z + 250.0 and absf(float(c.x) - x) < 2.6:
			return
	_ap.set("_lane", lane + 1)
	_ap.set("_hold_lane_t", 2.0)
