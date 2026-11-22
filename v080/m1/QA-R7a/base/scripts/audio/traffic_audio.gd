class_name TrafficAudio
extends RefCounted
## Pass-by sounds of the traffic and the spatial police siren (contract docs/verkehrsgeraeusche.md §2).
##
## Data: traffic_sounds.json (format ce-traffic-sounds-1, §1): mono loops per layer (engine, tires, air), classes
## (engine variants, tyre and air sound, source size) and the model → class map (sprite id traffic/<model>_<colour>,
## police/<country> → police, unknown → car). Godot imports the WAVs; load_sounds() switches their loop on.
##
## Model (pure – unit tests call update() and read `voices`/`siren`, no AudioServer):
##   listener  chase camera + traffic_listener_ahead_m along the road. x across, z along the road in metres; the
##             road scrolls with the real speed, so km/h / 3.6 = m/s. Curves are neglected.
##   source    the vehicle axis from rear to front. Distance and direction go to the point of that segment nearest
##             to the listener (a long truck stays "beside" while it is beside), the Doppler shift to its centre.
##   level     traffic_db + gain_db + level_db_per_decade · log10(v / ref_kmh) + distance: (ref / max(d, ref))^n
##             with ref = traffic_ref_m · size, n = traffic_rolloff (engine, tyres) or 2 (air: the "whoosh" is
##             only heard close by), faded out between 70 % and 100 % of traffic_max_m.
##   pan       constant power from sin(azimuth) · traffic_pan (front and back are the same in stereo).
##   pitch     clamp((v / ref_kmh)^pitch_exp, 0.6, 1.6) · Doppler · spread (±6 %, fixed per vehicle id).
##   Doppler   c / (c − k · v_approach) with v_approach = −d|p|/dt from the relative velocity along the road,
##             k = traffic_doppler, |k · v_approach| ≤ c / 2; smoothed over DOPPLER_TAU.
##   air       low-pass cutoff 20 kHz / (1 + d / traffic_air_m) (air absorption: duller with distance).
##   voices    traffic_voices slots, each engine + tyres + air of one vehicle. The nearest vehicles (trucks/buses count
##             HEAVY_RANK times nearer) get a slot; an owner keeps it until a candidate is nearer by traffic_hysteresis;
##             slots fade in and out over traffic_fade_s and a released slot is reused only once it is silent (no
##             clicks, no jumps).
##   siren     an extra slot at the police car (id −2) with its own distance law (siren_ref_m, siren_rolloff,
##             at least siren_floor while on) and Doppler; without the police car in the list it plays centred at
##             the level given to set_siren() (the old mono behaviour).
## Output (attach/apply): AudioStreamPlayer2D voices in an own SubViewport world with an AudioListener2D – Godot pans
## them with per-channel gains that it ramps over every mix step (click-free); each slot has its own bus with a
## low-pass (air absorption) that sends to the room bus.

const FORMAT := "ce-traffic-sounds-1"
const LAYERS: Array[String] = ["engine", "tires", "air"]
const SPEED_OF_SOUND := 343.0
const POLICE_ID := -2            ## vehicle id of the police car (race session, renderer)
const NONE := -2147483647        ## slot without a vehicle
const PITCH_MIN := 0.6
const PITCH_MAX := 1.6
const SPREAD := 0.06             ## per-vehicle random pitch ±6 %
const AIR_ROLLOFF := 2.0
const FAR_FADE := 0.7            ## the distance fade starts at this fraction of max_m
const MIN_KMH := 5.0             ## speeds below count as this (level/pitch of standing vehicles)
const LONGEST_M := 30.0          ## longest vehicle body (cheap window test before the exact distance)
const HEAVY_RANK := 1.45         ## voice ranking: trucks/buses (flag "heavy") count as this much nearer (√ size)
const CUTOFF_MAX := 20000.0
const CUTOFF_MIN := 800.0
const DOPPLER_TAU := 0.08        ## s, smoothing of the Doppler factor (speed jitter must not warble)
const SIREN_TAU := 0.15          ## s, smoothing of the siren gains (switch between centred and spatial)
const PAN_PX := 64.0             ## output: half width of the 2D listener world (pan ±1 = ±PAN_PX)
const BUS_PREFIX := "TrafficV"
const SIREN_BUS := "Siren"


class Sound:
	var name := ""
	var file := ""
	var layer := ""
	var ref_kmh := 100.0
	var pitch_exp := 1.0
	var gain_db := 0.0
	var db_per_decade := 0.0
	var stream: AudioStream = null


