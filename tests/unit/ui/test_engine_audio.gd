extends TestCase
## EngineAudio mixing core (engine sound v2, docs/motorsound.md §4) with the fixture bank
## tests/fixtures/engines/fixture_v4 (16 kHz, 2000–3900/min, deliberately different cycle variants):
## bounded/finite output, variants, pitch, click-free cycle boundaries, continuity over rpm sweeps, load
## blend, limiter pattern, layers (crackles, blow-off, shift crack, start clip), fades, CPU time per frame.

const FIXTURE := "res://tests/fixtures/engines/fixture_v4.json"
const DT := 1.0 / 60.0


func _bank() -> EngineBank:
	var b := EngineBank.load_file(FIXTURE)
	assert_true(b.ok(), "Fixture lädt: %s" % str(b.errors))
	return b


func _engine(seed: int = 1) -> EngineAudio:
	return EngineAudio.new(_bank(), seed)


func _render(e: EngineAudio, seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * e.bank.sample_rate))
	e.render(out, 0, out.size())
	return out


## Drives the gearbox like a frame loop: n frames of (speed, throttle), rendering each frame's samples.
func _drive(e: EngineAudio, out: PackedFloat32Array, frames: Array) -> void:
	var per := float(e.bank.sample_rate) * DT
	var acc := 0.0
	var pos := out.size()
	for f in frames:
		e.update(DT, float(f[0]), float(f[1]), 230.0, true)
		acc += per
		var n := int(acc)
		acc -= n
		out.resize(pos + n)
		e.render(out, pos, n)
		pos += n


func _peak(b: PackedFloat32Array, from: int = 0, to: int = -1) -> float:
	var m := 0.0
	for i in range(from, b.size() if to < 0 else to):
		m = maxf(m, absf(b[i]))
	return m


func _rms(b: PackedFloat32Array, from: int, to: int) -> float:
	var s := 0.0
	for i in range(from, to):
		s += b[i] * b[i]
	return sqrt(s / maxf(to - from, 1))


func _max_step(b: PackedFloat32Array, from: int = 1, to: int = -1) -> float:
	var m := 0.0
	for i in range(maxi(from, 1), b.size() if to < 0 else to):
		m = maxf(m, absf(b[i] - b[i - 1]))
	return m


## Largest sample-to-sample step inside the cycles of bank index bi (the signal's own steepness).
func _bank_step(b: EngineBank, bi: int) -> float:
	var m := 0.0
	for v in b.var_count[bi]:
		var off := b.cyc_off[b.var_first[bi] + v]
		var ln := b.cyc_len[b.var_first[bi] + v]
		for i in range(off + 1, off + ln):
			m = maxf(m, absf(b.data[i] - b.data[i - 1]))
	return m


## Largest jump a hard splice of two different variants would produce at the cycle boundary.
func _splice_jump(b: EngineBank, bi: int) -> float:
	var p := int(round(b.periods[bi]))
	var m := 0.0
	for k in b.var_count[bi]:
		for j in b.var_count[bi]:
			if j != k:
				var end := b.data[b.cyc_off[b.var_first[bi] + k] + p - 1]
				var head := b.data[b.cyc_off[b.var_first[bi] + j]]
				m = maxf(m, absf(head - end))
	return m


## Speed/throttle frames of a scripted drive: idle, revs at a standstill, full-throttle run, lift, braking.
func _script() -> Array:
	var frames: Array = []
	var spec := VehicleModel.resolve_spec(cfg(), "kompakt")
	for i in 60:
		frames.append([0.0, 0.0])
	for i in 70:
		frames.append([0.0, 1.0 if (i / 18) % 2 == 0 else 0.0])
	var v := 0.0
	for i in 600:
		v = VehicleModel.curve_speed(VehicleModel.curve_time(v, 230.0, float(spec["accel_a0"]), float(spec["accel_q"])) + DT,
			230.0, float(spec["accel_a0"]), float(spec["accel_q"]))
		frames.append([v, 1.0])
	for i in 120:
		v -= 5.0 * DT
		frames.append([v, 0.0])
	while v > 0.0:
		v = maxf(0.0, v - 70.0 * DT)
		frames.append([v, 0.0])
	for i in 60:
		frames.append([0.0, 0.0])
	return frames


