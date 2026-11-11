extends TestCase
## ModernAudio (contract §4.7): the owner of the Modern sound without a scene tree and without players – what it
## builds and removes, the Arcade semantics of the delegated calls (alive, pause, stop_all, hints), one-shots and
## their de-duplication against session events, snapshots, the effects mute, music contexts, the feed.

const DT := 1.0 / 60.0
const BANK := "res://tests/fixtures/engines/fixture_v4.json"
const TRAFFIC := "res://tests/fixtures/traffic/traffic_sounds.json"


## A slot that claims the collision event (as the real impact slot will).
class Claimer:
	extends ModernAudioModule
	var plays: Array[String] = []
	var events: Array[String] = []

	func claims() -> PackedStringArray:
		return PackedStringArray(["collision"])

	func play(sound: String, _gain_db: float) -> bool:
		if sound != "crash":
			return false
		plays.append(sound)
		return true

	func event(event_name: String, _args: Dictionary) -> void:
		events.append(event_name)


var _bank: EngineBank = null


func _provider(_id: String) -> EngineBank:
	if _bank == null:
		_bank = EngineBank.load_file(BANK)
	return _bank


func _modern(over: Dictionary = {}, opts: Dictionary = {}) -> ModernAudio:
	var c := cfg().duplicate(true)
	var modern: Dictionary = c["audio"]["modern"]
	modern.merge(over, true)
	var o := {"live": false, "quiet": true, "bank_provider": Callable(self, "_provider")}
	o.merge(opts, true)
	var m := ModernAudio.new()
	m.clock_ms = 1000
	m.start(c, o)
	return m


func _done(m: ModernAudio) -> void:
	m.shutdown()
	m.free()
	assert_eq(AudioServer.bus_count, 1, "nach dem Test nur noch Master")


func _steps(m: ModernAudio, n: int, paused: bool = false) -> void:
	for i in n:
		m.clock_ms += 17
		m.step(DT, paused)


func _drive(m: ModernAudio, n: int, speed: float, throttle: float) -> void:
	for i in n:
		m.set_engine(speed, throttle, 230.0, true)
		m.set_wind(speed)
		m.clock_ms += 17
		m.step(DT, false)


func test_start_builds_everything_and_shutdown_removes_it() -> void:
	assert_eq(AudioServer.bus_count, 1, "Ausgangslage")
	var m := _modern()
	assert_true(m.started, "gestartet")
	assert_eq(AudioServer.bus_count, 1 + ModernBuses.names().size(), "Busse angelegt")
	assert_eq(m.modules.size(), ModernAudio.SLOTS.size(), "ein Objekt je Baustein")
	assert_eq(ModernAudio.SLOTS, ["env", "engine", "layers", "road", "impact", "ambience", "traffic", "music", "sfx"] as Array[String], "Bausteine in ihrer Reihenfolge")
	var classes := [EnvAcoustics, EngineAudio3, VehicleLayers, RoadAudio, ImpactAudio, AmbienceAudio, TrafficExtras, MusicDirector, SfxBank]
	for i in m.modules.size():
		assert_true(is_instance_of(m.modules[i], classes[i]), "Baustein %s hat seine Klasse" % ModernAudio.SLOTS[i])
		assert_true(m.modules[i].ctx == m.ctx, "Baustein %s kennt den Kontext" % ModernAudio.SLOTS[i])
	assert_false(m.ctx.live, "ohne Wiedergabe")
	assert_eq(m.get_child_count(), 0, "keine Player ohne Wiedergabe")
	assert_true(m.assets.errors.is_empty(), "Manifeste ohne Fehler")
	assert_false(m.assets.use_placeholders, "Platzhalter nicht benutzt")
	var s := m.debug_state()
	assert_true((s["bus_problems"] as Array).is_empty(), "Busgraph in Ordnung")
	assert_eq((s["slots"] as Dictionary).size(), 9, "Zustand je Baustein")
	assert_true(JSON.stringify(s).length() > 100, "Zustand als JSON darstellbar")
	m.start(cfg())   # a second start changes nothing
	assert_eq(AudioServer.bus_count, 1 + ModernBuses.names().size(), "zweites start() ohne Wirkung")
	m.shutdown()
	assert_eq(AudioServer.bus_count, 1, "Busse entfernt")
	assert_false(m.started, "beendet")
	assert_true(m.modules.is_empty(), "Bausteine freigegeben")
	m.shutdown()   # harmless
	m.step(DT, false)
	m.play("crash")
	m.event("go")
	assert_eq(bool(m.debug_state()["started"]), false, "Aufrufe nach dem Ende tun nichts")
	m.free()
	# twenty rounds leave nothing behind
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	for i in 20:
		var x := _modern()
		x.set_vehicle("kompakt")
		_drive(x, 3, 100.0, 1.0)
		x.shutdown()
		x.free()
	assert_eq(AudioServer.bus_count, 1, "nach 20 Runden nur Master")
	assert_true(Performance.get_monitor(Performance.OBJECT_COUNT) <= objects + 4, "keine Objekte übrig (%d → %d)" % [int(objects), int(Performance.get_monitor(Performance.OBJECT_COUNT))])


