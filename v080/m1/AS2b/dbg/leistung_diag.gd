extends SceneTree
## AS2b diagnosis (scratch, not in the repository): the scenario of check_vehicles.gd "leistung" - which car gets a
## new node while the same cars drive on? Prints every car whose level changes during the 120 measured frames.

const RACE := "res://scenes/race/race.tscn"
const PROBE := "res://tests/race3d/fixtures/vehicle_probe_renderer.gd"

var _probe: GDScript
var _renderers: GDScript


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_probe = load(PROBE)
	_renderers = load("res://scripts/race/race_renderers.gd")
	var settings: Node = root.get_node("Settings")
	settings.call("disarm_crash_guard")
	_renderers.set("modern_script", PROBE)
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 2.0, "autopilot": false, "seed": 11,
		"gfx": "modern", "no_countdown": true, "start_speed_kmh": 0.0}
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	root.add_child(sc)
	var n := 0
	while int(sc.get("_sim_steps")) <= 2 and n < 3000:
		await process_frame
		n += 1
	var r: Node = sc.get("renderer")
	var view: Dictionary = r.get("view")
	var cam_z := float(view.get("camera_z", 0.0))
	var x0 := float((view.get("player", {}) as Dictionary).get("x", 0.0))
	var sets := ["traffic/sedan_red", "traffic/hatch_blue", "traffic/wagon_silver", "traffic/truck_red", "traffic/sports_blue",
		"traffic/van_white", "traffic/bus_red", "traffic/suv_grey", "police/de"]
	var cars: Array = []
	for i in 23:
		var lane := float(i % 3 - 1) * 3.75
		var sid: String = sets[i % sets.size()]
		var l := float(ModelDB.object_size(sid).get("length_m", 4.5))
		cars.append({"kind": "car", "id": 9200 + i, "set": sid, "z": cam_z + 14.0 + float(i) * 17.0, "x": x0 + lane, "length": l,
			"tail": 0.0, "brake": 1.0 if i % 4 == 0 else 0.0, "speed": 0.0, "blink": 1 if i % 5 == 0 else 0, "blink_t": 0.1})
	_probe.set("inject", cars)
	for f in 30:
		await process_frame
	var vl: Node = r.call("layer", "vehicles")
	var before: Dictionary = vl.call("perf")
	var snap0 := {}
	for v: Dictionary in r.call("debug_snapshot").get("vehicles", []):
		snap0[int(v["id"])] = v
	for f in 120:
		vl.call("update", r.get("view"), 1.0 / 60.0)
		await process_frame
		var b := int((vl.call("perf") as Dictionary)["vehicle_builds"])
		if b != int(before["vehicle_builds"]):
			print("build count %d -> %d in frame %d" % [int(before["vehicle_builds"]), b, f])
			for v: Dictionary in r.call("debug_snapshot").get("vehicles", []):
				var id := int(v["id"])
				var o: Dictionary = snap0.get(id, {})
				if o.is_empty() or str(o.get("lod")) != str(v.get("lod")):
					print("  car %d %s model %s: lod %s -> %s, dist %.1f -> %.1f, shown %s" % [id, str(v.get("set")), str(v.get("model")),
						str(o.get("lod", "-")), str(v.get("lod")), float(o.get("dist", -1.0)), float(v.get("dist", -1.0)), str(v.get("shown"))])
			before = vl.call("perf")
			for v: Dictionary in r.call("debug_snapshot").get("vehicles", []):
				snap0[int(v["id"])] = v
	var after: Dictionary = vl.call("perf")
	print("builds at the end %d, cars %d" % [int(after["vehicle_builds"]), int(after["vehicles"])])
	for v: Dictionary in r.call("debug_snapshot").get("vehicles", []):
		print("  %d %s %s lod %s dist %.1f" % [int(v["id"]), str(v.get("set")), str(v.get("model")), str(v.get("lod")), float(v.get("dist", -1.0))])
	_probe.call("reset")
	_renderers.set("modern_script", _renderers.get("MODERN_SCRIPT"))
	quit(0)
