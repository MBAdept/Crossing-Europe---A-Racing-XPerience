extends SceneTree
## FIX-ZS1 scratch: the start (km 0) of every stage direction – look-into-the-curve yaw of the countdown camera,
## sharpest curve and height change in the first 300 m, city / tunnel / water at the start.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var Fair: Variant = load("res://tests/race3d/fairness.gd")
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net: Dictionary = Fair.load_network()
	var r1 := float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
	var cam_cfg: Dictionary = ConfigLoader.lookup(cfg, "graphics.modern.camera", {})
	var rows: Array = []
	for dir: Dictionary in Fair.directions(net):
		var plan: Variant = StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		var p := RoadPath3D.new()
		p.setup(t, 0, r1)
		p.ensure(200)
		var cam := ChaseCamera3D.new()
		cam.look_gain = float(cam_cfg.get("look_gain", 0.6))
		cam.look_m = float(cam_cfg.get("look_m", 100.0))
		cam.yaw_max = deg_to_rad(float(cam_cfg.get("yaw_max_deg", 14.0)))
		var yaw0 := rad_to_deg(cam.look_yaw(p, -9.0))
		var cmax := 0.0
		var cmax_z := 0.0
		for k in 100:
			var s := t.get_segment(k)
			if absf(s.curve) > absf(cmax):
				cmax = s.curve
				cmax_z = s.z
		var y0 := t.get_segment(0).y
		var dy100 := t.get_segment(33).y - y0
		var dy300 := t.get_segment(100).y - y0
		var s0 := t.get_segment(0)
		var water := false
		for k in 20:
			water = water or t.get_segment(k).water
		rows.append([str(dir["name"]), yaw0, cmax, cmax_z, dy100, dy300, s0.city, s0.tunnel, water, s0.scenery, s0.road, s0.country])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return absf(float(a[1])) > absf(float(b[1])))
	print("name | yaw0_deg | curve_max | at_z | dy_100m | dy_300m | city | tunnel | water | scenery | road | country")
	for r: Array in rows:
		print("%s | %.2f | %.3f | %.0f | %.2f | %.2f | %s | %s | %s | %s | %s | %s" % r)
	quit(0)
