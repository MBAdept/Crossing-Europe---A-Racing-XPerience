extends TestCase
## ModernMix (contract D29): static levels from the plan and the volume settings, scripted ducking (depth, attack
## 50 ms, release 450 ms), snapshots (pause, impact, siren, result), effects off, and the numbers of the plan in the
## shipped configuration.

const DT := 1.0 / 60.0
## Loudness the race EQ (audio.modern.music.race_eq) takes from music – measured: title theme 1.4 dB, placeholder
## piece 1.7 dB (docs/audio-modern.md "Pegelplan").
const RACE_EQ_LOSS_DB := 1.5


func _mix(over: Dictionary = {}) -> ModernMix:
	var m: Variant = ConfigLoader.lookup(cfg(), "audio.modern", {})
	var d: Dictionary = (m as Dictionary).duplicate(true)
	d.merge(over, true)
	var mix := ModernMix.new()
	mix.setup(d)
	return mix


## Steps the mix for a while with a loudness of the car (LUFS).
func _run(mix: ModernMix, seconds: float, car_lufs: float, mute: bool = false, tail_db: float = -200.0) -> void:
	var n := int(round(seconds / DT))
	for i in n:
		mix.step(DT, car_lufs, mute, tail_db)


func test_static_levels_follow_plan_and_settings() -> void:
	var mix := _mix({"levels": {"MSfx": -3.0, "MCar": 1.5}})
	mix.set_volumes(1.0, 0.7)
	assert_near(mix.static_db("MSfx"), -3.0, 1.0e-4, "Effekte 1,0: nur der Planpegel")
	assert_near(mix.static_db("MMusic"), linear_to_db(0.7), 1.0e-4, "Musik 0,7 = −3,1 dB")
	assert_near(mix.static_db("MCar"), 1.5, 1.0e-6, "Planpegel eines Busses ohne Regler")
	assert_near(mix.static_db("MWind"), 0.0, 1.0e-6, "Vorgabe 0 dB")
	mix.set_volumes(0.5, 0.0)
	assert_near(mix.static_db("MSfx"), -3.0 + linear_to_db(0.5), 1.0e-4, "Effekte 0,5 = −6 dB dazu")
	assert_false(mix.static_mute("MSfx"), "Effekte hörbar")
	assert_true(mix.static_mute("MMusic"), "Musik 0 = stumm")
	assert_false(mix.static_mute("MCar"), "andere Busse nie stumm durch Regler")
	mix.set_volumes(0.0, 1.0)
	assert_true(mix.static_mute("MSfx"), "Effekte 0 = stumm")


## The key of the ducking: the loudness the plan gives the car in its driving state.
func test_car_loudness_after_the_plan() -> void:
	var mix := _mix({"loudness": {"idle_lufs": -24.0, "cruise_lufs": -21.0, "full_throttle_lufs": -16.0}, "duck": {"pace_cruise": 0.5}})
	assert_near(mix.car_lufs(true, 0.0, 250.0, 0.0), -24.0, 1.0e-6, "im Stand: Leerlauf")
	assert_near(mix.car_lufs(true, 125.0, 250.0, 0.0), -21.0, 1.0e-6, "rollt mit halbem Höchsttempo: Reisetempo")
	assert_near(mix.car_lufs(true, 250.0, 250.0, 0.0), -21.0, 1.0e-6, "schneller rollen macht den Plan nicht lauter")
	assert_near(mix.car_lufs(true, 62.5, 250.0, 0.0), -22.5, 1.0e-6, "dazwischen linear")
	assert_near(mix.car_lufs(true, 0.0, 250.0, 1.0), -16.0, 1.0e-6, "Vollgas im Stand")
	assert_near(mix.car_lufs(true, 200.0, 250.0, 1.0), -16.0, 1.0e-6, "Vollgas in Fahrt")
	assert_near(mix.car_lufs(true, 125.0, 250.0, 0.2), -20.0, 1.0e-6, "Reisetempo mit etwas Last")
	assert_near(mix.car_lufs(true, 125.0, 250.0, 7.0), -16.0, 1.0e-6, "Last begrenzt")
	assert_near(mix.car_lufs(false, 200.0, 250.0, 1.0), ModernMix.KEY_FLOOR_DB, 1.0e-6, "niemand fährt: still")
	# with the shipped thresholds: nothing at idle, about half at cruise, the full depth at full throttle
	var plan := _mix()
	assert_near(plan.duck_target_db(plan.car_lufs(true, 0.0, 250.0, 0.0)), 0.0, 1.0e-6, "Leerlauf: Musik oben")
	assert_near(plan.duck_target_db(plan.car_lufs(true, 250.0, 250.0, 1.0)), -plan.duck_depth_db, 1.0e-6, "Vollgas: volle Tiefe")
	assert_between(plan.duck_target_db(plan.car_lufs(true, 140.0, 250.0, 0.2)), -0.75 * plan.duck_depth_db, -0.25 * plan.duck_depth_db, "Reisetempo: teilweise")
	assert_near(plan.duck_target_db(plan.car_lufs(false, 250.0, 250.0, 1.0)), 0.0, 1.0e-6, "ohne Auto keine Absenkung")


