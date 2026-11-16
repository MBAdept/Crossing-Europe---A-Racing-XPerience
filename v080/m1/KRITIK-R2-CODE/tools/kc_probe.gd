extends SceneTree
## KRITIK-R2-CODE: runtime probes of RoadAudio / ImpactAudio without a scene tree (as the unit tests: ModernAudio not
## live, no players – stand-in players where the slab logic needs positions).
##   T1 frame rates 30 / 40 / 60 / 90 fps: slab locks per second, side drift spread, wind gust spread, mean power
##   T2 slab realignment with a drifting stand-in: the quiet loop is put back at the loud one's share
##   T3 pause: locks while paused, loops fade and stop
##   T4 NaN / INF sweep over speeds, surfaces, weather, understeer, events at 0 km/h
##   T5 squeal pitch: constant within one squeal; draws while inaudible
##   T6 stop_all: every stand-in player stopped
##   godot --headless --path <tree> -s <this> -- --graphics=arcade

class FakePlayer:
	extends Node
	var playing := false
	var volume_db := 0.0
	var pitch_scale := 1.0
	var pos := 0.0
	var length := 1.0
	var starts := 0
	var skew := 1.0

	func play(from_position: float = 0.0) -> void:
		playing = true
		pos = from_position
		starts += 1

	func stop() -> void:
		playing = false

	func get_playback_position() -> float:
		return pos

	func advance(dt: float) -> void:
		if playing:
			pos = fposmod(pos + dt * pitch_scale * skew, length)


var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _merge(into: Dictionary, over: Dictionary) -> void:
	for k: String in over:
		if over[k] is Dictionary and into.get(k, null) is Dictionary:
			_merge(into[k], over[k])
		else:
			into[k] = over[k]


func _modern(over: Dictionary = {}) -> ModernAudio:
	var c := ConfigLoader.load_merged().duplicate(true)
	_merge(c["audio"]["modern"], over)
	var m := ModernAudio.new()
	m.clock_ms = 1000
	m.start(c, {"live": false, "quiet": true})
	return m


func _frame(dt: float, speed: float, feed: Dictionary = {}, state: Dictionary = {}) -> ModernAudioFrame:
	var f := ModernAudioFrame.new()
	f.dt = dt
	f.alive = true
	f.speed = speed
	f.wind_speed = speed
	f.vmax = 230.0
	var fd := AudioFeed.new()
	fd.valid = true
	for k: String in feed:
		fd.set(k, feed[k])
	f.feed = fd
	if not state.is_empty():
		f.has_state = true
		f.state = state
	return f


func _fakes(r: RoadAudio, layers: Array) -> Array:
	var out: Array = []
	for l: RoadAudio.Layer in layers:
		for i in l.players.size():
			var p := FakePlayer.new()
			p.length = l.lengths[i]
			l.players[i] = p
			out.append(p)
	return out


func _unfake(layers: Array, fakes: Array) -> void:
	for l: RoadAudio.Layer in layers:
		for i in l.players.size():
			l.players[i] = null
	for p: FakePlayer in fakes:
		p.free()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print(("OK   " if ok else "FAIL ") + what)


func _stats(v: Array) -> Array:
	var mean := 0.0
	for x: float in v:
		mean += x
	mean /= maxf(v.size(), 1)
	var sd := 0.0
	for x: float in v:
		sd += (x - mean) * (x - mean)
	return [mean, sqrt(sd / maxf(v.size(), 1))]


func _bad(x: float) -> bool:
	return is_nan(x) or is_inf(x)