class VClass:
	var name := ""
	var engines: Array[String] = []
	var tires := ""
	var air := ""
	var size := 1.0


## One voice slot: engine + tyres + air of one vehicle (the siren slot uses layer 0 only). Gains are final
## (fade, level, distance and pan applied), per layer and channel.
class Voice:
	var vehicle := NONE
	var cls := ""
	var sounds: Array[String] = ["", "", ""]
	var fade := 0.0
	var releasing := false
	var gen := 0                 ## counts vehicles assigned to this slot (output restarts its players)
	var gl := PackedFloat32Array([0.0, 0.0, 0.0])
	var gr := PackedFloat32Array([0.0, 0.0, 0.0])
	var pitch := PackedFloat32Array([1.0, 1.0, 1.0])
	var offset := PackedFloat32Array([0.0, 0.0, 0.0])   ## start position in the loop (0..1)
	var cutoff := CUTOFF_MAX
	var distance := INF
	var pan := 0.0
	var doppler := 1.0
	var spread := 1.0
	var amp := PackedFloat32Array([0.0, 0.0, 0.0])      ## level · distance per layer (before pan and fade)


var ok := false                  ## sounds loaded and usable
var errors: Array[String] = []
var warnings: Array[String] = []
var path := ""
var sounds: Dictionary = {}      ## name -> Sound
var classes: Dictionary = {}     ## name -> VClass
var models: Dictionary = {}      ## model -> class name
var voices: Array[Voice] = []
var siren := Voice.new()
var siren_stream: AudioStream = null

# configuration (audio.*)
var voice_count := 6
var level_db := -4.0
var doppler_k := 2.0
var ref_m := 3.0
var max_m := 150.0
var rolloff := 1.0
var air_m := 30.0
var pan_width := 0.85
var ahead_m := 3.0
var hysteresis := 0.25
var fade_s := 0.3
var siren_db := -1.9
var siren_ref_m := 30.0
var siren_max_m := 900.0
var siren_rolloff := 0.6
var siren_floor := 0.3
var siren_fade_s := 0.35

## Listener of the last update (x, z incl. the ahead offset, speed in m/s) – for tests and tools.
var listener_x := 0.0
var listener_z := 0.0
var listener_v := 0.0
## GDScript time of update() + apply() in microseconds (perf_us_*), of apply() alone (perf_apply_us_*).
var perf_calls := 0
var perf_us_sum := 0
var perf_us_max := 0
var perf_apply_us_sum := 0
var perf_apply_us_max := 0
var _update_us := 0

var _class_cache: Dictionary = {}
var _class_cache_heavy: Dictionary = {}
var _owner: Dictionary = {}      ## vehicle id -> slot index
var _slot_idx := PackedInt32Array()   ## per slot: index of its vehicle in this frame's list (-1 = not there)
var _cand_i := PackedInt32Array()
var _cand_p := PackedFloat32Array()
var _siren_on := false
var _siren_level := 0.0
var _police_idx := -1

# output
var _vp: SubViewport = null
var _players: Array = []         ## per slot: Array of AudioStreamPlayer2D (3 traffic layers, 1 for the siren)
var _filters: Array = []         ## per slot: AudioEffectLowPassFilter
var _gens := PackedInt32Array()
var _last_db: Array = []         ## per slot: PackedFloat32Array of applied volume_db
var _last_cut := PackedFloat32Array()


func _init() -> void:
	_resize_voices()


