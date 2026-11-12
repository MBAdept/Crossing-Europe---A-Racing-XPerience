extends TestCase
## Light law of the environment rig of the mode "Modern" (scripts/race3d/environment_rig.gd, pure parts): level
## ground of the reference albedo shows Arcade's colour at every hour and in every weather, how far other albedos
## are off (the numbers of docs/renderer-modern.md), where the sun stands, the moon, clouds, the tunnel ramp, the
## night floor, the curves of the renderer and their inverses.

const Rig := preload("res://scripts/race3d/environment_rig.gd")
const SynTrack := preload("res://tests/race3d/synthetic_track.gd")

const HOURS: Array[float] = [0.0, 3.0, 5.5, 6.5, 7.0, 8.5, 10.0, 12.0, 13.0, 15.0, 17.5, 18.5, 19.0, 19.5, 20.0, 20.5, 21.0, 23.0]
const WEATHERS: Array[String] = ["normal", "rain", "snow"]


func _daytime() -> Dictionary:
	return ConfigLoader.lookup(cfg(), "daytime", {})


## Largest relative error of a level surface of `albedo` against Arcade's albedo × palette.ambient, over the channels.
func _error(albedo: float, st: Dictionary, p: Color) -> float:
	var shown := Rig.shown_level(albedo, st)
	var worst := 0.0
	for ch in 3:
		var want: float = albedo * p[ch]
		worst = maxf(worst, absf(shown[ch] - want) / want)
	return worst


func test_curves_and_inverses() -> void:
	for d: float in [0.02, 0.05, 0.1, 0.19, 0.38, 0.6, 0.95]:
		assert_near(Rig.engine_show(Rig.engine_unshow(d)), d, 1.0e-5, "engine_unshow ist die Umkehrung von engine_show (%.2f)" % d)
		assert_near(Rig.post_shown(Rig.post_inverse(d)), d, 2.0e-5, "post_inverse ist die Umkehrung des Nachbearbeitungspfads (%.2f)" % d)
	# the measured table of docs/modelle.md §4: ALBEDO 0.10 shows 22 without and 19 with the post path
	var shown := Rig.engine_show(Rig.engine_to_linear(0.10))
	assert_near(shown * 255.0, 22.7, 0.4, "ein Durchgang: ALBEDO 0,10 zeigt 22")
	assert_near(Rig.post_shown(shown) * 255.0, 19.4, 0.5, "mit Nachbearbeitung: 19")
	assert_eq(Rig.engine_show(0.0007), 0.0, "unter linear 0,0008 zeigt ein Durchgang nichts")
	assert_eq(Rig.post_inverse(0.0), 0.0, "Schwarz bleibt Schwarz")
	var both: Array = Rig.light_for(Color(0.2, 0.4, 0.8))
	var back := ModernMaterials.light_value(both[0], float(both[1]))
	assert_true(absf(back.r - 0.2) < 1.0e-4 and absf(back.g - 0.4) < 1.0e-4 and absf(back.b - 0.8) < 1.0e-4, "light_for() ist die Umkehrung von ModernMaterials.light_value()")
	assert_eq(Rig.light_for(Color(0.0, 0.0, 0.0))[1], 0.0, "kein Licht: Energie 0")


