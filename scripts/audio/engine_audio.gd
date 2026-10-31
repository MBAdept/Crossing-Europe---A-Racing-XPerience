class_name EngineAudio
extends RefCounted
## Engine sound of one car from its cycle bank (EngineBank; contract docs/motorsound.md §4).
##
## Cycle-synchronous overlap-add: a cycle phase (0..1 per working cycle = two revolutions) advances with the
## current rpm. Every output sample mixes the two neighbouring rpm banks × both loads; each source reads its
## current cycle at phase · period (read step rpm / bank_rpm, linear interpolation). Weights: linear in log rpm
## between the two rpm points, equal-power between the loads (smoothed engine load), "off" scaled by
## mix.off_gain. At every cycle boundary each bank picks a new random variant (never the same twice in a row);
## for the first overlap samples of the new cycle the previous cycle keeps playing past its end and is
## crossfaded out (smoothstep), so variants never splice hard. All banks share the cycle start (arrival of
## cylinder 1's pulse), so rpm and load blends stay in phase.
##
## Layers (bank "layers"/"clips", missing = off): turbo whistle (procedural sine; boost follows load × spool curve
## with spool_s lag, the shaft spins down slowly), blow-off clip on lifting with boost, crackle clips Poisson-timed
## for duration_s after lifting above min_rpm, limiter cut pattern (cut_cycles overrun cycles after on_cycles
## fired cycles, rpm droops while cut), shift crack on loaded upshifts, start clip at the race start.
##
## Use:
##   update(dt, speed_kmh, throttle, vmax_kmh, active)  once per frame (EngineGearbox + layer control)
##   render(out, offset, count)    mixing core: writes `count` samples (bank sample rate) into any
##                                 PackedFloat32Array – no AudioServer (tests, tools/audio/render_engine_demo.gd)
##   attach(parent, bus, buffer_s) / pump(latency_s, frame_dt) / detach()   live playback through an
##                                 AudioStreamGenerator (mix_rate = bank sample rate); pump() keeps at least
##                                 latency_s queued (more at low frame rates or with long driver mix periods).
##   start(with_clip), fade_to(gain, seconds), is_silent(), state() -> {rpm, gear, load, boost}
##   preview_throttle(t)           throttle of the vehicle-select rev blip (idle -> blip -> idle, PREVIEW_S)
## Tests drive the mixer directly with set_manual(rpm, load).

const SUB := 128                 ## control block: gains, load, gate and whistle are updated per block
const LOAD_TAU := 0.045          ## s, smoothing of the engine load (throttle response of the sound)
const GATE_TAU := 0.003          ## s, limiter cut on/off
const SOFT := 0.9                ## output soft limit: linear up to here, then tanh towards ±1
const LOOP_FADE_S := 0.25        ## fade-in of the cycle sound (start, preview)
const START_OVERLAP_S := 0.3     ## the cycle sound fades in this long before the start clip ends
const NEUTRAL_BOOST := 0.45      ## revving without load (standstill) builds only this share of the boost
const PREVIEW_S := 1.5           ## vehicle-select rev blip: total length …
const PREVIEW_BLIP := Vector2(0.25, 0.3)   ## … throttle from 0.25 s for 0.3 s
const PREVIEW_THROTTLE := 0.9

var bank: EngineBank
var gearbox: EngineGearbox
var rng := RandomNumberGenerator.new()
var level := 1.0                 ## linear gain on top of mix.gain (config audio.engine_db)
var manual := false              ## true: set_manual() drives rpm/load, the gearbox is not used
## Debug/test hooks: with debug_wraps, `wraps` collects the sample positions of all cycle starts,
## `variants_log` the variant chosen for bank `debug_bank` and `gates_log` the limiter gate (1 fired, 0 cut) at
## each of them. clips_started counts started clips per name.
var debug_wraps := false
var debug_bank := 0
var wraps := PackedInt32Array()
var variants_log := PackedInt32Array()
var gates_log := PackedInt32Array()
var clips_started := {}
## Live playback (attach/pump): render time statistics.
var player: AudioStreamPlayer
var perf_calls := 0
var perf_us_sum := 0
var perf_us_max := 0
var perf_samples := 0

