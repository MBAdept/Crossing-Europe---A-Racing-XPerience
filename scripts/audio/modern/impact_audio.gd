class_name ImpactAudio
extends ModernAudioModule
## Slot "impact" of the Modern sound (package AU-C1, contract §4.7.2; docs/audio-modern.md "Fahrbahn, Wind,
## Aufprall"): collisions, the guardrail and knocked delineators on the bus MImpact (→ MEnv). It claims the session
## events "collision" and "rail_hit" (claims()), so the plain play("crash") / play("rail") of the same moment is
## dropped by ModernAudio and only the layered Modern sound is heard; a play() without its event (another caller)
## still sounds – as the medium collision or the guardrail hit of its gain.
##
##   collision   {speed_kmh, rel_kmh, heavy, side}: layers by closing speed (|rel_kmh|; tiers light / medium /
##               heavy at impact.collision.tiers_kmh) – bumper thud and plastic, the deep punch of the body, sheet
##               metal folding, glass, debris – plus the boom of a truck or bus body when the partner is heavy;
##               panned to the side of the other car; each layer a little louder or quieter with the closing speed
##               around the tier's reference (slope_db per decade, at most max_db)
##   rail_hit    {impact_mps, side}: a hard hit with the ringing W-beam from impact.rail.hard_mps on, below it a graze
##   scrape      a loop of sheet metal grinding along the rail while frame.state.rail_contact, at the rail's side,
##               louder and higher with the speed
##   post        a delineator post the body knocks down (feed event "pass_object" with contact)
## Levels are data (audio.modern.impact): one-shots as sample peak at the master (the files peak at file_peak_db),
## the scrape loop as loudness at the master. Without a Modern file the Arcade stream of AudioManager plays with the
## Arcade level (LEVEL_DB, the wave-0 stand-in).

const FOLDER := "sfx"
const LOOPS := "vehicle"
const LEVEL_DB := {"crash": -1.0, "rail": -5.0}   ## as AudioManager.ONESHOT_DB (the Arcade fallback)
const TIERS: Array[String] = ["light", "medium", "heavy"]
const PANNED_VOICES := 8
const SCRAPE_SMOOTH_S := 0.05

var voices := ModernAudioVoices.new()    ## centred players: the Arcade fallback streams
var counts: Dictionary = {}              ## sound or event -> times sounded (tests)
var events: Dictionary = {}              ## event name -> count (tests)
var last_layers: Array = []              ## [[sound id, variant, gain dB, pan], …] of the last impact (tests)
var scrape_level := 0.0                  ## smoothed gain of the scrape loop
var scrape_pan := 0.0

var _ref_path_db := -1.94
var _pan := 0.7
var _file_peak_db := -3.0
var _tiers := Vector2(15.0, 45.0)
var _coll_slope := 10.0
var _coll_max := 4.0
var _tier_cfg: Dictionary = {}
var _truck_db: Dictionary = {}
var _rail_hit_db := -9.0
var _rail_touch_db := -17.0
var _rail_hard := 1.2
var _rail_ref := 3.0
var _rail_slope := 10.0
var _rail_max := 4.0
var _scrape_lufs := -21.0
var _scrape_slope := 12.0
var _scrape_max := -17.0
var _scrape_min := 5.0
var _post_db := -15.0
var _post_ref := 80.0
var _post_slope := 20.0

var _vp: SubViewport = null
var _panned: Array[AudioStreamPlayer2D] = []
var _next := 0
var _rng := RandomNumberGenerator.new()
var _variant: Dictionary = {}            ## sound id -> next variant
var _speed := 0.0
var _on := false
var _driven := false
var _scrape: AudioStreamPlayer2D = null
var _scrape_entry: ModernAudioAssets.Entry = null


