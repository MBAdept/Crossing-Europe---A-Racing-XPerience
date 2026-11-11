extends TestCase
## AU-C1: the slots "road" (RoadAudio) and "impact" (ImpactAudio) without players – the loudness plan of the contract
## at the car's top speed (wind 3 dB, tyres 4 dB under the full-throttle loudness), the speed laws, surfaces per side,
## wet road, squeal and scrub, concrete slabs, bridge joints with the exact axle gap, passed objects, wind zones and
## fades; collisions by closing speed and partner, the guardrail, the scrape loop, knocked delineators. The loudness
## of a layer is computed back from its gains and the loudness curve of its file (manifest lufs_pitch).

const DT := 1.0 / 60.0


func _merge(into: Dictionary, over: Dictionary) -> void:
	for k: String in over:
		if over[k] is Dictionary and into.get(k, null) is Dictionary:
			_merge(into[k], over[k])
		else:
			into[k] = over[k]


func _modern(over: Dictionary = {}) -> ModernAudio:
	var c := cfg().duplicate(true)
	_merge(c["audio"]["modern"], over)
	var m := ModernAudio.new()
	m.clock_ms = 1000
	m.start(c, {"live": false, "quiet": true})
	return m


func _done(m: ModernAudio) -> void:
	m.shutdown()
	m.free()


func _num(path: String) -> float:
	return float(ConfigLoader.lookup(cfg(), "audio.modern." + path, 0.0))


## A frame of a driven car on a road the feed describes.
func _frame(speed: float, feed: Dictionary = {}, state: Dictionary = {}) -> ModernAudioFrame:
	var f := ModernAudioFrame.new()
	f.dt = DT
	f.alive = true
	f.speed = speed
	f.wind_speed = speed
	f.vmax = 230.0
	var fd := AudioFeed.new()
	fd.valid = true
	for k: String in feed:
		fd.set(k, feed[k])
	f.feed = fd
	if not state.is_empty():
		f.has_state = true
		f.state = state
	return f


func _run(m: ModernAudio, f: ModernAudioFrame, n: int) -> void:
	for i in n:
		m.road.update(f)
		m.impact.update(f)


## Loudness at the master of a layer from its gains (each player adds its power, with the loudness curve of its
## own loop at its own pitch).
func _lufs(l: RoadAudio.Layer) -> float:
	var e := 0.0
	for i in l.gains.size():
		e += l.gains[i] * l.gains[i] * pow(10.0, l.lufs_at(l.pitch * l.ratios[i], i) / 10.0)
	if e <= 0.0:
		return -200.0
	return 10.0 * log(e) / log(10.0) + _num("road.ref_path_db")


## Loudness of one side (player i) of a layer.
func _lufs_side(l: RoadAudio.Layer, i: int) -> float:
	var g := l.gains[i]
	if g <= 0.0:
		return -200.0
	return l.lufs_at(l.pitch * l.ratios[i], i) + 20.0 * log(g) / log(10.0) + _num("road.ref_path_db")


## The plan without the random parts (gusts, side drift): levels exact to the hundredth.
const STILL := {"road": {"wind": {"gust_db": 0.0}, "sides": {"drift_db": 0.0}}}


func _sum(values: Array) -> float:
	var e := 0.0
	for v: float in values:
		e += pow(10.0, v / 10.0)
	return 10.0 * log(maxf(e, 1.0e-20)) / log(10.0)


func _wind_total(r: RoadAudio) -> float:
	var parts: Array = []
	for w: String in RoadAudio.WIND_LOOPS:
		parts.append(_lufs(r.winds[w]))
	return _sum(parts)