## Reads the audio.* configuration (docs/ui.md "Audio").
func setup(cfg: Dictionary) -> void:
	voice_count = clampi(int(ConfigLoader.lookup(cfg, "audio.traffic_voices", 6)), 0, 16)
	level_db = float(ConfigLoader.lookup(cfg, "audio.traffic_db", -4.0))
	doppler_k = maxf(float(ConfigLoader.lookup(cfg, "audio.traffic_doppler", 2.0)), 0.0)
	ref_m = maxf(float(ConfigLoader.lookup(cfg, "audio.traffic_ref_m", 3.0)), 0.5)
	max_m = maxf(float(ConfigLoader.lookup(cfg, "audio.traffic_max_m", 150.0)), ref_m * 2.0)
	rolloff = clampf(float(ConfigLoader.lookup(cfg, "audio.traffic_rolloff", 1.0)), 0.2, 3.0)
	air_m = maxf(float(ConfigLoader.lookup(cfg, "audio.traffic_air_m", 30.0)), 1.0)
	pan_width = clampf(float(ConfigLoader.lookup(cfg, "audio.traffic_pan", 0.85)), 0.0, 1.0)
	ahead_m = float(ConfigLoader.lookup(cfg, "audio.traffic_listener_ahead_m", 3.0))
	hysteresis = clampf(float(ConfigLoader.lookup(cfg, "audio.traffic_hysteresis", 0.25)), 0.0, 0.9)
	fade_s = maxf(float(ConfigLoader.lookup(cfg, "audio.traffic_fade_s", 0.3)), 0.02)
	siren_db = float(ConfigLoader.lookup(cfg, "audio.siren_db", -1.9))
	siren_ref_m = maxf(float(ConfigLoader.lookup(cfg, "audio.siren_ref_m", 30.0)), 1.0)
	siren_max_m = maxf(float(ConfigLoader.lookup(cfg, "audio.siren_max_m", 900.0)), siren_ref_m * 2.0)
	siren_rolloff = clampf(float(ConfigLoader.lookup(cfg, "audio.siren_rolloff", 0.6)), 0.1, 3.0)
	siren_floor = clampf(float(ConfigLoader.lookup(cfg, "audio.siren_floor", 0.3)), 0.0, 1.0)
	_resize_voices()


func _resize_voices() -> void:
	while voices.size() < voice_count:
		voices.append(Voice.new())
	while voices.size() > voice_count:
		voices.pop_back()


# --- data ------------------------------------------------------------------------------------------

## Loads traffic_sounds.json and (with_streams) its WAVs, enabling the loop of each. Returns ok. errors = unusable
## (no traffic sound), warnings = deviations the runtime tolerates (e.g. a class with a missing sound is dropped).
func load_sounds(json_path: String, with_streams: bool = true) -> bool:
	path = json_path
	ok = false
	errors.clear()
	warnings.clear()
	sounds.clear()
	classes.clear()
	models.clear()
	_class_cache.clear()
	_class_cache_heavy.clear()
	_owner.clear()
	for v in voices:
		v.vehicle = NONE
		v.fade = 0.0
	if not FileAccess.file_exists(json_path):
		errors.append("Datei fehlt: %s" % json_path)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not parsed is Dictionary:
		errors.append("kein gültiges JSON: %s" % json_path)
		return false
	var d: Dictionary = parsed
	if str(d.get("format", "")) != FORMAT:
		errors.append("Format \"%s\" statt \"%s\"" % [str(d.get("format", "")), FORMAT])
		return false
	var dir := json_path.get_base_dir()
	var sd: Variant = d.get("sounds", {})
	if not sd is Dictionary:
		errors.append("\"sounds\" fehlt")
		return false
	for sname: String in (sd as Dictionary):
		var e: Variant = sd[sname]
		if not e is Dictionary:
			warnings.append("Klang %s: kein Objekt" % sname)
			continue
		var s := Sound.new()
		s.name = sname
		s.file = str(e.get("file", ""))
		s.layer = str(e.get("layer", ""))
		s.ref_kmh = float(e.get("ref_kmh", 100.0))
		s.pitch_exp = float(e.get("pitch_exp", 1.0))
		s.gain_db = float(e.get("gain_db", 0.0))
		s.db_per_decade = float(e.get("level_db_per_decade", 0.0))
		if not LAYERS.has(s.layer):
			warnings.append("Klang %s: unbekannte Ebene \"%s\"" % [sname, s.layer])
			continue
		if s.ref_kmh <= 0.0 or s.file == "":
			warnings.append("Klang %s: ref_kmh/file ungültig" % sname)
			continue
		if with_streams:
			s.stream = _load_loop(dir.path_join(s.file))
			if s.stream == null:
				warnings.append("Klang %s: %s nicht ladbar" % [sname, s.file])
				continue
		sounds[sname] = s
	var cd: Variant = d.get("classes", {})
	if cd is Dictionary:
		for cname: String in (cd as Dictionary):
			var c := _parse_class(cname, cd[cname])
			if c != null:
				classes[cname] = c
	var md: Variant = d.get("models", {})
	if md is Dictionary:
		for m: String in (md as Dictionary):
			if classes.has(str(md[m])):
				models[m] = str(md[m])
			else:
				warnings.append("Modell %s: Klasse \"%s\" fehlt" % [m, str(md[m])])
	if not classes.has("car"):
		errors.append("Klasse \"car\" (Rückfall für unbekannte Modelle) fehlt oder ist unvollständig")
	ok = errors.is_empty()
	return ok


