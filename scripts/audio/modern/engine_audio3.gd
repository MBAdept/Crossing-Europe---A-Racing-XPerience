class_name EngineAudio3
extends ModernAudioModule
## Slot "engine" of the Modern sound: the engine of the player's car on the bus MEngine (→ MCar → MEnv).
## ModernAudio expects from this class, beyond the hooks of ModernAudioModule:
##   state() -> {rpm, gear (0 = neutral), load 0..1, boost 0..1, …}   AudioManager.engine_state(), frame.engine
##   perf()  -> {avg_ms, max_ms, frames, samples, skips, …}           AudioManager.engine_perf()
##   preview(id)                                                      vehicle selection: short rev blip of that car
## The car comes through set_vehicle(id), the driving values every frame in update(frame): frame.alive, speed,
## throttle, vmax, active. ctx.sync = no worker thread (--audio-sync, audio.modern.engine_thread = false).
##
## Engine v3 (package AU-B, contract D27; docs/motorsound.md "Modern"): the car's stereo cycle bank
## assets/audio/modern/engines/<car>.json + .i16 (EngineBank2, found through the manifest of the folder) played by
## an EngineMixThread – exhaust under load, overrun and induction as separate cycle-synchronous voices, slow random
## movement, load-dependent saturation, crackles, shift cracks, start clip, limiter. The gearbox is the Arcade
## model (EngineGearbox, unchanged): the same gears, shifts and rpm in both profiles.
## Per sounding engine one Unit: bank, gearbox, mixer, and the frame-rate logic around them – boost and shaft speed
## of the turbo, what happens when the driver lifts (crackles, blow-off) or the box shifts up (shift crack), the
## engine catching after the start clip. A car without a v3 bank is silent here; its gearbox still runs (state()).
##
## state() carries more than the four contract keys – for the vehicle layers (slot "layers", same frame):
##   shaft 0..1 (turbo shaft speed), limiter, shifting, throttle, and counters that only grow: upshifts,
##   downshifts, blowoffs (lifts with boost; blowoff_level = boost at the last one), starts.
##
## Banks are loaded when first needed and kept (at most BANK_CACHE): the race car's in set_vehicle() (stage setup),
## a previewed car's in a worker task, so the vehicle selection does not hitch (decoding int16 takes about 45 ms).
## Configuration: audio.modern.engine (docs/motorsound.md "Modern": Konfiguration).

const BUS := "MEngine"
const FADE_S := 0.12             ## fade on pause / scene change / resume
const START_WINDOW_S := 1.0      ## synchronous mode: after the engine start the generator queue is start_latency_s long
const NEUTRAL_BOOST := 0.45      ## revving without load (standstill) builds only this share of the boost
const MOVING_KMH := 20.0         ## a car that already drives when its engine sound starts gets no start clip
const BANK_CACHE := 3
const SYNC_SEED := 20261111      ## seed of the mixers in synchronous mode (sample-identical runs)


