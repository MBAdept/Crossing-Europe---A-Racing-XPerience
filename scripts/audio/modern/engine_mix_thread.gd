class_name EngineMixThread
extends RefCounted
## Mixer of the engine v3 (sound profile "Modern", contract D27; docs/motorsound.md "Modern"): plays an EngineBank2
## cycle-synchronously in stereo and feeds an AudioStreamGenerator – from a worker thread, or synchronously on the
## calling thread (tests, Movie Maker, --audio-sync, audio.modern.engine_thread = false).
##
## The algorithm is the one of the Arcade EngineAudio, with two channels and three layers: a cycle phase (0..1 per
## working cycle) advances with the rpm; every output frame mixes the two neighbouring rpm points × the layers
## "off", "on" (stereo) and "in" (mono), each read at phase · period of its bank (linear interpolation). At every
## cycle start each bank moves on to a random other variant; the previous cycle plays on past its end and is
## crossfaded out over the overlap. On top of that:
##   • exhaust and induction are separate voices: "on" / "off" follow the engine load (attack LOAD_UP_S, release
##     LOAD_DOWN_S, cut by the limiter gate), "in" follows the pedal (THR_UP_S / THR_DOWN_S) and the boost; a
##     turbo engine's "on" grows with the boost (layers.turbo.depth);
##   • blends keep the power: between two rpm points with the measured coherence of the pair (bank.xrpm), between
##     the loads with bank.xload and the banks' powers – no level dip where two banks do not add up in phase;
##   • slow movement, never a static loop: band-limited random drift of the engine speed (motion_rpm), of the level
##     of the load layer (motion_level_db) and of the load itself (motion_load), and a gain step per cycle
##     (motion_cycle_db);
##   • saturation that grows with load × rpm (layers.saturation): y = (tanh(x·d + b) − tanh b) / d^comp;
##   • clips of the bank after the saturation: crackles (Poisson-timed after lifting), shift cracks, the start clip,
##     pops on the limiter; mono clips are panned, each clip group has its gain (mix.clip_gain);
##   • mix.gain × level, the output fade and a soft limit (linear up to SOFT, tanh towards ±1) at the end.
##
## Threads: the game thread only writes a small control block under a mutex (drive(), fade_to(), start(),
## play_clip(), lift()); everything else belongs to the render side – the worker thread started by pump(), or the
## caller of render() / pump() in synchronous mode. reset() and detach() stop the worker first.
## The worker keeps `latency` seconds queued (more when the audio driver takes larger blocks) in chunks of CHUNK
## frames and fades the engine out when the game thread sent nothing for WATCHDOG_S (a frozen window, a long load).
##
## Use (EngineAudio3 owns one per sounding engine):
##   drive(rpm, load, throttle, boost, limiter, dt)   once per frame
##   attach(player, buffer_s) / pump(latency_s, frame_dt) / detach()   live playback
##   render(out, offset, count)   the mixing core into a PackedVector2Array – no AudioServer (tests, tools)
##   set_manual(rpm, load, throttle, boost)   tests and tools drive the mixer directly

const SUB := 128                 ## control block: gains, load, gate and movement are updated per block
const CHUNK := 256               ## frames per push of the worker thread
const LOAD_UP_S := 0.022         ## s, engine load of the sound rising / falling
const LOAD_DOWN_S := 0.060
const THR_UP_S := 0.012          ## s, induction following the pedal
const THR_DOWN_S := 0.045
const BOOST_TAU := 0.03          ## s, smoothing of the boost value of the game thread
const GATE_TAU := 0.003          ## s, limiter cut on/off
const SOFT := 0.9                ## output soft limit: linear up to here, then tanh towards ±1
const LOOP_FADE_S := 0.25        ## fade-in of the cycle sound (start, preview)
const START_OVERLAP_S := 0.3     ## the cycle sound fades in this long before the start clip ends
const WATCHDOG_S := 0.75         ## worker: no control for this long -> the engine fades out until control returns
const WATCHDOG_FADE_S := 0.12
const MIN_RHO := -0.6            ## coherence floor of the power-true rpm blend
const MAX_CLIPS := 10
const MAX_EVENTS := 32           ## pending control events (they are taken with every rendered chunk)

var bank: EngineBank2
var rng := RandomNumberGenerator.new()
var level := 1.0                 ## linear gain on top of mix.gain (config audio.modern.engine.level_db)
## Slow movement (see above); 0 switches a part off (tests of the plain mixer).
var motion_rpm := 0.0012
var motion_level_db := 0.6
var motion_load := 0.05
var motion_cycle_db := 0.5
## Debug/test hooks (render side): with debug_wraps, `wraps` collects the frame positions of all cycle starts,
## `variants_log` the variant chosen for bank `debug_bank`, `gates_log` the limiter gate at each of them.
var debug_wraps := false
var debug_bank := 0
var wraps := PackedInt32Array()
var variants_log := PackedInt32Array()
var gates_log := PackedInt32Array()
var clips_started := {}
var player: AudioStreamPlayer = null