# control (update / set_manual)
var _rpm_goal := 800.0
var _rpm_step := 0.0             # rpm per sample towards the goal
var _load_goal := 0.0
var _limiter := false
var _boost := 0.0
var _shaft := 0.0
var _load_peak := 0.0
var _lift_armed := false
var _crackle_left := 0.0
var _crackle_amt := 0.0
var _start_delay := 0.0
var _loop_goal := 1.0
var _w_jit := 0.0

# render state
var _rpm := 800.0
var _ph := 0.0
var _cur := PackedInt32Array()
var _prev := PackedInt32Array()
var _lo := 0
var _load_s := 0.0
var _gate := 1.0
var _gate_s := 1.0
var _lim_n := 0
var _droop := 0.0
var _gain := 1.0
var _gain_goal := 1.0
var _gain_step := 1.0
var _loop := 1.0
var _w_c := 1.0
var _w_s := 0.0
var _w_amp := 0.0
var _clip_pos := PackedInt32Array()
var _clip_end := PackedInt32Array()
var _clip_wait := PackedInt32Array()
var _clip_gain := PackedFloat32Array()
var _last_clip := {}
var _clock := 0
var _phbuf := PackedFloat64Array()
var _wrapbuf := PackedInt32Array()
var _vb := PackedInt32Array([0, 0, 0, 0])
var _vg0 := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
var _vg1 := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])

# layer parameters (from the bank)
var _redline := 6500.0
var _turbo := false
var _whistle := Vector2(1800.0, 5200.0)
var _turbo_level := 0.0
var _spool_s := 0.55
var _boost_rpm := 2200.0
var _crackle := false
var _crackle_min := 3200.0
var _crackle_rate := 7.0
var _crackle_dur := 1.4
var _crackle_level := 0.6
var _blowoff := false
var _blowoff_min := 0.55
var _blowoff_level := 0.5
var _lim_pattern := false
var _lim_cut := 2
var _lim_on := 3

# live output
var _playback: AudioStreamGeneratorPlayback
var _capacity := 0
var _scratch := PackedFloat32Array()
var _frames := PackedVector2Array()
var _frame_dt := 1.0 / 60.0
var _queued := 0
var _burst := 0.0


func _init(p_bank: EngineBank, p_seed: int = -1) -> void:
	bank = p_bank
	if p_seed >= 0:
		rng.seed = p_seed
	else:
		rng.randomize()
	gearbox = EngineGearbox.new().setup(bank.gearbox, bank.engine,
		bank.clip_count("shift") > 0 or bank.has_layer("crackle"))
	_redline = gearbox.redline_rpm
	var nb := bank.bank_count()
	_cur.resize(nb)
	_prev.resize(nb)
	for b in nb:
		_cur[b] = bank.var_first[b] + rng.randi_range(0, bank.var_count[b] - 1)
		_prev[b] = -1
	_phbuf.resize(SUB)
	_wrapbuf.resize(8)
	var t := bank.layer("turbo")
	_turbo = not t.is_empty()
	if _turbo:
		_whistle = Vector2(float(t["whistle_hz"][0]), float(t["whistle_hz"][1]))
		_turbo_level = float(t["level"])
		_spool_s = maxf(float(t["spool_s"]), 0.02)
		_boost_rpm = float(t["boost_rpm"])
	var c := bank.layer("crackle")
	_crackle = not c.is_empty() and bank.clip_count("crackle") > 0
	if _crackle:
		_crackle_min = float(c["min_rpm"])
		_crackle_rate = float(c["rate_hz"])
		_crackle_dur = maxf(float(c["duration_s"]), 0.05)
		_crackle_level = float(c["level"])
	var bo := bank.layer("blowoff")
	_blowoff = not bo.is_empty() and bank.clip_count("blowoff") > 0
	if _blowoff:
		_blowoff_min = float(bo["min_boost"])
		_blowoff_level = float(bo["level"])
	var lim := bank.layer("limiter")
	_lim_pattern = not lim.is_empty()
	if _lim_pattern:
		_lim_cut = int(lim["cut_cycles"])
		_lim_on = int(lim["on_cycles"])
	_rpm = gearbox.rpm
	_rpm_goal = _rpm


# --- control --------------------------------------------------------------------------------------