func test_engine_follows_the_session() -> void:
	var m := _modern()
	m.set_vehicle("kompakt")
	var idle := m.engine_state()
	for k: String in ["rpm", "gear", "load", "boost"]:
		assert_true(idle.has(k), "engine_state() hat %s" % k)
	_drive(m, 90, 0.0, 0.0)
	assert_true(m.frame.alive, "die Sitzung fährt")
	var rpm_idle := float(m.engine_state()["rpm"])
	_drive(m, 240, 140.0, 1.0)
	assert_true(float(m.engine_state()["rpm"]) > rpm_idle + 300.0, "Drehzahl steigt (%.0f → %.0f)" % [rpm_idle, float(m.engine_state()["rpm"])])
	assert_true(int(m.engine_state()["gear"]) >= 1, "Gang eingelegt")
	assert_near(float(m.frame.engine.get("rpm", 0.0)), float(m.engine_state()["rpm"]), 1.0e-6, "die Bausteine sehen denselben Motorzustand")
	assert_near(m.road.wind.level, pow((140.0 - 35.0) / 220.0, 1.4) * 0.55, 0.02, "Wind wie in Arcade")
	# the session stops calling: gone after ALIVE_S
	_steps(m, 10)
	assert_true(m.frame.alive, "0,17 s ohne Aufruf: noch da")
	_steps(m, 15)
	assert_false(m.frame.alive, "nach %.2f s ohne Aufruf weg" % ModernAudio.ALIVE_S)
	_steps(m, 60)
	assert_near(m.road.wind.level, 0.0, 0.01, "Wind ausgeblendet")
	assert_eq(int(m.engine_perf()["frames"]), 0, "ohne Wiedergabe wird nichts gemischt")
	# a car without a bank: the generic gearbox still gives a state
	# (engine v3, AU-B: the banks are the Modern ones of assets/audio/modern/engines, not those of the Arcade bank
	# provider – a car without a bank is one the folder does not know)
	var n := _modern({}, {"bank_provider": Callable()})
	n.set_vehicle("gibtsnicht")
	_drive(n, 120, 120.0, 1.0)
	assert_true(float(n.engine_state()["rpm"]) > 500.0, "Getriebe ohne Bank läuft")
	assert_false(bool(n.debug_state()["slots"]["engine"]["bank"]), "keine Bank")
	_done(n)
	_done(m)


func test_calls_while_paused_or_after_stop_all_are_ignored() -> void:
	var m := _modern()
	m.set_vehicle("kompakt")
	_drive(m, 30, 100.0, 0.5)
	assert_true(m.frame.alive, "fährt")
	# pause: the frame says so, calls are ignored, nothing is alive
	m.step(DT, true)
	m.set_engine(200.0, 1.0, 230.0, true)
	m.set_traffic([{"id": 1, "set": "traffic/sedan_blue", "z": 10.0, "x": 3.0, "length": 4.7, "speed": 90.0}], {"z": 0.0, "x": 0.0, "speed": 100.0})
	m.set_vehicle_state({"z": 5.0, "x": 0.0})
	m.step(DT, true)
	assert_true(m.frame.paused, "Pause im Bild vermerkt")
	assert_false(m.frame.alive, "in der Pause fährt niemand")
	assert_false(m.frame.traffic_alive, "kein Verkehr in der Pause")
	assert_false(m.frame.has_state, "kein Fahrzeugzustand in der Pause")
	assert_near(m.frame.speed, 100.0, 1.0e-6, "die Werte von vor der Pause bleiben")
	# resume
	m.step(DT, false)
	_drive(m, 5, 120.0, 0.5)
	assert_true(m.frame.alive, "nach der Pause wieder da")
	# stop_all: everything of the race is gone at once; calls of the same frame are ignored until the next car
	m.set_siren(true, 0.8)
	m.set_environment({"tunnel": true})
	m.step(DT, false)
	m.stop_all()
	m.set_engine(150.0, 1.0, 230.0, true)
	m.set_environment({"tunnel": true})
	m.step(DT, false)
	assert_false(m.frame.alive, "nach stop_all() im selben Frame kein Neustart")
	assert_false(m.frame.siren_on, "Martinshorn aus")
	assert_false(m.frame.tunnel, "Tunnel vergessen")
	assert_near(m.road.wind.level, 0.0, 1.0e-6, "Schleifen sofort still")
	assert_near(m.env.blend(), 0.0, 1.0e-6, "Raumklang wieder draußen")
	m.set_vehicle("kompakt")
	_drive(m, 3, 80.0, 0.3)
	assert_true(m.frame.alive, "mit dem nächsten Auto geht es weiter")
	_done(m)