func test_the_loudness_plan_at_top_speed() -> void:
	var m := _modern(STILL.duplicate(true))
	var r := m.road
	r.set_vehicle("kompakt")
	assert_near(r.vmax_kmh, 230.0, 0.01, "Höchsttempo des Kompakten aus der Konfiguration")
	var table: Variant = ConfigLoader.lookup(cfg(), "audio.modern.road.engine_top_lufs", {})
	var ref := float((table as Dictionary).get("kompakt", _num("loudness.full_throttle_lufs"))) if table is Dictionary else _num("loudness.full_throttle_lufs")
	assert_near(r.engine_ref_lufs, ref, 1.0e-6, "Bezug: der Motor des Kompakten bei Höchsttempo (gemessen, Konfiguration)")
	_run(m, _frame(230.0, {"surface_l": "asphalt", "surface_r": "asphalt", "zone": "open"}), 120)
	var tyres := _lufs(r.surfaces["asphalt"])
	var wind := _wind_total(r)
	assert_near(tyres, ref - _num("road.tyres.under_engine_db"), 0.05, "Reifen bei Höchsttempo %.2f LUFS: 4 dB unter dem Motor" % tyres)
	assert_near(wind, ref - _num("road.wind.under_engine_db"), 0.05, "Wind bei Höchsttempo %.2f LUFS: 3 dB unter dem Motor" % wind)
	assert_true(r.winds["wind_buffet"].level > 0.0, "Wummern bei Höchsttempo")
	# the same plan for a faster car at its own top speed
	r.set_vehicle("gran_turismo")
	var ref_gt := r.engine_ref_lufs
	_run(m, _frame(270.0, {"surface_l": "asphalt", "surface_r": "asphalt"}), 120)
	assert_near(_lufs(r.surfaces["asphalt"]), ref_gt - 4.0, 0.05, "Gran Turismo: Reifen bei seinem Höchsttempo")
	assert_near(_wind_total(r), ref_gt - 3.0, 0.05, "Gran Turismo: Wind bei seinem Höchsttempo")
	# a car without an entry: the plan's full-throttle loudness
	r.set_vehicle("gibtsnicht")
	assert_near(r.engine_ref_lufs, float((table as Dictionary).get("_", _num("loudness.full_throttle_lufs"))), 1.0e-6, "ohne Eintrag: der Plan")
	_done(m)


func test_the_speed_laws() -> void:
	var m := _modern(STILL.duplicate(true))
	var r := m.road
	r.set_vehicle("kompakt")
	_run(m, _frame(115.0), 120)
	assert_near(_lufs(r.surfaces["asphalt"]), r.engine_ref_lufs - 4.0 + 30.0 * log(0.5) / log(10.0), 0.05, "Reifen: 30 dB je Dekade")
	assert_near(_lufs(r.winds["wind_low"]), float(r._wind_band_top["wind_low"]) + 55.0 * log(0.5) / log(10.0), 0.05, "Wind: 55 dB je Dekade")
	assert_near(r.winds["wind_buffet"].level, 0.0, 1.0e-6, "kein Wummern bei halbem Höchsttempo")
	assert_true(r.surfaces["asphalt"].pitch < r.surfaces["asphalt"].pitch_for(230.0), "langsamer: tiefer")
	# standing: silent; a car rolling at walking pace hardly
	_run(m, _frame(0.0), 120)
	assert_true(r.surfaces["asphalt"].level < 0.001 and r.wind.level < 0.001, "im Stand still")
	_run(m, _frame(10.0), 120)
	assert_true(r.wind.level < 0.001, "kein Wind unter 20 km/h")
	assert_true(r.surfaces["asphalt"].level > 0.0, "Rollen ab Schrittempo")
	_done(m)


