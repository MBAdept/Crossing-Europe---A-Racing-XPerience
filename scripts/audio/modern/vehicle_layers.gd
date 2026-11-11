class_name VehicleLayers
extends ModernAudioModule
## Slot "layers" of the Modern sound: what the player's drivetrain adds around the engine's cycle sound, on the bus
## MEngineFx (→ MCar) – package AU-B, contract D27; docs/motorsound.md "Modern". Godot mixes these sounds natively;
## this script only moves volume and pitch once per frame (no per-sample script time):
##   turbo tone      the charger's whistle as a narrow band of noise around a tone (one charger: mono; two: one per
##                   side, slightly detuned) – pitch with the shaft speed (layers.turbo.whistle_hz), level with shaft
##                   speed and load
##   turbo hiss      flow noise of the compressor, with the boost
##   final drive     gear whine of the axle: pitch with the road speed (wheel circumference, final ratio, pinion
##                   teeth), louder under load – kept low (layers.driveline.fd_level)
##   gear mesh       gear whine of the gearbox: pitch with the engine speed (mesh teeth)
##   tip-in          one-shot when the pedal goes down hard while driving: induction gulp and the driveline taking
##                   up the torque
##   shift thump     one-shot on every gear change (stronger on a loaded upshift)
##   blow-off        one-shot when the driver lifts with boost (the engine slot decides when and how loud)
## The engine itself – starter and first fires, idle, limiter cut, shift cracks, crackles – is the cycle mixer of the
## slot "engine" (EngineAudio3): those sounds have to stay in step with its cycles.
##
## Everything follows frame.engine, the state of the engine slot in the same frame (rpm, gear, load, boost, shaft,
## limiter, shifting, throttle and the counters upshifts / downshifts / blowoffs), plus frame.speed and
## frame.throttle. The car's parameters come from its bank description (<car>.json: "layers" and "mix"; read
## without the samples), the sounds from assets/audio/modern/vehicle (ctx.assets). Levels are written in the
## engine's own scale: a level of 1 is the full scale of the bank before mix.gain, and the car's mix.gain and
## audio.modern.engine.level_db apply to the layers as to the engine – they keep their place under it.
## A car without a v3 bank has no layers. Configuration: audio.modern.layers (level_db, turbo_db, driveline_db,
## shots_db; enabled).

const BUS := "MEngineFx"
const FOLDER := "vehicle"
const SHOT_VOICES := 4
const SMOOTH_S := 0.05           ## loops follow their targets with this time constant
const FADE_S := 0.08             ## … and fade with this one when the session is gone or paused
const TURBO_REF_HZ := 3000.0     ## pitch of the turbo tone files at pitch_scale 1
const WHINE_REF_HZ := 1000.0     ## … of the driveline whine
const ROLL_KMH := 25.0           ## the driveline whine fades in up to this speed
const TIPIN_KMH := 20.0          ## tip-in only when the car moves
const TIPIN_LOW := 0.35          ## pedal below this …
const TIPIN_HIGH := 0.9          ## … then above this within TIPIN_S
const TIPIN_S := 0.25
const SHOT_GAP_S := 0.08         ## the same one-shot not twice within this time

var vehicle_id := ""
## Tests/tools: folder with the bank descriptions (<car>.json) instead of the one the manifest names.
var bank_dir := ""
var boost := 0.0                 ## last boost seen (tests: the slot receives the engine state)
var counts := {"tipin": 0, "thump": 0, "blowoff": 0}   ## one-shots started
var turbo := ModernAudioLoop.new()
var hiss := ModernAudioLoop.new()
var final_drive := ModernAudioLoop.new()
var gear_mesh := ModernAudioLoop.new()
var shots := ModernAudioVoices.new()

