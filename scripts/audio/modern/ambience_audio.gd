class_name AmbienceAudio
extends ModernAudioModule
## Slot "ambience" of the Modern sound (package AU-C2; contract D25–D29; docs/audio-modern.md "Welt, Ambiente,
## Verkehr"): the surroundings on the bus MAmb (→ MSfx; no reverb path – every bed and call carries its own space).
## Sounds: assets/audio/modern/ambience (tools/audio/modern/ambience_synth.py).
##
##   beds     stereo loops, faded in and out by weights: breeze (open land), leaves (forest), crickets (summer
##            nights), cicadas (Mediterranean days), city_day / city_night, water (a bridge over water, the coast, a
##            port city), tunnel_fans (the camera in a tunnel), hum (under a canopy: fuel station, border post), rain
##   calls    one-shots scattered at random (Poisson rates per minute, per category and place): birds, crows, a
##            skylark, a woodpecker, an owl, a distant dog, sparrows, pigeons, a car horn some streets away, a
##            church bell in old town centres, a scooter, gulls and a ship's horn by the water – variant, side,
##            distance (level) and pitch (±) drawn each time, so nothing repeats in step
##
## Weights (docs: the table "Ambiente"): the zone and canopy of frame.feed, the camera in a tunnel (frame.tunnel), the
## scenery's style, climate and features (AudioFeed, from data/scenery.json), water under the bridge, the hour
## (frame.state.hour against the daytime of the configuration: night, the dawn chorus, day, dusk), rain (frame.rain) and snow
## (feed.snow): insects and birds fall silent in rain and snow, snow makes everything quieter. Speed: a bed and a call
## are slope_db per decade quieter above from_kmh (the car covers them anyway – they must not add mud to the mix);
## above calls_max_kmh no call starts. Pause: the beds go on with their weights, pause_db quieter (the pause snapshot
## muffles MAmb); no call starts. Without a running stage (no engine calls, no state) for hold_s outside a pause
## everything fades out.
##
## Levels are data (audio.modern.ambience): each bed's loudness at the master at weight 1 and standstill
## (beds.<id>.lufs), each category's momentary loudness (calls.<cat>.lufs_m) – measured against the files' manifest
## loudness (lufs, lufs_m) and the path to the master (ref_path_db: Gesamtlautstärke at its default).
## Nothing here reads the renderer (Rule 4) or feeds back into the simulation (Rule 3).

const FOLDER := "ambience"
const BEDS: Array[String] = ["breeze", "leaves", "crickets", "cicadas", "city_day", "city_night", "water",
	"tunnel_fans", "hum", "rain"]
const CALL_VOICES := 4
const MIN_KMH := 1.0

## Category -> sounds (id, weight) it draws from.
const CALL_SOUNDS := {
	"bird": [["bird_blackbird", 3.0], ["bird_chaffinch", 2.0], ["bird_tit", 2.0]],
	"crow": [["bird_crow", 1.0]], "skylark": [["bird_skylark", 1.0]], "woodpecker": [["bird_woodpecker", 1.0]],
	"owl": [["owl", 1.0]], "dog": [["dog", 1.0]], "sparrow": [["bird_sparrow", 1.0]], "pigeon": [["pigeon", 1.0]],
	"horn": [["city_horn", 1.0]], "bell": [["church_bell", 1.0]], "scooter": [["scooter", 1.0]],
	"gull": [["gull", 1.0]], "ship": [["ship_horn", 1.0]],
}

## Defaults (audio.modern.ambience overrides them).
const BED_LUFS := {"breeze": -39.0, "leaves": -37.0, "crickets": -37.0, "cicadas": -34.0, "city_day": -33.0,
	"city_night": -37.0, "water": -35.0, "tunnel_fans": -34.0, "hum": -38.0, "rain": -29.0}
const BED_SLOPE := {"breeze": 10.0, "leaves": 10.0, "crickets": 12.0, "cicadas": 10.0, "city_day": 8.0,
	"city_night": 8.0, "water": 10.0, "tunnel_fans": 6.0, "hum": 12.0, "rain": 3.0}
const CALL_LUFS := {"bird": -33.0, "crow": -35.0, "skylark": -40.0, "woodpecker": -36.0, "owl": -35.0, "dog": -42.0,
	"sparrow": -34.0, "pigeon": -37.0, "horn": -36.0, "bell": -33.0, "scooter": -37.0, "gull": -31.0, "ship": -34.0}
