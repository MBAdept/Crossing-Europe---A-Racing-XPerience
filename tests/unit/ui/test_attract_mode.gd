extends TestCase
## Attract mode (AttractMode, docs/ui.md) and the photo title (TitleBackdrop): idle timer (60 s on the title, input
## restarts it, other screens hold it at zero), which input ends a demo, input during the demo is consumed and the
## key that ended it stays swallowed until released, the demo ends after demo_s and the next demo shows the next
## scene, effect buses muted for the demo and restored to the player's state (Music never touched), the curated
## scenes resolve to real stages, the race setup of a scene (autopilot, no countdown, no refuelling), the photo's
## cover fit for 16:9 and 16:10. The state machine runs without a scene tree here (a fake clock, no fades); the
## whole flow with the real race scene, input events and the no-writes check is tests/race/check_attract.gd.

const GameDataScript := preload("res://scripts/data/game_data.gd")


class FakeClock:
	var t := 0.0

	func now() -> float:
		return t


func _mode(clock: FakeClock, title_shown: bool = true) -> AttractMode:
	var a := AttractMode.new()
	a.configure(cfg())
	a.idle_s = 60.0
	a.demo_s = 30.0
	a.guard_s = 0.4
	a.clock = clock.now
	a.title_check = func() -> bool: return title_shown
	a.idle_due(0.0, false)   # timer starts at t = 0
	return a


