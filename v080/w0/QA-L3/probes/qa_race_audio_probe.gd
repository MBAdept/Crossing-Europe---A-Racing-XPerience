extends SceneTree
## QA lens 3: the Arcade sound in a real stage, frame by frame. Runs on tag v0.7.0 and on the integrated tree.
##   godot [--headless] --path <tree> --fixed-fps 60 -s <this> -- --out=<json> [--pre=modern|arcade|none] [--frames=1500]
## --pre: a stage of 200 frames before the measured one (modern = Modern picture and Modern sound, integrated tree
## only; arcade = control). The measured stage: dev_testetappe from km 40 (tunnel, bridge, police, rain), autopilot.
## Per frame: simulation state, AudioManager.engine_state(), traffic_state(), the values the session handed over.

const RACE := "res://scenes/race/race.tscn"

var _am: Node


func _initialize() -> void:
	_run.call_deferred()


func _process(_d: float) -> bool:
	return false


func _arg(name: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return def


func _frames(n: int) -> void:
	for i in n:
		await process_frame


static func sha(bytes: PackedByteArray) -> String:
	if bytes.is_empty():
		return "leer"
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(bytes)
	return h.finish().hex_encode()


func _launch(gfx_mode: String, km: float, seed_value: int) -> Node:
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var setup := {"mode": "single", "race_id": "", "stage_id": "dev_testetappe", "from_city": "", "vehicle": "gran_turismo",
		"start_world_minutes": 21.0 * 60.0, "weather": "rain", "start_km": km, "autopilot": true, "seed": seed_value,
		"traffic_warmup": true, "start_speed_kmh": 0.0, "gfx": gfx_mode}
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	return sc


func _run() -> void:
	await _frames(5)
	_am = root.get_node("AudioManager")
	var pre := _arg("pre", "none")
	var frames := int(_arg("frames", "1500"))
	var notes: Array = []
	if pre != "none":
		if _am.has_method("set_profile"):
			_am.call("set_profile", "modern" if pre == "modern" else "arcade")
		var p := await _launch(pre, 80.0, 99)
		await _frames(200)
		notes.append("vorher: %s, gfx %s, Klang %s" % [pre, str(p.get("gfx")) if "gfx" in p else "-",
			str(_am.call("profile")) if _am.has_method("profile") else "-"])
		p.queue_free()
		await _frames(3)
		_am.call("stop_all")
		if _am.has_method("set_profile"):
			_am.call("set_profile", "arcade")
		await _frames(3)
	var sc := await _launch("arcade", 40.0, 5)
	var sim := PackedFloat64Array()
	var eng := PackedFloat64Array()
	var handed := PackedFloat64Array()
	var traffic: Array = []
	var loops := PackedFloat64Array()
	var oneshots: Array = []
	var last_one := int(_am.get("_next_oneshot"))
	var per_frame_eng: Array = []
	for f in frames:
		await process_frame
		var v: Object = sc.get("vehicle")
		sim.append_array(PackedFloat64Array([float(sc.get("pos_z")), float(v.get("x")), float(v.get("speed")), float(sc.get("stage_time"))]))
		var es: Dictionary = _am.call("engine_state")
		eng.append_array(PackedFloat64Array([float(es.get("rpm", 0.0)), float(es.get("gear", 0)), float(es.get("load", 0.0)), float(es.get("boost", 0.0))]))
		if f % 100 == 0:
			per_frame_eng.append([f, var_to_str(float(es.get("rpm", 0.0))), int(es.get("gear", 0)), var_to_str(float(sc.get("pos_z")))])
		for k in ["_engine_speed", "_engine_throttle", "_engine_vmax", "_wind_speed", "_siren_dist", "_rain_explicit", "_skid_explicit",
				"_hint_rain", "_hint_skid", "_hint_siren"]:
			handed.append(float(_am.get(k)))
		handed.append(1.0 if _am.get("_engine_active") else 0.0)
		handed.append(1.0 if _am.get("_siren_on") else 0.0)
		handed.append(1.0 if _am.get("_tunnel") else 0.0)
		handed.append(float((_am.get("_traffic_vehicles") as Array).size()))
		var ts: Dictionary = _am.call("traffic_state")
		traffic.append(sha(var_to_bytes(ts)).left(12))
		var vol: Dictionary = _am.get("_vol")
		var vk: Array = vol.keys()
		vk.sort()
		for k2: Variant in vk:
			if str(k2) != "engine_on" and str(k2) != "engine_off":   # the fallback loops carry the smoothed pitch state
				loops.append(float(vol[k2]))
		var n1 := int(_am.get("_next_oneshot"))
		if n1 != last_one:
			var lp: Dictionary = _am.get("_last_play")
			var names: Array = lp.keys()
			names.sort()
			oneshots.append([f, n1, str(names)])
			last_one = n1
	var result: Dictionary = sc.call("build_result") if sc.has_method("build_result") else {}
	result.erase("gfx")
	var data := {"display": DisplayServer.get_name(), "pre": pre, "frames": frames, "notes": notes,
		"sim": sha(sim.to_byte_array()), "engine": sha(eng.to_byte_array()), "handed": sha(handed.to_byte_array()),
		"traffic": sha(var_to_bytes(traffic)), "loops": sha(loops.to_byte_array()), "oneshots": oneshots,
		"engine_samples": per_frame_eng, "result": var_to_str(result), "bus_count": AudioServer.bus_count,
		"final_km": var_to_str(float(sc.get("pos_z")) / 1000.0)}
	sc.queue_free()
	await _frames(3)
	_am.call("stop_all")
	var out := _arg("out", "")
	var f2 := FileAccess.open(out, FileAccess.WRITE)
	f2.store_string(JSON.stringify(data, "\t") + "\n")
	f2.close()
	print("RACE-AUDIO %s: sim %s engine %s handed %s traffic %s loops %s oneshots %d  km %s" % [pre, str(data["sim"]).left(10),
		str(data["engine"]).left(10), str(data["handed"]).left(10), str(data["traffic"]).left(10), str(data["loops"]).left(10),
		oneshots.size(), data["final_km"]])
	quit(0)
