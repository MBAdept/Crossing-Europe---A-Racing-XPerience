class_name TrafficExtras
extends ModernAudioModule
## Slot "traffic" of the Modern sound (package AU-C2; contract D25–D29; docs/audio-modern.md "Welt, Ambiente,
## Verkehr"): the other road users – pass-by voices on the buses MTrafficV0 … MTrafficV7 and the police siren on
## MSiren (→ MWorld → MEnv). ModernAudio expects, beyond the hooks of ModernAudioModule:
##   state() -> Dictionary   AudioManager.traffic_state() (voices of the last frame, listener, siren)
##   perf()  -> Dictionary   AudioManager.traffic_perf()
## Inputs every frame: frame.vehicles / frame.listener / frame.traffic_alive (set_traffic), frame.siren_level,
## frame.feed (wet, snow), and the session's event "collision".
##
## The model of the voices is Arcade's TrafficAudio, unchanged (voice assignment with hysteresis, distance, pan,
## Doppler, air absorption – docs/verkehrsgeraeusche.md §2), in a subclass that sends to the Modern buses and adds:
##   sounds      the Modern traffic sounds (assets/audio/modern/traffic, tools/audio/modern/traffic_modern.py): the
##               classes and the model map are configuration (audio.modern.traffic.classes / models) – more engines
##               per class (two operating points of the petrol and the diesel car, an electric car), the police with
##               a sports and a fast diesel engine. Not through TrafficAudio.load_sounds(): its loader sets the loop
##               end to the end of the data, and the Modern WAV loops carry LOOP_GUARD frames behind their loop end
##               (the streams come from ModernAudioAssets with the manifest's loop points).
##   levels      each sound's level is a target at the master (audio.modern.traffic.levels: LUFS of that layer of one
##               vehicle at or inside the reference distance traffic_ref_m · size, at the sound's ref_kmh), measured
##               against the manifest loudness: gain_db = target − lufs − ref_path_db + 3.01 (TrafficAudio pans a mono
##               voice with equal power – 3 dB under the same file on both channels, which the manifest measures)
##   wet         in rain (feed.wet ≥ wet_from) a new voice takes the wet variant of its tyres (spray); on snow too
##   whooshes    a moving vehicle passing the listener closely (lateral ≤ whoosh.max_m, its own speed ≥
##               whoosh.own_min_kmh, relative speed ≥ whoosh.min_kmh) throws a gust: a short swish of a car, the
##               pressure wave and buffeting of a truck or bus – at its side, louder with the vehicle's own speed (the
##               air it pushes: whoosh.slope_db per decade over whoosh.ref_kmh) and the nearness (1 / lateral
##               distance), quicker (pitch) with the relative speed; a standing car throws nothing
##   horns       rare and at random: a vehicle the player hit honks after a reaction time (horns.after_collision),
##               one the player squeezed past much faster honks twice (horns.close_pass); a truck its air horn, a
##               hatchback its small horn; at the vehicle's place (pan, distance, Doppler, followed while it sounds);
##               never the police; at most one horn per horns.cooldown_s
##   siren       the Modern siren (traffic/siren) with the distance law of Arcade's TrafficAudio (siren_ref_m,
##               siren_rolloff, siren_floor), its level a target at the master (siren_lufs at or inside
##               siren_ref_m); the centred fallback (no police car in the list) at the session's level × that
## Nothing here reads the renderer (Rule 4) or feeds back into the simulation (Rule 3).

const FOLDER := "traffic"
const FX_VOICES := 4
const PAIR_DB := 3.0103


