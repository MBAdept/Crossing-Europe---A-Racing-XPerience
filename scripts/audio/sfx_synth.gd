class_name SfxSynth
extends RefCounted
## Procedural sound synthesis (pure functions, no autoloads): every sound of the game is generated
## at startup as PCM samples and wrapped in an AudioStreamWAV – no audio files needed.
## Loops (engine, wind, rain, siren, skid, music) are built seamless: integer numbers of cycles and
## filters run twice so their state wraps around the loop point.

const RATE := 22050
## Fundamental of the engine loops; AudioManager sets pitch_scale = engine_hz / ENGINE_BASE_HZ.
const ENGINE_PERIOD := 256
const ENGINE_BASE_HZ := float(RATE) / ENGINE_PERIOD


## Shift points of the virtual gearbox as fractions of vmax (6 gears; other counts are resampled).
const GEAR_TOPS := [0.17, 0.31, 0.46, 0.62, 0.8, 1.03]


## Virtual gearbox: Vector2(gear 1..gears, rpm fraction 0..1 within that gear) for a speed.
## Shifting up drops the rpm to the ratio of the neighbouring shift points (saw-tooth engine pitch).
static func gear_for(speed_kmh: float, vmax_kmh: float, gears: int = 6) -> Vector2:
	var n := maxi(gears, 1)
	var tops: Array[float] = []
	for i in n:
		var idx := int(round(float(i) / maxf(n - 1, 1) * (GEAR_TOPS.size() - 1)))
		tops.append(float(GEAR_TOPS[idx]) * maxf(vmax_kmh, 1.0))
	for g in tops.size():
		if speed_kmh <= tops[g] or g == tops.size() - 1:
			return Vector2(g + 1, clampf(speed_kmh / maxf(tops[g], 1.0), 0.0, 1.0))
	return Vector2(n, 1.0)


## Wraps float samples (-1..1) into a 16-bit mono AudioStreamWAV.
static func to_wav(samples: PackedFloat32Array, loop: bool = false, rate: int = RATE) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


static func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


static func normalize(b: PackedFloat32Array, peak: float = 0.9) -> PackedFloat32Array:
	var m := 0.0001
	for v in b:
		m = maxf(m, absf(v))
	var k := peak / m
	for i in b.size():
		b[i] *= k
	return b


## One-pole low-pass, run twice so that the filter state wraps around (seamless loops).
static func lowpass_loop(b: PackedFloat32Array, cutoff_hz: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * cutoff_hz / RATE)
	var y := 0.0
	for pass_i in 2:
		for i in b.size():
			y += (b[i] - y) * a
			if pass_i == 1:
				b[i] = y
	return b


static func lowpass(b: PackedFloat32Array, cutoff_hz: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * cutoff_hz / RATE)
	var y := 0.0
	for i in b.size():
		y += (b[i] - y) * a
		b[i] = y
	return b


## Engine loop: one combustion pulse per cycle (decaying formants on integer harmonics) with
## per-cycle jitter. on_load = brighter, raspier layer for throttle.
static func engine_loop(on_load: bool, cycles: int = 64) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1701 if on_load else 1702
	var n := ENGINE_PERIOD * cycles
	var b := PackedFloat32Array()
	b.resize(n)
	var inv := 1.0 / ENGINE_PERIOD
	for k in cycles:
		var amp := 1.0 + rng.randf_range(-0.14, 0.14)
		var bright := rng.randf_range(0.8, 1.2)
		for i in ENGINE_PERIOD:
			var ph := i * inv
			var env := exp(-ph * (4.0 if on_load else 6.5))
			var s := 0.55 * sin(TAU * ph) + 0.22 * sin(TAU * 2.0 * ph + 0.6)
			s += 0.32 * env * sin(TAU * 3.0 * ph) * bright
			s += 0.16 * env * sin(TAU * 5.0 * ph + 1.1)
			if on_load:
				s += 0.2 * env * sin(TAU * 8.0 * ph) * bright + 0.18 * env * (1.0 if sin(TAU * 2.0 * ph) > 0.0 else -1.0)
				s += 0.1 * env * rng.randf_range(-1.0, 1.0)
			else:
				s += 0.04 * env * rng.randf_range(-1.0, 1.0)
			b[k * ENGINE_PERIOD + i] = s * amp
	lowpass_loop(b, 2600.0 if on_load else 1300.0)
	return normalize(b, 0.85)


## Filtered noise with slow gusts (wind), seamless.
static func wind_loop(seconds: float = 2.0) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var b := _buf(seconds)
	var n := b.size()
	for i in n:
		b[i] = rng.randf_range(-1.0, 1.0)
	lowpass_loop(b, 700.0)
	lowpass_loop(b, 900.0)
	for i in n:
		var t := float(i) / n
		b[i] *= 0.75 + 0.25 * sin(TAU * 2.0 * t) * sin(TAU * 3.0 * t + 0.5)
	return normalize(b, 0.8)


