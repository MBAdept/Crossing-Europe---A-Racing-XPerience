extends TestCase
## Palette: key frames, continuity over the day, weather and tunnel variants.

const KEYS := ["sky_top", "sky_mid", "sky_bottom", "glow", "fog", "ambient", "lights", "stars", "sun",
	"sun_visible", "sun_pos", "moon_visible", "moon_pos", "cloud", "cloud_dark", "night", "overcast", "wet", "snow", "tunnel"]


func _daytime() -> Dictionary:
	return ConfigLoader.lookup(cfg(), "daytime", {})


func test_all_keys_for_all_hours_and_weathers() -> void:
	for w: String in ["normal", "rain", "snow"]:
		var h := 0.0
		while h <= 24.0:
			var p := Palette.compute(h, w, _daytime())
			for k: String in KEYS:
				assert_true(p.has(k), "Schlüssel %s bei %.1f h / %s" % [k, h, w])
			assert_between(float(p["lights"]), 0.0, 1.0, "lights 0..1")
			h += 0.5


func test_continuity() -> void:
	var prev := Palette.compute(0.0, "normal", _daytime())
	var h := 0.05
	var max_jump := 0.0
	while h <= 24.0:
		var p := Palette.compute(h, "normal", _daytime())
		for k: String in ["sky_top", "sky_bottom", "fog", "ambient"]:
			var a: Color = prev[k]
			var b: Color = p[k]
			max_jump = maxf(max_jump, absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b))
		prev = p
		h += 0.05
	assert_true(max_jump < 0.12, "keine Farbsprünge zwischen 3-Minuten-Schritten (%.3f)" % max_jump)


func test_day_and_night() -> void:
	var day := Palette.compute(12.0, "normal", _daytime())
	var night := Palette.compute(1.0, "normal", _daytime())
	var dusk := Palette.compute(19.5, "normal", _daytime())
	assert_true(Palette.luminance(day["ambient"]) > Palette.luminance(night["ambient"]) + 0.4, "Nacht dunkler")
	assert_near(float(night["lights"]), 1.0, 0.001, "nachts Licht an")
	assert_near(float(day["lights"]), 0.0, 0.001, "mittags Licht aus")
	assert_true(day["sun_visible"], "Sonne mittags")
	assert_false(night["sun_visible"], "keine Sonne nachts")
	assert_true(night["moon_visible"], "Mond nachts")
	assert_true(float(night["stars"]) > 0.9, "Sterne nachts")
	assert_true((dusk["glow"] as Color).a > 0.4, "Abendrot")
	var sp: Vector2 = day["sun_pos"]
	assert_true(sp.y > 0.8, "Sonne mittags hoch")


func test_weather() -> void:
	var rain := Palette.compute(12.0, "rain", _daytime())
	var snow := Palette.compute(12.0, "snow", _daytime())
	var clear := Palette.compute(12.0, "normal", _daytime())
	assert_eq(float(rain["wet"]), 1.0, "Regen: nass")
	assert_eq(float(rain["overcast"]), 1.0, "Regen: bedeckt")
	assert_false(rain["sun_visible"], "Regen: keine Sonne")
	assert_eq(float(snow["snow"]), 1.0, "Schnee")
	assert_true(Palette.luminance(rain["ambient"]) < Palette.luminance(clear["ambient"]), "Regen dunkler")
	var grass := Color("5f9a40")
	assert_true(Palette.luminance(Palette.ground(grass, snow)) > Palette.luminance(Palette.ground(grass, clear)) + 0.3, "Schnee färbt den Boden weiß")
	assert_true(Palette.luminance(Palette.road(Palette.ROAD, rain)) < Palette.luminance(Palette.road(Palette.ROAD, clear)), "nasse Straße dunkler")


func test_tunnel_variant() -> void:
	var p := Palette.compute(12.0, "normal", _daytime(), true)
	assert_true(p["tunnel"], "Tunnel-Variante")
	assert_eq(float(p["lights"]), 1.0, "im Tunnel Licht an")
	assert_false(p["sun_visible"], "keine Sonne im Tunnel")
	assert_eq(p["fog"], Palette.TUNNEL_FOG, "dunkler Tunnelnebel")
	var q := Palette.tunnel(Palette.compute(12.0, "snow", _daytime()))
	assert_eq(float(q["snow"]), 0.0, "kein Schnee im Tunnel")


func test_lit() -> void:
	var night := Palette.compute(1.0, "normal", _daytime())
	assert_true(Palette.luminance(Palette.lit(night, 0.8)) > Palette.luminance(Palette.lit(night, 0.0)) + 0.3, "Scheinwerfer hellen auf")
	var c := Palette.lit(night, 5.0)
	assert_true(c.r <= 1.0 and c.g <= 1.0 and c.b <= 1.0, "begrenzt auf 1")