## A car the mix states have turned down counts with what is left of it.
func test_car_path_counts_the_mix_states() -> void:
	var mix := _mix()
	assert_near(mix.car_path_db(), 0.0, 1.0e-6, "ohne Zustand: nichts")
	mix.set_active("result", true)
	_run(mix, 6.0, ModernMix.KEY_FLOOR_DB)
	var dips: Dictionary = ConfigLoader.lookup(cfg(), "audio.modern.snapshots.result.gain_db", {})
	var want := float(dips.get("MCar", 0.0)) + float(dips.get("MEnv", 0.0))
	assert_true(want <= -6.0, "hinter der Ziellinie wird das Auto deutlich leiser gestellt (%.1f dB)" % want)
	assert_near(mix.car_path_db(), want, 0.05, "Zustand result: der Weg des Autos")
	# full throttle behind the finish line: what is left of the car no longer ducks the music
	var left := mix.car_lufs(true, 200.0, 250.0, 1.0) + mix.car_path_db()
	assert_near(mix.duck_target_db(left), 0.0, 1.0e-6, "kein Ducking für ein leise gestelltes Auto")


func test_duck_target_curve() -> void:
	var mix := _mix({"duck": {"from_lufs": -24.0, "to_lufs": -10.0, "depth_db": 4.5}})
	assert_near(mix.duck_target_db(-200.0), 0.0, 1.0e-6, "Stille: keine Absenkung")
	assert_near(mix.duck_target_db(-24.0), 0.0, 1.0e-6, "an der unteren Schwelle 0 dB")
	assert_near(mix.duck_target_db(-17.0), -2.25, 1.0e-5, "in der Mitte die halbe Tiefe")
	assert_near(mix.duck_target_db(-10.0), -4.5, 1.0e-6, "an der oberen Schwelle die volle Tiefe")
	assert_near(mix.duck_target_db(0.0), -4.5, 1.0e-6, "darüber nicht mehr")


