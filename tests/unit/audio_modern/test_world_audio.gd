extends TestCase
## AU-C2: the slots "env" (EnvAcoustics), "ambience" (AmbienceAudio) and "traffic" (TrafficExtras) without players
## (the pause also through ModernAudio.step(), as the game makes it) –
## zone presets on MEnv (tap times changed only while the taps are silent, the valley echo, the tunnel, snow), the
## weights of the ambience beds and the rates of the calls (zone, scenery, hour, weather, canopy, tunnel), their levels
## against the manifest loudness and the speed fade, the calls' randomness; the Modern traffic sounds and classes, the
## level plan of the voices, wet tyres, the gust of a close pass, horns after a collision, the siren's level.

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


func _log10(x: float) -> float:
	return log(x) / log(10.0)


## A frame of a driven car; feed values set on a valid AudioFeed.
func _frame(speed: float, feed: Dictionary = {}, state: Dictionary = {}, tunnel := false) -> ModernAudioFrame:
	var f := ModernAudioFrame.new()
	f.dt = DT
	f.alive = true
	f.speed = speed
	f.tunnel = tunnel
	var fd := AudioFeed.new()
	fd.valid = true
	for k: String in feed:
		fd.set(k, feed[k])
	f.feed = fd
	if not state.is_empty():
		f.has_state = true
		f.state = state
	return f


# --- env ------------------------------------------------------------------------------------------------------------

func test_env_zone_presets_reach_the_effects() -> void:
	var m := _modern()
	var env := m.env
	var refl := m.buses.reflections()
	var rev := m.buses.reverb()
	for z: String in ["city", "cutting", "forest", "open"]:
		var f := _frame(80.0, {"zone": z})
		for i in 240:
			env.update(f)
		var p: Dictionary = env.presets[z]
		var pan := float(p["tap_pan"])
		var want := float(p["tap_db"]) - 10.0 * _log10(1.0 + pan * pan)
		assert_eq(env.zone, z, "Zone %s" % z)
		assert_near(refl.tap1_delay_ms, float(p["taps_ms"][0]), 0.01, "%s: linke Reflexion" % z)
		assert_near(refl.tap2_delay_ms, float(p["taps_ms"][1]), 0.01, "%s: rechte Reflexion" % z)
		assert_near(refl.tap1_level_db, want, 0.05, "%s: Pegel der Reflexionen (Panorama ausgeglichen)" % z)
		assert_near(refl.tap2_pan, pan, 0.002, "%s: Panorama" % z)
		assert_near(rev.wet, float(p["wet"]), 0.002, "%s: Hallanteil" % z)
		assert_near(rev.room_size, float(p["room"]), 0.002, "%s: Raumgröße" % z)
	assert_near(rev.predelay_msec, _num("env.predelay_ms"), 0.001, "Predelay fest")
	_done(m)


func test_env_tap_times_change_only_while_silent() -> void:
	var m := _modern()
	var env := m.env
	var refl := m.buses.reflections()
	var open := _frame(80.0, {"zone": "open"})
	for i in 120:
		env.update(open)
	var city := _frame(80.0, {"zone": "city"})
	var last := refl.tap1_delay_ms
	var worst := -200.0
	var changes := 0
	for i in 120:
		env.update(city)
		if absf(refl.tap1_delay_ms - last) > 0.001:
			changes += 1
			worst = maxf(worst, refl.tap1_level_db)
			last = refl.tap1_delay_ms
	assert_eq(changes, 1, "Reflexionszeiten einmal umgestellt")
	assert_true(worst <= -60.0, "beim Umstellen stumm (%.1f dB)" % worst)
	assert_eq(env.tap_switches, 1, "Zähler")
	assert_true(refl.tap1_level_db > -20.0, "danach wieder eingeblendet (%.1f dB)" % refl.tap1_level_db)
	_done(m)