var _enabled := true
var _level_db := 0.0
var _turbo_db := 0.0
var _driveline_db := 0.0
var _shots_db := 0.0
var _has_car := false
var _scale_db := 0.0             # the car's mix.gain and the engine level
var _redline := 6500.0
var _turbo_on := false
var _whistle := Vector2(1800.0, 5200.0)
var _tone_level := 0.0
var _hiss_level := 0.0
var _fd_hz_per_mps := 18.7       # final ratio × pinion teeth / wheel circumference
var _gm_teeth := 29.0
var _fd_level := 0.0
var _gm_level := 0.0
var _tipin_level := 0.0
var _thump_level := 0.0
var _tipin_id := ""
var _thump_id := ""
var _blowoff_id := ""
var _seen_valid := false
var _seen_up := 0
var _seen_down := 0
var _seen_blow := 0
var _low_t := 100.0              # seconds since the pedal was below TIPIN_LOW
var _last_shot: Dictionary = {}  # name -> frame.time
var _variant: Dictionary = {}    # sound id -> last variant played
var _rng := RandomNumberGenerator.new()
var _frame_shots: Array = []     # one-shots of this frame (trace_row)


func _setup() -> void:
	_enabled = bool(ctx.value("layers.enabled", true))
	_level_db = ctx.number("layers.level_db", 0.0)
	_turbo_db = ctx.number("layers.turbo_db", 0.0)
	_driveline_db = ctx.number("layers.driveline_db", 0.0)
	_shots_db = ctx.number("layers.shots_db", 0.0)
	_rng.seed = 8061
	shots.attach(ctx, BUS, SHOT_VOICES, "VehicleShot")


## The bank description of a car ({} = none): engine, gearbox, layers, mix – without the samples.
func _meta_of(id: String) -> Dictionary:
	if bank_dir != "":
		return EngineBank2.read_meta(EngineBank2.path_for(id, bank_dir))
	if ctx.assets == null:
		return {}
	var e := ctx.assets.entry("engines", id)
	if e == null or e.kind != "bank" or e.files.is_empty():
		return {}
	return EngineBank2.read_meta(e.files[0].get_basename() + ".json")


static func _block(d: Dictionary, key: String) -> Dictionary:
	var v: Variant = d.get(key, {})
	return v if v is Dictionary else {}


func _gain_db(id: String) -> float:
	var e := ctx.assets.entry(FOLDER, id) if ctx.assets != null else null
	return e.gain_db if e != null else 0.0


func set_vehicle(id: String) -> void:
	vehicle_id = id
	_seen_valid = false
	_low_t = 100.0
	boost = 0.0
	turbo.release()
	hiss.release()
	final_drive.release()
	gear_mesh.release()
	shots.stop_all()
	_has_car = false
	var meta := _meta_of(id) if _enabled else {}
	if meta.is_empty():
		return
	_has_car = true
	var layers := _block(meta, "layers")
	var mix := _block(meta, "mix")
	_redline = maxf(float(_block(meta, "engine").get("redline_rpm", 6500.0)), 1000.0)
	_scale_db = linear_to_db(maxf(float(mix.get("gain", 1.0)), 1.0e-4)) + ctx.number("engine.level_db", 0.0) + _level_db
	# turbo
	var t := _block(layers, "turbo")
	_turbo_on = not t.is_empty() and str(t.get("tone", "")) != ""
	_tone_level = 0.0
	_hiss_level = 0.0
	if _turbo_on:
		var wh: Variant = t.get("whistle_hz", [1800, 5200])
		if wh is Array and (wh as Array).size() == 2:
			_whistle = Vector2(float(wh[0]), float(wh[1]))
		_tone_level = maxf(float(t.get("tone_level", 0.0)), 0.0)
		_hiss_level = maxf(float(t.get("hiss_level", 0.0)), 0.0)
		var tone_id := str(t.get("tone", ""))
		var hiss_id := str(t.get("hiss", ""))
		turbo.attach(ctx, BUS, ctx.stream(FOLDER, tone_id), "TurboTone")
		turbo.gain_db = _gain_db(tone_id) + _scale_db + _turbo_db
		hiss.attach(ctx, BUS, ctx.stream(FOLDER, hiss_id), "TurboHiss")
		hiss.gain_db = _gain_db(hiss_id) + _scale_db + _turbo_db
	# driveline
	var dl := _block(layers, "driveline")
	_fd_level = maxf(float(dl.get("fd_level", 0.0)), 0.0)
	_gm_level = maxf(float(dl.get("gm_level", 0.0)), 0.0)
	_fd_hz_per_mps = float(dl.get("final_ratio", 3.2)) * float(dl.get("pinion_teeth", 12)) / maxf(float(dl.get("wheel_m", 2.05)), 0.5)
	_gm_teeth = float(dl.get("mesh_teeth", 29))
	var whine_id := str(dl.get("sound", ""))
	if whine_id != "" and (_fd_level > 0.0 or _gm_level > 0.0):
		var st := ctx.stream(FOLDER, whine_id)
		final_drive.attach(ctx, BUS, st, "FinalDrive")
		final_drive.gain_db = _gain_db(whine_id) + _scale_db + _driveline_db
		gear_mesh.attach(ctx, BUS, st, "GearMesh")
		gear_mesh.gain_db = final_drive.gain_db
	# one-shots
	var ti := _block(layers, "tipin")
	_tipin_id = str(ti.get("sound", ""))
	_tipin_level = maxf(float(ti.get("level", 0.0)), 0.0)
	var th := _block(layers, "thump")
	_thump_id = str(th.get("sound", ""))
	_thump_level = maxf(float(th.get("level", 0.0)), 0.0)
	_blowoff_id = str(_block(layers, "blowoff").get("sound", ""))