func test_rain_skid_and_siren_rules() -> void:
	var m := _modern()
	m.set_vehicle("kompakt")
	# HUD hints only
	for i in 20:
		m.set_engine(100.0, 0.5, 230.0, true)
		m.hud_hints({"weather": "rain", "in_tunnel": false, "understeer": 0.6, "police_state": "none"})
		_steps(m, 1)
	assert_near(m.frame.rain, 1.0, 1.0e-6, "Regen aus dem HUD-Hinweis")
	assert_near(m.frame.skid, 0.6, 1.0e-6, "Quietschen aus dem HUD-Hinweis")
	assert_true(m.ambience.rain.level > 0.05, "Regenschleife blendet ein")
	assert_true(m.road.skid.level > 0.05, "Quietschen blendet ein")
	# explicit calls win for a second
	m.set_rain(0.0)
	m.set_skid(0.0)
	m.hud_hints({"weather": "rain", "understeer": 0.6})
	_steps(m, 1)
	assert_near(m.frame.rain, 0.0, 1.0e-6, "set_rain() hat Vorrang")
	assert_near(m.frame.skid, 0.0, 1.0e-6, "set_skid() hat Vorrang")
	for i in 70:
		m.set_engine(100.0, 0.5, 230.0, true)
		m.hud_hints({"weather": "rain", "understeer": 0.6})
		_steps(m, 1)
	assert_near(m.frame.rain, 1.0, 1.0e-6, "nach einer Sekunde gilt wieder der Hinweis")
	m.hud_hints({"weather": "rain", "in_tunnel": true})
	_steps(m, 1)
	assert_near(m.frame.rain, 0.0, 1.0e-6, "im Tunnel kein Regen")
	# siren: level from the distance; the HUD's chase state decides when it sends hints
	m.set_siren(true, 1.0)
	m.set_engine(100.0, 0.5, 230.0, true)
	m.hud_hints({"police_state": "none"})
	_steps(m, 1)
	assert_false(m.frame.siren_on, "ohne Verfolgung laut HUD kein Horn")
	m.set_engine(100.0, 0.5, 230.0, true)
	m.hud_hints({"police_state": "chase", "police_gap_m": 0.0})
	_steps(m, 1)
	assert_near(m.frame.siren_level, 0.8, 1.0e-5, "nah: 0,8")
	m.set_engine(100.0, 0.5, 230.0, true)
	m.hud_hints({"police_state": "chase", "police_gap_m": 420.0})
	_steps(m, 1)
	assert_near(m.frame.siren_level, lerpf(0.18, 0.8, 0.15), 1.0e-5, "fern: Mindestwert")
	_steps(m, 40)   # no hints any more, the session still alive? no – nothing calls: off
	assert_false(m.frame.siren_on, "ohne Sitzung und Hinweise aus")
	_done(m)


func test_one_shots_reach_their_slot() -> void:
	var streams := {}
	for n: String in SfxBank.ARCADE_DB:
		streams[n] = AudioStreamWAV.new()   # stand-ins for the SfxSynth streams of the AudioManager
	var m := _modern({}, {"streams": streams})
	m.play("crash")
	m.play("rail", -4.0)
	m.clock_ms += 100
	m.play("ui_move")
	m.play("flash")
	m.play("gibt_es_nicht")
	m.play("ui/platzhalter_blip")   # a placeholder: not there in a normal run
	assert_eq(int(m.impact.counts.get("crash", 0)), 1, "crash beim Aufprall-Baustein")
	assert_eq(int(m.impact.counts.get("rail", 0)), 1, "rail beim Aufprall-Baustein")
	assert_near(m.impact.voices.last_db, -5.0 - 4.0, 1.0e-6, "Pegel: Arcade-Wert + gain_db")
	assert_true(m.impact.voices.last_stream == streams["rail"], "der Arcade-Klang, solange es keinen Modern-Klang gibt")
	assert_eq(int(m.sfx.counts.get("ui_move", 0)), 1, "ui_move bei der SfxBank")
	assert_eq(int(m.sfx.counts.get("flash", 0)), 1, "flash bei der SfxBank")
	assert_eq(int(m.sfx.counts.get("crash", 0)), 0, "crash nicht doppelt")
	assert_eq(str(m.sfx.sources.get("ui_move", "")), "arcade", "ohne Modern-Datei der Arcade-Klang")
	assert_false(m.plays.has("gibt_es_nicht"), "Unbekanntes spielt nicht")
	assert_false(m.plays.has("ui/platzhalter_blip"), "Platzhalter spielen im Spiel nicht")
	assert_near(m.mix.weight("impact"), 0.0, 1.0e-6, "Zustand impact ist ausgelöst, aber noch nicht gerechnet")
	_steps(m, 3)
	assert_true(m.mix.weight("impact") > 0.9, "ein Aufprall löst den Zustand impact aus")
	# the same one-shot twice within 45 ms plays once (as Arcade)
	m.clock_ms += 500
	m.play("ui_ok")
	m.clock_ms += 30
	m.play("ui_ok")
	m.clock_ms += 30
	m.play("ui_ok")
	assert_eq(int(m.sfx.counts.get("ui_ok", 0)), 2, "Wiederholung innerhalb 45 ms ignoriert")
	_done(m)
	# with placeholders switched on (tests only) the Modern file plays, by id and bus of the manifest
	var p := _modern({"placeholders": true})
	p.play("ui/platzhalter_blip", -3.0)
	p.play("sfx/platzhalter_hit")
	assert_eq(int(p.plays.get("ui/platzhalter_blip", 0)), 1, "Modern-Einmalklang nach Ordner/Id")
	assert_eq(str(p.sfx.sources.get("ui/platzhalter_blip", "")), "modern", "aus der Modern-Datei")
	assert_true((p.sfx._pools["MUI"] as ModernAudioVoices).last_stream is AudioStreamWAV, "auf dem Bus des Manifests")
	assert_near((p.sfx._pools["MUI"] as ModernAudioVoices).last_db, -3.0, 1.0e-6, "gain_db des Aufrufs + des Manifests")
	assert_eq((p.sfx._pools["MSfx"] as ModernAudioVoices).played, 1, "sfx-Platzhalter auf MSfx")
	_done(p)