const CLIMATE_CRICKETS := {"north": 0.5, "continental": 1.0, "default": 1.0, "alpine": 0.6, "mediterranean": 1.2}


## One bed: a stereo loop on MAmb, started at a random point of its loop.
class Bed:
	extends RefCounted
	var id := ""
	var player: AudioStreamPlayer = null
	var lufs := -20.0               ## the file's loudness (manifest)
	var weight := 0.0               ## smoothed 0..1
	var target := 0.0               ## the weight of this frame's rules
	var gain := 0.0                 ## linear gain of this frame (tests)
	var has_sound := false


var beds: Dictionary = {}         ## id -> Bed
var weights: Dictionary = {}      ## id -> target weight of the last frame (tests)
var rates: Dictionary = {}        ## category -> calls per minute in the last frame (tests)
var calls_played := 0
var last_call: Dictionary = {}    ## id, variant, category, db, pan, pitch (tests)
var night := 0.0                  ## 0 day … 1 night
var dawn := 0.0                   ## 0 … 1 at the dawn chorus
var water_w := 0.0
var city_w := 0.0

var _ref_path_db := -1.94
var _fade_s := 1.5
var _tunnel_fade_s := 0.5
var _from_kmh := 30.0
var _max_fade_db := 12.0
var _pause_db := -6.0
var _calls_max_kmh := 140.0
var _call_spread_db := 8.0
var _call_pitch := 0.04
var _bed_lufs: Dictionary = {}
var _bed_slope: Dictionary = {}
var _call_lufs: Dictionary = {}
var _rates_cfg: Dictionary = {}
var _daytime: Dictionary = {}
var _vp: SubViewport = null
var _call_players: Array[AudioStreamPlayer2D] = []
var _call_last: Dictionary = {}   ## sound id -> last variant
var _rng := RandomNumberGenerator.new()
var _on := false
var _was_running := false
var _off_s := 0.0                 ## seconds without a running stage (outside a pause)
var _hold_s := 0.75
var _was_tunnel := false
var _fast_s := 0.0                ## > 0: the quick fade of a tunnel portal is still on
var _fast_hold_s := 2.0


func _setup() -> void:
	_ref_path_db = ctx.number("ambience.ref_path_db", _ref_path_db)
	_fade_s = maxf(ctx.number("ambience.fade_s", _fade_s), 0.05)
	_tunnel_fade_s = maxf(ctx.number("ambience.tunnel_fade_s", _tunnel_fade_s), 0.05)
	_from_kmh = maxf(ctx.number("ambience.speed.from_kmh", _from_kmh), MIN_KMH)
	_max_fade_db = ctx.number("ambience.speed.max_db", _max_fade_db)
	_pause_db = ctx.number("ambience.pause_db", _pause_db)
	_calls_max_kmh = ctx.number("ambience.calls_max_kmh", _calls_max_kmh)
	_call_spread_db = ctx.number("ambience.call_spread_db", _call_spread_db)
	_call_pitch = ctx.number("ambience.call_pitch", _call_pitch)
	_bed_lufs = BED_LUFS.duplicate()
	_bed_slope = BED_SLOPE.duplicate()
	_call_lufs = CALL_LUFS.duplicate()
	var bcfg: Variant = ctx.value("ambience.beds", {})
	if bcfg is Dictionary:
		for id: String in bcfg:
			var b: Variant = (bcfg as Dictionary)[id]
			if b is Dictionary:
				_bed_lufs[id] = float((b as Dictionary).get("lufs", _bed_lufs.get(id, -40.0)))
				_bed_slope[id] = float((b as Dictionary).get("slope_db", _bed_slope.get(id, 10.0)))
	var ccfg: Variant = ctx.value("ambience.calls", {})
	if ccfg is Dictionary:
		for c: String in ccfg:
			var v: Variant = (ccfg as Dictionary)[c]
			if v is Dictionary:
				_call_lufs[c] = float((v as Dictionary).get("lufs_m", _call_lufs.get(c, -40.0)))
	var r: Variant = ctx.value("ambience.rates", {})
	_rates_cfg = r if r is Dictionary else {}
	var dt: Variant = ConfigLoader.lookup(ctx.cfg, "daytime", {})
	_daytime = dt if dt is Dictionary else {}
	_rng.seed = int(ctx.number("ambience.seed", 7301))
	_hold_s = maxf(ctx.number("ambience.hold_s", _hold_s), 0.0)
	for id in BEDS:
		var b := Bed.new()
		b.id = id
		var e := ctx.assets.entry(FOLDER, id) if ctx.assets != null else null
		var stream: AudioStream = ctx.stream(FOLDER, id, "rain" if id == "rain" else "")
		b.has_sound = stream != null
		b.lufs = e.lufs if e != null else -24.0           # the Arcade rain loop: about -24 LUFS (stand-in only)
		if stream != null:
			b.player = ctx.player("MAmb", "Amb_" + id)
			if b.player != null:
				b.player.stream = stream
				b.player.volume_db = -80.0
		beds[id] = b
	if ctx.live:
		_vp = ModernAudioPan.make_viewport(ctx.host, "AmbienceCalls")
	if _vp != null:
		for i in CALL_VOICES:
			_call_players.append(ModernAudioPan.player(_vp, "MAmb", "AmbCall%d" % i))