func _setup() -> void:
	_ref_path_db = ctx.number("impact.ref_path_db", _ref_path_db)
	_pan = clampf(ctx.number("impact.pan", _pan), 0.0, 1.0)
	_file_peak_db = ctx.number("impact.file_peak_db", _file_peak_db)
	var t: Variant = ctx.value("impact.collision.tiers_kmh", null)
	if t is Array and (t as Array).size() == 2:
		_tiers = Vector2(float(t[0]), float(t[1]))
	_coll_slope = ctx.number("impact.collision.slope_db", _coll_slope)
	_coll_max = maxf(ctx.number("impact.collision.max_db", _coll_max), 0.0)
	for tier: String in TIERS:
		var d: Variant = ctx.value("impact.collision." + tier, {})
		_tier_cfg[tier] = d if d is Dictionary else {}
	var tr: Variant = ctx.value("impact.collision.truck", {})
	_truck_db = tr if tr is Dictionary else {}
	_rail_hit_db = ctx.number("impact.rail.hit_peak_db", _rail_hit_db)
	_rail_touch_db = ctx.number("impact.rail.touch_peak_db", _rail_touch_db)
	_rail_hard = ctx.number("impact.rail.hard_mps", _rail_hard)
	_rail_ref = maxf(ctx.number("impact.rail.ref_mps", _rail_ref), 0.1)
	_rail_slope = ctx.number("impact.rail.slope_db", _rail_slope)
	_rail_max = maxf(ctx.number("impact.rail.max_db", _rail_max), 0.0)
	_scrape_lufs = ctx.number("impact.rail.scrape_lufs", _scrape_lufs)
	_scrape_slope = ctx.number("impact.rail.scrape_slope_db", _scrape_slope)
	_scrape_max = ctx.number("impact.rail.scrape_max_lufs", _scrape_max)
	_scrape_min = ctx.number("impact.rail.scrape_min_kmh", _scrape_min)
	_post_db = ctx.number("impact.post.peak_db", _post_db)
	_post_ref = maxf(ctx.number("impact.post.ref_kmh", _post_ref), 1.0)
	_post_slope = ctx.number("impact.post.slope_db", _post_slope)
	_rng.seed = 60917
	voices.attach(ctx, "MImpact", 2, "Impact")
	if ctx.live:
		_vp = ModernAudioPan.make_viewport(ctx.host, "ImpactVoices")
		for i in PANNED_VOICES:
			var p := ModernAudioPan.player(_vp, "MImpact", "ImpactPanned%d" % i)
			if p != null:
				_panned.append(p)
	_scrape_entry = ctx.assets.entry(LOOPS, "rail_scrape") if ctx.assets != null else null
	if _scrape_entry != null and _vp != null:
		_scrape = ModernAudioPan.player(_vp, "MImpact", "RailScrape")
		if _scrape != null:
			_scrape.stream = ctx.stream(LOOPS, "rail_scrape")


func claims() -> PackedStringArray:
	return PackedStringArray(["collision", "rail_hit"])


static func _log10(x: float) -> float:
	return log(maxf(x, 1.0e-9)) / log(10.0)


## Tier of a closing speed (km/h): "light", "medium" or "heavy".
func tier_of(closing_kmh: float) -> String:
	if closing_kmh < _tiers.x:
		return "light"
	return "medium" if closing_kmh < _tiers.y else "heavy"


## The layers of a collision: [[sound id, peak dB at the master], …].
func collision_layers(closing_kmh: float, heavy: bool) -> Array:
	var tier := tier_of(closing_kmh)
	var cfg: Dictionary = _tier_cfg.get(tier, {})
	var ref := maxf(float(cfg.get("ref_kmh", 30.0)), 1.0)
	var adj := clampf(_coll_slope * _log10(maxf(closing_kmh, 1.0) / ref), -_coll_max, _coll_max)
	var out: Array = []
	var truck := heavy and _truck_db.has(tier)
	var layers: Variant = cfg.get("layers", {})
	if layers is Dictionary:
		var ids: Array = (layers as Dictionary).keys()
		ids.sort()
		for id: String in ids:
			# against a truck or bus its body's boom is the low punch (two punches at once would only add up to a
			# peak – measured in the worst case: the master limiter took 4.8 dB)
			if truck and id == "hit_heavy":
				continue
			out.append([id, float(layers[id]) + adj])
	if truck:
		out.append(["truck_boom", float(_truck_db[tier]) + adj])
	return out


