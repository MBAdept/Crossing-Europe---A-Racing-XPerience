extends SceneTree
## Probe (RINT-B): brake against tail light on screen with the race look – a model car 18 m ahead in the player's lane,
## at night (22:00) and by day (12:00), tail only and tail + brake. Prints the summed luminance increase over the
## background of the lamp pixels and the ratio. Run under Xvfb (opengl3), --gfx-sync.
## usage: ... -s <this> -- --set=traffic/sedan_red --hour=22 --out=<dir>

const RACE := "res://scenes/race/race.tscn"
const PROBE := "res://tests/race3d/fixtures/vehicle_probe_renderer.gd"

var _sc: Node
var _probe: GDScript
var _renderers: GDScript
var _phase := 0
var _frames := 0
var _set := "traffic/sedan_red"
var _hour := 22.0
var _out := ""
var _imgs: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--set="):
			_set = a.substr(6)
		elif a.begins_with("--hour="):
			_hour = float(a.substr(7))
		elif a.begins_with("--out="):
			_out = a.substr(6)
	root.get_node("Settings").call("disarm_crash_guard")
	_renderers = load("res://scripts/race/race_renderers.gd")
	_renderers.set("modern_script", PROBE)
	_probe = load(PROBE)
	_probe.set("hide_player", true)
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": _hour * 60.0, "weather": "normal", "start_km": 2.0, "autopilot": false, "seed": 11,
		"gfx": "modern", "no_countdown": true, "start_speed_kmh": 0.0}
	_sc = (load(RACE) as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)


func _car(brake: float) -> Dictionary:
	var r: Object = _sc.get("renderer")
	var view: Dictionary = r.get("view")
	var cam_z := float(view.get("camera_z", 0.0))
	var x0 := float((view.get("player", {}) as Dictionary).get("x", 0.0))
	return {"kind": "car", "id": 9700, "set": _set, "z": cam_z + 18.0, "x": x0, "length": 4.7, "tail": 1.0, "brake": brake,
		"speed": 0.0}


func _process(_dt: float) -> bool:
	if _sc == null or int(_sc.get("_sim_steps")) < 2:
		return false
	_frames += 1
	match _phase:
		0:
			_probe.set("inject", [])
			if _frames > 20:
				_imgs.append(root.get_texture().get_image())
				_probe.set("inject", [_car(0.0)])
				_phase = 1
				_frames = 0
		1:
			if _frames > 20:
				_imgs.append(root.get_texture().get_image())
				_probe.set("inject", [_car(1.0)])
				_phase = 2
				_frames = 0
		2:
			if _frames > 20:
				_imgs.append(root.get_texture().get_image())
				_report()
				return true
	return false


func _report() -> void:
	var bg: Image = _imgs[0]
	var names := ["tail", "brake"]
	var sums := []
	for k in 2:
		var im: Image = _imgs[k + 1]
		var s := 0.0
		var n := 0
		for y in range(370, 450):
			for x in range(580, 700):
				var c := im.get_pixel(x, y)
				var b := bg.get_pixel(x, y)
				# lamp pixels: red dominant and brighter than the background (the car's own body pixels are not counted)
				if c.r > 0.35 and c.r > c.g * 1.6 and c.r > c.b * 1.6:
					var lum := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
					var lb := 0.2126 * b.r + 0.7152 * b.g + 0.0722 * b.b
					s += maxf(lum - lb, 0.0)
					n += 1
		sums.append([s, n])
		if _out != "":
			im.save_png(_out.path_join("brake_probe_%s_%s.png" % [names[k], str(int(_hour))]))
	print("BRAKE " + JSON.stringify({"set": _set, "hour": _hour, "tail_sum": snappedf(float(sums[0][0]), 0.01), "tail_px": sums[0][1],
		"brake_sum": snappedf(float(sums[1][0]), 0.01), "brake_px": sums[1][1],
		"ratio": snappedf(float(sums[1][0]) / maxf(float(sums[0][0]), 0.001), 0.01)}))
