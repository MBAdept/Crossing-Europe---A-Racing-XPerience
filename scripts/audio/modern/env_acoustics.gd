class_name EnvAcoustics
extends ModernAudioModule
## Slot "env" of the Modern sound: the acoustics of the surroundings on the bus MEnv (dry + early reflections +
## reverb in one path – ModernBuses creates the two effects, this slot sets their parameters).
##
## Stand-in of wave 0 (package AU-C2 replaces it with zone presets – open, forest, cutting, city, tunnel, underpass,
## valley echo, snow – driven by frame.feed.zone): today's room sound. The Arcade RoomAudio is used as the model
## only (its configuration audio.reverb_* / audio.reflections_*, its tunnel blend and params()), never attached:
## early reflections of two taps and the tunnel reverb that fades in while the camera is in a tunnel.
## Overrides for Modern: audio.modern.env.<same key as in audio> (e.g. "reverb_tunnel_wet").

var model: RoomAudio = null
var _applied := Vector2(-1000.0, -1.0)


func _setup() -> void:
	var cfg := ctx.cfg
	var over: Variant = ctx.value("env", {})
	if over is Dictionary and not (over as Dictionary).is_empty():
		cfg = cfg.duplicate(true)
		var audio: Dictionary = cfg.get("audio", {})
		for k: String in over:
			if not k.begins_with("_"):
				audio[k] = (over as Dictionary)[k]
		cfg["audio"] = audio
	model = RoomAudio.new()
	model.setup(cfg)
	var refl: AudioEffectDelay = ctx.buses.reflections() if ctx.buses != null else null
	if refl != null:
		refl.tap1_delay_ms = RoomAudio.REFLECTION_MS.x
		refl.tap1_pan = -RoomAudio.REFLECTION_PAN
		refl.tap2_delay_ms = RoomAudio.REFLECTION_MS.y
		refl.tap2_pan = RoomAudio.REFLECTION_PAN
	var rev: AudioEffectReverb = ctx.buses.reverb() if ctx.buses != null else null
	if rev != null:
		rev.room_size = model.room_size
		rev.damping = model.damping
		rev.spread = 1.0
		rev.hipass = model.hipass
		rev.predelay_msec = model.predelay_ms
		rev.predelay_feedback = model.predelay_feedback
	_apply()


func update(frame: ModernAudioFrame) -> void:
	model.update(frame.dt, frame.tunnel)
	_apply()


func stop_all() -> void:
	model.reset()
	_apply()


## 0 outdoors … 1 in a tunnel.
func blend() -> float:
	return model.blend if model != null else 0.0


func _apply() -> void:
	if ctx.buses == null or ctx.buses.reflections() == null:
		return
	var p := model.params(model.blend)
	var r := float(p["reflections_db"])
	var w := float(p["wet"])
	if absf(r - _applied.x) > 0.01:
		ctx.buses.reflections().tap1_level_db = r
		ctx.buses.reflections().tap2_level_db = r
		_applied.x = r
	if absf(w - _applied.y) > 0.0005:
		ctx.buses.reverb().wet = w
		_applied.y = w


func debug_state() -> Dictionary:
	return {"blend": blend(), "reflections_db": _applied.x, "wet": _applied.y}
