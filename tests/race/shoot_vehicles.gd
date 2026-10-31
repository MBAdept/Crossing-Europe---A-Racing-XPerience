extends SceneTree
## Frame strips of vehicle scenarios in the real race scene (vehicle display v2, docs/renn-modul.md §8).
## Needs a real renderer (Xvfb + OpenGL) and a fixed frame rate, so every frame advances the same game time:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --fixed-fps 30 -s res://tests/race/shoot_vehicles.gd -- --scenario=curve_right --out=/tmp/strip \
##       [--sprite-manifest=res://tests/fixtures/sprites/manifest.json] [--hour=12] [--hud] [--perf] [--no-shots]
## With the fixture manifest the scenario cars use the fixtures (17-angle car, police, box truck) and the
## player the perspective fixture; without it the current assets. Random traffic is switched off; the cars
## are placed and driven by the scenario (speed, lane changes). Saves <out>_<NN>.png every `every` frames.
## Scenarios (dev_testetappe): curve_left, curve_right (cars and a truck ahead entering a curve),
## curve_sharp_left, curve_sharp_right (the sharpest curves, R ≈ 165/199 m, truck and car close ahead),
## overtake, overtake_curve (passing a truck in the neighbour lane), overtake_cars (passing cars close by on
## both sides: perspective flank warp), beside (a car standing still relative to the player in the left lane,
## rear 10 m ahead of the camera – for comparisons with a true 3D render), lane_change (cars ahead change
## lanes), player_left, player_right (player alone through curves), player_lanes (player lane changes),
## police (the police car pulls in ahead), tunnel (truck and car in the tunnel). Overrides: --km, --kmh,
## --frames, --every. --perf prints the renderer's _draw times at the end; with --no-shots
## (no screenshots) it also runs headless (CPU time of _draw is the same).
## The scene is accessed untyped (this script compiles before the autoloads the scene uses).

const SCENARIOS := {
	"curve_left": {"km": 37.62, "lane": 1, "kmh": 100.0, "frames": 96, "every": 6,
		"cars": [{"kind": "truck", "lane": 1, "gap": 22.0, "kmh": 80.0}, {"kind": "car", "lane": 0, "gap": 12.0, "kmh": 92.0},
			{"kind": "car", "lane": 0, "gap": 60.0, "kmh": 88.0}]},
	"curve_right": {"km": 57.62, "lane": 0, "kmh": 100.0, "frames": 96, "every": 6,
		"cars": [{"kind": "truck", "lane": 1, "gap": 18.0, "kmh": 80.0}, {"kind": "car", "lane": 0, "gap": 14.0, "kmh": 92.0},
			{"kind": "car", "lane": 1, "gap": 60.0, "kmh": 85.0}]},
	# the sharpest curves of dev_testetappe (left R ≈ 165 m from km 38.16, right R ≈ 199 m from km 58.14):
	# truck and car close ahead, driven deep into the curve
	"curve_sharp_left": {"km": 38.0, "lane": 0, "kmh": 100.0, "frames": 180, "every": 10,
		"cars": [{"kind": "truck", "lane": 1, "gap": 10.0, "kmh": 92.0}, {"kind": "car", "lane": 0, "gap": 16.0, "kmh": 96.0},
			{"kind": "car", "lane": 1, "gap": 45.0, "kmh": 90.0}]},
	"curve_sharp_right": {"km": 58.0, "lane": 0, "kmh": 100.0, "frames": 180, "every": 10,
		"cars": [{"kind": "truck", "lane": 1, "gap": 10.0, "kmh": 92.0}, {"kind": "car", "lane": 0, "gap": 16.0, "kmh": 96.0},
			{"kind": "car", "lane": 1, "gap": 45.0, "kmh": 90.0}]},
	# passing cars close by on both sides (perspective flank warp of the ortho car sprites)
	"overtake_cars": {"km": 30.0, "lane": 1, "kmh": 150.0, "frames": 60, "every": 3,
		"cars": [{"kind": "car", "lane": 0, "gap": 14.0, "kmh": 105.0}, {"kind": "car", "lane": 2, "gap": 22.0, "kmh": 110.0}]},
	# a car standing still relative to the player in the left neighbour lane, rear 10 m ahead of the camera
	# (gap = 10 - camera distance 9 - half the limousine 2.425): compare with a true 3D render
	"beside": {"km": 30.0, "lane": 1, "kmh": 120.0, "frames": 12, "every": 12,
		"cars": [{"kind": "car", "lane": 0, "gap": -1.425, "kmh": 120.0}]},
	"overtake": {"km": 30.0, "lane": 0, "kmh": 150.0, "frames": 90, "every": 3,
		"cars": [{"kind": "truck", "lane": 1, "gap": 16.0, "kmh": 85.0}, {"kind": "car", "lane": 2, "gap": 40.0, "kmh": 110.0}]},
	"overtake_curve": {"km": 68.95, "lane": 0, "kmh": 150.0, "frames": 90, "every": 3,
		"cars": [{"kind": "truck", "lane": 1, "gap": 16.0, "kmh": 85.0}, {"kind": "car", "lane": 2, "gap": 34.0, "kmh": 110.0}]},
	"lane_change": {"km": 31.0, "lane": 1, "kmh": 110.0, "frames": 90, "every": 5,
		"cars": [{"kind": "car", "lane": 1, "gap": 18.0, "kmh": 105.0, "change_at": 10, "to": 0},
			{"kind": "truck", "lane": 2, "gap": 30.0, "kmh": 95.0, "change_at": 30, "to": 1},
			{"kind": "car", "lane": 0, "gap": 55.0, "kmh": 110.0, "change_at": 45, "to": 1}]},
	"player_left": {"km": 37.75, "lane": 1, "kmh": 140.0, "frames": 120, "every": 8, "cars": []},
	"player_right": {"km": 57.75, "lane": 1, "kmh": 140.0, "frames": 120, "every": 8, "cars": []},
	"player_lanes": {"km": 31.0, "lane": 2, "kmh": 160.0, "frames": 72, "every": 4, "cars": [],
		"steer": [[6, 30, -1.0], [42, 66, 1.0]]},
	"police": {"km": 31.0, "lane": 1, "kmh": 120.0, "frames": 75, "every": 5, "cars": [], "police": true},
	"tunnel": {"km": 51.0, "lane": 0, "kmh": 110.0, "frames": 60, "every": 6,
		"cars": [{"kind": "truck", "lane": 1, "gap": 8.0, "kmh": 80.0}, {"kind": "car", "lane": 0, "gap": 30.0, "kmh": 95.0}]},
}