func test_env_valley_echo_and_tunnel() -> void:
	var m := _modern()
	var env := m.env
	var refl := m.buses.reflections()
	var rev := m.buses.reverb()
	var valley := _frame(80.0, {"zone": "valley"})
	for i in 420:
		env.update(valley)
	assert_true(refl.feedback_active, "Echo im Tal")
	assert_near(refl.feedback_delay_ms, float(env.presets["valley"]["echo_ms"]), 0.01, "Echozeit")
	assert_near(refl.feedback_level_db, float(env.presets["valley"]["echo_db"]), 0.1, "Echopegel")
	var open := _frame(80.0, {"zone": "open"})
	for i in 180:
		env.update(open)
	assert_false(refl.feedback_active, "kein Echo im Freien")
	# the car enters a tunnel before the camera: the zone outside stays until the camera is in
	var car_in := _frame(80.0, {"zone": "tunnel", "tunnel": true})
	for i in 30:
		env.update(car_in)
	assert_eq(env.zone, "open", "Kamera noch draußen: Zone draußen")
	var cam_in := _frame(80.0, {"zone": "tunnel", "tunnel": true}, {}, true)
	for i in 60:
		env.update(cam_in)
	assert_eq(env.zone, "tunnel", "Kamera im Tunnel")
	assert_true(env.blend() > 0.9, "Tunnelhall nach 1 s (%.2f)" % env.blend())
	assert_true(rev.wet > 0.25, "Hallanteil im Tunnel")
	_done(m)


func test_env_holds_its_zone_in_the_pause_and_a_hitch() -> void:
	var m := _modern()
	var env := m.env
	var city := _frame(50.0, {"zone": "city"})
	for i in 240:
		env.update(city)
	var switches := env.tap_switches
	var invalid := _frame(50.0, {"zone": "city"})
	invalid.feed.valid = false
	invalid.paused = true
	for i in 600:
		env.update(invalid)
	assert_eq(env.zone, "city", "Pause: Zone gehalten")
	invalid.paused = false
	invalid.dt = 0.4                    # a hitch of 0.4 s: one frame without a feed
	env.update(invalid)
	assert_eq(env.zone, "city", "Hänger: Zone gehalten")
	invalid.dt = DT
	for i in 30:
		env.update(city)
	assert_eq(env.tap_switches, switches, "keine Umstellung der Reflexionen")
	for i in 90:
		env.update(invalid)
	assert_eq(env.zone, "open", "länger ohne Feed: im Freien")
	_done(m)


func test_env_snow_and_cover() -> void:
	var m := _modern()
	var env := m.env
	var rev := m.buses.reverb()
	var city := _frame(60.0, {"zone": "city"})
	for i in 240:
		env.update(city)
	var wet_dry := rev.wet
	var snow := _frame(60.0, {"zone": "city", "snow": 1.0})
	for i in 240:
		env.update(snow)
	assert_near(rev.wet, wet_dry * _num("env.snow.wet_k"), 0.003, "Schnee: weniger Hall")
	assert_true(rev.damping > float(env.presets["city"]["damp"]), "Schnee: dunkler")
	var fuel := _frame(20.0, {"zone": "open", "cover": "fuel"})
	for i in 240:
		env.update(fuel)
	assert_eq(env.zone, "cover", "unter dem Tankstellendach")
	env.stop_all()
	assert_eq(env.zone, "open", "stop_all: im Freien")
	_done(m)


# --- ambience -------------------------------------------------------------------------------------------------------

func _amb_run(m: ModernAudio, f: ModernAudioFrame, n: int) -> void:
	for i in n:
		m.ambience.update(f)


