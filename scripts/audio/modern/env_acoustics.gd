class_name EnvAcoustics
extends ModernAudioModule
## Slot "env" of the Modern sound (package AU-C2; contract D25–D29; docs/audio-modern.md "Welt, Ambiente, Verkehr"):
## the acoustics of the surroundings on the bus MEnv – everything of the car, the impacts and the other road users
## passes it (MCar, MImpact, MWorld → MEnv). ModernBuses creates the two effects in one path (dry + early
## reflections: AudioEffectDelay with two taps and its feedback line; reverb: AudioEffectReverb, dry 1); this slot
## sets their parameters from a preset per zone:
##
##   open     two faint early reflections (embankments, a guardrail), barely a tail
##   forest   denser, closer reflections and a short, dark diffuse tail (trunks and leaves scatter)
##   valley   faint reflections, a slap echo from the slopes (the delay's feedback line: one repeat every echo_ms,
##            low-passed) and a longer, sparse tail
##   cutting  rock walls on both sides: strong reflections left and right, short tail
##   city     facades: later, strong reflections, a medium tail (street canyon)
##   bridge   open space under and around the deck: the faintest reflections
##   tunnel   strong, close reflections and the long, dense tube reverberation
##   cover    a canopy (fuel station, border post): close reflections from the roof, a short tail
## Snow absorbs (audio.modern.env.snow: quieter reflections, less and darker reverberation).
##
## The zone comes from frame.feed (AudioFeed.zone, cover) – the tunnel from frame.tunnel, the camera in a tunnel (the
## picture's view; the car is some metres ahead), as in Arcade. Without a track the car is in the open.
## Parameters move smoothly towards their preset (fade_s; into and out of a tunnel tunnel_fade_s). Godot applies the
## delay's tap times, its feedback time and the reverb's predelay without a ramp – a jump of the read position, a
## click while sound passes (read in the engine source, docs "Fallen") – so tap and echo times change only while
## their line is silent: the taps fade out (tap_switch_s), take their new times and fade in again. Levels, room,
## damping and wet change block by block, in small steps (smoothed here every frame). The pans of the taps follow
## Godot's law (left · (1 − p), right · (1 + p)): the level is compensated by 1 + p² so a wider pan keeps its energy.
## The predelay of the reverb is one value for all zones (audio.modern.env.predelay_ms) and never changes.
##
## Width of the car (docs/motorsound.md 6.9: the engine v3 is dry; Kompakt, Kombi and Limousine sit in the centre):
## the reflections reach the two ears at different times (tap times differ per side), which decorrelates the car
## a little in every zone; nothing is added on the car's own bus.

const PRESET_KEYS: Array[String] = ["tap_db", "tap_pan", "echo_db", "room", "damp", "wet", "hipass", "pre_fb"]
const SILENT_DB := -70.0

