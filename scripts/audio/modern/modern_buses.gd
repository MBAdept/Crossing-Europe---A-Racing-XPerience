class_name ModernBuses
extends RefCounted
## Audio buses of the sound profile "Modern" (contract §4.7.3, docs/audio-modern.md "Busse"). ModernAudio builds them
## when the profile starts and removes them when it ends; the Arcade buses (Master, SFX, Music, Room, Engine,
## TrafficV<n>, Siren) and their effects are never touched – only the limiter on Master is shared.
##
##   Master
##   └─ MMaster                 glue compressor (audio.modern.glue)
##      ├─ MMusic               music: EQ of the race context (shelves), pause low-pass, fader (ducking, dips)
##      └─ MSfx                 effects group: volume setting "Effekte", level of the plan
##         ├─ MUI               menu and countdown sounds, stingers
##         ├─ MEnv              surroundings: dry + early reflections + reverb (one path – a bus has one send)
##         │  ├─ MCar           the player's car; its level steers the ducking of the music
##         │  │  ├─ MEngine     engine (generator)
##         │  │  ├─ MEngineFx   turbo, driveline, exhaust clips
##         │  │  ├─ MRoad       tyres, rumble strip, joints
##         │  │  └─ MWind       wind
##         │  ├─ MImpact        collisions, guardrail
##         │  └─ MWorld         other road users
##         │     ├─ MTrafficV0 … MTrafficV7   one bus per voice (low-pass = air absorption)
##         │     └─ MSiren
##         └─ MAmb              ambience beds (carry their own space)
##
## Index order matters: a bus can only send to a bus with a lower index (the engine silently sends to Master
## otherwise), so the buses are appended in the order of GRAPH – a group before its members. This is not the order
## in which §4.7.3 lists the names (MEnv is last there).
##
## Levels: the static level of a bus (plan + volume setting) is its volume; everything that moves while sound
## plays (ducking, snapshot dips) goes through an AudioEffectAmplify "fader" on the bus. Reason, measured (Godot
## 4.7.2, 100 Hz sine, −6 dB): a bus volume change is applied at a mix-block boundary without a ramp (step 15–33×
## the signal's own steepness = a click), AudioEffectAmplify ramps across the block (1.0–1.5×).
##
## Race EQ of the music (audio.modern.music.race_eq): shelving filters in series – not AudioEffectEQ6/10/21. Those
## sum band-passes and are not neutral: with every band at 0 dB the EQ10 raises the signal by 1.4 to 3.3 dB (ripple
## from band to band), the EQ21 by about 3.9 dB, the EQ6 by 0.5 to 2.6 dB (measured from impulse responses, Godot
## 4.7.2). A shelving filter is exact: 0 dB outside the shelf, and the square of its "gain" inside (measured: gain
## 0.841 → −3.01 dB, 1.122 → +2.00 dB; half of it at the cutoff, the transition spans about an octave to each side)
## – with the filter's default slope setting and resonance 0.5 (other slope settings change the gain of the shelf).

const MASTER := "Master"
const TRAFFIC_VOICES := 8
const TRAFFIC_PREFIX := "MTrafficV"
const LOWPASS_OFF_HZ := 20000.0   ## cutoff at and above which a snapshot low-pass is switched off
const PEAK_FLOOR_DB := -200.0

## [name, send] in index order (the eight traffic voice buses are inserted at "MTrafficV*").
const GRAPH: Array = [
	["MMaster", MASTER], ["MMusic", "MMaster"], ["MSfx", "MMaster"], ["MUI", "MSfx"], ["MEnv", "MSfx"],
	["MCar", "MEnv"], ["MEngine", "MCar"], ["MEngineFx", "MCar"], ["MRoad", "MCar"], ["MWind", "MCar"],
	["MImpact", "MEnv"], ["MWorld", "MEnv"], ["MTrafficV*", "MWorld"], ["MSiren", "MWorld"], ["MAmb", "MSfx"],
]
## Buses with a fader (AudioEffectAmplify, the last effect) for scripted gains.
const FADER_BUSES: Array[String] = ["MMusic", "MEnv", "MCar", "MWorld", "MAmb"]
## Buses with a low-pass for snapshots (pause): disabled while not needed.
const LOWPASS_BUSES: Array[String] = ["MMusic", "MEnv", "MAmb"]

var built := false
var _faders: Dictionary = {}      ## bus -> AudioEffectAmplify
var _lowpass: Dictionary = {}     ## bus -> AudioEffectLowPassFilter
var _gain_db: Dictionary = {}     ## bus -> last fader value
var _lp_hz: Dictionary = {}       ## bus -> last cutoff (LOWPASS_OFF_HZ = off)
var _music_eq: Array[AudioEffectFilter] = []   ## shelving filters of the race EQ on MMusic
var _music_eq_db: Array[float] = []            ## the gain of each shelf in dB when fully on
var _music_eq_amount := 0.0                    ## 0 = off (filters disabled) … 1 = the full shelves
var _glue: AudioEffectCompressor = null
var _reflections: AudioEffectDelay = null
var _reverb: AudioEffectReverb = null