func test_ambience_weights_by_place_time_and_weather() -> void:
	var m := _modern()
	var a := m.ambience
	var day_open := _frame(0.0, {"zone": "open", "style": "plain", "climate": "continental"}, {"hour": 13.0, "weather": "normal"})
	a.compute(day_open)
	assert_true(float(a.weights["breeze"]) > 0.9, "Land am Tag: Wind")
	assert_eq(float(a.weights["crickets"]), 0.0, "keine Grillen am Tag")
	assert_eq(float(a.weights["cicadas"]), 0.0, "keine Zikaden nördlich der Alpen")
	assert_true(float(a.rates["bird"]) > 3.0 and float(a.rates["skylark"]) > 0.0, "Vögel und Lerche")
	assert_eq(float(a.rates["owl"]), 0.0, "keine Eule am Tag")
	var night_open := _frame(0.0, {"zone": "open", "climate": "continental"}, {"hour": 23.5, "weather": "normal"})
	a.compute(night_open)
	assert_true(float(a.weights["crickets"]) > 0.9, "Nacht: Grillen")
	assert_eq(float(a.rates["bird"]), 0.0, "Nacht: keine Singvögel")
	assert_true(float(a.rates["owl"]) > 0.0, "Nacht: Eule")
	var north := _frame(0.0, {"zone": "open", "climate": "north"}, {"hour": 23.5})
	a.compute(north)
	assert_near(float(a.weights["crickets"]), 0.5, 1.0e-6, "Norden: halb so viele Grillen")
	var med := _frame(0.0, {"zone": "open", "climate": "mediterranean"}, {"hour": 14.0})
	a.compute(med)
	assert_true(float(a.weights["cicadas"]) > 0.9, "Mittelmeer am Tag: Zikaden")
	var rain := _frame(0.0, {"zone": "open", "climate": "mediterranean"}, {"hour": 14.0, "weather": "rain"})
	rain.rain = 1.0
	a.compute(rain)
	assert_eq(float(a.weights["cicadas"]), 0.0, "Regen: Zikaden still")
	assert_eq(float(a.rates["bird"]), 0.0, "Regen: Vögel still")
	assert_near(float(a.weights["rain"]), 1.0, 1.0e-6, "Regenbett")
	var snow := _frame(0.0, {"zone": "forest", "snow": 1.0}, {"hour": 23.0, "weather": "snow"})
	a.compute(snow)
	assert_eq(float(a.weights["crickets"]), 0.0, "Schnee: keine Grillen")
	assert_near(float(a.weights["leaves"]), 0.55, 1.0e-6, "Schnee: Wald etwa 5 dB leiser")
	var tunnel := _frame(80.0, {"zone": "tunnel", "tunnel": true}, {"hour": 13.0}, true)
	tunnel.rain = 0.0
	a.compute(tunnel)
	for id: String in a.weights:
		if id != "tunnel_fans":
			assert_eq(float(a.weights[id]), 0.0, "Tunnel: %s still" % id)
	assert_near(float(a.weights["tunnel_fans"]), 1.0, 1.0e-6, "Tunnel: Lüfter")
	var fuel := _frame(0.0, {"zone": "open", "cover": "fuel"}, {"hour": 13.0})
	a.compute(fuel)
	assert_near(float(a.weights["hum"]), 1.0, 1.0e-6, "Tankstellendach: Brummen")
	assert_near(float(a.weights["breeze"]), 0.6, 1.0e-6, "unter dem Dach etwas abgeschirmt")
	var centre := _frame(0.0, {"zone": "city", "city": true, "scenery": "city_hanse_center", "features": PackedStringArray(["cranes"])},
		{"hour": 11.0})
	a.compute(centre)
	assert_true(float(a.weights["city_day"]) > 0.9 and float(a.weights["water"]) > 0.3, "Hansestadt: Stadt und Hafen")
	assert_true(float(a.rates["bell"]) > 0.0 and float(a.rates["sparrow"]) > 0.0 and float(a.rates["gull"]) > 0.0,
		"Altstadt: Glocke, Spatzen, Möwen")
	var bridge := _frame(0.0, {"zone": "bridge", "water": true}, {"hour": 11.0})
	a.compute(bridge)
	assert_near(float(a.weights["water"]), 1.0, 1.0e-6, "Brücke über Wasser")
	_done(m)


func test_ambience_levels_and_speed_fade() -> void:
	var m := _modern()
	var a := m.ambience
	var ref := _num("ambience.ref_path_db")
	var f := _frame(0.0, {"zone": "open", "climate": "continental"}, {"hour": 13.0})
	_amb_run(m, f, 900)
	var b: AmbienceAudio.Bed = a.beds["breeze"]
	assert_true(b.has_sound, "Bett aus dem Manifest")
	var lufs := b.lufs + linear_to_db(b.gain) + ref
	assert_near(lufs, _num("ambience.beds.breeze.lufs"), 0.05, "Wind am Master wie geplant im Stand")
	var fast := _frame(130.0, {"zone": "open", "climate": "continental"}, {"hour": 13.0})
	_amb_run(m, fast, 600)
	var want := _num("ambience.beds.breeze.lufs") - _num("ambience.beds.breeze.slope_db") * _log10(130.0 / _num("ambience.speed.from_kmh"))
	assert_near(b.lufs + linear_to_db(b.gain) + ref, want, 0.05, "Abblenden mit dem Tempo")
	var gone := _frame(0.0, {"zone": "open"})
	gone.alive = false
	gone.has_state = false
	_amb_run(m, gone, 900)
	assert_true(b.gain < 0.001, "ohne Etappe still")
	_done(m)