func test_level_ground_shows_arcades_colour() -> void:
	var worst_ref := 0.0
	var worst_day := {"normal": 0.0, "rain": 0.0, "snow": 0.0}
	var worst_day_at := {"normal": "", "rain": "", "snow": ""}
	for hour: float in HOURS:
		for weather: String in WEATHERS:
			var pal := Palette.compute(hour, weather, _daytime(), false)
			var st := Rig.light_state(pal, 0.0, 0.3, 0.1)
			var p: Color = pal["ambient"]
			var level: Color = st["level"]
			var ref := float(st["ref"])
			var take_all := float(st["share"]) <= 0.0 or not bool(st["moon"])
			for ch in 3:
				var want: float = ref * p[ch]
				# moonlight is added on top of most of the ambient light: level ground is a little brighter than Arcade
				if take_all:
					worst_ref = maxf(worst_ref, absf(level[ch] - want) / want)
				else:
					assert_between(level[ch] / want, 1.0, 1.2, "Mondnacht %.1f Uhr: ebener Boden 0 … 20 %% heller als Arcade (%.3f)" % [hour, level[ch] / want])
			assert_true((Rig.shown_level(ref, st) as Color).is_equal_approx(level), "shown_level() rechnet wie light_state()")
			if float(pal["night"]) < 0.05:
				for albedo: float in [0.3, 0.38, 0.45, 0.6, 0.9]:
					var e := _error(albedo, st, p)
					if e > float(worst_day[weather]):
						worst_day[weather] = e
						worst_day_at[weather] = "%.1f Uhr, Albedo %.2f" % [hour, albedo]
	assert_true(worst_ref <= 0.003, "Bezugs-Albedo: ebener Boden zeigt Arcades Farbe zu jeder Stunde und bei jedem Wetter (%.2f %%)" % (worst_ref * 100.0))
	print("      Lichtgesetz bei Tag, Albedo 0,3 … 0,9: klar %.1f %% (%s), Regen %.1f %% (%s), Schnee %.1f %% (%s)" % [
		float(worst_day["normal"]) * 100.0, worst_day_at["normal"], float(worst_day["rain"]) * 100.0, worst_day_at["rain"],
		float(worst_day["snow"]) * 100.0, worst_day_at["snow"]])
	assert_true(float(worst_day["normal"]) <= 0.08, "klarer Tag: höchstens 8 %% daneben für Albedo 0,3 … 0,9 (%.1f %% bei %s)" % [float(worst_day["normal"]) * 100.0, worst_day_at["normal"]])
	assert_true(float(worst_day["rain"]) <= 0.12 and float(worst_day["snow"]) <= 0.12, "Regen und Schnee bei Tag: höchstens 12 %% (%.1f %% / %.1f %%)" % [
		float(worst_day["rain"]) * 100.0, float(worst_day["snow"]) * 100.0])


func test_share_and_shadow_colour() -> void:
	var day := Rig.light_state(Palette.compute(13.0, "normal", _daytime(), false), 0.0, 0.0, 0.0)
	assert_near(float(day["share"]), Rig.SHARE_DAY, 1.0e-6, "klarer Tag: die Hälfte des Anzeigewerts ist gerichtet")
	var amb: Color = day["ambient_display"]
	var sun: Color = day["sun_display"]
	assert_true(sun.r > sun.b and amb.b > amb.r, "warme Sonne, kühlerer Schatten (Sonne %s, Schatten %s)" % [str(sun), str(amb)])
	assert_between(amb.get_luminance() / (amb.get_luminance() + sun.get_luminance()), 0.45, 0.6, "der Schatten zeigt etwa die Hälfte des beleuchteten Bodens")
	var rain := Rig.light_state(Palette.compute(13.0, "rain", _daytime(), false), 0.0, 0.0, 0.0)
	assert_between(float(rain["share"]), 0.08, 0.2, "Regen: ein Rest gerichtetes Licht, die Form bleibt (%.3f)" % float(rain["share"]))
	assert_near(rad_to_deg(float(rain["elevation"])), Rig.OVERCAST_ELEV_DEG, 0.01, "Regen: das Licht fällt von oben")
	var flat := Rig.light_state(Palette.compute(13.0, "normal", _daytime(), false), 0.0, 0.0, 0.0, true)
	assert_eq(float(flat["share"]), 0.0, "--gfx-debug=nolight: alles Licht im Umgebungsanteil")
	assert_true((flat["sun"] as Color).get_luminance() <= 0.0, "… die Sonne hat Energie 0")
	var tunnel := Rig.light_state(Palette.compute(12.0, "normal", _daytime(), false), 1.0, 0.0, 0.0)
	assert_eq(float(tunnel["share"]), 0.0, "Tunnel: Sonne aus")
	assert_true((tunnel["ambient"] as Color).r > (tunnel["ambient"] as Color).b * 2.0, "Tunnel: warmes Kunstlicht")
	var half := Rig.light_state(Palette.compute(12.0, "normal", _daytime(), false), 0.5, 0.0, 0.0)
	assert_near(float(half["share"]), Rig.SHARE_DAY * 0.5, 1.0e-6, "am Portal blendet das Sonnenlicht aus")
	assert_true((half["display"] as Color).is_equal_approx((Color.WHITE as Color).lerp(Palette.TUNNEL_AMBIENT, 0.5)), "… und das Umgebungslicht zum Tunnellicht über")


