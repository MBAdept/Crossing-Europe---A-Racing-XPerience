class_name RoomAudio
extends RefCounted
## Room sound (contract docs/verkehrsgeraeusche.md §2): two buses between the sources and SFX.
##
##   Engine (→ Room)  the player's engine (EngineAudio pushes mono frames): a short, diffuse stereo reverb
##                    (AudioEffectReverb, small room, spread 1, wet audio.engine_width) decorrelates the channels –
##                    a wider image that stays centred. Its input is high-passed (audio.engine_width_hipass, 0..1 =
##                    0..6 kHz): the few strong low harmonics stay mono, so they cannot tip the balance; above, many
##                    partials average out. (Fixed left/right delay taps would comb-filter the harmonic engine
##                    differently per channel and pull it to one side, depending on the rpm: measured +1.7 dB.)
##   Room (→ SFX)     engine, traffic voices and siren: early reflections (AudioEffectDelay, two taps slightly left
##                    and right, audio.reflections_db outdoors, audio.reflections_tunnel_db in tunnels) and a long,
##                    dense tunnel reverb (AudioEffectReverb, wet audio.reverb_wet outdoors … audio.reverb_tunnel_wet).
##
## The tunnel state (camera in a tunnel, AudioManager.set_environment) moves `blend` linearly within
## audio.reverb_fade_s; params(blend) maps it (smoothstep) to the effect parameters. update()/params() are pure apart
## from writing the effect objects created by attach() – tests use them without the AudioServer.

const ROOM_BUS := "Room"
const ENGINE_BUS := "Engine"
const REFLECTION_MS := Vector2(17.0, 23.0)   ## early reflections: left, right tap
const REFLECTION_PAN := 0.15                 ## taps only slightly to the sides: the centred engine stays centred
## engine width: short diffuse room (Freeverb: room_size, damping, predelay ms); its high-pass is a setting
const WIDTH_ROOM := Vector3(0.1, 0.7, 3.0)

var blend := 0.0                 ## 0 outdoors … 1 in a tunnel
var tunnel := false
# configuration (audio.*)
var fade_s := 0.8
var reflections_db := -16.0
var reflections_tunnel_db := -8.0
var wet := 0.0
var tunnel_wet := 0.3
var room_size := 0.86
var damping := 0.45
var predelay_ms := 22.0
var predelay_feedback := 0.3
var hipass := 0.03
var engine_width := 0.6
var engine_width_hipass := 0.1

var _refl: AudioEffectDelay = null
var _reverb: AudioEffectReverb = null
var _width: AudioEffectReverb = null
var _applied := Vector2(-1000.0, -1.0)


func setup(cfg: Dictionary) -> void:
	fade_s = maxf(float(ConfigLoader.lookup(cfg, "audio.reverb_fade_s", 0.8)), 0.01)
	reflections_db = float(ConfigLoader.lookup(cfg, "audio.reflections_db", -16.0))
	reflections_tunnel_db = float(ConfigLoader.lookup(cfg, "audio.reflections_tunnel_db", -8.0))
	wet = clampf(float(ConfigLoader.lookup(cfg, "audio.reverb_wet", 0.0)), 0.0, 1.0)
	tunnel_wet = clampf(float(ConfigLoader.lookup(cfg, "audio.reverb_tunnel_wet", 0.3)), 0.0, 1.0)
	room_size = clampf(float(ConfigLoader.lookup(cfg, "audio.reverb_room_size", 0.86)), 0.0, 1.0)
	damping = clampf(float(ConfigLoader.lookup(cfg, "audio.reverb_damping", 0.45)), 0.0, 1.0)
	predelay_ms = clampf(float(ConfigLoader.lookup(cfg, "audio.reverb_predelay_ms", 22.0)), 0.0, 500.0)
	predelay_feedback = clampf(float(ConfigLoader.lookup(cfg, "audio.reverb_predelay_feedback", 0.3)), 0.0, 0.98)
	hipass = clampf(float(ConfigLoader.lookup(cfg, "audio.reverb_hipass", 0.03)), 0.0, 1.0)
	engine_width = clampf(float(ConfigLoader.lookup(cfg, "audio.engine_width", 0.6)), 0.0, 1.0)
	engine_width_hipass = clampf(float(ConfigLoader.lookup(cfg, "audio.engine_width_hipass", 0.1)), 0.0, 1.0)


## Effect parameters for a tunnel blend 0..1: {reflections_db, wet}.
func params(b: float) -> Dictionary:
	var s := smoothstep(0.0, 1.0, clampf(b, 0.0, 1.0))
	return {"reflections_db": lerpf(reflections_db, reflections_tunnel_db, s), "wet": lerpf(wet, tunnel_wet, s)}


## One frame: the blend follows the tunnel state within fade_s; the effects get the new parameters.
func update(dt: float, in_tunnel: bool) -> void:
	tunnel = in_tunnel
	blend = move_toward(blend, 1.0 if in_tunnel else 0.0, dt / fade_s)
	_apply()


## Outdoors at once (new race, scene change).
func reset() -> void:
	tunnel = false
	blend = 0.0
	_apply()


## Creates (or reuses) the buses and their effects: Room after `send_bus`, Engine after Room (sends must go to a
## bus with a lower index).
func attach(send_bus: String) -> void:
	var room := _bus(ROOM_BUS, send_bus)
	_refl = _effect(room, "AudioEffectDelay") as AudioEffectDelay
	_refl.dry = 1.0
	_refl.tap1_active = true
	_refl.tap1_delay_ms = REFLECTION_MS.x
	_refl.tap1_pan = -REFLECTION_PAN
	_refl.tap2_active = true
	_refl.tap2_delay_ms = REFLECTION_MS.y
	_refl.tap2_pan = REFLECTION_PAN
	_refl.feedback_active = false
	_reverb = _effect(room, "AudioEffectReverb") as AudioEffectReverb
	_reverb.dry = 1.0
	_reverb.room_size = room_size
	_reverb.damping = damping
	_reverb.spread = 1.0
	_reverb.hipass = hipass
	_reverb.predelay_msec = predelay_ms
	_reverb.predelay_feedback = predelay_feedback
	var eng := _bus(ENGINE_BUS, ROOM_BUS)
	_width = _effect(eng, "AudioEffectReverb") as AudioEffectReverb
	_width.dry = 1.0
	_width.wet = engine_width
	_width.room_size = WIDTH_ROOM.x
	_width.damping = WIDTH_ROOM.y
	_width.hipass = engine_width_hipass
	_width.predelay_msec = WIDTH_ROOM.z
	_width.predelay_feedback = 0.0
	_width.spread = 1.0
	_applied = Vector2(-1000.0, -1.0)
	_apply()


func _apply() -> void:
	if _refl == null:
		return
	var p := params(blend)
	var r := float(p["reflections_db"])
	var w := float(p["wet"])
	if absf(r - _applied.x) > 0.01:
		_refl.tap1_level_db = r
		_refl.tap2_level_db = r
		_applied.x = r
	if absf(w - _applied.y) > 0.0005:
		_reverb.wet = w
		_applied.y = w


static func _bus(bus_name: String, send_bus: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send_bus)
	return idx


## The bus's first effect of that class (created and appended when missing).
static func _effect(idx: int, cls: String) -> AudioEffect:
	for j in AudioServer.get_bus_effect_count(idx):
		var fx := AudioServer.get_bus_effect(idx, j)
		if fx.get_class() == cls:
			return fx
	var e: AudioEffect = ClassDB.instantiate(cls)
	AudioServer.add_bus_effect(idx, e)
	return e
