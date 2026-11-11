extends TestCase
## The slots "engine" (EngineAudio3) and "layers" (VehicleLayers) of the Modern sound with the shipped banks, driven
## through ModernAudio as the race session drives them – without a scene tree and without players (the mixers are
## rendered by hand where the samples matter): the state the other slots and the ducking read, start clip, shifts,
## lifting (crackles, blow-off), the preview blip, synchronous mode sample for sample, a long frame that is not a
## session gone, and what the vehicle layers make of the engine state.

const DT := 1.0 / 60.0
const STATE_KEYS: Array[String] = ["rpm", "gear", "load", "boost", "shaft", "limiter", "shifting", "throttle", "upshifts",
	"downshifts", "blowoffs", "blowoff_level", "starts"]


func _modern(opts: Dictionary = {}, over: Dictionary = {}) -> ModernAudio:
	var c := cfg().duplicate(true)
	(c["audio"]["modern"] as Dictionary).merge(over, true)
	var o := {"live": false, "quiet": true}
	o.merge(opts, true)
	var m := ModernAudio.new()
	m.clock_ms = 1000
	m.start(c, o)
	return m


func _done(m: ModernAudio) -> void:
	m.shutdown()
	m.free()
	assert_eq(AudioServer.bus_count, 1, "nach dem Test nur noch Master")


func _frame(m: ModernAudio, speed: float, throttle: float, vmax: float = 250.0, dt: float = DT) -> void:
	m.set_engine(speed, throttle, vmax, true)
	m.clock_ms += int(dt * 1000.0)
	m.step(dt, false)


func _unit(m: ModernAudio) -> EngineAudio3.Unit:
	return m.engine.get("_unit") as EngineAudio3.Unit


## Full throttle from a standstill with the car's own acceleration curve up to `to_kmh`; returns the speed reached.
func _pull(m: ModernAudio, car: String, to_kmh: float, seconds: float = 40.0) -> float:
	var spec := VehicleModel.resolve_spec(cfg(), car)
	var vmax := float(spec["vmax_kmh"])
	var v := 0.0
	for i in int(seconds / DT):
		v = VehicleModel.curve_speed(VehicleModel.curve_time(v, vmax, float(spec["accel_a0"]), float(spec["accel_q"])) + DT, vmax,
			float(spec["accel_a0"]), float(spec["accel_q"]))
		_frame(m, v, 1.0, vmax)
		if v >= to_kmh:
			break
	return v