func track_changed(_feed: AudioFeed) -> void:
	_call_last.clear()


## 0 day … 1 night for the life of the surroundings, from the hour and the daytime of the configuration (the hours
## of the picture's palette): night until dawn_start, the birds wake between dawn_start and sunrise (the dawn chorus
## starts before the sun), day until sunset, night again from sunset to night_start + 0.5 – smooth ramps.
func night_of(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	var dawn0 := float(_daytime.get("dawn_start", 5.0))
	var rise := float(_daytime.get("sunrise", 6.5))
	var sset := float(_daytime.get("sunset", 19.5))
	var night0 := float(_daytime.get("night_start", 20.5)) + 0.5
	if h < dawn0 or h >= night0:
		return 1.0
	if h < rise:
		return 1.0 - smoothstep(dawn0, rise, h)
	if h < sset:
		return 0.0
	return smoothstep(sset, night0, h)


## The dawn chorus: 1 from dawn_start to an hour after sunrise, else 0 (smooth edges).
func dawn_of(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	var dawn0 := float(_daytime.get("dawn_start", 5.0))
	var rise := float(_daytime.get("sunrise", 6.5))
	return smoothstep(dawn0 - 0.3, dawn0 + 0.4, h) * (1.0 - smoothstep(rise + 0.7, rise + 1.3, h))


## Speed fade in dB (<= 0) for a slope per decade above from_kmh.
func speed_db(slope: float, kmh: float) -> float:
	return -minf(slope * log(maxf(kmh, _from_kmh) / _from_kmh) / log(10.0), _max_fade_db)


## The target weights of the beds and the call rates (per minute) for this frame.
func compute(frame: ModernAudioFrame) -> void:
	var f := frame.feed
	var have := f != null and f.valid
	var tunnel := frame.tunnel
	var hour := float(frame.st("hour", 13.0)) if frame.has_state else 13.0
	night = night_of(hour)
	dawn = dawn_of(hour)
	var day := 1.0 - night
	var rain := clampf(frame.rain, 0.0, 1.0)
	var snow := clampf(f.snow, 0.0, 1.0) if have else 0.0
	if frame.has_state and str(frame.st("weather", "")) == "snow" and not tunnel:
		snow = maxf(snow, 1.0)
	var zone := f.zone if have else "open"
	var style := f.style if have else ""
	var climate := f.climate if have else "default"
	var features: PackedStringArray = f.features if have else PackedStringArray()
	var covered := 1.0 if (have and f.cover != "") else 0.0
	var outdoors := 0.0 if tunnel else 1.0
	city_w = 1.0 if zone == "city" or (have and f.city) else 0.0
	var nat := 1.0 - city_w
	water_w = 0.0
	if have and f.water:
		water_w = 1.0
	elif style == "coast":
		water_w = 0.6
	elif city_w > 0.0 and features.has("cranes"):
		water_w = 0.4
	var life := (1.0 - rain) * (1.0 - snow)            # insects and birds
	var hush := 1.0 - 0.45 * snow                      # snow: everything outdoors about 5 dB quieter
	var shade := 1.0 - 0.4 * covered                   # a canopy shields a little
	var w := {}
	var zk := {"forest": 0.4, "cutting": 0.6, "bridge": 1.2}
	w["breeze"] = (nat * float(zk.get(zone, 1.0)) + 0.25 * city_w) * hush
	var lk := {"forest": 1.0, "valley": 0.4}
	w["leaves"] = nat * float(lk.get(zone, 0.15)) * hush
	w["crickets"] = night * life * float(CLIMATE_CRICKETS.get(climate, 1.0)) * (nat + 0.3 * city_w)
	w["cicadas"] = day * life * (1.0 if climate == "mediterranean" else 0.0) * (nat + 0.4 * city_w)
	w["city_day"] = city_w * day * hush
	w["city_night"] = city_w * night * hush
	w["water"] = water_w * hush
	w["rain"] = rain
	for id: String in w:
		w[id] = float(w[id]) * outdoors * (shade if id != "rain" else 1.0)
	w["tunnel_fans"] = 1.0 if tunnel else 0.0
	w["hum"] = covered * outdoors
	weights = w
	# call rates per minute (configuration audio.modern.ambience.rates.<cat>: {day, night} per place weight)
	var r := {}
	var open_land := 1.0 if (zone == "open" or zone == "valley" or zone == "bridge") else 0.0
	var forest := 1.0 if zone == "forest" else 0.0
	var plain := 1.0 if (style == "plain" or style == "hills" or style == "") else 0.0
	var centre := 1.0 if (have and f.scenery.ends_with("_center")) else 0.0
	var chorus := 1.0 + 0.6 * dawn
	r["bird"] = _rate("bird", day * life * chorus * (open_land * 7.0 + forest * 12.0 + (1.0 - open_land - forest) * nat * 4.0))
	r["crow"] = _rate("crow", day * (1.0 - rain) * nat * 1.2)
	r["skylark"] = _rate("skylark", day * life * open_land * plain * 0.8)
	r["woodpecker"] = _rate("woodpecker", day * life * forest * 0.8)
	r["owl"] = _rate("owl", night * (1.0 - rain) * (forest * 1.0 + open_land * 0.4))
	r["dog"] = _rate("dog", (0.4 * night + 0.15 * day) * (1.0 - rain) * nat)
	r["sparrow"] = _rate("sparrow", day * (1.0 - rain) * (1.0 - snow) * city_w * 4.0)
	r["pigeon"] = _rate("pigeon", day * (1.0 - rain) * city_w * 1.5)
	r["horn"] = _rate("horn", city_w * (1.2 * day + 0.4 * night))
	r["bell"] = _rate("bell", city_w * centre * (0.35 * day + 0.1 * night))
	r["scooter"] = _rate("scooter", city_w * (0.8 * day + 0.4 * night) * (2.0 if climate == "mediterranean" else 1.0) * (1.0 - rain))
	r["gull"] = _rate("gull", water_w * (day + 0.3 * night) * (1.0 - 0.5 * rain) * 5.0)
	r["ship"] = _rate("ship", (1.0 if water_w > 0.3 else 0.0) * 0.25)
	for c: String in r:
		r[c] = float(r[c]) * outdoors * (1.0 - 0.5 * covered)
	rates = r


func _rate(cat: String, default_per_min: float) -> float:
	var k: Variant = _rates_cfg.get(cat, null)
	return default_per_min * (float(k) if (k is float or k is int) else 1.0)


func update(frame: ModernAudioFrame) -> void:
	# A running stage: the session drives the car or sends its state. ModernAudio reports neither while the game is
	# paused (and for a frame after a long hitch, docs "Fallen" 15) – the stage still runs then: the beds go on with the
	# weights they had (no feed to compute new ones), only hold_s without a stage outside a pause end them.
	var running := frame.alive or frame.has_state
	if running:
		_off_s = 0.0
		_was_running = true
	elif not frame.paused:
		_off_s += frame.dt
		if _off_s >= _hold_s:
			_was_running = false
	_on = running or _was_running
	if running or not _was_running:
		compute(frame)
	var v := maxf(frame.speed, 0.0)
	if frame.tunnel != _was_tunnel:
		_fast_s = _fast_hold_s          # into or out of a tunnel: the beds follow quickly, not only in this frame
	_was_tunnel = frame.tunnel
	_fast_s = maxf(_fast_s - frame.dt, 0.0)
	var tau := _tunnel_fade_s if (frame.tunnel or _fast_s > 0.0) else _fade_s
	var k := 1.0 - exp(-frame.dt / tau)
	var pause_k := db_to_linear(_pause_db) if frame.paused else 1.0
	for id: String in beds:
		var b: Bed = beds[id]
		b.target = float(weights.get(id, 0.0)) if _on else 0.0
		if frame.tunnel and id != "tunnel_fans" and id != "rain":
			b.weight = lerpf(b.weight, b.target, 1.0 - exp(-frame.dt / _tunnel_fade_s))
		else:
			b.weight = lerpf(b.weight, b.target, k)
		var db := float(_bed_lufs.get(id, -40.0)) - b.lufs - _ref_path_db + speed_db(float(_bed_slope.get(id, 10.0)), v)
		b.gain = db_to_linear(db) * b.weight * pause_k
		_drive(b)
	if _on and not frame.paused and v < _calls_max_kmh:
		for c: String in rates:
			var per_s := float(rates[c]) / 60.0
			if per_s > 0.0 and _rng.randf() < per_s * frame.dt:
				_call(c, v)


func _drive(b: Bed) -> void:
	if b.player == null:
		return
	if b.gain < 0.0005:
		if b.player.playing:
			b.player.stop()
		return
	if not b.player.playing:
		var len_s := b.player.stream.get_length() if b.player.stream != null else 0.0
		b.player.play(_rng.randf() * len_s * 0.95)
	b.player.volume_db = linear_to_db(b.gain)


## Starts a call of a category: sound by weight, variant (not the last one again), distance (0 … −spread dB), side,
## pitch ± call_pitch. The level follows the speed like the beds (slope of the breeze).
func _call(cat: String, kmh: float) -> void:
	var opts: Array = CALL_SOUNDS.get(cat, [])
	if opts.is_empty() or ctx.assets == null:
		return
	var total := 0.0
	for o: Array in opts:
		total += float(o[1])
	var x := _rng.randf() * total
	var id := str((opts[0] as Array)[0])
	for o: Array in opts:
		x -= float(o[1])
		if x <= 0.0:
			id = str(o[0])
			break
	var e := ctx.assets.entry(FOLDER, id)
	if e == null:
		return
	var n := e.files.size()
	var variant := RoadAudio.pick_variant(_rng, n, int(_call_last.get(id, -1)))
	_call_last[id] = variant
	var lufs_m := e.lufs
	var m: Variant = e.meta.get("lufs_m", null)
	if m is Array and variant < (m as Array).size():
		lufs_m = float(m[variant])
	var dist_db := -_rng.randf() * _call_spread_db
	var db := float(_call_lufs.get(cat, -40.0)) + dist_db - lufs_m - _ref_path_db \
		+ speed_db(float(_bed_slope.get("breeze", 10.0)), kmh)
	var pan := _rng.randf_range(-0.9, 0.9)
	var pitch := 1.0 + _rng.randf_range(-_call_pitch, _call_pitch)
	calls_played += 1
	last_call = {"id": id, "variant": variant, "category": cat, "db": db, "pan": pan, "pitch": pitch}
	var pl := free_voice(_call_players)
	if pl == null:
		return
	pl.stream = ctx.assets.stream(FOLDER, id, variant)
	pl.pitch_scale = pitch
	if ModernAudioPan.apply(pl, db_to_linear(db), pan):
		pl.play()


## A player for a one-shot: a silent one, else the one with the least left to play (a long bell is not cut by the
## next sparrow). null without players.
static func free_voice(players: Array[AudioStreamPlayer2D]) -> AudioStreamPlayer2D:
	var best: AudioStreamPlayer2D = null
	var best_left := INF
	for p in players:
		if p == null:
			continue
		if not p.playing:
			return p
		var left := INF
		if p.stream != null:
			left = (p.stream.get_length() - p.get_playback_position()) / maxf(p.pitch_scale, 0.01)
		if left < best_left:
			best_left = left
			best = p
	return best


func stop_all() -> void:
	_was_running = false
	_off_s = _hold_s
	for id: String in beds:
		var b: Bed = beds[id]
		b.weight = 0.0
		b.gain = 0.0
		if b.player != null and b.player.playing:
			b.player.stop()
	for p in _call_players:
		if p != null:
			p.stop()


func teardown() -> void:
	for id: String in beds:
		ModernAudioContext.free_player((beds[id] as Bed).player)
	beds.clear()
	for p in _call_players:
		ModernAudioPan.free_player(p)
	_call_players.clear()
	if _vp != null and is_instance_valid(_vp):
		_vp.queue_free()
	_vp = null


func debug_state() -> Dictionary:
	var g := {}
	for id: String in beds:
		var b: Bed = beds[id]
		if b.gain > 0.0005:
			g[id] = snappedf(linear_to_db(b.gain), 0.01)
	var rain_level := (beds["rain"] as Bed).weight if beds.has("rain") else 0.0
	return {"rain": rain_level, "beds": g, "night": night, "calls": calls_played, "city": city_w, "water": water_w}