# --- control block (game thread writes under _mutex, render side takes it) -------------------------
var _mutex := Mutex.new()
var _c_seq := 0
var _c_rpm := 800.0
var _c_load := 0.0
var _c_thr := 0.0
var _c_boost := 0.0
var _c_limiter := false
var _c_dt := 0.0                 # ramp time of the rpm; 0 = jump (set_manual)
var _c_events: Array = []
var _c_gain_goal := 1.0          # what the game thread asked for last (is_silent())
var _c_usec := 0                 # wall clock of the last control call
# status published by the render side
var _s_gain := 1.0
var _s_queued := 0
var _s_calls := 0
var _s_us_sum := 0
var _s_us_max := 0
var _s_samples := 0
# worker thread
var _thread: Thread = null
var _t_run := false
var _t_latency := 0.05

# --- render side ----------------------------------------------------------------------------------
var _sr := 32000.0
var _idle_rpm := 800.0
var _redline := 6500.0
var _seq_seen := -1
var _rpm := 800.0
var _rpm_goal := 800.0
var _rpm_step := 0.0
var _load_goal := 0.0
var _thr_goal := 0.0
var _boost_goal := 0.0
var _limiter := false
var _ph := 0.0
var _cur := PackedInt32Array()
var _prev := PackedInt32Array()
var _lo := 0
var _load_s := 0.0
var _thr_s := 0.0
var _boost_s := 0.0
var _gate := 1.0
var _gate_s := 1.0
var _lim_n := 0
var _droop := 0.0
var _gain := 1.0
var _gain_goal := 1.0
var _gain_step := 1.0
var _loop := 1.0
var _loop_goal := 1.0
var _start_wait := 0             # frames until the cycle sound fades in under the start clip
var _wd := 1.0                   # watchdog gain
var _wd_goal := 1.0
var _m_rpm := 0.0                # slow movement: unit-variance drift processes
var _m_amp := 0.0
var _m_load := 0.0
var _cyc_goal := 1.0
var _cyc_g := 1.0
var _e_r := 800.0                # values at the end of the last block (start of the next one)
var _e_l := 0.0
var _e_in := 0.0
var _e_amp := 1.0
var _e_on := 1.0
var _e_loop := 1.0
var _e_drive := 1.0
var _crackle_left := 0.0
var _crackle_amt := 0.0
var _clip_base := PackedInt32Array()
var _clip_pos := PackedInt32Array()
var _clip_len := PackedInt32Array()
var _clip_wait := PackedInt32Array()
var _clip_mono := PackedByteArray()
var _clip_gl := PackedFloat32Array()
var _clip_gr := PackedFloat32Array()
var _last_clip := {}
var _clock := 0
var _phbuf := PackedFloat64Array()
var _wrapbuf := PackedInt32Array()
var _l := PackedFloat32Array()
var _r := PackedFloat32Array()
var _cl := PackedFloat32Array()
var _cr := PackedFloat32Array()
var _g0 := PackedFloat64Array()
var _g1 := PackedFloat64Array()
# layer parameters (from the bank)
var _sat_amount := 1.0
var _sat_bias := 0.1
var _sat_comp := 0.55
var _turbo_depth := 0.0
var _in_base := 1.0
var _crackle := false
var _crackle_rate := 7.0
var _crackle_dur := 1.4
var _crackle_level := 0.6
var _crackle_pan := 0.0
var _crackle_gain := 1.0
var _shift_pan := 0.0
var _lim_pattern := false
var _lim_cut := 2
var _lim_on := 3
var _lim_pop := 0.0
# live output
var _playback: AudioStreamGeneratorPlayback = null
var _capacity := 0
var _frames := PackedVector2Array()
var _tail := PackedVector2Array()
var _frame_dt := 1.0 / 60.0
var _queued := 0
var _burst := 0.0
var _pump_usec := 0
var _silent_s := 0.0


func _init(p_bank: EngineBank2, p_seed: int = -1) -> void:
	bank = p_bank
	if p_seed >= 0:
		rng.seed = p_seed
	else:
		rng.randomize()
	_sr = float(bank.sample_rate)
	_idle_rpm = float(bank.engine.get("idle_rpm", 800.0))
	_redline = float(bank.engine.get("redline_rpm", 6500.0))
	var nb := bank.bank_count()
	_cur.resize(nb)
	_prev.resize(nb)
	for b in nb:
		_cur[b] = bank.var_first[b] + rng.randi_range(0, bank.var_count[b] - 1)
		_prev[b] = -1
	_phbuf.resize(SUB)
	_wrapbuf.resize(8)
	_l.resize(SUB)
	_r.resize(SUB)
	_cl.resize(SUB)
	_cr.resize(SUB)
	_g0.resize(6)
	_g1.resize(6)
	_frames.resize(CHUNK)
	var sat := bank.layer("saturation")
	_sat_amount = maxf(float(sat.get("amount", 0.0)), 0.0)
	_sat_bias = float(sat.get("bias", 0.1))
	_sat_comp = float(sat.get("comp", 0.55))
	var t := bank.layer("turbo")
	_turbo_depth = clampf(float(t.get("depth", 0.0)), 0.0, 0.9)
	_in_base = 0.55 if not t.is_empty() else 1.0
	var c := bank.layer("crackle")
	_crackle = not c.is_empty() and bank.clip_count("crackle") > 0
	if _crackle:
		_crackle_rate = float(c.get("rate_hz", 7.0))
		_crackle_dur = maxf(float(c.get("duration_s", 1.4)), 0.05)
		_crackle_level = float(c.get("level", 0.6))
		_crackle_pan = float(c.get("pan", 0.0))
	_crackle_gain = float(bank.clip_gain.get("crackle", 1.0))
	_shift_pan = float(bank.layer("shift").get("pan", 0.0))
	var lim := bank.layer("limiter")
	_lim_pattern = not lim.is_empty()
	if _lim_pattern:
		_lim_cut = maxi(int(lim.get("cut_cycles", 2)), 1)
		_lim_on = maxi(int(lim.get("on_cycles", 3)), 1)
		_lim_pop = float(lim.get("pop", 0.0)) if _crackle else 0.0
	_rpm = _idle_rpm
	_rpm_goal = _rpm
	_e_r = _rpm
	_c_rpm = _rpm
	_c_usec = Time.get_ticks_usec()