var _sc: Node
var _name := ""
var _cfg: Dictionary = {}
var _frame := 0
var _shot := 0
var _out := ""
var _cars: Array = []          ## [Car, spec]
var _capture := false
var _perf := false
var _cells := {}               ## vehicle id -> [cell changes, last cell, min yaw, max yaw] (sprite vehicles)


func _initialize() -> void:
	var args := CliArgs.all()
	_name = str(args.get("scenario", "curve_right"))
	if not SCENARIOS.has(_name):
		print("Unbekanntes Szenario: ", _name, " – ", SCENARIOS.keys())
		quit(2)
		return
	_cfg = (SCENARIOS[_name] as Dictionary).duplicate(true)
	for key: String in ["km", "kmh", "frames", "every"]:   # overrides: --km=38.0 --frames=180 ...
		if args.has(key):
			_cfg[key] = float(args[key])
	_out = str(args.get("out", "/tmp/vehicles_" + _name))
	_perf = args.has("perf")
	var setup := {"mode": "single", "race_id": "", "stage_id": "dev_testetappe", "from_city": "", "vehicle": str(args.get("vehicle", "limousine")),
		"start_world_minutes": float(args.get("hour", 12.0)) * 60.0, "weather": str(args.get("weather", "normal")),
		"start_km": float(_cfg["km"]), "autopilot": false, "no_countdown": true, "seed": 5}
	_sc = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)
	RenderingServer.frame_post_draw.connect(_on_post_draw)


func _db() -> Node:
	return root.get_node("SpriteDB")


func _set_for(kind: String) -> String:
	var fixture := {"car": "fixture/car17", "truck": "fixture/truck_box", "police": "fixture/police17"}
	var current := {"car": "traffic/sedan_blue", "truck": "traffic/truck_white", "police": "police/de"}
	var id: String = fixture[kind]
	return id if _db().call("has_set", id) else str(current[kind])


