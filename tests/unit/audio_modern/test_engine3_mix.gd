extends TestCase
## EngineMixThread – the mixing core of the engine v3 (sound profile "Modern", contract D27 and §6 AU-B): with the
## fixture bank of test_engine3_fixture.gd (deliberately different cycle variants, two different channels) and with
## the five shipped banks. No AudioServer: render() only.
##   bounded and finite output · variants never twice in a row · cycle length follows the rpm · no clicks at cycle
##   boundaries on both channels (one bank, two banks) · continuity over an rpm sweep · power-true blends between
##   the loads and between rpm points · induction follows the pedal, the exhaust layers the load · limiter pattern ·
##   clips (start, crackles after lifting, panned mono clips) · the same seed and control give the same samples ·
##   movement: never a static loop · the shipped banks: L/R balance within 0.5 dB and a mono sum not below −3 dB of
##   a channel over a full-load and an overrun sweep · render time per frame.

const FX := preload("res://tests/unit/audio_modern/test_engine3_fixture.gd")
const DT := 1.0 / 60.0
const CARS: Array[String] = ["kompakt", "kombi", "limousine", "sportwagen", "gran_turismo"]
const OFF := EngineBank2.LAYER_OFF
const ON := EngineBank2.LAYER_ON


func _bank(opts: Dictionary = {}) -> EngineBank2:
	var b := FX.bank(opts)
	assert_true(b.ok(), "Fixture lädt: %s" % str(b.errors))
	# the fixture is a 16-kHz bank on purpose (half the samples): that is its only deviation
	assert_true(b.warnings.size() == 1 and b.warnings[0].contains("16000"), "Fixture: nur der Hinweis auf die Abtastrate (%s)" % str(b.warnings))
	return b


## A mixer without movement (the plain algorithm).
func _plain(b: EngineBank2, p_seed: int) -> EngineMixThread:
	var m := EngineMixThread.new(b, p_seed)
	m.motion_rpm = 0.0
	m.motion_level_db = 0.0
	m.motion_load = 0.0
	m.motion_cycle_db = 0.0
	m.motion_rpm_slow = 0.0
	m.motion_level_slow_db = 0.0
	m.motion_load_slow = 0.0
	return m