# --- control (game thread) ------------------------------------------------------------------------

## One frame of the engine: rpm, engine load 0..1 (throttle, cut while shifting), pedal 0..1 (induction), boost
## 0..1, limiter active, frame time (the rpm ramps to the new value within dt of audio).
func drive(rpm: float, load: float, throttle: float, boost: float, limiter_on: bool, dt: float) -> void:
	_mutex.lock()
	_c_rpm = rpm
	_c_load = clampf(load, 0.0, 1.0)
	_c_thr = clampf(throttle, 0.0, 1.0)
	_c_boost = clampf(boost, 0.0, 1.0)
	_c_limiter = limiter_on
	_c_dt = maxf(dt, 0.001)
	_c_seq += 1
	_c_usec = Time.get_ticks_usec()
	_mutex.unlock()


## Tests/tools: sets the operating point at once (no ramp, smoothed values jump too). throttle < 0 = as the load.
func set_manual(rpm: float, load: float, throttle: float = -1.0, boost: float = 1.0, limiter_on: bool = false) -> void:
	_mutex.lock()
	_c_rpm = rpm
	_c_load = clampf(load, 0.0, 1.0)
	_c_thr = clampf(throttle if throttle >= 0.0 else load, 0.0, 1.0)
	_c_boost = clampf(boost, 0.0, 1.0)
	_c_limiter = limiter_on
	_c_dt = 0.0
	_c_seq += 1
	_c_usec = Time.get_ticks_usec()
	_mutex.unlock()


## Engine start: with_clip plays the bank's start clip (if any) and fades the cycle sound in near its end;
## otherwise the cycle sound fades in at once.
func start(with_clip: bool = true) -> void:
	_event(["start", with_clip], 1.0)


## Output fade (pause, scene change, preview end): gain 0..1 within `seconds`.
func fade_to(gain: float, seconds: float) -> void:
	var g := clampf(gain, 0.0, 1.0)
	_mutex.lock()
	var same := g == _c_gain_goal
	_mutex.unlock()
	if not same:
		_event(["fade", g, seconds], g)


## Starts a clip of the bank ("crackle", "shift", "start"): variant −1 = a random one (not the last one of this
## clip), gain on top of the clip group's gain, pan −1..1 for mono clips.
func play_clip(clip_name: String, index: int = -1, gain: float = 1.0, pan: float = 0.0) -> void:
	_event(["clip", clip_name, index, gain, pan], -1.0)


## The driver lifted off at speed: crackles for the bank's duration, amount 0..1 (0 ends them).
func lift(amount: float) -> void:
	_event(["lift", clampf(amount, 0.0, 1.0)], -1.0)


func _event(e: Array, gain_goal: float) -> void:
	_mutex.lock()
	if _c_events.size() >= MAX_EVENTS:
		_c_events.pop_front()      # nobody renders (headless): the queue must not grow
	_c_events.append(e)
	if gain_goal >= 0.0:
		_c_gain_goal = gain_goal
	_c_usec = Time.get_ticks_usec()
	_mutex.unlock()


## Faded out completely and asked to stay so: nothing left to render.
func is_silent() -> bool:
	_mutex.lock()
	var s := _c_gain_goal <= 0.0 and _s_gain <= 0.0 and _c_events.is_empty()
	_mutex.unlock()
	return s


## Back to idle, silent at once (stop_all, new race): start() or fade_to(1, …) brings the sound back. Stops the
## worker thread.
func reset() -> void:
	stop_thread()
	_mutex.lock()
	_c_events.clear()
	_c_gain_goal = 0.0
	_c_rpm = _idle_rpm
	_c_load = 0.0
	_c_thr = 0.0
	_c_boost = 0.0
	_c_limiter = false
	_c_dt = 0.0
	_c_seq += 1
	_s_gain = 0.0
	_mutex.unlock()
	_gain = 0.0
	_gain_goal = 0.0
	_loop = 0.0
	_loop_goal = 1.0
	_e_loop = 0.0
	_start_wait = 0
	_rpm = _idle_rpm
	_rpm_goal = _rpm
	_rpm_step = 0.0
	_e_r = _rpm
	_load_goal = 0.0
	_load_s = 0.0
	_thr_goal = 0.0
	_thr_s = 0.0
	_boost_goal = 0.0
	_boost_s = 0.0
	_e_l = 0.0
	_e_in = 0.0
	_e_drive = 1.0
	_limiter = false
	_gate = 1.0
	_gate_s = 1.0
	_lim_n = 0
	_droop = 0.0
	_wd = 1.0
	_wd_goal = 1.0
	_crackle_left = 0.0
	_clear_clips()