func test_surfaces_per_side_wet_and_snow() -> void:
	var m := _modern(STILL.duplicate(true))
	var r := m.road
	r.set_vehicle("limousine")
	_run(m, _frame(120.0, {"surface_l": "asphalt", "surface_r": "rumble"}), 60)
	var a: RoadAudio.Layer = r.surfaces["asphalt"]
	var rb: RoadAudio.Layer = r.surfaces["rumble"]
	assert_true(a.gains[0] > 0.01 and a.gains[1] < 1.0e-4, "Asphalt nur links")
	assert_true(rb.gains[1] > 0.01 and rb.gains[0] < 1.0e-4, "Rüttelstreifen nur rechts")
	assert_true(rb.pans[1] > 0.0 and rb.pans[0] < 0.0, "rechter Spieler rechts")
	assert_near(rb.pitch, 120.0 / 108.0, 1.0e-4, "Schlagfolge proportional zum Tempo")
	var l_rumble := _lufs(rb)
	var expect := r.engine_ref_lufs - 4.0 + _num("road.tyres.surface_db.rumble") \
		+ _num("road.tyres.slope_by_surface.rumble") * log(120.0 / 245.0) / log(10.0) - 3.0103
	assert_near(l_rumble, expect, 0.05, "eine Seite auf dem Rüttelstreifen: 3 dB unter beiden")
	# the wet road hisses on what is paved, not on grass
	_run(m, _frame(120.0, {"surface_l": "asphalt", "surface_r": "asphalt", "wet": 1.0}), 60)
	assert_true(r.wet.level > 0.01, "nasse Fahrbahn zischt")
	_run(m, _frame(120.0, {"surface_l": "grass", "surface_r": "grass", "wet": 1.0}), 120)
	assert_true(r.wet.level < 1.0e-3, "auf Gras kein Sprühzischen")
	assert_true(r.surfaces["grass"].level > 0.01, "Gras rumpelt")
	# without a feed: dry asphalt, the rain of the old calls
	var f := _frame(120.0)
	f.feed.valid = false
	f.rain = 1.0
	_run(m, f, 120)
	assert_true(r.surfaces["asphalt"].level > 0.01 and r.wet.level > 0.01, "ohne Strecke: Asphalt und Regen aus set_rain()")
	# snow: quieter rolling and a crunch of its own (AU-R: no longer the gravel loop with its stones)
	_run(m, _frame(80.0, {"surface_l": "asphalt", "surface_r": "asphalt"}), 120)
	var dry := _lufs(r.surfaces["asphalt"])
	_run(m, _frame(80.0, {"surface_l": "asphalt", "surface_r": "asphalt", "snow": 1.0}), 200)
	assert_near(r.snow_amount, 1.0, 1.0e-6, "Schnee eingeblendet")
	assert_near(_lufs(r.surfaces["asphalt"]) - dry, _num("road.tyres.snow_db"), 0.05, "Schnee dämpft das Rollen")
	assert_true(r.snow.level > 0.0 and r.snow.own_loops, "und knirscht – eigene Schleife je Seite")
	assert_true(r.surfaces["shoulder"].level < 1.0e-4, "kein Schotter im Schnee")
	var crunch := r.engine_ref_lufs - 4.0 + _num("road.tyres.surface_db.snow") + _num("road.tyres.slope_by_surface.snow") \
		* log(80.0 / 245.0) / log(10.0) + _num("road.tyres.snow_db") + 20.0 * log(_num("road.tyres.snow_crunch")) / log(10.0)
	assert_near(_lufs(r.snow), crunch, 0.05, "Knirschen so laut wie bisher das Schotter-Knirschen")
	_done(m)


func test_squeal_and_scrub() -> void:
	var m := _modern()
	var r := m.road
	r.set_vehicle("kombi")
	_run(m, _frame(110.0, {}, {"understeer": 0.8, "lat_speed": 0.0}), 60)
	var dry := r.squeal.level
	assert_true(dry > 0.01, "Untersteuern quietscht")
	_run(m, _frame(110.0, {"wet": 1.0}, {"understeer": 0.8}), 120)
	assert_true(r.squeal.level < dry * 0.5, "nass quietscht es kaum")
	assert_true(r.scrub.level > 0.01, "dafür radiert es")
	_run(m, _frame(110.0, {"surface_l": "shoulder", "surface_r": "shoulder"}, {"understeer": 0.8}), 120)
	assert_true(r.squeal.level < dry * 0.3, "auf Schotter kein Quietschen")
	_run(m, _frame(110.0, {}, {"understeer": 0.0, "crash": true}), 60)
	assert_true(r.scrub.level > 0.01, "Rutschen beim Unfall")
	_run(m, _frame(110.0, {}, {"understeer": 0.0, "lat_speed": 0.5}), 120)
	assert_true(r.squeal.level < 1.0e-3 and r.scrub.level < 1.0e-3, "geradeaus still")
	_run(m, _frame(10.0, {}, {"understeer": 1.0}), 120)
	assert_true(r.squeal.level < 1.0e-3, "unter 15 km/h kein Quietschen")
	# without a vehicle state: the old set_skid() / HUD hint
	var f := _frame(100.0)
	f.skid = 0.7
	_run(m, f, 60)
	assert_true(r.skid.level > 0.01, "frame.skid ohne Fahrzeugzustand")
	_done(m)