func _parse_class(cname: String, e: Variant) -> VClass:
	if not e is Dictionary:
		warnings.append("Klasse %s: kein Objekt" % cname)
		return null
	var c := VClass.new()
	c.name = cname
	var eng: Variant = e.get("engine", [])
	if eng is String:
		eng = [eng]
	if eng is Array:
		for n: Variant in eng:
			if _has_sound(str(n), "engine"):
				c.engines.append(str(n))
	c.tires = str(e.get("tires", ""))
	c.air = str(e.get("air", ""))
	c.size = clampf(float(e.get("size", 1.0)), 0.3, 5.0)
	if c.engines.is_empty() or not _has_sound(c.tires, "tires") or not _has_sound(c.air, "air"):
		warnings.append("Klasse %s: Klang fehlt (engine %s, tires %s, air %s)" % [cname, str(eng), c.tires, c.air])
		return null
	return c


func _has_sound(sname: String, layer: String) -> bool:
	return sounds.has(sname) and (sounds[sname] as Sound).layer == layer


## Imported WAV with its loop switched on (forward over the whole sample). A duplicate without a path: the cached
## resource stays unchanged, and a loop still playing when the game quits is not reported as a resource in use.
static func _load_loop(wav_path: String) -> AudioStream:
	if not ResourceLoader.exists(wav_path):
		return null
	var s: Variant = load(wav_path)
	if s is AudioStreamWAV:
		var w: AudioStreamWAV = (s as AudioStreamWAV).duplicate()
		var frames := int(round(w.get_length() * float(w.mix_rate)))
		if frames <= 1:
			return null
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = frames
		return w
	if s is AudioStream:
		return s
	return null


## Model of a sprite set id: traffic/<model>_<colour> -> model, police/<country> -> "police", else the name
## without a colour suffix and trailing digits (fixture/car17 -> "car").
static func model_of(set_id: String) -> String:
	if set_id.begins_with("police/") or set_id.begins_with("fixture/police"):
		return "police"
	var n := set_id.get_slice("/", 1) if set_id.contains("/") else set_id
	n = n.get_slice("_", 0)
	while n.length() > 0 and n.unicode_at(n.length() - 1) >= 48 and n.unicode_at(n.length() - 1) <= 57:
		n = n.left(n.length() - 1)
	return n


## Class of a vehicle entry: models map of the model, heavy vehicles of unknown models count as truck, else car.
func class_of(set_id: String, heavy: bool = false) -> String:
	var cache := _class_cache_heavy if heavy else _class_cache
	var hit: Variant = cache.get(set_id)
	if hit != null:
		return hit
	var m := model_of(set_id)
	var c := "car"
	if models.has(m):
		c = models[m]
	elif classes.has(m):
		c = m
	elif heavy and classes.has("truck"):
		c = "truck"
	if not classes.has(c):
		c = "car"
	cache[set_id] = c
	return c


# --- pure maths ------------------------------------------------------------------------------------

## Constant-power stereo gains (left, right) for pan -1 (left) … +1 (right); centre = (0.707, 0.707).
static func pan_gains(pan: float) -> Vector2:
	var a := (clampf(pan, -1.0, 1.0) + 1.0) * PI * 0.25
	return Vector2(cos(a), sin(a))


## Distance attenuation 0..1: 1 within ref_m, then (ref / d)^rolloff, faded to 0 between FAR_FADE · max_m and max_m.
static func distance_gain(d: float, p_ref_m: float, p_max_m: float, p_rolloff: float) -> float:
	if d >= p_max_m:
		return 0.0
	var g := pow(p_ref_m / maxf(d, p_ref_m), p_rolloff)
	return g * (1.0 - smoothstep(FAR_FADE * p_max_m, p_max_m, d))


## Doppler factor of a source at rel_pos (source − listener, x across / y along the road, m) moving with rel_vel
## (source − listener velocity, m/s): c / (c − k · v_approach), |k · v_approach| ≤ c / 2.
static func doppler_factor(rel_pos: Vector2, rel_vel: Vector2, k: float) -> float:
	var d := rel_pos.length()
	if d < 1.0e-4:
		return 1.0
	var approach := -rel_pos.dot(rel_vel) / d
	var a := clampf(k * approach, -0.5 * SPEED_OF_SOUND, 0.5 * SPEED_OF_SOUND)
	return SPEED_OF_SOUND / (SPEED_OF_SOUND - a)


