extends RefCounted
## Fixture of the engine v3 tests (no tests in this file): a small bank of the format "ce-engine-bank-2" built in
## memory – 16 kHz stereo, four rpm points 2000–3900/min, per point the layers "off" and "on" (stereo, four cycle
## variants that deliberately differ, the two channels with different content) and "in" (mono, four variants packed
## two per stereo block), crackle / shift (stereo) and start clips, the layers limiter, crackle, shift, turbo,
## saturation. Options:
##   coherent   true (default): every rpm point has the same cycle shape (xrpm 1); false: a random one each (xrpm 0)
##   on_is_off  true: "on" = "off" × 2 (xload 1, powers in "lufs"); default: independent shapes (xload 0)
##   saturation amount of layers.saturation (default 0 – the plain mixer stays linear but for its tanh)
##   variants   cycle variants per stereo bank (default 4)
##   in_level   amplitude of the induction layer (default 0.1)
## Deterministic: fixed seeds.

const SR := 16000
const PERIODS: Array[int] = [960, 768, 614, 492]      ## 2000, 2500, 3127, 3902 /min
const OVERLAP := 32
const HARMONICS := 6


static func rpm_of(period: int) -> float:
	return 120.0 * SR / float(period)


## [meta: Dictionary, samples: PackedFloat32Array (interleaved stereo)]
static func build(opts: Dictionary = {}) -> Array:
	var coherent := bool(opts.get("coherent", true))
	var on_is_off := bool(opts.get("on_is_off", false))
	var n_var := int(opts.get("variants", 4))
	var in_level := float(opts.get("in_level", 0.1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261111
	var samples := PackedFloat32Array()
	var banks: Array = []
	# base shapes: per layer and channel the phases of the harmonics
	var shape := func(r: RandomNumberGenerator) -> PackedFloat64Array:
		var ph := PackedFloat64Array()
		for h in HARMONICS:
			ph.append(r.randf() * TAU)
		return ph
	var base := {"off": [shape.call(rng), shape.call(rng)], "on": [shape.call(rng), shape.call(rng)]}
	for pi in PERIODS.size():
		var p := PERIODS[pi]
		var shapes := base
		if not coherent:
			shapes = {"off": [shape.call(rng), shape.call(rng)], "on": [shape.call(rng), shape.call(rng)]}
		if on_is_off:
			shapes = {"off": shapes["off"], "on": shapes["off"]}
		var ms := {}
		for layer: String in ["off", "on"]:
			var amp := 0.18 if layer == "off" else (0.36 if on_is_off else 0.3)
			var cyc: Array = []
			var sq := 0.0
			for v in n_var:
				# variants: own level and own phase of the upper harmonics – a hard splice would jump
				var scale := 0.75 + 0.5 * float(v) / float(maxi(n_var - 1, 1))
				var twist := 0.9 * float(v)
				if on_is_off:
					scale = 1.0
					twist = 0.0
				var at := samples.size() / 2
				samples.resize(samples.size() + (p + OVERLAP) * 2)
				for k in p + OVERLAP:
					var x := float(k) / float(p)
					for c in 2:
						var ph: PackedFloat64Array = shapes[layer][c]
						var s := 0.0
						for h in HARMONICS:
							s += sin(TAU * float(h + 1) * x + ph[h] + (twist if h >= 2 else 0.0)) / float(h + 1)
						s *= amp * scale
						samples[(at + k) * 2 + c] = s
						if k < p:
							sq += s * s
				cyc.append([at, p + OVERLAP, 0])
			ms[layer] = sq / float(2 * n_var * p)
			banks.append({"rpm": rpm_of(p), "layer": layer, "period": float(p), "overlap": OVERLAP, "gain": 1.0,
				"lufs": 10.0 * log(maxf(2.0 * float(ms[layer]), 1.0e-12)) / log(10.0), "xrpm": 1.0 if coherent else 0.0,
				"xload": 1.0 if on_is_off else 0.0, "cycles": cyc})
		# induction: mono, a 12th harmonic; four variants in two stereo blocks
		var incyc: Array = []
		for blk in 2:
			var at := samples.size() / 2
			samples.resize(samples.size() + (p + OVERLAP) * 2)
			for k in p + OVERLAP:
				var x := float(k) / float(p)
				samples[(at + k) * 2] = in_level * (0.9 + 0.1 * blk) * sin(TAU * 12.0 * x)
				samples[(at + k) * 2 + 1] = in_level * (1.0 + 0.1 * blk) * sin(TAU * 12.0 * x + 0.2)
			incyc.append([at, p + OVERLAP, 1])
			incyc.append([at, p + OVERLAP, 2])
		banks.append({"rpm": rpm_of(p), "layer": "in", "period": float(p), "overlap": OVERLAP, "gain": 1.0,
			"lufs": 10.0 * log(in_level * in_level) / log(10.0), "xrpm": 1.0, "xload": 0.0, "cycles": incyc})
	# clips: decaying noise bursts; the stereo ones differ between the channels (left louder)
	var clips := {}
	var clip := func(frames: int, left: float, right: float) -> Array:
		var at := samples.size() / 2
		samples.resize(samples.size() + frames * 2)
		for k in frames:
			var env := exp(-float(k) / (0.25 * frames)) * minf(float(k) / 8.0, 1.0)
			var n := rng.randf_range(-1.0, 1.0)
			samples[(at + k) * 2] = left * env * n
			samples[(at + k) * 2 + 1] = right * env * n
		return [at, frames, 0]
	clips["crackle"] = [clip.call(400, 0.5, 0.25), clip.call(500, 0.5, 0.25), clip.call(300, 0.5, 0.25)]
	# two mono clips packed into one stereo block (modes 1 and 2): the mixer pans them
	var pair: Array = clip.call(600, 0.4, 0.4)
	clips["shift"] = [[pair[0], 600, 1], [pair[0], 600, 2]]
	clips["start"] = [clip.call(8000, 0.3, 0.3)]
	var meta := {"format": "ce-engine-bank-2", "car": "fixture", "sample_rate": SR, "channels": 2, "data": "fixture.i16",
		"engine": {"label": "Fixture", "cylinders": 4, "layout": "inline", "fuel": "petrol", "aspiration": "turbo",
			"idle_rpm": 1950, "redline_rpm": 3800, "limiter_rpm": 3900},
		"gearbox": {"kmh_per_1000rpm": [20.0, 32.0, 46.0, 60.0], "upshift_rpm": [2600, 3700], "downshift_rpm": [2100, 2900],
			"shift_time_s": 0.15, "launch_rpm": 2600},
		"banks": banks, "clips": clips,
		"layers": {"limiter": {"cut_cycles": 2, "on_cycles": 3, "pop": 0.0},
			"crackle": {"min_rpm": 2600, "rate_hz": 30.0, "duration_s": 1.0, "level": 0.6, "pan": 0.5},
			"shift": {"pan": 0.5},
			"turbo": {"whistle_hz": [1500, 4000], "level": 0.1, "spool_s": 0.3, "boost_rpm": 2000, "depth": 0.0,
				"tone": "turbo_single", "tone_level": 0.05, "hiss": "turbo_hiss", "hiss_level": 0.03},
			"blowoff": {"min_boost": 0.5, "level": 0.4, "sound": "blowoff_soft"},
			"saturation": {"amount": float(opts.get("saturation", 0.0)), "bias": 0.1, "comp": 0.55, "floor": 0.4},
			"driveline": {"wheel_m": 2.0, "final_ratio": 3.0, "pinion_teeth": 12, "mesh_teeth": 29, "sound": "driveline_whine",
				"fd_level": 0.01, "gm_level": 0.01},
			"tipin": {"sound": "tipin", "level": 1.0}, "thump": {"sound": "shift_thump", "level": 1.0}},
		"mix": {"gain": 1.0, "off_gain": 1.0, "in_gain": 1.0, "idle_load": 0.0, "load_curve": 1.0,
			"clip_gain": {"crackle": 1.0, "shift": 1.0, "start": 1.0}}}
	return [meta, samples]


## The fixture as a loaded bank (errors in bank.errors).
static func bank(opts: Dictionary = {}) -> EngineBank2:
	var ms := build(opts)
	return EngineBank2.from_dict(ms[0], ms[1], "fixture")
