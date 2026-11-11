class_name RoadAudio
extends ModernAudioModule
## Slot "road" of the Modern sound (package AU-C1, contract D27–D29, §4.7.2; docs/audio-modern.md "Fahrbahn, Wind,
## Aufprall"): what the player's car does on the road, on the bus MRoad, and the wind, on MWind (both → MCar).
## Godot mixes every sound natively; this script only moves levels, pitches and pans once per frame.
##
##   rolling     one loop per surface (asphalt, concrete, cobbles, steel deck, rumble strip, gravel shoulder, grass)
##               on two panned players – the left and the right wheels, reading the loop at different offsets – so
##               each side has its own surface (one wheel on the rumble strip, the other on the road) and the pair
##               is wide; level and pitch follow the road speed
##   wet         spray hiss on a wet road; snow muffles the rolling noise (low-pass on MRoad) and adds a crunch
##   slabs       the 'ta-tock' of the joints of a concrete motorway: a loop played at pitch v / design speed, so the
##               rhythm of front and rear axle is exact at every speed (two designs, crossfaded by speed)
##   joints      expansion joints of bridges (feed event "joint"): front and rear axle in one sound, the variant
##               whose axle gap is nearest to wheelbase / speed, its pitch shifted to match it exactly
##   passes      the car's noise thrown back by posts, signs, trees, buildings, gantries, rocks it passes (feed
##               event "pass_object"), panned to their side, louder and shorter with the speed
##   squeal      tyres at the limit of grip (understeer) – a tone; scrub without the tone for little slip, a wet road
##               and the slide of a crash; the lateral speed of a sharp lane change adds a little scrub
##   wind        three bands and the buffeting near top speed (the 'open window'), on panned pairs, with gusts;
##               quieter in tunnels and cuttings, stronger and gustier on bridges
##
## Levels are data (audio.modern.road): every target is the loudness at the master (LUFS, Gesamtlautstärke at its
## default – ref_path_db) of what the player hears; the loops carry their loudness per pitch (manifest lufs_pitch),
## the one-shots their momentary loudness (lufs_m). The plan of the contract: at the car's top speed the wind is
## wind.under_engine_db and the tyres on dry asphalt tyres.under_engine_db under the full-throttle loudness of the
## plan (audio.modern.loudness.full_throttle_lufs); below it they follow slope_db per decade of speed.
##
## Inputs: frame.speed, frame.wind_speed, frame.rain / frame.skid (without a vehicle state), frame.state
## (understeer, lat_speed, crash), frame.feed (surface_l / surface_r, paving, wet, snow, zone) and the feed's events.
## Without a track (feed not valid) the car rolls on dry asphalt in the open. Nothing here reads the renderer
## (Rule 4) or feeds back into the simulation (Rule 3).

const FOLDER := "vehicle"
const SFX := "sfx"
const SURFACE_LOOPS := {"asphalt": "tyre_asphalt", "concrete": "tyre_concrete", "cobbles": "tyre_cobbles",
	"deck": "tyre_deck", "rumble": "tyre_rumble", "shoulder": "tyre_gravel", "grass": "tyre_grass"}
const LOOSE: Array[String] = ["shoulder", "grass"]
const WIND_LOOPS: Array[String] = ["wind_low", "wind_mid", "wind_high", "wind_buffet"]
const PASS_SOUNDS := {"post": "pass_post", "sign": "pass_sign", "tree": "pass_tree", "building": "pass_building",
	"gantry": "pass_gantry", "rock": "pass_rock", "object": "pass_sign"}
const PAIR_DB := -3.0103          ## two decorrelated players carry one layer: each is 3 dB lower
const PASS_VOICES := 4
const JOINT_VOICES := 3
const MIN_SPEED := 1.0            ## km/h in the speed laws (log10)