func update(frame: ModernAudioFrame) -> void:
	_driven = EngineAudio3.driven(frame, _driven)
	_on = _driven and not frame.effects_muted
	_speed = frame.speed if _on else 0.0
	# the scrape loop while the car touches the guardrail
	var st := frame.state if frame.has_state else {}
	var touching := _on and bool(st.get("rail_contact", false)) and _speed >= _scrape_min
	var target := 0.0
	var pitch := 1.0
	if _scrape_entry != null:
		var ref := float(_scrape_entry.meta.get("ref_kmh", 100.0))
		pitch = clampf(pow(maxf(_speed, 1.0) / maxf(ref, 1.0), float(_scrape_entry.meta.get("pitch_exp", 0.35))), 0.3, 2.5)
		if touching:
			var centre := (float(st.get("road_left", -5.625)) + float(st.get("road_right", 5.625))) * 0.5
			scrape_pan = (-1.0 if float(st.get("x", 0.0)) < centre else 1.0) * _pan
			var lufs := _curve_lufs(_scrape_entry, pitch)
			var level := minf(_scrape_lufs + _scrape_slope * _log10(_speed / ref), _scrape_max)
			target = db_to_linear(level - lufs - _ref_path_db)
	var k := 1.0 - exp(-minf(maxf(frame.dt, 0.0001), 0.1) / SCRAPE_SMOOTH_S)
	scrape_level = lerpf(scrape_level, target, k)
	if _scrape != null:
		if scrape_level < ModernAudioPan.SILENT:
			if _scrape.playing:
				_scrape.stop()
		else:
			ModernAudioPan.apply(_scrape, scrape_level, scrape_pan)
			if absf(_scrape.pitch_scale - pitch) > 0.0005:
				_scrape.pitch_scale = pitch
			if not _scrape.playing:
				_scrape.play(_rng.randf() * 1.5)


## Loudness of a loop at a pitch (manifest lufs_pitch; its loudness at pitch 1 without it).
static func _curve_lufs(e: ModernAudioAssets.Entry, p: float) -> float:
	var c: Variant = e.meta.get("lufs_pitch", [])
	if not (c is Array) or (c as Array).size() < 2:
		return e.lufs
	var curve: Array = c
	var lp := log(maxf(p, 0.01))
	if lp <= log(float(curve[0][0])):
		return float(curve[0][1])
	for i in range(1, curve.size()):
		var a := log(float(curve[i][0]))
		if lp <= a:
			var a0 := log(float(curve[i - 1][0]))
			return lerpf(float(curve[i - 1][1]), float(curve[i][1]), (lp - a0) / maxf(a - a0, 1.0e-6))
	return float(curve[curve.size() - 1][1])


func event(event_name: String, args: Dictionary) -> void:
	match event_name:
		"collision":
			events[event_name] = int(events.get(event_name, 0)) + 1
			var closing := absf(float(args.get("rel_kmh", 0.3 * float(args.get("speed_kmh", 60.0)))))
			_collision(closing, bool(args.get("heavy", false)), int(args.get("side", 0)), 0.0)
		"rail_hit":
			events[event_name] = int(events.get(event_name, 0)) + 1
			_rail(float(args.get("impact_mps", 0.0)), int(args.get("side", 0)), 0.0)
		"pass_object":
			if bool(args.get("contact", false)) and _on:
				events["post_hit"] = int(events.get("post_hit", 0)) + 1
				var db := _post_db + _post_slope * _log10(maxf(_speed, 5.0) / _post_ref)
				last_layers = []
				_layer("post_hit", db, float(int(args.get("side", 0))) * _pan, 1.0)