## Every Modern bus name in index order.
static func names() -> PackedStringArray:
	var out := PackedStringArray()
	for e: Array in GRAPH:
		var n := str(e[0])
		if n == "MTrafficV*":
			for i in TRAFFIC_VOICES:
				out.append(TRAFFIC_PREFIX + str(i))
		else:
			out.append(n)
	return out


## Send target of a Modern bus ("" for an unknown name).
static func send_of(bus: String) -> String:
	if bus.begins_with(TRAFFIC_PREFIX):
		return "MWorld"
	for e: Array in GRAPH:
		if str(e[0]) == bus:
			return str(e[1])
	return ""


## Nominal ratio for Godot's AudioEffectCompressor that gives the wanted effective ratio. The effect multiplies the
## overshoot by 2.0814 before applying (ratio − 1) / ratio – measured: threshold −12 dB, ratio 2, a sine at −6 / −3 /
## 0 dBFS leaves at −11.1 / −11.0 / −11.0 dBFS (a limiter, not 2:1).
static func compressor_ratio(effective: float) -> float:
	var want := (1.0 - 1.0 / maxf(effective, 1.0)) / 2.08136898
	return clampf(1.0 / maxf(1.0 - want, 0.021), 1.0, 48.0)


## Value of the "gain" property of Godot's shelving filters for a shelf of `db` decibels (its square is the gain).
static func shelf_gain(db: float) -> float:
	return clampf(pow(10.0, db / 40.0), 0.05, 4.0)


## A neutral shelving filter (gain 1) for an entry of audio.modern.music.race_eq – {"shelf": "low" | "high", "hz":
## cutoff, "db": gain of the shelf}; null for an entry that would do nothing.
static func shelf_filter(spec: Dictionary) -> AudioEffectFilter:
	var hz := float(spec.get("hz", 0.0))
	if hz <= 0.0 or absf(float(spec.get("db", 0.0))) < 0.01:
		return null
	var f: AudioEffectFilter
	if str(spec.get("shelf", "low")) == "high":
		f = AudioEffectHighShelfFilter.new()
	else:
		f = AudioEffectLowShelfFilter.new()
	f.cutoff_hz = clampf(hz, 20.0, 20000.0)
	f.resonance = 0.5
	f.db = AudioEffectFilter.FILTER_6DB
	f.gain = 1.0
	return f


## Creates the buses (appended after every existing bus), their sends and base effects. `modern` = audio.modern.
## Does nothing when this object built them already.
func build(modern: Dictionary = {}) -> void:
	if built:
		return
	remove()   # buses a crashed run or another object left behind: start clean, in the right order
	for n in names():
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, n)
		AudioServer.set_bus_send(idx, send_of(n))
	built = true
	# MMaster: glue compressor
	var glue: Dictionary = _dict(modern.get("glue", {}))
	_glue = AudioEffectCompressor.new()
	_glue.threshold = float(glue.get("threshold_db", -9.0))
	_glue.ratio = compressor_ratio(float(glue.get("ratio", 2.0)))
	_glue.attack_us = maxf(float(glue.get("attack_ms", 30.0)), 0.02) * 1000.0
	_glue.release_ms = maxf(float(glue.get("release_ms", 300.0)), 20.0)
	_glue.gain = float(glue.get("gain_db", 0.0))
	_glue.mix = 1.0
	AudioServer.add_bus_effect(index("MMaster"), _glue)
	AudioServer.set_bus_effect_enabled(index("MMaster"), 0, bool(glue.get("enabled", true)))
	# MMusic: EQ of the race context (off outside races) – shelving filters in series
	var eq: Variant = _dict(modern.get("music", {})).get("race_eq", [])
	var mi := index("MMusic")
	for spec: Variant in (eq if eq is Array else []):
		var sh := shelf_filter(_dict(spec))
		if sh == null:
			continue
		AudioServer.add_bus_effect(mi, sh)
		AudioServer.set_bus_effect_enabled(mi, AudioServer.get_bus_effect_count(mi) - 1, false)
		_music_eq.append(sh)
		_music_eq_db.append(float(_dict(spec).get("db", 0.0)))
	_music_eq_amount = 0.0
	# MEnv: dry + early reflections + reverb (parameters: slot EnvAcoustics)
	_reflections = AudioEffectDelay.new()
	_reflections.dry = 1.0
	_reflections.tap1_active = true
	_reflections.tap2_active = true
	_reflections.tap1_level_db = -60.0
	_reflections.tap2_level_db = -60.0
	_reflections.feedback_active = false
	AudioServer.add_bus_effect(index("MEnv"), _reflections)
	_reverb = AudioEffectReverb.new()
	_reverb.dry = 1.0
	_reverb.wet = 0.0
	AudioServer.add_bus_effect(index("MEnv"), _reverb)
	# snapshot low-passes (off) and faders (0 dB), in this order at the end of the chain
	for n in LOWPASS_BUSES:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = LOWPASS_OFF_HZ   # slope: the effect's default (one biquad stage, 12 dB per octave)
		var idx := index(n)
		AudioServer.add_bus_effect(idx, lp)
		AudioServer.set_bus_effect_enabled(idx, AudioServer.get_bus_effect_count(idx) - 1, false)
		_lowpass[n] = lp
		_lp_hz[n] = LOWPASS_OFF_HZ
	for n in FADER_BUSES:
		var amp := AudioEffectAmplify.new()
		amp.volume_db = 0.0
		AudioServer.add_bus_effect(index(n), amp)
		_faders[n] = amp
		_gain_db[n] = 0.0
	# traffic voices and the siren: low-pass of the air absorption (parameters: slot TrafficExtras)
	for i in TRAFFIC_VOICES + 1:
		var n := (TRAFFIC_PREFIX + str(i)) if i < TRAFFIC_VOICES else "MSiren"
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = LOWPASS_OFF_HZ
		AudioServer.add_bus_effect(index(n), lp)