func _clear_clips() -> void:
	_clip_base.clear()
	_clip_pos.clear()
	_clip_len.clear()
	_clip_wait.clear()
	_clip_mono.clear()
	_clip_gl.clear()
	_clip_gr.clear()


# --- render side: control ---------------------------------------------------------------------------

func _take_control() -> void:
	_mutex.lock()
	var seq := _c_seq
	var rpm := _c_rpm
	var load := _c_load
	var thr := _c_thr
	var boost := _c_boost
	var lim := _c_limiter
	var dt := _c_dt
	var events := _c_events
	if not events.is_empty():
		_c_events = []
	_mutex.unlock()
	if seq != _seq_seen:
		_seq_seen = seq
		_rpm_goal = rpm
		_load_goal = load
		_thr_goal = thr
		_boost_goal = boost
		_limiter = lim
		if dt <= 0.0:
			_rpm = rpm
			_rpm_step = 0.0
			_e_r = rpm * (1.0 - _droop) * (1.0 + motion_rpm * _m_rpm)
			_load_s = maxf(load, _idle_share())
			_thr_s = thr
			_boost_s = boost
			_e_l = clampf(_load_s * _gate_s, 0.0, 1.0)
			_e_in = _in_level()
			_e_on = 1.0 - _turbo_depth * (1.0 - _boost_s)
			_e_drive = _drive_of(_e_l)
		else:
			_rpm_step = absf(rpm - _rpm) / maxf(dt * _sr, 1.0)
	for e: Array in events:
		match str(e[0]):
			"start":
				_gain = 1.0
				_gain_goal = 1.0
				_loop = 0.0
				_e_loop = 0.0
				_wd = 1.0
				var clip_s := bank.clip_seconds("start") if bool(e[1]) else 0.0
				if clip_s > 0.0:
					_start_clip("start", 0, 1.0, 0.0, 0)
					_start_wait = int(maxf(clip_s - START_OVERLAP_S, 0.01) * _sr)
					_loop_goal = 0.0
				else:
					_start_wait = 0
					_loop_goal = 1.0
			"fade":
				_gain_goal = float(e[1])
				_gain_step = 1.0 / maxf(float(e[2]) * _sr, 1.0)
			"clip":
				_start_clip(str(e[1]), int(e[2]), float(e[3]), float(e[4]), 0)
			"lift":
				if _crackle and float(e[1]) > 0.0:
					_crackle_left = _crackle_dur
					_crackle_amt = float(e[1])
				else:
					_crackle_left = 0.0


func _idle_share() -> float:
	return bank.idle_load * clampf(1.0 - (_rpm - _idle_rpm) / (0.5 * _idle_rpm), 0.0, 1.0)


func _in_level() -> float:
	return bank.in_gain * pow(_thr_s, 1.3) * (_in_base + (1.0 - _in_base) * _boost_s)


func _drive_of(l: float) -> float:
	return 1.0 + _sat_amount * l * clampf(_rpm / _redline, 0.0, 1.0)


## Starts a clip variant (−1 = random, not the last one of this clip) after `wait` frames.
func _start_clip(clip_name: String, index: int, gain: float, pan: float, wait: int) -> void:
	var c: PackedInt32Array = bank.clips.get(clip_name, PackedInt32Array())
	var n := c.size() / 3
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
	if _clip_base.size() >= MAX_CLIPS:
		return
	clips_started[clip_name] = int(clips_started.get(clip_name, 0)) + 1
	var g := gain * float(bank.clip_gain.get(clip_name, 1.0))
	var mono := c[i * 3 + 2] != 0
	var gl := g
	var gr := g
	if mono:
		var a := (clampf(pan, -1.0, 1.0) + 1.0) * PI * 0.25
		gl = g * sqrt(2.0) * cos(a)
		gr = g * sqrt(2.0) * sin(a)
	_clip_base.append(c[i * 3])
	_clip_pos.append(0)
	_clip_len.append(c[i * 3 + 1])
	_clip_wait.append(wait)
	_clip_mono.append(1 if mono else 0)
	_clip_gl.append(gl)
	_clip_gr.append(gr)


# --- mixing core ----------------------------------------------------------------------------------

## Writes `count` stereo frames (bank sample rate, within ±1) into out[offset … offset + count − 1].
## Applies the pending control first. No AudioServer.
func render(out: PackedVector2Array, offset: int, count: int) -> void:
	if count <= 0:
		return
	_take_control()
	var done := 0
	while done < count:
		var n := mini(SUB, count - done)
		_render_block(out, offset + done, n)
		done += n
	_mutex.lock()
	_s_gain = _gain
	_mutex.unlock()