## One looping sound on one plain player (centred) or on two panned players (left / right, read at different
## offsets of the loop). gains are linear, as for a plain player; drive() smooths them towards their targets.
class Layer:
	extends RefCounted
	var id := ""
	var players: Array = []                  ## AudioStreamPlayer / AudioStreamPlayer2D, or null while not live
	var pans := PackedFloat32Array()
	var offsets := PackedFloat32Array()      ## start position of each player in the loop (share of its length)
	var gains := PackedFloat32Array()        ## smoothed gain per player
	var level := 0.0                         ## largest gain of the layer (tests, debug)
	var pitch := 1.0
	var ref_kmh := 0.0                       ## manifest: design speed (pitch 1)
	var pitch_exp := 0.0                     ## manifest: pitch = (v / ref_kmh) ** pitch_exp
	var curve: Array = []                    ## manifest lufs_pitch: [[pitch, LUFS], …]
	var lufs := -20.0                        ## manifest: loudness at pitch 1
	var length_s := 1.0
	var has_sound := false

	func lufs_at(p: float) -> float:
		if curve.size() < 2:
			return lufs
		var lp := log(maxf(p, 0.01))
		if lp <= log(float(curve[0][0])):
			return float(curve[0][1])
		for i in range(1, curve.size()):
			var a := log(float(curve[i][0]))
			if lp <= a:
				var a0 := log(float(curve[i - 1][0]))
				return lerpf(float(curve[i - 1][1]), float(curve[i][1]), (lp - a0) / maxf(a - a0, 1.0e-6))
		return float(curve[curve.size() - 1][1])

	func pitch_for(kmh: float) -> float:
		if ref_kmh <= 0.0:
			return 1.0
		return clampf(pow(maxf(kmh, 1.0) / ref_kmh, pitch_exp), 0.15, 3.5)

	func drive(targets: PackedFloat32Array, p: float, k: float) -> void:
		pitch = clampf(p, 0.05, 4.0)
		level = 0.0
		for i in gains.size():
			gains[i] = lerpf(gains[i], maxf(targets[i], 0.0), clampf(k, 0.0, 1.0))
			if gains[i] < ModernAudioPan.SILENT and targets[i] <= 0.0:
				gains[i] = 0.0          # faded out: exactly silent (the slot skips silent layers)
			level = maxf(level, gains[i])
			var pl: Node = players[i]
			if pl == null:
				continue
			var g := gains[i]
			if g < ModernAudioPan.SILENT:
				if pl.get("playing"):
					pl.call("stop")
				continue
			if pl is AudioStreamPlayer2D:
				ModernAudioPan.apply(pl as AudioStreamPlayer2D, g, pans[i])
			else:
				var db := linear_to_db(g)
				if absf(float(pl.get("volume_db")) - db) > 0.02:
					pl.set("volume_db", db)
			if absf(float(pl.get("pitch_scale")) - pitch) > 0.0005:
				pl.set("pitch_scale", pitch)
			if not pl.get("playing"):
				pl.call("play", offsets[i] * length_s)

	func silence() -> void:
		level = 0.0
		for i in gains.size():
			gains[i] = 0.0
			var pl: Node = players[i]
			if pl != null and pl.get("playing"):
				pl.call("stop")

	func release() -> void:
		silence()
		for pl: Node in players:
			if pl is AudioStreamPlayer:
				ModernAudioContext.free_player(pl as AudioStreamPlayer)
			else:
				ModernAudioPan.free_player(pl)
		players.clear()


# configuration (audio.modern.road)
var _ref_path_db := -1.94
var _smooth_s := 0.06
var _surface_s := 0.05
var _fade_s := 0.12
var _tyre_top := -20.0
var _tyre_slope := 30.0
var _tyre_fade := Vector2(3.0, 25.0)
var _tyre_pan := 0.55
var _surface_db: Dictionary = {}
var _surface_slope: Dictionary = {}
var _wet_db := 1.0
var _wet_slope := 40.0
var _snow_db := -3.0
var _snow_lp := 3000.0
var _snow_crunch := 0.35
var _loose_boost := 0.8
var _slab_db := -2.0
var _slab_slope := 20.0
var _slab_xfade := Vector2(110.0, 150.0)
var _squeal_lufs := -19.0
var _squeal_min := 15.0
var _squeal_wet := 0.3
var _squeal_loose := 0.15
var _scrub_lufs := -22.0
var _lat_from := 1.5
var _lat_full := 5.0
var _crash_scrub := 0.8
var _joint_lufs := -22.0
var _joint_steel_db := 1.5
var _joint_end_db := 2.0
var _joint_slope := 20.0
var _joint_min := 15.0
var _pass_lufs := -31.0
var _pass_slope := 40.0
var _pass_ref_m := 3.0
var _pass_overhead_m := 6.0
var _pass_min := 40.0
var _pass_floor := -58.0
var _pass_pan := 0.75
var _pass_kind_db: Dictionary = {}
var _wind_top := -19.0
var _wind_slope := 55.0
var _wind_fade := Vector2(20.0, 60.0)
var _wind_pan := 0.7
var _wind_band_top: Dictionary = {}       ## loop id -> loudness at top speed in the open (bands sum to _wind_top)
var _buffet_from := 0.82
var _gust_db := 1.5
var _gust_s := 1.2
var _zone_db_cfg: Dictionary = {}
var _zone_gust_cfg: Dictionary = {}
var _zone_s := 0.8