func test_engine_slot_drives_the_v3_bank() -> void:
	var m := _modern()
	m.set_vehicle("gran_turismo")
	var dbg: Dictionary = m.debug_state()["slots"]["engine"]
	assert_true(bool(dbg["bank"]), "Bank v3 geladen")
	assert_eq(str(dbg["vehicle"]), "gran_turismo", "Fahrzeug")
	assert_false(bool(dbg["playing"]), "ohne Wiedergabe spielt nichts")
	var u := _unit(m)
	assert_true(u != null and u.bank.car == "gran_turismo" and u.bank.sample_rate == 32000, "die Stereo-Bank des Autos")
	for i in 90:
		_frame(m, 0.0, 0.0)
	var s := m.engine_state()
	for k in STATE_KEYS:
		assert_true(s.has(k), "engine_state() hat %s" % k)
	assert_eq(int(s["starts"]), 1, "ein Motorstart")
	assert_eq(int(s["gear"]), 0, "im Stand: Leerlauf")
	assert_between(float(s["rpm"]), 650.0, 1000.0, "Leerlaufdrehzahl")
	assert_eq(m.frame.engine, s, "die folgenden Bausteine sehen denselben Zustand")
	# revving in neutral: the engine load follows the pedal, the boost stays partial
	for i in 40:
		_frame(m, 0.0, 1.0)
	assert_true(float(m.engine_state()["rpm"]) > 3000.0, "Gasstoß im Stand dreht hoch")
	assert_true(float(m.engine_state()["boost"]) < 0.5, "ohne Last kaum Ladedruck")
	for i in 90:
		_frame(m, 0.0, 0.0)
	# through the gears
	var v := _pull(m, "gran_turismo", 200.0)
	for i in 60:
		_frame(m, v, 1.0, 270.0)      # holding the speed at full throttle: any shift is over, the boost stands
	s = m.engine_state()
	assert_true(v >= 200.0, "200 km/h erreicht")
	assert_true(int(s["upshifts"]) >= 3 and int(s["gear"]) >= 4, "hochgeschaltet (%d ×, Gang %d)" % [int(s["upshifts"]), int(s["gear"])])
	assert_between(float(s["rpm"]), 2000.0, 7200.0, "Drehzahl im Band")
	assert_true(float(s["boost"]) > 0.8 and float(s["shaft"]) > 0.6, "voller Ladedruck, Lader auf Drehzahl")
	assert_near(float(s["load"]), 1.0, 0.05, "volle Motorlast")
	# the ducking key of the mix reads this load: the car's loudness after the plan is the full-throttle one
	assert_near(m.mix.car, float(m.mix.loudness["full_throttle_lufs"]), 1.0, "Schlüssel des Duckings bei Vollgas")
	# lifting at speed: blow-off and crackles are armed, the load falls
	var blow := int(s["blowoffs"])
	for i in 30:
		_frame(m, v, 0.0, 270.0)
	s = m.engine_state()
	assert_eq(int(s["blowoffs"]), blow + 1, "Gas weg mit Ladedruck: Schubumluft")
	assert_true(float(s["blowoff_level"]) > 0.1, "ihr Pegel")
	assert_true(float(s["load"]) < 0.05, "keine Last")
	# Crackles are Poisson-timed. Outside the synchronous mode the mixer's seed is random: with half a second
	# rendered this assertion failed in about one run out of ten (no crackle fell into the window). A fixed seed and
	# the whole crackle time make the count a fixed number.
	u.mix.rng.seed = 4711
	var buf := PackedVector2Array()
	buf.resize(48000)
	u.mix.render(buf, 0, buf.size())
	var crackles := int(u.mix.clips_started.get("crackle", 0))
	print("      Schubknallen in 1,5 s nach dem Gaswegnehmen (fester Seed): %d Clips" % crackles)
	assert_true(crackles >= 2, "Schubknallen nach dem Gaswegnehmen (%s)" % str(u.mix.clips_started))
	# braking down: downshifts
	var down := int(s["downshifts"])
	while v > 60.0:
		v -= 45.0 * DT
		_frame(m, v, 0.0, 270.0)
	assert_true(int(m.engine_state()["downshifts"]) >= down + 2, "beim Bremsen zurückgeschaltet")
	assert_eq(int(m.engine_perf()["frames"]), 0, "ohne Wiedergabe füllt niemand einen Generator")
	assert_true(m.engine_perf().has("skips") and m.engine_perf().has("ms_per_frame"), "perf() mit den Schlüsseln des AudioManagers und der Zeit je Bild")
	# stop_all: back to idle, silent; the next stage starts the engine again
	m.stop_all()
	assert_eq(int(m.engine_state()["gear"]), 0, "stop_all: Getriebe zurückgesetzt")
	assert_true(u.mix.is_silent(), "stop_all: still")
	m.set_vehicle("gran_turismo")
	for i in 5:
		_frame(m, 0.0, 0.0)
	assert_eq(int(m.engine_state()["starts"]), 1, "neue Etappe: neuer Motor, ein Start")
	# a car without a v3 bank: silent, the generic gearbox still gives a state
	m.set_vehicle("gibtsnicht")
	for i in 120:
		_frame(m, 120.0, 1.0)
	assert_false(bool(m.debug_state()["slots"]["engine"]["bank"]), "kein Auto, keine Bank")
	assert_true(float(m.engine_state()["rpm"]) > 500.0 and int(m.engine_state()["gear"]) >= 1, "Getriebe ohne Bank läuft")
	_done(m)