## Fallback presets (the configuration audio.modern.env.presets replaces single values).
const PRESETS := {
	"open": {"taps_ms": [17.0, 23.0], "tap_db": -19.0, "tap_pan": 0.3, "echo_ms": 0.0, "echo_db": -70.0,
		"room": 0.3, "damp": 0.6, "wet": 0.02, "hipass": 0.05, "pre_fb": 0.0},
	"forest": {"taps_ms": [13.0, 21.0], "tap_db": -15.0, "tap_pan": 0.4, "echo_ms": 0.0, "echo_db": -70.0,
		"room": 0.45, "damp": 0.75, "wet": 0.06, "hipass": 0.05, "pre_fb": 0.0},
	"valley": {"taps_ms": [19.0, 29.0], "tap_db": -18.0, "tap_pan": 0.3, "echo_ms": 380.0, "echo_db": -21.0,
		"room": 0.6, "damp": 0.65, "wet": 0.04, "hipass": 0.06, "pre_fb": 0.0},
	"cutting": {"taps_ms": [27.0, 41.0], "tap_db": -10.0, "tap_pan": 0.6, "echo_ms": 0.0, "echo_db": -70.0,
		"room": 0.4, "damp": 0.45, "wet": 0.06, "hipass": 0.05, "pre_fb": 0.0},
	"city": {"taps_ms": [47.0, 71.0], "tap_db": -12.0, "tap_pan": 0.55, "echo_ms": 0.0, "echo_db": -70.0,
		"room": 0.55, "damp": 0.5, "wet": 0.09, "hipass": 0.05, "pre_fb": 0.0},
	"bridge": {"taps_ms": [17.0, 23.0], "tap_db": -23.0, "tap_pan": 0.2, "echo_ms": 0.0, "echo_db": -70.0,
		"room": 0.25, "damp": 0.65, "wet": 0.015, "hipass": 0.06, "pre_fb": 0.0},
	"tunnel": {"taps_ms": [11.0, 16.0], "tap_db": -7.0, "tap_pan": 0.5, "echo_ms": 0.0, "echo_db": -70.0,
		"room": 0.86, "damp": 0.4, "wet": 0.3, "hipass": 0.03, "pre_fb": 0.2},
	"cover": {"taps_ms": [9.0, 13.0], "tap_db": -9.0, "tap_pan": 0.4, "echo_ms": 0.0, "echo_db": -70.0,
		"room": 0.4, "damp": 0.5, "wet": 0.11, "hipass": 0.04, "pre_fb": 0.0},
}

var presets: Dictionary = {}
var fade_s := 0.7
var tunnel_fade_s := 0.35
var tap_switch_s := 0.08
var echo_lp_hz := 1800.0
var predelay_ms := 18.0
var snow_tap_db := -4.0
var snow_wet_k := 0.6
var snow_damp_add := 0.2

var zone := "open"                 ## the preset in use
var target: Dictionary = {}        ## the preset values the parameters move to (snow applied)
var current: Dictionary = {}       ## smoothed values (tap_db, tap_pan, echo_db, room, damp, wet, hipass, pre_fb)
var taps_ms := Vector2(17.0, 23.0) ## tap times in use
var echo_ms := 0.0                 ## feedback time in use (0 = none)
var tap_gate := 1.0                ## 0..1: taps faded out for a change of their times
var echo_gate := 1.0
var tap_switches := 0              ## changes of the tap times (tests)
var echo_switches := 0
var snow := 0.0

var _tap_phase := 0                ## 0 steady, 1 fading out for new times, 2 fading in
var _echo_phase := 0
var _outside_zone := "open"        ## the last zone outside a tunnel (the car may be in a tunnel before the camera)
var _fade_override := 0.0          ## > 0: the time constant of the current change (into or out of a tunnel)
var _applied: Dictionary = {}


func _setup() -> void:
	fade_s = maxf(ctx.number("env.fade_s", fade_s), 0.02)
	tunnel_fade_s = maxf(ctx.number("env.tunnel_fade_s", tunnel_fade_s), 0.02)
	tap_switch_s = maxf(ctx.number("env.tap_switch_s", tap_switch_s), 0.01)
	echo_lp_hz = ctx.number("env.echo_lowpass_hz", echo_lp_hz)
	predelay_ms = clampf(ctx.number("env.predelay_ms", predelay_ms), 0.0, 400.0)
	snow_tap_db = ctx.number("env.snow.tap_db", snow_tap_db)
	snow_wet_k = clampf(ctx.number("env.snow.wet_k", snow_wet_k), 0.0, 1.0)
	snow_damp_add = clampf(ctx.number("env.snow.damp_add", snow_damp_add), 0.0, 1.0)
	presets = {}
	var over: Variant = ctx.value("env.presets", {})
	for z: String in PRESETS:
		var p: Dictionary = (PRESETS[z] as Dictionary).duplicate(true)
		if over is Dictionary and (over as Dictionary).get(z, null) is Dictionary:
			for k: String in (over as Dictionary)[z]:
				p[k] = (over as Dictionary)[z][k]
		presets[z] = p
	_set_zone("open")
	_snap()
	var rev: AudioEffectReverb = ctx.buses.reverb() if ctx.buses != null else null
	if rev != null:
		rev.spread = 1.0
		rev.predelay_msec = predelay_ms
	var refl: AudioEffectDelay = ctx.buses.reflections() if ctx.buses != null else null
	if refl != null:
		refl.feedback_lowpass = echo_lp_hz
	_apply(true)


