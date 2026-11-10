extends TestCase
## ModernMix (contract D29): static levels from the plan and the volume settings, scripted ducking (depth, attack
## 50 ms, release 450 ms), snapshots (pause, impact, siren, result), effects off, and the numbers of the plan in the
## shipped configuration.

const DT := 1.0 / 60.0


func _mix(over: Dictionary = {}) -> ModernMix:
	var m: Variant = ConfigLoader.lookup(cfg(), "audio.modern", {})
	var d: Dictionary = (m as Dictionary).duplicate(true)
	d.merge(over, true)
	var mix := ModernMix.new()
	mix.setup(d)
	return mix


func _run(mix: ModernMix, seconds: float, key_db: float, mute: bool = false, tail_db: float = -200.0) -> void:
	var n := int(round(seconds / DT))
	for i in n:
		mix.step(DT, key_db, mute, tail_db)


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


func test_duck_target_curve() -> void:
	var mix := _mix({"duck": {"from_db": -24.0, "to_db": -10.0, "depth_db": 4.5}})
	assert_near(mix.duck_target_db(-200.0), 0.0, 1.0e-6, "Stille: keine Absenkung")
	assert_near(mix.duck_target_db(-24.0), 0.0, 1.0e-6, "an der unteren Schwelle 0 dB")
	assert_near(mix.duck_target_db(-17.0), -2.25, 1.0e-5, "in der Mitte die halbe Tiefe")
	assert_near(mix.duck_target_db(-10.0), -4.5, 1.0e-6, "an der oberen Schwelle die volle Tiefe")
	assert_near(mix.duck_target_db(0.0), -4.5, 1.0e-6, "darüber nicht mehr")


func test_duck_attack_and_release_times() -> void:
	var mix := _mix({"duck": {"from_db": -24.0, "to_db": -10.0, "depth_db": 4.0, "attack_s": 0.05, "release_s": 0.45}, "snapshots": {}})
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
	assert_eq(mix.duck_key, "MCar", "gesteuert vom Auto-Bus")
	assert_eq(mix.duck_bus, "MMusic", "wirkt auf die Musik")
	for s: String in ["pause", "impact", "siren", "result"]:
		assert_true(mix.has_snapshot(s), "Zustand %s" % s)
	# default sliders: Gesamt 0.8, Musik 0.7
	mix.set_volumes(1.0, 0.7)
	var sliders := linear_to_db(0.8) + mix.static_db("MMusic") + float(mix.levels["MMaster"])
	var master := float(mix.loudness["master_lufs"])
	assert_near(master + mix.music_context_db("menu") + sliders, float(mix.loudness["menu_music_lufs"]), 0.25, "Menümusik bei Standardreglern")
	assert_near(master + mix.music_context_db("title") + sliders, float(mix.loudness["menu_music_lufs"]), 0.25, "Titel wie Menü")
	# race: with the car at full throttle the ducked music sits music_under_car_db below it
	var ducked := master + mix.music_context_db("race") + sliders - mix.duck_depth_db
	assert_near(ducked, float(mix.loudness["full_throttle_lufs"]) - float(mix.loudness["music_under_car_db"]), 0.6, "Musik im Rennen unter Vollgas")
	assert_true(mix.music_context_db("gibtsnicht") == 0.0, "unbekannter Kontext: 0 dB")
	for c in ModernMix.CONTEXTS:
		if c != "off":
			assert_true(mix.context_db.has(c), "Pegel für Kontext %s" % c)


func test_state_is_plain_data() -> void:
	var mix := _mix()
	mix.trigger("impact")
	mix.step(DT, -12.0)
	var s := mix.state()
	assert_true(JSON.stringify(s).length() > 10, "als JSON darstellbar")
	assert_true((s["snapshots"] as Dictionary).has("impact"), "Zustände enthalten")
	assert_true(float(s["duck_db"]) < 0.0, "Absenkung enthalten")
