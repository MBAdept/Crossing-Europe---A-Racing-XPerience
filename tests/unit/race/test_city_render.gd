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


## Mountain range behind a city (cities.json background.behind): colour and base haze from the data, so
## the Alps behind Bern or the Witoscha read instead of vanishing in the sky colour; the defaults (string or
## no colour/haze) keep the old faint look, and bad weather still fades every range towards the fog.
func test_backdrop_behind_range_parameters() -> void:
	var plain := RaceBackdrop.behind_params("alps", ["#9cacbc", "#5a7e4e"])
	assert_eq(str(plain["style"]), "alps", "Stil aus dem Namen")
	assert_near(float(plain["haze"]), 0.55, 0.0001, "Standard-Dunst")
	assert_eq(plain["color"], Color("#9cacbc"), "Standardfarbe: ferne Hintergrundfarbe")
	var bern := RaceBackdrop.behind_params({"style": "alps", "height": 0.75, "color": "#6f8296", "haze": 0.3}, ["#9cacbc"])
	assert_eq(str(bern["style"]), "alps", "Stil")
	assert_near(float(bern["height"]), 0.75, 0.0001, "Höhe")
	assert_eq(bern["color"], Color("#6f8296"), "eigene Farbe")
	assert_near(float(bern["haze"]), 0.3, 0.0001, "eigener Dunst")
	assert_near(RaceBackdrop.behind_haze(0.55, 0.0), 0.55, 0.0001, "klar: Grunddunst")
	assert_near(RaceBackdrop.behind_haze(0.55, 1.0), 0.97, 0.0001, "Nebel: fast Nebelfarbe")
	assert_near(RaceBackdrop.behind_haze(0.3, 1.0), 0.97, 0.0001, "auch eine klare Kette verschwindet im Nebel")
	assert_true(RaceBackdrop.behind_haze(0.3, 0.2) < RaceBackdrop.behind_haze(0.55, 0.2), "Grunddunst wirkt")


## The outskirts ground blends into the centre ground over the last GROUND_BLEND_M before the centre (QA:
## a hard line across the ground where the green gardens met the sand of the centre).
func test_ground_blends_into_the_centre() -> void:
	var c := 5000.0
	assert_near(RoadRenderer.ground_blend(c - RoadRenderer.GROUND_BLEND_M - 10.0, c), 0.0, 0.0001, "davor Stadtrand")
	assert_near(RoadRenderer.ground_blend(c - 1.0, c), 1.0, 0.01, "am Zentrum fast ganz Zentrum")
	assert_near(RoadRenderer.ground_blend(c + 10.0, c), 0.0, 0.0001, "im Zentrum (eigene Landschaft) nichts")
	assert_near(RoadRenderer.ground_blend(100.0, 0.0), 0.0, 0.0001, "ohne Zentrum nichts")
	var prev := 0.0
	var z := c - RoadRenderer.GROUND_BLEND_M
	while z < c:
		var f := RoadRenderer.ground_blend(z, c)
		assert_true(f >= prev - 0.0001 and f - prev < 0.06, "stetig und monoton bei %.0f" % (z - c))
		prev = f
		z += 3.0
