class_name EngineAudio3
extends ModernAudioModule
## Slot "engine" of the Modern sound: the engine of the player's car on the bus MEngine (→ MCar → MEnv).
## ModernAudio expects from this class, beyond the hooks of ModernAudioModule:
##   state() -> {rpm, gear (0 = neutral), load 0..1, boost 0..1}   AudioManager.engine_state(), frame.engine
##   perf()  -> {avg_ms, max_ms, frames, samples, skips}           AudioManager.engine_perf()
##   preview(id)                                                   vehicle selection: short rev blip of that car
## The car comes through set_vehicle(id), the driving values every frame in update(frame): frame.alive, speed,
## throttle, vmax, active. ctx.sync = no worker thread (--audio-sync, audio.modern.engine_thread = false).
##
## Stand-in of wave 0 (package AU-B replaces it with engine v3: stereo banks <car>.json + <car>.i16 from
## assets/audio/modern/engines, mixer in a worker thread): the car's Arcade cycle bank played by the unchanged
## Arcade classes EngineAudio / EngineBank / EngineGearbox, mixed on the main thread, with the same handling as in
## the AudioManager (start clip, fade when the session stops or the tree pauses, longer queue in the first second
## of a stage) and the stereo width reverb of the Arcade Engine bus on MEngine (the Arcade bank is mono). A car
## without a bank is silent here; its gearbox still runs (state()).

const BUS := "MEngine"
const FADE_S := 0.12             ## fade on pause / scene change / resume (as AudioManager.ENGINE_FADE_S)
const PREVIEW_DB := -2.0         ## rev blip relative to the engine level
const START_WINDOW_S := 1.0      ## after the engine start the generator queue is engine_start_latency_s long

var vehicle_id := ""
var _eng: EngineAudio = null
var _start_pending := false
var _started_at := -100.0
var _fallback: EngineGearbox = null
var _preview: EngineAudio = null
var _preview_next: EngineAudio = null
var _preview_t := 0.0
var _time := 0.0
var _level_db := -3.0
var _latency := 0.07
var _buffer := 0.25
var _start_latency := 0.2
var _preview_on := true
var _gears := 6


func _setup() -> void:
	var c := ctx.cfg
	_gears = int(ConfigLoader.lookup(c, "audio.engine_gears", 6))
	_level_db = float(ConfigLoader.lookup(c, "audio.engine_db", -3.0))
	_latency = clampf(float(ConfigLoader.lookup(c, "audio.engine_latency_s", 0.07)), 0.02, 0.2)
	_buffer = clampf(float(ConfigLoader.lookup(c, "audio.engine_buffer_s", 0.25)), _latency * 2.0, 1.0)
	_start_latency = clampf(float(ConfigLoader.lookup(c, "audio.engine_start_latency_s", 0.2)), _latency, _buffer * 0.85)
	_preview_on = bool(ConfigLoader.lookup(c, "audio.engine_preview", true))
	_fallback = EngineGearbox.generic(250.0, _gears)
	# stereo width of the mono bank: the short diffuse reverb of the Arcade Engine bus (RoomAudio)
	var width: AudioEffectReverb = null
	if ctx.buses != null:
		width = ctx.buses.effect(BUS, "AudioEffectReverb") as AudioEffectReverb
	if width != null:
		width.dry = 1.0
		width.wet = clampf(float(ConfigLoader.lookup(c, "audio.engine_width", 0.6)), 0.0, 1.0)
		width.room_size = RoomAudio.WIDTH_ROOM.x
		width.damping = RoomAudio.WIDTH_ROOM.y
		width.hipass = clampf(float(ConfigLoader.lookup(c, "audio.engine_width_hipass", 0.1)), 0.0, 1.0)
		width.predelay_msec = RoomAudio.WIDTH_ROOM.z
		width.predelay_feedback = 0.0
		width.spread = 1.0


func set_vehicle(id: String) -> void:
	vehicle_id = id
	var vmax := float(ConfigLoader.lookup(ctx.cfg, "vehicles.types.%s.vmax_kmh" % id, 250.0))
	_fallback = EngineGearbox.generic(vmax, _gears)
	_detach(_eng)
	_eng = null
	_start_pending = false
	var bank := _bank(id)
	if bank != null:
		_eng = EngineAudio.new(bank)
		_eng.level = db_to_linear(_level_db)
		_eng.reset()
		_start_pending = true


func _bank(id: String) -> EngineBank:
	if not ctx.bank_provider.is_valid():
		return null
	var b: Variant = ctx.bank_provider.call(id)
	return b as EngineBank if b is EngineBank else null


