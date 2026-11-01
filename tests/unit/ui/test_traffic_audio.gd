extends TestCase
## Traffic pass-by sounds and the spatial siren (TrafficAudio, docs/verkehrsgeraeusche.md §2) with the placeholder
## loops of tests/fixtures/traffic (make_traffic_fixtures.py): loading, class lookup, the pure maths (pan, distance,
## Doppler, air absorption, speed pitch/level, per-id spread), voice assignment with hysteresis and click-free fades,
## a pass-by on the left (left channel louder, pitch drops at passing), siren (spatial/centred), CPU time per frame.
## Room sound (RoomAudio): tunnel blend and effect parameters.

const FIXTURE := "res://tests/fixtures/traffic/traffic_sounds.json"
const DT := 1.0 / 60.0
const LANE := 3.75


func _ta(with_streams: bool = false) -> TrafficAudio:
	var t := TrafficAudio.new()
	t.setup(cfg())
	assert_true(t.load_sounds(FIXTURE, with_streams), "Fixture lädt: %s" % str(t.errors))
	return t


func _car(id: int, z_rear: float, x: float, kmh: float, set_id: String = "traffic/sedan_blue", length: float = 4.7) -> Dictionary:
	return {"id": id, "set": set_id, "z": z_rear, "x": x, "length": length, "speed": kmh, "heavy": set_id.contains("truck")}


func _listener(z: float, kmh: float, x: float = 0.0) -> Dictionary:
	return {"z": z, "x": x, "speed": kmh}


func _slot_of(t: TrafficAudio, id: int) -> TrafficAudio.Voice:
	for v in t.voices:
		if v.vehicle == id:
			return v
	return null


func _total(v: TrafficAudio.Voice) -> float:
	var s := 0.0
	for k in 3:
		s += v.gl[k] + v.gr[k]
	return s


# --- data -----------------------------------------------------------------------------------------