## Rain: hissing high-passed noise + random droplet ticks, seamless.
static func rain_loop(seconds: float = 2.0) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var b := _buf(seconds)
	var n := b.size()
	var lp := 0.0
	for pass_i in 2:
		for i in n:
			var x := rng.randf_range(-1.0, 1.0)
			lp += (x - lp) * 0.25
			if pass_i == 1:
				b[i] = (x - lp) * 0.5
	for d in 220:
		var p := rng.randi_range(0, n - 1)
		var a := rng.randf_range(0.2, 0.7)
		var f := rng.randf_range(2500.0, 6000.0)
		for j in 90:
			b[(p + j) % n] += a * exp(-j / 12.0) * sin(TAU * f * j / RATE)
	return normalize(b, 0.7)


## German two-tone siren ("Martinshorn", tatü-tata): alternating tones, brassy harmonics.
static func siren_loop(f1: float = 440.0, f2: float = 587.0, tone_s: float = 0.62) -> PackedFloat32Array:
	var seg := int(tone_s * RATE)
	var b := PackedFloat32Array()
	b.resize(seg * 2)
	var harm := [1.0, 0.55, 0.38, 0.22, 0.14, 0.09]
	var fade := int(0.012 * RATE)
	for t_i in 2:
		var f := f1 if t_i == 0 else f2
		for i in seg:
			var s := 0.0
			for h in harm.size():
				s += float(harm[h]) * sin(TAU * f * (h + 1) * i / RATE)
			var env := minf(1.0, minf(float(i) / fade, float(seg - i) / fade))
			b[t_i * seg + i] = s * env
	return normalize(b, 0.8)


## Tyre squeal for understeer, seamless (integer carrier/vibrato cycles per loop).
static func skid_loop() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var b := _buf(1.0)
	var n := b.size()
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 1100.0 + 70.0 * sin(TAU * 7.0 * t)
		ph += TAU * f / RATE
		b[i] = 0.6 * sin(ph) + 0.25 * sin(ph * 2.0) + 0.25 * rng.randf_range(-1.0, 1.0)
	lowpass_loop(b, 3500.0)
	return normalize(b, 0.7)


static func _env_ad(t: float, attack: float, decay: float) -> float:
	if t < attack:
		return t / maxf(attack, 0.0001)
	return exp(-(t - attack) / maxf(decay, 0.0001))


## Chiptune-ish tone (sine + a bit of odd harmonics).
static func _tone(f: float, t: float) -> float:
	return sin(TAU * f * t) + 0.3 * sin(TAU * 3.0 * f * t) + 0.12 * sin(TAU * 5.0 * f * t)


static func crash() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var b := _buf(1.1)
	var lp := 0.0
	var ph := 0.0
	var metal := [523.0, 1381.0, 2210.0, 3170.0, 4410.0]
	for i in b.size():
		var t := float(i) / RATE
		var f := lerpf(95.0, 38.0, minf(t / 0.3, 1.0))
		ph += TAU * f / RATE
		var thump := sin(ph) * exp(-t * 7.0)
		var x := rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * 0.35
		var crunch := lp * exp(-t * 4.5) * (0.6 + 0.4 * absf(sin(TAU * 31.0 * t)))
		var m := 0.0
		for k in metal.size():
			m += sin(TAU * float(metal[k]) * t + k) * exp(-t * (5.0 + k * 2.0))
		b[i] = 0.9 * thump + 0.8 * crunch + 0.12 * m
	for d in 30:
		var p := rng.randi_range(int(0.05 * RATE), int(0.5 * RATE))
		var f2 := rng.randf_range(3000.0, 7000.0)
		for j in 120:
			if p + j < b.size():
				b[p + j] += 0.18 * exp(-j / 25.0) * sin(TAU * f2 * j / RATE)
	return normalize(b, 0.95)


## Radar flash: shutter click + charging flash whine.
static func radar_flash() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var b := _buf(0.5)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var click := 0.0
		if t < 0.006 or (t > 0.07 and t < 0.078):
			click = rng.randf_range(-1.0, 1.0)
		var f := lerpf(1800.0, 4600.0, minf(t / 0.35, 1.0))
		ph += TAU * f / RATE
		var whine := 0.3 * sin(ph) * _env_ad(t, 0.02, 0.18)
		b[i] = click * 0.9 + whine
	return normalize(b, 0.85)


static func beep(freq: float, seconds: float, decay: float = 1.0) -> PackedFloat32Array:
	var b := _buf(seconds)
	var n := b.size()
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.004) * minf(1.0, (seconds - t) / 0.03) * exp(-t * decay)
		b[i] = _tone(freq, t) * env
	return normalize(b, 0.75)


## Finish jingle: rising arpeggio C5 E5 G5 C6, then a C major chord.
static func finish_jingle() -> PackedFloat32Array:
	var b := _buf(1.7)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	var step := 0.1
	for i in b.size():
		var t := float(i) / RATE
		var s := 0.0
		var k := int(t / step)
		if k < notes.size():
			var tt := t - k * step
			s = _tone(float(notes[k]), tt) * minf(1.0, tt / 0.004) * minf(1.0, (step - tt) / 0.01)
		else:
			var tc := t - notes.size() * step
			var env := minf(1.0, tc / 0.01) * exp(-tc * 2.2)
			s = (_tone(1046.5, tc) + 0.8 * _tone(1318.5, tc) + 0.7 * _tone(1568.0, tc)) * 0.5 * env
		b[i] = s
	return normalize(b, 0.8)