## TrafficAudio on the Modern buses (which exist with their low-pass filters – ModernBuses).
class ModernTraffic:
	extends TrafficAudio

	var buses: ModernBuses = null
	var wet_map: Dictionary = {}    ## dry tyre sound -> wet variant
	var wet := false                ## new voices take the wet tyres

	func attach(parent: Node, _send_bus: String) -> void:
		if _vp != null or buses == null:
			return
		_vp = SubViewport.new()
		_vp.name = "ModernTrafficVoices"
		_vp.size = Vector2i(int(PAN_PX), int(PAN_PX))
		_vp.audio_listener_enable_2d = true
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		parent.add_child(_vp)
		var lis := AudioListener2D.new()
		_vp.add_child(lis)
		lis.make_current()
		var strength := float(ProjectSettings.get_setting("audio/general/2d_panning_strength", 0.5))
		var ps := clampf(1.0 / maxf(strength, 0.01), 0.0, 3.0)
		_players.clear()
		_filters.clear()
		_last_db.clear()
		for i in voice_count + 1:
			var bus := (ModernBuses.TRAFFIC_PREFIX + str(i)) if i < voice_count else "MSiren"
			_filters.append(buses.voice_filter(i if i < voice_count else ModernBuses.TRAFFIC_VOICES))
			var layer_players: Array = []
			for k in (3 if i < voice_count else 1):
				var p := AudioStreamPlayer2D.new()
				p.bus = bus
				p.max_distance = 1.0e6
				p.attenuation = 1.0
				p.panning_strength = ps
				p.area_mask = 0
				p.volume_db = -80.0
				_vp.add_child(p)
				layer_players.append(p)
			_players.append(layer_players)
			_last_db.append(PackedFloat32Array([-80.0, -80.0, -80.0]))
		_gens.resize(voice_count + 1)
		_gens.fill(-1)
		_last_cut.resize(voice_count + 1)
		_last_cut.fill(-1.0)

	## A new voice: Arcade's choice of class, engine variant and start points; in rain the wet tyres.
	func _start_voice(v: Voice, e: Dictionary) -> void:
		super._start_voice(v, e)
		if wet and wet_map.has(v.sounds[1]) and sounds.has(wet_map[v.sounds[1]]):
			v.sounds[1] = wet_map[v.sounds[1]]

	## The SubViewport of the voices (the one-shots of this slot play in the same listener world).
	func viewport() -> SubViewport:
		return _vp

	## Index of a slot's vehicle in this frame's list (−1: none).
	func slot_index(s: int) -> int:
		return _slot_idx[s] if s < _slot_idx.size() else -1


var model: ModernTraffic = null
var siren_amp := 1.0                ## linear amplitude of the siren at its reference distance
var horns_played := 0
var whooshes_played := 0
var last_fx: Dictionary = {}        ## the last horn or whoosh: kind, id, variant, db, pan, pitch, vehicle (tests)
var modern_sounds := false          ## the Modern traffic sounds are in use (else Arcade's, as in wave 0)

var _ref_path_db := -1.94
var _wet_from := 0.3
var _wh_max_m := 4.5
var _wh_heavy_max_m := 5.5
var _wh_min_kmh := 15.0
var _wh_own_min_kmh := 30.0
var _wh_ref_kmh := 80.0
var _wh_rel_ref_kmh := 60.0
var _wh_ref_m := 2.0
var _wh_slope := 20.0
var _wh_lufs := {"car": -27.0, "heavy": -22.0}
var _wh_floor := -50.0
var _horn_lufs := {"car": -24.0, "small": -25.0, "truck": -20.0}
var _horn_ref_m := 10.0
var _horn_after_collision := 0.8
var _horn_close := 0.25
var _horn_close_m := 1.8
var _horn_close_kmh := 30.0
var _horn_cooldown := 8.0
var _horn_delay := Vector2(0.3, 0.7)
var _rng := RandomNumberGenerator.new()
var _prev_rel: Dictionary = {}      ## vehicle id -> signed longitudinal offset (m) of the last frame
var _pending: Array[Dictionary] = []   ## horns waiting for their reaction time
var _horn_wait := 0.0
var _fx: Array[AudioStreamPlayer2D] = []
var _fx_follow: Array = []          ## per fx player: [slot, vehicle id] it follows (horns), or []
var _fx_next := 0
var _fx_last: Dictionary = {}
var _frame_vehicles: Array = []