func _key(code: Key, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = pressed
	e.echo = echo
	return e


func _pad(button: JoyButton, pressed: bool = true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = pressed
	return e


func _axis(value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = JOY_AXIS_LEFT_Y
	e.axis_value = value
	return e


func _click(pressed: bool = true) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	return e


func test_config_and_scenes() -> void:
	var a := AttractMode.new()
	a.configure(cfg())
	assert_true(a.enabled, "Attract-Modus an")
	assert_near(a.idle_s, 60.0, 0.001, "eine Minute ohne Eingabe")
	assert_near(a.demo_s, 30.0, 0.001, "30 s Demo")
	assert_true(a.scenes.size() >= 6, "mindestens sechs kuratierte Szenen")
	var gd: Node = GameDataScript.new()
	var vehicles: Dictionary = ConfigLoader.lookup(cfg(), "vehicles.types", {})
	var weathers: Array = ConfigLoader.lookup(cfg(), "weather.types", [])
	var ids := {}
	var weather_seen := {}
	for sc in a.scenes:
		var id := str(sc.get("id", ""))
		assert_true(id != "" and not ids.has(id), "eindeutige id: %s" % id)
		ids[id] = true
		assert_true(str(sc.get("name", "")) != "", "%s: Name für das Overlay" % id)
		var plan: StagePlan = gd.call("get_stage_plan", str(sc["stage"]), str(sc.get("from", "")))
		assert_true(plan != null, "%s: Etappe %s ab %s" % [id, sc["stage"], sc.get("from", "")])
		if plan == null:
			continue
		assert_true(plan.from_id == str(sc.get("from", "")), "%s: Startstadt passt zur Richtung" % id)
		var km := float(sc.get("km", -1.0))
		# 30 s at the cruise speed cover at most cruise / 3.6 * 30 m = cruise * 0.1 km (time scale 12)
		assert_between(km, 0.0, plan.length_km - 1.0, "%s: Start-km auf der Etappe" % id)
		assert_between(float(sc.get("hour", -1.0)), 0.0, 23.99, "%s: Uhrzeit" % id)
		assert_true(weathers.has(str(sc.get("weather", ""))), "%s: Wetter" % id)
		weather_seen[str(sc.get("weather", ""))] = true
		assert_true(vehicles.has(str(sc.get("vehicle", ""))), "%s: Fahrzeug" % id)
		assert_between(float(sc.get("speed_kmh", -1.0)), 30.0, 260.0, "%s: Starttempo" % id)
		assert_between(float(sc.get("cruise_kmh", -1.0)), 60.0, 260.0, "%s: Wunschtempo" % id)
	for w in ["normal", "rain", "snow"]:
		assert_true(weather_seen.has(w), "Szenen mit Wetter %s" % w)
	gd.free()
	a.free()


func test_scene_setup_for_the_race_session() -> void:
	var sc := {"id": "x", "stage": "kiel_hamburg", "from": "kiel", "km": 77.0, "hour": 12.5, "weather": "rain",
		"vehicle": "kombi", "speed_kmh": 90, "cruise_kmh": 160, "seed": 5}
	var s := AttractMode.scene_setup(sc, cfg())
	assert_eq(str(s["stage_id"]), "kiel_hamburg", "Etappe")
	assert_eq(str(s["from_city"]), "kiel", "Richtung")
	assert_near(float(s["start_km"]), 77.0, 0.001, "Start-km")
	assert_near(float(s["start_world_minutes"]), 750.0, 0.001, "12:30 Uhr")
	assert_eq(str(s["weather"]), "rain", "Wetter")
	assert_eq(str(s["vehicle"]), "kombi", "Fahrzeug")
	assert_true(bool(s["autopilot"]), "Autopilot fährt")
	assert_near(float(s["autopilot_target"]), 160.0, 0.001, "Wunschtempo")
	assert_false(bool(s["autopilot_speeding"]), "hält Radarlimits ein (keine Verfolgung)")
	assert_eq(str(s["autopilot_refuel"]), "never", "tankt nicht")
	assert_true(bool(s["no_countdown"]), "kein Countdown")
	assert_true(bool(s["traffic_warmup"]), "Verkehr schon da")
	assert_eq(str(s["mode"]), "demo", "Modus demo (kein Rennen, keine einzelne Etappe)")
	# flying start before the traffic is built (Review v0.5.0): the race session clears the start for this speed
	assert_near(float(s["start_speed_kmh"]), 90.0, 0.001, "Starttempo im Setup")
	assert_false(s.has("start_lane"), "ohne lane: Standardspur")
	sc["lane"] = 0
	assert_eq(int(AttractMode.scene_setup(sc, cfg())["start_lane"]), 0, "Startspur im Setup")


func test_scene_index_by_number_or_id() -> void:
	var list: Array[Dictionary] = [{"id": "a", "stage": "s"}, {"id": "b", "stage": "s"}, {"id": "c", "stage": "s"}]
	assert_eq(AttractMode.scene_index_for(list, "2"), 2, "Index")
	assert_eq(AttractMode.scene_index_for(list, "4"), 1, "Index läuft herum")
	assert_eq(AttractMode.scene_index_for(list, "b"), 1, "id")
	assert_eq(AttractMode.scene_index_for(list, "zz"), 0, "unbekannt -> erste Szene")
	assert_eq(AttractMode.parse_scenes([{"id": "ohne Etappe"}, {"stage": "kiel_hamburg"}, 3]).size(), 1, "nur Szenen mit Etappe")


func test_idle_timer() -> void:
	var c := FakeClock.new()
	var a := _mode(c)
	assert_false(a.idle_due(59.9, true), "59,9 s: noch keine Demo")
	assert_true(a.idle_due(60.0, true), "60 s ohne Eingabe: Demo")
	# input restarts the timer
	a.idle_due(0.0, false)
	c.t = 30.0
	assert_false(a.handle_input(_key(KEY_DOWN)), "Eingabe im Titel wird nicht verschluckt")
	assert_false(a.idle_due(89.9, true), "Taste bei 30 s: 89,9 s noch keine Demo")
	assert_true(a.idle_due(90.0, true), "60 s nach der letzten Eingabe")
	c.t = 100.0
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(6, 0)
	a.handle_input(move)
	assert_false(a.idle_due(159.0, true), "Mausbewegung zählt als Eingabe")
	c.t = 200.0
	a.handle_input(_axis(0.2))
	assert_true(a.idle_due(200.0, true), "Stick-Rauschen hält den Timer nicht auf")
	# other screens (or an open question) hold the timer at zero
	assert_false(a.idle_due(300.0, false), "anderer Bildschirm: keine Demo")
	assert_false(a.idle_due(359.0, true), "zählt erst ab dem Titel")
	assert_true(a.idle_due(360.0, true), "60 s im Titel")
	a.enabled = false
	assert_false(a.idle_due(1000.0, true), "abgeschaltet")
	a.free()


func test_wake_events() -> void:
	assert_true(AttractMode.is_wake_event(_key(KEY_X)), "beliebige Taste")
	assert_false(AttractMode.is_wake_event(_key(KEY_X, true, true)), "Echo einer gehaltenen Taste")
	assert_false(AttractMode.is_wake_event(_key(KEY_X, false)), "Loslassen")
	assert_true(AttractMode.is_activity_event(_key(KEY_X, false)), "Loslassen ist Aktivität")
	assert_true(AttractMode.is_wake_event(_pad(JOY_BUTTON_A)), "Gamepad A")
	assert_true(AttractMode.is_wake_event(_pad(JOY_BUTTON_START)), "Gamepad Start")
	assert_true(AttractMode.is_wake_event(_pad(JOY_BUTTON_DPAD_UP)), "Steuerkreuz")
	assert_false(AttractMode.is_wake_event(_pad(JOY_BUTTON_A, false)), "Gamepad loslassen")
	assert_true(AttractMode.is_wake_event(_axis(-0.8)), "deutlicher Stickausschlag")
	assert_false(AttractMode.is_wake_event(_axis(0.3)), "Stick-Rauschen")
	assert_true(AttractMode.is_wake_event(_click()), "Mausklick")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	assert_true(AttractMode.is_wake_event(touch), "Fingertipp (Steam Deck)")
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(20, 5)
	assert_false(AttractMode.is_wake_event(move), "Mausbewegung beendet die Demo nicht")
	assert_true(AttractMode.is_activity_event(move), "… zählt aber als Aktivität im Titel")


func test_input_ends_demo_and_is_swallowed() -> void:
	var c := FakeClock.new()
	var a := _mode(c)
	var before := InputMode.gamepad
	a.state = AttractMode.State.DEMO
	c.t = 10.0
	assert_true(a.handle_input(_axis(0.2)), "während der Demo wird alles verschluckt")
	assert_eq(a.state, AttractMode.State.DEMO, "Rauschen beendet nichts")
	assert_true(a.handle_input(_pad(JOY_BUTTON_A)), "Gamepad A verschluckt (kein Menüpunkt)")
	assert_eq(a.state, AttractMode.State.IDLE, "zurück im Titel")
	assert_eq(a.last_end_reason, "input", "beendet durch Eingabe")
	assert_true(InputMode.gamepad, "Hinweise im Titel zeigen das Gamepad")
	# the button that ended the demo does nothing in the title until it is released
	c.t = 11.0
	assert_true(a.handle_input(_pad(JOY_BUTTON_A)), "dieselbe Taste noch gedrückt: verschluckt")
	assert_true(a.handle_input(_pad(JOY_BUTTON_A, false)), "Loslassen verschluckt")
	assert_false(a.handle_input(_pad(JOY_BUTTON_A)), "danach wirkt sie wieder")
	# a key ending the demo: its echo and release are swallowed, other keys pass after guard_s
	a.state = AttractMode.State.DEMO
	c.t = 20.0
	assert_true(a.handle_input(_key(KEY_ENTER)), "Enter beendet die Demo")
	c.t = 20.2
	assert_true(a.handle_input(_key(KEY_DOWN)), "andere Taste in der Schutzzeit verschluckt")
	c.t = 21.5
	assert_true(a.handle_input(_key(KEY_ENTER, true, true)), "Echo der gehaltenen Taste verschluckt")
	assert_true(a.handle_input(_key(KEY_ENTER, false)), "Loslassen verschluckt")
	assert_true(a.handle_input(_key(KEY_DOWN, false)), "Loslassen der Taste aus der Schutzzeit verschluckt")
	assert_false(a.handle_input(_key(KEY_ENTER)), "danach normale Bedienung")
	# a stick push wakes the demo; while it stays pushed it does not move the title's focus
	a.state = AttractMode.State.DEMO
	c.t = 30.0
	assert_true(a.handle_input(_axis(0.9)), "Stick weckt")
	assert_eq(a.state, AttractMode.State.IDLE, "Demo beendet")
	c.t = 31.0
	assert_true(a.handle_input(_axis(1.0)), "Stick noch gedrückt: verschluckt")
	assert_true(a.handle_input(_axis(0.1)), "zurück in Ruhe: verschluckt und freigegeben")
	assert_false(a.handle_input(_axis(0.2)), "Ruhe-Rauschen danach normal")
	assert_false(a.handle_input(_axis(1.0)), "neuer Ausschlag bedient das Menü")
	InputMode.gamepad = before
	a.free()


func test_demo_duration_and_rotation() -> void:
	var c := FakeClock.new()
	var a := _mode(c)
	var n := a.scenes.size()
	a.scene_index = n - 1
	a.state = AttractMode.State.DEMO
	a.set("_demo_t0", 100.0)
	c.t = 129.9
	a._process(0.016)
	assert_eq(a.state, AttractMode.State.DEMO, "29,9 s: Demo läuft")
	c.t = 130.0
	a._process(0.016)
	assert_eq(a.state, AttractMode.State.IDLE, "nach 30 s zurück zum Titel")
	assert_eq(a.last_end_reason, "time", "Ende durch Zeit")
	assert_eq(a.scene_index, 0, "nächste Demo: nächste Szene (läuft herum)")
	assert_false(a.idle_due(189.9, true), "Leerlauf-Timer startet neu")
	assert_true(a.idle_due(190.0, true), "nächste Demo nach weiteren 60 s")
	a.free()


func test_effect_buses_muted_and_restored() -> void:
	var made: Array[String] = []
	for bus_name in ["SFX", "Music", "Room", "TrafficV0", "Siren"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
			made.append(bus_name)
	var idx := func(n: String) -> int: return AudioServer.get_bus_index(n)
	var before := {}
	for n in ["SFX", "Music", "Room", "TrafficV0", "Siren"]:
		before[n] = AudioServer.is_bus_mute(idx.call(n))
	AudioServer.set_bus_mute(idx.call("SFX"), false)
	AudioServer.set_bus_mute(idx.call("Music"), false)
	AudioServer.set_bus_mute(idx.call("Room"), true)       # e.g. muted by the player's settings
	AudioServer.set_bus_mute(idx.call("TrafficV0"), false)
	var a := AttractMode.new()
	var names := AttractMode.effect_bus_names()
	for n in ["SFX", "Room", "TrafficV0", "Siren"]:
		assert_true(names.has(n), "Effekt-Bus %s" % n)
	assert_false(names.has("Music"), "Musik-Bus ist kein Effekt-Bus")
	assert_false(names.has("Master"), "Master bleibt")
	a.mute_effects()
	assert_true(AudioServer.is_bus_mute(idx.call("SFX")), "SFX stumm")
	assert_true(AudioServer.is_bus_mute(idx.call("TrafficV0")), "Verkehr stumm")
	assert_false(AudioServer.is_bus_mute(idx.call("Music")), "Titelmusik läuft weiter")
	a.mute_effects()   # a second call keeps the first states
	AudioServer.set_bus_mute(idx.call("SFX"), false)
	a._keep_muted()
	assert_true(AudioServer.is_bus_mute(idx.call("SFX")), "bleibt während der Demo stumm")
	a.restore_effects()
	assert_false(AudioServer.is_bus_mute(idx.call("SFX")), "SFX wieder an")
	assert_true(AudioServer.is_bus_mute(idx.call("Room")), "vom Spieler stummgeschaltet bleibt stumm")
	assert_false(AudioServer.is_bus_mute(idx.call("TrafficV0")), "Verkehr wieder an")
	assert_false(AudioServer.is_bus_mute(idx.call("Music")), "Musik unverändert")

	# back to the state before the test, remove the buses it made (highest index first)
	for n: String in before:
		if idx.call(n) >= 0:
			AudioServer.set_bus_mute(idx.call(n), bool(before[n]))
	made.reverse()
	for n in made:
		AudioServer.remove_bus(idx.call(n))
	a.free()


## Review v0.5.0 (QA): back on the title the effect buses stayed muted only until the same frame – a muted bus keeps
## processing its effects, so the engine's reverb and the room's delay played their last half second over the title
## music. Now they come back once every effect bus is quiet, or after AttractMode.UNMUTE_MAX_S at the latest.
func test_effect_buses_come_back_after_their_tails() -> void:
	var made := AudioServer.get_bus_index("SFX") < 0
	if made:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
	var sfx := AudioServer.get_bus_index("SFX")
	var before := AudioServer.is_bus_mute(sfx)
	AudioServer.set_bus_mute(sfx, false)
	var a := AttractMode.new()
	var t := [0.0]
	var quiet := [false]
	a.clock = func() -> float: return float(t[0])
	a.title_check = func() -> bool: return false
	a.quiet_check = func() -> bool: return bool(quiet[0])
	a.mute_effects()
	a._unmute_by = a.now() + AttractMode.UNMUTE_MAX_S   # what _return_to_title sets
	t[0] = 0.5
	a._process(0.0)
	assert_true(AudioServer.is_bus_mute(sfx), "Nachhall läuft noch: SFX bleibt stumm")
	t[0] = AttractMode.UNMUTE_MAX_S + 0.01
	a._process(0.0)
	assert_false(AudioServer.is_bus_mute(sfx), "spätestens nach %.1f s wieder an" % AttractMode.UNMUTE_MAX_S)
	a.mute_effects()
	a._unmute_by = a.now() + AttractMode.UNMUTE_MAX_S
	quiet[0] = true
	a._process(0.0)
	assert_false(AudioServer.is_bus_mute(sfx), "still: sofort wieder an")
	AudioServer.set_bus_mute(sfx, before)
	if made:
		AudioServer.remove_bus(sfx)
	a.free()


## Title photo: cover fit fills 16:9 and 16:10 without leaving the picture, the Ken Burns zoom never shows an
## edge, and the red car stays visible left of the menu card at the strongest zoom.
func test_title_backdrop_cover_fit() -> void:
	var img := Vector2(1672, 941)
	for view: Vector2 in [Vector2(1280, 720), Vector2(1280, 800), Vector2(1720, 720)]:
		for t in [0.0, 11.0, 22.5, 36.0, 50.0]:
			for p: Vector2 in [Vector2.ZERO, Vector2(view.x, 0), view, Vector2(0, view.y)]:
				var uv := TitleBackdrop.photo_uv(p, view, img, t)
				assert_between(uv.x, 0.0, 1.0, "u im Bild (%s, t %.1f)" % [view, t])
				assert_between(uv.y, 0.0, 1.0, "v im Bild (%s, t %.1f)" % [view, t])
	# 16:9: the whole picture at rest (the image is 1672×941 ≈ 16:9)
	var tl := TitleBackdrop.photo_uv(Vector2.ZERO, Vector2(1280, 720), img, 0.0)
	assert_near(tl.x, 0.0, 0.01, "16:9 zeigt das ganze Bild (links)")
	# 16:10: the sides are cropped symmetrically, the height is complete
	var tl10 := TitleBackdrop.photo_uv(Vector2.ZERO, Vector2(1280, 800), img, 0.0)
	assert_between(tl10.x, 0.03, 0.06, "16:10 beschneidet die Seiten")
	assert_near(tl10.y, 0.0, 0.002, "16:10 volle Höhe")
	# the car (image UV ~0.19..0.48 × 0.47..0.85) stays left of the menu card (window x >= 846) at full zoom
	for view: Vector2 in [Vector2(1280, 720), Vector2(1280, 800)]:
		var card_x := (view.x - 1280.0) * 0.5 + TitleScreen.CARD.position.x
		var at_card := TitleBackdrop.photo_uv(Vector2(card_x, view.y * 0.6), view, img, 22.5)
		assert_true(at_card.x > 0.5, "Menükarte rechts vom roten Auto (%s: u %.2f)" % [view, at_card.x])
		var left := TitleBackdrop.photo_uv(Vector2(0, view.y * 0.6), view, img, 22.5)
		assert_true(left.x < 0.18, "Auto ganz im Bild (%s: u %.2f)" % [view, left.x])