var vehicle_id := ""
var vmax_kmh := 250.0                     ## nominal top speed of the car (vehicles.types.<id>.vmax_kmh)
var wheelbase_m := 2.7
var surfaces: Dictionary = {}             ## surface -> Layer (left and right wheels)
var wet: Layer = null
var squeal: Layer = null
var skid: Layer = null                    ## = squeal (the name of the wave-0 stand-in, kept for tests and tools)
var scrub: Layer = null
var slab_slow: Layer = null
var slab_fast: Layer = null
var winds: Dictionary = {}                ## loop id -> Layer
var wind: Layer = null                    ## = winds.wind_low (the name of the stand-in)
var joints := 0                           ## feed events seen (tests)
var passes := 0
var played := {"joint": 0, "pass": 0}     ## one-shots started (or counted while not live)
var last_joint: Dictionary = {}           ## id, variant, gap, pitch, db (tests)
var last_pass: Dictionary = {}
var zone_db := 0.0                        ## smoothed zone offset of the wind (dB)
var zone_gust := 1.0
var snow_amount := 0.0

var _vp: SubViewport = null
var _joint_voices := ModernAudioVoices.new()
var _pass_players: Array[AudioStreamPlayer2D] = []
var _pass_next := 0
var _driven := false
var _on := false
var _speed := 0.0
var _gust := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])   # per wind band + a common one
var _rng := RandomNumberGenerator.new()
var _lowpass: AudioEffectLowPassFilter = null
var _lowpass_on := false
var _t2 := PackedFloat32Array([0.0, 0.0])
var _t1 := PackedFloat32Array([0.0])


func _setup() -> void:
	_read_config()
	_rng.seed = 51017
	if ctx.live:
		_vp = ModernAudioPan.make_viewport(ctx.host, "RoadVoices")
	for s: String in SURFACE_LOOPS:
		surfaces[s] = _layer(str(SURFACE_LOOPS[s]), "MRoad", [-_tyre_pan, _tyre_pan])
	wet = _layer("tyre_wet", "MRoad", [-_tyre_pan, _tyre_pan])
	squeal = _layer("squeal", "MRoad", [])
	skid = squeal
	scrub = _layer("scrub", "MRoad", [])
	slab_slow = _layer("slab_slow", "MRoad", [])
	slab_fast = _layer("slab_fast", "MRoad", [])
	for w: String in WIND_LOOPS:
		winds[w] = _layer(w, "MWind", [-_wind_pan, _wind_pan])
	wind = winds["wind_low"]
	_joint_voices.attach(ctx, "MRoad", JOINT_VOICES, "RoadJoint")
	if _vp != null:
		for i in PASS_VOICES:
			_pass_players.append(ModernAudioPan.player(_vp, "MRoad", "RoadPass%d" % i))
	if ctx.live and ctx.buses != null:
		var fx: AudioEffect = ctx.buses.effect("MRoad", "AudioEffectLowPassFilter")
		_lowpass = fx as AudioEffectLowPassFilter if fx is AudioEffectLowPassFilter else null
		if _lowpass != null:
			_lowpass.cutoff_hz = 20000.0
			_set_lowpass_enabled(false)