func _setup() -> void:
	var cfg := ctx.cfg.duplicate(true)
	var audio: Dictionary = cfg.get("audio", {})
	audio["traffic_voices"] = ModernBuses.TRAFFIC_VOICES
	var over: Variant = ctx.value("traffic", {})
	if over is Dictionary:
		for k: String in over:
			if not k.begins_with("_") and not (over as Dictionary)[k] is Dictionary:
				audio[k] = (over as Dictionary)[k]
	audio["traffic_voices"] = clampi(int(audio.get("traffic_voices", ModernBuses.TRAFFIC_VOICES)), 0, ModernBuses.TRAFFIC_VOICES)
	cfg["audio"] = audio
	model = ModernTraffic.new()
	model.buses = ctx.buses
	model.setup(cfg)
	_read_config()
	modern_sounds = _load_modern()
	if not modern_sounds:
		var src := ctx.arcade_traffic
		if src != null and src.ok:
			# the sounds the AudioManager loaded (read only): no second copy in memory
			model.sounds = src.sounds
			model.classes = src.classes
			model.models = src.models
			model.path = src.path
			model.ok = true
	model.siren_stream = ctx.stream(FOLDER, "siren", "siren")
	var se := ctx.assets.entry(FOLDER, "siren") if ctx.assets != null else null
	if se != null:
		model.siren_db = ctx.number("traffic.siren_lufs", -17.0) - se.lufs - _ref_path_db
	siren_amp = db_to_linear(model.siren_db)
	_rng.seed = int(ctx.number("traffic.seed", 9203))
	if ctx.live and ctx.host != null:
		model.attach(ctx.host, "MWorld")
		var vp := model.viewport()
		if vp != null:
			for i in FX_VOICES:
				# on MWorld itself: the voices' buses carry the air absorption of their own vehicle
				_fx.append(ModernAudioPan.player(vp, "MWorld", "TrafficFx%d" % i))
				_fx_follow.append([])


func _read_config() -> void:
	_ref_path_db = ctx.number("traffic.ref_path_db", _ref_path_db)
	_wet_from = ctx.number("traffic.wet_from", _wet_from)
	_wh_max_m = ctx.number("traffic.whoosh.max_m", _wh_max_m)
	_wh_heavy_max_m = ctx.number("traffic.whoosh.heavy_max_m", _wh_heavy_max_m)
	_wh_min_kmh = ctx.number("traffic.whoosh.min_kmh", _wh_min_kmh)
	_wh_own_min_kmh = ctx.number("traffic.whoosh.own_min_kmh", _wh_own_min_kmh)
	_wh_ref_kmh = ctx.number("traffic.whoosh.ref_kmh", _wh_ref_kmh)
	_wh_ref_m = ctx.number("traffic.whoosh.ref_m", _wh_ref_m)
	_wh_slope = ctx.number("traffic.whoosh.slope_db", _wh_slope)
	_wh_floor = ctx.number("traffic.whoosh.floor_lufs", _wh_floor)
	_wh_lufs = {"car": ctx.number("traffic.whoosh.car_lufs", -27.0), "heavy": ctx.number("traffic.whoosh.heavy_lufs", -22.0)}
	_horn_lufs = {"car": ctx.number("traffic.horns.car_lufs", -24.0), "small": ctx.number("traffic.horns.small_lufs", -25.0),
		"truck": ctx.number("traffic.horns.truck_lufs", -20.0)}
	_horn_ref_m = maxf(ctx.number("traffic.horns.ref_m", _horn_ref_m), 1.0)
	_horn_after_collision = clampf(ctx.number("traffic.horns.after_collision", _horn_after_collision), 0.0, 1.0)
	_horn_close = clampf(ctx.number("traffic.horns.close_pass", _horn_close), 0.0, 1.0)
	_horn_close_m = ctx.number("traffic.horns.close_m", _horn_close_m)
	_horn_close_kmh = ctx.number("traffic.horns.close_kmh", _horn_close_kmh)
	_horn_cooldown = ctx.number("traffic.horns.cooldown_s", _horn_cooldown)
	var hd: Variant = ctx.value("traffic.horns.delay_s", null)
	if hd is Array and (hd as Array).size() == 2:
		_horn_delay = Vector2(float(hd[0]), float(hd[1]))