## The pause as ModernAudio.step() makes it (KRITIK AU-C2, finding 1: neither alive nor has_state while paused).
func test_ambience_goes_on_in_the_pause() -> void:
	var m := _modern()
	var b: AmbienceAudio.Bed = m.ambience.beds["breeze"]
	var ref := _num("ambience.ref_path_db")
	for i in 600:
		m.set_engine(0.0, 0.0, 230.0, true)
		m.set_vehicle_state({"z": 0.0, "x": 0.0, "speed": 0.0, "hour": 13.0, "weather": "normal"})
		m.clock_ms += 17
		m.step(DT, false)
	var before := b.lufs + linear_to_db(b.gain) + ref
	assert_near(before, _num("ambience.beds.breeze.lufs"), 0.1, "im Stand wie geplant")
	var calls := m.ambience.calls_played
	for i in 600:
		m.clock_ms += 17
		m.step(DT, true)
	assert_false(m.frame.alive or m.frame.has_state, "pausiert: weder alive noch Zustand")
	assert_near(b.lufs + linear_to_db(b.gain) + ref, before + _num("ambience.pause_db"), 0.1, "Pause: leiser, aber da")
	assert_eq(m.ambience.calls_played, calls, "in der Pause kein Ruf")
	for i in 600:
		m.set_engine(0.0, 0.0, 230.0, true)
		m.set_vehicle_state({"z": 0.0, "x": 0.0, "speed": 0.0, "hour": 13.0, "weather": "normal"})
		m.clock_ms += 17
		m.step(DT, false)
	assert_near(b.lufs + linear_to_db(b.gain) + ref, before, 0.1, "nach der Pause wie vorher")
	# the stage ends: after hold_s without the session the beds fade out
	for i in 600:
		m.clock_ms += 17
		m.step(DT, false)
	assert_true(b.gain < 0.001, "Etappe vorbei: still")
	_done(m)


func test_ambience_tunnel_exit_is_quick() -> void:
	var m := _modern()
	var a := m.ambience
	var inside := _frame(80.0, {"zone": "tunnel", "tunnel": true}, {"hour": 13.0}, true)
	_amb_run(m, inside, 300)
	assert_true((a.beds["tunnel_fans"] as AmbienceAudio.Bed).weight > 0.95, "im Tunnel: Lüfter")
	var out := _frame(80.0, {"zone": "open"}, {"hour": 13.0})
	_amb_run(m, out, 60)
	assert_true((a.beds["tunnel_fans"] as AmbienceAudio.Bed).weight < 0.15,
		"eine Sekunde nach der Ausfahrt sind die Lüfter fast weg (%.2f)" % (a.beds["tunnel_fans"] as AmbienceAudio.Bed).weight)
	assert_true((a.beds["breeze"] as AmbienceAudio.Bed).weight > 0.85, "der Wind ist schon da")
	_done(m)


func test_ambience_calls_random_and_bounded() -> void:
	var m := _modern()
	var a := m.ambience
	var f := _frame(0.0, {"zone": "forest", "climate": "continental", "style": "forest"}, {"hour": 13.0})
	a.compute(f)
	var per_min := 0.0
	for c: String in a.rates:
		per_min += float(a.rates[c])
	var last := {}
	var repeats := 0
	var lo := 1000.0
	var hi := -1000.0
	var n0 := a.calls_played
	var seconds := 600.0
	for i in int(seconds / DT):
		a.update(f)
		if a.calls_played > n0:
			n0 = a.calls_played
			var lc := a.last_call
			var e := m.assets.entry("ambience", str(lc["id"]))
			var lm := float((e.meta["lufs_m"] as Array)[int(lc["variant"])])
			var lufs := lm + float(lc["db"]) + _num("ambience.ref_path_db")
			var target := _num("ambience.calls.%s.lufs_m" % str(lc["category"]))
			lo = minf(lo, lufs - target)
			hi = maxf(hi, lufs - target)
			# RoadAudio.pick_variant: with three or more variants never the last one again (two: at random)
			if e.files.size() > 2 and int(last.get(lc["id"], -1)) == int(lc["variant"]):
				repeats += 1
			last[lc["id"]] = int(lc["variant"])
			assert_true(absf(float(lc["pitch"]) - 1.0) <= _num("ambience.call_pitch") + 1.0e-6, "Tonhöhe begrenzt")
	var want := per_min * seconds / 60.0
	assert_true(a.calls_played >= want * 0.7 and a.calls_played <= want * 1.3,
		"Rufe im Wald: %d in %d s (Rate %.1f je Minute)" % [a.calls_played, int(seconds), per_min])
	assert_eq(repeats, 0, "bei drei Varianten keine zweimal hintereinander")
	assert_true(hi <= 0.01 and lo >= -_num("ambience.call_spread_db") - 0.01, "Pegel im Band (%.2f … %.2f dB)" % [lo, hi])
	var n1 := a.calls_played
	var fast := _frame(160.0, {"zone": "forest"}, {"hour": 13.0})
	for i in 3600:
		a.update(fast)
	assert_eq(a.calls_played, n1, "keine Rufe über calls_max_kmh")
	_done(m)