func test_concrete_slabs_keep_their_rhythm() -> void:
	var m := _modern()
	var r := m.road
	r.set_vehicle("limousine")
	_run(m, _frame(90.0, {"surface_l": "concrete", "surface_r": "concrete", "paving": "concrete"}), 120)
	assert_near(r.slab_slow.pitch, 1.0, 1.0e-4, "bei 90 km/h die Fugenfolge wie entworfen")
	assert_true(r.slab_slow.level > 0.0 and r.slab_fast.level < 1.0e-4, "langsames Muster")
	var expect := r.engine_ref_lufs - 4.0 + _num("road.slabs.db") + _num("road.slabs.slope_db") * log(90.0 / 245.0) / log(10.0)
	assert_near(_lufs(r.slab_slow), expect, 0.05, "Pegel der Fugen")
	_run(m, _frame(200.0, {"surface_l": "concrete", "surface_r": "concrete"}), 120)
	assert_near(r.slab_fast.pitch, 200.0 / 180.0, 1.0e-4, "bei 200 km/h das schnelle Muster, Tonhöhe v / 180")
	assert_true(r.slab_slow.level < 1.0e-4, "langsames Muster aus")
	_run(m, _frame(200.0, {"surface_l": "asphalt", "surface_r": "asphalt"}), 120)
	assert_true(r.slab_fast.level < 1.0e-4, "auf Asphalt keine Plattenfugen")
	_done(m)


func test_bridge_joints_with_the_exact_axle_gap() -> void:
	var m := _modern()
	var r := m.road
	r.set_vehicle("kompakt")
	assert_near(r.wheelbase_m, 0.6 * 4.1, 1.0e-6, "Radstand aus der Länge")
	for kmh: float in [40.0, 80.0, 120.0, 200.0, 260.0]:
		_run(m, _frame(kmh), 2)
		r.event("joint", {"kind": "bridge", "deck": "steel", "z": 10.0})
		var j := r.last_joint
		var gaps: Array = m.assets.entry("sfx", "joint_steel").meta["gaps_s"]
		var gap := r.wheelbase_m / (kmh / 3.6)
		var played_gap := float(gaps[int(j["variant"])]) / float(j["pitch"])
		if float(j["pitch"]) > 0.7001 and float(j["pitch"]) < 1.4499:
			assert_near(played_gap, gap, 1.0e-5, "%d km/h: Achsabstand %.3f s getroffen" % [int(kmh), gap])
		assert_eq(str(j["id"]), "joint_steel", "Stahldeck")
	var n := int(r.played["joint"])
	r.event("joint", {"kind": "bridge_end", "deck": "concrete"})
	assert_eq(str(r.last_joint["id"]), "joint_concrete", "Betondeck")
	assert_eq(int(r.played["joint"]), n + 1, "gespielt")
	_run(m, _frame(10.0), 2)
	r.event("joint", {"kind": "bridge", "deck": "steel"})
	assert_eq(int(r.played["joint"]), n + 1, "unter 15 km/h nichts")
	assert_eq(r.joints, 7, "jede Fuge gezählt")
	_done(m)