func update(frame: ModernAudioFrame) -> void:
	_frame_shots.clear()
	var e := frame.engine
	boost = float(e.get("boost", 0.0))
	var dt := maxf(frame.dt, 0.0001)
	var on := _has_car and frame.alive and not frame.effects_muted and not e.is_empty()
	var k := 1.0 - exp(-dt / (SMOOTH_S if on else FADE_S))
	var t_tone := 0.0
	var t_hiss := 0.0
	var t_fd := 0.0
	var t_gm := 0.0
	var p_tone := turbo.pitch
	var p_fd := final_drive.pitch
	var p_gm := gear_mesh.pitch
	if on:
		var rpm := float(e.get("rpm", 0.0))
		var load := clampf(float(e.get("load", 0.0)), 0.0, 1.0)
		var shaft := clampf(float(e.get("shaft", boost)), 0.0, 1.0)
		var rev := clampf(rpm / _redline, 0.0, 1.0)
		if _turbo_on:
			t_tone = _tone_level * pow(shaft, 1.6) * (0.35 + 0.65 * load)
			t_hiss = _hiss_level * pow(clampf(boost, 0.0, 1.0), 1.5) * (0.4 + 0.6 * shaft)
			p_tone = lerpf(_whistle.x, _whistle.y, pow(shaft, 0.8)) / TURBO_REF_HZ
		var roll := clampf(frame.speed / ROLL_KMH, 0.0, 1.0)
		var in_gear := int(e.get("gear", 0)) > 0
		t_fd = _fd_level * pow(clampf(frame.speed / 250.0, 0.0, 1.2), 1.2) * (0.45 + 0.55 * load) * roll
		t_gm = _gm_level * pow(rev, 1.5) * (0.3 + 0.7 * load) * roll * (1.0 if in_gear else 0.0)
		# on overrun the flanks of the teeth change sides: the whine drops a touch in pitch
		p_fd = maxf(frame.speed / 3.6 * _fd_hz_per_mps * (0.994 if load < 0.2 else 1.0), 20.0) / WHINE_REF_HZ
		p_gm = maxf(rpm / 60.0 * _gm_teeth, 20.0) / WHINE_REF_HZ
		_events(frame, e, load)
	else:
		_seen_valid = false
		_low_t = 100.0
	turbo.drive(t_tone, p_tone, k)
	hiss.drive(t_hiss, 1.0, k)
	final_drive.drive(t_fd, p_fd, k)
	gear_mesh.drive(t_gm, p_gm, k)