func test_a_play_and_its_event_sound_once() -> void:
	var m := _modern()
	var c := Claimer.new()
	c.setup(m.ctx)
	m.modules.insert(0, c)
	m._claimed["collision"] = true
	# play() first, the event right after (the order of the race session): the play is dropped
	m.play("crash")
	assert_true(c.plays.is_empty(), "das play() wartet auf sein Ereignis")
	m.clock_ms += 2
	m.event("collision", {"speed_kmh": 90.0, "heavy": false, "side": 1})
	_steps(m, 6)
	assert_eq(c.events, ["collision"] as Array[String], "das Ereignis kommt an")
	assert_true(c.plays.is_empty(), "das play() klingt nicht zusätzlich")
	assert_eq(int(m.dropped.get("crash", 0)), 1, "als doppelt verworfen")
	# the event first, the play within 50 ms: dropped as well
	m.clock_ms += 1000
	m.event("collision", {})
	m.clock_ms += 30
	m.play("crash")
	_steps(m, 6)
	assert_true(c.plays.is_empty(), "play() nach dem Ereignis verworfen")
	assert_eq(int(m.dropped.get("crash", 0)), 2, "zweimal verworfen")
	# a play() without its event (another caller): it sounds, 50 ms late
	m.clock_ms += 1000
	m.play("crash")
	m.clock_ms += 30
	m.step(DT, false)
	assert_true(c.plays.is_empty(), "nach 30 ms wartet es noch")
	m.clock_ms += 30
	m.step(DT, false)
	assert_eq(c.plays, ["crash"] as Array[String], "ohne Ereignis spielt es nach %d ms" % ModernAudio.DEDUP_MS)
	# sounds whose event nobody claims are immediate
	m.clock_ms += 1000
	m.play("go")
	assert_eq(int(m.sfx.counts.get("go", 0)), 1, "go sofort")
	m.event("go")
	assert_eq(int(m.sfx.counts.get("go", 0)), 1, "das Ereignis go spielt nichts dazu")
	assert_eq(int(m.events_seen.get("go", 0)), 1, "aber es wird verteilt")
	# stop_all() forgets waiting one-shots
	m.clock_ms += 1000
	m.play("crash")
	m.stop_all()
	m.clock_ms += 200
	m.step(DT, false)
	assert_eq(c.plays.size(), 1, "nach stop_all() kommt nichts nach")
	for sound: String in ModernAudio.PLAY_EVENTS:
		assert_true(SfxBank.ROUTES.has(sound), "%s ist ein bekannter Einmalklang" % sound)
	_done(m)