## One frame of the car: speed (km/h), throttle 0..1, current vmax, active = engine drives the car.
func update(dt: float, speed_kmh: float, throttle: float, vmax_kmh: float = 0.0, active: bool = true) -> void:
	if dt <= 0.0:
		return
	if not manual:
		gearbox.update(dt, speed_kmh, throttle, vmax_kmh, active)
		if _start_delay > 0.0:
			_start_delay -= dt
			if _start_delay <= 0.0:
				# the engine catches: a short flare above idle, then the cycle sound fades in
				gearbox.rpm = maxf(gearbox.rpm, gearbox.idle_rpm * 1.3)
				_loop_goal = 1.0
		_set_goals(gearbox.rpm, gearbox.load, gearbox.limiter, dt)
		if gearbox.ev_upshift:
			_on_upshift()
	_update_layers(dt)


## Tests/tools: drive the mixer directly (gearbox bypassed). dt > 0 ramps to the rpm over dt seconds of audio,
## dt = 0 jumps.
func set_manual(rpm: float, load: float, limiter_on: bool = false, dt: float = 0.0) -> void:
	manual = true
	if dt <= 0.0:
		_rpm = rpm
		_rpm_goal = rpm
		_rpm_step = 0.0
		_load_goal = clampf(load, 0.0, 1.0)
		_load_s = _load_goal
		_limiter = limiter_on
	else:
		_set_goals(rpm, load, limiter_on, dt)
		_update_layers(dt)


func _set_goals(rpm: float, load: float, limiter_on: bool, dt: float) -> void:
	_rpm_goal = rpm
	_rpm_step = absf(rpm - _rpm) / maxf(dt * float(bank.sample_rate), 1.0)
	_load_goal = clampf(load, 0.0, 1.0)
	_limiter = limiter_on


## Engine start: with_clip plays the bank's start clip (if any) and fades the cycle sound in near its end;
## otherwise the cycle sound fades in at once.
func start(with_clip: bool = true) -> void:
	_gain = 1.0
	_gain_goal = 1.0
	_loop = 0.0
	var clip_s := bank.clip_seconds("start") if with_clip else 0.0
	if clip_s > 0.0:
		_play_clip("start", 0, 1.0, 0)
		_start_delay = maxf(clip_s - START_OVERLAP_S, 0.01)
		_loop_goal = 0.0
	else:
		_start_delay = 0.0
		_loop_goal = 1.0


## Output fade (pause, scene change, preview end): gain 0..1 within `seconds`.
func fade_to(gain: float, seconds: float) -> void:
	_gain_goal = clampf(gain, 0.0, 1.0)
	_gain_step = 1.0 / maxf(seconds * float(bank.sample_rate), 1.0)


## Throttle of the vehicle-select rev blip at time t (s): idle, a short blip, back to idle.
static func preview_throttle(t: float) -> float:
	return PREVIEW_THROTTLE if t >= PREVIEW_BLIP.x and t < PREVIEW_BLIP.x + PREVIEW_BLIP.y else 0.0


## Faded out completely (clips are scaled by the same gain): nothing left to render.
func is_silent() -> bool:
	return _gain <= 0.0 and _gain_goal <= 0.0


## Back to idle, silent at once (stop_all, new race): start() or fade_to(1, …) brings the sound back.
func reset() -> void:
	_gain = 0.0
	_gain_goal = 0.0
	_loop = 0.0
	_loop_goal = 1.0
	gearbox.reset()
	_rpm = gearbox.rpm
	_rpm_goal = _rpm
	_rpm_step = 0.0
	_load_goal = 0.0
	_load_s = 0.0
	_limiter = false
	_boost = 0.0
	_shaft = 0.0
	_load_peak = 0.0
	_lift_armed = false
	_crackle_left = 0.0
	_start_delay = 0.0
	_gate = 1.0
	_gate_s = 1.0
	_lim_n = 0
	_droop = 0.0
	_w_amp = 0.0
	_clip_pos.clear()
	_clip_end.clear()
	_clip_wait.clear()
	_clip_gain.clear()


## {rpm, gear (0 = neutral), load 0..1, boost 0..1} – for tests and the HUD.
func state() -> Dictionary:
	if manual:
		return {"rpm": _rpm_goal, "gear": 0, "load": _load_goal, "boost": _boost}
	return {"rpm": gearbox.rpm, "gear": gearbox.gear, "load": gearbox.load, "boost": _boost}