## Preset name for this frame: the camera in a tunnel wins; a canopy over the car; else the feed's zone (a tunnel the
## camera has not reached yet keeps the zone outside).
func zone_of(frame: ModernAudioFrame) -> String:
	if frame.tunnel:
		return "tunnel"
	var f := frame.feed
	if f == null or not f.valid:
		return "open"
	if f.cover != "":
		return "cover"
	if f.zone == "tunnel":
		return _outside_zone
	return f.zone if presets.has(f.zone) else "open"


func update(frame: ModernAudioFrame) -> void:
	var z := zone_of(frame)
	if z != "tunnel" and z != "cover":
		_outside_zone = z
	var s := 0.0
	if frame.feed != null and frame.feed.valid and not frame.tunnel:
		s = clampf(frame.feed.snow, 0.0, 1.0)
	if z != zone or absf(s - snow) > 0.001:
		var into_tunnel := (z == "tunnel") != (zone == "tunnel")
		snow = s
		_set_zone(z)
		if into_tunnel:
			_fade_override = tunnel_fade_s
	_step(frame.dt)
	_apply(false)


func _set_zone(z: String) -> void:
	zone = z
	var p: Dictionary = presets.get(z, presets["open"])
	target = {}
	for k in PRESET_KEYS:
		target[k] = float(p.get(k, (PRESETS["open"] as Dictionary)[k]))
	target["tap_db"] = float(target["tap_db"]) + snow_tap_db * snow
	target["echo_db"] = float(target["echo_db"]) + snow_tap_db * snow
	target["wet"] = float(target["wet"]) * lerpf(1.0, snow_wet_k, snow)
	target["damp"] = clampf(float(target["damp"]) + snow_damp_add * snow, 0.0, 1.0)
	var t: Array = p.get("taps_ms", [17.0, 23.0])
	target["taps"] = Vector2(float(t[0]), float(t[1]))
	target["echo_ms"] = float(p.get("echo_ms", 0.0))


## Everything at its target at once (setup, stop_all).
func _snap() -> void:
	for k in PRESET_KEYS:
		current[k] = float(target[k])
	taps_ms = target["taps"]
	echo_ms = float(target["echo_ms"])
	tap_gate = 1.0
	echo_gate = 1.0
	_tap_phase = 0
	_echo_phase = 0
	_fade_override = 0.0


func _step(dt: float) -> void:
	var tau := _fade_override if _fade_override > 0.0 else fade_s
	var k := 1.0 - exp(-dt / maxf(tau, 0.001))
	for key in PRESET_KEYS:
		current[key] = lerpf(float(current[key]), float(target[key]), k)
	if _fade_override > 0.0 and absf(float(current["wet"]) - float(target["wet"])) < 0.002:
		_fade_override = 0.0
	# tap times: fade out, switch, fade in
	var want: Vector2 = target["taps"]
	var g_step := dt / tap_switch_s
	match _tap_phase:
		0:
			if absf(want.x - taps_ms.x) > 0.5 or absf(want.y - taps_ms.y) > 0.5:
				_tap_phase = 1
		1:
			tap_gate = maxf(tap_gate - g_step, 0.0)
			if tap_gate <= 0.0:
				taps_ms = want
				tap_switches += 1
				_tap_phase = 2
		2:
			tap_gate = minf(tap_gate + g_step * 0.5, 1.0)
			if tap_gate >= 1.0:
				_tap_phase = 0
	var want_echo := float(target["echo_ms"])
	match _echo_phase:
		0:
			if absf(want_echo - echo_ms) > 0.5:
				_echo_phase = 1
		1:
			echo_gate = maxf(echo_gate - g_step, 0.0)
			if echo_gate <= 0.0:
				echo_ms = want_echo
				echo_switches += 1
				_echo_phase = 2
		2:
			echo_gate = minf(echo_gate + g_step * 0.5, 1.0)
			if echo_gate >= 1.0:
				_echo_phase = 0