static func fuel_start() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var b := _buf(0.8)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var clunk := sin(TAU * 120.0 * t) * exp(-t * 30.0) + (rng.randf_range(-1.0, 1.0) * exp(-t * 300.0))
		var x := rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * 0.08
		var hum := (sin(TAU * 100.0 * t) * 0.5 + lp * 2.0) * smoothstep(0.1, 0.35, t) * minf(1.0, (0.8 - t) / 0.2)
		b[i] = clunk + 0.5 * hum
	return normalize(b, 0.8)


static func fuel_done() -> PackedFloat32Array:
	var b := _buf(0.9)
	for i in b.size():
		var t := float(i) / RATE
		var s := 0.0
		if t < 0.35:
			s = (sin(TAU * 1318.5 * t) + 0.3 * sin(TAU * 3.0 * 1318.5 * t * 1.003)) * exp(-t * 7.0)
		if t >= 0.18:
			var t2 := t - 0.18
			s += (sin(TAU * 1046.5 * t2) + 0.3 * sin(TAU * 3.0 * 1046.5 * t2 * 1.003)) * exp(-t2 * 5.0)
		var click := sin(TAU * 900.0 * t) * exp(-t * 120.0)
		b[i] = s + click * 0.5
	return normalize(b, 0.75)


static func ui_tick() -> PackedFloat32Array:
	var b := _buf(0.05)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * 2100.0 * t) * exp(-t * 90.0)
	return normalize(b, 0.5)


static func ui_two_tone(f1: float, f2: float) -> PackedFloat32Array:
	var b := _buf(0.16)
	for i in b.size():
		var t := float(i) / RATE
		var f := f1 if t < 0.06 else f2
		var tt := t if t < 0.06 else t - 0.06
		b[i] = _tone(f, tt) * minf(1.0, tt / 0.003) * exp(-tt * 18.0)
	return normalize(b, 0.6)


## Synthwave menu loop (4 bars, A minor – F – C – G), ~8.6 s. Heavier to generate (background thread).
static func music_loop(bpm: float = 112.0) -> PackedFloat32Array:
	var beat := 60.0 / bpm
	var bar := beat * 4.0
	var b := _buf(bar * 4.0)
	var n := b.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1985
	# chord roots (bass) and triads (pad), Hz
	var roots := [110.0, 87.31, 130.81, 98.0]
	var triads := [[220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [261.63, 329.63, 392.0], [196.0, 246.94, 293.66]]
	var arp := [0, 1, 2, 1, 0, 2, 1, 2]
	var lp_bass := 0.0
	var lp_pad := 0.0
	var hat_lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var bar_i := int(t / bar) % 4
		var tb := fmod(t, beat)
		var t8 := fmod(t, beat * 0.5)
		var t16 := fmod(t, beat * 0.25)
		var idx16 := int(t / (beat * 0.25)) % 8
		var root: float = roots[bar_i]
		var tri: Array = triads[bar_i]
		# bass: 8th-note saw, octave jumps
		var bf := root * (2.0 if int(t / (beat * 0.5)) % 2 == 1 else 1.0)
		var saw := 2.0 * fmod(bf * t, 1.0) - 1.0
		lp_bass += (saw - lp_bass) * 0.12
		var bass := lp_bass * exp(-t8 * 5.0) * 0.55
		# arpeggio lead (16ths), square-ish
		var af: float = float(tri[arp[idx16]]) * 2.0
		var sq := 1.0 if sin(TAU * af * t) > 0.0 else -1.0
		var lead := sq * exp(-t16 * 14.0) * 0.12
		# pad: detuned saws
		var pad := 0.0
		for k in 3:
			var pf: float = tri[k]
			pad += (2.0 * fmod(pf * 1.003 * t, 1.0) - 1.0) + (2.0 * fmod(pf * 0.997 * t, 1.0) - 1.0)
		lp_pad += (pad - lp_pad) * 0.05
		var pad_v := lp_pad * 0.06
		# drums: kick on 1 & 3, snare on 2 & 4, hats on 8ths
		var beat_i := int(t / beat) % 4
		var kick := 0.0
		if beat_i == 0 or beat_i == 2:
			kick = sin(TAU * lerpf(110.0, 45.0, minf(tb / 0.12, 1.0)) * tb) * exp(-tb * 9.0) * 0.9
		var snare := 0.0
		if beat_i == 1 or beat_i == 3:
			snare = rng.randf_range(-1.0, 1.0) * exp(-tb * 16.0) * 0.35 + sin(TAU * 190.0 * tb) * exp(-tb * 20.0) * 0.2
		var x := rng.randf_range(-1.0, 1.0)
		hat_lp += (x - hat_lp) * 0.6
		var hat := (x - hat_lp) * exp(-t8 * 60.0) * 0.18
		b[i] = bass + lead + pad_v + kick + snare + hat
	return normalize(b, 0.8)