## One sounding engine.
class Unit:
	var id := ""
	var bank: EngineBank2
	var gearbox: EngineGearbox
	var mix: EngineMixThread
	var rng := RandomNumberGenerator.new()
	var boost := 0.0
	var shaft := 0.0
	var throttle := 0.0
	var upshifts := 0
	var downshifts := 0
	var blowoffs := 0
	var blowoff_level := 0.0
	var starts := 0
	var _load_peak := 0.0
	var _lift_armed := false
	var _catch_s := 0.0          # time until the engine catches under the start clip
	var _turbo := false
	var _spool_s := 0.55
	var _boost_rpm := 2200.0
	var _crackle := false
	var _crackle_min := 3200.0
	var _blowoff := false
	var _blowoff_min := 0.55
	var _blowoff_level := 0.5
	var _shift_pan := 0.0
	var _redline := 6500.0

	func _init(p_id: String, p_bank: EngineBank2, p_seed: int) -> void:
		id = p_id
		bank = p_bank
		gearbox = EngineGearbox.new().setup(bank.gearbox, bank.engine, bank.clip_count("shift") > 0 or bank.has_layer("crackle"))
		mix = EngineMixThread.new(bank, p_seed)
		if p_seed >= 0:
			rng.seed = p_seed + 1
		else:
			rng.randomize()
		_redline = gearbox.redline_rpm
		var t := bank.layer("turbo")
		_turbo = not t.is_empty()
		if _turbo:
			_spool_s = maxf(float(t.get("spool_s", 0.55)), 0.02)
			_boost_rpm = float(t.get("boost_rpm", 2200.0))
		var c := bank.layer("crackle")
		_crackle = not c.is_empty() and bank.clip_count("crackle") > 0
		_crackle_min = float(c.get("min_rpm", 3200.0))
		var bo := bank.layer("blowoff")
		_blowoff = not bo.is_empty() and _turbo
		_blowoff_min = float(bo.get("min_boost", 0.55))
		_blowoff_level = float(bo.get("level", 0.5))
		_shift_pan = float(bank.layer("shift").get("pan", 0.0))

	## Engine start. with_clip: starter and first fires (the bank's start clip), the cycle sound fades in near its end.
	func start(with_clip: bool) -> void:
		starts += 1
		var clip_s := bank.clip_seconds("start") if with_clip else 0.0
		_catch_s = maxf(clip_s - EngineMixThread.START_OVERLAP_S, 0.01) if clip_s > 0.0 else 0.0
		mix.start(clip_s > 0.0)

	## One frame of the car: speed (km/h), pedal 0..1, current vmax, active = the engine drives the car.
	func update(dt: float, speed_kmh: float, pedal: float, vmax_kmh: float, active: bool) -> void:
		if dt <= 0.0:
			return
		throttle = clampf(pedal, 0.0, 1.0)
		gearbox.update(dt, speed_kmh, throttle, vmax_kmh, active)
		if _catch_s > 0.0:
			_catch_s -= dt
			if _catch_s <= 0.0:
				# the engine catches: a short flare above idle, the cycle sound fades in
				gearbox.rpm = maxf(gearbox.rpm, gearbox.idle_rpm * 1.3)
		var rpm := gearbox.rpm
		var load := gearbox.load
		if _turbo:
			var spool := smoothstep(_boost_rpm * 0.7, _boost_rpm * 1.4, rpm)
			var target := load * spool * (NEUTRAL_BOOST if gearbox.gear == 0 else 1.0)
			boost += (target - boost) * (1.0 - exp(-dt / (_spool_s if target > boost else 0.16)))
			var shaft_t := 0.75 * boost + 0.25 * clampf(rpm / _redline, 0.0, 1.0) * (0.3 + 0.7 * load)
			shaft += (shaft_t - shaft) * (1.0 - exp(-dt / (0.35 * _spool_s if shaft_t > shaft else 0.9)))
		# lifting off (also the end of a downshift blip, not the cut of an upshift): crackles and blow-off
		var upshift_cut := gearbox.shifting and gearbox.shift_dir > 0
		_load_peak = maxf(load, _load_peak - dt / 0.35)
		if load > 0.5:
			_lift_armed = true
		if _lift_armed and load < 0.2 and _load_peak > 0.6 and not upshift_cut:
			_lift_armed = false
			if _crackle and rpm >= _crackle_min:
				mix.lift(clampf(0.45 + 0.55 * (rpm - _crackle_min) / maxf(_redline - _crackle_min, 1.0), 0.45, 1.0))
			if _blowoff and boost >= _blowoff_min:
				blowoffs += 1
				blowoff_level = _blowoff_level * clampf(boost, 0.0, 1.0)
				boost *= 0.3
		if gearbox.ev_upshift:
			upshifts += 1
			# loaded upshift: shift crack (ignition cut of a dual-clutch box). No blow-off – the throttle stays open
			if _load_peak > 0.6 and bank.clip_count("shift") > 0 and rpm > 0.4 * _redline:
				mix.play_clip("shift", -1, 0.55 + 0.35 * clampf(rpm / _redline, 0.0, 1.0), rng.randf_range(-1.0, 1.0) * _shift_pan)
		if gearbox.ev_downshift:
			downshifts += 1
		mix.drive(rpm, load, throttle, boost if _turbo else 1.0, gearbox.limiter, dt)

	func reset() -> void:
		mix.reset()
		gearbox.reset()
		boost = 0.0
		shaft = 0.0
		throttle = 0.0
		_load_peak = 0.0
		_lift_armed = false
		_catch_s = 0.0

	func state() -> Dictionary:
		return {"rpm": gearbox.rpm, "gear": gearbox.gear, "load": gearbox.load, "boost": boost, "shaft": shaft,
			"limiter": gearbox.limiter, "shifting": gearbox.shifting, "throttle": throttle, "upshifts": upshifts,
			"downshifts": downshifts, "blowoffs": blowoffs, "blowoff_level": blowoff_level, "starts": starts}