## The six voice gains (lo off/on/in, hi off/on/in) for a place between two rpm points (wh 0..1), a load, the
## induction level, the level of the load layer and the loop fade.
func _gains(out: PackedFloat64Array, lo: int, hi: int, wh: float, l: float, inn: float, on_amp: float, fade: float) -> void:
	var bk := bank
	var a := 1.0 - wh
	var b := wh
	var lc := pow(l, bk.load_curve) if l > 0.0 else 0.0
	var s := sin(lc * PI * 0.5) * on_amp
	var c := cos(lc * PI * 0.5) * bk.off_gain
	# the load blend keeps the power: s² · P_on + c² · P_off, whatever the coherence of the two layers
	var p_on := a * bk.power[lo * 3 + 1] + b * bk.power[hi * 3 + 1]
	var p_off := a * bk.power[lo * 3] + b * bk.power[hi * 3]
	var want := s * s * p_on + c * c * p_off
	var have := want + 2.0 * (a * bk.xload[lo] + b * bk.xload[hi]) * s * c * sqrt(p_on * p_off)
	var kl := fade
	if have > 1.0e-12 and want > 0.0:
		kl = fade * clampf(sqrt(want / have), 0.6, 1.8)
	for layer in 3:
		var kr := 1.0
		if hi != lo:
			kr = 1.0 / sqrt(a * a + b * b + 2.0 * maxf(bk.xrpm[hi * 3 + layer], MIN_RHO) * a * b)
		var g := c * kl
		if layer == 1:
			g = s * kl
		elif layer == 2:
			g = inn * fade
		out[layer] = a * kr * g * bk.gains[lo * 3 + layer]
		out[3 + layer] = b * kr * g * bk.gains[hi * 3 + layer]


func _render_block(out: PackedVector2Array, o: int, n: int) -> void:
	var sr := _sr
	var nf := float(n)
	var bk := bank
	var dt := nf / sr
	# --- slow movement: three drift processes (unit variance) and the gain of the running cycle
	_m_rpm += -_m_rpm * (dt / 0.25) + rng.randfn() * sqrt(2.0 * dt / 0.25)
	_m_amp += -_m_amp * (dt / 0.12) + rng.randfn() * sqrt(2.0 * dt / 0.12)
	_m_load += -_m_load * (dt / 0.2) + rng.randfn() * sqrt(2.0 * dt / 0.2)
	_cyc_g += (_cyc_goal - _cyc_g) * 0.5
	# --- control values at the end of the block (the start values are those of the last block's end)
	var r_start := _e_r
	_rpm = move_toward(_rpm, _rpm_goal, _rpm_step * nf)
	_droop += ((0.03 if _gate < 0.5 else 0.0) - _droop) * (1.0 - exp(-dt / 0.025))
	var r_end := _rpm * (1.0 - _droop) * (1.0 + motion_rpm * _m_rpm)
	_e_r = r_end
	var load_goal := maxf(_load_goal, _idle_share())
	if _load_goal > 0.6:
		_crackle_left = 0.0
	_load_s += (load_goal - _load_s) * (1.0 - exp(-dt / (LOAD_UP_S if load_goal > _load_s else LOAD_DOWN_S)))
	_gate_s += (_gate - _gate_s) * (1.0 - exp(-dt / GATE_TAU))
	_thr_s += (_thr_goal - _thr_s) * (1.0 - exp(-dt / (THR_UP_S if _thr_goal > _thr_s else THR_DOWN_S)))
	_boost_s += (_boost_goal - _boost_s) * (1.0 - exp(-dt / BOOST_TAU))
	var l0 := _e_l
	var l1 := clampf(_load_s * _gate_s * (1.0 + motion_load * _m_load), 0.0, 1.0)
	_e_l = l1
	var in0 := _e_in
	var in1 := _in_level()
	_e_in = in1
	var amp0 := _e_amp
	var amp1 := exp(0.115129 * (motion_level_db * _m_amp)) * _cyc_g
	_e_amp = amp1
	var on0 := _e_on
	var on1 := 1.0 - _turbo_depth * (1.0 - _boost_s)
	_e_on = on1
	if _start_wait > 0:
		_start_wait -= n
		if _start_wait <= 0:
			_loop_goal = 1.0
	var lp0 := _e_loop
	_loop = move_toward(_loop, _loop_goal, nf / (sr * LOOP_FADE_S))
	_e_loop = _loop
	# --- rpm pair: lo/hi from the block start, weights linear in log rpm
	var rp := bk.rpms
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
		var la := bk.log_rpms[lo]
		var span := bk.log_rpms[hi] - la
		wh0 = clampf((log(r_start) - la) / span, 0.0, 1.0)
		wh1 = clampf((log(maxf(r_end, 1.0)) - la) / span, 0.0, 1.0)
	var g0 := _g0
	var g1 := _g1
	_gains(g0, lo, hi, wh0, l0, in0, amp0 * on0, lp0)
	_gains(g1, lo, hi, wh1, l1, in1, amp1 * on1, _loop)
	# --- cycle phase per frame; cycle starts (wraps) split the block into segments
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
	var l := _l
	var r := _r
	for k in n:
		l[k] = 0.0
		r[k] = 0.0
	var nv := 6 if hi != lo else 3
	var s := 0
	for wi in nw + 1:
		var e := wb[wi] if wi < nw else n
		if e > s:
			for v in nv:
				var ga := g0[v]
				var gb := g1[v]
				if ga > 1.0e-6 or gb > 1.0e-6:
					var dg := (gb - ga) / nf
					var b := (lo if v < 3 else hi) * 3 + (v % 3)
					if v % 3 == 2:
						_voice_mono(s, e, b, ga + dg * s, dg)
					else:
						_voice_st(s, e, b, ga + dg * s, dg)
		if wi < nw:
			_next_cycle(e)
		s = e
	# --- clips into their own buffers (they are added after the saturation)
	_render_crackles(dt, n)
	var with_clips := not _clip_base.is_empty()
	if with_clips:
		_render_clips(n)
	# --- output stage: saturation, clips, level, fade, soft limit
	var d0 := _e_drive
	var d1 := _drive_of(l1)
	_e_drive = d1
	var dr := d0
	var ddr := (d1 - d0) / nf
	var tb0 := tanh(_sat_bias * (d0 - 1.0))
	var tb := tb0
	var dtb := (tanh(_sat_bias * (d1 - 1.0)) - tb0) / nf
	var nm0 := pow(d0, -_sat_comp)
	var nm := nm0
	var dnm := (pow(d1, -_sat_comp) - nm0) / nf
	var sb := _sat_bias
	var base := bk.mix_gain * level
	var og0 := _gain * _wd * base
	_gain = move_toward(_gain, _gain_goal, _gain_step * nf)
	_wd = move_toward(_wd, _wd_goal, nf / (sr * WATCHDOG_FADE_S))
	var og := og0
	var dog := (_gain * _wd * base - og0) / nf
	var knee := 1.0 - SOFT
	if with_clips:
		var cl := _cl
		var cr := _cr
		for k in n:
			var x := (tanh(l[k] * dr + sb * (dr - 1.0)) - tb) * nm + cl[k]
			var y := (tanh(r[k] * dr + sb * (dr - 1.0)) - tb) * nm + cr[k]
			x *= og
			y *= og
			if not (x >= -SOFT and x <= SOFT):
				x = _limit(x, knee)
			if not (y >= -SOFT and y <= SOFT):
				y = _limit(y, knee)
			out[o + k] = Vector2(x, y)
			dr += ddr
			tb += dtb
			nm += dnm
			og += dog
	else:
		for k in n:
			var x := (tanh(l[k] * dr + sb * (dr - 1.0)) - tb) * nm * og
			var y := (tanh(r[k] * dr + sb * (dr - 1.0)) - tb) * nm * og
			if not (x >= -SOFT and x <= SOFT):
				x = _limit(x, knee)
			if not (y >= -SOFT and y <= SOFT):
				y = _limit(y, knee)
			out[o + k] = Vector2(x, y)
			dr += ddr
			tb += dtb
			nm += dnm
			og += dog
	_clock += n