func _update_layers(dt: float) -> void:
	var rpm := _rpm_goal
	var load := _load_goal
	if _turbo:
		var spool := smoothstep(_boost_rpm * 0.7, _boost_rpm * 1.4, rpm)
		var target := load * spool * (NEUTRAL_BOOST if not manual and gearbox.gear == 0 else 1.0)
		_boost += (target - _boost) * (1.0 - exp(-dt / (_spool_s if target > _boost else 0.16)))
		var shaft_t := 0.75 * _boost + 0.25 * clampf(rpm / _redline, 0.0, 1.0) * (0.3 + 0.7 * load)
		_shaft += (shaft_t - _shaft) * (1.0 - exp(-dt / (0.35 * _spool_s if shaft_t > _shaft else 0.9)))
	# lifting off (also the end of a downshift blip, not the cut of an upshift): crackles and blow-off
	var upshift_cut := not manual and gearbox.shifting and gearbox.shift_dir > 0
	_load_peak = maxf(load, _load_peak - dt / 0.35)
	if load > 0.5:
		_lift_armed = true
		if load > 0.6:
			_crackle_left = 0.0
	if _lift_armed and load < 0.2 and _load_peak > 0.6 and not upshift_cut:
		_lift_armed = false
		_on_lift(rpm)


func _on_lift(rpm: float) -> void:
	if _crackle and rpm >= _crackle_min:
		_crackle_left = _crackle_dur
		_crackle_amt = clampf(0.45 + 0.55 * (rpm - _crackle_min) / maxf(_redline - _crackle_min, 1.0), 0.45, 1.0)
	if _blowoff and _boost >= _blowoff_min:
		_play_clip("blowoff", -1, _blowoff_level * clampf(_boost, 0.0, 1.0), 0)
		_boost *= 0.3


## Loaded upshift: shift crack (ignition cut of a dual-clutch box). No blow-off – the throttle stays open.
func _on_upshift() -> void:
	if _load_peak > 0.6 and bank.clip_count("shift") > 0 and _rpm_goal > 0.4 * _redline:
		_play_clip("shift", -1, 0.55 + 0.35 * clampf(_rpm_goal / _redline, 0.0, 1.0), 0)


## Starts a clip variant (-1 = random, not the last one of this clip) after `wait` samples.
func _play_clip(clip_name: String, index: int, gain: float, wait: int) -> void:
	var c: PackedInt32Array = bank.clips.get(clip_name, PackedInt32Array())
	var n := c.size() / 2
	if n == 0:
		return
	var i := index
	if i < 0:
		i = rng.randi_range(0, n - 1)
		var last := int(_last_clip.get(clip_name, -1))
		if n > 1 and i == last:
			i = (i + 1 + rng.randi_range(0, n - 2)) % n
	i = clampi(i, 0, n - 1)
	_last_clip[clip_name] = i
	if _clip_pos.size() >= 8:
		return
	clips_started[clip_name] = int(clips_started.get(clip_name, 0)) + 1
	_clip_pos.append(c[i * 2])
	_clip_end.append(c[i * 2] + c[i * 2 + 1])
	_clip_wait.append(wait)
	_clip_gain.append(gain)


# --- mixing core ----------------------------------------------------------------------------------

## Writes `count` samples (bank sample rate, mono, within ±1) into out[offset … offset + count – 1].
## Pure: touches only this object's state and `out` – no AudioServer.
func render(out: PackedFloat32Array, offset: int, count: int) -> void:
	if count <= 0:
		return
	if offset == 0 and count == out.size():
		out.fill(0.0)
	else:
		for k in range(offset, offset + count):
			out[k] = 0.0
	var done := 0
	while done < count:
		var n := mini(SUB, count - done)
		_render_block(out, offset + done, n)
		done += n
	# output stage: NaN/inf guard and soft limit (linear up to SOFT, tanh towards ±1)
	var knee := 1.0 - SOFT
	for k in range(offset, offset + count):
		var x := out[k]
		if not (x >= -SOFT and x <= SOFT):
			if not (x > -1.0e6 and x < 1.0e6):
				out[k] = 0.0
			elif x > 0.0:
				out[k] = SOFT + knee * tanh((x - SOFT) / knee)
			else:
				out[k] = -SOFT - knee * tanh((-x - SOFT) / knee)


