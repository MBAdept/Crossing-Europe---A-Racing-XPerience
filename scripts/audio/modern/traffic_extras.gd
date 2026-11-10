class_name TrafficExtras
extends ModernAudioModule
## Slot "traffic" of the Modern sound: the other road users – pass-by voices on the buses MTrafficV0 … MTrafficV7 and
## the police siren on MSiren (→ MWorld → MEnv; package AU-C2: own sounds from assets/audio/modern/traffic, horns,
## close-pass whooshes, siren styles). ModernAudio expects, beyond the hooks of ModernAudioModule:
##   state() -> Dictionary   AudioManager.traffic_state() (voices of the last frame, listener, siren)
##   perf()  -> Dictionary   AudioManager.traffic_perf()
## Inputs every frame: frame.vehicles / frame.listener / frame.traffic_alive (set_traffic), frame.siren_level.
##
## Stand-in of wave 0: the Arcade model unchanged (TrafficAudio: voice assignment, distance, pan, Doppler, air
## absorption) with eight voices, playing the Arcade traffic sounds the AudioManager has loaded and its siren. Only
## the output differs: a subclass sends the same players to the Modern voice buses instead of TrafficV<n> / Siren –
## the Arcade buses are not touched. Configuration: the Arcade keys audio.traffic_* / audio.siren_*, overridden by
## audio.modern.traffic.<same key> (default: traffic_voices = 8).


## TrafficAudio on the Modern buses (which exist with their low-pass filters – ModernBuses).
class ModernTraffic:
	extends TrafficAudio

	var buses: ModernBuses = null

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


var model: ModernTraffic = null


func _setup() -> void:
	var cfg := ctx.cfg.duplicate(true)
	var audio: Dictionary = cfg.get("audio", {})
	audio["traffic_voices"] = ModernBuses.TRAFFIC_VOICES
	var over: Variant = ctx.value("traffic", {})
	if over is Dictionary:
		for k: String in over:
			if not k.begins_with("_"):
				audio[k] = (over as Dictionary)[k]
	audio["traffic_voices"] = clampi(int(audio.get("traffic_voices", ModernBuses.TRAFFIC_VOICES)), 0, ModernBuses.TRAFFIC_VOICES)
	cfg["audio"] = audio
	model = ModernTraffic.new()
	model.buses = ctx.buses
	model.setup(cfg)
	var src := ctx.arcade_traffic
	if src != null and src.ok:
		# the sounds the AudioManager loaded (read only): no second copy in memory
		model.sounds = src.sounds
		model.classes = src.classes
		model.models = src.models
		model.path = src.path
		model.ok = true
	model.siren_stream = ctx.stream("traffic", "siren", "siren")
	if ctx.live and ctx.host != null:
		model.attach(ctx.host, "MWorld")


func update(frame: ModernAudioFrame) -> void:
	model.set_siren(frame.siren_level > 0.0, frame.siren_level)
	model.update(frame.dt, frame.vehicles if frame.traffic_alive else [], frame.listener, frame.traffic_alive)
	model.apply()


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


func teardown() -> void:
	if model != null:
		model.detach()


func debug_state() -> Dictionary:
	var voices := 0
	if model != null:
		for v in model.voices:
			if v.vehicle != TrafficAudio.NONE:
				voices += 1
	return {"ok": model != null and model.ok, "voices": voices, "slots": model.voices.size() if model != null else 0,
		"siren": model.siren.fade if model != null else 0.0}