func test_ambience_night_and_daytime() -> void:
	var m := _modern()
	var a := m.ambience
	assert_near(a.night_of(13.0), 0.0, 1.0e-6, "Mittag: Tag")
	assert_near(a.night_of(2.0), 1.0, 1.0e-6, "2 Uhr: Nacht")
	assert_true(a.night_of(5.8) > 0.0 and a.night_of(5.8) < 1.0, "Morgendämmerung dazwischen")
	assert_true(a.night_of(6.4) < 0.05, "kurz vor Sonnenaufgang singen die Vögel schon")
	assert_true(a.dawn_of(6.3) > 0.9, "Morgenchor")
	assert_true(a.night_of(19.8) > 0.0 and a.night_of(21.5) > 0.99, "Abend: Grillen nach Sonnenuntergang")
	assert_near(a.dawn_of(13.0), 0.0, 1.0e-6, "kein Morgenchor mittags")
	_done(m)


# --- traffic --------------------------------------------------------------------------------------------------------

func _tframe(vehicles: Array, listener_speed: float, feed: Dictionary = {}) -> ModernAudioFrame:
	var f := _frame(listener_speed, feed)
	f.traffic_alive = true
	f.vehicles = vehicles
	f.listener = {"z": 0.0, "x": 0.0, "speed": listener_speed}
	return f


func test_traffic_modern_sounds_and_levels() -> void:
	var m := _modern()
	var t := m.traffic
	assert_true(t.modern_sounds, "Modern-Verkehrsklänge geladen")
	var ref := _num("traffic.ref_path_db")
	for id: String in t.model.sounds:
		var s: TrafficAudio.Sound = t.model.sounds[id]
		var e := m.assets.entry("traffic", id)
		var want := float(ConfigLoader.lookup(cfg(), "audio.modern.traffic.levels." + id, -30.0))
		assert_near(s.gain_db, want - e.lufs - ref + 3.0103 - t.model.level_db, 1.0e-4, "Pegel %s" % id)
	assert_eq((t.model.classes["police"] as TrafficAudio.VClass).engines.size(), 2, "Polizei: zwei Motoren")
	assert_eq(t.model.class_of("traffic/hatch_red"), "car", "Kleinwagen: Klasse car")
	# one car at 3 m beside the listener at its design speed: each layer at its target loudness
	var car := {"id": 5, "set": "traffic/sedan_blue", "z": -2.35, "x": 3.0, "length": 4.7, "speed": 120.0}
	for i in 60:
		t.update(_tframe([car], 120.0))
	var v: TrafficAudio.Voice = t.model.voices[0] if t.model.voices[0].vehicle == 5 else t.model.voices[1]
	assert_eq(v.vehicle, 5, "Stimme vergeben")
	assert_near(v.fade, 1.0, 1.0e-6, "eingeblendet")
	for k in 3:
		var sname: String = v.sounds[k]
		var s: TrafficAudio.Sound = t.model.sounds[sname]
		var e := m.assets.entry("traffic", sname)
		# from the channel gains TrafficAudio hands to its players (not from the level formula): the manifest measures
		# the file on both channels at gain 1
		var lufs := e.lufs + 10.0 * _log10((v.gl[k] * v.gl[k] + v.gr[k] * v.gr[k]) / 2.0) + ref
		var want := float(ConfigLoader.lookup(cfg(), "audio.modern.traffic.levels." + sname, -30.0))
		var d_db := 20.0 * _log10(t.model.distance_gain(v.distance, t.model.ref_m, t.model.max_m,
			TrafficAudio.AIR_ROLLOFF if k == 2 else t.model.rolloff))
		var sp_db := t.model.speed_level_db(120.0, s.ref_kmh, s.db_per_decade)
		assert_near(lufs, want + d_db + sp_db, 0.05, "Ebene %s am Master" % sname)
	_done(m)