## The Modern sounds and classes; false when the manifest has none (then Arcade's, as in wave 0).
func _load_modern() -> bool:
	if ctx.assets == null:
		return false
	var levels: Variant = ctx.value("traffic.levels", {})
	var lv: Dictionary = levels if levels is Dictionary else {}
	var layer_default := {"engine": -27.0, "tires": -27.0, "air": -30.0}
	var snd: Dictionary = {}
	for id: String in ctx.assets.ids(FOLDER, "loop"):
		var e := ctx.assets.entry(FOLDER, id)
		var layer := str(e.meta.get("layer", ""))
		if not TrafficAudio.LAYERS.has(layer):
			continue
		var s := TrafficAudio.Sound.new()
		s.name = id
		s.file = e.files[0]
		s.layer = layer
		s.ref_kmh = float(e.meta.get("ref_kmh", 100.0))
		s.pitch_exp = float(e.meta.get("pitch_exp", 1.0))
		s.db_per_decade = float(e.meta.get("level_db_per_decade", 0.0))
		var target := float(lv.get(id, layer_default.get(layer, -30.0)))
		s.gain_db = target - e.lufs - _ref_path_db + PAIR_DB - model.level_db
		s.stream = ctx.assets.stream(FOLDER, id)
		if s.stream == null:
			continue
		snd[id] = s
	if snd.is_empty():
		return false
	model.sounds = snd
	model.classes.clear()
	model.models.clear()
	var cl: Variant = ctx.value("traffic.classes", {})
	if cl is Dictionary:
		for cname: String in cl:
			var c: TrafficAudio.VClass = model._parse_class(cname, (cl as Dictionary)[cname])
			if c != null:
				model.classes[cname] = c
	var md: Variant = ctx.value("traffic.models", {})
	if md is Dictionary:
		for m: String in md:
			if model.classes.has(str(md[m])):
				model.models[m] = str(md[m])
	var wm: Variant = ctx.value("traffic.wet", {})
	model.wet_map = wm if wm is Dictionary else {}
	model.ok = model.classes.has("car")
	return model.ok


func update(frame: ModernAudioFrame) -> void:
	var f := frame.feed
	model.wet = f != null and f.valid and maxf(f.wet, f.snow) >= _wet_from
	var lvl := clampf(frame.siren_level, 0.0, 1.0) * siren_amp
	model.set_siren(frame.siren_level > 0.0, lvl)
	var vehicles: Array = frame.vehicles if frame.traffic_alive else []
	_frame_vehicles = vehicles
	model.update(frame.dt, vehicles, frame.listener, frame.traffic_alive)
	model.apply()
	_horn_wait = maxf(_horn_wait - frame.dt, 0.0)
	if frame.traffic_alive and not frame.paused:
		_passes(vehicles)
	else:
		_prev_rel.clear()
	_step_pending(frame.dt)
	_follow()