## Low-pass cutoff (Hz) of the air absorption at distance d.
static func air_cutoff_hz(d: float, p_air_m: float) -> float:
	return clampf(CUTOFF_MAX / (1.0 + maxf(d, 0.0) / p_air_m), CUTOFF_MIN, CUTOFF_MAX)


## Playback pitch from the vehicle speed: (v / ref)^exp within 0.6..1.6.
static func speed_pitch(speed_kmh: float, ref_kmh: float, pitch_exp: float) -> float:
	return clampf(pow(maxf(speed_kmh, MIN_KMH) / ref_kmh, pitch_exp), PITCH_MIN, PITCH_MAX)


## Level change (dB) from the vehicle speed: db_per_decade · log10(v / ref).
static func speed_level_db(speed_kmh: float, ref_kmh: float, db_per_decade: float) -> float:
	if db_per_decade == 0.0:
		return 0.0
	return db_per_decade * log(maxf(speed_kmh, MIN_KMH) / ref_kmh) / log(10.0)


## Deterministic random number 0..1 of a vehicle id (and a salt for independent values).
static func id_random(id: int, salt: int = 0) -> float:
	var h := (id * 2654435761 + salt * 40503 + 12345) & 0x7fffffff
	h = (((h >> 15) ^ h) * 2246822519) & 0x7fffffff
	h = (((h >> 13) ^ h) * 3266489917) & 0x7fffffff
	h = (h >> 16) ^ h
	return float(h & 0xffffff) / 16777216.0


## Pitch spread of a vehicle: 1 ± SPREAD, fixed per id.
static func spread_of(id: int) -> float:
	return 1.0 + SPREAD * (2.0 * id_random(id, 11) - 1.0)


# --- per frame ------------------------------------------------------------------------------------

## Police siren: on/off and its level 0..1 when it plays centred (no police car in the vehicle list).
func set_siren(on: bool, level01: float) -> void:
	_siren_on = on
	_siren_level = clampf(level01, 0.0, 1.0)


## One frame. vehicles: [{id, set, z (rear, m), x (m), length (m), speed (km/h), heavy?}] (the renderer's car
## list; the police car has id −2); listener: {z, x, speed (km/h)} of the chase camera. alive = false (pause,
## scene left, no calls) fades everything out.
## One pass over the list: the police car's index, the owners' indices and the candidates within max_m (a cheap test
## of z against the window first – most vehicles of the traffic window are far away). Required keys: id, z, x, length,
## speed, set; heavy is optional.
func update(dt: float, vehicles: Array, listener: Dictionary, alive: bool = true) -> void:
	var t0 := Time.get_ticks_usec()
	listener_x = float(listener.get("x", 0.0))
	listener_z = float(listener.get("z", 0.0)) + ahead_m
	listener_v = float(listener.get("speed", 0.0)) / 3.6
	_police_idx = -1
	var n_slots := voices.size()
	_slot_idx.resize(n_slots)
	_slot_idx.fill(-1)
	_cand_i.clear()
	_cand_p.clear()
	var scan := ok and n_slots > 0 and alive
	var z_lo := listener_z - max_m - LONGEST_M
	var z_hi := listener_z + max_m
	var keep := 1.0 - hysteresis
	for i in vehicles.size():
		var e: Dictionary = vehicles[i]
		var vid: int = e["id"]
		if vid == POLICE_ID:
			_police_idx = i
		if not scan:
			continue
		var zr: float = e["z"]
		if zr > z_hi or zr < z_lo:
			continue
		var ln: float = e["length"]
		var ex: float = e["x"]
		var dz := clampf(listener_z, zr, zr + ln) - listener_z
		var dx := ex - listener_x
		var d := sqrt(dx * dx + dz * dz)
		if not (d < max_m):          # also NaN
			continue
		var prio := d / HEAVY_RANK if e.get("heavy", false) else d
		var slot: int = _owner.get(vid, -1)
		if slot >= 0:
			prio *= keep
			_slot_idx[slot] = i
		_cand_i.append(i)
		_cand_p.append(prio)
	if ok and n_slots > 0:
		_assign(vehicles)
		var k_fade := dt / fade_s
		var k_dop := 1.0 - exp(-dt / DOPPLER_TAU)
		for s in n_slots:
			var v := voices[s]
			if v.vehicle == NONE:
				continue
			var idx := _slot_idx[s]
			if idx < 0:
				v.releasing = true      # gone or out of reach: fade out with the last values
			else:
				_spatial(v, vehicles[idx], k_dop)
			v.fade = clampf(v.fade + (-k_fade if (v.releasing or not alive) else k_fade), 0.0, 1.0)
			_finish_gains(v)
			if v.fade <= 0.0 and (v.releasing or not alive):
				_owner.erase(v.vehicle)
				v.vehicle = NONE
				v.releasing = false
				v.distance = INF
	_update_siren(dt, vehicles)
	var us := Time.get_ticks_usec() - t0
	_update_us = us
	perf_calls += 1
	perf_us_sum += us
	perf_us_max = maxi(perf_us_max, us)