func _render_block(out: PackedFloat32Array, a: int, n: int) -> void:
	var sr := float(bank.sample_rate)
	var nf := float(n)
	# --- control values at the start (…0) and the end (…1) of the block, linear in between
	var r_start := _rpm * (1.0 - _droop)
	_rpm = move_toward(_rpm, _rpm_goal, _rpm_step * nf)
	_droop += ((0.03 if _gate < 0.5 else 0.0) - _droop) * (1.0 - exp(-nf / (sr * 0.025)))
	var r_end := _rpm * (1.0 - _droop)
	var idle := gearbox.idle_rpm
	var load_goal := maxf(_load_goal, bank.idle_load * clampf(1.0 - (_rpm - idle) / (0.5 * idle), 0.0, 1.0))
	var l0 := _load_s * _gate_s
	_load_s += (load_goal - _load_s) * (1.0 - exp(-nf / (sr * LOAD_TAU)))
	_gate_s += (_gate - _gate_s) * (1.0 - exp(-nf / (sr * GATE_TAU)))
	var l1 := _load_s * _gate_s
	var g0 := _gain
	_gain = move_toward(_gain, _gain_goal, _gain_step * nf)
	var g1 := _gain
	var lp0 := _loop
	_loop = move_toward(_loop, _loop_goal, nf / (sr * LOOP_FADE_S))
	var base := bank.mix_gain * level
	var c0 := g0 * lp0 * base
	var c1 := g1 * _loop * base
	# rpm pair: lo/hi from the block start, weights linear in log rpm
	var rp := bank.rpms
	var nr := rp.size()
	var lo := clampi(_lo, 0, nr - 1)
	while lo > 0 and r_start < rp[lo]:
		lo -= 1
	while lo < nr - 1 and r_start >= rp[lo + 1]:
		lo += 1
	_lo = lo
	var hi := mini(lo + 1, nr - 1)
	var wh0 := 0.0
	var wh1 := 0.0
	if hi != lo and r_start >= rp[0]:
		var la := bank.log_rpms[lo]
		var span := bank.log_rpms[hi] - la
		wh0 = clampf((log(r_start) - la) / span, 0.0, 1.0)
		wh1 = clampf((log(maxf(r_end, 1.0)) - la) / span, 0.0, 1.0)
	var on0 := sin(l0 * PI * 0.5)
	var on1 := sin(l1 * PI * 0.5)
	var off0 := cos(l0 * PI * 0.5) * bank.off_gain
	var off1 := cos(l1 * PI * 0.5) * bank.off_gain
	# --- cycle phase per sample; cycle starts (wraps) split the block into segments
	var inv := 1.0 / (120.0 * sr)
	var inc := r_start * inv
	var dinc := (r_end - r_start) * inv / nf
	var ph := _ph
	var phb := _phbuf
	var wb := _wrapbuf
	var nw := 0
	for k in n:
		phb[k] = ph
		ph += inc
		inc += dinc
		if ph >= 1.0:
			ph -= 1.0
			if nw < wb.size():
				wb[nw] = k + 1
				nw += 1
	_ph = ph
	# voices: (lo, off), (lo, on), (hi, off), (hi, on) with gains ramping linearly over the block
	var vb := _vb
	var vg0 := _vg0
	var vg1 := _vg1
	vb[0] = lo * 2
	vb[1] = lo * 2 + 1
	vb[2] = hi * 2
	vb[3] = hi * 2 + 1
	vg0[0] = (1.0 - wh0) * off0 * c0
	vg0[1] = (1.0 - wh0) * on0 * c0
	vg0[2] = wh0 * off0 * c0
	vg0[3] = wh0 * on0 * c0
	vg1[0] = (1.0 - wh1) * off1 * c1
	vg1[1] = (1.0 - wh1) * on1 * c1
	vg1[2] = wh1 * off1 * c1
	vg1[3] = wh1 * on1 * c1
	var nv := 4 if hi != lo else 2
	var s := 0
	for wi in nw + 1:
		var e := wb[wi] if wi < nw else n
		if e > s:
			for v in nv:
				var ga := vg0[v]
				var gb := vg1[v]
				if ga > 1.0e-5 or gb > 1.0e-5:
					var dg := (gb - ga) / nf
					_voice(out, a, s, e, vb[v], ga + dg * s, dg)
		if wi < nw:
			_next_cycle(e)
		s = e
	# --- layers
	_render_whistle(out, a, n, g0 * base, g1 * base, sr)
	_render_crackles(nf / sr, n)
	_render_clips(out, a, n, 0.5 * (g0 + g1) * base)
	_clock += n