## NaN/inf guard and soft limit (linear up to SOFT, tanh towards ±1).
func _limit(x: float, knee: float) -> float:
	if not (x > -1.0e6 and x < 1.0e6):
		return 0.0
	if x > 0.0:
		return SOFT + knee * tanh((x - SOFT) / knee)
	return -SOFT - knee * tanh((-x - SOFT) / knee)


## Adds the stereo bank b over block frames [s, e) to the scratch buffers; gain g at s, +dg per frame.
func _voice_st(s: int, e: int, b: int, g: float, dg: float) -> void:
	var d := bank.data
	var phb := _phbuf
	var l := _l
	var r := _r
	var p := bank.periods[b]
	var base := bank.cyc_base[_cur[b]]
	var k := s
	var prev := _prev[b]
	if prev >= 0:
		# crossfade zone: the previous cycle continues past its end for (overlap − 4) frames; the margin keeps
		# its interpolated reads inside its [offset, length] even with rounding of period
		var ov := float(bank.overlaps[b] - 4)
		var fz := ov / p
		if phb[s] < fz:
			var basep := bank.cyc_base[prev]
			var iov := 1.0 / ov
			while k < e:
				var phk := phb[k]
				if phk >= fz:
					break
				var pos := phk * p
				var i0 := int(pos)
				var fr := pos - i0
				var q := base + i0 * 2
				var pp := pos + p
				var i1 := int(pp)
				var frp := pp - i1
				var qp := basep + i1 * 2
				var u := pos * iov
				var w := u * u * (3.0 - 2.0 * u)
				var x0 := d[q]
				var xn := x0 + (d[q + 2] - x0) * fr
				var y0 := d[qp]
				var xo := y0 + (d[qp + 2] - y0) * frp
				l[k] += (xo + (xn - xo) * w) * g
				x0 = d[q + 1]
				xn = x0 + (d[q + 3] - x0) * fr
				y0 = d[qp + 1]
				xo = y0 + (d[qp + 3] - y0) * frp
				r[k] += (xo + (xn - xo) * w) * g
				g += dg
				k += 1
	for j in range(k, e):
		var pos := phb[j] * p
		var i0 := int(pos)
		var fr := pos - i0
		var q := base + i0 * 2
		var x0 := d[q]
		var y0 := d[q + 1]
		l[j] += (x0 + (d[q + 2] - x0) * fr) * g
		r[j] += (y0 + (d[q + 3] - y0) * fr) * g
		g += dg