## Voice assignment with hysteresis: of the candidates (distance, heavy / HEAVY_RANK, owners × (1 − hysteresis)) the best
## voice_count keep or get a slot; owners not among them are released (fade out), newcomers take a silent slot or wait.
func _assign(vehicles: Array) -> void:
	var n := _cand_i.size()
	var chosen := PackedInt32Array()
	if n <= voices.size():
		chosen = _cand_i
	else:
		var taken := PackedByteArray()
		taken.resize(n)
		for _k in voices.size():
			var best := -1
			for j in n:
				if taken[j] == 0 and (best < 0 or _cand_p[j] < _cand_p[best]):
					best = j
			taken[best] = 1
			chosen.append(_cand_i[best])
	var chosen_ids: Dictionary = {}
	for i in chosen:
		chosen_ids[int((vehicles[i] as Dictionary).get("id", 0))] = i
	for v in voices:
		if v.vehicle != NONE:
			v.releasing = not chosen_ids.has(v.vehicle)
	for vid: int in chosen_ids:
		if _owner.has(vid):
			continue
		for s in voices.size():
			if voices[s].vehicle == NONE:
				_start_voice(voices[s], vehicles[chosen_ids[vid]])
				_owner[vid] = s
				_slot_idx[s] = chosen_ids[vid]
				break


func _start_voice(v: Voice, e: Dictionary) -> void:
	var vid := int(e.get("id", 0))
	v.vehicle = vid
	v.cls = class_of(str(e.get("set", "")), bool(e.get("heavy", false)))
	var c: VClass = classes[v.cls]
	v.sounds[0] = c.engines[int(id_random(vid, 23) * c.engines.size()) % c.engines.size()]
	v.sounds[1] = c.tires
	v.sounds[2] = c.air
	for k in 3:
		v.offset[k] = id_random(vid, 31 + k)
	v.spread = spread_of(vid)
	v.fade = 0.0
	v.releasing = false
	v.doppler = -1.0             # first _spatial() sets it without smoothing
	v.gen += 1


## Geometry, level, pan, pitch and air absorption of a slot's vehicle (gains before the fade in v.amp).
func _spatial(v: Voice, e: Dictionary, k_dop: float) -> void:
	var c: VClass = classes[v.cls]
	var sp: float = e["speed"]
	var speed := maxf(sp, 0.0)
	var geo := _geometry(e, speed)
	var d := geo.x
	v.distance = d
	v.pan = geo.y * pan_width
	var dop := geo.z
	v.doppler = dop if v.doppler < 0.0 else lerpf(v.doppler, dop, k_dop)
	v.cutoff = air_cutoff_hz(d, air_m)
	var ref := ref_m * c.size
	for k in 3:
		var s: Sound = sounds[v.sounds[k]]
		var lvl := level_db + s.gain_db + speed_level_db(speed, s.ref_kmh, s.db_per_decade)
		v.amp[k] = db_to_linear(lvl) * distance_gain(d, ref, max_m, AIR_ROLLOFF if k == 2 else rolloff)
		v.pitch[k] = speed_pitch(speed, s.ref_kmh, s.pitch_exp) * v.doppler * v.spread


## (distance to the nearest point of the vehicle axis, sin(azimuth) of that point, Doppler factor of the centre).
func _geometry(e: Dictionary, speed_kmh: float) -> Vector3:
	var zr: float = e["z"]
	var lv: float = e["length"]
	var ex: float = e["x"]
	var ln := maxf(lv, 0.1)
	var dx := ex - listener_x
	var dzn := clampf(listener_z, zr, zr + ln) - listener_z
	var d := maxf(sqrt(dx * dx + dzn * dzn), 0.5)
	var dop := doppler_factor(Vector2(dx, zr + ln * 0.5 - listener_z), Vector2(0.0, speed_kmh / 3.6 - listener_v), doppler_k)
	return Vector3(d, clampf(dx / d, -1.0, 1.0), dop)