## One-shots of this frame: gear changes and blow-offs from the engine's counters, tip-in from the pedal.
func _events(frame: ModernAudioFrame, e: Dictionary, load: float) -> void:
	var up := int(e.get("upshifts", 0))
	var down := int(e.get("downshifts", 0))
	var blow := int(e.get("blowoffs", 0))
	if _seen_valid:
		if up > _seen_up:
			# the load is cut during the shift: the pedal tells how much torque comes back
			_shot("thump", _thump_id, _thump_level * (0.5 + 0.5 * clampf(maxf(frame.throttle, load), 0.0, 1.0)), frame.time)
		elif down > _seen_down:
			_shot("thump", _thump_id, _thump_level * 0.45, frame.time)
		if blow > _seen_blow:
			_shot("blowoff", _blowoff_id, 2.0 * float(e.get("blowoff_level", 0.0)), frame.time)
	_seen_valid = true
	_seen_up = up
	_seen_down = down
	_seen_blow = blow
	# tip-in: from a closed pedal to (nearly) full within TIPIN_S, in gear, moving
	var thr := frame.throttle
	if thr <= TIPIN_LOW:
		_low_t = 0.0
	else:
		if thr >= TIPIN_HIGH and _low_t <= TIPIN_S and frame.speed > TIPIN_KMH and int(e.get("gear", 0)) > 0:
			_shot("tipin", _tipin_id, _tipin_level, frame.time)
			_low_t = 100.0
		_low_t += frame.dt


func _shot(kind: String, id: String, gain: float, now: float) -> void:
	if id == "" or gain <= 0.0005 or now - float(_last_shot.get(kind, -100.0)) < SHOT_GAP_S:
		return
	var n := ctx.assets.variant_count(FOLDER, id) if ctx.assets != null else 0
	if n == 0:
		return
	var v := 0
	if n > 1:
		v = _rng.randi_range(0, n - 1)
		if v == int(_variant.get(id, -1)):
			v = (v + 1) % n
	_variant[id] = v
	_last_shot[kind] = now
	counts[kind] = int(counts.get(kind, 0)) + 1
	var db := linear_to_db(gain) + _gain_db(id) + _scale_db + _shots_db
	_frame_shots.append([id, v, snappedf(db, 0.01)])
	if ctx.live:
		shots.play(ctx.assets.stream(FOLDER, id, v), db)


func stop_all() -> void:
	turbo.silence()
	hiss.silence()
	final_drive.silence()
	gear_mesh.silence()
	shots.stop_all()
	_seen_valid = false
	_low_t = 100.0


func teardown() -> void:
	turbo.release()
	hiss.release()
	final_drive.release()
	gear_mesh.release()
	shots.release()


## Tools: what the layers do in this frame – per loop [level (linear, engine scale × its gain), pitch_scale] and the
## one-shots started [[sound id, variant, volume dB], …].
func trace_row() -> Dictionary:
	return {"turbo": [turbo.level * db_to_linear(turbo.gain_db), turbo.pitch], "hiss": [hiss.level * db_to_linear(hiss.gain_db), hiss.pitch],
		"fd": [final_drive.level * db_to_linear(final_drive.gain_db), final_drive.pitch],
		"gm": [gear_mesh.level * db_to_linear(gear_mesh.gain_db), gear_mesh.pitch], "shots": _frame_shots.duplicate(true)}


func debug_state() -> Dictionary:
	var playing := 0
	for l: ModernAudioLoop in [turbo, hiss, final_drive, gear_mesh]:
		playing += 1 if l.playing() else 0
	return {"vehicle": vehicle_id, "car": _has_car, "boost": boost, "loops": playing, "turbo": turbo.level, "hiss": hiss.level,
		"final_drive": final_drive.level, "gear_mesh": gear_mesh.level, "turbo_pitch": turbo.pitch,
		"final_drive_pitch": final_drive.pitch, "gear_mesh_pitch": gear_mesh.pitch, "shots": counts.duplicate()}
