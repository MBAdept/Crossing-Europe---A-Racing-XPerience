extends SceneTree
## Scratch tool of AU-B (not part of the repo): offline render of the engine of one car over a scripted drive or over
## steady points, with the Arcade engine (EngineAudio, mono) or the Modern engine v3 (EngineAudio3.Unit, stereo).
## No AudioServer: the mixers' render() is called directly with a fixed frame time of 1/60 s.
##   godot --headless --path <repo> -s <this file> -- --car=kompakt --profile=modern --scenario=drive --out=/abs/x.wav
##   --scenario=steady --rpms=1000,2000,... --loads=1,0.25,0 --seconds=3
##   --bank-dir=<dir with <car>.json/.i16> (Modern; default res://assets/audio/modern/engines)
##   --seed=N  --motion=0 (switch the slow movement off)  --layers (log the vehicle layers into the trace)
## Output: <out> (16 bit, bank rate, stereo) and <out>.json (trace per frame, phases).

const DT := 1.0 / 60.0


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var car := str(args.get("car", "gran_turismo"))
	var profile := str(args.get("profile", "modern"))
	var scenario := str(args.get("scenario", "drive"))
	var out := str(args.get("out", "/tmp/e3.wav"))
	var seed_v := int(args.get("seed", "4711"))
	var cfg := ConfigLoader.load_merged()
	var spec := VehicleModel.resolve_spec(cfg, car)
	var vmax := float(spec.get("vmax_kmh", 245.0))
	var sr := 32000
	var arc: EngineAudio = null
	var unit: EngineAudio3.Unit = null
	var t0 := Time.get_ticks_msec()
	if profile == "arcade":
		var bank := EngineBank.load_file("res://assets/audio/engines/%s.json" % car)
		if not bank.ok():
			print("FEHLER Arcade-Bank: ", bank.errors)
			quit(1)
			return
		arc = EngineAudio.new(bank, seed_v)
		arc.level = db_to_linear(float(ConfigLoader.lookup(cfg, "audio.engine_db", -3.0)))
		sr = bank.sample_rate
	else:
		var dir := str(args.get("bank-dir", "res://assets/audio/modern/engines"))
		var bank2 := EngineBank2.load_file(dir.path_join(car + ".json"))
		if not bank2.ok():
			print("FEHLER Bank v3: ", bank2.errors)
			quit(1)
			return
		for w in bank2.warnings:
			print("Hinweis Bank: ", w)
		unit = EngineAudio3.Unit.new(car, bank2, seed_v)
		unit.mix.level = db_to_linear(float(ConfigLoader.lookup(cfg, "audio.modern.engine.level_db", 0.0)))
		if args.has("motion") and str(args["motion"]) == "0":
			unit.mix.motion_rpm = 0.0
			unit.mix.motion_level_db = 0.0
			unit.mix.motion_load = 0.0
			unit.mix.motion_cycle_db = 0.0
			unit.mix.motion_rpm_slow = 0.0
			unit.mix.motion_level_slow_db = 0.0
			unit.mix.motion_load_slow = 0.0
		sr = bank2.sample_rate
	var load_ms := Time.get_ticks_msec() - t0
	var pcm := PackedByteArray()
	var trace := {"car": car, "profile": profile, "scenario": scenario, "sample_rate": sr, "dt": DT, "vmax": vmax, "load_ms": load_ms,
		"t": [], "speed": [], "throttle": [], "rpm": [], "gear": [], "load": [], "boost": [], "phases": [], "layers": []}
	var layers: VehicleLayers = null
	var lctx: ModernAudioContext = null
	var lframe: ModernAudioFrame = null
	if unit != null and args.has("layers"):
		lctx = ModernAudioContext.new()
		lctx.cfg = cfg
		var mo: Variant = ConfigLoader.lookup(cfg, "audio.modern", {})
		lctx.modern = mo if mo is Dictionary else {}
		lctx.live = false
		lctx.assets = ModernAudioAssets.new()
		lctx.assets.load_all(str(args.get("assets-dir", ModernAudioAssets.ROOT)))
		layers = VehicleLayers.new()
		layers.setup(lctx)
		if args.has("bank-dir"):
			layers.set("bank_dir", str(args["bank-dir"]))
		layers.set_vehicle(car)
		lframe = ModernAudioFrame.new()
	var us_render := 0
	var frames_total := 0
	var buf2 := PackedVector2Array()
	var buf1 := PackedFloat32Array()
	if scenario == "steady":
		var rpms := str(args.get("rpms", "1000,2000,3000,4000,5000,6000")).split(",")
		var loads := str(args.get("loads", "1")).split(",")
		var seconds := float(args.get("seconds", "3"))
		var n := int(seconds * sr)
		var t := 0.0
		for ld in loads:
			for r in rpms:
				var rpm := float(r)
				var load := float(ld)
				if unit != null:
					unit.mix.reset()
					unit.mix.set_manual(rpm, load, load, 1.0)
					unit.mix.start(false)
					buf2.resize(n)
					# skip the fade-in of the cycle sound
					unit.mix.render(buf2, 0, int(0.5 * sr))
					var u0 := Time.get_ticks_usec()
					unit.mix.render(buf2, 0, n)
					us_render += Time.get_ticks_usec() - u0
					_append2(pcm, buf2, n)
				else:
					arc.reset()
					arc.set_manual(rpm, load)
					arc.start(false)
					buf1.resize(n)
					arc.render(buf1, 0, int(0.5 * sr))
					var u1 := Time.get_ticks_usec()
					arc.render(buf1, 0, n)
					us_render += Time.get_ticks_usec() - u1
					_append1(pcm, buf1, n)
				frames_total += n
				trace["phases"].append({"name": "rpm%d_load%d" % [int(rpm), int(round(load * 100.0))], "t0": t, "t1": t + seconds, "rpm": rpm, "load": load})
				t += seconds
	else:
		var tl := _timeline(scenario, spec, vmax)
		var steps: Array = tl["steps"]
		trace["phases"] = tl["phases"]
		if unit != null:
			unit.reset()
		else:
			arc.reset()
		var started := false
		for i in steps.size():
			var st: Array = steps[i]
			var speed := float(st[0])
			var thr := float(st[1])
			var active := bool(st[2])
			var n := int(float(i + 1) * sr * DT) - int(float(i) * sr * DT)
			var state: Dictionary
			if unit != null:
				if not started:
					started = true
					unit.start(speed < 20.0 and not args.has("no-start-clip"))
					unit.mix.fade_to(1.0, 0.01)
				unit.update(DT, speed, thr, vmax, active)
				state = unit.state()
				if buf2.size() != n:
					buf2.resize(n)
				var u0 := Time.get_ticks_usec()
				unit.mix.render(buf2, 0, n)
				us_render += Time.get_ticks_usec() - u0
				_append2(pcm, buf2, n)
				if layers != null:
					lframe.dt = DT
					lframe.time = i * DT
					lframe.alive = true
					lframe.speed = speed
					lframe.throttle = thr
					lframe.vmax = vmax
					lframe.active = active
					lframe.engine = state
					layers.update(lframe)
					trace["layers"].append(layers.call("trace_row"))
			else:
				if not started:
					started = true
					arc.start(speed < 20.0 and not args.has("no-start-clip"))
				arc.update(DT, speed, thr, vmax, active)
				state = arc.state()
				if buf1.size() != n:
					buf1.resize(n)
				var u1 := Time.get_ticks_usec()
				arc.render(buf1, 0, n)
				us_render += Time.get_ticks_usec() - u1
				_append1(pcm, buf1, n)
			frames_total += n
			trace["t"].append(snappedf(i * DT, 0.0001))
			trace["speed"].append(snappedf(speed, 0.01))
			trace["throttle"].append(snappedf(thr, 0.001))
			trace["rpm"].append(snappedf(float(state["rpm"]), 0.1))
			trace["gear"].append(int(state["gear"]))
			trace["load"].append(snappedf(float(state["load"]), 0.001))
			trace["boost"].append(snappedf(float(state["boost"]), 0.001))
	trace["render_ms"] = us_render / 1000.0
	trace["ms_per_frame60"] = us_render / 1000.0 / maxf(float(frames_total), 1.0) * sr / 60.0
	if unit != null:
		trace["clips_started"] = unit.mix.clips_started
		trace["counters"] = unit.state()
	else:
		trace["clips_started"] = arc.clips_started
	_write_wav(out, pcm, sr)
	var f := FileAccess.open(out + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(trace))
	f.close()
	print("e3render: %s %s %s -> %s (%.1f s Klang, Rendern %.0f ms = %.3f ms je 1/60 s, Bank geladen in %d ms)" % [car, profile, scenario,
		out, float(frames_total) / sr, us_render / 1000.0, float(trace["ms_per_frame60"]), load_ms])
	if layers != null:
		layers.teardown()
	quit(0)