func _read_config() -> void:
	_ref_path_db = ctx.number("road.ref_path_db", _ref_path_db)
	_smooth_s = maxf(ctx.number("road.smooth_s", _smooth_s), 0.005)
	_surface_s = maxf(ctx.number("road.surface_s", _surface_s), 0.005)
	_fade_s = maxf(ctx.number("road.fade_s", _fade_s), 0.005)
	var full := ctx.number("loudness.full_throttle_lufs", -16.0)
	_tyre_top = full - ctx.number("road.tyres.under_engine_db", 4.0)
	_tyre_slope = ctx.number("road.tyres.slope_db", _tyre_slope)
	_tyre_fade = _vec2(ctx.value("road.tyres.fade_kmh", null), _tyre_fade)
	_tyre_pan = clampf(ctx.number("road.tyres.pan", _tyre_pan), 0.0, 1.0)
	_surface_db = _dict(ctx.value("road.tyres.surface_db", {}))
	_surface_slope = _dict(ctx.value("road.tyres.slope_by_surface", {}))
	_wet_db = ctx.number("road.tyres.wet_db", _wet_db)
	_wet_slope = ctx.number("road.tyres.wet_slope_db", _wet_slope)
	_snow_db = ctx.number("road.tyres.snow_db", _snow_db)
	_snow_lp = clampf(ctx.number("road.tyres.snow_lowpass_hz", _snow_lp), 200.0, 20000.0)
	_snow_crunch = clampf(ctx.number("road.tyres.snow_crunch", _snow_crunch), 0.0, 1.0)
	_loose_boost = maxf(ctx.number("road.tyres.loose_boost", _loose_boost), 0.0)
	_slab_db = ctx.number("road.slabs.db", _slab_db)
	_slab_slope = ctx.number("road.slabs.slope_db", _slab_slope)
	_slab_xfade = _vec2(ctx.value("road.slabs.crossfade_kmh", null), _slab_xfade)
	_squeal_lufs = ctx.number("road.squeal.lufs", _squeal_lufs)
	_squeal_min = ctx.number("road.squeal.min_kmh", _squeal_min)
	_squeal_wet = clampf(ctx.number("road.squeal.wet", _squeal_wet), 0.0, 1.0)
	_squeal_loose = clampf(ctx.number("road.squeal.loose", _squeal_loose), 0.0, 1.0)
	_scrub_lufs = ctx.number("road.squeal.scrub_lufs", _scrub_lufs)
	_lat_from = ctx.number("road.squeal.lat_from_mps", _lat_from)
	_lat_full = maxf(ctx.number("road.squeal.lat_full_mps", _lat_full), _lat_from + 0.1)
	_crash_scrub = clampf(ctx.number("road.squeal.crash_scrub", _crash_scrub), 0.0, 1.0)
	_joint_lufs = ctx.number("road.joints.lufs", _joint_lufs)
	_joint_steel_db = ctx.number("road.joints.steel_db", _joint_steel_db)
	_joint_end_db = ctx.number("road.joints.end_db", _joint_end_db)
	_joint_slope = ctx.number("road.joints.slope_db", _joint_slope)
	_joint_min = ctx.number("road.joints.min_kmh", _joint_min)
	_pass_lufs = ctx.number("road.passes.lufs", _pass_lufs)
	_pass_slope = ctx.number("road.passes.slope_db", _pass_slope)
	_pass_ref_m = maxf(ctx.number("road.passes.ref_m", _pass_ref_m), 0.5)
	_pass_overhead_m = maxf(ctx.number("road.passes.overhead_m", _pass_overhead_m), 0.5)
	_pass_min = ctx.number("road.passes.min_kmh", _pass_min)
	_pass_floor = ctx.number("road.passes.floor_lufs", _pass_floor)
	_pass_pan = clampf(ctx.number("road.passes.pan", _pass_pan), 0.0, 1.0)
	_pass_kind_db = _dict(ctx.value("road.passes.kind_db", {}))
	_wind_top = full - ctx.number("road.wind.under_engine_db", 3.0)
	_wind_slope = ctx.number("road.wind.slope_db", _wind_slope)
	_wind_fade = _vec2(ctx.value("road.wind.fade_kmh", null), _wind_fade)
	_wind_pan = clampf(ctx.number("road.wind.pan", _wind_pan), 0.0, 1.0)
	_buffet_from = clampf(ctx.number("road.wind.buffet_from", _buffet_from), 0.0, 0.999)
	_gust_db = maxf(ctx.number("road.wind.gust_db", _gust_db), 0.0)
	_gust_s = maxf(ctx.number("road.wind.gust_s", _gust_s), 0.05)
	_zone_db_cfg = _dict(ctx.value("road.wind.zone_db", {}))
	_zone_gust_cfg = _dict(ctx.value("road.wind.zone_gust", {}))
	_zone_s = maxf(ctx.number("road.wind.zone_s", _zone_s), 0.01)
	# the bands share the wind's loudness at top speed: their offsets keep their relation, their sum is _wind_top
	var bands := _dict(ctx.value("road.wind.bands_db", {}))
	var sum := 0.0
	for w: String in WIND_LOOPS:
		sum += db_to_linear(float(bands.get(w, 0.0))) ** 2
	_wind_band_top.clear()
	for w: String in WIND_LOOPS:
		_wind_band_top[w] = _wind_top + float(bands.get(w, 0.0)) - 10.0 * log(maxf(sum, 1.0e-9)) / log(10.0)


