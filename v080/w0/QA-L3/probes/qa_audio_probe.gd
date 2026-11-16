extends SceneTree
## QA lens 3 (wave 0): independent fingerprint of the Arcade sound. Runs on a tree of tag v0.7.0 and on the
## integrated tree (only API that exists since v0.7.0 is used statically; everything new goes through call()).
##   godot [--headless] --path <tree> --fixed-fps 60 -s <this> -- --out=<json> [--exercise=none|modern|modern_race]
##       [--switches=N]
## exercise=modern: before the fingerprint, N times: set_profile("modern"), a scripted burst of every API call,
##   set_profile("arcade").   exercise=modern_race: additionally a race stage (gfx modern, sound modern) per switch.
## Then, in every variant the same: static fingerprint + a scripted Arcade drive of 360 frames (per-frame state).

const SEED := 4242
const DT := 1.0 / 60.0
const CARS: Array[String] = ["gran_turismo", "kombi", "kompakt", "limousine", "sportwagen"]
const RACE := "res://scenes/race/race.tscn"

var _am: Node
var _out := ""
var _exercise := "none"
var _switches := 2
var _notes: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _process(_d: float) -> bool:
	return false


func _arg(name: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return def


static func sha(bytes: PackedByteArray) -> String:
	if bytes.is_empty():
		return "leer"
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(bytes)
	return h.finish().hex_encode()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


# --- fingerprints ---------------------------------------------------------------------------------

func bus_layout() -> Array:
	var out: Array = []
	for i in AudioServer.bus_count:
		var effects: Array = []
		for j in AudioServer.get_bus_effect_count(i):
			var fx := AudioServer.get_bus_effect(i, j)
			var params := {}
			for p: Dictionary in fx.get_property_list():
				var pname := str(p["name"])
				if (int(p["usage"]) & PROPERTY_USAGE_STORAGE) == 0 or pname == "script" or pname.begins_with("resource_"):
					continue
				params[pname] = var_to_str(fx.get(pname))
			effects.append({"class": fx.get_class(), "enabled": AudioServer.is_bus_effect_enabled(i, j), "params": params})
		out.append({"index": i, "name": AudioServer.get_bus_name(i), "send": str(AudioServer.get_bus_send(i)),
			"volume_db": var_to_str(AudioServer.get_bus_volume_db(i)), "mute": AudioServer.is_bus_mute(i),
			"solo": AudioServer.is_bus_solo(i), "bypass": AudioServer.is_bus_bypassing_effects(i),
			"channels": AudioServer.get_bus_channels(i), "effects": effects})
	return out


func stream_sig(s: Variant) -> Variant:
	if s == null:
		return null
	if s is AudioStreamWAV:
		var w: AudioStreamWAV = s
		return {"class": "AudioStreamWAV", "format": w.format, "loop_mode": w.loop_mode, "loop_begin": w.loop_begin,
			"loop_end": w.loop_end, "mix_rate": w.mix_rate, "stereo": w.stereo, "bytes": w.data.size(), "sha": sha(w.data)}
	if s is AudioStream:
		var a: AudioStream = s
		var d := {"class": a.get_class(), "path": a.resource_path, "length": var_to_str(a.get_length())}
		for k in ["loop", "loop_offset", "bpm", "beat_count", "bar_beats", "mix_rate", "buffer_length"]:
			if k in a:
				d[k] = var_to_str(a.get(k))
		return d
	return str(s)


## Children of a node as plain data (no auto-generated names): class, bus, stream, volume, pitch, playing.
func subtree(n: Node, depth: int = 0) -> Array:
	var out: Array = []
	for c in n.get_children():
		var d := {"class": c.get_class(), "depth": depth, "children": c.get_child_count()}
		if c.get_script() != null:
			d["script"] = (c.get_script() as Script).resource_path
		for k in ["bus", "volume_db", "pitch_scale", "playing", "max_distance", "attenuation", "panning_strength", "area_mask", "max_polyphony", "mix_target", "autoplay", "stream_paused"]:
			if k in c:
				d[k] = var_to_str(c.get(k))
		if "stream" in c:
			d["stream"] = stream_sig(c.get("stream"))
		if c is SubViewport:
			d["vp"] = [str((c as SubViewport).size), (c as SubViewport).audio_listener_enable_2d, (c as SubViewport).render_target_update_mode]
		out.append(d)
		out.append_array(subtree(c, depth + 1))
	return out


## Script variables of the AudioManager as plain data (objects by class, containers by size / content hash).
func am_vars() -> Dictionary:
	var out := {}
	for p: Dictionary in _am.get_property_list():
		if (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var k := str(p["name"])
		var v: Variant = _am.get(k)
		if v is float or v is int or v is bool or v is String:
			out[k] = var_to_str(v)
		elif v is Dictionary:
			var keys: Array = (v as Dictionary).keys()
			keys.sort()
			out[k] = {"dict_keys": str(keys)}
			if k == "_vol":
				out[k]["values"] = var_to_str(v)
		elif v is Array:
			out[k] = {"array_size": (v as Array).size()}
		elif v is PackedFloat32Array:
			out[k] = {"pf32": (v as PackedFloat32Array).size()}
		elif v is Object:
			out[k] = {"object": (v as Object).get_class(), "script": ((v as Object).get_script() as Script).resource_path if (v as Object).get_script() != null else ""}
		elif v == null:
			out[k] = null
		else:
			out[k] = var_to_str(v)
	return out


## The seeded mixer output of the bank the AudioManager caches (and every profile plays from).
func engine_hash(b: EngineBank, mixer_seed: int) -> Dictionary:
	var e := EngineAudio.new(b, mixer_seed)
	e.start(true)
	var out := PackedFloat32Array()
	var per := float(b.sample_rate) * DT
	var acc := 0.0
	var pos := 0
	var v := 0.0
	for i in 420:
		var thr := 1.0 if (i > 30 and i < 300 and (i / 40) % 5 != 4) else 0.0
		if thr > 0.0:
			v = minf(v + 55.0 * DT, 240.0)
		else:
			v = maxf(v - (25.0 if i < 360 else 120.0) * DT, 0.0)
		e.update(DT, v, thr, 250.0, true)
		acc += per
		var n := int(acc)
		acc -= n
		out.resize(pos + n)
		e.render(out, pos, n)
		pos += n
	e.fade_to(0.0, 0.1)
	var tail := int(0.2 * b.sample_rate)
	out.resize(pos + tail)
	e.render(out, pos, tail)
	return {"samples": out.size(), "sha": sha(out.to_byte_array()), "state": var_to_str(e.state())}


func bank_sig(b: EngineBank) -> Dictionary:
	var d := {}
	for p: Dictionary in b.get_property_list():
		if (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var k := str(p["name"])
		var v: Variant = b.get(k)
		if v is PackedFloat32Array:
			d[k] = sha((v as PackedFloat32Array).to_byte_array())
		elif v is PackedByteArray:
			d[k] = sha(v)
		elif v is Object:
			d[k] = (v as Object).get_class()
		else:
			d[k] = sha(var_to_bytes(v))
	return d


func traffic_sig() -> Dictionary:
	var t: Variant = _am.get("_traffic")
	if not (t is TrafficAudio):
		return {"none": true}
	var ta: TrafficAudio = t
	var sounds := {}
	for k: Variant in ta.sounds:
		var s: Object = ta.sounds[k]
		var d := {}
		for p: Dictionary in s.get_property_list():
			if (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
				continue
			var pk := str(p["name"])
			var v: Variant = s.get(pk)
			d[pk] = stream_sig(v) if v is AudioStream else var_to_str(v)
		sounds[str(k)] = d
	var classes := {}
	for ck: Variant in ta.classes:
		var co: Object = ta.classes[ck]
		var cd := {}
		for p: Dictionary in co.get_property_list():
			if (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
				cd[str(p["name"])] = var_to_str(co.get(str(p["name"])))
		classes[str(ck)] = cd
	var d2 := {"ok": ta.ok, "voice_count": ta.voice_count, "sounds": sounds, "classes": classes,
		"models": sha(var_to_bytes(ta.models)), "path": ta.path, "siren_stream": stream_sig(ta.siren_stream),
		"voices": ta.voices.size(), "state": sha(var_to_bytes(ta.state()))}
	var vars := {}
	for p: Dictionary in ta.get_property_list():
		if (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var pk := str(p["name"])
		var v: Variant = ta.get(pk)
		if v is float or v is int or v is bool or v is String:
			if not pk.begins_with("perf_") and pk != "_update_us":
				vars[pk] = var_to_str(v)
	d2["vars"] = vars
	return d2


func room_sig() -> Dictionary:
	var r: Variant = _am.get("_room")
	if not (r is RoomAudio):
		return {"none": true}
	var vars := {}
	for p: Dictionary in (r as Object).get_property_list():
		if (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var pk := str(p["name"])
		var v: Variant = (r as Object).get(pk)
		if v is float or v is int or v is bool or v is String or v is Vector2 or v is Vector3:
			vars[pk] = var_to_str(v)
	return vars


func counts() -> Dictionary:
	return {"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"buses": AudioServer.bus_count, "am_children": _am.get_child_count(), "root_children": root.get_child_count(),
		"tex_mem": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"buf_mem": int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)),
		"video_mem": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"aspect": root.content_scale_aspect, "msaa3d": root.msaa_3d, "scale3d": root.scaling_3d_scale,
		"shadow_atlas": root.positional_shadow_atlas_size, "use_hdr_2d": root.use_hdr_2d,
		"dir_shadow_size": int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size", -1))}


func static_fingerprint() -> Dictionary:
	var streams := {}
	var sd: Dictionary = _am.get("_streams")
	for k: Variant in sd:
		streams[str(k)] = stream_sig(sd[k])
	var engines := {}
	var banks := {}
	for car in CARS:
		var b: Variant = _am.call("bank_for", car)
		if b is EngineBank:
			banks[car] = bank_sig(b)
			engines[car] = engine_hash(b, SEED)
			banks[car + "_after_render"] = sha(var_to_bytes(bank_sig(b)))
		else:
			engines[car] = null
	return {"buses": bus_layout(), "streams": streams, "engines": engines, "banks": banks, "traffic": traffic_sig(),
		"room": room_sig(), "am_vars": am_vars(), "am_tree": subtree(_am), "sounds_ready": _am.get("sounds_ready")}


# --- the scripted Arcade drive --------------------------------------------------------------------

func _traffic_frame(i: int) -> Array:
	var z0 := 30.0 - 0.35 * i
	return [
		{"id": 1, "set": "traffic/truck_red", "z": z0 + 40.0, "x": 1.9, "length": 16.5, "speed": 88.0, "heavy": true},
		{"id": 2, "set": "traffic/sedan_blue", "z": z0, "x": -1.9, "length": 4.7, "speed": 120.0},
		{"id": 3, "set": "traffic/van_white", "z": z0 + 90.0, "x": 1.9, "length": 5.6, "speed": 105.0},
		{"id": -2, "set": "police/de", "z": -200.0 + 0.5 * i, "x": -1.9, "length": 4.8, "speed": 185.0},
	]


## 360 frames of the calls a race session makes, with the Arcade profile; returns per-frame states.
func arcade_drive() -> Dictionary:
	_am.call("stop_all")
	await _frames(2)
	_am.call("set_vehicle", "limousine")
	var eng := PackedFloat64Array()
	var internals := PackedFloat64Array()
	var traffic_hashes: Array = []
	var bus_fx := PackedFloat64Array()
	var per_var := {}
	var speed := 0.0
	for i in 360:
		var thr := 1.0 if (i < 200 and (i / 50) % 4 != 3) else 0.0
		speed = minf(speed + 40.0 * DT, 230.0) if thr > 0.0 else maxf(speed - 30.0 * DT, 0.0)
		_am.call("set_engine", speed, thr, 245.0, true)
		_am.call("set_wind", speed)
		_am.call("set_siren", i > 120 and i < 300, 0.6)
		if i % 90 < 45:
			_am.call("set_rain", 0.8)
		_am.call("set_skid", 0.6 if (i > 150 and i < 180) else 0.0)
		_am.call("set_traffic", _traffic_frame(i), {"z": 0.0, "x": 0.0, "speed": speed})
		_am.call("set_environment", {"tunnel": i > 100 and i < 220})
		_am.call("hud_hints", {"weather": "rain", "in_tunnel": i > 100 and i < 220, "understeer": 0.2,
			"police_state": "chase" if (i > 120 and i < 300) else "none", "police_gap_m": 150.0})
		if i == 60:
			_am.call("play", "crash")
		if i == 61:
			_am.call("play", "rail", -3.0)
		if i == 200:
			_am.call("play", "flash")
		if i == 250:
			paused = true
		if i == 262:
			paused = false
		await process_frame
		var es: Dictionary = _am.call("engine_state")
		eng.append_array(PackedFloat64Array([float(es.get("rpm", 0.0)), float(es.get("gear", 0)), float(es.get("load", 0.0)), float(es.get("boost", 0.0))]))
		for k in ["_throttle_s", "_pitch_s", "_gear", "_shift_dip", "_engine_speed", "_engine_throttle", "_wind_speed", "_siren_dist", "_rain_explicit", "_skid_explicit", "_hint_rain", "_hint_skid", "_hint_siren"]:
			internals.append(float(_am.get(k)))
			if not per_var.has(k):
				per_var[k] = PackedFloat64Array()
			(per_var[k] as PackedFloat64Array).append(float(_am.get(k)))
		var vol: Dictionary = _am.get("_vol")
		var vk: Array = vol.keys()
		vk.sort()
		for k2: Variant in vk:
			internals.append(float(vol[k2]))
			if not per_var.has("vol_" + str(k2)):
				per_var["vol_" + str(k2)] = PackedFloat64Array()
			(per_var["vol_" + str(k2)] as PackedFloat64Array).append(float(vol[k2]))
		var ts: Dictionary = _am.call("traffic_state")
		traffic_hashes.append(sha(var_to_bytes(ts)).left(16))
		# the room effects of the Arcade buses (tunnel blend) as they are in the AudioServer
		var ri := AudioServer.get_bus_index("Room")
		if ri >= 0:
			for j in AudioServer.get_bus_effect_count(ri):
				var fx := AudioServer.get_bus_effect(ri, j)
				if fx is AudioEffectReverb:
					bus_fx.append((fx as AudioEffectReverb).wet)
				elif fx is AudioEffectDelay:
					bus_fx.append((fx as AudioEffectDelay).tap1_level_db)
		for bi in AudioServer.bus_count:
			var bn := AudioServer.get_bus_name(bi)
			if bn.begins_with("TrafficV") or bn == "Siren":
				for j in AudioServer.get_bus_effect_count(bi):
					var fx2 := AudioServer.get_bus_effect(bi, j)
					if fx2 is AudioEffectLowPassFilter:
						bus_fx.append((fx2 as AudioEffectLowPassFilter).cutoff_hz)
	var players := subtree(_am)
	_am.call("stop_all")
	await _frames(3)
	var pv := {}
	for k3: String in per_var:
		var arr: PackedFloat64Array = per_var[k3]
		pv[k3] = {"sha": sha(arr.to_byte_array()), "n": arr.size()}
		if k3 == "_pitch_s" or k3 == "_throttle_s":
			var vals: Array = []
			for x in arr:
				vals.append(var_to_str(x))
			pv[k3]["values"] = vals
	return {"per_var": pv, "players_full": players, "engine": sha(eng.to_byte_array()), "engine_values": eng.size(), "internals": sha(internals.to_byte_array()),
		"internal_values": internals.size(), "traffic": sha(var_to_bytes(traffic_hashes)), "bus_fx": sha(bus_fx.to_byte_array()),
		"bus_fx_values": bus_fx.size(), "players_at_end": sha(var_to_bytes(players)), "players_at_end_n": players.size(),
		"last_engine": [eng[eng.size() - 4], eng[eng.size() - 3]]}


# --- exercising the Modern code paths (integrated tree only) --------------------------------------

func _modern_burst(i: int) -> void:
	_am.call("set_profile", "modern")
	_am.call("set_race_music", i % 2 == 0)
	_am.call("set_music_context", ["title", "menu", "race_menu", "race", "result", "off"][i % 6], {"stage": "kiel_hamburg"})
	_am.call("set_music", i % 2 == 1)
	for car in CARS:
		_am.call("preview_engine", car)
		await process_frame
	_am.call("set_vehicle", CARS[i % CARS.size()])
	_am.call("event", "stage_start", {"countdown_s": 3.0})
	for k in 90:
		_am.call("set_engine", 60.0 + 2.0 * k, 1.0 if k % 30 < 20 else 0.0, 245.0, true)
		_am.call("set_wind", 60.0 + 2.0 * k)
		_am.call("set_siren", k > 20, 0.7)
		_am.call("set_rain", 1.0)
		_am.call("set_skid", 0.7)
		_am.call("set_traffic", _traffic_frame(k), {"z": 0.0, "x": 0.0, "speed": 150.0})
		_am.call("set_environment", {"tunnel": k % 40 < 20})
		_am.call("hud_hints", {"weather": "rain", "understeer": 0.5, "police_state": "chase", "police_gap_m": 60.0})
		_am.call("set_vehicle_state", {"z": 1000.0 + 3.0 * k, "x": 0.5, "speed": 60.0 + 2.0 * k, "throttle": 1.0, "brake": 0.0,
			"steer": 0.1, "understeer": 0.2, "lat_speed": 0.3, "off_road": 0, "rail_contact": false, "road_left": -5.6,
			"road_right": 5.6, "shoulder_m": 2.5, "in_tunnel": k % 40 < 20, "weather": "rain", "hour": 12.0, "crash": false,
			"finished": false})
		if k == 10:
			for s in ["crash", "rail", "flash", "go", "beep", "finish", "fuel_start", "fuel_done", "ui_move", "ui_ok", "ui_back"]:
				_am.call("play", s)
		if k == 12:
			for e in ["countdown", "go", "collision", "rail_hit", "radar_flash", "chase_start", "escaped", "busted",
					"refuel_start", "refuel_done", "out_of_fuel", "tow", "stage_finish"]:
				_am.call("event", e, {"n": 1, "speed_kmh": 120.0, "heavy": true, "side": 1, "impact_mps": 4.0, "liters": 30.0,
					"record": true, "last_stage": false})
		if k == 40:
			paused = true
		if k == 46:
			paused = false
		await process_frame
	if i % 2 == 0:
		_am.call("stop_all")
	_am.call("set_profile", "arcade")
	await _frames(2)


func _modern_race(i: int, gfx_mode: String = "modern", sound: String = "modern") -> void:
	if _am.has_method("set_profile"):
		_am.call("set_profile", sound)
	var setup := {"mode": "single", "race_id": "", "stage_id": "dev_testetappe", "from_city": "", "vehicle": CARS[i % CARS.size()],
		"start_world_minutes": 12.0 * 60.0, "weather": ["rain", "normal", "snow"][i % 3], "start_km": 40.0 + i, "autopilot": true,
		"no_countdown": true, "seed": 7 + i, "traffic_warmup": true, "start_speed_kmh": 100.0, "gfx": gfx_mode}
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	await physics_frame
	root.add_child(sc)
	await _frames(150)
	_notes.append("race %d: gfx=%s renderer=%s profile=%s" % [i, str(sc.get("gfx")) if "gfx" in sc else "-",
		str((sc.get("renderer") as Object).get_script().resource_path).get_file() if sc.get("renderer") != null else "null",
		str(_am.call("profile")) if _am.has_method("profile") else "-"])
	sc.queue_free()
	await _frames(3)
	_am.call("stop_all")
	if _am.has_method("set_profile"):
		_am.call("set_profile", "arcade")
	await _frames(2)


func _run() -> void:
	await _frames(4)
	_am = root.get_node_or_null("AudioManager")
	_out = _arg("out", "")
	_exercise = _arg("exercise", "none")
	_switches = int(_arg("switches", "2"))
	var data := {"godot": Engine.get_version_info().get("string", ""), "display": DisplayServer.get_name(),
		"exercise": _exercise, "switches": _switches, "has_profiles": _am.has_method("set_profile")}
	data["counts_boot"] = counts()
	if _exercise == "arcade_race":
		for i in _switches:
			await _modern_race(i, "arcade", "arcade")
		await _frames(5)
	elif _exercise == "mixed_race":
		for i in _switches:
			await _modern_race(i, "modern" if i % 2 == 0 else "arcade", "arcade" if i % 4 < 2 else "modern")
		await _frames(5)
	elif _exercise != "none":
		if not _am.has_method("set_profile"):
			print("QA-PROBE FEHLER: dieser Baum kennt set_profile nicht")
			quit(2)
			return
		for i in _switches:
			await _modern_burst(i)
			if _exercise == "modern_race":
				await _modern_race(i)
		await _frames(5)
		data["profile_after"] = str(_am.call("profile"))
	if _arg("settle", "0") != "0":
		var until := Time.get_ticks_msec() + int(float(_arg("settle", "0")) * 1000.0)
		while Time.get_ticks_msec() < until:
			await process_frame
	if _arg("music", "0") != "0":
		_am.call("set_music", true)
		await _frames(3)
	data["counts_before_fingerprint"] = counts()
	data["static"] = static_fingerprint()
	data["drive"] = await arcade_drive()
	data["static_after_drive"] = {"buses": bus_layout(), "am_tree": subtree(_am), "traffic": traffic_sig(), "room": room_sig()}
	data["counts_end"] = counts()
	var until2 := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until2:
		await process_frame
	data["counts_end_settled"] = counts()
	if ClassDB.class_exists("ModernAudioContext") or _am.has_method("set_profile"):
		var mc: Variant = load("res://scripts/audio/modern/modern_audio_context.gd")
		if mc is GDScript:
			data["kept_streams_end"] = int((mc as GDScript).call("kept_count"))
	data["notes"] = _notes
	var text := JSON.stringify(data, "\t", true) + "\n"
	if _out == "":
		print(text)
	else:
		var f := FileAccess.open(_out, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	print("QA-PROBE geschrieben: %s (%d Busse, Übung %s × %d)" % [_out, AudioServer.bus_count, _exercise, _switches])
	quit(0)