func test_start_clip_only_from_a_standstill() -> void:
	var buf := PackedVector2Array()
	buf.resize(4000)
	for moving: bool in [false, true]:
		var m := _modern()
		m.set_vehicle("limousine")
		for i in 3:
			_frame(m, 120.0 if moving else 0.0, 0.3)
		var u := _unit(m)
		u.mix.render(buf, 0, buf.size())
		assert_eq(int(u.mix.clips_started.get("start", 0)), 0 if moving else 1,
			"Startclip %s" % ("nicht, wenn die Etappe im Fahren beginnt" if moving else "am Start im Stand"))
		var p := 0.0
		for v in buf:
			p += v.x * v.x + v.y * v.y
		assert_true(p > 0.0, "der Motor klingt")
		_done(m)


## Renders what the engine slot mixes for a scripted drive, frame by frame (a frame's share of samples).
func _run_sync(sync: bool) -> PackedVector2Array:
	var m := _modern({"sync": sync})
	assert_eq(m.ctx.sync, sync, "Kontext synchron")
	m.set_vehicle("kompakt")
	var out := PackedVector2Array()
	var acc := 0.0
	var v := 0.0
	for i in 420:
		var thr := 0.0 if i < 60 or i > 330 else 1.0
		v = clampf(v + (26.0 if thr > 0.5 else -12.0) * DT, 0.0, 230.0) if i >= 60 else 0.0
		_frame(m, v, thr, 230.0)
		var u := _unit(m)
		acc += 32000.0 * DT
		var n := int(acc)
		acc -= n
		var at := out.size()
		out.resize(at + n)
		u.mix.render(out, at, n)
	_done(m)
	return out


func test_synchronous_mode_is_sample_identical() -> void:
	var a := _run_sync(true)
	var b := _run_sync(true)
	assert_true(a.size() > 200000, "gerendert (%d Frames)" % a.size())
	var peak := 0.0
	for v in a:
		peak = maxf(peak, maxf(absf(v.x), absf(v.y)))
	assert_true(peak > 0.05, "hörbar (Spitze %.3f)" % peak)
	assert_true(a == b, "synchroner Betrieb: zwei Läufe Abtastwert für Abtastwert gleich")
	var c := _run_sync(false)
	assert_false(a == c, "mit Mischer-Thread: zufällige Varianten und Bewegung (anderer Seed)")


func test_preview_blip() -> void:
	var m := _modern()
	m.preview_engine("sportwagen")
	# the bank is loaded by a worker task: the blip starts when it is there
	var t0 := Time.get_ticks_msec()
	while not bool(m.debug_state()["slots"]["engine"]["preview"]) and Time.get_ticks_msec() - t0 < 5000:
		m.step(DT, false)
		OS.delay_msec(2)
	var dbg: Dictionary = m.debug_state()["slots"]["engine"]
	assert_true(bool(dbg["preview"]), "Vorschau läuft (nach %d ms)" % (Time.get_ticks_msec() - t0))
	assert_eq(str(dbg["preview_vehicle"]), "sportwagen", "mit der Bank des gewählten Autos")
	var p := m.engine.get("_preview") as EngineAudio3.Unit
	var idle := p.gearbox.idle_rpm
	var top := 0.0
	for i in int(EngineAudio.PREVIEW_S / DT):
		m.step(DT, false)
		top = maxf(top, p.gearbox.rpm)
	assert_true(top > idle * 2.0, "Gasstoß: %.0f/min (Leerlauf %.0f)" % [top, idle])
	assert_true(p.gearbox.rpm < top * 0.7, "und zurück")
	for i in 60:
		m.step(DT, false)
	assert_false(bool(m.debug_state()["slots"]["engine"]["preview"]), "die Vorschau endet von selbst")
	# a second car while one plays: the first fades, they never overlap
	m.preview_engine("kombi")
	for i in 40:
		m.step(DT, false)
		OS.delay_msec(2)
	m.preview_engine("kompakt")
	t0 = Time.get_ticks_msec()
	while str(m.debug_state()["slots"]["engine"]["preview_vehicle"]) != "kompakt" and Time.get_ticks_msec() - t0 < 5000:
		m.step(DT, false)
		OS.delay_msec(2)
	assert_eq(str(m.debug_state()["slots"]["engine"]["preview_vehicle"]), "kompakt", "die neue Wahl löst die alte ab")
	assert_true(int(m.debug_state()["slots"]["engine"]["banks_cached"]) <= EngineAudio3.BANK_CACHE, "höchstens %d Banken im Speicher" % EngineAudio3.BANK_CACHE)
	# no preview when it is switched off
	var off := _modern({}, {"engine": {"preview": false}})
	off.preview_engine("kombi")
	for i in 10:
		off.step(DT, false)
	assert_false(bool(off.debug_state()["slots"]["engine"]["preview"]), "engine.preview = false")
	_done(off)
	_done(m)