func _render(m: EngineMixThread, seconds: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(int(seconds * m.bank.sample_rate))
	m.render(out, 0, out.size())
	return out


## Frames of drive(rpm, load, throttle), each rendered with the frame's share of samples.
func _drive(m: EngineMixThread, out: PackedVector2Array, frames: Array, limiter: bool = false) -> void:
	var per := float(m.bank.sample_rate) * DT
	var acc := 0.0
	var pos := out.size()
	for f: Array in frames:
		m.drive(float(f[0]), float(f[1]), float(f[2]), 1.0, limiter, DT)
		acc += per
		var n := int(acc)
		acc -= n
		out.resize(pos + n)
		m.render(out, pos, n)
		pos += n


func _ch(v: Vector2, c: int) -> float:
	return v.x if c == 0 else v.y


func _peak(o: PackedVector2Array) -> float:
	var m := 0.0
	for v in o:
		m = maxf(m, maxf(absf(v.x), absf(v.y)))
	return m


## Mean squares [left, right, mono sum (L + R) / 2] of o[from … to).
func _power(o: PackedVector2Array, from: int = 0, to: int = -1) -> Vector3:
	var end := o.size() if to < 0 else to
	var l := 0.0
	var r := 0.0
	var mo := 0.0
	for i in range(from, end):
		var v := o[i]
		l += v.x * v.x
		r += v.y * v.y
		mo += 0.25 * (v.x + v.y) * (v.x + v.y)
	var n := maxf(float(end - from), 1.0)
	return Vector3(l / n, r / n, mo / n)


func _db(x: float) -> float:
	return 10.0 * log(maxf(x, 1.0e-20)) / log(10.0)


func _max_step(o: PackedVector2Array, c: int, from: int = 1, to: int = -1) -> float:
	var m := 0.0
	for i in range(maxi(from, 1), o.size() if to < 0 else to):
		m = maxf(m, absf(_ch(o[i], c) - _ch(o[i - 1], c)))
	return m


## Largest sample-to-sample step inside the cycles of bank index bi, channel c (the signal's own steepness).
func _bank_step(b: EngineBank2, bi: int, c: int) -> float:
	var m := 0.0
	for v in b.var_count[bi]:
		var base := b.cyc_base[b.var_first[bi] + v] + c
		for k in range(1, b.cyc_len[b.var_first[bi] + v]):
			m = maxf(m, absf(b.data[base + 2 * k] - b.data[base + 2 * k - 2]))
	return m * b.gains[bi]


## Largest jump a hard splice of two different variants would make at the cycle boundary.
func _splice_jump(b: EngineBank2, bi: int, c: int) -> float:
	var p := int(round(b.periods[bi]))
	var m := 0.0
	for k in b.var_count[bi]:
		for j in b.var_count[bi]:
			if j != k:
				var tail := b.data[b.cyc_base[b.var_first[bi] + k] + c + 2 * (p - 1)]
				var head := b.data[b.cyc_base[b.var_first[bi] + j] + c]
				m = maxf(m, absf(head - tail))
	return m * b.gains[bi]


func test_output_is_finite_and_within_unity() -> void:
	var b := _bank({"saturation": 1.0})
	var m := EngineMixThread.new(b, 3)
	m.start(true)
	var out := PackedVector2Array()
	var frames: Array = []
	for i in 60:
		frames.append([2000.0, 0.0, 0.0])
	for i in 240:
		frames.append([2000.0 + 8.0 * i, 1.0, 1.0])
	for i in 120:
		frames.append([3900.0 - 10.0 * i, 0.0, 0.0])
	_drive(m, out, frames)
	var bad := 0
	for v in out:
		if is_nan(v.x) or is_inf(v.x) or is_nan(v.y) or is_inf(v.y):
			bad += 1
	assert_eq(bad, 0, "kein NaN/inf")
	assert_true(_peak(out) <= 1.0, "Spitze <= 1 (%.3f)" % _peak(out))
	assert_true(_peak(out) > 0.1, "hörbar")
	# far too loud on purpose: the soft limit keeps both channels below 1
	var hot := _plain(b, 4)
	hot.level = 12.0
	hot.set_manual(3000.0, 1.0)
	var o2 := _render(hot, 0.5)
	assert_true(_peak(o2) <= 1.0, "übersteuert: Spitze <= 1 (%.4f)" % _peak(o2))
	assert_true(_peak(o2) > EngineMixThread.SOFT, "die weiche Begrenzung greift")


func test_variants_random_never_twice_in_a_row() -> void:
	var b := _bank()
	var m := _plain(b, 5)
	m.debug_wraps = true
	m.debug_bank = 1 * 3 + ON
	m.set_manual(2500.0, 1.0)
	_render(m, 4.0)
	var seen := {}
	assert_true(m.variants_log.size() > 50, "genug Zyklen (%d)" % m.variants_log.size())
	for i in m.variants_log.size():
		seen[m.variants_log[i]] = true
		if i > 0 and m.variants_log[i] == m.variants_log[i - 1]:
			fail("dieselbe Variante zweimal hintereinander (Zyklus %d)" % i)
			break
	assert_eq(seen.size(), b.var_count[1 * 3 + ON], "alle Varianten kommen vor")


func test_cycle_length_follows_rpm() -> void:
	var b := _bank()
	for rpm: float in [2000.0, 2300.0, 2800.0, 3500.0, 3900.0]:
		var m := _plain(b, 6)
		m.debug_wraps = true
		m.set_manual(rpm, 0.5)
		_render(m, 1.5)
		var w := m.wraps
		var expect := 120.0 / rpm * b.sample_rate
		assert_near(float(w[w.size() - 1] - w[1]) / float(w.size() - 2), expect, 0.5, "Zykluslänge bei %d/min" % int(rpm))
		for i in range(2, w.size()):
			if absf(float(w[i] - w[i - 1]) - expect) > 1.01:
				fail("Zyklus %d bei %d/min: %d statt %.1f Abtastwerte" % [i, int(rpm), w[i] - w[i - 1], expect])
				break


func test_no_clicks_at_cycle_boundaries_on_both_channels() -> void:
	var b := _bank()
	# exactly at the third rpm point, load 0, pedal 0: one bank ("off") alone
	var bi := 2 * 3 + OFF
	var m := _plain(b, 7)
	m.debug_wraps = true
	m.set_manual(FX.rpm_of(FX.PERIODS[2]), 0.0, 0.0)
	var out := _render(m, 3.0)
	assert_true(m.wraps.size() > 50, "viele Zyklusgrenzen (%d)" % m.wraps.size())
	for c in 2:
		var own := _bank_step(b, bi, c)
		var naive := _splice_jump(b, bi, c)
		assert_true(naive > 2.5 * own, "Fixture, Kanal %d: Varianten absichtlich verschieden (Sprung %.4f, Steilheit %.4f)" % [c, naive, own])
		var worst := 0.0
		for w in m.wraps:
			if w > 2 and w + 48 < out.size():
				worst = maxf(worst, _max_step(out, c, w - 2, w + 48))
		# crossfade over (overlap − 4) frames with a smoothstep: at most 1.5 / (overlap − 4) of the jump per frame
		var bound := (own + naive * 1.5 / float(b.overlaps[bi] - 4)) * 1.05 + 0.0005
		assert_true(worst <= bound, "Kanal %d: Zyklusgrenzen ohne Knacken (%.4f <= %.4f)" % [c, worst, bound])
		assert_true(worst < 0.5 * naive, "Kanal %d: deutlich unter dem harten Schnitt (%.4f gegen %.4f)" % [c, worst, naive])
	# between two rpm points: two banks, read steps other than 1
	var m2 := _plain(b, 8)
	m2.set_manual(2800.0, 0.0, 0.0)
	var out2 := _render(m2, 2.0)
	for c in 2:
		var own2 := maxf(_bank_step(b, 1 * 3 + OFF, c), _bank_step(b, 2 * 3 + OFF, c)) * 2800.0 / 2500.0
		var naive2 := maxf(_splice_jump(b, 1 * 3 + OFF, c), _splice_jump(b, 2 * 3 + OFF, c))
		var bound2 := (own2 + naive2 * 1.5 / float(b.overlaps[bi] - 4)) * 1.1 + 0.0005
		assert_true(_max_step(out2, c) <= bound2, "Kanal %d zwischen zwei Drehzahlpunkten ohne Knacken (%.4f <= %.4f)" % [c, _max_step(out2, c), bound2])
	# full load with the induction layer on top
	var m3 := _plain(b, 9)
	m3.debug_wraps = true
	m3.set_manual(FX.rpm_of(FX.PERIODS[1]), 1.0, 1.0)
	var out3 := _render(m3, 2.0)
	for c in 2:
		var own3 := _bank_step(b, 1 * 3 + ON, c) + _bank_step(b, 1 * 3 + EngineBank2.LAYER_IN, 0)
		var naive3 := _splice_jump(b, 1 * 3 + ON, c) + 0.05
		var worst3 := 0.0
		for w in m3.wraps:
			if w > 2 and w + 48 < out3.size():
				worst3 = maxf(worst3, _max_step(out3, c, w - 2, w + 48))
		assert_true(worst3 <= (own3 + naive3 * 1.5 / 28.0) * 1.1 + 0.0005, "Kanal %d unter Volllast mit Ansaugebene (%.4f)" % [c, worst3])


func test_continuous_over_rpm_sweep() -> void:
	var b := _bank()
	var m := _plain(b, 10)
	m.set_manual(1900.0, 0.0, 0.0)
	var out := PackedVector2Array()
	var frames: Array = []
	for f in 480:
		var x := float(f) / 240.0
		frames.append([lerpf(1900.0, 4000.0, x if x <= 1.0 else 2.0 - x), 0.0, 0.0])
	_drive(m, out, frames)
	for c in 2:
		var steep := 0.0
		var jump := 0.0
		for i in 4:
			steep = maxf(steep, _bank_step(b, i * 3 + OFF, c))
			jump = maxf(jump, _splice_jump(b, i * 3 + OFF, c))
		# read steps up to 1.25 between points and 4000 / 3900 above the last one; crossfade term as above
		var bound := (steep * 1.26 + jump * 1.5 / 28.0) * 1.1 + 0.001
		assert_true(_max_step(out, c) <= bound, "Kanal %d stetig über den Drehzahlverlauf (%.4f <= %.4f)" % [c, _max_step(out, c), bound])
	# no gaps: every 10 ms carries signal on both channels
	var win := int(0.01 * b.sample_rate)
	var quiet := 0
	for i in range(0, out.size() - win, win):
		var p := _power(out, i, i + win)
		if p.x < 1.0e-5 or p.y < 1.0e-5:
			quiet += 1
	assert_eq(quiet, 0, "keine Aussetzer (10-ms-Fenster, beide Kanäle)")


## Cycle averaged over the variants of bank bi, n points, both channels → PackedFloat64Array (n × 2).
func _mean_cycle(b: EngineBank2, bi: int, n: int) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(n * 2)
	var p := b.periods[bi]
	for v in b.var_count[bi]:
		var base := b.cyc_base[b.var_first[bi] + v]
		for k in n:
			var pos := float(k) / float(n) * p
			var i0 := int(pos)
			var fr := pos - i0
			for c in 2:
				var a := b.data[base + 2 * i0 + c]
				out[k * 2 + c] += (a + (b.data[base + 2 * i0 + 2 + c] - a) * fr) / float(b.var_count[bi])
	return out


## Coherence of two banks as the synthesis tool defines it: <mean cycle A, mean cycle B> / sqrt(P_A · P_B).
func _coherence(b: EngineBank2, bi: int, bj: int) -> float:
	var n := 512
	var a := _mean_cycle(b, bi, n)
	var c := _mean_cycle(b, bj, n)
	var dot := 0.0
	for k in n * 2:
		dot += a[k] * c[k]
	dot /= float(n * 2)
	var pw := [0.0, 0.0]
	var which := [bi, bj]
	for w in 2:
		var bw: int = which[w]
		var per := int(b.periods[bw])
		for v in b.var_count[bw]:
			var base := b.cyc_base[b.var_first[bw] + v]
			for k in per * 2:
				pw[w] += b.data[base + k] * b.data[base + k]
		pw[w] /= float(b.var_count[bw] * per * 2)
	return dot / sqrt(float(pw[0]) * float(pw[1]))


func test_blend_between_rpm_points_keeps_the_power() -> void:
	# random cycle shapes per rpm point: a plain crossfade loses level between the points
	var b := _bank({"coherent": false})
	var lo := 1 * 3 + OFF
	var hi := 2 * 3 + OFF
	var rho := _coherence(b, lo, hi)
	b.xrpm[hi] = rho
	var mid_rpm := sqrt(FX.rpm_of(FX.PERIODS[1]) * FX.rpm_of(FX.PERIODS[2]))
	var p := {}
	for rpm: float in [FX.rpm_of(FX.PERIODS[1]), mid_rpm, FX.rpm_of(FX.PERIODS[2])]:
		var m := _plain(b, 11)
		m.set_manual(rpm, 0.0, 0.0)
		var o := _power(_render(m, 1.5), 800)
		p[rpm] = o.x + o.y
	var want := 0.5 * (float(p[FX.rpm_of(FX.PERIODS[1])]) + float(p[FX.rpm_of(FX.PERIODS[2])]))
	var plain_loss := _db(0.5 * (1.0 + rho))
	assert_true(absf(rho) < 0.9, "Fixture: die beiden Punkte sind nicht deckungsgleich (Kohärenz %.2f)" % rho)
	assert_between(_db(float(p[mid_rpm]) / want), -1.0, 1.0, "Leistung zwischen zwei Drehzahlpunkten gehalten (%.2f dB; ein einfaches Überblenden ergäbe %.1f dB)" % [_db(float(p[mid_rpm]) / want), plain_loss])


func test_blend_between_the_loads_keeps_the_power() -> void:
	# "on" = "off" × 2: fully coherent layers (xload 1) – sin/cos weights alone would add 2.6 dB at half load
	var b := _bank({"on_is_off": true})
	var p := {}
	for load: float in [0.0, 0.5, 1.0]:
		var m := _plain(b, 12)
		m.set_manual(FX.rpm_of(FX.PERIODS[2]), load, 0.0)
		var o := _power(_render(m, 1.0), 800)
		p[load] = o.x + o.y
	assert_true(float(p[1.0]) > 2.5 * float(p[0.0]), "Last lauter als Schub")
	var want := 0.5 * (float(p[0.0]) + float(p[1.0]))
	assert_between(_db(float(p[0.5]) / want), -0.8, 0.8, "gleiche Leistung beim Überblenden der Lasten (%.2f dB)" % _db(float(p[0.5]) / want))


func test_induction_follows_the_pedal_and_exhaust_the_load() -> void:
	var b := _bank({"in_level": 0.2})
	var rpm := FX.rpm_of(FX.PERIODS[2])
	var p := {}
	for combo: Array in [[0.0, 0.0], [0.0, 1.0], [1.0, 0.0], [1.0, 1.0]]:
		var m := _plain(b, 13)
		m.set_manual(rpm, float(combo[0]), float(combo[1]))
		var o := _power(_render(m, 0.8), 800)
		p[combo] = o.x + o.y
	assert_true(float(p[[0.0, 1.0]]) > float(p[[0.0, 0.0]]) * 1.3, "Gaspedal ohne Motorlast (Schaltpause): die Ansaugebene kommt dazu")
	assert_true(float(p[[1.0, 1.0]]) > float(p[[1.0, 0.0]]) * 1.05, "Volllast: mit Pedal lauter als ohne")
	assert_true(float(p[[1.0, 0.0]]) > float(p[[0.0, 0.0]]) * 1.5, "die Auspuffebenen folgen der Last")
	# a turbo engine's induction grows with the boost
	var lo := _plain(b, 13)
	lo.set_manual(rpm, 0.0, 1.0, 0.0)
	var o_lo := _power(_render(lo, 0.8), 800)
	assert_true(o_lo.x + o_lo.y < float(p[[0.0, 1.0]]), "ohne Ladedruck leiser als mit")


func test_limiter_cut_pattern() -> void:
	var b := _bank()
	var m := _plain(b, 14)
	m.debug_wraps = true
	m.set_manual(3900.0, 1.0, 1.0, 1.0, true)
	_render(m, 1.5)
	var g := m.gates_log
	var cut := int(b.layer("limiter")["cut_cycles"])
	var on := int(b.layer("limiter")["on_cycles"])
	assert_true(g.size() > 20, "genug Zyklen")
	for i in g.size():
		if g[i] != (0 if (i % (cut + on)) < cut else 1):
			fail("Muster %d aus / %d an: %s" % [cut, on, str(g.slice(0, 12))])
			break
	var m2 := _plain(b, 15)
	m2.debug_wraps = true
	m2.set_manual(3900.0, 1.0, 1.0, 1.0, false)
	_render(m2, 0.5)
	for x in m2.gates_log:
		if x != 1:
			fail("ohne Begrenzer kein Schnitt")
			break


## Power of a clip alone: the same mixer run with and without it, subtracted (clips are added after the saturation).
func _clip_alone(b: EngineBank2, clip_name: String, index: int, pan: float) -> Vector3:
	var outs: Array[PackedVector2Array] = []
	for with_clip: bool in [false, true]:
		var m := _plain(b, 19)
		m.set_manual(2500.0, 0.0, 0.0)
		if with_clip:
			m.play_clip(clip_name, index, 1.0, pan)
		outs.append(_render(m, 0.06))
	var diff := PackedVector2Array()
	diff.resize(outs[0].size())
	for i in diff.size():
		diff[i] = outs[1][i] - outs[0][i]
	return _power(diff)


func test_clips_start_crackles_and_panning() -> void:
	var b := _bank()
	# start clip, then the cycle sound
	var m := _plain(b, 16)
	m.reset()
	assert_true(m.is_silent(), "nach reset() still")
	m.start(true)
	m.set_manual(1950.0, 0.0, 0.0)
	var o := _render(m, 1.0)
	assert_eq(int(m.clips_started.get("start", 0)), 1, "Startclip gespielt")
	assert_true(_power(o, 0, 4000).x > 1.0e-4, "der Clip klingt sofort")
	assert_true(_power(o, 12000, 16000).x > 1.0e-4, "danach läuft der Motor")
	# crackles after lifting, none after getting back on the throttle
	var m2 := _plain(b, 17)
	m2.set_manual(3200.0, 0.0, 0.0)
	m2.lift(1.0)
	_render(m2, 0.6)
	var n := int(m2.clips_started.get("crackle", 0))
	assert_true(n >= 3, "Schubknallen nach dem Gaswegnehmen (%d)" % n)
	m2.lift(0.0)
	_render(m2, 0.1)
	var n2 := int(m2.clips_started.get("crackle", 0))
	_render(m2, 0.6)
	assert_eq(int(m2.clips_started.get("crackle", 0)), n2, "lift(0) beendet es")
	# a stereo clip keeps its channels (left twice the right in the fixture), a mono clip is panned
	var o3 := _clip_alone(b, "crackle", 0, 1.0)
	assert_near(_db(o3.x / o3.y), 6.02, 0.1, "Stereo-Clip: Kanäle wie gespeichert, sein Pan zählt nicht (L/R %.2f dB)" % _db(o3.x / o3.y))
	for pan: float in [-1.0, 0.0, 1.0]:
		for index in 2:
			var o4 := _clip_alone(b, "shift", index, pan)
			if pan < 0.0:
				assert_true(o4.x > 1.0e-5 and o4.y < 1.0e-10, "Mono-Clip %d ganz links" % index)
			elif pan > 0.0:
				assert_true(o4.y > 1.0e-5 and o4.x < 1.0e-10, "Mono-Clip %d ganz rechts" % index)
			else:
				assert_near(_db(o4.y / o4.x), 0.0, 0.01, "Mono-Clip %d mittig" % index)
	# fade out: silent, and nothing is rendered any more
	var m5 := _plain(b, 20)
	m5.set_manual(2500.0, 0.5)
	m5.fade_to(0.0, 0.05)
	var o5 := _render(m5, 0.3)
	assert_true(m5.is_silent(), "ausgeblendet")
	assert_true(_power(o5, 3000).x < 1.0e-12, "danach Stille")


func test_same_seed_and_control_give_the_same_samples() -> void:
	var b := _bank({"saturation": 1.0})
	var frames: Array = []
	for i in 200:
		frames.append([2000.0 + 9.0 * i, 1.0 if i > 20 and i < 150 else 0.0, 1.0 if i > 20 and i < 150 else 0.0])
	var outs: Array[PackedVector2Array] = []
	for s: int in [77, 77, 78]:
		var m := EngineMixThread.new(b, s)      # with movement
		m.start(true)
		var o := PackedVector2Array()
		_drive(m, o, frames)
		m.lift(1.0)
		_drive(m, o, [[3000.0, 0.0, 0.0], [2900.0, 0.0, 0.0], [2800.0, 0.0, 0.0]])
		outs.append(o)
	assert_true(outs[0].size() > 50000, "gerendert (%d Frames)" % outs[0].size())
	assert_true(outs[0] == outs[1], "gleicher Seed, gleiche Steuerung: Abtastwert für Abtastwert gleich")
	assert_false(outs[0] == outs[2], "anderer Seed: andere Zyklusvarianten und Bewegung")


func _levels_db(o: PackedVector2Array, win: int, from: int) -> PackedFloat64Array:
	var lv := PackedFloat64Array()
	var i := from
	while i + win <= o.size():
		var p := _power(o, i, i + win)
		lv.append(_db(p.x + p.y))
		i += win
	return lv


func _std(a: PackedFloat64Array) -> float:
	var mean := 0.0
	for x in a:
		mean += x
	mean /= maxf(float(a.size()), 1.0)
	var s := 0.0
	for x in a:
		s += (x - mean) * (x - mean)
	return sqrt(s / maxf(float(a.size()), 1.0))


func test_movement_never_a_static_loop() -> void:
	var bank := EngineBank2.load_file(EngineBank2.path_for("kompakt"))
	assert_true(bank.ok(), "Bank des Kompakten lädt: %s" % str(bank.errors))
	if not bank.ok():
		return
	var win := int(0.05 * bank.sample_rate)
	# cruise (130 km/h in 7th gear, light load) and overrun, 8 s each: with the movement the level and the cycle
	# length move, without it they stand still
	for load: float in [0.22, 0.0]:
		var live := EngineMixThread.new(bank, 31)
		live.debug_wraps = true
		live.set_manual(2650.0, load, load)
		var o := _render(live, 8.0)
		var still := _plain(bank, 31)
		still.debug_wraps = true
		still.set_manual(2650.0, load, load)
		var o2 := _render(still, 8.0)
		var sd := _std(_levels_db(o, win, win * 4))
		var sd0 := _std(_levels_db(o2, win, win * 4))
		assert_true(sd > 0.25, "Last %.2f: der Pegel bewegt sich (Standardabweichung der 50-ms-Pegel %.2f dB)" % [load, sd])
		assert_true(sd < 2.5, "… aber er pumpt nicht (%.2f dB)" % sd)
		assert_true(sd > sd0 + 0.15, "Last %.2f: mehr als die Zyklusvarianten allein (%.2f gegen %.2f dB)" % [load, sd, sd0])
		var lens := PackedFloat64Array()
		for i in range(2, live.wraps.size()):
			lens.append(float(live.wraps[i] - live.wraps[i - 1]))
		var lens0 := PackedFloat64Array()
		for i in range(2, still.wraps.size()):
			lens0.append(float(still.wraps[i] - still.wraps[i - 1]))
		assert_true(_std(lens) > 1.5, "Last %.2f: die Drehzahl wandert (Zykluslänge ± %.1f Abtastwerte)" % [load, _std(lens)])
		assert_true(_std(lens0) < 0.6, "ohne Bewegung steht sie (± %.2f)" % _std(lens0))
		# and it wanders slowly as well: seconds apart the mean level differs
		var sec := _levels_db(o, bank.sample_rate, bank.sample_rate)
		assert_true(_std(sec) > 0.05, "Last %.2f: langsames Atmen (1-s-Pegel ± %.2f dB)" % [load, _std(sec)])


## Full-load sweep up and overrun sweep down over the whole rpm range: [power up, power down] (Vector3 each).
func _sweeps(bank: EngineBank2) -> Array:
	var idle := float(bank.engine["idle_rpm"])
	var lim := float(bank.engine["limiter_rpm"])
	var res: Array = []
	for load: float in [1.0, 0.0]:
		var m := EngineMixThread.new(bank, 41)
		m.set_manual(idle * 1.05, load, load)
		var o := PackedVector2Array()
		var frames: Array = []
		for f in 300:
			var x := float(f) / 299.0
			frames.append([lerpf(idle * 1.05, lim * 0.98, x if load > 0.5 else 1.0 - x), load, load])
		_drive(m, o, frames)
		res.append(_power(o, 2000))
	return res


func test_shipped_banks_balance_and_mono_sum() -> void:
	var total_bytes := 0
	for car in CARS:
		var bank := EngineBank2.load_file(EngineBank2.path_for(car))
		assert_true(bank.ok(), "%s lädt: %s" % [car, str(bank.errors)])
		if not bank.ok():
			continue
		total_bytes += bank.frames * 4
		var sw := _sweeps(bank)
		var names := ["Volllast", "Schub"]
		for i in 2:
			var p: Vector3 = sw[i]
			var bal := _db(p.y / p.x)
			var mono := _db(p.z / maxf(p.x, p.y))
			print("      %-12s %-8s R−L %+.2f dB, Mono-Summe %.2f dB unter dem lauteren Kanal" % [car, names[i], bal, -mono])
			assert_true(absf(bal) <= 0.5, "%s %s: Kanalbalance %.2f dB (höchstens 0,5)" % [car, names[i], bal])
			assert_true(mono >= -3.0, "%s %s: Mono-Summe %.2f dB (nicht unter −3)" % [car, names[i], mono])
	assert_true(total_bytes < 12.5 * 1048576.0, "Banken zusammen %.1f MB (unter 12,5)" % (total_bytes / 1048576.0))


func test_render_time_per_frame() -> void:
	var bank := EngineBank2.load_file(EngineBank2.path_for("gran_turismo"))
	assert_true(bank.ok(), "Bank lädt")
	if not bank.ok():
		return
	var m := EngineMixThread.new(bank, 51)
	var per := float(bank.sample_rate) * DT
	var acc := 0.0
	var buf := PackedVector2Array()
	var t_sum := 0
	var t_max := 0
	var frames := 360
	m.set_manual(3000.0, 1.0)
	for f in frames:
		# between two rpm points (six voices), full load, the limiter never: the usual worst case
		m.drive(3000.0 + 8.0 * f, 1.0, 1.0, 1.0, false, DT)
		acc += per
		var n := int(acc)
		acc -= n
		if buf.size() != n:
			buf.resize(n)
		var t0 := Time.get_ticks_usec()
		m.render(buf, 0, n)
		var us := Time.get_ticks_usec() - t0
		t_sum += us
		t_max = maxi(t_max, us)
	var avg_ms := t_sum / 1000.0 / frames
	print("      Mischer v3, Gran Turismo, Volllast zwischen zwei Drehzahlpunkten: %.3f ms je Bild (1/60 s Klang, 32 kHz Stereo), höchstens %.2f ms" % [avg_ms, t_max / 1000.0])
	assert_true(avg_ms < 5.0, "Mischzeit je Bild unter 5 ms auch auf einer belasteten Maschine (%.3f ms)" % avg_ms)
