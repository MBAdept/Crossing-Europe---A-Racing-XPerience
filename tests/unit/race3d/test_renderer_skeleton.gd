extends TestCase
## Pure parts of the Modern renderer skeleton that need no scene tree: merging of hook data into perf_stats() /
## debug_snapshot() (ModernRenderer.merge_data) and the light law of the built-in plain environment
## (scripts/race3d/plain_environment.gd): level ground shows Arcade's colour, where the light comes from, rain,
## night, tunnel.

const PlainEnvironment := preload("res://scripts/race3d/plain_environment.gd")


func test_merge_data() -> void:
	var out := {"mode": "modern", "instances": 0, "lights": {"omni": 0, "spot": 0}, "vehicles": [], "render_ms_avg": 0.5}
	ModernRenderer.merge_data(out, {"instances": 7, "lights": {"omni": 3, "pools": 2}, "vehicles": [{"id": 1}], "neu": "x"})
	ModernRenderer.merge_data(out, {"instances": 5, "lights": {"omni": 1}, "vehicles": [{"id": 2}], "mode": "modern"})
	assert_eq(int(out["instances"]), 12, "Zahlen werden addiert")
	assert_eq(out["lights"], {"omni": 4, "spot": 0, "pools": 2}, "Wörterbücher werden zusammengeführt")
	assert_eq((out["vehicles"] as Array).size(), 2, "Listen werden angehängt")
	assert_eq(str(out["neu"]), "x", "neue Schlüssel kommen dazu")
	assert_eq(str(out["mode"]), "modern", "anderes wird ersetzt")
	assert_near(float(out["render_ms_avg"]), 0.5, 1.0e-9, "unberührte Schlüssel bleiben")


## What the Compatibility renderer shows for a level surface: the ambient pass and the sun pass, each turned into a
## display value, added (docs/modelle.md §4).
func _shown_level(albedo: float, st: Dictionary, channel: int) -> float:
	var a := PlainEnvironment.engine_to_linear(albedo)
	var amb: Color = st["ambient"]
	var sun: Color = st["sun"]
	var ndl := maxf((st["to_sun"] as Vector3).y, 0.0)
	return PlainEnvironment.engine_show(a * amb[channel]) + PlainEnvironment.engine_show(a * sun[channel] * ndl)


func test_plain_light_matches_arcade_on_level_ground() -> void:
	var daytime: Dictionary = ConfigLoader.lookup(cfg(), "daytime", {})
	var worst := {"normal": 0.0, "rain": 0.0, "snow": 0.0}
	var at_ref := 0.0
	for hour: float in [8.5, 12.0, 15.0, 17.5]:
		for weather: String in ["normal", "rain", "snow"]:
			var pal := Palette.compute(hour, weather, daytime, false)
			var st := PlainEnvironment.light_state(pal, false, 0.3, 0.1)
			var p: Color = pal["ambient"]
			for albedo: float in [0.3, PlainEnvironment.REF_ALBEDO, 0.6, 0.9]:
				for ch in 3:
					var want: float = albedo * p[ch]
					var got := _shown_level(albedo, st, ch)
					worst[weather] = maxf(float(worst[weather]), absf(got - want) / want)
					if albedo == PlainEnvironment.REF_ALBEDO:
						at_ref = maxf(at_ref, absf(got - want) / want)
	assert_true(at_ref <= 0.002, "für die Bezugs-Albedo genau Arcades Farbe (%.2f %%)" % (at_ref * 100.0))
	assert_true(float(worst["normal"]) <= 0.075, "ebene Fläche bei Tag = Albedo × palette.ambient, höchstens 7,5 %% daneben für Albedo 0,3 … 0,9 (%.1f %%)" % (float(worst["normal"]) * 100.0))
	assert_true(float(worst["rain"]) <= 0.11 and float(worst["snow"]) <= 0.11, "bei Regen und Schnee höchstens 11 %% (%.1f %% / %.1f %%)" % [
		float(worst["rain"]) * 100.0, float(worst["snow"]) * 100.0])