var vehicle_id := ""
## Tests: banks by vehicle id that are used instead of the files (EngineBank2).
var bank_override: Dictionary = {}

var _unit: Unit = null
var _start_pending := false
var _started_at := -100.0
var _fallback: EngineGearbox = null
var _preview: Unit = null
var _preview_t := 0.0
var _preview_wanted := ""
var _time := 0.0
var _gears := 6
var _level_db := 0.0
var _preview_db := -2.0
var _latency := 0.05
var _sync_latency := 0.07
var _start_latency := 0.2
var _buffer := 0.3
var _preview_on := true
var _motion: Dictionary = {}
var _banks: Dictionary = {}          ## id -> EngineBank2 (null = no usable bank)
var _bank_order: Array[String] = []  ## least recently used first
var _tasks: Dictionary = {}          ## id -> WorkerThreadPool task of a running load
var _loaded: Dictionary = {}         ## id -> EngineBank2 written by a finished task (under _load_mutex)
var _load_mutex := Mutex.new()
var _seed_n := 0


func _setup() -> void:
	_gears = int(ConfigLoader.lookup(ctx.cfg, "audio.engine_gears", 6))
	_level_db = ctx.number("engine.level_db", 0.0)
	_preview_db = ctx.number("engine.preview_db", -2.0)
	_latency = clampf(ctx.number("engine.latency_s", 0.05), 0.02, 0.2)
	_sync_latency = clampf(ctx.number("engine.sync_latency_s", 0.07), 0.02, 0.2)
	_buffer = clampf(ctx.number("engine.buffer_s", 0.3), maxf(_latency, _sync_latency) * 2.0, 1.0)
	_start_latency = clampf(ctx.number("engine.start_latency_s", 0.2), _sync_latency, _buffer * 0.85)
	_preview_on = bool(ctx.value("engine.preview", true))
	var m: Variant = ctx.value("engine.motion", {})
	_motion = m if m is Dictionary else {}
	_fallback = EngineGearbox.generic(250.0, _gears)


# --- banks ----------------------------------------------------------------------------------------

## Path of the bank description of a car ("" = the profile has none): the manifest of the folder names the raw file.
func _bank_path(id: String) -> String:
	if ctx.assets == null:
		return ""
	var e := ctx.assets.entry("engines", id)
	if e == null or e.kind != "bank" or e.files.is_empty():
		return ""
	return e.files[0].get_basename() + ".json"


func _remember(id: String, bank: EngineBank2) -> void:
	_banks[id] = bank
	_bank_order.erase(id)
	_bank_order.append(id)
	while _bank_order.size() > BANK_CACHE:
		var old := _bank_order[0]
		if old == vehicle_id or (_preview != null and _preview.id == old):
			break
		_bank_order.remove_at(0)
		_banks.erase(old)


func _checked(id: String, bank: EngineBank2) -> EngineBank2:
	if bank == null:
		return null
	for w in bank.warnings:
		push_warning("Motorbank %s: %s" % [bank.path, w])
	if not bank.ok():
		for e in bank.errors:
			push_error("Motorbank %s: %s" % [bank.path, e])
		return null
	return bank


