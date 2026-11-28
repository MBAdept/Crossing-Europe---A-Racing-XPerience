extends TestCase
## The measurements of tests/race/check_audio_modern.gd (tests/race/audio_meter.gd, package AU-E) on signals with known
## values. The loudness and true-peak references are tools/audio/qc/qc_lib.py on the same signals (48 kHz):
##   997 Hz, amplitude 0.5 on both channels, 2 s: integrated −6.058 LUFS; followed by 2 s of silence: −6.397 (the
##   blocks across the edge stay in, as in qc_lib); 100 Hz −7.888; 40 Hz −12.322; 5 kHz at 0.25 −8.766;
##   12 kHz at 0.5 with a 45° phase: sample peak −9.03 dB, true peak −5.914 dBTP.
## On a real recording (vollgas_gran_turismo of the check) both agree to 0.001 dB (docs/audio-modern.md §17).

const Meter := preload("res://tests/race/audio_meter.gd")
const RATE := 48000.0


func _sine(f: float, amp: float, seconds: float, phase := 0.0) -> PackedFloat32Array:
	var n := int(RATE * seconds)
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		x[i] = amp * sin(TAU * f * i / RATE + phase)
	return x


func _lufs(x: PackedFloat32Array) -> float:
	var k := Meter.k_weight(x, RATE)
	return Meter.integrated(Meter.power_sum(k, k), RATE, 0.0, x.size() / RATE)


func test_loudness_matches_qc_lib() -> void:
	assert_near(_lufs(_sine(997.0, 0.5, 2.0)), -6.058, 0.02, "997 Hz")
	assert_near(_lufs(_sine(100.0, 0.5, 2.0)), -7.888, 0.03, "100 Hz")
	assert_near(_lufs(_sine(40.0, 0.5, 2.0)), -12.322, 0.05, "40 Hz (RLB-Hochpass)")
	assert_near(_lufs(_sine(5000.0, 0.25, 2.0)), -8.766, 0.05, "5 kHz (Kuhschwanz +4 dB)")


func test_gating_and_windows() -> void:
	var x := _sine(997.0, 0.5, 2.0)
	var y := x.duplicate()
	var silence := PackedFloat32Array()
	silence.resize(int(RATE * 2.0))
	y.append_array(silence)
	assert_near(_lufs(y), -6.397, 0.02, "Stille wird ausgeblendet (wie qc_lib)")
	var k := Meter.k_weight(y, RATE)
	var c := Meter.power_sum(k, k)
	var st := Meter.series(c, RATE, 0.0, 4.0, 0.4, 0.1)
	assert_near(Meter.max_of(st), -6.058, 0.03, "momentan im Ton")
	assert_true(Meter.min_of(st) < -60.0, "momentan in der Stille")
	assert_near(Meter.window_lufs(c, int(RATE * 0.5), int(RATE * 1.0)), -6.058, 0.03, "Fenster")


func test_true_peak_finds_inter_sample_peaks() -> void:
	var x := _sine(12000.0, 0.5, 0.5, PI / 4.0)
	var tp := Meter.true_peak(x, x, 0, x.size())
	assert_near(Meter.db(float(tp["sample_peak"])), -9.031, 0.01, "Abtastspitze")
	assert_near(Meter.db(float(tp["true_peak"])), -5.914, 0.02, "True Peak wie qc_lib")
	assert_true(int(tp["checked"]) > 0, "Stellen geprüft")
	assert_eq(Meter.count_at_least(x, x, 0, x.size(), 0.999), 0, "keine Vollaussteuerung")


func test_balance_highpass_and_spectrum_ratio() -> void:
	var l := _sine(500.0, 0.5, 0.5)
	var r := _sine(500.0, 0.25, 0.5)
	assert_near(Meter.balance_db(l, r, 0, l.size()), 6.02, 0.05, "links 6 dB lauter")
	# a small speaker: 4th order at 180 Hz takes 100 Hz down by about 20 dB and leaves 1 kHz alone
	var lo := _sine(100.0, 0.5, 1.0)
	var hi := _sine(1000.0, 0.5, 1.0)
	var lo_hp := Meter.highpass4(lo, RATE, 180.0)
	var hi_hp := Meter.highpass4(hi, RATE, 180.0)
	var n := lo.size()
	assert_near(Meter.rms_db(lo_hp, n / 2, n) - Meter.rms_db(lo, n / 2, n), -20.4, 0.6, "100 Hz durch 180 Hz Hochpass")
	assert_near(Meter.rms_db(hi_hp, n / 2, n) - Meter.rms_db(hi, n / 2, n), 0.0, 0.1, "1 kHz bleibt")
	# the same harmonic sound 8 % lower: the log-spectrum ratio finds 0.92
	var a := PackedFloat32Array()
	var b := PackedFloat32Array()
	var m := int(RATE * 0.5)
	a.resize(m)
	b.resize(m)
	for i in m:
		var t := i / RATE
		var va := 0.0
		var vb := 0.0
		for h in range(1, 7):
			va += 0.3 / h * sin(TAU * 60.0 * h * t)
			vb += 0.3 / h * sin(TAU * 60.0 * 0.92 * h * t)
		a[i] = va
		b[i] = vb
	var sa := Meter.log_spectrum(a, a, 0, m, RATE, 40.0, 1000.0, 48)
	var sb := Meter.log_spectrum(b, b, 0, m, RATE, 40.0, 1000.0, 48)
	var q := Meter.spectrum_ratio(sa, sb, 48, 24)
	assert_near(float(q["ratio"]), 0.92, 0.005, "Tonhöhenverhältnis")
	var same := Meter.spectrum_ratio(sa, sa, 48, 24)
	assert_near(float(same["ratio"]), 1.0, 1.0e-6, "gleiche Spektren")


func test_reverberation_time() -> void:
	# white noise decaying by 60 dB in 1.5 s
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var n := int(RATE * 2.5)
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		x[i] = rng.randf_range(-0.5, 0.5) * pow(10.0, -3.0 * (i / RATE) / 1.5)
	var curve := Meter.schroeder_db(x, x, 0, n, RATE)
	assert_near(Meter.rt60(curve), 1.5, 0.08, "Nachhallzeit aus T20")
	var short := PackedFloat32Array()
	short.resize(int(RATE * 0.02))
	for i in short.size():
		short[i] = rng.randf_range(-0.5, 0.5) if i < 48 else 0.0
	assert_true(Meter.rt60(Meter.schroeder_db(short, short, 0, short.size(), RATE)) < 0.05, "ein Knacks ohne Raum")