## The same for a mono bank (its samples sit on every second value from cyc_base on): added to both channels.
func _voice_mono(s: int, e: int, b: int, g: float, dg: float) -> void:
	var d := bank.data
	var phb := _phbuf
	var l := _l
	var r := _r
	var p := bank.periods[b]
	var base := bank.cyc_base[_cur[b]]
	var k := s
	var prev := _prev[b]
	if prev >= 0:
		var ov := float(bank.overlaps[b] - 4)
		var fz := ov / p
		if phb[s] < fz:
			var basep := bank.cyc_base[prev]
			var iov := 1.0 / ov
			while k < e:
				var phk := phb[k]
				if phk >= fz:
					break
				var pos := phk * p
				var i0 := int(pos)
				var q := base + i0 * 2
				var x0 := d[q]
				var xn := x0 + (d[q + 2] - x0) * (pos - i0)
				var pp := pos + p
				var i1 := int(pp)
				var qp := basep + i1 * 2
				var y0 := d[qp]
				var xo := y0 + (d[qp + 2] - y0) * (pp - i1)
				var u := pos * iov
				var x := (xo + (xn - xo) * (u * u * (3.0 - 2.0 * u))) * g
				l[k] += x
				r[k] += x
				g += dg
				k += 1
	for j in range(k, e):
		var pos := phb[j] * p
		var i0 := int(pos)
		var q := base + i0 * 2
		var x0 := d[q]
		var x := (x0 + (d[q + 2] - x0) * (pos - i0)) * g
		l[j] += x
		r[j] += x
		g += dg


## Cycle boundary at block frame `rel`: every bank moves on to a new random variant (never the current one), the
## cycle gets its own gain, the limiter pattern advances by one cycle.
func _next_cycle(rel: int) -> void:
	var nb := _cur.size()
	var vf := bank.var_first
	var vc := bank.var_count
	for b in nb:
		var c := _cur[b]
		_prev[b] = c
		var first := vf[b]
		var x := rng.randi_range(0, vc[b] - 2)
		if first + x >= c:
			x += 1
		_cur[b] = first + x
	_cyc_goal = exp(0.115129 * motion_cycle_db * rng.randfn()) if motion_cycle_db > 0.0 else 1.0
	if _limiter and _lim_pattern:
		var cut := (_lim_n % (_lim_cut + _lim_on)) < _lim_cut
		if cut and _gate > 0.5 and _lim_pop > 0.0 and rng.randf() < _lim_pop:
			_start_clip("crackle", -1, _crackle_level * rng.randf_range(0.25, 0.5), rng.randf_range(-1.0, 1.0) * _crackle_pan, rel)
		_gate = 0.0 if cut else 1.0
		_lim_n += 1
	else:
		_lim_n = 0
		_gate = 1.0
	if debug_wraps:
		wraps.append(_clock + rel)
		gates_log.append(int(_gate))
		if debug_bank >= 0 and debug_bank < nb:
			variants_log.append(_cur[debug_bank])


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
		_start_clip("crackle", -1, g, rng.randf_range(-1.0, 1.0) * _crackle_pan, rng.randi_range(0, n - 1))


## Mixes the running clips of this block into _cl / _cr.
func _render_clips(n: int) -> void:
	var d := bank.data
	var cl := _cl
	var cr := _cr
	for k in n:
		cl[k] = 0.0
		cr[k] = 0.0
	var i := 0
	while i < _clip_base.size():
		var wait := _clip_wait[i]
		if wait >= n:
			_clip_wait[i] = wait - n
			i += 1
			continue
		var pos := _clip_pos[i]
		var m := mini(n - wait, _clip_len[i] - pos)
		var gl := _clip_gl[i]
		var gr := _clip_gr[i]
		var q := _clip_base[i] + pos * 2
		if _clip_mono[i] != 0:
			for k in m:
				var x := d[q + k * 2]
				cl[wait + k] += x * gl
				cr[wait + k] += x * gr
		else:
			for k in m:
				cl[wait + k] += d[q + k * 2] * gl
				cr[wait + k] += d[q + k * 2 + 1] * gr
		pos += m
		_clip_wait[i] = 0
		if pos >= _clip_len[i]:
			_clip_base.remove_at(i)
			_clip_pos.remove_at(i)
			_clip_len.remove_at(i)
			_clip_wait.remove_at(i)
			_clip_mono.remove_at(i)
			_clip_gl.remove_at(i)
			_clip_gr.remove_at(i)
		else:
			_clip_pos[i] = pos
			i += 1


# --- live playback --------------------------------------------------------------------------------

## Takes a player (created by the owner on its bus) and gives it the generator stream (mix rate = bank rate).
func attach(p_player: AudioStreamPlayer, buffer_s: float = 0.25) -> void:
	if player != null or p_player == null:
		return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate_mode = AudioStreamGenerator.MIX_RATE_CUSTOM
	gen.mix_rate = _sr
	gen.buffer_length = buffer_s
	p_player.stream = gen
	player = p_player