## Level of the taps in dB as Godot gets it: the preset level, the pan compensation and the switching gate.
func tap_level_db() -> float:
	var p := float(current["tap_pan"])
	var db := float(current["tap_db"]) - 10.0 * log(1.0 + p * p) / log(10.0)
	return maxf(db + linear_to_db(maxf(tap_gate, 1.0e-4)), SILENT_DB)


func echo_level_db() -> float:
	if echo_ms <= 0.0:
		return SILENT_DB
	return maxf(float(current["echo_db"]) + linear_to_db(maxf(echo_gate, 1.0e-4)), SILENT_DB)


func _apply(force: bool) -> void:
	if ctx == null or ctx.buses == null:
		return
	var refl := ctx.buses.reflections()
	var rev := ctx.buses.reverb()
	if refl == null or rev == null:
		return
	var tl := tap_level_db()
	var pan := clampf(float(current["tap_pan"]), 0.0, 1.0)
	_put(refl, "tap1_delay_ms", taps_ms.x, 0.01, force)
	_put(refl, "tap2_delay_ms", taps_ms.y, 0.01, force)
	_put(refl, "tap1_level_db", tl, 0.01, force)
	_put(refl, "tap2_level_db", tl, 0.01, force)
	_put(refl, "tap1_pan", -pan, 0.001, force)
	_put(refl, "tap2_pan", pan, 0.001, force)
	var el := echo_level_db()
	var on := el > SILENT_DB + 0.5 and echo_ms > 0.0
	if on != bool(_applied.get("fb_on", not on)) or force:
		refl.feedback_active = on
		_applied["fb_on"] = on
	if on:
		_put(refl, "feedback_delay_ms", echo_ms, 0.01, force)
		_put(refl, "feedback_level_db", el, 0.01, force)
	_put(rev, "room_size", float(current["room"]), 0.0005, force)
	_put(rev, "damping", float(current["damp"]), 0.0005, force)
	_put(rev, "wet", float(current["wet"]), 0.0005, force)
	_put(rev, "hipass", float(current["hipass"]), 0.0005, force)
	_put(rev, "predelay_feedback", float(current["pre_fb"]), 0.0005, force)


func _put(fx: Object, prop: String, v: float, eps: float, force: bool) -> void:
	var key := str(fx.get_instance_id()) + prop
	if force or absf(float(_applied.get(key, 1.0e9)) - v) > eps:
		fx.set(prop, v)
		_applied[key] = v


func stop_all() -> void:
	_outside_zone = "open"
	snow = 0.0
	_set_zone("open")
	_snap()
	_apply(true)


## 0 outdoors … 1 in a tunnel (the share of the tunnel's wet in the current reverberation; tools and tests).
func blend() -> float:
	var w0 := float((presets["open"] as Dictionary)["wet"])
	var w1 := float((presets["tunnel"] as Dictionary)["wet"])
	return clampf((float(current.get("wet", w0)) - w0) / maxf(w1 - w0, 1.0e-6), 0.0, 1.0)


func debug_state() -> Dictionary:
	return {"zone": zone, "blend": blend(), "reflections_db": tap_level_db(), "wet": float(current.get("wet", 0.0)),
		"room": float(current.get("room", 0.0)), "taps_ms": [taps_ms.x, taps_ms.y], "echo_ms": echo_ms,
		"echo_db": echo_level_db(), "tap_switches": tap_switches, "snow": snow}