## Adds bank b over block samples [s, e) to out (block starts at out index a); gain g at s, +dg per sample.
func _voice(out: PackedFloat32Array, a: int, s: int, e: int, b: int, g: float, dg: float) -> void:
	var d := bank.data
	var phb := _phbuf
	var p := bank.periods[b]
	var base := bank.cyc_off[_cur[b]]
	var k := s
	var prev := _prev[b]
	if prev >= 0:
		# crossfade zone: the previous cycle continues past its end for (overlap - 4) samples; the margin keeps
		# its interpolated reads inside its [offset, length] even with rounding of period
		var ov := float(bank.overlaps[b] - 4)
		var fz := ov / p
		if phb[s] < fz:
			var basep := bank.cyc_off[prev]
			var iov := 1.0 / ov
			while k < e:
				var phk := phb[k]
				if phk >= fz:
					break
				var pos := phk * p
				var i0 := int(pos)
				var x0 := d[base + i0]
				var xn := x0 + (d[base + i0 + 1] - x0) * (pos - i0)
				var pp := pos + p
				var i1 := int(pp)
				var y0 := d[basep + i1]
				var xo := y0 + (d[basep + i1 + 1] - y0) * (pp - i1)
				var u := pos * iov
				out[a + k] += (xo + (xn - xo) * (u * u * (3.0 - 2.0 * u))) * g
				g += dg
				k += 1
	for j in range(k, e):
		var pos := phb[j] * p
		var i0 := int(pos)
		var x0 := d[base + i0]
		out[a + j] += (x0 + (d[base + i0 + 1] - x0) * (pos - i0)) * g
		g += dg


## Cycle boundary at block sample `rel`: every bank moves on to a new random variant (never the current one);
## the limiter pattern advances by one cycle.
func _next_cycle(rel: int) -> void:
	var nb := _cur.size()
	var vf := bank.var_first
	var vc := bank.var_count
	for b in nb:
		var c := _cur[b]
		_prev[b] = c
		var first := vf[b]
		var r := rng.randi_range(0, vc[b] - 2)
		if first + r >= c:
			r += 1
		_cur[b] = first + r
	if _limiter and _lim_pattern:
		_gate = 0.0 if (_lim_n % (_lim_cut + _lim_on)) < _lim_cut else 1.0
		_lim_n += 1
	else:
		_lim_n = 0
		_gate = 1.0
	if debug_wraps:
		wraps.append(_clock + rel)
		gates_log.append(int(_gate))
		if debug_bank >= 0 and debug_bank < nb:
			variants_log.append(_cur[debug_bank])


func _render_whistle(out: PackedFloat32Array, a: int, n: int, ga: float, gb: float, sr: float) -> void:
	if not _turbo:
		return
	var amp0 := _w_amp
	var sh := clampf(_shaft, 0.0, 1.0)
	_w_jit = clampf(_w_jit + rng.randf_range(-0.15, 0.15), -1.0, 1.0)
	var amp1 := _turbo_level * pow(sh, 1.6) * (0.35 + 0.65 * _load_s) * (1.0 + 0.08 * _w_jit)
	_w_amp = amp1
	if amp0 < 1.0e-5 and amp1 < 1.0e-5:
		return
	var freq := minf(lerpf(_whistle.x, _whistle.y, pow(sh, 0.8)) * (1.0 + 0.004 * _w_jit), 0.45 * sr)
	var dth := TAU * freq / sr
	var cr := cos(dth)
	var sn := sin(dth)
	var c := _w_c
	var s := _w_s
	var amp := amp0 * ga
	var damp := (amp1 * gb - amp) / float(n)
	for k in range(a, a + n):
		var nc := c * cr - s * sn
		s = c * sn + s * cr
		c = nc
		out[k] += s * amp
		amp += damp
	var m := 1.0 / sqrt(c * c + s * s)
	_w_c = c * m
	_w_s = s * m


## Poisson-timed crackles after lifting: probability rate · intensity · dt per block, random start in the block.
func _render_crackles(dt: float, n: int) -> void:
	if _crackle_left <= 0.0:
		return
	_crackle_left -= dt
	if _load_s >= 0.3:
		return
	var x := clampf(_crackle_left / _crackle_dur, 0.0, 1.0)
	if rng.randf() < _crackle_rate * (0.3 + 0.7 * x) * _crackle_amt * dt:
		var g := _crackle_level * rng.randf_range(0.35, 1.0) * (0.35 + 0.65 * x * _crackle_amt)
		_play_clip("crackle", -1, g, rng.randi_range(0, n - 1))