func test_a_long_frame_is_not_a_session_gone() -> void:
	var m := _modern()
	m.set_vehicle("gran_turismo")
	for i in 120:
		_frame(m, 150.0, 1.0)
	var u := _unit(m)
	var buf := PackedVector2Array()
	buf.resize(2048)
	u.mix.render(buf, 0, buf.size())
	var before := m.layers.final_drive.level
	assert_true(before > 0.001, "Antriebsheulen läuft")
	# a hitch: one frame of 0.4 s – ModernAudio sees no call for more than ALIVE_S
	m.clock_ms += 400
	m.step(0.4, false)
	assert_false(m.frame.alive, "für ModernAudio ist die Sitzung in diesem Bild weg")
	u.mix.render(buf, 0, buf.size())
	assert_false(u.mix.is_silent(), "der Motor blendet dafür nicht aus")
	assert_true(m.layers.final_drive.level > before * 0.8, "die Fahrzeugebenen auch nicht")
	_frame(m, 151.0, 1.0)
	assert_true(m.frame.alive, "danach geht es weiter")
	# really gone: the next normal frames without a call fade everything out
	for i in 40:
		m.clock_ms += 17
		m.step(DT, false)
	u.mix.render(buf, 0, buf.size())
	u.mix.render(buf, 0, buf.size())
	u.mix.render(buf, 0, buf.size())
	assert_true(u.mix.is_silent(), "Sitzung weg: Motor aus")
	assert_true(m.layers.final_drive.level < 0.0005, "Sitzung weg: Ebenen aus")
	# the pause is never mistaken for a hitch
	for i in 30:
		_frame(m, 150.0, 1.0)
	m.clock_ms += 400
	m.step(0.4, true)
	u.mix.render(buf, 0, buf.size() / 2)
	for i in 12:
		m.clock_ms += 17
		m.step(DT, true)
		u.mix.render(buf, 0, buf.size())
	assert_true(u.mix.is_silent(), "Pause: Motor blendet aus")
	_done(m)