func test_duck_attack_and_release_times() -> void:
	var mix := _mix({"duck": {"from_lufs": -24.0, "to_lufs": -10.0, "depth_db": 4.0, "attack_s": 0.05, "release_s": 0.45}, "snapshots": {}})
	# attack: after one time constant (50 ms = 3 frames) 63 % of the way, after 0.25 s practically there
	_run(mix, 0.05, -6.0)
	assert_between(mix.duck_db, -4.0 * 0.70, -4.0 * 0.55, "nach 50 ms rund 63 % der Tiefe")
	_run(mix, 0.2, -6.0)
	assert_near(mix.duck_db, -4.0, 0.05, "nach 250 ms voll abgesenkt")
	assert_near(mix.gain_db("MMusic"), mix.duck_db, 1.0e-6, "wirkt auf den Musikbus")
	assert_near(mix.gain_db("MCar"), 0.0, 1.0e-6, "nicht auf andere Busse")
	# release: slow – after 450 ms still 37 % down, back after two seconds
	_run(mix, 0.45, -200.0)
	assert_between(mix.duck_db, -4.0 * 0.45, -4.0 * 0.30, "450 ms nach dem Ende noch rund 37 % der Tiefe")
	_run(mix, 2.5, -200.0)
	assert_near(mix.duck_db, 0.0, 0.01, "wieder oben")
	# never below the depth, never above 0
	var lo := 0.0
	var hi := -100.0
	for i in 600:
		mix.step(DT, -3.0 if (i / 20) % 2 == 0 else -60.0)
		lo = minf(lo, mix.duck_db)
		hi = maxf(hi, mix.duck_db)
	assert_true(lo >= -4.0001 and hi <= 0.0, "bleibt zwischen −Tiefe und 0 (%.3f … %.3f)" % [lo, hi])


func test_snapshot_pause_lowpass_and_gain() -> void:
	var mix := _mix({"snapshots": {"pause": {"attack_s": 0.2, "release_s": 0.4, "gain_db": {"MMusic": -6.0}, "lowpass_hz": {"MMusic": 800.0}}}})
	assert_near(mix.lowpass_hz("MMusic"), 20000.0, 0.01, "ohne Pause kein Tiefpass")
	mix.set_active("pause", true)
	_run(mix, 0.1, -200.0)
	assert_near(mix.weight("pause"), 0.5, 0.02, "nach der halben Einblendzeit halb")
	assert_near(mix.gain_db("MMusic"), -3.0, 0.15, "halber Pegel")
	assert_near(mix.lowpass_hz("MMusic"), 4000.0, 250.0, "Eckfrequenz gleitet logarithmisch (20 kHz → 800 Hz: Mitte 4 kHz)")
	_run(mix, 0.15, -200.0)
	assert_near(mix.weight("pause"), 1.0, 1.0e-6, "voll")
	assert_near(mix.gain_db("MMusic"), -6.0, 1.0e-5, "−6 dB")
	assert_near(mix.lowpass_hz("MMusic"), 800.0, 0.5, "800 Hz")
	assert_near(mix.lowpass_hz("MEnv"), 20000.0, 0.01, "andere Busse offen")
	mix.set_active("pause", false)
	_run(mix, 0.2, -200.0)
	assert_near(mix.weight("pause"), 0.5, 0.02, "blendet in release_s aus")
	_run(mix, 0.25, -200.0)
	assert_near(mix.weight("pause"), 0.0, 1.0e-6, "weg")
	assert_near(mix.lowpass_hz("MMusic"), 20000.0, 0.01, "Tiefpass wieder aus")


func test_snapshot_trigger_holds_and_releases() -> void:
	var mix := _mix({"snapshots": {"impact": {"attack_s": 0.02, "release_s": 0.6, "hold_s": 0.25, "gain_db": {"MMusic": -5.0, "MAmb": -3.0}}}})
	mix.trigger("impact")
	_run(mix, 0.05, -200.0)
	assert_near(mix.gain_db("MMusic"), -5.0, 1.0e-4, "sofort unten")
	assert_near(mix.gain_db("MAmb"), -3.0, 1.0e-4, "auch das Ambiente")
	_run(mix, 0.15, -200.0)
	assert_near(mix.weight("impact"), 1.0, 1.0e-6, "hält hold_s")
	_run(mix, 0.4, -200.0)
	assert_between(mix.weight("impact"), 0.3, 0.75, "blendet danach aus")
	_run(mix, 0.5, -200.0)
	assert_near(mix.weight("impact"), 0.0, 1.0e-6, "wieder oben")
	mix.trigger("gibtsnicht")   # unknown names are ignored
	mix.set_active("gibtsnicht", true)
	assert_false(mix.has_snapshot("gibtsnicht"), "unbekannter Zustand")