func test_where_the_sun_stands() -> void:
	# a low sun stands where Arcade's panorama draws it; the high sun is swung to the left and behind the car
	var rise := Palette.compute(6.6, "normal", _daytime(), false)
	var st_rise := Rig.light_state(rise, 0.0, 0.0, 0.0)
	var sp: Vector2 = rise["sun_pos"]
	assert_near(float(st_rise["azimuth"]), sp.x * Rig.AZIMUTH_GAIN, 1.0e-6, "Sonnenaufgang: Arcades Azimut")
	var to_rise: Vector3 = st_rise["to_sun"]
	assert_true(to_rise.z < -0.3 and to_rise.x < -0.3 and to_rise.y < 0.4, "… vorn links, flach (%s)" % str(to_rise))
	var noon := Palette.compute(13.0, "normal", _daytime(), false)
	var st_noon := Rig.light_state(noon, 0.0, 0.0, 0.0)
	var to_noon: Vector3 = st_noon["to_sun"]
	assert_near(to_noon.length(), 1.0, 1.0e-5, "Einheitsvektor")
	assert_near(rad_to_deg(asin(to_noon.y)), Rig.ELEV_MAX_DEG, 0.01, "Mittag: höchster Stand")
	assert_true(to_noon.z > 0.2 and to_noon.x < -0.5, "Mittag: die Sonne steht hinter der linken Schulter (%s) – Heck und Schilder liegen im Licht" % str(to_noon))
	var set_pal := Palette.compute(19.3, "normal", _daytime(), false)
	var to_set: Vector3 = Rig.light_state(set_pal, 0.0, 0.0, 0.0)["to_sun"]
	assert_true(to_set.z < -0.3 and to_set.x > 0.3, "Sonnenuntergang: vorn rechts (%s)" % str(to_set))
	# the direction is held against the road heading: turning the road and the panorama together changes nothing
	var turned: Vector3 = Rig.light_state(noon, 0.0, 0.7, 0.7)["to_sun"]
	assert_true(turned.distance_to(to_noon) < 1.0e-5, "die Sonne schwenkt nicht mit den Kurven")
	var only_road: Vector3 = Rig.light_state(noon, 0.0, 0.7, 0.0)["to_sun"]
	assert_true(only_road.distance_to(to_noon) > 0.3, "… wohl aber mit der Straße gegen das Panorama")
	# R4 (lead decision, "Keine Sonnenscheibe"): the backdrop draws the disc where Arcade draws it – at noon ahead,
	# while the light comes from behind the left shoulder; at a low sun disc and light agree exactly
	var rig: Node3D = Rig.new()
	var sky: Dictionary = rig.call("sky_palette", noon)
	assert_eq(sky["sun_pos"], noon["sun_pos"], "sky_palette(): die Sonnenscheibe steht an Arcades Stelle")
	assert_true(absf((sky["sun_pos"] as Vector2).x * Rig.AZIMUTH_GAIN) < 0.5, "… mittags vorn im Bild (Arcades Panorama)")
	var sky_rise: Dictionary = rig.call("sky_palette", rise)
	assert_near((sky_rise["sun_pos"] as Vector2).x * Rig.AZIMUTH_GAIN, float(st_rise["azimuth"]), 1.0e-6, "tiefe Sonne: Scheibe und Licht im selben Azimut")
	assert_eq(noon["sun_pos"], Palette.compute(13.0, "normal", _daytime(), false)["sun_pos"], "die Palette der Ansicht bleibt unberührt")
	assert_true(rig.get("sun") is DirectionalLight3D and (rig.get("sun") as DirectionalLight3D).shadow_enabled, "genau ein gerichtetes Licht, immer mit Schatten (D5)")
	var lights := 0
	for c: Node in rig.get_children():
		if c is Light3D:
			lights += 1
	assert_eq(lights, 1, "ein Licht im Rig")
	var env: Environment = rig.get("environment")
	assert_eq(env.background_mode, Environment.BG_CANVAS, "Hintergrund BG_CANVAS (D7)")
	assert_eq(env.background_canvas_max_layer, -10, "… hinter Canvas-Ebene -10")
	assert_eq(env.tonemap_mode, Environment.TONE_MAPPER_LINEAR, "linearer Tonemapper")
	assert_true(env.adjustment_enabled, "Nachbearbeitung fest eingeschaltet (D6)")
	assert_eq(env.ambient_light_source, Environment.AMBIENT_SOURCE_COLOR, "Umgebungslicht als Farbe")
	assert_true(env.sky != null and env.reflected_light_source == Environment.REFLECTION_SOURCE_SKY, "Himmel nur als Reflexionsquelle")
	assert_eq(env.fog_mode, Environment.FOG_MODE_DEPTH, "Tiefennebel")
	rig.call("apply_quality", {"shadow_splits": 4, "shadow_blend": true, "shadow_distance_m": 200.0, "glow": true, "ssao": true, "sky_reflections": false})
	var sun: DirectionalLight3D = rig.get("sun")
	assert_eq(sun.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "Hoch: vier Kaskaden")
	assert_true(sun.directional_shadow_blend_splits and is_equal_approx(sun.directional_shadow_max_distance, 200.0) and sun.shadow_enabled, "… überblendet, 200 m, Schatten bleibt an")
	assert_true(env.glow_enabled and env.ssao_enabled and env.reflected_light_source == Environment.REFLECTION_SOURCE_DISABLED, "Effekte folgen den Stufen")
	rig.call("apply_quality", {"shadow_splits": 1, "shadow_distance_m": 0.0, "glow": false})
	assert_eq(sun.directional_shadow_mode, DirectionalLight3D.SHADOW_ORTHOGONAL, "Schatten Aus: orthogonal")
	assert_true(sun.shadow_enabled and is_equal_approx(sun.directional_shadow_max_distance, Rig.SHADOW_DISTANCE_M), "… das Licht behält seinen Schatten (D5)")
	rig.call("quality_lowered", {"shadow_splits": 4, "shadow_distance_m": 80.0, "glow": true})
	assert_eq(sun.directional_shadow_mode, DirectionalLight3D.SHADOW_ORTHOGONAL, "der Wächter ändert keine Shader-Variante (Schattenmodus bleibt)")
	assert_true(is_equal_approx(sun.directional_shadow_max_distance, 80.0) and env.glow_enabled, "… wohl aber Reichweite und Effekte")
	rig.free()