func test_snapshots_follow_the_game() -> void:
	var m := _modern()
	m.set_vehicle("kompakt")
	m.set_music_context("race")
	_drive(m, 10, 120.0, 1.0)
	assert_near(m.buses.lowpass_hz("MMusic"), 20000.0, 0.1, "Ausgangslage: kein Tiefpass")
	# pause menu: low-pass and dip on the music
	_steps(m, 30, true)
	assert_true(m.mix.weight("pause") > 0.99, "Pause aktiv")
	assert_near(m.buses.lowpass_hz("MMusic"), float(ConfigLoader.lookup(cfg(), "audio.modern.snapshots.pause.lowpass_hz.MMusic", 0.0)), 1.0, "Tiefpass auf dem Bus")
	assert_true(m.buses.gain_db("MMusic") < -5.0, "Musik abgesenkt (%.1f dB)" % m.buses.gain_db("MMusic"))
	_steps(m, 60, false)
	assert_near(m.buses.lowpass_hz("MMusic"), 20000.0, 0.1, "nach der Pause wieder offen")
	# chase: the siren dips the music
	for i in 60:
		m.set_engine(120.0, 0.5, 230.0, true)
		m.set_siren(true, 0.5)
		_steps(m, 1)
	assert_true(m.mix.weight("siren") > 0.99, "Verfolgung aktiv")
	assert_near(m.buses.gain_db("MMusic") - m.mix.duck_db, float(ConfigLoader.lookup(cfg(), "audio.modern.snapshots.siren.gain_db.MMusic", 0.0)), 0.05, "Musik unter dem Horn (zusätzlich zur Absenkung unter dem Auto)")
	assert_true(m.mix.duck_db < -1.0, "und unter dem fahrenden Auto (%.1f dB)" % m.mix.duck_db)
	m.set_siren(false, 0.0)
	# collision event
	m.event("collision", {"speed_kmh": 120.0, "heavy": true, "side": -1})
	_steps(m, 3)
	assert_true(m.mix.weight("impact") > 0.9, "Kollision: Zustand impact")
	# finish: car and world go down until the stage is left
	m.event("stage_finish", {"record": true, "last_stage": false})
	for i in 90:
		m.set_engine(60.0, 0.0, 230.0, false)
		_steps(m, 1)
	assert_true(m.mix.weight("result") > 0.99, "nach der Ziellinie: Zustand result")
	assert_true(m.buses.gain_db("MCar") < -6.0, "Auto leiser (%.1f dB)" % m.buses.gain_db("MCar"))
	m.stop_all()
	_steps(m, 60)
	assert_near(m.mix.weight("result"), 0.0, 1.0e-6, "mit dem Verlassen der Etappe vorbei")
	assert_near(m.buses.gain_db("MCar"), 0.0, 0.01, "Auto-Bus wieder neutral")
	# the race EQ of the music follows the context – gliding, so the level of the music never steps
	assert_near(m.buses.music_eq_amount(), 1.0, 1.0e-6, "im Rennen ist der Musik-EQ ganz an")
	m.set_music_context("menu")
	_steps(m, 1)
	assert_between(m.buses.music_eq_amount(), 0.5, 0.999, "er blendet aus")
	_steps(m, 60)
	assert_false(m.buses.music_eq_on(), "im Menü aus")
	m.set_music_context("race")
	_steps(m, 1)
	assert_between(m.buses.music_eq_amount(), 0.001, 0.5, "und wieder ein")
	_steps(m, 60)
	assert_near(m.buses.music_eq_amount(), 1.0, 1.0e-6, "ganz an")
	_done(m)


func test_ducking_follows_the_car() -> void:
	var m := _modern()
	var depth := float(ConfigLoader.lookup(cfg(), "audio.modern.duck.depth_db", 0.0))
	assert_true(depth >= 3.0, "mindestens 3 dB")
	m.set_vehicle("kompakt")
	_drive(m, 90, 0.0, 0.0)
	assert_near(m.buses.gain_db("MMusic"), 0.0, 0.02, "im Leerlauf bleibt die Musik oben")
	assert_near(m.mix.car, float(m.mix.loudness["idle_lufs"]), 0.5, "Auto nach Plan im Leerlauf")
	_drive(m, 150, 150.0, 1.0)
	assert_near(m.buses.gain_db("MMusic"), -depth, 0.1, "Vollgas: Musik um die volle Tiefe abgesenkt")
	assert_near(m.mix.car, float(m.mix.loudness["full_throttle_lufs"]), 0.5, "Auto nach Plan bei Vollgas")
	# the session leaves (stop calling): the music comes back within about two seconds
	_steps(m, 150)
	assert_near(m.buses.gain_db("MMusic"), 0.0, 0.05, "und wieder zurück")
	# tests may give the loudness of the car directly
	m.car_lufs_override = -16.0
	_steps(m, 60)
	assert_near(m.buses.gain_db("MMusic"), -depth, 0.05, "vorgegebene Lautheit des Autos")
	_done(m)


func test_no_ducking_for_a_car_the_mix_turned_down() -> void:
	var m := _modern()
	var depth := float(ConfigLoader.lookup(cfg(), "audio.modern.duck.depth_db", 0.0))
	m.set_vehicle("kompakt")
	_drive(m, 150, 150.0, 1.0)
	assert_near(m.buses.gain_db("MMusic"), -depth, 0.1, "Vollgas: Musik abgesenkt")
	# behind the finish line the state "result" turns the car down: still flat out, but the music comes back
	m.event("stage_finish", {"record": false, "last_stage": false})
	_drive(m, 240, 150.0, 1.0)
	assert_true(m.buses.gain_db("MCar") < -6.0, "Auto leise gestellt (%.1f dB)" % m.buses.gain_db("MCar"))
	assert_near(m.buses.gain_db("MMusic"), 0.0, 0.1, "ein leise gestelltes Auto senkt die Musik nicht ab")
	_done(m)