## Vehicles of the voices that crossed the listener since the last frame: whooshes and close-pass horns.
func _passes(vehicles: Array) -> void:
	var seen: Dictionary = {}
	var lz := model.listener_z
	var lx := model.listener_x
	var lv := model.listener_v * 3.6
	for s in model.voices.size():
		var idx := model.slot_index(s)
		if idx < 0:
			continue
		var e: Dictionary = vehicles[idx]
		var vid := int(e.get("id", 0))
		var rel := float(e["z"]) + float(e["length"]) * 0.5 - lz
		seen[vid] = rel
		if not _prev_rel.has(vid):
			continue
		var before := float(_prev_rel[vid])
		if signf(before) == signf(rel) or before == 0.0:
			continue
		var dx := absf(float(e["x"]) - lx)
		var heavy := bool(e.get("heavy", false))
		var own_kmh := maxf(float(e["speed"]), 0.0)
		var rel_kmh := absf(own_kmh - lv)
		if rel_kmh >= _wh_min_kmh and own_kmh >= _wh_own_min_kmh and dx <= (_wh_heavy_max_m if heavy else _wh_max_m):
			_whoosh(s, vid, heavy, own_kmh, rel_kmh, dx, signf(float(e["x"]) - lx))
		if vid != TrafficAudio.POLICE_ID and dx <= _horn_close_m and lv - float(e["speed"]) >= _horn_close_kmh \
				and _horn_wait <= 0.0 and _rng.randf() < _horn_close:
			_queue_horn(s, vid, str(e.get("set", "")), heavy, 1)
	_prev_rel = seen


func _whoosh(slot: int, vid: int, heavy: bool, own_kmh: float, rel_kmh: float, dx: float, side: float) -> void:
	var id := "whoosh_truck" if heavy else "whoosh_car"
	var e := ctx.assets.entry(FOLDER, id) if ctx.assets != null else null
	if e == null:
		return
	var target := float(_wh_lufs["heavy" if heavy else "car"]) + _wh_slope * log(own_kmh / _wh_ref_kmh) / log(10.0) \
		- 20.0 * log(maxf(dx, 1.0) / _wh_ref_m) / log(10.0)
	if target < _wh_floor:
		return
	var variant := RoadAudio.pick_variant(_rng, e.files.size(), int(_fx_last.get(id, -1)))
	_fx_last[id] = variant
	var pitch := clampf(sqrt(rel_kmh / _wh_rel_ref_kmh), 0.8, 1.25)
	var db := target - _lufs_m(e, variant) - _ref_path_db
	whooshes_played += 1
	_play_fx("whoosh", id, variant, db, side * 0.6, pitch, [])
	last_fx["slot"] = slot
	last_fx["vehicle"] = vid


func _queue_horn(slot: int, vid: int, set_id: String, heavy: bool, variant: int) -> void:
	_horn_wait = _horn_cooldown
	var model_name := TrafficAudio.model_of(set_id)
	var kind := "truck" if heavy else ("small" if model_name == "hatch" else "car")
	_pending.append({"t": _rng.randf_range(_horn_delay.x, _horn_delay.y), "slot": slot, "vehicle": vid, "kind": kind,
		"variant": variant})


func _step_pending(dt: float) -> void:
	var keep: Array[Dictionary] = []
	for p in _pending:
		p["t"] = float(p["t"]) - dt
		if float(p["t"]) > 0.0:
			keep.append(p)
			continue
		var s := int(p["slot"])
		var v: TrafficAudio.Voice = model.voices[s] if s < model.voices.size() else null
		if v == null or v.vehicle != int(p["vehicle"]):
			continue                     # the vehicle is gone: no horn out of nowhere
		var kind := str(p["kind"])
		var id := "horn_truck" if kind == "truck" else ("horn_small" if kind == "small" else "horn_car")
		var e := ctx.assets.entry(FOLDER, id) if ctx.assets != null else null
		if e == null:
			continue
		var variant := clampi(int(p["variant"]), 0, e.files.size() - 1)
		var target := float(_horn_lufs.get(kind, -24.0)) - 20.0 * log(maxf(v.distance, 1.0) / _horn_ref_m) / log(10.0)
		var db := target - _lufs_m(e, variant) - _ref_path_db
		horns_played += 1
		_play_fx("horn", id, variant, db, v.pan, clampf(v.doppler, 0.5, 2.0), [s, v.vehicle])
	_pending = keep