func _setup_scenario() -> void:
	var traffic: Object = _sc.get("traffic")
	var track: Object = _sc.get("track")
	var veh: Object = _sc.get("vehicle")
	var empty: Array[String] = []
	traffic.set("car_sets", empty)
	traffic.set("heavy_sets", empty)
	(traffic.get("cars") as Array).clear()
	var pz: float = _sc.get("pos_z")
	var lane := int(_cfg["lane"])
	veh.set("x", float(track.call("lane_center_x", pz, lane)))
	_sc.set("cam_x", veh.get("x"))
	veh.set("speed", float(_cfg["kmh"]))
	if not bool(ConfigLoader.lookup(ConfigLoader.load_merged(), "debug.show_render_stats", false)) and not CliArgs.has("hud"):
		(_sc.get("hud") as CanvasItem).visible = false
	var plen: float = veh.get("length_m")
	var next_id := 9000
	for spec: Dictionary in _cfg["cars"]:
		var c := TrafficSystem.Car.new()
		var set_id := _set_for(str(spec["kind"]))
		var dims: Dictionary = _db().call("object_size", set_id)
		c.id = next_id
		next_id += 1
		c.set_id = set_id
		c.length = float(dims.get("length_m", 4.5))
		c.width = float(dims.get("width_m", 1.8))
		c.height = float(dims.get("height_m", 1.5))
		c.heavy = str(spec["kind"]) == "truck"
		c.z = pz + plen * 0.5 + float(spec["gap"]) + c.length * 0.5
		c.lane = int(spec["lane"])
		c.x = float(track.call("lane_center_x", c.z, c.lane))
		c.speed = float(spec["kmh"])
		c.cruise_speed = c.speed
		c.lane_cooldown = 1.0e9
		(traffic.get("cars") as Array).append(c)
		_cars.append([c, spec])
	if bool(_cfg.get("police", false)):
		var police: Object = _sc.get("police")
		police.set("state", PoliceSystem.State.STOPPING)   # overtakes and pulls in ahead
		police.set("overtake_time", 0.0)


func _physics_process(_delta: float) -> bool:
	if _sc == null or not _sc.is_inside_tree():
		return false
	if _frame == 0:
		return false
	var veh: Object = _sc.get("vehicle")
	veh.set("speed", float(_cfg["kmh"]))
	for e: Array in _cars:
		var c: TrafficSystem.Car = e[0]
		var spec: Dictionary = e[1]
		c.speed = float(spec["kmh"])
		if spec.has("change_at") and _frame >= int(spec["change_at"]):
			c.lane = int(spec["to"])
	var steer := 0.0
	for s: Array in _cfg.get("steer", []):
		if _frame >= int(s[0]) and _frame < int(s[1]):
			steer = float(s[2])
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	if steer < 0.0:
		Input.action_press("steer_left", -steer)
	elif steer > 0.0:
		Input.action_press("steer_right", steer)
	return false


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		_setup_scenario()
		return false
	if _frame >= 4 and (_frame - 4) % int(_cfg["every"]) == 0 and not CliArgs.has("no-shots"):
		_capture = true
	_log_cells()
	if _frame > 4 + int(_cfg["frames"]):
		for id: int in _cells:
			var c: Array = _cells[id]
			print("Fahrzeug %d: %d Zellwechsel, Darstellungswinkel %.1f° .. %.1f°" % [id, int(c[0]), float(c[2]), float(c[3])])
		if _perf:
			var r: Object = _sc.get("renderer")
			print("PERF ", JSON.stringify(r.call("perf_stats")))
		print("Szenario %s: %d Bilder unter %s_*.png" % [_name, _shot, _out])
		quit(0)
		return true
	return false


## Cell and smoothed yaw of every scenario car (sprites) after each frame: cell changes = flicker check.
func _log_cells() -> void:
	var r: Object = _sc.get("renderer")
	if r == null or _frame < 3:
		return
	var ids: Array[int] = []
	for e: Array in _cars:
		ids.append((e[0] as TrafficSystem.Car).id)
	if bool(_cfg.get("police", false)):
		ids.append(-2)
	for id in ids:
		var cell := int(r.call("vehicle_cell", id))
		if cell < 0:
			continue
		var yaw := float(r.call("vehicle_yaw_deg", id))
		if not _cells.has(id):
			_cells[id] = [0, cell, yaw, yaw]
		var c: Array = _cells[id]
		if cell != int(c[1]):
			c[0] = int(c[0]) + 1
			c[1] = cell
		c[2] = minf(float(c[2]), yaw)
		c[3] = maxf(float(c[3]), yaw)


func _on_post_draw() -> void:
	if not _capture:
		return
	_capture = false
	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		print("Kein Bild (läuft das Skript mit --headless? Es braucht einen echten Renderer)")
		quit(1)
		return
	img.save_png("%s_%02d.png" % [_out, _shot])
	if CliArgs.has("verbose"):
		var pz: float = _sc.get("pos_z")
		var line := "shot %02d frame %d: player z %.1f speed %.0f" % [_shot, _frame, pz, float((_sc.get("vehicle") as Object).get("speed"))]
		for e: Array in _cars:
			var c: TrafficSystem.Car = e[0]
			line += "  | %s rear %.1f m vor Kamera, x %.2f, %.0f km/h" % [c.set_id.get_file(), c.z - c.length * 0.5 - (pz - 9.0), c.x, c.speed]
		var r: Object = _sc.get("renderer")
		line += "  | Spieler %s" % str(r.get("last_player_pose"))
		print(line)
	_shot += 1