func test_snapshots_and_duck_add_up() -> void:
	var mix := _mix()
	mix.set_active("siren", true)
	mix.set_active("pause", true)
	_run(mix, 1.5, -3.0)
	var siren: float = ConfigLoader.lookup(cfg(), "audio.modern.snapshots.siren.gain_db.MMusic", 0.0)
	var pause: float = ConfigLoader.lookup(cfg(), "audio.modern.snapshots.pause.gain_db.MMusic", 0.0)
	var depth: float = ConfigLoader.lookup(cfg(), "audio.modern.duck.depth_db", 0.0)
	assert_near(mix.gain_db("MMusic"), siren + pause - depth, 0.02, "Absenkungen addieren sich in dB")
	mix.reset()
	assert_near(mix.gain_db("MMusic"), 0.0, 1.0e-6, "reset(): neutral")


func test_result_snapshot_takes_car_and_world_down() -> void:
	var mix := _mix()
	mix.set_active("result", true)
	_run(mix, 2.0, -200.0)
	assert_true(mix.gain_db("MCar") <= -6.0, "Auto deutlich leiser (%.1f dB)" % mix.gain_db("MCar"))
	assert_true(mix.gain_db("MWorld") <= -6.0, "Verkehr deutlich leiser")
	assert_near(mix.gain_db("MMusic"), 0.0, 1.0e-6, "die Musik nicht")


func test_effects_off_stops_ducking_and_dips_and_waits_for_the_tail() -> void:
	var mix := _mix()
	mix.set_active("siren", true)
	_run(mix, 1.0, -3.0)
	assert_true(mix.gain_db("MMusic") < -5.0, "Ausgangslage: Musik abgesenkt")
	# effects muted (volume 0 or attract demo): the music comes back although the car is loud
	_run(mix, 0.5, -3.0, true)
	assert_true(mix.effects_muted, "Effekte stumm")
	assert_true(mix.gain_db("MMusic") > -4.0, "die Musik kommt schon zurück (%.2f dB)" % mix.gain_db("MMusic"))
	_run(mix, 3.5, -3.0, true)
	assert_near(mix.gain_db("MMusic"), 0.0, 0.02, "keine Absenkung, solange niemand die Effekte hört")
	# unmuted again: only once the reverb tail is gone …
	mix.step(DT, -200.0, false, -30.0)
	assert_true(mix.effects_muted, "Hallfahne noch hörbar: bleibt stumm")
	mix.step(DT, -200.0, false, -80.0)
	assert_false(mix.effects_muted, "Fahne verklungen: wieder an")
	# … or after UNMUTE_MAX_S at the latest
	_run(mix, 0.5, -200.0, true)
	_run(mix, ModernMix.UNMUTE_MAX_S - 0.2, -200.0, false, -20.0)
	assert_true(mix.effects_muted, "wartet auf die Fahne")
	_run(mix, 0.4, -200.0, false, -20.0)
	assert_false(mix.effects_muted, "spätestens nach %.1f s wieder an" % ModernMix.UNMUTE_MAX_S)