func test_traffic_wet_tyres() -> void:
	var m := _modern()
	var t := m.traffic
	var car := {"id": 9, "set": "traffic/wagon_grey", "z": 20.0, "x": 3.5, "length": 4.7, "speed": 100.0}
	var truck := {"id": 10, "set": "traffic/truck_red", "z": 40.0, "x": 3.5, "length": 16.5, "speed": 85.0, "heavy": true}
	for i in 10:
		t.update(_tframe([car, truck], 120.0, {"wet": 1.0}))
	var tyres := {}
	for v in t.model.voices:
		if v.vehicle != TrafficAudio.NONE:
			tyres[v.vehicle] = v.sounds[1]
	assert_eq(str(tyres.get(9, "")), "tires_car_wet", "Pkw nass")
	assert_eq(str(tyres.get(10, "")), "tires_truck_wet", "Lkw nass")
	t.stop_all()
	for i in 10:
		t.update(_tframe([car], 120.0, {"wet": 0.0}))
	for v in t.model.voices:
		if v.vehicle == 9:
			assert_eq(v.sounds[1], "tires_car", "trocken")
	_done(m)


func test_traffic_close_pass_whoosh() -> void:
	var m := _modern()
	var t := m.traffic
	# the player (listener, 150 km/h) overtakes a truck 2.5 m to the right doing 85 km/h
	var z := 30.0
	var n0 := t.whooshes_played
	for i in 240:
		z -= (150.0 - 85.0) / 3.6 * DT
		t.update(_tframe([{"id": 3, "set": "traffic/truck_red", "z": z, "x": 2.5, "length": 16.5, "speed": 85.0, "heavy": true}], 150.0))
	assert_eq(t.whooshes_played - n0, 1, "ein Luftstoß beim Passieren")
	assert_eq(str(t.last_fx.get("id", "")), "whoosh_truck", "Lkw: Bugwelle")
	assert_true(float(t.last_fx["pan"]) > 0.0, "rechts")
	var e := m.assets.entry("traffic", "whoosh_truck")
	var lufs := float((e.meta["lufs_m"] as Array)[int(t.last_fx["variant"])]) + float(t.last_fx["db"]) + _num("traffic.ref_path_db")
	var want := _num("traffic.whoosh.heavy_lufs") + _num("traffic.whoosh.slope_db") * _log10(85.0 / _num("traffic.whoosh.ref_kmh")) \
		- 20.0 * _log10(2.5 / _num("traffic.whoosh.ref_m"))
	assert_near(lufs, want, 0.3, "Pegel nach dem Tempo des Lkw und dem Abstand")
	# far to the side or slowly: none
	t.stop_all()
	z = 30.0
	n0 = t.whooshes_played
	for i in 240:
		z -= (150.0 - 85.0) / 3.6 * DT
		t.update(_tframe([{"id": 4, "set": "traffic/sedan_blue", "z": z, "x": 7.5, "length": 4.7, "speed": 85.0}], 150.0))
	assert_eq(t.whooshes_played - n0, 0, "7,5 m daneben: kein Luftstoß")
	# a standing car passed closely: no gust (it pushes no air)
	t.stop_all()
	z = 30.0
	n0 = t.whooshes_played
	for i in 240:
		z -= 50.0 / 3.6 * DT
		t.update(_tframe([{"id": 6, "set": "traffic/sedan_blue", "z": z, "x": 2.5, "length": 4.7, "speed": 0.0}], 50.0))
	assert_eq(t.whooshes_played - n0, 0, "stehendes Auto: kein Luftstoß")
	_done(m)