func test_passed_objects() -> void:
	var m := _modern()
	var r := m.road
	r.set_vehicle("kompakt")
	_run(m, _frame(100.0), 2)
	r.event("pass_object", {"kind": "post", "side": 1, "dist_m": 4.0, "size": 0.3})
	var t100 := float(r.last_pass["target"])
	assert_near(t100, _num("road.passes.lufs") + 20.0 * log(0.3) / log(10.0) - 20.0 * log(4.0 / 3.0) / log(10.0), 0.01, "Pegel nach Größe und Abstand")
	assert_true(float(r.last_pass["pan"]) > 0.0, "rechts")
	_run(m, _frame(200.0), 2)
	r.event("pass_object", {"kind": "post", "side": -1, "dist_m": 4.0, "size": 0.3})
	assert_near(float(r.last_pass["target"]) - t100, 40.0 * log(2.0) / log(10.0), 0.01, "doppeltes Tempo: 12 dB lauter")
	assert_true(float(r.last_pass["pan"]) < 0.0, "links")
	assert_true(float(r.last_pass["pitch"]) > 1.0, "schneller: kürzer und heller")
	var n := int(r.played["pass"])
	r.event("pass_object", {"kind": "post", "side": 1, "dist_m": 60.0, "size": 0.15})
	r.event("pass_object", {"kind": "post", "side": 1, "dist_m": 0.6, "size": 0.15, "contact": true})
	assert_eq(int(r.played["pass"]), n, "unter der Hörschwelle und berührt: keine Vorbeifahrt")
	r.event("pass_object", {"kind": "gantry", "side": 0, "dist_m": 0.0, "size": 2.0})
	assert_near(float(r.last_pass["pan"]), 0.0, 1.0e-6, "Schilderbrücke über dem Auto: mittig")
	assert_eq(str(r.last_pass["id"]), "pass_gantry", "eigener Klang")
	_run(m, _frame(30.0), 2)
	r.event("pass_object", {"kind": "tree", "side": 1, "dist_m": 2.0, "size": 1.0})
	assert_eq(int(r.played["pass"]), n + 1, "unter 40 km/h keine Vorbeifahrt")
	_done(m)


func test_wind_zones_gusts_and_fades() -> void:
	var m := _modern({"road": {"wind": {"gust_db": 0.0}}})
	var r := m.road
	r.set_vehicle("sportwagen")
	_run(m, _frame(200.0, {"zone": "open"}), 120)
	var open := _wind_total(r)
	_run(m, _frame(200.0, {"zone": "tunnel"}), 600)
	assert_near(_wind_total(r) - open, _num("road.wind.zone_db.tunnel"), 0.05, "im Tunnel leiser")
	assert_near(r.zone_gust, 0.0, 1.0e-3, "keine Böen im Tunnel")
	_run(m, _frame(200.0, {"zone": "bridge"}), 600)
	assert_near(_wind_total(r) - open, _num("road.wind.zone_db.bridge"), 0.05, "auf der Brücke stärker")
	_done(m)
	# gusts move the level, deterministically
	var g1 := _modern()
	var g2 := _modern()
	g1.road.set_vehicle("sportwagen")
	g2.road.set_vehicle("sportwagen")
	var lv: Array = []
	for i in 300:
		_run(g1, _frame(200.0, {"zone": "open"}), 1)
		_run(g2, _frame(200.0, {"zone": "open"}), 1)
		lv.append(_lufs(g1.road.winds["wind_mid"]))
	assert_near(_lufs(g1.road.winds["wind_mid"]), _lufs(g2.road.winds["wind_mid"]), 1.0e-6, "Böen in jedem Lauf gleich")
	var lo := 999.0
	var hi := -999.0
	for v: float in lv.slice(100):
		lo = minf(lo, v)
		hi = maxf(hi, v)
	assert_between(hi - lo, 0.5, 9.0, "Böen bewegen den Wind (%.1f dB)" % (hi - lo))
	# the session goes: everything fades; stop_all: at once
	var f := _frame(200.0, {"surface_l": "asphalt", "surface_r": "asphalt"})
	_run(g1, f, 30)
	f.alive = false
	_run(g1, f, 2)
	assert_true(g1.road.wind.level > 0.0, "blendet aus, reißt nicht ab")
	_run(g1, f, 90)
	assert_true(g1.road.wind.level < 0.001 and g1.road.surfaces["asphalt"].level < 0.001, "ohne Sitzung ausgeblendet")
	f.alive = true
	_run(g1, f, 30)
	g1.road.stop_all()
	assert_near(g1.road.wind.level, 0.0, 1.0e-9, "stop_all: sofort still")
	_done(g1)
	_done(g2)