## The bank of a car, loaded now if necessary (null = none).
func _bank_now(id: String) -> EngineBank2:
	if bank_override.has(id):
		return bank_override[id] as EngineBank2
	_finish_task(id, true)
	if _banks.has(id):
		_remember(id, _banks[id])
		return _banks[id]
	var path := _bank_path(id)
	var bank: EngineBank2 = null
	if path != "":
		var t0 := Time.get_ticks_msec()
		bank = _checked(id, EngineBank2.load_file(path))
		if bank != null and ctx.live:
			print("ModernAudio: Motorbank %s geladen in %d ms" % [bank.summary(), Time.get_ticks_msec() - t0])
	_remember(id, bank)
	return bank


## The bank of a car if it is in memory; otherwise a worker task starts loading it and null comes back
## (bank_ready() tells when it is there).
func _bank_async(id: String) -> EngineBank2:
	if bank_override.has(id) or _banks.has(id) or ctx.sync:
		return _bank_now(id)
	if not _tasks.has(id):
		var path := _bank_path(id)
		if path == "":
			_remember(id, null)
			return null
		_tasks[id] = WorkerThreadPool.add_task(_load_task.bind(id, path), false, "Motorbank " + id)
	return null


func _load_task(id: String, path: String) -> void:
	var bank := EngineBank2.load_file(path)
	_load_mutex.lock()
	_loaded[id] = bank
	_load_mutex.unlock()


## Takes over the result of a load task (wait = block until it is done).
func _finish_task(id: String, wait: bool) -> void:
	if not _tasks.has(id):
		return
	var task: int = _tasks[id]
	if not wait and not WorkerThreadPool.is_task_completed(task):
		return
	WorkerThreadPool.wait_for_task_completion(task)
	_tasks.erase(id)
	_load_mutex.lock()
	var bank: EngineBank2 = _loaded.get(id)
	_loaded.erase(id)
	_load_mutex.unlock()
	_remember(id, _checked(id, bank))


func _bank_ready(id: String) -> bool:
	_finish_task(id, false)
	return bank_override.has(id) or _banks.has(id)


# --- units ----------------------------------------------------------------------------------------

func _make_unit(id: String, bank: EngineBank2, level_db: float) -> Unit:
	_seed_n += 1
	var u := Unit.new(id, bank, (SYNC_SEED + _seed_n * 7919) if ctx.sync else -1)
	u.mix.level = db_to_linear(level_db)
	u.mix.motion_rpm = float(_motion.get("rpm", u.mix.motion_rpm))
	u.mix.motion_level_db = float(_motion.get("level_db", u.mix.motion_level_db))
	u.mix.motion_load = float(_motion.get("load", u.mix.motion_load))
	u.mix.motion_cycle_db = float(_motion.get("cycle_db", u.mix.motion_cycle_db))
	return u


## Stops the worker of a unit and frees its player; the generator stream is kept alive a little longer than the
## player (ModernAudioContext.keep_alive – the audio thread still mixes a fade-out block of it).
func _release_output(u: Unit) -> void:
	if u == null:
		return
	ModernAudioContext.free_player(u.mix.detach())


func _pump(u: Unit, dt: float, node_name: String, latency_sync: float) -> void:
	if not ctx.live:
		return
	if u.mix.player == null and not u.mix.is_silent():
		u.mix.attach(ctx.player(BUS, node_name), _buffer)
	u.mix.pump(latency_sync if ctx.sync else _latency, dt, not ctx.sync)


func set_vehicle(id: String) -> void:
	vehicle_id = id
	var vmax := float(ConfigLoader.lookup(ctx.cfg, "vehicles.types.%s.vmax_kmh" % id, 250.0))
	_fallback = EngineGearbox.generic(vmax, _gears)
	_release_output(_unit)
	_unit = null
	_start_pending = false
	var bank := _bank_now(id)
	if bank != null:
		_unit = _make_unit(id, bank, _level_db)
		_unit.reset()
		_start_pending = true