static func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


static func _vec2(v: Variant, default: Vector2) -> Vector2:
	if v is Array and (v as Array).size() == 2:
		return Vector2(float(v[0]), float(v[1]))
	return default


static func _log10(x: float) -> float:
	return log(maxf(x, 1.0e-9)) / log(10.0)


## A layer for a loop of the vehicle folder: two panned players (pans = their pans) or one plain player (pans = []).
func _layer(id: String, bus: String, pans: Array) -> Layer:
	var l := Layer.new()
	l.id = id
	var e := ctx.assets.entry(FOLDER, id) if ctx.assets != null else null
	var stream: AudioStream = ctx.stream(FOLDER, id) if e != null else null
	l.has_sound = stream != null or e != null
	if e != null:
		l.ref_kmh = float(e.meta.get("ref_kmh", 0.0))
		l.pitch_exp = float(e.meta.get("pitch_exp", 0.0))
		l.lufs = e.lufs
		var c: Variant = e.meta.get("lufs_pitch", [])
		l.curve = c if c is Array else []
		if e.loops():
			l.length_s = float(e.loop_end - e.loop_begin) / float(maxi(e.sample_rate, 1))
	var n := maxi(pans.size(), 1)
	for i in n:
		l.pans.append(float(pans[i]) if i < pans.size() else 0.0)
		l.offsets.append(float(i) / float(n))
		l.gains.append(0.0)
		var pl: Node = null
		if stream != null and ctx.live:
			if pans.is_empty():
				pl = ctx.player(bus, "Road_" + id)
			elif _vp != null:
				pl = ModernAudioPan.player(_vp, bus, "Road_%s_%d" % [id, i])
			if pl != null:
				pl.set("stream", stream)
				pl.set("volume_db", -80.0)
		l.players.append(pl)
	return l


func set_vehicle(id: String) -> void:
	vehicle_id = id
	vmax_kmh = maxf(float(ConfigLoader.lookup(ctx.cfg, "vehicles.types.%s.vmax_kmh" % id, 250.0)), 60.0)
	wheelbase_m = clampf(0.6 * float(ConfigLoader.lookup(ctx.cfg, "vehicles.types.%s.length_m" % id, 4.5)), 1.8, 4.0)


func track_changed(_feed: AudioFeed) -> void:
	for i in _gust.size():
		_gust[i] = 0.0


## Gain (as for a plain player) that brings a loop to `target` LUFS at the master, played at pitch p; a pair of
## players shares it (each 3 dB lower).
func _gain(l: Layer, target: float, p: float, pair: bool) -> float:
	if not l.has_sound:
		return 0.0
	return db_to_linear(target - l.lufs_at(p) - _ref_path_db + (PAIR_DB if pair else 0.0))


func _speed_db(slope: float, kmh: float) -> float:
	return slope * _log10(maxf(kmh, MIN_SPEED) / vmax_kmh)


static func _ramp(x: float, r: Vector2) -> float:
	return smoothstep(r.x, maxf(r.y, r.x + 0.001), x)