func test_collisions_by_closing_speed_and_partner() -> void:
	var m := _modern()
	var im := m.impact
	assert_true(im.claims().has("collision") and im.claims().has("rail_hit"), "beansprucht Kollision und Leitplanke")
	assert_eq(im.tier_of(5.0), "light", "leicht")
	assert_eq(im.tier_of(30.0), "medium", "mittel")
	assert_eq(im.tier_of(90.0), "heavy", "schwer")
	m.event("collision", {"speed_kmh": 130.0, "rel_kmh": 90.0, "heavy": false, "side": 1})
	var ids: Array = []
	for row: Array in im.last_layers:
		ids.append(str(row[0]))
	ids.sort()
	assert_eq(ids, ["crunch", "debris", "glass", "hit_heavy"], "schwerer Aufprall: Schlag, Blech, Glas, Teile")
	var ref := _num("impact.ref_path_db")
	var adj := _num("impact.collision.slope_db") * log(90.0 / _num("impact.collision.heavy.ref_kmh")) / log(10.0)
	for row: Array in im.last_layers:
		if str(row[0]) == "hit_heavy":
			assert_near(float(row[2]), _num("impact.collision.heavy.layers.hit_heavy") + adj - _num("impact.file_peak_db") - ref, 0.01, "Pegel nach Schließgeschwindigkeit")
		assert_near(float(row[3]), _num("impact.pan"), 1.0e-6, "rechts")
		assert_true(absf(float(row[4])) <= _num("impact.variation.db") + 1.0e-6, "Pegel der Schicht zufällig, höchstens ±%.0f dB" % _num("impact.variation.db"))
		assert_between(float(row[5]), 0.0, 2.0 * _num("impact.variation.ms") + 0.01, "Einsatz der Schicht bis %.0f ms später" % (2.0 * _num("impact.variation.ms")))
	m.event("collision", {"speed_kmh": 100.0, "rel_kmh": -25.0, "heavy": true, "side": -1})
	ids = []
	for row: Array in im.last_layers:
		ids.append(str(row[0]))
	assert_true(ids.has("truck_boom") and ids.has("crunch"), "Lkw: der tiefe Schlag des Aufbaus")
	assert_false(ids.has("hit_heavy"), "statt des eigenen tiefen Schlags (zwei Schläge addierten sich nur zur Spitze)")
	assert_true(float(im.last_layers[0][3]) < 0.0, "links")
	m.event("collision", {"speed_kmh": 90.0, "rel_kmh": 4.0, "heavy": false, "side": 0})
	ids = []
	for row: Array in im.last_layers:
		ids.append(str(row[0]))
	ids.sort()
	assert_eq(ids, ["debris", "hit_light"], "leichter Rempler")
	# louder with the closing speed, within max_db
	var a := im.collision_layers(70.0, false)
	var b := im.collision_layers(140.0, false)
	var c := im.collision_layers(10000.0, false)
	assert_near(float(b[0][1]) - float(a[0][1]), _num("impact.collision.slope_db") * log(2.0) / log(10.0), 0.01, "doppelte Schließgeschwindigkeit")
	assert_near(float(c[0][1]) - float(a[0][1]), _num("impact.collision.max_db"), 0.01, "begrenzt")
	assert_eq(int(im.events.get("collision", 0)), 3, "drei Kollisionen")
	_done(m)