func _play_fx(kind: String, id: String, variant: int, db: float, pan: float, pitch: float, follow: Array) -> void:
	last_fx = {"kind": kind, "id": id, "variant": variant, "db": db, "pan": pan, "pitch": pitch}
	if _fx.is_empty():
		return
	var i := _fx_next
	_fx_next = (_fx_next + 1) % _fx.size()
	var pl := _fx[i]
	_fx_follow[i] = follow
	if pl == null:
		return
	pl.stream = ctx.assets.stream(FOLDER, id, variant)
	pl.pitch_scale = pitch
	pl.set_meta("gain", db_to_linear(db))
	ModernAudioPan.apply(pl, db_to_linear(db), pan)
	pl.play()


## Horns follow their vehicle's side while they sound.
func _follow() -> void:
	for i in _fx.size():
		var f: Array = _fx_follow[i]
		var pl := _fx[i]
		if f.is_empty() or pl == null or not pl.playing:
			continue
		var s := int(f[0])
		if s < model.voices.size() and model.voices[s].vehicle == int(f[1]):
			ModernAudioPan.apply(pl, float(pl.get_meta("gain", 1.0)), model.voices[s].pan)


func event(event_name: String, args: Dictionary) -> void:
	if event_name != "collision" or _horn_wait > 0.0 or _rng.randf() >= _horn_after_collision:
		return
	# the vehicle the player hit: the nearest voice within 15 m (the session does not name it)
	var best := -1
	var best_d := 15.0
	for s in model.voices.size():
		var v := model.voices[s]
		if v.vehicle == TrafficAudio.NONE or v.vehicle == TrafficAudio.POLICE_ID or v.releasing:
			continue
		if v.distance < best_d:
			best_d = v.distance
			best = s
	if best < 0:
		return
	var idx := model.slot_index(best)
	var set_id := ""
	var heavy := bool(args.get("heavy", false))
	if idx >= 0 and idx < _frame_vehicles.size():
		set_id = str((_frame_vehicles[idx] as Dictionary).get("set", ""))
		heavy = bool((_frame_vehicles[idx] as Dictionary).get("heavy", heavy))
	_queue_horn(best, model.voices[best].vehicle, set_id, heavy, 0)


static func _lufs_m(e: ModernAudioAssets.Entry, variant: int) -> float:
	var m: Variant = e.meta.get("lufs_m", null)
	if m is Array and variant < (m as Array).size():
		return float(m[variant])
	return e.lufs


## Voices of the last frame, listener and siren (TrafficAudio.state()).
func state() -> Dictionary:
	return model.state() if model != null else {}


## GDScript time of the traffic voices per frame: {avg_ms, max_ms, frames, apply_avg_ms, apply_max_ms}.
func perf() -> Dictionary:
	if model == null or model.perf_calls == 0:
		return {"avg_ms": 0.0, "max_ms": 0.0, "frames": 0, "apply_avg_ms": 0.0, "apply_max_ms": 0.0}
	return {"avg_ms": model.perf_us_sum / 1000.0 / model.perf_calls, "max_ms": model.perf_us_max / 1000.0,
		"frames": model.perf_calls, "apply_avg_ms": model.perf_apply_us_sum / 1000.0 / model.perf_calls,
		"apply_max_ms": model.perf_apply_us_max / 1000.0}


func stop_all() -> void:
	model.reset()
	_prev_rel.clear()
	_pending.clear()
	for p in _fx:
		if p != null:
			p.stop()


func teardown() -> void:
	for p in _fx:
		ModernAudioPan.free_player(p)
	_fx.clear()
	if model != null:
		model.detach()


func debug_state() -> Dictionary:
	var voices := 0
	if model != null:
		for v in model.voices:
			if v.vehicle != TrafficAudio.NONE:
				voices += 1
	return {"ok": model != null and model.ok, "voices": voices, "slots": model.voices.size() if model != null else 0,
		"siren": model.siren.fade if model != null else 0.0, "modern": modern_sounds, "wet": model.wet if model != null else false,
		"horns": horns_played, "whooshes": whooshes_played}
