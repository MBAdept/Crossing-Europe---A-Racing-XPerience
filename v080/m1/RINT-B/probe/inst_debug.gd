extends SceneTree
## Debug (RINT-B): compares the vehicles layer's instance count with the nodes under the car roots, headless.

const RACE := "res://scenes/race/race.tscn"
var _sc: Node
var _n := 0


func _initialize() -> void:
	root.get_node("Settings").call("disarm_crash_guard")
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 720.0, "weather": "normal", "start_km": 2.0, "autopilot": false, "seed": 11,
		"gfx": "modern", "no_countdown": true, "start_speed_kmh": 0.0}
	_sc = (load(RACE) as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)
	Engine.time_scale = 4.0


func _process(_dt: float) -> bool:
	if _sc == null or int(_sc.get("_sim_steps")) < 2:
		return false
	_n += 1
	if _n % 300 != 0:
		return false
	var r: Object = _sc.get("renderer")
	var vl: Object = r.call("layer", "vehicles")
	var pf: Dictionary = vl.call("perf")
	var world: Node3D = r.get("world")
	var names := {}
	var total := 0
	for c: Node in world.get_children():
		var k := 0
		var stack: Array[Node] = [c]
		while not stack.is_empty():
			var x: Node = stack.pop_back()
			if x.is_queued_for_deletion():
				continue
			if x is GeometryInstance3D:
				k += 1
			for y in x.get_children():
				stack.append(y)
		if k > 0:
			names[str(c.name)] = k
			if str(c.name).contains("car_"):
				total += k
	var own := 0
	for id: Variant in vl.get("_cars"):
		var car: Object = vl.get("_cars")[id]
		var lv: Dictionary = car.get("levels")
		for l: Variant in lv:
			own += ModelFactory.geometry_of(lv[l]).size()
	for k2: Variant in vl.get("_free"):
		for car2: Object in vl.get("_free")[k2]:
			var lv2: Dictionary = car2.get("levels")
			for l2: Variant in lv2:
				own += ModelFactory.geometry_of(lv2[l2]).size()
	print("DBG frame %d time %.1f counter %d own_levels %d car_nodes %d" % [_n, float(r.get("view").get("time", 0.0)), int(pf["vehicle_instances"]), own, total])
	print("DBG names " + JSON.stringify(names))
	return _n >= 1200