func _render_clips(out: PackedFloat32Array, a: int, n: int, gain: float) -> void:
	var d := bank.data
	var i := 0
	while i < _clip_pos.size():
		var wait := _clip_wait[i]
		if wait >= n:
			_clip_wait[i] = wait - n
			i += 1
			continue
		var pos := _clip_pos[i]
		var m := mini(n - wait, _clip_end[i] - pos)
		var g := _clip_gain[i] * gain
		var o := a + wait - pos
		for k in range(pos, pos + m):
			out[o + k] += d[k] * g
		pos += m
		_clip_wait[i] = 0
		if pos >= _clip_end[i]:
			_clip_pos.remove_at(i)
			_clip_end.remove_at(i)
			_clip_wait.remove_at(i)
			_clip_gain.remove_at(i)
		else:
			_clip_pos[i] = pos
			i += 1


# --- live playback --------------------------------------------------------------------------------

## Creates the AudioStreamPlayer (AudioStreamGenerator, mix_rate = bank sample rate) under `parent`.
func attach(parent: Node, bus: String = "SFX", buffer_s: float = 0.25) -> void:
	if player != null:
		return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate_mode = AudioStreamGenerator.MIX_RATE_CUSTOM
	gen.mix_rate = float(bank.sample_rate)
	gen.buffer_length = buffer_s
	player = AudioStreamPlayer.new()
	player.stream = gen
	player.bus = bus
	parent.add_child(player)


## Takes over the player of `other` (same sample rate: the stream continues without a gap, e.g. the next
## preview after the previous one faded out); otherwise frees it and attaches a new one.
func take_output(other: EngineAudio, parent: Node, bus: String = "SFX", buffer_s: float = 0.25) -> void:
	if other.player != null and other.bank.sample_rate == bank.sample_rate and player == null:
		player = other.player
		_playback = other._playback
		_capacity = other._capacity
		_queued = other._queued
		_burst = other._burst
		_frame_dt = other._frame_dt
		other.player = null
		other._playback = null
		return
	other.detach()
	attach(parent, bus, buffer_s)


## Keeps latency_s of audio queued in the generator, more when needed: at least 1.6 frame times (smoothed
## frame_dt, low frame rates) and 1.25 × the largest block the audio driver took between two fills (decaying
## maximum; drivers with long mix periods), at most 90 % of the buffer. Faded out: stops filling, stops the
## player once the queue has played. Returns the number of frames rendered.
func pump(latency_s: float, frame_dt: float = 0.0) -> int:
	if player == null:
		return 0
	if frame_dt > 0.0:
		_frame_dt += (minf(frame_dt, 0.25) - _frame_dt) * 0.1
	if is_silent():
		if player.playing and (_playback == null or _playback.get_frames_available() >= _capacity):
			player.stop()
			_playback = null
		return 0
	if not player.playing or _playback == null:
		player.play()
		_playback = player.get_stream_playback() as AudioStreamGeneratorPlayback
		if _playback == null:
			return 0
		_capacity = _playback.get_frames_available()
		_queued = 0
	var free := _playback.get_frames_available()
	var queued := _capacity - free
	_burst = maxf(float(_queued - queued), _burst * 0.995)
	var target := mini(maxi(int(maxf(latency_s, 1.6 * _frame_dt) * bank.sample_rate), int(_burst * 1.25)),
		int(_capacity * 0.9))
	var need := mini(target - queued, free)
	_queued = queued
	if need <= 0:
		return 0
	_queued = queued + need
	var t0 := Time.get_ticks_usec()
	if _scratch.size() != need:
		_scratch.resize(need)
		_frames.resize(need)
	render(_scratch, 0, need)
	for k in need:
		var x := _scratch[k]
		_frames[k] = Vector2(x, x)
	_playback.push_buffer(_frames)
	var us := Time.get_ticks_usec() - t0
	perf_calls += 1
	perf_us_sum += us
	perf_us_max = maxi(perf_us_max, us)
	perf_samples += need
	return need


## Underruns of the current generator playback (the queue ran empty; 0 without playback).
func skips() -> int:
	return _playback.get_skips() if _playback != null else 0


## Frees the player (stop; the AudioServer fades the voice out).
func detach() -> void:
	if player != null:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
		player = null
	_playback = null
	_capacity = 0