func test_layers_follow_the_engine() -> void:
	var m := _modern()
	var lay: VehicleLayers = m.layers
	m.set_vehicle("gran_turismo")
	assert_true(bool(lay.debug_state()["car"]), "Ebenen für das Auto")
	for i in 60:
		_frame(m, 0.0, 0.0)
	assert_near(lay.turbo.level, 0.0, 1.0e-4, "im Leerlauf kein Laderton")
	assert_near(lay.final_drive.level, 0.0, 1.0e-6, "im Stand kein Antriebsheulen")
	var v := _pull(m, "gran_turismo", 180.0)
	var s := m.engine_state()
	assert_true(lay.turbo.level > 0.01 and lay.hiss.level > 0.005, "unter Last: Laderton %.4f, Rauschen %.4f" % [lay.turbo.level, lay.hiss.level])
	assert_true(lay.turbo.level < 0.06, "der Laderton bleibt unter dem Motor (%.4f der Vollaussteuerung)" % lay.turbo.level)
	assert_near(lay.final_drive.pitch, v / 3.6 * 3.2 * 12.0 / 2.05 / 1000.0, 0.02, "Achsheulen: Tonhöhe aus dem Tempo")
	assert_near(lay.gear_mesh.pitch, float(s["rpm"]) / 60.0 * 29.0 / 1000.0, 0.08, "Getriebeheulen: Tonhöhe aus der Drehzahl")
	assert_true(lay.final_drive.level > 0.001 and lay.final_drive.level < 0.015, "Achsheulen dezent (%.4f)" % lay.final_drive.level)
	assert_true(lay.turbo.pitch > 1.0, "Laderton über seinem Bezugston (×%.2f)" % lay.turbo.pitch)
	assert_eq(int(lay.counts["thump"]), int(s["upshifts"]), "ein Lastwechselschlag je Gangwechsel")
	assert_eq(int(lay.counts["tipin"]), 0, "kein Gasannahme-Klang beim Durchbeschleunigen")
	# lift, then back on the throttle: blow-off once, tip-in once
	for i in 40:
		_frame(m, v, 0.0, 270.0)
	assert_eq(int(lay.counts["blowoff"]), 1, "Schubumluft beim Gaswegnehmen")
	assert_true(lay.turbo.level < 0.01, "der Laderton fällt mit dem Ladedruck")
	for i in 20:
		_frame(m, v, 1.0, 270.0)
	assert_eq(int(lay.counts["tipin"]), 1, "Gasannahme: Pedal von zu auf voll")
	for i in 20:
		_frame(m, v, 1.0, 270.0)
	assert_eq(int(lay.counts["tipin"]), 1, "nur einmal")
	# session gone: loops fade; stop_all: silent at once
	for i in 60:
		m.clock_ms += 17
		m.step(DT, false)
	assert_true(lay.turbo.level < 0.0005 and lay.final_drive.level < 0.0005, "ohne Sitzung blenden die Schleifen aus")
	for i in 30:
		_frame(m, v, 1.0, 270.0)
	m.stop_all()
	assert_near(lay.turbo.level + lay.hiss.level + lay.final_drive.level + lay.gear_mesh.level, 0.0, 1.0e-9, "stop_all: sofort still")
	# the naturally aspirated car has no turbo layer, the diesel no blow-off
	m.set_vehicle("sportwagen")
	_pull(m, "sportwagen", 150.0)
	assert_near(lay.turbo.level + lay.hiss.level, 0.0, 1.0e-9, "Saugmotor: kein Lader")
	assert_true(lay.gear_mesh.level > 0.0005, "aber Getriebeheulen")
	m.set_vehicle("kombi")
	var vk := _pull(m, "kombi", 150.0)
	var blow := int(lay.counts["blowoff"])
	for i in 40:
		_frame(m, vk, 0.0, 235.0)
	assert_eq(int(lay.counts["blowoff"]), blow, "Diesel: keine Schubumluft")
	assert_true(lay.turbo.level >= 0.0, "Diesel mit Lader")
	# no bank, no layers; layers switched off
	m.set_vehicle("gibtsnicht")
	for i in 30:
		_frame(m, 120.0, 1.0)
	assert_false(bool(lay.debug_state()["car"]), "Auto ohne Bank: keine Ebenen")
	assert_near(lay.final_drive.level, 0.0, 1.0e-9, "… und nichts klingt")
	_done(m)
	var off := _modern({}, {"layers": {"enabled": false}})
	off.set_vehicle("gran_turismo")
	for i in 30:
		_frame(off, 120.0, 1.0)
	assert_false(bool(off.layers.debug_state()["car"]), "layers.enabled = false")
	_done(off)