## Removes every Modern bus (from the highest index down; the effects go with them).
func remove() -> void:
	var list := names()
	for i in range(list.size() - 1, -1, -1):
		var idx := AudioServer.get_bus_index(list[i])
		if idx > 0:
			AudioServer.remove_bus(idx)
	built = false
	_faders.clear()
	_lowpass.clear()
	_gain_db.clear()
	_lp_hz.clear()
	_music_eq.clear()
	_music_eq_db.clear()
	_music_eq_amount = 0.0
	_glue = null
	_reflections = null
	_reverb = null


## Bus index (−1 = missing).
func index(bus: String) -> int:
	return AudioServer.get_bus_index(bus)


## Static level of a bus: plan level + volume setting, and its mute state. Not for values that move while sound
## plays (set_gain_db).
func set_static_db(bus: String, db: float, mute: bool = false) -> void:
	var idx := index(bus)
	if idx < 0:
		return
	if absf(AudioServer.get_bus_volume_db(idx) - db) > 0.001:
		AudioServer.set_bus_volume_db(idx, db)
	if AudioServer.is_bus_mute(idx) != mute:
		AudioServer.set_bus_mute(idx, mute)


func set_mute(bus: String, mute: bool) -> void:
	var idx := index(bus)
	if idx >= 0 and AudioServer.is_bus_mute(idx) != mute:
		AudioServer.set_bus_mute(idx, mute)


## Scripted gain of a fader bus in dB (ramped by the effect across the next mix block).
func set_gain_db(bus: String, db: float) -> void:
	var amp: AudioEffectAmplify = _faders.get(bus)
	if amp == null or absf(float(_gain_db[bus]) - db) < 0.005:
		return
	_gain_db[bus] = db
	amp.volume_db = clampf(db, -80.0, 24.0)


func gain_db(bus: String) -> float:
	return float(_gain_db.get(bus, 0.0))


## Snapshot low-pass of a bus: a cutoff at or above LOWPASS_OFF_HZ (or 0) switches the filter off.
func set_lowpass_hz(bus: String, hz: float) -> void:
	var lp: AudioEffectLowPassFilter = _lowpass.get(bus)
	if lp == null:
		return
	var cut := LOWPASS_OFF_HZ if (hz <= 0.0 or hz >= LOWPASS_OFF_HZ) else maxf(hz, 60.0)
	var last := float(_lp_hz[bus])
	if absf(cut - last) < 1.0:
		return
	_lp_hz[bus] = cut
	lp.cutoff_hz = cut
	if (cut >= LOWPASS_OFF_HZ) != (last >= LOWPASS_OFF_HZ):
		var idx := index(bus)
		for j in AudioServer.get_bus_effect_count(idx):
			if AudioServer.get_bus_effect(idx, j) == lp:
				AudioServer.set_bus_effect_enabled(idx, j, cut < LOWPASS_OFF_HZ)


func lowpass_hz(bus: String) -> float:
	return float(_lp_hz.get(bus, LOWPASS_OFF_HZ))