func test_night_moon_and_floor() -> void:
	var pal := Palette.compute(23.0, "normal", _daytime(), false)
	var night := Rig.light_state(pal, 0.0, 0.0, 0.0)
	assert_true(bool(night["moon"]), "Nacht: die Richtung ist die des Mondes")
	assert_near(float(night["share"]), Rig.SHARE_MOON, 1.0e-6, "klare Nacht: Mondlicht")
	assert_true((night["sun"] as Color).get_luminance() > 0.0, "… mit Energie über null")
	assert_near(float(night["ref"]), Rig.REF_NIGHT, 1.0e-6, "nachts gilt die dunklere Bezugs-Albedo (Nachtschwelle)")
	var rain_night := Rig.light_state(Palette.compute(23.0, "rain", _daytime(), false), 0.0, 0.0, 0.0)
	assert_eq(float(rain_night["share"]), 0.0, "Regennacht: kein Mond")
	# dusk: the sun's part is gone before the moon's begins – never two lights, never a jump
	var last := -1.0
	for i in 61:
		var h := 18.0 + float(i) * 0.05
		var p2 := Palette.compute(h, "normal", _daytime(), false)
		var st := Rig.light_state(p2, 0.0, 0.0, 0.0)
		var night_v := float(p2["night"])
		if night_v > Rig.NIGHT_TO and night_v < Rig.MOON_FROM:
			assert_eq(float(st["share"]), 0.0, "zwischen Sonne und Mond ist das Licht ungerichtet (%.2f Uhr)" % h)
		if last >= 0.0:
			assert_true(absf(float(st["share"]) - last) < 0.12, "der gerichtete Anteil ändert sich stetig (%.2f Uhr: %.3f nach %.3f)" % [h, float(st["share"]), last])
		last = float(st["share"])
	# night floor (A-4): both passes of a mid albedo stay above the floor of the display curve, and a dark surface
	# is not crushed to black
	var p: Color = pal["ambient"]
	var floor_lin := Rig.engine_unshow(12.0 / 255.0)
	var amb: Color = night["ambient"]
	assert_true(Rig.engine_to_linear(0.3) * amb.g > floor_lin, "Nacht: der Umgebungsdurchgang einer Fläche mit Albedo 0,3 liegt über 12/255")
	var asphalt := Rig.shown_level(0.34, night)
	assert_between(asphalt.g / (0.34 * p.g), 1.0, 1.45, "Nacht: Asphalt heller als in Arcade, höchstens 45 %% (%.2f)" % (asphalt.g / (0.34 * p.g)))
	var dark := Rig.shown_level(0.25, night)
	assert_true(dark.g / (0.25 * p.g) > 0.85, "Nacht: Albedo 0,25 höchstens 15 %% dunkler als in Arcade (%.2f)" % (dark.g / (0.25 * p.g)))
	assert_true(Rig.shown_level(0.2, night).g > 5.0 / 255.0, "Nacht: auch Albedo 0,2 bleibt über Schwarz")