## Once per frame on the game thread. Synchronous mode (threaded false): renders what is needed to keep latency_s
## queued – at least 1.6 frame times and 1.25 × the largest block the audio driver took between two fills, at most
## 90 % of the buffer – and returns the number of frames rendered. Threaded mode: starts the player and the worker
## (which keeps latency_s queued by itself) and returns 0. Faded out: the queue plays out, then the player stops.
func pump(latency_s: float, frame_dt: float = 0.0, threaded: bool = false) -> int:
	if player == null or not is_instance_valid(player):
		return 0
	if frame_dt > 0.0:
		_frame_dt += (minf(frame_dt, 0.25) - _frame_dt) * 0.1
	if is_silent():
		_silent_s += maxf(frame_dt, 0.001)
		if player.playing and (_playback == null or _silent_s > 0.3 or _playback.get_frames_available() >= _capacity):
			stop_thread()
			player.stop()
			_playback = null
		return 0
	_silent_s = 0.0
	if not player.playing or _playback == null:
		stop_thread()
		player.play()
		_playback = player.get_stream_playback() as AudioStreamGeneratorPlayback
		if _playback == null:
			return 0
		_capacity = _playback.get_frames_available()
		_queued = 0
		_burst = 0.0
		_pump_usec = Time.get_ticks_usec()
	if threaded:
		_mutex.lock()
		_t_latency = latency_s
		_mutex.unlock()
		if _thread == null:
			_t_run = true
			_thread = Thread.new()
			_thread.start(_thread_main)
		return 0
	stop_thread()
	return _fill(maxf(latency_s, 1.6 * _frame_dt), false)


## Keeps `latency_s` queued. Worker: whole chunks only. Returns the frames rendered.
func _fill(latency_s: float, chunks_only: bool) -> int:
	var pb := _playback
	if pb == null:
		return 0
	var free := pb.get_frames_available()
	var queued := _capacity - free
	var now := Time.get_ticks_usec()
	_burst = maxf(float(_queued - queued), _burst * exp(-float(now - _pump_usec) / 3.3e6))
	_pump_usec = now
	var target := mini(maxi(int(latency_s * _sr), int(_burst * 1.25)), int(_capacity * 0.9))
	var need := mini(target - queued, free)
	_queued = queued
	if need <= 0 or (chunks_only and need < CHUNK):
		return 0
	var t0 := Time.get_ticks_usec()
	var done := 0
	while need - done >= CHUNK:
		render(_frames, 0, CHUNK)
		pb.push_buffer(_frames)
		done += CHUNK
	if not chunks_only and need > done:
		var m := need - done
		if _tail.size() != m:
			_tail.resize(m)
		render(_tail, 0, m)
		pb.push_buffer(_tail)
		done += m
	_queued = queued + done
	var us := Time.get_ticks_usec() - t0
	_mutex.lock()
	_s_calls += 1
	_s_us_sum += us
	_s_us_max = maxi(_s_us_max, us)
	_s_samples += done
	_s_queued = _queued
	_mutex.unlock()
	return done


func _thread_main() -> void:
	while true:
		_mutex.lock()
		var run := _t_run
		var latency := _t_latency
		var idle_us := Time.get_ticks_usec() - _c_usec
		var asleep := _c_gain_goal <= 0.0 and _s_gain <= 0.0 and _c_events.is_empty()
		_mutex.unlock()
		if not run:
			break
		if asleep:
			OS.delay_usec(5000)
			continue
		_wd_goal = 0.0 if idle_us > int(WATCHDOG_S * 1.0e6) else 1.0
		var n := _fill(latency, true)
		OS.delay_usec(1000 if n > 0 else 2500)


## Stops the worker thread (waits for it). Harmless without one.
func stop_thread() -> void:
	if _thread == null:
		return
	_mutex.lock()
	_t_run = false
	_mutex.unlock()
	_thread.wait_to_finish()
	_thread = null
	_wd = 1.0
	_wd_goal = 1.0


func threaded() -> bool:
	return _thread != null


## Gives the player back to the owner (which keeps its stream alive and frees it): stops the worker, forgets the
## playback.
func detach() -> AudioStreamPlayer:
	stop_thread()
	var p := player
	player = null
	_playback = null
	_capacity = 0
	return p


## Underruns of the current generator playback (the queue ran empty; 0 without playback).
func skips() -> int:
	return _playback.get_skips() if _playback != null else 0


## Render time of the live playback: {avg_ms, max_ms per filling call, frames = filling calls, samples rendered,
## skips = underruns, ms_per_frame = render time per 1/60 s of sound}.
func perf() -> Dictionary:
	_mutex.lock()
	var calls := _s_calls
	var us := _s_us_sum
	var mx := _s_us_max
	var samples := _s_samples
	_mutex.unlock()
	if calls == 0:
		return {"avg_ms": 0.0, "max_ms": 0.0, "frames": 0, "samples": 0, "skips": 0, "ms_per_frame": 0.0}
	return {"avg_ms": us / 1000.0 / calls, "max_ms": mx / 1000.0, "frames": calls, "samples": samples, "skips": skips(),
		"ms_per_frame": us / 1000.0 / maxf(float(samples), 1.0) * _sr / 60.0}
