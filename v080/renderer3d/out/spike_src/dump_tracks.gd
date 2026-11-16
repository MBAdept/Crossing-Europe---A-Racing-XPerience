extends SceneTree
## Dumps curve / height / flags per segment of every stage direction (design study v0.8.0, scratch only).
##   godot --headless --path . -s res://spike/dump_tracks.gd -- --out=<dir>

func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return default


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net: Dictionary = ConfigLoader.load_json("res://data/network.json")
	var countries: Dictionary = (ConfigLoader.load_json("res://data/countries.json") as Dictionary).get("countries", {})
	var cities := {}
	for c: Dictionary in net.get("cities", []):
		cities[str(c["id"])] = c
	var out := _arg("out", "/tmp")
	var index: Array = []
	var t0 := Time.get_ticks_msec()
	for s: Dictionary in net.get("stages", []):
		for from_id: String in [str(s["from"]), str(s["to"])]:
			var plan := StagePlan.build(s, from_id, cities, countries, cfg)
			var track := Track.new()
			track.setup(plan, cfg, {})
			var n := track.segment_count
			var buf := PackedFloat32Array()
			buf.resize(n * 4)
			for i in n:
				var sg := track.get_segment(i)
				buf[i * 4] = sg.curve
				buf[i * 4 + 1] = sg.y
				buf[i * 4 + 2] = sg.lanes + sg.fuel_lane
				var fl := 0
				if sg.tunnel: fl |= 1
				if sg.city: fl |= 2
				if sg.road == "autobahn": fl |= 4
				if sg.water: fl |= 8
				if sg.runout: fl |= 16
				buf[i * 4 + 3] = float(fl)
			var name := "%s__%s" % [str(s["id"]), from_id]
			var f := FileAccess.open(out + "/" + name + ".f32", FileAccess.WRITE)
			f.store_buffer(buf.to_byte_array())
			f.close()
			var secs: Array = []
			for sec: Dictionary in plan.sections:
				secs.append({"start_km": sec["start_km"], "end_km": sec["end_km"], "curviness": sec["curviness"], "hills": sec["hills"], "road": sec["road"], "scenery": sec["scenery"]})
			index.append({"name": name, "stage": s["id"], "from": from_id, "n": n, "length_km": plan.length_km, "length_z": track.length_z,
				"seg_len": track.seg_len, "dev": bool(s.get("dev", false)), "sections": secs, "city_limits_km": plan.city_limits_km})
	var fi := FileAccess.open(out + "/index.json", FileAccess.WRITE)
	fi.store_string(JSON.stringify(index))
	fi.close()
	print("DUMP %d stage directions in %d ms" % [index.size(), Time.get_ticks_msec() - t0])
	quit(0)