func update(frame: ModernAudioFrame) -> void:
	var dt := maxf(frame.dt, 0.0001)
	_driven = EngineAudio3.driven(frame, _driven)
	_on = _driven and not frame.effects_muted
	_speed = frame.speed if _on else 0.0
	var k := 1.0 - exp(-minf(dt, 0.1) / (_smooth_s if _on else _fade_s))
	var ks := 1.0 - exp(-minf(dt, 0.1) / (_surface_s if _on else _fade_s))
	var v := _speed
	var feed := frame.feed
	var fv := feed != null and feed.valid
	var sl := feed.surface_l if fv else "asphalt"
	var sr := feed.surface_r if fv else "asphalt"
	var wet_amt := feed.wet if fv else frame.rain
	var snow_target := feed.snow if fv else 0.0
	var zone := feed.zone if fv else ("tunnel" if frame.tunnel else "open")
	snow_amount = move_toward(snow_amount, snow_target, dt / 1.5)
	var st := frame.state if frame.has_state else {}
	var us := clampf(float(st.get("understeer", frame.skid)) if frame.has_state else frame.skid, 0.0, 1.0)
	var tyre_fade := _ramp(v, _tyre_fade) if _on else 0.0
	var loose := (0.5 if LOOSE.has(sl) else 0.0) + (0.5 if LOOSE.has(sr) else 0.0)
	# rolling noise per surface and side
	var snow_db := _snow_db * snow_amount
	for s: String in surfaces:
		var l: Layer = surfaces[s]
		var wl := 1.0 if sl == s else 0.0
		var wr := 1.0 if sr == s else 0.0
		if s == "shoulder" and snow_amount > 0.0:
			wl = maxf(wl, _snow_crunch * snow_amount)
			wr = maxf(wr, _snow_crunch * snow_amount)
		if (wl == 0.0 and wr == 0.0 and l.level < ModernAudioPan.SILENT) or not l.has_sound:
			continue
		var p := l.pitch_for(v)
		var target := _tyre_top + float(_surface_db.get(s, 0.0)) + _speed_db(float(_surface_slope.get(s, _tyre_slope)), v) + snow_db
		if LOOSE.has(s):
			target += 20.0 * _log10(1.0 + _loose_boost * us)    # a sliding car ploughs the gravel
		var g := _gain(l, target, p, true) * tyre_fade
		_t2[0] = g * wl
		_t2[1] = g * wr
		l.drive(_t2, p, ks)
	# wet road: on what is paved
	var paved := 1.0 - loose
	if wet != null and wet.has_sound and (wet_amt > 0.0 or wet.level >= ModernAudioPan.SILENT):
		var pw := wet.pitch_for(v)
		var gw := _gain(wet, _tyre_top + _wet_db + _speed_db(_wet_slope, v), pw, true) * tyre_fade * wet_amt * paved
		_t2[0] = gw
		_t2[1] = gw
		wet.drive(_t2, pw, k)
	_update_slabs(v, sl, sr, tyre_fade, k)
	_update_squeal(v, us, st, wet_amt, loose, k)
	_update_wind(frame, dt, zone, k)
	_update_lowpass()


func _update_slabs(v: float, sl: String, sr: String, fade: float, k: float) -> void:
	var conc := (0.5 if sl == "concrete" else 0.0) + (0.5 if sr == "concrete" else 0.0)
	var xf := _ramp(v, _slab_xfade)
	var target := _tyre_top + _slab_db + _speed_db(_slab_slope, v)
	for pair: Array in [[slab_slow, 1.0 - xf], [slab_fast, xf]]:
		var l: Layer = pair[0]
		if l == null or not l.has_sound or (conc == 0.0 and l.level < ModernAudioPan.SILENT):
			continue
		var p := clampf(maxf(v, MIN_SPEED) / maxf(l.ref_kmh, 1.0), 0.15, 3.0)
		_t1[0] = _gain(l, target, p, false) * conc * float(pair[1]) * fade
		l.drive(_t1, p, k)


func _update_squeal(v: float, us: float, st: Dictionary, wet_amt: float, loose: float, k: float) -> void:
	var v_ok := clampf((v - _squeal_min) / 20.0, 0.0, 1.0) if _on else 0.0
	var crash := bool(st.get("crash", false))
	var lat := absf(float(st.get("lat_speed", 0.0)))
	var lat_amt := clampf((lat - _lat_from) / (_lat_full - _lat_from), 0.0, 1.0) * 0.5 * clampf(v / 100.0, 0.0, 1.0)
	var sq := us * v_ok * lerpf(1.0, _squeal_loose, loose) * lerpf(1.0, _squeal_wet, wet_amt)
	var sc := maxf(maxf(us * (0.45 + 0.55 * wet_amt) * (1.0 - loose), _crash_scrub if crash else 0.0), lat_amt) * v_ok
	if squeal != null and squeal.has_sound:
		var p := 0.9 + 0.22 * us + 0.08 * clampf(v / 250.0, 0.0, 1.0)
		_t1[0] = _gain(squeal, _squeal_lufs + 26.0 * _log10(maxf(sq, 1.0e-4)), p, false) if sq > 0.002 else 0.0
		squeal.drive(_t1, p, k)
	if scrub != null and scrub.has_sound:
		var ps := 0.8 + 0.4 * clampf(v / 200.0, 0.0, 1.0)
		_t1[0] = _gain(scrub, _scrub_lufs + 20.0 * _log10(maxf(sc, 1.0e-4)), ps, false) if sc > 0.002 else 0.0
		scrub.drive(_t1, ps, k)