func update(frame: ModernAudioFrame) -> void:
	_time = frame.time
	if _eng == null:
		if _fallback != null and frame.alive:
			_fallback.update(frame.dt, frame.speed, frame.throttle, frame.vmax, frame.active)
	else:
		if frame.alive:
			if _start_pending:
				_start_pending = false
				_eng.start(true)
				_started_at = _time
			_eng.update(frame.dt, frame.speed, frame.throttle, frame.vmax, frame.active)
			_eng.fade_to(1.0, FADE_S)
		else:
			_eng.fade_to(0.0, FADE_S)
		if ctx.live:
			if _eng.player == null and not _eng.is_silent():
				_eng.attach(ctx.host, BUS, _buffer)
			_eng.pump(_latency if _time - _started_at > START_WINDOW_S else _start_latency, frame.dt)
	_update_preview(frame.dt)


## {rpm, gear (0 = neutral, 1..n), load 0..1, boost 0..1} of the race engine.
func state() -> Dictionary:
	if _eng != null:
		return _eng.state()
	if _fallback != null:
		return {"rpm": _fallback.rpm, "gear": _fallback.gear, "load": _fallback.load, "boost": 0.0}
	return {"rpm": 0.0, "gear": 0, "load": 0.0, "boost": 0.0}


## Render time of the live playback: {avg_ms, max_ms per filling call, frames, samples, skips = underruns}.
func perf() -> Dictionary:
	if _eng == null or _eng.perf_calls == 0:
		return {"avg_ms": 0.0, "max_ms": 0.0, "frames": 0, "samples": 0, "skips": 0}
	return {"avg_ms": _eng.perf_us_sum / 1000.0 / _eng.perf_calls, "max_ms": _eng.perf_us_max / 1000.0,
		"frames": _eng.perf_calls, "samples": _eng.perf_samples, "skips": _eng.skips()}


## Vehicle selection: a short rev blip of that car; a running blip fades out first, they never overlap.
func preview(id: String) -> void:
	if not _preview_on or not ctx.live:
		return
	var bank := _bank(id)
	if bank == null:
		return
	var e := EngineAudio.new(bank)
	e.level = db_to_linear(_level_db + PREVIEW_DB)
	e.start(false)
	if _preview == null:
		_preview = e
		_preview_t = 0.0
		_preview.attach(ctx.host, BUS, _buffer)
	else:
		_preview.fade_to(0.0, 0.04)
		_preview_next = e


func _update_preview(dt: float) -> void:
	if _preview == null:
		return
	if _preview_next != null and _preview.is_silent():
		_keep_stream(_preview)
		_preview_next.take_output(_preview, ctx.host, BUS, _buffer)
		_preview = _preview_next
		_preview_next = null
		_preview_t = 0.0
	_preview_t += dt
	var thr := 0.0
	if _preview_next == null:
		thr = EngineAudio.preview_throttle(_preview_t)
		if _preview_t >= EngineAudio.PREVIEW_S - 0.25:
			_preview.fade_to(0.0, 0.25)
	_preview.update(dt, 0.0, thr, 0.0, false)
	_preview.pump(_latency, dt)
	if _preview_next == null and _preview.is_silent() and _preview_t > EngineAudio.PREVIEW_S + 0.5:
		_stop_preview()


func _stop_preview() -> void:
	_detach(_preview)
	_preview = null
	_preview_next = null


## Detaches an engine from its player. The generator stream is kept alive a little longer than the player (see
## ModernAudioContext.keep_alive: the audio thread still mixes a fade-out block of it).
func _detach(e: EngineAudio) -> void:
	if e == null:
		return
	_keep_stream(e)
	e.detach()


func _keep_stream(e: EngineAudio) -> void:
	if e != null and e.player != null and is_instance_valid(e.player):
		ModernAudioContext.keep_alive(e.player.stream)


func stop_all() -> void:
	if _eng != null:
		_detach(_eng)
		_eng.reset()
	_stop_preview()
	if _fallback != null:
		_fallback.reset()


func teardown() -> void:
	_detach(_eng)
	_eng = null
	_stop_preview()


func debug_state() -> Dictionary:
	var s := state()
	s["vehicle"] = vehicle_id
	s["bank"] = _eng != null
	s["playing"] = _eng != null and _eng.player != null and is_instance_valid(_eng.player) and _eng.player.playing
	s["preview"] = _preview != null
	return s