func test_tunnel_ramp() -> void:
	var t: Track = SynTrack.new()
	t.fill(cfg(), SynTrack.straight(900), PackedFloat32Array(), {"tunnel": [300, 500]})
	var z0 := 300.0 * t.seg_len
	var z1 := 500.0 * t.seg_len
	assert_eq(Rig.tunnel_blend(t, z0 - Rig.TUNNEL_RAMP_OUT_M - 1.0), 0.0, "vor dem Portal: Tageslicht")
	assert_eq(Rig.tunnel_blend(t, z0 + Rig.TUNNEL_RAMP_IN_M + 1.0), 1.0, "im Tunnel: Tunnellicht")
	assert_eq(Rig.tunnel_blend(t, (z0 + z1) * 0.5), 1.0, "mitten im Tunnel")
	assert_eq(Rig.tunnel_blend(t, z1 + Rig.TUNNEL_RAMP_OUT_M + 1.0), 0.0, "hinter dem Ausgang")
	var last := 0.0
	var z := z0 - 15.0
	while z < z0 + 18.0:
		var v := Rig.tunnel_blend(t, z)
		assert_true(v >= last and v - last < 0.2, "die Rampe steigt stetig (%.1f m: %.3f)" % [z - z0, v])
		last = v
		z += 1.0
	assert_between(Rig.tunnel_blend(t, z0), 0.2, 0.6, "am Portal etwa die Hälfte")
	var open: Track = SynTrack.new()
	open.fill(cfg(), SynTrack.straight(300))
	assert_eq(Rig.tunnel_blend(open, 400.0), 0.0, "ohne Tunnel: 0")
	assert_eq(Rig.tunnel_blend(null, 400.0), 0.0, "ohne Strecke: 0")