func _update_wind(frame: ModernAudioFrame, dt: float, zone: String, k: float) -> void:
	var vw := frame.wind_speed if _on else 0.0
	var kz := 1.0 - exp(-minf(dt, 0.1) / _zone_s)
	zone_db = lerpf(zone_db, float(_zone_db_cfg.get(zone, 0.0)), kz)
	zone_gust = lerpf(zone_gust, float(_zone_gust_cfg.get(zone, 1.0)), kz)
	# gusts: Ornstein-Uhlenbeck processes with unit spread (one shared, one per band), the same sequence every run
	var a := minf(dt, 0.1) / _gust_s
	var sd := sqrt(2.0 * a)
	for i in _gust.size():
		_gust[i] += -_gust[i] * a + sd * _rng.randfn(0.0, 1.0)
	var fade := _ramp(vw, _wind_fade)
	for bi in WIND_LOOPS.size():
		var id: String = WIND_LOOPS[bi]
		var l: Layer = winds[id]
		if not l.has_sound or (fade <= 0.0 and l.level < ModernAudioPan.SILENT):
			continue
		var weight := 1.0
		if id == "wind_buffet":
			weight = _ramp(vw, Vector2(_buffet_from * vmax_kmh, vmax_kmh))
		var gust := (0.6 * _gust[4] + 0.8 * _gust[bi]) * _gust_db * zone_gust
		var p := l.pitch_for(vw)
		var target := float(_wind_band_top[id]) + _speed_db(_wind_slope, vw) + zone_db + gust
		var g := _gain(l, target, p, true) * fade * weight
		_t2[0] = g
		_t2[1] = g
		l.drive(_t2, p, k)


## Snow muffles the rolling noise: a low-pass on MRoad (this slot's bus) while it snows.
func _update_lowpass() -> void:
	if _lowpass == null:
		return
	var want := snow_amount > 0.01
	if want:
		_lowpass.cutoff_hz = exp(lerpf(log(20000.0), log(_snow_lp), snow_amount))
	if want != _lowpass_on:
		_set_lowpass_enabled(want)


func _set_lowpass_enabled(on: bool) -> void:
	_lowpass_on = on
	var idx := ctx.buses.index("MRoad") if ctx.buses != null else -1
	if idx < 0:
		return
	for j in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, j) == _lowpass:
			AudioServer.set_bus_effect_enabled(idx, j, on)


func event(event_name: String, args: Dictionary) -> void:
	if event_name == "joint":
		joints += 1
		_joint(args)
	elif event_name == "pass_object":
		passes += 1
		if not bool(args.get("contact", false)):     # a post the body hits: the impact slot sounds it
			_pass(args)


## An expansion joint under the car: the variant whose axle gap is nearest to wheelbase / speed, its pitch
## shifted so the gap is exact.
func _joint(args: Dictionary) -> void:
	if not _on or _speed < _joint_min:
		return
	var steel := str(args.get("deck", "")) == "steel"
	var id := "joint_steel" if steel else "joint_concrete"
	var e := ctx.assets.entry(SFX, id) if ctx.assets != null else null
	if e == null:
		return
	var gaps: Variant = e.meta.get("gaps_s", [])
	var gap := wheelbase_m / (_speed / 3.6)
	var best := 0
	if gaps is Array and not (gaps as Array).is_empty():
		var bd := INF
		for i in mini((gaps as Array).size(), e.files.size()):
			var d := absf(log(float(gaps[i]) / gap))
			if d < bd:
				bd = d
				best = i
	var pitch := clampf(float(gaps[best]) / gap, 0.7, 1.45) if gaps is Array and best < (gaps as Array).size() else 1.0
	var target := _joint_lufs + _joint_slope * _log10(_speed / 100.0) + (_joint_steel_db if steel else 0.0) \
		+ (_joint_end_db if str(args.get("kind", "")) == "bridge_end" else 0.0)
	var db := target - _lufs_m(e, best) - _ref_path_db
	last_joint = {"id": id, "variant": best, "gap": gap, "pitch": pitch, "db": db}
	played["joint"] = int(played["joint"]) + 1
	_joint_voices.play(ctx.assets.stream(SFX, id, best), db, pitch)


