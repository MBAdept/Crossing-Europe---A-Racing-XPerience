extends TestCase
## Individual cities in the renderer (docs/staedte.md): pure helpers – landmark haze law (no pop-in at the
## edge of the draw range), water tint, Eiffel profile, terrain under bridges – and the backdrop styles.


## Landmarks fade in with the haze: visible beyond the draw range, alpha continuous in depth (no jump at
## the draw range where the far pass hands over to the scene), haze grows with depth.
func test_landmark_fade_has_no_pop_in() -> void:
	for vis: float in [900.0, 495.0, 585.0, 322.0]:
		var fog_start := vis * 0.45
		var prev := RoadRenderer.landmark_fade(0.0, vis, fog_start, 2.0, 1900.0)
		assert_near(prev.x, 1.0, 0.0001, "nah voll sichtbar (Sicht %.0f)" % vis)
		assert_near(prev.y, 0.0, 0.0001, "nah kein Dunst")
		var d := 5.0
		while d < 2200.0:
			var f := RoadRenderer.landmark_fade(d, vis, fog_start, 2.0, 1900.0)
			assert_true(absf(f.x - prev.x) < 0.03, "Alpha stetig bei %.0f m (Sicht %.0f)" % [d, vis])
			assert_true(f.x <= prev.x + 0.0001 and f.y >= prev.y - 0.0001, "monoton bei %.0f m" % d)
			prev = f
			d += 2.5
		var at_edge := RoadRenderer.landmark_fade(vis, vis, fog_start, 2.0, 1900.0)
		assert_true(at_edge.x > 0.9, "am Rand der Sichtweite noch sichtbar (%.2f)" % at_edge.x)
		assert_true(at_edge.y < 0.85, "dunstig, aber nicht weg")
	var day := RoadRenderer.landmark_fade(1600.0, 900.0, 405.0, 2.0, 1900.0)
	assert_true(day.x > 0.0, "bei klarer Sicht ab dem Beginn der City Limits (1667 m) zu sehen")
	assert_near(RoadRenderer.landmark_fade(1850.0, 900.0, 405.0, 2.0, 1900.0).x, 0.0, 0.0001, "jenseits der Reichweite weg")


func test_water_tint_mirrors_the_sky_towards_the_horizon() -> void:
	var base := Color("3e5a50")
	var sky := Color("c8dcf0")
	var near := RoadRenderer.water_tint(base, Color.WHITE, sky, 10.0)
	var far := RoadRenderer.water_tint(base, Color.WHITE, sky, 500.0)
	assert_true(far.get_luminance() > near.get_luminance(), "fern heller (Himmelsspiegelung)")
	var night := RoadRenderer.water_tint(base, Color(0.2, 0.22, 0.3), Color("10141e"), 100.0)
	assert_true(night.get_luminance() < 0.12, "nachts dunkel (%.2f)" % night.get_luminance())


func test_eiffel_profile() -> void:
	assert_near(RoadRenderer.eiffel_half_width(0.0), 62.0, 0.5, "Fuß 125 m breit")
	assert_between(RoadRenderer.eiffel_half_width(57.0), 26.0, 34.0, "erste Etage")
	assert_between(RoadRenderer.eiffel_half_width(276.0), 3.0, 5.0, "oben schlank")
	var prev := 1000.0
	for h in range(0, 280, 10):
		var w := RoadRenderer.eiffel_half_width(float(h))
		assert_true(w < prev, "verjüngt sich nach oben")
		prev = w


func test_terrain_under_bridges() -> void:
	var quay := {"z0": 300.0, "z1": 420.0, "depth": 3.0, "slope": 3.0}
	assert_near(Track.water_level_at(300.0, quay), 0.0, 0.0001, "Widerlager")
	assert_near(Track.water_level_at(303.0, quay), -3.0, 0.0001, "Kaimauer: nach einem Segment Wasser")
	assert_near(Track.water_level_at(360.0, quay), -3.0, 0.0001, "Wasser")
	assert_near(Track.water_level_at(420.0, quay), 0.0, 0.0001, "Ufer")
	var high := {"z0": 0.0, "z1": 200.0, "depth": 16.0, "slope": 24.0}
	assert_near(Track.water_level_at(12.0, high), -8.0, 0.0001, "Böschung")


func test_backdrop_city_styles() -> void:
	assert_true(RaceBackdrop.STYLES.has("suburb"), "Stadtrand-Hintergrund")
	var kinds := {}
	for L: Dictionary in RaceBackdrop.STYLES["suburb"]:
		kinds[str(L["type"])] = true
	assert_true(kinds.has("houses") and kinds.has("skyline") and kinds.has("trees"), "Häuser, Bäume, ferne Skyline")