func test_traffic_horn_after_collision() -> void:
	var m := _modern({"traffic": {"horns": {"after_collision": 1.0}}})
	var t := m.traffic
	var truck := {"id": 12, "set": "traffic/truck_red", "z": 1.0, "x": 2.0, "length": 16.5, "speed": 80.0, "heavy": true}
	for i in 5:
		t.update(_tframe([truck], 80.0))
	t.event("collision", {"speed_kmh": 40.0, "heavy": true, "side": 1})
	var n0 := t.horns_played
	for i in 60:
		t.update(_tframe([truck], 80.0))
	assert_eq(t.horns_played - n0, 1, "der Lkw hupt nach der Reaktionszeit")
	assert_eq(str(t.last_fx["id"]), "horn_truck", "Drucklufthorn")
	var he := m.assets.entry("traffic", "horn_truck")
	var hl := float((he.meta["lufs_m"] as Array)[int(t.last_fx["variant"])]) + float(t.last_fx["db"]) + _num("traffic.ref_path_db")
	var hw := minf(_num("traffic.horns.truck_lufs") - 20.0 * _log10(_num("traffic.horns.near_m") / _num("traffic.horns.ref_m")),
		_num("traffic.horns.max_lufs"))
	assert_near(hl, hw, 0.05, "Lkw in 2 m: flach innerhalb near_m, höchstens max_lufs (%.1f LUFS)" % hl)
	assert_true(hl <= _num("traffic.horns.max_lufs") + 0.01, "nie über max_lufs")
	t.event("collision", {"speed_kmh": 40.0, "heavy": true, "side": 1})
	for i in 60:
		t.update(_tframe([truck], 80.0))
	assert_eq(t.horns_played - n0, 1, "Pause zwischen zwei Hupen")
	# the police never honks
	t.stop_all()
	var police := {"id": TrafficAudio.POLICE_ID, "set": "police/de", "z": 1.0, "x": 2.0, "length": 4.8, "speed": 80.0}
	m.traffic._horn_wait = 0.0
	for i in 5:
		t.update(_tframe([police], 80.0))
	t.event("collision", {"speed_kmh": 40.0, "heavy": false, "side": 1})
	for i in 60:
		t.update(_tframe([police], 80.0))
	assert_eq(t.horns_played - n0, 1, "Polizei hupt nicht")
	# the police is the nearest, a car further away: nobody honks (not the uninvolved car)
	t.stop_all()
	m.traffic._horn_wait = 0.0
	var car := {"id": 14, "set": "traffic/sedan_red", "z": 6.0, "x": -3.5, "length": 4.7, "speed": 80.0}
	for i in 5:
		t.update(_tframe([police, car], 80.0))
	t.event("collision", {"speed_kmh": 40.0, "heavy": false, "side": 1})
	for i in 60:
		t.update(_tframe([police, car], 80.0))
	assert_eq(t.horns_played - n0, 1, "Polizei am nächsten: niemand hupt")
	# a horn waiting for its reaction time is dropped when the game is paused
	t.stop_all()
	m.traffic._horn_wait = 0.0
	for i in 5:
		t.update(_tframe([truck], 80.0))
	t.event("collision", {"speed_kmh": 40.0, "heavy": true, "side": 1})
	var pf := _tframe([truck], 80.0)
	pf.paused = true
	t.update(pf)
	for i in 60:
		t.update(_tframe([truck], 80.0))
	assert_eq(t.horns_played - n0, 1, "Pause: die wartende Hupe entfällt")
	_done(m)


func test_traffic_siren_level() -> void:
	var m := _modern()
	var t := m.traffic
	var e := m.assets.entry("traffic", "siren")
	assert_true(e != null, "Martinshorn im Manifest")
	assert_near(t.model.siren_db, _num("traffic.siren_lufs") - e.lufs - _num("traffic.ref_path_db"), 1.0e-4, "Pegel des Martinshorns")
	var f := _tframe([], 120.0)
	f.siren_on = true
	f.siren_level = 1.0
	for i in 60:
		t.update(f)
	var st := t.state()
	var lufs := e.lufs + 20.0 * _log10(float(st["siren"]["left"])) + _num("traffic.ref_path_db")
	assert_near(lufs, _num("traffic.siren_lufs"), 0.1, "ohne Polizeiauto: mittig in der Lautheit der Bezugsentfernung")
	_done(m)