## R4: set_zone(kind, amount) – the interface the structure builders (R5) call duck-typed. Without a call the rig
## takes the tunnel from the plan (tunnel_blend); a "tunnel" zone replaces that and blends light, fog and globals.
func test_set_zone() -> void:
	var t: Track = SynTrack.new()
	t.fill(cfg(), SynTrack.straight(900), PackedFloat32Array(), {"tunnel": [300, 500]})
	var rig: Node = Rig.new()
	rig.set("_track", t)
	var pal := Palette.compute(12.0, "normal", _daytime())
	var outside := {"palette": pal, "camera_z": 100.0 * t.seg_len, "visibility_m": 900.0, "time": 1.0}
	var inside := {"palette": pal, "camera_z": 400.0 * t.seg_len, "visibility_m": 900.0, "time": 1.0}
	assert_true(rig.has_method("set_zone") and rig.has_method("zone"), "set_zone() und zone() gibt es")
	rig.call("update", inside, 0.0)
	var st: Dictionary = rig.get("state")
	assert_eq(float(st["tunnel01"]), 1.0, "ohne set_zone: der Tunnel des Etappenplans gilt (tunnel_blend)")
	rig.call("update", outside, 0.0)
	st = rig.get("state")
	assert_eq(float(st["tunnel01"]), 0.0, "ohne set_zone: draußen Tageslicht")
	var sun: DirectionalLight3D = rig.get("sun")
	var day_energy := sun.light_energy
	assert_true(day_energy > 0.0, "draußen scheint die Sonne")
	rig.call("set_zone", "tunnel", 1.0)
	rig.call("update", outside, 0.0)
	st = rig.get("state")
	assert_eq(float(st["tunnel01"]), 1.0, "set_zone(\"tunnel\", 1): Tunnel, auch wo der Plan keinen kennt")
	assert_eq(sun.light_energy, 0.0, "im Tunnel keine Sonne (Energie 0)")
	assert_true(sun.shadow_enabled and sun.visible, "das eine Schattenlicht bleibt (D5)")
	assert_true((st["fog_color"] as Color).is_equal_approx(Palette.TUNNEL_FOG), "Tunnelnebel")
	assert_near(float(st["fog_begin"]), Rig.TUNNEL_FOG_BEGIN_M, 1.0e-4, "Tunnelnebel ab 12 m")
	var env_d: Color = st["display"]
	assert_true(env_d.is_equal_approx(Palette.TUNNEL_AMBIENT), "Tunnellicht (Palette.TUNNEL_AMBIENT)")
	rig.call("set_zone", "tunnel", 0.0)
	rig.call("update", inside, 0.0)
	st = rig.get("state")
	assert_eq(float(st["tunnel01"]), 0.0, "set_zone(\"tunnel\", 0): offen, auch wo der Plan einen Tunnel hat")
	assert_near(sun.light_energy, day_energy, 1.0e-5, "… mit derselben Sonne wie draußen")
	rig.call("set_zone", "tunnel", 0.5)
	rig.call("update", outside, 0.0)
	st = rig.get("state")
	assert_near(float(st["tunnel01"]), 0.5, 1.0e-6, "Zwischenwerte gehen durch")
	assert_true(sun.light_energy > 0.0 and sun.light_energy < day_energy, "… halbe Sonne")
	rig.call("set_zone", "tunnel", 7.0)
	assert_eq(float(rig.call("zone", "tunnel")), 1.0, "Werte werden auf 0..1 begrenzt")
	rig.call("set_zone", "tunnel", -1.0)
	assert_eq(float(rig.call("zone", "tunnel")), 0.0, "… auch nach unten")
	assert_eq(float(rig.call("zone", "unbekannt", 0.25)), 0.25, "eine Art, die keiner gesetzt hat: der Rückfallwert")
	rig.call("set_zone", "bruecke_x", 1.0)
	rig.call("update", outside, 0.0)
	var snap: Dictionary = (rig.call("snapshot") as Dictionary)["environment"]
	assert_true((snap["zones"] as Dictionary).has("bruecke_x"), "fremde Arten stehen im Schnappschuss und ändern nichts")
	rig.free()


func test_wind_and_sun_azimuth() -> void:
	var calm := Rig.wind(12.0, 0.0, 0.0)
	var storm := Rig.wind(12.0, 1.0, 0.0)
	assert_true(storm.z > calm.z and calm.z > 0.0, "Regen und Schnee: mehr Wind")
	assert_true(Rig.wind(12.0, 0.0, 0.0, 1.0).z > calm.z, "über offenem Wasser (Zone \"bridge\"): mehr Wind")
	assert_eq(Rig.wind(12.0, 0.0, 1.0, 1.0).z, 0.0, "… aber nie im Tunnel")
	assert_near(Vector2(calm.x, calm.y).length(), 1.0, 1.0e-5, "Windrichtung ist ein Einheitsvektor")
	assert_eq(Rig.wind(12.0, 1.0, 1.0).z, 0.0, "im Tunnel steht die Luft")
	assert_eq(Rig.wind(5.0, 0.3, 0.0), Rig.wind(5.0, 0.3, 0.0), "gleiche Zeit, gleicher Wind (keine Uhr)")
	assert_near(Rig.sun_azimuth(Vector2(0.4, 0.0)), 0.4 * Rig.AZIMUTH_GAIN, 1.0e-6, "tiefe Sonne: Arcades Azimut")
	assert_near(Rig.sun_azimuth(Vector2(0.0, 1.0)), -Rig.SIDE_SWING, 1.0e-6, "hohe Sonne: um SIDE_SWING nach links")
	var last := Rig.sun_azimuth(Vector2(0.0, 0.0))
	for i in 21:
		var a := Rig.sun_azimuth(Vector2(0.0, float(i) / 20.0))
		assert_true(a <= last + 1.0e-6, "der Schwenk wächst mit der Höhe")
		last = a