## The shipped numbers: targets of contract D29 and what follows from them at the default sliders.
func test_loudness_plan_in_the_configuration() -> void:
	var mix := _mix()
	assert_near(float(mix.loudness["full_throttle_lufs"]), -16.0, 1.0e-6, "Vollgas −16 LUFS")
	assert_near(float(mix.loudness["cruise_lufs"]), -21.0, 1.0e-6, "Reisetempo −21")
	assert_near(float(mix.loudness["idle_lufs"]), -24.0, 1.0e-6, "Leerlauf −24")
	assert_near(float(mix.loudness["music_under_car_db"]), 8.0, 1.0e-6, "Musik 8 dB unter dem Auto")
	assert_near(float(mix.loudness["menu_music_lufs"]), -20.0, 1.0e-6, "Menümusik −20")
	assert_near(float(mix.loudness["master_lufs"]), -14.0, 1.0e-6, "Dateien −14")
	assert_near(float(mix.loudness["true_peak_dbtp"]), -1.0, 1.0e-6, "True Peak −1")
	assert_near(mix.duck_attack_s, 0.05, 1.0e-6, "Ducking Attack 50 ms")
	assert_near(mix.duck_release_s, 0.45, 1.0e-6, "Ducking Release 450 ms")
	assert_eq(mix.duck_bus, "MMusic", "wirkt auf die Musik")
	assert_true(mix.duck_from_lufs > float(mix.loudness["idle_lufs"]), "im Leerlauf keine Absenkung")
	assert_true(mix.duck_to_lufs <= float(mix.loudness["full_throttle_lufs"]), "bei Vollgas die volle Tiefe")
	for s: String in ["pause", "impact", "siren", "result"]:
		assert_true(mix.has_snapshot(s), "Zustand %s" % s)
	# default sliders: Gesamt 0.8, Musik 0.7
	mix.set_volumes(1.0, 0.7)
	var sliders := linear_to_db(0.8) + mix.static_db("MMusic") + float(mix.levels["MMaster"])
	var master := float(mix.loudness["master_lufs"])
	assert_near(master + mix.music_context_db("menu") + sliders, float(mix.loudness["menu_music_lufs"]), 0.25, "Menümusik bei Standardreglern")
	assert_near(master + mix.music_context_db("title") + sliders, float(mix.loudness["menu_music_lufs"]), 0.25, "Titel wie Menü")
	# race: with the car at full throttle the ducked music sits music_under_car_db below it (the race EQ of the
	# music bus takes RACE_EQ_LOSS_DB of its loudness)
	var ducked := master + mix.music_context_db("race") - RACE_EQ_LOSS_DB + sliders - mix.duck_depth_db
	assert_near(ducked, float(mix.loudness["full_throttle_lufs"]) - float(mix.loudness["music_under_car_db"]), 0.6, "Musik im Rennen unter Vollgas")
	assert_true(mix.music_context_db("gibtsnicht") == 0.0, "unbekannter Kontext: 0 dB")
	for c in ModernMix.CONTEXTS:
		if c != "off":
			assert_true(mix.context_db.has(c), "Pegel für Kontext %s" % c)


## AU-R: the top-speed row of the plan – engine + road + wind at the car's top speed −15 ± 1 LUFS (KRITIK-FAHRBAHN
## 2.6: measured −14.9 with the Limousine). It follows from the measured engine of each car at top speed
## (road.engine_top_lufs) and the plan's relation: tyres tyres.under_engine_db and wind wind.under_engine_db under it.
func test_top_speed_row_of_the_plan() -> void:
	var mix := _mix()
	var top := float(mix.loudness["top_speed_lufs"])
	var tol := float(mix.loudness["top_speed_tol_db"])
	assert_near(top, -15.0, 1.0e-6, "Höchsttempo −15 LUFS")
	assert_near(tol, 1.0, 1.0e-6, "± 1 dB")
	var road: Dictionary = ConfigLoader.lookup(cfg(), "audio.modern.road", {})
	var tyres := float(ConfigLoader.lookup(road, "tyres.under_engine_db", 4.0))
	var wind := float(ConfigLoader.lookup(road, "wind.under_engine_db", 3.0))
	var engines: Dictionary = road.get("engine_top_lufs", {})
	assert_true(engines.size() >= 5, "gemessener Motor je Auto")
	for car: String in engines:
		var e := float(engines[car])
		var sum := e + 10.0 * log(1.0 + pow(10.0, -tyres / 10.0) + pow(10.0, -wind / 10.0)) / log(10.0)
		assert_near(sum, top, tol, "%s: Motor %.1f + Fahrbahn + Wind = %.1f LUFS" % [car, e, sum])


func test_state_is_plain_data() -> void:
	var mix := _mix()
	mix.trigger("impact")
	mix.step(DT, -12.0)
	var s := mix.state()
	assert_true(JSON.stringify(s).length() > 10, "als JSON darstellbar")
	assert_true((s["snapshots"] as Dictionary).has("impact"), "Zustände enthalten")
	assert_true(float(s["duck_db"]) < 0.0, "Absenkung enthalten")