func test_output_is_finite_and_within_unity() -> void:
	var e := _engine(3)
	e.start(true)
	var out := PackedFloat32Array()
	_drive(e, out, _script())
	var bad := 0
	for x in out:
		if is_nan(x) or is_inf(x):
			bad += 1
	assert_eq(bad, 0, "kein NaN/inf")
	assert_true(_peak(out) <= 1.0, "Spitze <= 1 (%.3f)" % _peak(out))
	assert_true(_peak(out) > 0.1, "hörbar")
	# far too loud on purpose: the soft limit keeps it below 1
	var hot := _engine(4)
	hot.level = 8.0
	hot.set_manual(3000.0, 1.0)
	var o2 := _render(hot, 0.5)
	assert_true(_peak(o2) <= 1.0, "übersteuert: Spitze <= 1 (%.4f)" % _peak(o2))
	assert_true(_peak(o2) > EngineAudio.SOFT, "Begrenzer greift")


func test_variants_random_never_twice_in_a_row() -> void:
	var e := _engine(5)
	e.debug_wraps = true
	e.debug_bank = 2 * 1 + 1
	e.set_manual(2500.0, 1.0)
	_render(e, 4.0)
	var log := e.variants_log
	assert_true(log.size() > 50, "genug Zyklen (%d)" % log.size())
	var seen := {}
	for i in log.size():
		seen[log[i]] = true
		if i > 0:
			assert_true(log[i] != log[i - 1], "nie dieselbe Variante zweimal hintereinander")
	assert_eq(seen.size(), e.bank.var_count[3], "alle Varianten kommen vor")


func test_cycle_length_follows_rpm() -> void:
	for rpm: float in [2000.0, 2300.0, 2800.0, 3500.0, 3900.0]:
		var e := _engine(6)
		e.debug_wraps = true
		e.set_manual(rpm, 0.5)
		_render(e, 1.5)
		var w := e.wraps
		var expect := 120.0 / rpm * e.bank.sample_rate
		var span := float(w[w.size() - 1] - w[1]) / float(w.size() - 2)
		assert_near(span, expect, 0.5, "Zykluslänge bei %d/min" % int(rpm))
		for i in range(2, w.size()):
			assert_near(float(w[i] - w[i - 1]), expect, 1.01, "jeder Zyklus bei %d/min" % int(rpm))


func test_no_clicks_at_cycle_boundaries() -> void:
	var b := _bank()
	# 3125/min, load 0: exactly one bank (off, no noise burst) -> the output is that bank × off_gain
	var bi := 2 * 2
	var own := _bank_step(b, bi)
	var naive := _splice_jump(b, bi)
	assert_true(naive > 2.5 * own, "Fixture: Varianten absichtlich verschieden (Sprung %.3f, Steilheit %.3f)" % [naive, own])
	var e := EngineAudio.new(b, 7)
	e.debug_wraps = true
	e.set_manual(3125.0, 0.0)
	var out := _render(e, 3.0)
	var worst := 0.0
	for w in e.wraps:
		if w > 2 and w + 40 < out.size():
			worst = maxf(worst, _max_step(out, w - 2, w + 40))
	var g := b.off_gain
	assert_true(e.wraps.size() > 50, "viele Zyklusgrenzen")
	# crossfade over (overlap - 4) samples with smoothstep: at most 1.5 / (overlap - 4) of the jump per sample
	var bound := g * (own + naive * 1.5 / float(b.overlaps[bi] - 4)) * 1.05 + 0.0005
	assert_true(worst <= bound, "Zyklusgrenzen ohne Klick (%.4f <= %.4f)" % [worst, bound])
	assert_true(worst < 0.5 * g * naive, "deutlich unter dem harten Schnitt (%.4f vs %.4f)" % [worst, g * naive])
	# between two rpm points (two banks, read steps != 1)
	var e2 := EngineAudio.new(b, 8)
	b.idle_load = 0.0
	e2.set_manual(2800.0, 0.0)
	var out2 := _render(e2, 2.0)
	var own2 := maxf(_bank_step(b, 2 * 1), _bank_step(b, 2 * 2)) * 2800.0 / 2500.0
	var naive2 := maxf(_splice_jump(b, 2 * 1), _splice_jump(b, 2 * 2))
	var bound2 := g * (own2 + naive2 * 1.5 / float(b.overlaps[bi] - 4)) * 1.1 + 0.0005
	assert_true(_max_step(out2) <= bound2, "zwischen zwei Drehzahlpunkten ohne Klick (%.4f <= %.4f)" % [_max_step(out2), bound2])