## A roadside object passed: its whoosh at its side, by kind, size, distance and speed.
func _pass(args: Dictionary) -> void:
	if not _on or _speed < _pass_min:
		return
	var kind := str(args.get("kind", "object"))
	var id := str(PASS_SOUNDS.get(kind, "pass_sign"))
	var e := ctx.assets.entry(SFX, id) if ctx.assets != null else null
	if e == null:
		return
	var overhead := int(args.get("side", 0)) == 0
	var dist := _pass_overhead_m if overhead else maxf(float(args.get("dist_m", 3.0)), 1.5)
	var size := maxf(float(args.get("size", 1.0)), 0.05)
	var target := _pass_lufs + float(_pass_kind_db.get(kind, 0.0)) + _pass_slope * _log10(_speed / 100.0) \
		+ 20.0 * _log10(size) - 20.0 * _log10(dist / _pass_ref_m)
	if target < _pass_floor:
		return
	var n := e.files.size()
	var variant := (passes % n) if n > 0 else 0
	var ref := float(e.meta.get("ref_kmh", 100.0))
	var pitch := clampf(sqrt(_speed / maxf(ref, 1.0)), 0.6, 1.8)
	var pan := float(int(args.get("side", 0))) * _pass_pan
	var gain := db_to_linear(target - _lufs_m(e, variant) - _ref_path_db)
	last_pass = {"id": id, "variant": variant, "pitch": pitch, "pan": pan, "db": linear_to_db(gain), "target": target}
	played["pass"] = int(played["pass"]) + 1
	if _pass_players.is_empty():
		return
	var pl: AudioStreamPlayer2D = _pass_players[_pass_next]
	_pass_next = (_pass_next + 1) % _pass_players.size()
	if pl == null:
		return
	pl.stream = ctx.assets.stream(SFX, id, variant)
	pl.pitch_scale = pitch
	ModernAudioPan.apply(pl, gain, pan)
	pl.play()


## Momentary loudness of a one-shot variant (manifest lufs_m; the integrated loudness without it).
static func _lufs_m(e: ModernAudioAssets.Entry, variant: int) -> float:
	var m: Variant = e.meta.get("lufs_m", null)
	if m is Array and variant < (m as Array).size():
		return float(m[variant])
	return e.lufs


func stop_all() -> void:
	_driven = false
	_on = false
	for l: Layer in _all_layers():
		l.silence()
	_joint_voices.stop_all()
	for p in _pass_players:
		if p != null:
			p.stop()


func teardown() -> void:
	for l: Layer in _all_layers():
		l.release()
	_joint_voices.release()
	for p in _pass_players:
		ModernAudioPan.free_player(p)
	_pass_players.clear()
	if _vp != null and is_instance_valid(_vp):
		_vp.queue_free()
	_vp = null
	if _lowpass != null:
		_set_lowpass_enabled(false)
	_lowpass = null


func _all_layers() -> Array:
	var out: Array = surfaces.values()
	out.append_array([wet, squeal, scrub, slab_slow, slab_fast])
	out.append_array(winds.values())
	return out.filter(func(l: Variant) -> bool: return l != null)


## Tools: per layer [gain left, gain right (or the one gain), pitch] of this frame.
func levels() -> Dictionary:
	var out := {}
	for l: Layer in _all_layers():
		var row: Array = []
		for g in l.gains:
			row.append(snappedf(g, 0.0001))
		row.append(snappedf(l.pitch, 0.0001))
		out[l.id] = row
	return out


func debug_state() -> Dictionary:
	var wind_level := 0.0
	for w: String in winds:
		wind_level = maxf(wind_level, (winds[w] as Layer).level)
	var playing := 0
	for l: Layer in _all_layers():
		for pl: Node in l.players:
			playing += 1 if (pl != null and pl.get("playing")) else 0
	var surf := {}
	for s: String in surfaces:
		var l: Layer = surfaces[s]
		if l.level >= ModernAudioPan.SILENT:
			surf[s] = [snappedf(l.gains[0], 0.0001), snappedf(l.gains[1], 0.0001)]
	return {"vehicle": vehicle_id, "wind": wind_level, "skid": squeal.level if squeal != null else 0.0,
		"scrub": scrub.level if scrub != null else 0.0, "wet": wet.level if wet != null else 0.0, "surfaces": surf,
		"slab": maxf(slab_slow.level, slab_fast.level) if slab_slow != null else 0.0, "zone_db": zone_db,
		"snow": snow_amount, "joints": joints, "passes": passes, "played": played.duplicate(), "players": playing}