func test_load_fixture_with_looping_streams() -> void:
	var t := _ta(true)
	assert_eq(t.sounds.size(), 9, "Klänge")
	assert_eq(t.classes.size(), 6, "Klassen")
	assert_true(t.warnings.is_empty(), "keine Warnungen: %s" % str(t.warnings))
	for sname: String in t.sounds:
		var s: TrafficAudio.Sound = t.sounds[sname]
		assert_true(s.stream is AudioStreamWAV, "%s ist ein AudioStreamWAV" % sname)
		var w: AudioStreamWAV = s.stream
		assert_eq(w.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s Schleife an" % sname)
		assert_eq(w.loop_end, int(round(w.get_length() * w.mix_rate)), "%s Schleifenende = Länge" % sname)
	var car: TrafficAudio.VClass = t.classes["car"]
	assert_eq(car.engines.size(), 2, "car hat zwei Motorvarianten")
	assert_near((t.classes["truck"] as TrafficAudio.VClass).size, 2.2, 1.0e-6, "Lkw-Größe")
	var air: TrafficAudio.Sound = t.sounds["air"]
	assert_near(air.db_per_decade, 40.0, 1.0e-6, "level_db_per_decade der Luft")
	assert_near((t.sounds["car_petrol"] as TrafficAudio.Sound).db_per_decade, 0.0, 1.0e-6, "fehlendes Feld = 0")


func test_missing_or_broken_files() -> void:
	var t := TrafficAudio.new()
	t.setup(cfg())
	assert_false(t.load_sounds("res://tests/fixtures/traffic/gibt_es_nicht.json"), "fehlende Datei")
	assert_false(t.ok, "nicht ok")
	assert_false(t.errors.is_empty(), "Fehler gemeldet")
	# without traffic sounds update() still runs (no voices) and the siren works
	t.set_siren(true, 0.5)
	for i in 30:
		t.update(DT, [_car(1, 10.0, -LANE, 100.0)], _listener(0.0, 120.0))
	for v in t.voices:
		assert_eq(v.vehicle, TrafficAudio.NONE, "keine Stimmen ohne Klänge")
	assert_near(t.siren.gl[0], 0.5, 0.01, "Martinshorn trotzdem (mittig)")
	# wrong format / class without its sounds
	var p := "user://test_traffic_broken.json"
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(JSON.stringify({"format": "falsch", "sounds": {}}))
	f.close()
	assert_false(t.load_sounds(p, false), "falsches Format")
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	(d["classes"] as Dictionary)["truck"] = {"engine": ["gibt_es_nicht"], "tires": "tires_truck", "air": "air", "size": 2.2}
	f = FileAccess.open(p, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	assert_true(t.load_sounds(p, false), "eine kaputte Klasse macht nicht alles unbrauchbar")
	assert_false(t.classes.has("truck"), "kaputte Klasse verworfen")
	assert_false(t.warnings.is_empty(), "Warnung für die kaputte Klasse")
	assert_eq(t.class_of("traffic/truck_white", true), "car", "Lkw fällt auf car zurück")
	(d["classes"] as Dictionary).erase("car")
	f = FileAccess.open(p, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	assert_false(t.load_sounds(p, false), "ohne Klasse car unbrauchbar")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func test_class_of_sprite_ids() -> void:
	var t := _ta()
	var cases := {"traffic/sedan_blue": "car", "traffic/hatch_red": "car", "traffic/wagon_silver": "car",
		"traffic/suv_black": "van", "traffic/van_white": "van", "traffic/sports_yellow": "sport",
		"traffic/truck_white": "truck", "traffic/bus_yellow": "bus", "police/de": "police", "police/it": "police",
		"traffic/rocket_green": "car", "fixture/car17": "car", "fixture/truck_box": "truck", "fixture/police17": "police", "": "car"}
	for id: String in cases:
		assert_eq(t.class_of(id), str(cases[id]), id)
	assert_eq(t.class_of("traffic/hauler_grey", true), "truck", "unbekanntes schweres Fahrzeug = truck")
	assert_eq(TrafficAudio.model_of("traffic/sedan_dark_blue"), "sedan", "Modell vor der Farbe")


# --- pure maths -------------------------------------------------------------------------------------

func test_pan_gains_constant_power() -> void:
	var last_l := 2.0
	for i in 41:
		var p := -1.0 + i * 0.05
		var g := TrafficAudio.pan_gains(p)
		assert_near(g.x * g.x + g.y * g.y, 1.0, 1.0e-5, "Leistung konstant bei pan %.2f" % p)
		assert_true(g.x <= last_l + 1.0e-6, "links fällt monoton")
		last_l = g.x
		if p < -0.01:
			assert_true(g.x > g.y, "pan %.2f: links lauter" % p)
		elif p > 0.01:
			assert_true(g.y > g.x, "pan %.2f: rechts lauter" % p)
	var c := TrafficAudio.pan_gains(0.0)
	assert_near(c.x, c.y, 1.0e-6, "Mitte gleich")
	assert_near(TrafficAudio.pan_gains(-1.0).y, 0.0, 1.0e-6, "ganz links: rechts stumm")


func test_distance_gain() -> void:
	assert_near(TrafficAudio.distance_gain(2.0, 5.0, 150.0, 1.0), 1.0, 1.0e-6, "innerhalb des Bezugsabstands voll")
	assert_near(TrafficAudio.distance_gain(5.0, 5.0, 150.0, 1.0), 1.0, 1.0e-6, "am Bezugsabstand voll")
	assert_near(TrafficAudio.distance_gain(10.0, 5.0, 150.0, 1.0), 0.5, 1.0e-6, "doppelter Abstand -6 dB")
	assert_near(TrafficAudio.distance_gain(10.0, 5.0, 150.0, 2.0), 0.25, 1.0e-6, "Luft: doppelter Abstand -12 dB")
	assert_near(TrafficAudio.distance_gain(50.0, 5.0, 150.0, 1.0), 0.1, 1.0e-6, "50 m: 1/10 (vor der Ausblendung)")
	assert_eq(TrafficAudio.distance_gain(150.0, 5.0, 150.0, 1.0), 0.0, "am Maximalabstand 0")
	assert_eq(TrafficAudio.distance_gain(400.0, 5.0, 150.0, 1.0), 0.0, "dahinter 0")
	assert_true(TrafficAudio.distance_gain(10.0, 11.0, 150.0, 1.0) > TrafficAudio.distance_gain(10.0, 5.0, 150.0, 1.0),
		"große Quelle (Bezug × Größe) fällt in der Nähe langsamer ab")
	# monotonic and continuous: per 5 cm never more than the steepest slope (1/ref at the reference distance)
	var last := 1.0
	var d := 0.0
	while d < 160.0:
		var g := TrafficAudio.distance_gain(d, 5.0, 150.0, 1.0)
		assert_true(g <= last + 1.0e-7, "monoton fallend bei %.2f m" % d)
		assert_true(last - g <= 0.05 / 5.0 + 1.0e-6, "keine Sprünge bei %.2f m" % d)
		last = g
		d += 0.05


func test_doppler_factor() -> void:
	var c := TrafficAudio.SPEED_OF_SOUND
	# car 40 m ahead, 12.5 m/s slower than the listener: we close in -> higher
	var ahead := TrafficAudio.doppler_factor(Vector2(0.0, 40.0), Vector2(0.0, -12.5), 1.0)
	assert_near(ahead, c / (c - 12.5), 1.0e-5, "rein radial, Faktor 1")
	var behind := TrafficAudio.doppler_factor(Vector2(0.0, -40.0), Vector2(0.0, -12.5), 1.0)
	assert_near(behind, c / (c + 12.5), 1.0e-5, "nach dem Überholen tiefer")
	assert_true(ahead > 1.0 and behind < 1.0, "höher davor, tiefer danach")
	assert_near(TrafficAudio.doppler_factor(Vector2(-3.75, 0.0), Vector2(0.0, -12.5), 2.0), 1.0, 1.0e-6, "querab: keine Verschiebung")
	assert_near(TrafficAudio.doppler_factor(Vector2(0.0, 40.0), Vector2(0.0, -12.5), 0.0), 1.0, 1.0e-6, "Faktor 0: aus")
	var k2 := TrafficAudio.doppler_factor(Vector2(0.0, 40.0), Vector2(0.0, -12.5), 2.0)
	assert_near(k2, c / (c - 25.0), 1.0e-5, "Übertreibung skaliert die Geschwindigkeit")
	# oblique: only the component along the line of sight counts
	var obl := TrafficAudio.doppler_factor(Vector2(3.0, 4.0), Vector2(0.0, -10.0), 1.0)
	assert_near(obl, c / (c - 8.0), 1.0e-5, "schräg: Anteil entlang der Sichtlinie")
	assert_near(TrafficAudio.doppler_factor(Vector2(0.0, 10.0), Vector2(0.0, -500.0), 3.0), 2.0, 1.0e-6, "begrenzt nach oben")
	assert_near(TrafficAudio.doppler_factor(Vector2(0.0, -10.0), Vector2(0.0, -500.0), 3.0), 2.0 / 3.0, 1.0e-6, "begrenzt nach unten")


func test_speed_pitch_level_and_air() -> void:
	assert_near(TrafficAudio.speed_pitch(120.0, 120.0, 1.0), 1.0, 1.0e-6, "Bezugstempo = 1")
	assert_near(TrafficAudio.speed_pitch(60.0, 120.0, 1.0), 0.6, 1.0e-6, "untere Grenze 0,6")
	assert_near(TrafficAudio.speed_pitch(90.0, 120.0, 1.0), 0.75, 1.0e-6, "linear mit dem Tempo")
	assert_near(TrafficAudio.speed_pitch(250.0, 120.0, 1.0), 1.6, 1.0e-6, "obere Grenze 1,6")
	assert_near(TrafficAudio.speed_pitch(60.0, 120.0, 0.35), pow(0.5, 0.35), 1.0e-6, "Exponent")
	assert_near(TrafficAudio.speed_level_db(1200.0, 120.0, 30.0), 30.0, 1.0e-4, "eine Dekade = level_db_per_decade")
	assert_near(TrafficAudio.speed_level_db(60.0, 120.0, 30.0), -30.0 * log(2.0) / log(10.0), 1.0e-4, "halbes Tempo")
	assert_eq(TrafficAudio.speed_level_db(60.0, 120.0, 0.0), 0.0, "ohne Feld: 0")
	assert_true(TrafficAudio.speed_level_db(0.0, 120.0, 30.0) > -60.0, "Stillstand endlich")
	assert_near(TrafficAudio.air_cutoff_hz(0.0, 30.0), 20000.0, 1.0e-3, "nah offen")
	assert_near(TrafficAudio.air_cutoff_hz(30.0, 30.0), 10000.0, 1.0e-3, "bei traffic_air_m halbiert")
	var last := 1.0e9
	for d in [0.0, 5.0, 20.0, 50.0, 100.0, 150.0, 1000.0]:
		var f := TrafficAudio.air_cutoff_hz(float(d), 30.0)
		assert_true(f < last or f == TrafficAudio.CUTOFF_MIN, "dumpfer mit der Entfernung (%s m)" % str(d))
		assert_true(f >= TrafficAudio.CUTOFF_MIN, "nie unter CUTOFF_MIN")
		last = f


func test_id_random_and_spread() -> void:
	var sum := 0.0
	var seen := {}
	for id in range(1, 2001):
		var r := TrafficAudio.id_random(id, 11)
		assert_true(r >= 0.0 and r < 1.0, "in [0, 1)")
		sum += r
		seen[int(r * 1000.0)] = true
		var s := TrafficAudio.spread_of(id)
		assert_true(s >= 0.94 - 1.0e-6 and s <= 1.06 + 1.0e-6, "Streuung ±6 %")
	assert_between(sum / 2000.0, 0.45, 0.55, "Mittelwert")
	assert_true(seen.size() > 700, "gut verteilt (%d Klassen)" % seen.size())
	assert_eq(TrafficAudio.id_random(77, 3), TrafficAudio.id_random(77, 3), "deterministisch")
	assert_true(TrafficAudio.id_random(77, 3) != TrafficAudio.id_random(77, 4), "Salz macht unabhängig")
	assert_true(TrafficAudio.spread_of(-2) > 0.9, "Polizei-ID geht")


# --- voices -------------------------------------------------------------------------------------------

func test_nearest_vehicles_get_voices() -> void:
	var t := _ta()
	t.ahead_m = 0.0
	var cars: Array = []
	for i in 10:
		cars.append(_car(100 + i, 10.0 + i * 12.0, -LANE if i % 2 == 0 else LANE, 100.0))
	cars.append(_car(500, 400.0, 0.0, 100.0))   # beyond traffic_max_m
	t.update(DT, cars, _listener(0.0, 120.0))
	var ids: Array[int] = []
	for v in t.voices:
		ids.append(v.vehicle)
	for i in 6:
		assert_true(ids.has(100 + i), "Fahrzeug %d (nah) hat eine Stimme" % i)
	for i in range(6, 10):
		assert_false(ids.has(100 + i), "Fahrzeug %d (fern) hat keine" % i)
	assert_false(ids.has(500), "jenseits von traffic_max_m keine Stimme")
	var v0 := _slot_of(t, 100)
	assert_eq(v0.cls, "car", "Klasse")
	assert_true(["car_petrol", "car_diesel"].has(v0.sounds[0]), "Motorvariante aus der Klasse")
	assert_eq(v0.sounds[1], "tires_car", "Reifen")
	assert_eq(v0.sounds[2], "air", "Luft")
	# the engine variant is fixed per id, both variants occur
	var variants := {}
	for id in range(1, 60):
		var tt := _ta()
		tt.update(DT, [_car(id, 10.0, LANE, 100.0)], _listener(0.0, 120.0))
		variants[tt.voices[0].sounds[0]] = true
	assert_eq(variants.size(), 2, "beide Motorvarianten kommen vor")


func test_hysteresis_and_release_before_reuse() -> void:
	var t := _ta()
	t.ahead_m = 0.0
	t.voice_count = 1
	t._resize_voices()
	var a := _car(1, 40.0, LANE, 120.0)
	var b := _car(2, 37.0, -LANE, 120.0)
	t.update(DT, [a], _listener(0.0, 120.0))
	assert_eq(t.voices[0].vehicle, 1, "A bekommt die Stimme")
	for i in 30:
		t.update(DT, [a, b], _listener(0.0, 120.0))
	assert_eq(t.voices[0].vehicle, 1, "B ist nur knapp näher: A behält die Stimme (Hysterese)")
	assert_false(t.voices[0].releasing, "A wird nicht ausgeblendet")
	b["z"] = 20.0
	t.update(DT, [a, b], _listener(0.0, 120.0))
	assert_eq(t.voices[0].vehicle, 1, "B deutlich näher: A blendet erst aus …")
	assert_true(t.voices[0].releasing, "… A wird freigegeben")
	var frames := 0
	while t.voices[0].vehicle == 1 and frames < 200:
		var before := _total(t.voices[0])
		t.update(DT, [a, b], _listener(0.0, 120.0))
		if t.voices[0].vehicle == 1:
			assert_true(_total(t.voices[0]) <= before + 1.0e-6, "Ausblenden ohne Anstieg")
		frames += 1
	assert_between(frames, int(t.fade_s / DT) - 2, int(t.fade_s / DT) + 3, "Ausblenden dauert traffic_fade_s")
	t.update(DT, [a, b], _listener(0.0, 120.0))
	assert_eq(t.voices[0].vehicle, 2, "erst die stille Stimme geht an B")
	assert_true(t.voices[0].fade < 0.1, "B blendet ein")


func test_gains_change_smoothly_frame_to_frame() -> void:
	# dense traffic with lane changes, overtakers from behind and vehicles leaving: no slot's gain may jump
	var t := _ta()
	var cars: Array = []
	for i in 14:
		cars.append(_car(10 + i, -60.0 + i * 15.0, [-LANE, 0.0, LANE][i % 3], 90.0 + (i * 13) % 70,
			"traffic/truck_white" if i % 5 == 0 else "traffic/sedan_blue", 16.5 if i % 5 == 0 else 4.7))
	var lz := 0.0
	var fade_step := 0.0
	var amp_ratio := Vector2(1.0, 1.0)
	var last_fade := PackedFloat32Array()
	last_fade.resize(t.voices.size())
	var last_amp := PackedFloat32Array()
	last_amp.resize(t.voices.size())
	var last_gen := PackedInt32Array()
	last_gen.resize(t.voices.size())
	var assigned := 0
	for f in 600:
		lz += 130.0 / 3.6 * DT
		for c: Dictionary in cars:
			c["z"] = float(c["z"]) + float(c["speed"]) / 3.6 * DT
		if f == 300:
			cars.remove_at(3)   # one vanishes (despawn)
		t.update(DT, cars, _listener(lz, 130.0))
		for s in t.voices.size():
			var v := t.voices[s]
			var amp := v.amp[0] + v.amp[1] + v.amp[2]
			if v.gen == last_gen[s]:
				fade_step = maxf(fade_step, absf(v.fade - last_fade[s]))
				if amp > 1.0e-3 and last_amp[s] > 1.0e-3 and v.vehicle != TrafficAudio.NONE:
					amp_ratio = Vector2(minf(amp_ratio.x, amp / last_amp[s]), maxf(amp_ratio.y, amp / last_amp[s]))
			elif v.vehicle != TrafficAudio.NONE:
				assigned += 1
				assert_true(v.fade <= DT / t.fade_s + 1.0e-6, "neue Stimme beginnt bei Null (fade %.3f)" % v.fade)
			last_fade[s] = v.fade
			last_amp[s] = amp
			last_gen[s] = v.gen
	assert_true(assigned > 6, "Stimmen wurden neu vergeben (%d)" % assigned)
	# the fade moves by at most DT / fade_s per frame; the level from the geometry changes only a little per frame
	assert_true(fade_step <= DT / t.fade_s + 1.0e-5, "Blende je Frame %.4f" % fade_step)
	assert_between(amp_ratio.x, 0.85, 1.0, "Pegel fällt je Frame höchstens 15 %% (%.3f)" % amp_ratio.x)
	assert_between(amp_ratio.y, 1.0, 1.18, "Pegel steigt je Frame höchstens 18 %% (%.3f)" % amp_ratio.y)


func test_pass_by_on_the_left() -> void:
	var t := _ta()
	var lz := 0.0
	var car := _car(7, 40.0, -LANE, 105.0)
	var left_louder := 0
	var beside_clear := 0
	var frames := 0
	var beside := 0
	var peak := 0.0
	var at_pass := 0.0
	var dop_before := 0.0
	var dop_after := 0.0
	var pitch_before := 0.0
	var pitch_after := 0.0
	for f in 360:   # 6 s at 150 km/h vs 105 km/h: the car is passed after about 3.5 s
		lz += 150.0 / 3.6 * DT
		car["z"] = float(car["z"]) + 105.0 / 3.6 * DT
		t.update(DT, [car], _listener(lz, 150.0))
		var v := _slot_of(t, 7)
		if v == null:
			continue
		var centre := float(car["z"]) + 2.35 - t.listener_z
		frames += 1
		if v.gl[0] > v.gr[0]:
			left_louder += 1
		if absf(centre) < 3.0:
			beside += 1
			if v.gl[0] > v.gr[0] * 4.0:
				beside_clear += 1
		var g := _total(v)
		peak = maxf(peak, g)
		if absf(centre) < 0.5:
			at_pass = g
		if centre > 15.0 and centre < 20.0:
			dop_before = v.doppler
			pitch_before = v.pitch[0]
		if centre < -15.0 and centre > -20.0:
			dop_after = v.doppler
			pitch_after = v.pitch[0]
	assert_true(frames > 300, "Stimme lange aktiv")
	assert_eq(left_louder, frames, "das Auto links ist immer links lauter (%d von %d Frames)" % [left_louder, frames])
	assert_true(beside > 5 and beside_clear == beside, "querab deutlich links (%d von %d)" % [beside_clear, beside])
	assert_true(at_pass >= peak * 0.98, "am lautesten beim Passieren (%.3f von %.3f)" % [at_pass, peak])
	assert_true(at_pass > 0.0, "beim Passieren hörbar")
	assert_true(dop_before > 1.0 and dop_after < 1.0, "Doppler davor %.4f, danach %.4f" % [dop_before, dop_after])
	# 45 km/h relative, exaggerated ×2: about ±7 % at a shallow angle
	assert_between(pitch_before / pitch_after, 1.08, 1.20, "Tonhöhe fällt beim Passieren")


func test_truck_louder_than_car_at_the_same_distance() -> void:
	var t := _ta()
	t.ahead_m = 0.0
	t.update(DT, [_car(1, 20.0, LANE, 85.0, "traffic/truck_white", 16.5), _car(2, 20.0, -LANE, 85.0)], _listener(0.0, 120.0))
	for i in 30:
		t.update(DT, [_car(1, 20.0, LANE, 85.0, "traffic/truck_white", 16.5), _car(2, 20.0, -LANE, 85.0)], _listener(0.0, 120.0))
	var truck := _slot_of(t, 1)
	var car := _slot_of(t, 2)
	assert_eq(truck.cls, "truck", "Lkw-Klasse")
	assert_eq(truck.sounds[0], "truck_diesel", "Lkw-Motor")
	assert_true(_total(truck) > _total(car) * 1.5, "Lkw lauter (%.3f gegen %.3f)" % [_total(truck), _total(car)])
	assert_true(truck.gr[0] > truck.gl[0] and car.gl[0] > car.gr[0], "rechts bzw. links")


func test_pause_fades_out_and_vehicle_gone_releases() -> void:
	var t := _ta()
	var cars := [_car(1, 15.0, -LANE, 100.0), _car(2, 30.0, LANE, 100.0)]
	for i in 40:
		t.update(DT, cars, _listener(0.0, 100.0))
	assert_near(t.voices[0].fade, 1.0, 1.0e-6, "eingeblendet")
	# vehicle 2 vanishes: fades out with its last values, slot freed afterwards
	var v2 := _slot_of(t, 2)
	var before := _total(v2)
	t.update(DT, [cars[0]], _listener(0.0, 100.0))
	assert_true(v2.releasing, "verschwundenes Fahrzeug wird ausgeblendet")
	assert_true(_total(v2) < before and _total(v2) > before * 0.8, "weich, kein Abriss")
	for i in 30:
		t.update(DT, [cars[0]], _listener(0.0, 100.0))
	assert_eq(_slot_of(t, 2), null, "Stimme frei")
	# pause (alive = false): everything fades out within traffic_fade_s
	for i in int(t.fade_s / DT) + 2:
		t.update(DT, [], _listener(0.0, 100.0), false)
	for v in t.voices:
		assert_eq(v.vehicle, TrafficAudio.NONE, "nach der Pause alle frei")
		assert_near(_total(v), 0.0, 1.0e-6, "still")
	# back: fades in again
	t.update(DT, cars, _listener(0.0, 100.0))
	assert_true(_slot_of(t, 1) != null and _slot_of(t, 1).fade < 0.1, "nach der Pause wieder einblenden")


func test_listener_ahead_offset() -> void:
	var t := _ta()
	t.ahead_m = 3.0
	t.update(DT, [], _listener(100.0, 120.0, 1.5))
	assert_near(t.listener_z, 103.0, 1.0e-6, "Hörer vor der Kamera")
	assert_near(t.listener_x, 1.5, 1.0e-6, "quer an der Kamera")
	assert_near(t.listener_v, 120.0 / 3.6, 1.0e-5, "Tempo in m/s")


func test_siren_centred_and_spatial() -> void:
	var t := _ta()
	t.ahead_m = 0.0
	t.set_siren(true, 0.5)
	for i in 60:
		t.update(DT, [], _listener(0.0, 150.0))
	var st := t.state()
	assert_false(bool(st["siren"]["spatial"]), "ohne Polizei in der Liste: mittig")
	assert_near(t.siren.gl[0], 0.5, 0.005, "Pegel wie set_siren")
	assert_near(t.siren.gr[0], 0.5, 0.005, "beide Kanäle gleich")
	# the police car 60 m behind on the left, 30 km/h faster: spatial, left, higher (approaching)
	var pol := {"id": TrafficAudio.POLICE_ID, "set": "police/de", "z": -62.4, "x": -LANE, "length": 4.8, "speed": 180.0}
	for i in 60:
		t.update(DT, [pol], _listener(0.0, 150.0))
	st = t.state()
	assert_true(bool(st["siren"]["spatial"]), "mit Polizei: räumlich")
	assert_true(t.siren.gl[0] > t.siren.gr[0], "links lauter")
	assert_true(t.siren.doppler > 1.01, "nähert sich: höher (%.4f)" % t.siren.doppler)
	var near := t.siren.gl[0] + t.siren.gr[0]
	pol["z"] = -600.0
	for i in 60:
		t.update(DT, [pol], _listener(0.0, 150.0))
	var far := t.siren.gl[0] + t.siren.gr[0]
	assert_true(far < near, "weiter weg leiser")
	assert_true(far >= t.siren_floor * db_to_linear(t.siren_db) * 0.99, "nie unter siren_floor")
	# off: fades out within siren_fade_s
	t.set_siren(false, 0.0)
	for i in int(t.siren_fade_s / DT) + 2:
		t.update(DT, [pol], _listener(0.0, 150.0))
	assert_near(t.siren.gl[0] + t.siren.gr[0], 0.0, 1.0e-6, "aus")


func test_reset_silences_everything() -> void:
	var t := _ta()
	t.set_siren(true, 0.6)
	for i in 30:
		t.update(DT, [_car(1, 10.0, LANE, 100.0)], _listener(0.0, 120.0))
	t.reset()
	for v in t.voices:
		assert_eq(v.vehicle, TrafficAudio.NONE, "frei")
		assert_near(_total(v), 0.0, 1.0e-9, "still")
	assert_eq(t.siren.gl[0], 0.0, "Martinshorn still")


func test_cpu_time_per_frame() -> void:
	var t := _ta()
	var cars: Array = []
	for i in 40:
		cars.append(_car(i + 1, -200.0 + i * 25.0, [-LANE, 0.0, LANE][i % 3], 80.0 + (i * 7) % 90,
			"traffic/truck_white" if i % 6 == 0 else "traffic/sedan_blue"))
	cars.append({"id": TrafficAudio.POLICE_ID, "set": "police/de", "z": -100.0, "x": -LANE, "length": 4.8, "speed": 170.0})
	t.set_siren(true, 0.5)
	var lz := 0.0
	for f in 120:   # warm-up
		lz += 2.0
		t.update(DT, cars, _listener(lz, 150.0))
	t.perf_calls = 0
	t.perf_us_sum = 0
	t.perf_us_max = 0
	for f in 600:
		lz += 2.0
		for c: Dictionary in cars:
			c["z"] = float(c["z"]) + float(c["speed"]) / 3.6 * DT
		t.update(DT, cars, _listener(lz, 150.0))
	var avg_ms := t.perf_us_sum / 1000.0 / t.perf_calls
	print("      TrafficAudio.update: %.3f ms je Frame (max %.3f ms) bei 41 Fahrzeugen, %d Stimmen" % [avg_ms, t.perf_us_max / 1000.0, t.voice_count])
	assert_true(avg_ms < 0.3, "GDScript-Aufwand je Frame %.3f ms < 0,3 ms" % avg_ms)


# --- room ---------------------------------------------------------------------------------------------

func test_room_tunnel_blend() -> void:
	var r := RoomAudio.new()
	r.setup(cfg())
	var p0 := r.params(0.0)
	var p1 := r.params(1.0)
	assert_near(float(p0["wet"]), r.wet, 1.0e-6, "draußen: Hallanteil draußen")
	assert_near(float(p1["wet"]), r.tunnel_wet, 1.0e-6, "im Tunnel: Tunnelhall")
	assert_true(r.tunnel_wet > r.wet, "im Tunnel mehr Hall")
	assert_near(float(p0["reflections_db"]), r.reflections_db, 1.0e-6, "frühe Reflexionen draußen")
	assert_true(float(p1["reflections_db"]) > float(p0["reflections_db"]), "im Tunnel lautere Reflexionen")
	var steps := 0
	var last := -1.0
	while r.blend < 1.0 and steps < 1000:
		r.update(DT, true)
		var w := float(r.params(r.blend)["wet"])
		assert_true(w >= last, "blendet stetig ein")
		assert_true(w - maxf(last, 0.0) < 0.02, "ohne Sprung")
		last = w
		steps += 1
	assert_between(steps * DT, r.fade_s - 0.05, r.fade_s + 0.05, "Einblenden dauert reverb_fade_s")
	for i in 10:
		r.update(DT, false)
	assert_true(r.blend < 1.0 and r.blend > 0.0, "blendet aus")
	r.reset()
	assert_eq(r.blend, 0.0, "reset = draußen")
	assert_between(r.engine_width, 0.0, 1.0, "Motorbreite (Anteil des Breitenhalls)")
	assert_true(r.engine_width_hipass > 0.0, "Breitenhall mit Hochpass: tiefe Motortöne bleiben mono und mittig")