## play("crash") / play("rail") whose event did not come within 50 ms (ModernAudio): the medium collision, the
## guardrail by the gain the caller gives (the race session: −10 + 2 × impact m/s).
func play(sound: String, gain_db: float) -> bool:
	if not LEVEL_DB.has(sound):
		return false
	counts[sound] = int(counts.get(sound, 0)) + 1
	if sound == "crash":
		if not _collision(_tiers.x + 0.5 * (_tiers.y - _tiers.x), false, 0, 0.0):
			voices.play(ctx.stream(FOLDER, sound, sound), float(LEVEL_DB[sound]) + gain_db)
	elif not _rail(clampf((gain_db + 10.0) * 0.5, 0.0, 6.0), 0, 0.0):
		voices.play(ctx.stream(FOLDER, sound, sound), float(LEVEL_DB[sound]) + gain_db)
	return true


## The layers of a collision; false when no Modern sound exists (the caller takes the Arcade stream).
func _collision(closing: float, heavy: bool, side: int, extra_db: float) -> bool:
	var layers := collision_layers(closing, heavy)
	last_layers = []
	var any := false
	var pan := float(side) * _pan
	for row: Array in layers:
		any = _layer(str(row[0]), float(row[1]) + extra_db, pan, _rng.randf_range(0.96, 1.04)) or any
	if any:
		counts["collision_" + tier_of(closing)] = int(counts.get("collision_" + tier_of(closing), 0)) + 1
	return any


func _rail(impact_mps: float, side: int, extra_db: float) -> bool:
	var hard := impact_mps >= _rail_hard
	var id := "rail_hit" if hard else "rail_touch"
	var base := _rail_hit_db if hard else _rail_touch_db
	var adj := clampf(_rail_slope * _log10(maxf(impact_mps, 0.1) / _rail_ref), -_rail_max, _rail_max) if hard else 0.0
	last_layers = []
	return _layer(id, base + adj + extra_db, float(side) * _pan, _rng.randf_range(0.97, 1.03))


## One layer: the next variant of a Modern one-shot at a sample peak of `peak_db` at the master, panned.
func _layer(id: String, peak_db: float, pan: float, pitch: float) -> bool:
	var e := ctx.assets.entry(FOLDER, id) if ctx.assets != null else null
	if e == null:
		return false
	var n := e.files.size()
	var v := int(_variant.get(id, 0)) % maxi(n, 1)
	_variant[id] = v + 1
	var db := peak_db - _file_peak_db - _ref_path_db
	last_layers.append([id, v, snappedf(db, 0.01), pan])
	counts[id] = int(counts.get(id, 0)) + 1
	if _panned.is_empty():
		return true
	var pl := _panned[_next]
	_next = (_next + 1) % _panned.size()
	pl.stream = ctx.assets.stream(FOLDER, id, v)
	pl.pitch_scale = pitch
	ModernAudioPan.apply(pl, db_to_linear(db), pan)
	pl.play()
	return true


func stop_all() -> void:
	voices.stop_all()
	for p in _panned:
		p.stop()
	scrape_level = 0.0
	if _scrape != null:
		_scrape.stop()
	_on = false
	_driven = false


func teardown() -> void:
	voices.release()
	for p in _panned:
		ModernAudioPan.free_player(p)
	_panned.clear()
	ModernAudioPan.free_player(_scrape)
	_scrape = null
	if _vp != null and is_instance_valid(_vp):
		_vp.queue_free()
	_vp = null


func debug_state() -> Dictionary:
	var busy := voices.busy()
	for p in _panned:
		busy += 1 if p.playing else 0
	return {"plays": counts.duplicate(), "events": events.duplicate(), "busy": busy, "scrape": scrape_level,
		"last": last_layers.duplicate(true)}
