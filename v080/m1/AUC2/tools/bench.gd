extends SceneTree
## GDScript time per frame of the slots env, ambience and traffic (no players: the logic only), 8 vehicles near.
func _initialize() -> void:
	var cfg: Dictionary = ConfigLoader.load_merged()
	var m := ModernAudio.new()
	m.clock_ms = 1000
	m.start(cfg, {"live": false, "quiet": true})
	var f := ModernAudioFrame.new()
	f.dt = 1.0 / 60.0
	f.alive = true
	f.speed = 120.0
	f.has_state = true
	f.state = {"hour": 13.0, "weather": "normal"}
	var fd := AudioFeed.new()
	fd.valid = true
	fd.zone = "forest"
	fd.climate = "continental"
	f.feed = fd
	f.traffic_alive = true
	f.listener = {"z": 0.0, "x": 0.0, "speed": 120.0}
	var cars: Array = []
	for i in 14:
		cars.append({"id": i + 1, "set": "traffic/sedan_blue" if i % 3 else "traffic/truck_red", "z": -60.0 + i * 11.0,
			"x": 3.75 if i % 2 else -3.75, "length": 4.7 if i % 3 else 16.5, "speed": 100.0 + i, "heavy": i % 3 == 0})
	f.vehicles = cars
	var n := 6000
	for slot in ["env", "ambience", "traffic"]:
		var t0 := Time.get_ticks_usec()
		var worst := 0
		for i in n:
			for c: Dictionary in cars:
				c["z"] = float(c["z"]) + (float(c["speed"]) - 120.0) / 3.6 / 60.0
			var a := Time.get_ticks_usec()
			match slot:
				"env": m.env.update(f)
				"ambience": m.ambience.update(f)
				"traffic": m.traffic.update(f)
			worst = maxi(worst, Time.get_ticks_usec() - a)
		var us := float(Time.get_ticks_usec() - t0) / n
		print("%-9s Mittel %.3f ms je Bild, längstes %.3f ms (%d Bilder, ohne Player)" % [slot, us / 1000.0, worst / 1000.0, n])
	m.shutdown()
	m.free()
	quit(0)