func _append2(pcm: PackedByteArray, buf: PackedVector2Array, n: int) -> void:
	var at := pcm.size()
	pcm.resize(at + n * 4)
	for k in n:
		var v := buf[k]
		pcm.encode_s16(at + k * 4, clampi(int(round(v.x * 32767.0)), -32768, 32767))
		pcm.encode_s16(at + k * 4 + 2, clampi(int(round(v.y * 32767.0)), -32768, 32767))


func _append1(pcm: PackedByteArray, buf: PackedFloat32Array, n: int) -> void:
	var at := pcm.size()
	pcm.resize(at + n * 4)
	for k in n:
		var s := clampi(int(round(buf[k] * 32767.0)), -32768, 32767)
		pcm.encode_s16(at + k * 4, s)
		pcm.encode_s16(at + k * 4 + 2, s)


func _write_wav(path: String, pcm: PackedByteArray, sr: int) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + pcm.size())
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)
	f.store_16(2)
	f.store_32(sr)
	f.store_32(sr * 4)
	f.store_16(4)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(pcm.size())
	f.store_buffer(pcm)
	f.close()


## The scripted drives: [[speed km/h, throttle, active], …] per frame and the phases.
func _timeline(scenario: String, spec: Dictionary, vmax: float) -> Dictionary:
	var steps: Array = []
	var phases: Array = []
	var a0 := float(spec["accel_a0"])
	var q := float(spec["accel_q"])
	var v := 0.0
	var t_phase := 0.0
	var ctx := {"steps": steps, "phases": phases}

	var hold := func(name: String, seconds: float, speed: float, thr: float) -> void:
		var t_a := steps.size() * DT
		for i in int(round(seconds / DT)):
			steps.append([speed, thr, true])
		phases.append({"name": name, "t0": t_a, "t1": steps.size() * DT, "v0": speed, "v1": speed})

	if scenario == "drive":
		# 1 start and idle
		hold.call("idle", 4.0, 0.0, 0.0)
		# 2 two blips in neutral (as a player does during the countdown)
		var t_a := steps.size() * DT
		for i in int(round(3.2 / DT)):
			var tt := i * DT
			var on := (tt >= 0.2 and tt < 0.5) or (tt >= 1.5 and tt < 2.0)
			steps.append([0.0, 1.0 if on else 0.0, true])
		phases.append({"name": "revs", "t0": t_a, "t1": steps.size() * DT, "v0": 0.0, "v1": 0.0})
		# 3 full throttle through the gears
		t_a = steps.size() * DT
		var v_top := minf(205.0, vmax * 0.9)
		v = 0.0
		var n := 0
		while v < v_top and n < int(30.0 / DT):
			v = VehicleModel.curve_speed(VehicleModel.curve_time(v, vmax, a0, q) + DT, vmax, a0, q)
			steps.append([v, 1.0, true])
			n += 1
		phases.append({"name": "pull", "t0": t_a, "t1": steps.size() * DT, "v0": 0.0, "v1": v})
		# 4 cruise at 200 (or what the car reached)
		var v_hi := minf(v, 200.0)
		t_a = steps.size() * DT
		for i in int(round(6.0 / DT)):
			v = move_toward(v, v_hi, 20.0 * DT)
			steps.append([v, 0.45, true])
		phases.append({"name": "cruise_hi", "t0": t_a, "t1": steps.size() * DT, "v0": v_hi, "v1": v_hi})
		# 5 lift off
		t_a = steps.size() * DT
		var v0 := v
		for i in int(round(2.5 / DT)):
			v = maxf(v - 7.0 * DT, 0.0)
			steps.append([v, 0.0, true])
		phases.append({"name": "lift", "t0": t_a, "t1": steps.size() * DT, "v0": v0, "v1": v})
		# 6 brake down to 130: downshifts
		t_a = steps.size() * DT
		v0 = v
		while v > 130.0:
			v = maxf(v - 30.0 * DT, 130.0)
			steps.append([v, 0.0, true])
		for i in int(round(0.6 / DT)):
			steps.append([v, 0.0, true])
		phases.append({"name": "brake", "t0": t_a, "t1": steps.size() * DT, "v0": v0, "v1": v})
		# 7 cruise at 130
		hold.call("cruise_130", 6.0, 130.0, 0.22)
		# 8 kick-down
		t_a = steps.size() * DT
		v0 = v
		for i in int(round(3.5 / DT)):
			v = VehicleModel.curve_speed(VehicleModel.curve_time(v, vmax, a0, q) + DT, vmax, a0, q)
			steps.append([v, 1.0, true])
		phases.append({"name": "kickdown", "t0": t_a, "t1": steps.size() * DT, "v0": v0, "v1": v})
		# 9 lift, 10 brake to a stop, idle
		t_a = steps.size() * DT
		v0 = v
		for i in int(round(2.0 / DT)):
			v = maxf(v - 7.0 * DT, 0.0)
			steps.append([v, 0.0, true])
		phases.append({"name": "lift2", "t0": t_a, "t1": steps.size() * DT, "v0": v0, "v1": v})
		t_a = steps.size() * DT
		v0 = v
		while v > 0.0:
			v = maxf(v - 32.0 * DT, 0.0)
			steps.append([v, 0.0, true])
		for i in int(round(2.0 / DT)):
			steps.append([0.0, 0.0, true])
		phases.append({"name": "stop", "t0": t_a, "t1": steps.size() * DT, "v0": v0, "v1": 0.0})
	elif scenario == "sweep":
		# slow full-load pull in a high gear: no start clip, from 60 km/h for 30 s, then lift for 6 s
		hold.call("roll", 1.0, 60.0, 0.3)
		var t_a := steps.size() * DT
		v = 60.0
		for i in int(round(40.0 / DT)):
			v = minf(v + 5.0 * DT, vmax * 0.97)
			steps.append([v, 1.0, true])
		phases.append({"name": "sweep_on", "t0": t_a, "t1": steps.size() * DT, "v0": 60.0, "v1": v})
		t_a = steps.size() * DT
		var v0 := v
		for i in int(round(20.0 / DT)):
			v = maxf(v - 9.0 * DT, 40.0)
			steps.append([v, 0.0, true])
		phases.append({"name": "sweep_off", "t0": t_a, "t1": steps.size() * DT, "v0": v0, "v1": v})
	elif scenario == "cruise":
		# long constant motorway speeds (tonal fatigue): 60 s at 130, 60 s at 200
		hold.call("roll", 2.0, 130.0, 0.5)
		hold.call("cruise_130", 60.0, 130.0, 0.22)
		hold.call("cruise_200", 60.0, minf(200.0, vmax * 0.85), 0.45)
	elif scenario == "limiter":
		hold.call("idle", 1.0, 0.0, 0.0)
		hold.call("limiter", 4.0, 0.0, 1.0)
		hold.call("fall", 3.0, 0.0, 0.0)
	return ctx