func test_continuous_over_rpm_sweep() -> void:
	var b := _bank()
	b.idle_load = 0.0
	var e := EngineAudio.new(b, 9)
	e.set_manual(2000.0, 0.0)
	var out := PackedFloat32Array()
	var per := int(b.sample_rate * DT)
	var frames := 240
	for f in frames * 2:
		var x := float(f) / frames
		var rpm := lerpf(1900.0, 4000.0, x if x <= 1.0 else 2.0 - x)
		e.set_manual(rpm, 0.0, false, DT)
		var at := out.size()
		out.resize(at + per)
		e.render(out, at, per)
	var steep := 0.0
	for bi in [0, 2, 4, 6]:
		steep = maxf(steep, _bank_step(b, bi))
	var jump := 0.0
	for bi in [0, 2, 4, 6]:
		jump = maxf(jump, _splice_jump(b, bi))
	# read steps up to 1.25 (between points) and 4000/3900 above the last point; crossfade term as above
	var bound := b.off_gain * (steep * 1.26 + jump * 1.5 / 28.0) * 1.1 + 0.001
	assert_true(_max_step(out) <= bound, "stetig über den Drehzahlverlauf (%.4f <= %.4f)" % [_max_step(out), bound])
	# no gaps: every 10 ms window carries signal. (Between two rpm points the fixture's deliberately different
	# variants of two banks can partly cancel, down to ~0.008 – a dropout would be ~0.)
	var win := int(0.01 * b.sample_rate)
	var quiet := 0
	for i in range(0, out.size() - win, win):
		if _rms(out, i, i + win) < 0.003:
			quiet += 1
	assert_eq(quiet, 0, "keine Aussetzer (10-ms-Fenster)")
	assert_true(_rms(out, 0, out.size()) > 0.03, "durchgehend hörbar")


func test_equal_power_load_blend() -> void:
	var b := _bank()
	b.idle_load = 0.0
	var rms := {}
	for load: float in [0.0, 0.5, 1.0]:
		var e := EngineAudio.new(b, 10)
		e.set_manual(3125.0, load)
		var out := _render(e, 1.0)
		rms[load] = _rms(out, 1000, out.size())
	assert_true(float(rms[1.0]) > float(rms[0.0]), "Last lauter als Schub")
	var mid := float(rms[0.5]) * float(rms[0.5])
	var avg := 0.5 * (float(rms[0.0]) * float(rms[0.0]) + float(rms[1.0]) * float(rms[1.0]))
	assert_between(mid / avg, 0.6, 1.4, "gleiche Leistung beim Überblenden (Energie %.4f vs %.4f)" % [mid, avg])


func test_limiter_cut_pattern() -> void:
	var e := _engine(11)
	e.debug_wraps = true
	e.set_manual(3900.0, 1.0, true)
	_render(e, 1.5)
	var g := e.gates_log
	var cut := int(e.bank.layer("limiter")["cut_cycles"])
	var on := int(e.bank.layer("limiter")["on_cycles"])
	assert_true(g.size() > 20, "genug Zyklen")
	for i in g.size():
		var want := 0 if (i % (cut + on)) < cut else 1
		if g[i] != want:
			fail("Muster %d aus / %d an: %s" % [cut, on, str(g.slice(0, 12))])
			break
	var e2 := _engine(12)
	e2.debug_wraps = true
	e2.set_manual(3900.0, 1.0, false)
	_render(e2, 0.5)
	for x in e2.gates_log:
		assert_eq(x, 1, "ohne Begrenzer immer gezündet")