func test_effects_mute_follows_the_arcade_sfx_bus_and_the_setting() -> void:
	AudioServer.add_bus()
	AudioServer.set_bus_name(1, "SFX")
	var m := _modern()
	var msfx := AudioServer.get_bus_index("MSfx")
	m.car_lufs_override = -16.0
	_steps(m, 30)
	assert_false(AudioServer.is_bus_mute(msfx), "Ausgangslage: Effekte hörbar")
	assert_true(m.buses.gain_db("MMusic") < -3.0, "Musik unter dem Auto abgesenkt")
	# the attract demo mutes the Arcade effects bus – Modern follows without knowing why
	AudioServer.set_bus_mute(1, true)
	_steps(m, 240)
	assert_true(AudioServer.is_bus_mute(msfx), "MSfx stumm, solange SFX stumm ist")
	assert_true(m.frame.effects_muted, "die Bausteine erfahren es")
	assert_near(m.buses.gain_db("MMusic"), 0.0, 0.02, "die Musik wird dann nicht abgesenkt")
	AudioServer.set_bus_mute(1, false)
	_steps(m, 2)
	assert_false(AudioServer.is_bus_mute(msfx), "wieder hörbar")
	# the volume setting "Effekte" at 0
	m.apply_volumes(0.0, 0.7)
	assert_true(AudioServer.is_bus_mute(msfx), "Effekte 0: sofort stumm")
	_steps(m, 5)
	assert_true(AudioServer.is_bus_mute(msfx), "bleibt stumm")
	m.apply_volumes(1.0, 0.7)
	_steps(m, 2)
	assert_false(AudioServer.is_bus_mute(msfx), "Regler wieder auf: hörbar")
	assert_false(AudioServer.is_bus_mute(1), "der Arcade-Bus wurde nicht angefasst")
	_done_keep(m)
	AudioServer.remove_bus(1)
	assert_eq(AudioServer.bus_count, 1, "aufgeräumt")


func _done_keep(m: ModernAudio) -> void:
	m.shutdown()
	m.free()


func test_volume_settings_and_plan_levels_on_the_buses() -> void:
	var m := _modern({"levels": {"MSfx": -3.0, "MWind": -2.0}})
	m.apply_volumes(0.5, 0.7)
	assert_near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("MSfx")), -3.0 + linear_to_db(0.5), 1.0e-3, "Effekte: Plan + Regler")
	assert_near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("MMusic")), linear_to_db(0.7), 1.0e-3, "Musik: Regler")
	assert_near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("MWind")), -2.0, 1.0e-3, "Planpegel eines Busses")
	assert_near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("MMaster")), 0.0, 1.0e-3, "MMaster 0 dB")
	m.apply_volumes(1.0, 0.0)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("MMusic")), "Musik 0: stumm")
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index("MSfx")), "Effekte hörbar")
	_done(m)
	# debug: --mute-bus names stay muted through every volume change and frame
	var d := _modern({}, {"mute_buses": ["MEnv", "MMusic", "Gibtsnicht"]})
	d.apply_volumes(1.0, 1.0)
	_steps(d, 3)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("MEnv")), "--mute-bus=MEnv bleibt stumm")
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("MMusic")), "--mute-bus=MMusic bleibt stumm")
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index("MSfx")), "die anderen nicht")
	assert_false(d.frame.effects_muted, "ein stummer Teilbus gilt nicht als „Effekte aus“")
	_done(d)