func update(frame: ModernAudioFrame) -> void:
	_time = frame.time
	if _unit == null:
		if _fallback != null and frame.alive:
			_fallback.update(frame.dt, frame.speed, frame.throttle, frame.vmax, frame.active)
	else:
		if frame.alive:
			if _start_pending:
				_start_pending = false
				_unit.start(frame.speed < MOVING_KMH)
				_started_at = _time
			_unit.update(frame.dt, frame.speed, frame.throttle, frame.vmax, frame.active)
			_unit.mix.fade_to(1.0, FADE_S)
		else:
			_unit.mix.fade_to(0.0, FADE_S)
		_pump(_unit, frame.dt, "EngineV3", _sync_latency if _time - _started_at > START_WINDOW_S else _start_latency)
	_update_preview(frame.dt)


## {rpm, gear (0 = neutral, 1..n), load 0..1, boost 0..1} of the race engine, plus the keys for the vehicle layers
## (see the head of this file).
func state() -> Dictionary:
	if _unit != null:
		return _unit.state()
	if _fallback != null:
		return {"rpm": _fallback.rpm, "gear": _fallback.gear, "load": _fallback.load, "boost": 0.0}
	return {"rpm": 0.0, "gear": 0, "load": 0.0, "boost": 0.0}


## Render time of the live playback: {avg_ms, max_ms per filling call, frames = filling calls, samples, skips =
## underruns, ms_per_frame = render time per 1/60 s of sound, threaded}.
func perf() -> Dictionary:
	if _unit == null:
		return {"avg_ms": 0.0, "max_ms": 0.0, "frames": 0, "samples": 0, "skips": 0, "ms_per_frame": 0.0, "threaded": false}
	var p := _unit.mix.perf()
	p["threaded"] = not ctx.sync
	return p


# --- preview --------------------------------------------------------------------------------------

## Vehicle selection: a short rev blip of that car; a running blip fades out first, they never overlap.
func preview(id: String) -> void:
	if not _preview_on:
		return
	_preview_wanted = id
	_bank_async(id)
	if _preview != null:
		_preview.mix.fade_to(0.0, 0.04)


func _update_preview(dt: float) -> void:
	if _preview_wanted != "" and (_preview == null or not ctx.live or _preview.mix.is_silent()) and _bank_ready(_preview_wanted):
		var id := _preview_wanted
		_preview_wanted = ""
		_stop_preview()
		var bank := _bank_now(id)
		if bank != null:
			_preview = _make_unit(id, bank, _level_db + _preview_db)
			_preview.start(false)
			_preview_t = 0.0
	if _preview == null:
		return
	_preview_t += dt
	var thr := 0.0
	if _preview_wanted == "":
		thr = EngineAudio.preview_throttle(_preview_t)
		if _preview_t >= EngineAudio.PREVIEW_S - 0.25:
			_preview.mix.fade_to(0.0, 0.25)
	_preview.update(dt, 0.0, thr, 0.0, false)
	_pump(_preview, dt, "EnginePreview", _sync_latency)
	if _preview_wanted == "" and (not ctx.live or _preview.mix.is_silent()) and _preview_t > EngineAudio.PREVIEW_S + 0.5:
		_stop_preview()


func _stop_preview() -> void:
	_release_output(_preview)
	_preview = null


func stop_all() -> void:
	if _unit != null:
		_release_output(_unit)
		_unit.reset()
	_stop_preview()
	_preview_wanted = ""
	if _fallback != null:
		_fallback.reset()


func teardown() -> void:
	_release_output(_unit)
	_unit = null
	_stop_preview()
	_preview_wanted = ""
	for id: String in _tasks.keys():
		_finish_task(id, true)
	_banks.clear()
	_bank_order.clear()


func debug_state() -> Dictionary:
	var s := state()
	s["vehicle"] = vehicle_id
	s["bank"] = _unit != null
	s["playing"] = _unit != null and _unit.mix.player != null and is_instance_valid(_unit.mix.player) and _unit.mix.player.playing
	s["threaded"] = _unit != null and _unit.mix.threaded()
	s["preview"] = _preview != null
	s["preview_wanted"] = _preview_wanted
	s["preview_vehicle"] = _preview.id if _preview != null else ""
	s["banks_cached"] = _banks.size()
	return s