func test_crackles_and_blowoff_after_lifting() -> void:
	# 5 s full throttle from a standstill through the gears (boost builds), then lift-off at speed
	var e := _engine(13)
	var out := PackedFloat32Array()
	var frames: Array = _script().slice(130, 430)
	_drive(e, out, frames)
	assert_true(e.state()["boost"] > 0.55, "Ladedruck aufgebaut (%.2f)" % float(e.state()["boost"]))
	assert_true(float(e.state()["rpm"]) > float(e.bank.layer("crackle")["min_rpm"]), "Drehzahl über min_rpm")
	assert_eq(int(e.clips_started.get("crackle", 0)), 0, "kein Knallen unter Last")
	assert_eq(int(e.clips_started.get("blowoff", 0)), 0, "keine Schubumluft beim Hochschalten")
	var v := float(frames[frames.size() - 1][0])
	frames = []
	for i in 90:
		v -= 5.0 * DT
		frames.append([v, 0.0])
	_drive(e, out, frames)
	assert_eq(int(e.clips_started.get("blowoff", 0)), 1, "Schubumluft beim Gaswegnehmen")
	assert_true(int(e.clips_started.get("crackle", 0)) >= 2, "Knallen nach dem Gaswegnehmen (%d)" % int(e.clips_started.get("crackle", 0)))
	assert_true(float(e.state()["boost"]) < 0.3, "Ladedruck abgebaut")
	# lifting below crackle.min_rpm: no crackles; above: crackles (mixer driven directly)
	for case in [[2300.0, 0], [3500.0, 1]]:
		var e2 := _engine(14)
		var buf := _buf(e2)
		for i in 150:
			e2.set_manual(float(case[0]), 1.0 if i < 60 else 0.0, false, DT)
			e2.render(buf, 0, buf.size())
		var pops := int(e2.clips_started.get("crackle", 0))
		if int(case[1]) == 0:
			assert_eq(pops, 0, "unter min_rpm kein Knallen")
		else:
			assert_true(pops >= 1, "über min_rpm Knallen (%d)" % pops)
	# revving at a standstill (no load on the engine) builds little boost
	var e3 := _engine(15)
	frames = []
	for i in 120:
		frames.append([0.0, 1.0])
	_drive(e3, PackedFloat32Array(), frames)
	assert_true(float(e3.state()["boost"]) < EngineAudio.NEUTRAL_BOOST + 0.01, "wenig Ladedruck im Stand (%.2f)" % float(e3.state()["boost"]))


func _buf(e: EngineAudio) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(e.bank.sample_rate * DT) + 1)
	return b


func test_shift_crack_and_whistle_on_full_throttle_run() -> void:
	var e := _engine(15)
	e.start(false)
	var out := PackedFloat32Array()
	var frames: Array = _script().slice(130, 730)
	var gears := {}
	var ups := 0
	var per := float(e.bank.sample_rate) * DT
	var acc := 0.0
	for f in frames:
		e.update(DT, float(f[0]), float(f[1]), 230.0, true)
		gears[int(e.state()["gear"])] = true
		if e.gearbox.ev_upshift:
			ups += 1
		acc += per
		var n := int(acc)
		acc -= n
		var at := out.size()
		out.resize(at + n)
		e.render(out, at, n)
	assert_true(ups >= 3, "hochgeschaltet (%d)" % ups)
	assert_true(int(e.clips_started.get("shift", 0)) >= 2, "Schaltknall bei Last")
	assert_true(e._w_amp > 0.0, "Turbopfeifen bei Ladedruck")


func test_start_clip_then_idle() -> void:
	var e := _engine(16)
	e.start(true)
	assert_eq(int(e.clips_started.get("start", 0)), 1, "Startclip")
	var out := PackedFloat32Array()
	var frames: Array = []
	for i in 90:
		frames.append([0.0, 0.0])
	_drive(e, out, frames)
	var sr := e.bank.sample_rate
	assert_true(_rms(out, 0, int(0.05 * sr)) > 0.01, "Anlasser hörbar")
	assert_true(_rms(out, int(1.2 * sr), int(1.5 * sr)) > 0.01, "danach Leerlauf")
	assert_near(float(e.state()["rpm"]), e.gearbox.idle_rpm, 20.0, "Leerlaufdrehzahl")
	assert_eq(int(e.state()["gear"]), 0, "neutral")


func test_fade_out_goes_silent() -> void:
	var e := _engine(17)
	e.set_manual(3000.0, 1.0)
	_render(e, 0.2)
	e.fade_to(0.0, 0.05)
	var out := _render(e, 0.12)
	assert_true(e.is_silent(), "ausgeblendet")
	assert_true(_peak(out, int(0.06 * e.bank.sample_rate)) < 0.0001, "danach still")
	assert_true(_max_step(out) < 0.2, "weich ausgeblendet")