func test_music_contexts() -> void:
	# without Modern music files (an empty asset folder): the menu contexts play today's title theme, a race is silent
	var title := AudioStreamWAV.new()
	var none := {"assets_dir": "res://tests/unit/audio_modern/fixtures/ohne_klaenge"}
	var m := _modern(none, {"streams": {"music": title}})
	assert_eq(m.music.context, "off", "am Anfang still")
	assert_false(m.music.wanted(), "keine Menümusik gewünscht")
	# the menu code's switch alone (waves 0 and 1): menu music = today's title theme at the plan's level
	m.set_music(true)
	_steps(m, 40)
	assert_eq(m.music.context, "menu", "set_music(true) = Menü")
	assert_eq(m.music.current_key(), MusicDirector.ARCADE_KEY, "ohne Modern-Datei: die Titelmelodie von heute")
	assert_near(float(m.music.debug_state()["db"]), m.mix.music_context_db("menu"), 1.0e-6, "Pegel des Kontexts")
	assert_true(m.music.wanted(), "Menümusik gewünscht")
	m.set_music(true)
	assert_eq(m.music.context, "menu", "nochmal an: bleibt")
	# contexts: the screens between stages keep the piece
	m.set_music_context("race_menu")
	_steps(m, 5)
	assert_eq(m.music.current_key(), MusicDirector.ARCADE_KEY, "ohne Zwischenspiel läuft die Titelmelodie weiter")
	m.set_music(true)
	assert_eq(m.music.context, "race_menu", "set_music(true) ändert einen Menü-Kontext nicht")
	m.set_music(false)
	assert_eq(m.music.context, "off", "set_music(false) = aus")
	m.set_music_context("race", {"stage": "kiel_hamburg"})
	m.event("stage_start", {"countdown_s": 0.0})
	_steps(m, 40)
	assert_eq(m.music.current_key(), "", "ohne Rennstück bleibt es im Rennen still")
	assert_false(m.music.wanted(), "im Rennen keine Menümusik")
	assert_eq(m.frame.music_context, "race", "die Bausteine kennen den Kontext")
	m.set_music(true)
	_steps(m, 2)
	assert_eq(m.music.context, "menu", "zurück im Menü")
	assert_eq(m.music.current_key(), MusicDirector.ARCADE_KEY, "Menümusik")
	m.stop_all()
	_steps(m, 2)
	assert_eq(m.music.current_key(), MusicDirector.ARCADE_KEY, "stop_all() lässt die Musik laufen")
	m.set_music_context("gibt_es_nicht")
	assert_eq(m.music.context, "off", "unbekannter Kontext = aus")
	for c in ["title", "result"]:
		m.set_music_context(c)
		_steps(m, 2)
		assert_eq(m.music.current_key(), MusicDirector.ARCADE_KEY, "Kontext %s: Titelmelodie" % c)
	_done(m)
	# the Arcade title theme arrives after the menu context was set (synthesised in a thread while the Modern profile
	# is already active): silence until then – never a piece noted as started without a stream –, then it starts
	var late_streams := {}
	var late := _modern(none, {"streams": late_streams})
	late.set_music_context("menu")
	late.set_music(true)
	_steps(late, 40)
	assert_eq(late.music.context, "menu", "Menü-Kontext gesetzt")
	assert_eq(late.music.current_key(), "", "ohne Stream läuft kein Stück")
	assert_true(late.music.resolve().is_empty(), "resolve() nennt kein Stück ohne Stream")
	late_streams["music"] = title
	_steps(late, 3)
	assert_eq(late.music.current_key(), MusicDirector.ARCADE_KEY, "mit dem Stream beginnt die Titelmelodie")
	assert_true(late.music.resolve().get("stream") == title, "… mit genau diesem Stream")
	late.set_music(false)
	late.set_music(true)
	_steps(late, 3)
	assert_eq(late.music.current_key(), MusicDirector.ARCADE_KEY, "aus und wieder an: läuft")
	_done(late)
	# the shipped files (AU-D1): the title remaster in the menus, race piece 1 from the start of the stage, the option
	# "Musik im Rennen", the ending at the finish (details: test_music_director.gd)
	var r := _modern({"placeholders": true}, {"streams": {"music": title}})
	r.set_music(true)
	_steps(r, 5)
	assert_eq(r.music.current_key(), "music/titel_remaster", "Menü: das Titel-Remaster")
	r.set_music(false)
	r.set_music_context("race", {"stage": "kiel_hamburg"})
	_steps(r, 5)
	assert_eq(r.music.current_key(), "", "Rennkontext: bereit, bis die Etappe beginnt")
	r.event("stage_start", {"countdown_s": 0.0})
	_steps(r, 3)
	var race_key := r.music.current_key()
	assert_true(race_key.begins_with("race/linke_spur#"), "Rennstück 1, kein Platzhalter (%s)" % race_key)
	assert_near(float(r.music.debug_state()["db"]), r.mix.music_context_db("race") + r.assets.entry("music", "linke_spur").gain_db, 1.0e-6, "Pegel des Rennens")
	r.set_race_music(false)
	_steps(r, 2)
	assert_eq(r.music.current_key(), "", "Musik im Rennen aus")
	r.set_race_music(true)
	_steps(r, 2)
	assert_eq(r.music.current_key(), race_key, "wieder an")
	r.event("stage_finish", {"record": false, "last_stage": false})
	_steps(r, 2)
	assert_eq(str(r.music.debug_state()["race_phase"]), MusicDirector.RACE_ENDING, "nach der Ziellinie: der Schluss des Stücks")
	r.set_music(true)
	_steps(r, 2)
	assert_eq(r.music.current_key(), "music/titel_remaster", "zurück im Menü")
	_done(r)