## Race EQ of the music bus: 0 = off (its filters are disabled), 1 = the full shelves, between them a share of
## their dB (ModernAudio glides the amount, so switching the context does not step the level of the music).
func set_music_eq_amount(amount: float) -> void:
	var a := clampf(amount, 0.0, 1.0)
	if not built or a == _music_eq_amount:
		return
	var was_on := _music_eq_amount > 0.0
	_music_eq_amount = a
	for i in _music_eq.size():
		_music_eq[i].gain = shelf_gain(_music_eq_db[i] * a)
	if was_on != (a > 0.0):
		var idx := index("MMusic")
		for j in AudioServer.get_bus_effect_count(idx):
			if _is_eq(AudioServer.get_bus_effect(idx, j)):
				AudioServer.set_bus_effect_enabled(idx, j, a > 0.0)


## Race EQ fully on or off at once.
func set_music_eq(on: bool) -> void:
	set_music_eq_amount(1.0 if on else 0.0)


func music_eq_on() -> bool:
	return _music_eq_amount > 0.0


func music_eq_amount() -> float:
	return _music_eq_amount


## The shelving filters of the race EQ, in the order of audio.modern.music.race_eq.
func music_eq() -> Array[AudioEffectFilter]:
	return _music_eq


## The two effects of the environment path on MEnv (parameters belong to the slot EnvAcoustics).
func reflections() -> AudioEffectDelay:
	return _reflections


func reverb() -> AudioEffectReverb:
	return _reverb


func glue() -> AudioEffectCompressor:
	return _glue


## The first effect of that class on a bus; created in front of the snapshot low-pass / fader when missing
## (effects a slot owns, e.g. the stereo width of a mono engine). null for a missing bus. Never one of the effects
## this object owns (fader, snapshot low-pass, race EQ).
func effect(bus: String, cls: String, create: bool = true) -> AudioEffect:
	var idx := index(bus)
	if idx < 0:
		return null
	for j in AudioServer.get_bus_effect_count(idx):
		var fx := AudioServer.get_bus_effect(idx, j)
		if fx.get_class() == cls and fx != _faders.get(bus) and fx != _lowpass.get(bus) and not _is_eq(fx):
			return fx
	if not create or not ClassDB.can_instantiate(cls):
		return null
	var e: AudioEffect = ClassDB.instantiate(cls)
	var at := AudioServer.get_bus_effect_count(idx)
	for j in AudioServer.get_bus_effect_count(idx):
		var fx := AudioServer.get_bus_effect(idx, j)
		if fx == _faders.get(bus) or fx == _lowpass.get(bus):
			at = j
			break
	AudioServer.add_bus_effect(idx, e, at)
	return e


## Low-pass of a traffic voice bus (index 0…TRAFFIC_VOICES−1) or of the siren bus (index TRAFFIC_VOICES).
func voice_filter(i: int) -> AudioEffectLowPassFilter:
	var idx := index((TRAFFIC_PREFIX + str(i)) if i < TRAFFIC_VOICES else "MSiren")
	if idx < 0:
		return null
	for j in AudioServer.get_bus_effect_count(idx):
		var fx := AudioServer.get_bus_effect(idx, j)
		if fx is AudioEffectLowPassFilter:
			return fx
	return null


## Peak level of a bus in the last mix block (dBFS, after its effects and its volume; PEAK_FLOOR_DB when silent).
func peak_db(bus: String) -> float:
	var idx := index(bus)
	if idx < 0:
		return PEAK_FLOOR_DB
	var m := PEAK_FLOOR_DB
	for ch in AudioServer.get_bus_channels(idx):
		m = maxf(m, maxf(AudioServer.get_bus_peak_volume_left_db(idx, ch), AudioServer.get_bus_peak_volume_right_db(idx, ch)))
	return m


## Static gain in dB from a bus to the Master input: the bus volumes along its sends (faders not included).
func path_db(bus: String) -> float:
	var db := 0.0
	var n := bus
	var guard := 0
	while n != "" and n != MASTER and guard < 16:
		var idx := index(n)
		if idx < 0:
			break
		db += AudioServer.get_bus_volume_db(idx)
		n = str(AudioServer.get_bus_send(idx))
		guard += 1
	return db


## Problems of the graph as it is in the AudioServer (empty = fine): missing buses, wrong sends, a send to a bus
## that does not have a lower index.
func verify() -> Array[String]:
	var out: Array[String] = []
	for n in names():
		var idx := index(n)
		if idx < 0:
			out.append("Bus %s fehlt" % n)
			continue
		var send := str(AudioServer.get_bus_send(idx))
		if send != send_of(n):
			out.append("Bus %s sendet an %s statt %s" % [n, send, send_of(n)])
		var sidx := AudioServer.get_bus_index(send)
		if sidx < 0 or sidx >= idx:
			out.append("Bus %s (Index %d) sendet an %s (Index %d): das Ziel braucht einen kleineren Index" % [n, idx, send, sidx])
	return out


## fx is one of the shelving filters of the race EQ.
func _is_eq(fx: AudioEffect) -> bool:
	return fx is AudioEffectFilter and _music_eq.has(fx)


static func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}