## AU-R (KRITIK-FAHRBAHN B12/B15): the glass breaks in every hard crash, below glass.from_kmh only sometimes; the
## variants come at random (never the same one twice in a row when there are three or more).
func test_collision_variety() -> void:
	var m := _modern()
	var im := m.impact
	var glass := 0
	var n := 300
	for i in n:
		m.event("collision", {"speed_kmh": 100.0, "rel_kmh": 60.0, "heavy": false, "side": 1})
		for row: Array in im.last_layers:
			glass += 1 if str(row[0]) == "glass" else 0
	var chance := _num("impact.collision.glass.chance")
	assert_between(float(glass) / n, chance - 0.08, chance + 0.08, "Glas bei 60 km/h in %.0f %% der Unfälle (Ziel %.0f %%)" % [100.0 * glass / n, 100.0 * chance])
	var hard := 0
	for i in 50:
		m.event("collision", {"speed_kmh": 150.0, "rel_kmh": _num("impact.collision.glass.from_kmh") + 1.0, "heavy": false, "side": -1})
		for row: Array in im.last_layers:
			hard += 1 if str(row[0]) == "glass" else 0
	assert_eq(hard, 50, "ab %.0f km/h Schließgeschwindigkeit immer Glas" % _num("impact.collision.glass.from_kmh"))
	# variants of glass, debris and the truck boom: four each, all used, never twice in a row
	for id: String in ["glass", "debris", "truck_boom"]:
		assert_true(m.assets.variant_count("sfx", id) >= 4, "%s: mindestens vier Varianten" % id)
	var seen := {}
	var last := -1
	var repeats := 0
	for i in 200:
		m.event("collision", {"speed_kmh": 150.0, "rel_kmh": 120.0, "heavy": true, "side": 1})
		for row: Array in im.last_layers:
			if str(row[0]) == "truck_boom":
				seen[int(row[1])] = true
				repeats += 1 if int(row[1]) == last else 0
				last = int(row[1])
	assert_eq(seen.size(), m.assets.variant_count("sfx", "truck_boom"), "jede Variante des Lkw-Schlags kommt vor")
	assert_eq(repeats, 0, "nie zweimal dieselbe hintereinander")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var two := {}
	for i in 100:
		two[RoadAudio.pick_variant(rng, 2, 0)] = true
	assert_eq(two.size(), 2, "zwei Varianten: zufällig, beide kommen vor")
	assert_eq(RoadAudio.pick_variant(rng, 1, 0), 0, "eine Variante")
	_done(m)


## AU-R (KRITIK-FAHRBAHN B1): every paired layer plays an own loop per side (another seed, another length), the right
## side a little higher (not the rumble strip), each side drifts slowly in level – the mean power of the plan kept.
func test_each_side_has_its_own_loop_and_drift() -> void:
	var m := _modern()
	var r := m.road
	r.set_vehicle("limousine")
	var paired: Array = []
	for s: String in r.surfaces:
		paired.append(r.surfaces[s])
	paired.append_array([r.wet, r.snow])
	for w: String in r.winds:
		paired.append(r.winds[w])
	for l: RoadAudio.Layer in paired:
		assert_true(l.own_loops, "%s: eigene Schleife rechts" % l.id)
		assert_true(l.lengths[0] >= 4.0 and l.lengths[1] >= 4.0, "%s: Schleifen ab 4 s (%.1f / %.1f s)" % [l.id, l.lengths[0], l.lengths[1]])
		var ratio := l.lengths[1] / l.lengths[0]
		assert_true(absf(ratio - roundf(ratio)) > 0.1 and absf(ratio - 1.0) > 0.1, "%s: Längen ohne kleines gemeinsames Vielfaches" % l.id)
	assert_near(r.surfaces["asphalt"].ratios[1], _num("road.sides.pitch"), 1.0e-6, "rechts etwas höher")
	assert_near(r.surfaces["rumble"].ratios[1], 1.0, 1.0e-6, "Rüttelstreifen: Schlagfolge exakt v / Rillenabstand")
	# the drift moves the sides apart and keeps the plan on average
	var still := _modern(STILL.duplicate(true))
	still.road.set_vehicle("limousine")
	_run(still, _frame(130.0, {"surface_l": "asphalt", "surface_r": "asphalt"}), 60)
	var plan := _lufs(still.road.surfaces["asphalt"])
	_done(still)
	var diffs: Array = []
	var power := 0.0
	var frames := 3000
	for i in frames:
		_run(m, _frame(130.0, {"surface_l": "asphalt", "surface_r": "asphalt"}), 1)
		if i >= 60:
			var a: RoadAudio.Layer = r.surfaces["asphalt"]
			diffs.append(_lufs_side(a, 0) - _lufs_side(a, 1))
			power += pow(10.0, _lufs(a) / 10.0)
	var mean := 0.0
	for d: float in diffs:
		mean += d
	mean /= diffs.size()
	var sd := 0.0
	for d: float in diffs:
		sd += (d - mean) * (d - mean)
	sd = sqrt(sd / diffs.size())
	assert_between(sd, 0.8, 3.5, "die Seiten schwanken gegeneinander (%.2f dB)" % sd)
	var avg := 10.0 * log(power / (frames - 60)) / log(10.0)
	assert_near(avg, plan, 0.5, "im Mittel der Pegel des Plans (%.2f gegen %.2f LUFS)" % [avg, plan])
	_done(m)