func test_track_and_state_reach_the_feed_and_the_slots() -> void:
	var stage := {"id": "t_modern", "from": "a", "to": "b", "length_km": 40, "seed": 99,
		"sections": [{"length_km": 40, "road": "autobahn", "curviness": 2, "hills": 1, "scenery": "forest_hills", "country": "DE", "speed_limit": null}],
		"fuel_stations_km": [15], "radars": [], "tunnels": [{"km": 6, "length_km": 1, "name": "T"}], "borders": []}
	var plan := StagePlan.build(stage, "a", {"a": {"name": "A", "country": "DE"}, "b": {"name": "B", "country": "DE"}},
		{"DE": {"name": "Deutschland", "name_local": "Deutschland", "limits": {"autobahn": null, "landstrasse": 100, "city": 50}}}, cfg())
	var sc: Variant = ConfigLoader.load_json("res://data/scenery.json")
	var track := Track.new()
	track.setup(plan, cfg(), (sc as Dictionary).get("scenery", {}))
	var m := _modern()
	m.set_vehicle("gran_turismo")
	assert_near(m.feed.track_half_m, 1.95 * 0.42, 0.001, "Spurweite aus der Fahrzeugbreite")
	m.set_track(track, plan)
	assert_true(m.feed.has_track(), "Strecke beim Feed")
	var z := track.km_to_z(2.0)
	while z < track.km_to_z(9.0):
		track.update_window(z - 9.0, 300.0)
		m.set_engine(150.0, 1.0, 270.0, true)
		m.set_vehicle_state({"z": z, "x": 1.875, "speed": 150.0, "road_left": -5.625, "road_right": 5.625, "shoulder_m": 2.5,
			"off_road": 0, "rail_contact": false, "in_tunnel": track.is_tunnel_at(z - 9.0), "weather": "normal", "hour": 12.0})
		_steps(m, 1)
		z += 150.0 / 3.6 * DT
	assert_true(m.frame.has_state, "Fahrzeugzustand im Bild")
	assert_true(m.feed.valid, "Feed gültig")
	assert_eq(int(m.events_seen.get("tunnel_in", 0)), 1, "Tunnelbeginn als Ereignis verteilt")
	assert_eq(int(m.events_seen.get("tunnel_out", 0)), 1, "Tunnelende als Ereignis verteilt")
	assert_true(int(m.events_seen.get("pass_object", 0)) >= 1, "Vorbeifahrten verteilt")
	assert_eq(m.road.passes, int(m.events_seen.get("pass_object", 0)), "die Bausteine bekommen sie")
	assert_eq(m.frame.feed.zone, "forest", "Zone im Bild")
	# the state goes stale like the engine does; the stage ends
	_steps(m, 30)
	assert_false(m.frame.has_state, "ohne Aufrufe kein Fahrzeugzustand mehr")
	assert_false(m.feed.valid, "Feed ungültig")
	m.set_track(null, null)
	assert_false(m.feed.has_track(), "Strecke abgegeben")
	_done(m)


func test_traffic_runs_on_eight_modern_voices() -> void:
	var arcade := TrafficAudio.new()
	arcade.setup(cfg())
	assert_true(arcade.load_sounds(TRAFFIC, false), "Fixture-Klänge")
	var m := _modern({}, {"arcade_traffic": arcade})
	assert_eq(m.traffic.model.voices.size(), 8, "acht Stimmen (MTrafficV0–7)")
	assert_true(m.traffic.model.ok, "Klänge vom Arcade-Objekt übernommen")
	assert_true(m.traffic.model.sounds == arcade.sounds, "dieselben Klänge, keine Kopie")
	var cars: Array = []
	for i in 10:
		cars.append({"id": i + 1, "set": "traffic/sedan_blue", "z": 20.0 + i * 9.0, "x": -1.9 if i % 2 == 0 else 1.9, "length": 4.7, "speed": 110.0})
	cars.append({"id": -2, "set": "police/de", "z": -40.0, "x": 0.0, "length": 4.8, "speed": 180.0})
	for i in 40:
		m.set_engine(120.0, 0.5, 230.0, true)
		m.set_siren(true, 0.7)
		m.set_traffic(cars, {"z": 0.0, "x": 0.0, "speed": 120.0})
		m.set_environment({"tunnel": true})
		_steps(m, 1)
	var st := m.traffic_state()
	for k: String in ["ok", "voices", "listener", "siren", "tunnel_blend"]:
		assert_true(st.has(k), "traffic_state() hat %s" % k)
	var used := 0
	for v: Dictionary in st["voices"]:
		used += 1 if int(v["vehicle"]) != TrafficAudio.NONE else 0
	assert_eq(used, 8, "alle acht Stimmen vergeben")
	assert_true(bool(st["siren"]["on"]) and bool(st["siren"]["spatial"]), "Martinshorn räumlich an der Polizei")
	assert_true(float(st["tunnel_blend"]) > 0.5, "Tunnelüberblendung des Raumklangs")
	assert_true(int(m.traffic_perf()["frames"]) >= 40, "traffic_perf() zählt")
	m.stop_all()
	_steps(m, 1)
	assert_eq(int(m.debug_state()["slots"]["traffic"]["voices"]), 0, "stop_all(): Stimmen frei")
	assert_false(arcade.voices.size() == 8, "das Arcade-Objekt behält seine eigene Stimmenzahl")
	_done(m)