func _run() -> void:
	await process_frame
	var conc := {"surface_l": "concrete", "surface_r": "concrete", "paving": "concrete"}
	var long_run := CliArgs.has("long")
	var secs := 600.0 if long_run else 60.0
	# ---- T1 frame rates
	var rows := {}
	for fps: int in [30, 40, 60, 90]:
		var m := _modern()
		var r := m.road
		r.set_vehicle("limousine")
		var fakes := _fakes(r, [r.slab_slow, r.slab_fast])
		var dt := 1.0 / fps
		var n := int(secs * fps)
		var side: Array = []
		var gust: Array = []
		var power := 0.0
		var cnt := 0
		for i in n:
			var f := _frame(dt, 130.0, conc)
			r.update(f)
			for p: FakePlayer in fakes:
				p.advance(dt)
			if i * dt >= 2.0:
				var c: RoadAudio.Layer = r.surfaces["concrete"]
				if c.gains[0] > 0.0 and c.gains[1] > 0.0:
					side.append(20.0 * log(c.gains[0] / c.gains[1]) / log(10.0))
					power += c.gains[0] * c.gains[0] + c.gains[1] * c.gains[1]
					cnt += 1
				var w: RoadAudio.Layer = r.winds["wind_mid"]
				if w.gains[0] > 0.0:
					gust.append(20.0 * log(w.gains[0]) / log(10.0))
		var ss := _stats(side)
		var gs := _stats(gust)
		rows[fps] = {"locks_per_s": snappedf(r.slab_locks / secs, 0.001), "locks": r.slab_locks,
			"starts": [fakes[0].starts, fakes[1].starts], "realigned": r.slab_realigned,
			"side_sd_db": snappedf(ss[1], 0.001), "gust_sd_db": snappedf(gs[1], 0.001),
			"conc_power_db": snappedf(10.0 * log(power / maxf(cnt, 1)) / log(10.0), 0.001)}
		print("T1 ", fps, " fps ", JSON.stringify(rows[fps]))
		_unfake([r.slab_slow, r.slab_fast], fakes)
		m.shutdown()
		m.free()
	var lps: Array = []
	var sds: Array = []
	var pws: Array = []
	for fps: int in rows:
		lps.append(float(rows[fps]["locks_per_s"]))
		sds.append(float(rows[fps]["side_sd_db"]))
		pws.append(float(rows[fps]["conc_power_db"]))
	_check(lps.max() <= 2.1, "T1 at most about 2 locks per second at any frame rate %s" % str(lps))
	_check(sds.max() - sds.min() <= 0.3, "T1 side drift spread independent of the frame rate %s" % str(sds))
	_check(pws.max() - pws.min() <= 0.5, "T1 mean power of concrete independent of the frame rate %s" % str(pws))
	if long_run:
		print("PROBE DONE (long T1 only) fails=%d" % _fails)
		quit(0 if _fails == 0 else 1)
		return
	# ---- T2 realignment with a drifting stand-in (fast loop 5e-4 too fast)
	var m2 := _modern()
	var r2 := m2.road
	r2.set_vehicle("limousine")
	var f2 := _fakes(r2, [r2.slab_slow, r2.slab_fast])
	(f2[1] as FakePlayer).skew = 1.0005
	var dt2 := 1.0 / 60.0
	var max_err_ms := 0.0
	var after_realign_err := []
	var last_re := 0
	for i in int(60.0 * 60):
		r2.update(_frame(dt2, 130.0, conc))
		for p: FakePlayer in f2:
			p.advance(dt2)
		var d := fposmod(r2.slab_fast.share() - r2.slab_slow.share() + 0.5, 1.0) - 0.5
		var err := absf(d) * r2.slab_slow.length_s / maxf(r2.slab_slow.pitch, 0.01) * 1000.0
		max_err_ms = maxf(max_err_ms, err)
		if r2.slab_realigned != last_re:
			last_re = r2.slab_realigned
			after_realign_err.append(snappedf(err, 0.01))
	print("T2 realigned ", r2.slab_realigned, " max offset ms ", snappedf(max_err_ms, 0.01), " offset right after each realign ", after_realign_err)
	_check(r2.slab_realigned >= 3, "T2 a drifting pair is put back in step (%d times in 60 s)" % r2.slab_realigned)
	_check(max_err_ms <= r2._slab_align_ms + 3.0, "T2 the offset stays near slabs.align_ms (max %.2f ms)" % max_err_ms)
	var ok_after := true
	for e: float in after_realign_err:
		ok_after = ok_after and e < 0.5
	_check(ok_after, "T2 right after a realignment the loops are in step")
	_unfake([r2.slab_slow, r2.slab_fast], f2)
	m2.shutdown()
	m2.free()
	# ---- T3 pause
	var m3 := _modern()
	var r3 := m3.road
	r3.set_vehicle("limousine")
	var all3: Array = r3._all_layers()
	var f3 := _fakes(r3, all3)
	for i in 300:
		r3.update(_frame(1.0 / 60.0, 130.0, conc))
		for p: FakePlayer in f3:
			p.advance(1.0 / 60.0)
	var playing_before := 0
	for p: FakePlayer in f3:
		playing_before += 1 if p.playing else 0
	var locks0 := r3.slab_locks
	var pf := _frame(1.0 / 60.0, 130.0, conc)
	pf.paused = true
	pf.alive = false
	var frames_to_silence := -1
	for i in 600:
		r3.update(pf)
		var any := false
		for p: FakePlayer in f3:
			any = any or p.playing
		if not any and frames_to_silence < 0:
			frames_to_silence = i + 1
	var locks_paused := r3.slab_locks - locks0
	print("T3 playing before pause ", playing_before, ", frames until all stopped ", frames_to_silence, ", locks while paused (10 s) ", locks_paused)
	_check(frames_to_silence > 0 and frames_to_silence <= 90, "T3 every loop stops within 1.5 s of the pause (%d frames)" % frames_to_silence)
	_check(locks_paused <= 2, "T3 at most 2 AudioServer locks in 10 s of pause (%d)" % locks_paused)
	# ---- T6 stop_all (resume first)
	for i in 120:
		r3.update(_frame(1.0 / 60.0, 130.0, conc))
	m3.stop_all()
	var still := 0
	for p: FakePlayer in f3:
		still += 1 if p.playing else 0
	_check(still == 0, "T6 stop_all stops every loop (%d still playing)" % still)
	_unfake(all3, f3)
	m3.shutdown()
	m3.free()
	# ---- T4 NaN sweep
	var m4 := _modern()
	var r4 := m4.road
	r4.set_vehicle("kompakt")
	var nan := 0
	var cases := 0
	for sp: float in [0.0, 0.3, 1.0, 5.0, 15.0, 40.0, 100.0, 149.9, 150.0, 151.0, 200.0, 260.0, 400.0]:
		for s: String in ["asphalt", "concrete", "cobbles", "deck", "rumble", "shoulder", "grass"]:
			for wx: Array in [[0.0, 0.0], [1.0, 0.0], [0.0, 1.0]]:
				for us: float in [0.0, 0.003, 1.0]:
					var fr := _frame(1.0 / 40.0, sp, {"surface_l": s, "surface_r": "asphalt", "wet": wx[0], "snow": wx[1], "zone": "tunnel" if sp > 300 else "open"},
						{"understeer": us, "lat_speed": 30.0 if us > 0.5 else 0.0, "crash": us > 0.5})
					for k in 3:
						r4.update(fr)
					cases += 1
					var lv := r4.levels()
					for id: String in lv:
						for x: float in lv[id]:
							nan += 1 if _bad(x) else 0
					r4.event("joint", {"deck": "steel", "kind": "bridge_end"})
					r4.event("pass_object", {"kind": "tree", "side": 1, "dist_m": 0.0, "size": 0.0})
					if not r4.last_joint.is_empty() and _bad(float(r4.last_joint.get("pitch", 0.0))):
						nan += 1
	var im := m4.impact
	for rel: float in [0.0, -0.0, 0.01, -50.0, 1000.0]:
		m4.event("collision", {"speed_kmh": 0.0, "rel_kmh": rel, "heavy": rel > 100.0, "side": 0})
		for row: Array in im.last_layers:
			for x: Variant in row:
				if (x is float) and _bad(float(x)):
					nan += 1
		m4.event("rail_hit", {"impact_mps": rel, "side": -1})
	_check(nan == 0, "T4 no NaN/INF in %d cases (found %d)" % [cases, nan])
	m4.shutdown()
	m4.free()
	# ---- T5 squeal pitch: constant within one squeal
	var m5 := _modern()
	var r5 := m5.road
	r5.set_vehicle("kombi")
	var changes_audible := 0
	var draws_inaudible := 0
	for ev in 20:
		var last := -1.0
		var us := 0.8 if ev % 2 == 0 else 0.004
		for i in 60:
			var before := r5.squeal_factor
			r5.update(_frame(1.0 / 60.0, 110.0, {}, {"understeer": us}))
			if r5.squeal.level >= 0.0005:
				if last >= 0.0 and absf(r5.squeal_factor - last) > 1e-9:
					changes_audible += 1
				last = r5.squeal_factor
			elif absf(r5.squeal_factor - before) > 1e-9:
				draws_inaudible += 1
		for i in 120:
			r5.update(_frame(1.0 / 60.0, 110.0, {}, {"understeer": 0.0}))
	print("T5 pitch changes during an audible squeal: ", changes_audible, ", redraws while inaudible: ", draws_inaudible)
	_check(changes_audible == 0, "T5 one pitch per audible squeal")
	m5.shutdown()
	m5.free()
	print("PROBE DONE fails=%d" % _fails)
	quit(0 if _fails == 0 else 1)