## AU-R (KRITIK-FAHRBAHN B12): each squeal its own pitch, within ±pitch_spread.
func test_squeal_pitch_per_event() -> void:
	var m := _modern()
	var r := m.road
	r.set_vehicle("kombi")
	var factors := {}
	for i in 12:
		_run(m, _frame(110.0, {}, {"understeer": 0.8}), 30)
		assert_true(r.squeal.level > 0.0, "quietscht")
		factors[snappedf(r.squeal_factor, 0.0001)] = true
		assert_between(r.squeal_factor, 1.0 - _num("road.squeal.pitch_spread") - 1.0e-6, 1.0 + _num("road.squeal.pitch_spread") + 1.0e-6, "Tonhöhe in ±%.0f %%" % (100.0 * _num("road.squeal.pitch_spread")))
		_run(m, _frame(110.0, {}, {"understeer": 0.0}), 90)
		assert_true(r.squeal.level < ModernAudioPan.SILENT, "verklungen")
	assert_true(factors.size() >= 10, "jedes Quietschen eine eigene Tonhöhe (%d verschiedene von 12)" % factors.size())
	_done(m)


func test_guardrail_scrape_and_delineators() -> void:
	var m := _modern()
	var im := m.impact
	var ref := _num("impact.ref_path_db")
	var fp := _num("impact.file_peak_db")
	m.event("rail_hit", {"impact_mps": 0.4, "side": 1})
	assert_eq(str(im.last_layers[0][0]), "rail_touch", "leicht: gestreift")
	assert_near(float(im.last_layers[0][2]), _num("impact.rail.touch_peak_db") - fp - ref, 0.01, "Pegel")
	m.event("rail_hit", {"impact_mps": 3.0, "side": -1})
	assert_eq(str(im.last_layers[0][0]), "rail_hit", "hart: Schlag mit schwingender Planke")
	assert_near(float(im.last_layers[0][2]), _num("impact.rail.hit_peak_db") - fp - ref, 0.01, "Pegel bei 3 m/s")
	assert_true(float(im.last_layers[0][3]) < 0.0, "links")
	# the scrape loop while touching, at the rail's side, louder with the speed
	var st := {"rail_contact": true, "x": 7.0, "road_left": -5.625, "road_right": 5.625}
	_run(m, _frame(100.0, {}, st), 60)
	assert_true(im.scrape_level > 0.01 and im.scrape_pan > 0.0, "Schleifen rechts")
	var at100 := im.scrape_level
	_run(m, _frame(50.0, {}, st), 60)
	assert_true(im.scrape_level < at100, "langsamer leiser")
	st["x"] = -7.0
	_run(m, _frame(100.0, {}, st), 60)
	assert_true(im.scrape_pan < 0.0, "links")
	st["rail_contact"] = false
	_run(m, _frame(100.0, {}, st), 60)
	assert_true(im.scrape_level < 1.0e-3, "ohne Berührung still")
	# a knocked delineator
	m.event("pass_object", {"kind": "post", "set": "delineator", "side": 1, "dist_m": 0.6, "size": 0.15, "contact": true})
	assert_eq(str(im.last_layers[0][0]), "post_hit", "Leitpfosten umgefahren")
	assert_true(float(im.last_layers[0][3]) > 0.0, "rechts")
	var n := int(im.counts.get("post_hit", 0))
	m.event("pass_object", {"kind": "post", "side": 1, "dist_m": 4.0, "size": 0.15, "contact": false})
	assert_eq(int(im.counts.get("post_hit", 0)), n, "nur bei Berührung")
	_done(m)