func test_preview_blip_goes_up_and_back_to_idle() -> void:
	var e := _engine(18)
	e.start(false)
	var t := 0.0
	var top := 0.0
	var out := PackedFloat32Array()
	while t < EngineAudio.PREVIEW_S:
		var thr := EngineAudio.preview_throttle(t)
		_drive_one(e, out, 0.0, thr)
		top = maxf(top, float(e.state()["rpm"]))
		t += DT
	var gb := e.gearbox
	assert_true(top > gb.idle_rpm + 0.3 * (gb.limiter_rpm - gb.idle_rpm), "Gasstoß dreht hoch (%d)" % int(top))
	assert_true(top < gb.limiter_rpm, "nicht bis in den Begrenzer")
	assert_near(float(e.state()["rpm"]), gb.idle_rpm, 0.15 * gb.idle_rpm, "zurück im Leerlauf")


func _drive_one(e: EngineAudio, out: PackedFloat32Array, v: float, thr: float) -> void:
	e.update(DT, v, thr, 230.0, false)
	var n := int(e.bank.sample_rate * DT)
	var at := out.size()
	out.resize(at + n)
	e.render(out, at, n)


## Realistic bank structure in memory: 32 kHz, 13 rpm points 700–7200/min, 8 variants, overlap 96.
func _big_bank() -> EngineBank:
	var sr := 32000
	var rpms := [700, 860, 1060, 1300, 1600, 1970, 2420, 2980, 3660, 4500, 5530, 6400, 7200]
	var banks: Array = []
	var off := 0
	for r in rpms:
		for load in ["off", "on"]:
			var p := 120.0 / float(r) * sr
			var cycles: Array = []
			for v in 8:
				cycles.append([off, int(round(p)) + 96])
				off += int(round(p)) + 96
			banks.append({"rpm": r, "load": load, "period": p, "overlap": 96, "cycles": cycles})
	var data := PackedFloat32Array()
	data.resize(off + 8000)
	for i in data.size():
		data[i] = 0.3 * sin(i * 0.05) + 0.2 * sin(i * 0.31)
	var crackle: Array = [[off, 2000], [off + 2000, 2000]]
	var meta := {"format": EngineBank.FORMAT, "car": "gross", "sample_rate": sr, "data": "x.f32",
		"engine": {"idle_rpm": 700, "redline_rpm": 7000, "limiter_rpm": 7200, "fuel": "petrol", "aspiration": "turbo"},
		"gearbox": {"kmh_per_1000rpm": [9.0, 14.5, 21.0, 28.5, 35.5, 43.0, 52.0], "upshift_rpm": [3000, 6800],
			"downshift_rpm": [1300, 4200], "shift_time_s": 0.18, "launch_rpm": 2600},
		"banks": banks, "clips": {"crackle": crackle, "blowoff": [[off + 4000, 4000]]},
		"layers": {"turbo": {"whistle_hz": [1800, 5200], "level": 0.1, "spool_s": 0.55, "boost_rpm": 2200},
			"crackle": {"min_rpm": 3200, "rate_hz": 7.0, "duration_s": 1.4, "level": 0.6},
			"blowoff": {"min_boost": 0.55, "level": 0.5}, "limiter": {"cut_cycles": 2, "on_cycles": 3}},
		"mix": {"gain": 1.0, "off_gain": 0.42}}
	var b := EngineBank.from_dict(meta, data)
	assert_true(b.ok(), "große Testbank: %s" % str(b.errors))
	return b


func test_cpu_time_per_frame() -> void:
	var b := _big_bank()
	var results := []
	# 533 samples = one 60-fps frame at 32 kHz; best of 5 runs of 60 frames (robust against a busy machine)
	for case in [[140.0, 0.55, "4 Quellen + Turbo"], [0.0, 1.0, "Begrenzer im Stand"], [120.0, 0.0, "Schub + Knallen"]]:
		var e := EngineAudio.new(b, 19)
		var buf := PackedFloat32Array()
		buf.resize(533)
		for i in 90:
			e.update(DT, float(case[0]), 1.0 if i < 60 else float(case[1]), 270.0, true)
			e.render(buf, 0, 533)
		var best := 1.0e9
		for rep in 5:
			var t0 := Time.get_ticks_usec()
			for f in 60:
				e.update(DT, float(case[0]), float(case[1]), 270.0, true)
				e.render(buf, 0, 533)
			best = minf(best, float(Time.get_ticks_usec() - t0) / 60.0 / 1000.0)
		results.append("%s %.3f ms" % [case[2], best])
		assert_true(best < 1.0, "%s: unter 1 ms pro Frame (%.3f ms)" % [case[2], best])
	print("      EngineAudio pro Frame (533 Samples, 32 kHz): ", ", ".join(results))