func _finish_gains(v: Voice) -> void:
	var g := pan_gains(v.pan)
	for k in 3:
		var a := v.amp[k] * v.fade
		v.gl[k] = a * g.x
		v.gr[k] = a * g.y


## Siren slot: spatial at the police car when it is in the list, else centred at set_siren()'s level. On/off
## comes from set_siren() alone (the caller decides; the HUD hints keep it alive without vehicle updates).
func _update_siren(dt: float, vehicles: Array) -> void:
	var s := siren
	s.fade = clampf(s.fade + (dt if _siren_on else -dt) / siren_fade_s, 0.0, 1.0)
	var tl := 0.0
	var tr := 0.0
	if _police_idx >= 0:
		var e: Dictionary = vehicles[_police_idx]
		var speed := maxf(float(e.get("speed", 0.0)), 0.0)
		var geo := _geometry(e, speed)
		s.distance = geo.x
		s.pan = geo.y * pan_width
		s.doppler = geo.z if s.vehicle != POLICE_ID else lerpf(s.doppler, geo.z, 1.0 - exp(-dt / DOPPLER_TAU))
		s.vehicle = POLICE_ID
		s.cutoff = air_cutoff_hz(geo.x, air_m)
		var amp := db_to_linear(siren_db) * maxf(siren_floor,
			distance_gain(geo.x, siren_ref_m, siren_max_m, siren_rolloff))
		s.amp[0] = amp
		var g := pan_gains(s.pan) * sqrt(2.0)     # centre = the old mono level on both channels
		tl = amp * g.x
		tr = amp * g.y
	else:
		s.vehicle = NONE
		s.distance = INF
		s.pan = 0.0
		s.doppler = lerpf(s.doppler, 1.0, 1.0 - exp(-dt / DOPPLER_TAU))
		s.cutoff = CUTOFF_MAX
		s.amp[0] = _siren_level
		tl = _siren_level
		tr = _siren_level
	s.pitch[0] = s.doppler
	# amp[1]/amp[2] = smoothed left/right before the fade (no jump when the police car enters the list)
	if s.fade <= 0.0 or s.amp[1] + s.amp[2] <= 0.0:
		s.amp[1] = tl
		s.amp[2] = tr
	else:
		var k := 1.0 - exp(-dt / SIREN_TAU)
		s.amp[1] = lerpf(s.amp[1], tl, k)
		s.amp[2] = lerpf(s.amp[2], tr, k)
	s.gl[0] = s.amp[1] * s.fade
	s.gr[0] = s.amp[2] * s.fade


## Fades everything out at once (no output left playing): new race, scene change.
func reset() -> void:
	_owner.clear()
	for v in voices:
		v.vehicle = NONE
		v.fade = 0.0
		v.releasing = false
		v.distance = INF
		for k in 3:
			v.gl[k] = 0.0
			v.gr[k] = 0.0
	siren.fade = 0.0
	siren.gl[0] = 0.0
	siren.gr[0] = 0.0
	siren.amp[1] = 0.0
	siren.amp[2] = 0.0
	_siren_on = false
	_siren_level = 0.0
	if _vp != null:
		for ps: Array in _players:
			for p: AudioStreamPlayer2D in ps:
				if p.playing:
					p.stop()


## Debug/tests: the voices of the last frame.
func state() -> Dictionary:
	var out: Array = []
	for i in voices.size():
		var v := voices[i]
		out.append({"slot": i, "vehicle": v.vehicle, "class": v.cls, "sounds": v.sounds.duplicate(), "fade": v.fade,
			"releasing": v.releasing, "distance": v.distance, "pan": v.pan, "doppler": v.doppler, "cutoff": v.cutoff,
			"left": [v.gl[0], v.gl[1], v.gl[2]], "right": [v.gr[0], v.gr[1], v.gr[2]],
			"pitch": [v.pitch[0], v.pitch[1], v.pitch[2]]})
	return {"ok": ok, "voices": out, "listener": {"x": listener_x, "z": listener_z, "speed_ms": listener_v},
		"siren": {"on": _siren_on, "spatial": siren.vehicle == POLICE_ID, "fade": siren.fade, "distance": siren.distance,
			"pan": siren.pan, "doppler": siren.doppler, "left": siren.gl[0], "right": siren.gr[0]}}