func test_plain_light_states() -> void:
	var daytime: Dictionary = ConfigLoader.lookup(cfg(), "daytime", {})
	# 13:00 is the solar noon of the palette (half way between sunrise 6:30 and sunset 19:30)
	var day := PlainEnvironment.light_state(Palette.compute(13.0, "normal", daytime, false), false, 0.0, 0.0)
	assert_near(float(day["share"]), PlainEnvironment.SHARE_DAY, 1.0e-6, "Mittag: die Hälfte des Lichts ist gerichtet")
	var to_sun: Vector3 = day["to_sun"]
	assert_near(to_sun.length(), 1.0, 1.0e-5, "Richtung zur Sonne ist ein Einheitsvektor")
	assert_near(rad_to_deg(asin(to_sun.y)), PlainEnvironment.ELEV_MAX_DEG, 0.01, "Mittag: höchster Sonnenstand")
	assert_true(to_sun.z < 0.0 and absf(to_sun.x) < 1.0e-4, "Mittag: die Sonne steht in Fahrtrichtung (wie RaceBackdrop sie zeichnet)")
	var morning := PlainEnvironment.light_state(Palette.compute(8.5, "normal", daytime, false), false, 0.0, 0.0)
	assert_true((morning["to_sun"] as Vector3).x < -0.3 and (morning["to_sun"] as Vector3).y < to_sun.y, "morgens steht sie links und tiefer")
	# the direction is held against the road heading: turning the road and the panorama by the same angle changes nothing
	var turned := PlainEnvironment.light_state(Palette.compute(13.0, "normal", daytime, false), false, 0.7, 0.7)
	assert_true((turned["to_sun"] as Vector3).distance_to(to_sun) < 1.0e-5, "die Sonne schwenkt nicht mit den Kurven")
	var only_road := PlainEnvironment.light_state(Palette.compute(13.0, "normal", daytime, false), false, 0.7, 0.0)
	assert_true(absf((only_road["to_sun"] as Vector3).x - sin(0.7) * cos(deg_to_rad(PlainEnvironment.ELEV_MAX_DEG))) < 1.0e-4,
		"… sie steht, wo Arcade sie zum Straßenverlauf zeichnet")
	var shadow_side: Color = day["ambient"]
	var sunny: Color = day["sun"]
	assert_true(sunny.r > shadow_side.r * 0.5 and shadow_side.b > shadow_side.r, "warme Sonne, kühleres Umgebungslicht")
	var rain := PlainEnvironment.light_state(Palette.compute(13.0, "rain", daytime, false), false, 0.0, 0.0)
	assert_true(float(rain["share"]) < float(day["share"]) and float(rain["share"]) > 0.2, "Regen: weniger gerichtetes Licht, aber Form bleibt (%.2f)" % float(rain["share"]))
	assert_near(rad_to_deg(asin((rain["to_sun"] as Vector3).y)), PlainEnvironment.OVERCAST_ELEV_DEG, 0.01, "Regen: weiches Licht von oben")
	var night_pal := Palette.compute(23.0, "normal", daytime, false)
	var night := PlainEnvironment.light_state(night_pal, false, 0.0, 0.0)
	assert_eq(float(night["share"]), 0.0, "Nacht: kein gerichteter Anteil (zwei dunkle Durchgänge fielen unter die Anzeigeschwelle)")
	assert_eq(night["sun"], Color(0.0, 0.0, 0.0), "Nacht: Energie 0, das Licht bleibt bestehen")
	assert_true(bool(night["moon"]), "Nacht: die Richtung ist die des Mondes")
	var amb: Color = night["ambient"]
	var floor_lin := PlainEnvironment.engine_unshow(12.0 / 255.0)
	assert_true(PlainEnvironment.engine_to_linear(PlainEnvironment.REF_ALBEDO) * amb.g > floor_lin, "Nacht: Umgebungslicht über der Anzeigeschwelle")
	var tunnel := PlainEnvironment.light_state(Palette.compute(12.0, "normal", daytime, false), true, 0.0, 0.0)
	assert_eq(float(tunnel["share"]), 0.0, "Tunnel: Sonne aus")
	assert_true((tunnel["ambient"] as Color).r > (tunnel["ambient"] as Color).b * 2.0, "Tunnel: warmes Kunstlicht")
	var both: Array = PlainEnvironment.light_for(Color(0.2, 0.4, 0.8))
	var back := ModernMaterials.light_value(both[0], float(both[1]))
	assert_true(absf(back.r - 0.2) < 1.0e-4 and absf(back.g - 0.4) < 1.0e-4 and absf(back.b - 0.8) < 1.0e-4, "light_for() ist die Umkehrung von ModernMaterials.light_value()")
	assert_eq(PlainEnvironment.light_for(Color(0.0, 0.0, 0.0))[1], 0.0, "kein Licht: Energie 0")