# --- output ---------------------------------------------------------------------------------------

## Creates the voice buses (low-pass, send to `send_bus`) and the players in an own 2D listener world under
## `parent`. Call once, inside the tree.
func attach(parent: Node, send_bus: String) -> void:
	if _vp != null:
		return
	_vp = SubViewport.new()
	_vp.name = "TrafficVoices"
	_vp.size = Vector2i(int(PAN_PX), int(PAN_PX))
	_vp.audio_listener_enable_2d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	parent.add_child(_vp)
	var lis := AudioListener2D.new()
	_vp.add_child(lis)
	lis.make_current()
	var strength := float(ProjectSettings.get_setting("audio/general/2d_panning_strength", 0.5))
	var ps := clampf(1.0 / maxf(strength, 0.01), 0.0, 3.0)   # pan ±PAN_PX = full left/right
	_players.clear()
	_filters.clear()
	_last_db.clear()
	for i in voice_count + 1:
		var bus := (BUS_PREFIX + str(i)) if i < voice_count else SIREN_BUS
		_filters.append(_ensure_bus(bus, send_bus))
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


static func _ensure_bus(bus: String, send_bus: String) -> AudioEffectLowPassFilter:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus)
	AudioServer.set_bus_send(idx, send_bus)
	for j in AudioServer.get_bus_effect_count(idx):
		var fx := AudioServer.get_bus_effect(idx, j)
		if fx is AudioEffectLowPassFilter:
			return fx
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = CUTOFF_MAX
	AudioServer.add_bus_effect(idx, lp)
	return lp


## Pushes the voices of the last update() to the players (only values that changed).
func apply() -> void:
	if _vp == null:
		return
	var t0 := Time.get_ticks_usec()
	for i in voices.size():
		var v := voices[i]
		_apply_slot(i, v, v.vehicle != NONE or v.fade > 0.0, 3)
	var sv := siren
	_apply_slot(voices.size(), sv, siren_stream != null and (sv.fade > 0.0 or _siren_on), 1)
	var us := Time.get_ticks_usec() - t0
	perf_us_sum += us
	perf_us_max = maxi(perf_us_max, us + _update_us)
	perf_apply_us_sum += us
	perf_apply_us_max = maxi(perf_apply_us_max, us)


func _apply_slot(i: int, v: Voice, active: bool, layers: int) -> void:
	var ps: Array = _players[i]
	var last: PackedFloat32Array = _last_db[i]
	if not active:
		if _gens[i] != -1:
			for p: AudioStreamPlayer2D in ps:
				p.stop()
			_gens[i] = -1
		return
	if _gens[i] != v.gen:
		_gens[i] = v.gen
		for k in layers:
			var p: AudioStreamPlayer2D = ps[k]
			var stream: AudioStream = siren_stream if layers == 1 else (sounds[v.sounds[k]] as Sound).stream
			p.stream = stream
			p.volume_db = -80.0
			last[k] = -80.0
			p.pitch_scale = clampf(v.pitch[k], 0.25, 4.0)
			p.play(v.offset[k] * stream.get_length())
	for k in layers:
		var p: AudioStreamPlayer2D = ps[k]
		var l := v.gl[k]
		var r := v.gr[k]
		var s := l + r
		var vol := linear_to_db(s) if s > 1.0e-5 else -80.0
		if absf(vol - last[k]) > 0.02:
			p.volume_db = vol
			last[k] = vol
		if s > 1.0e-5:
			var x := (2.0 * r / s - 1.0) * PAN_PX
			if absf(p.position.x - x) > 0.01:
				p.position = Vector2(x, 0.0)
		var pitch := clampf(v.pitch[k], 0.25, 4.0)
		if absf(p.pitch_scale - pitch) > 0.0002:
			p.pitch_scale = pitch
		if not p.playing:
			p.play(v.offset[k] * (p.stream.get_length() if p.stream != null else 0.0))
	if absf(_last_cut[i] - v.cutoff) > 1.0:
		_last_cut[i] = v.cutoff
		(_filters[i] as AudioEffectLowPassFilter).cutoff_hz = v.cutoff


## Stops and frees the players (the buses stay).
func detach() -> void:
	for ps: Array in _players:
		for p: AudioStreamPlayer2D in ps:
			if is_instance_valid(p):
				p.stop()
				p.stream = null
	if _vp != null and is_instance_valid(_vp):
		_vp.queue_free()
	_vp = null
	_players.clear()
	_filters.clear()
