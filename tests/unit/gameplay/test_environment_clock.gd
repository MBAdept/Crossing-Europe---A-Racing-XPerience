extends TestCase
## WorldClock and EnvironmentModel: time-lapse, daytime, max-speed/visibility factors, race weather, stage pause.

const Fx := preload("res://tests/sim/fixtures.gd")


func test_clock_time_lapse() -> void:
	var c := cfg()
	var clock := WorldClock.new()
	clock.setup(c, 8.0 * 60.0)
	assert_eq(clock.text(), "08:00", "Start")
	clock.advance(600.0)
	assert_eq(clock.text(), "10:00", "10 Spielminuten = 2 Stunden")
	assert_near(clock.hour(), 10.0, 0.0001, "Stunde")
	assert_near(clock.elapsed_world_minutes(), 120.0, 0.0001, "vergangene Weltzeit")
	assert_near(clock.elapsed_game_seconds(), 600.0, 0.0001, "vergangene Spielzeit")
	clock.advance(300.0 * 15.0)
	assert_eq(clock.day_index(), 1, "nächster Tag")
	assert_eq(clock.text(), "01:00", "über Mitternacht")
	assert_eq(WorldClock.world_minutes_at(2, 6.5), 2.0 * 1440.0 + 390.0, "Tag + Uhrzeit")


func test_daytime_categories() -> void:
	var c := cfg()
	assert_eq(WorldClock.daytime_category(3.0, c), "night", "3 Uhr")
	assert_eq(WorldClock.daytime_category(6.0, c), "dawn", "6 Uhr")
	assert_eq(WorldClock.daytime_category(12.0, c), "day", "12 Uhr")
	assert_eq(WorldClock.daytime_category(19.0, c), "dusk", "19 Uhr")
	assert_eq(WorldClock.daytime_category(22.0, c), "night", "22 Uhr")
	assert_eq(WorldClock.daytime_category(26.0, c), "night", "26 = 2 Uhr")


func test_night_amount_smooth() -> void:
	var env := EnvironmentModel.new()
	env.setup(cfg())
	assert_eq(env.night_amount(2.0), 1.0, "Nacht")
	assert_eq(env.night_amount(12.0), 0.0, "Tag")
	var dawn := env.night_amount(6.25)
	assert_true(dawn > 0.0 and dawn < 1.0, "Dämmerung dazwischen")
	assert_true(env.night_amount(6.0) > env.night_amount(7.0), "morgens heller werdend")
	assert_true(env.night_amount(19.0) < env.night_amount(20.0), "abends dunkler werdend")
	assert_true(env.is_night(23.0) and not env.is_night(13.0), "is_night")


func test_vmax_factors_and_escape_requirement() -> void:
	var c := cfg()
	var env := EnvironmentModel.new()
	env.setup(c)
	assert_eq(env.vmax_factor(12.0, "normal"), 1.0, "Tag, normal")
	var rain_day := env.vmax_factor(12.0, "rain")
	var rain_night := env.vmax_factor(2.0, "rain")
	var snow_night := env.vmax_factor(2.0, "snow")
	assert_true(rain_day < 1.0, "Regen senkt vmax")
	assert_true(rain_night < rain_day, "Nacht senkt vmax zusätzlich")
	assert_true(snow_night < rain_night, "Schnee senkt am stärksten")
	var slowest := 1000.0
	for id: String in Fx.VEHICLES:
		slowest = minf(slowest, float(ConfigLoader.lookup(c, "vehicles.types.%s.vmax_kmh" % id, 0)))
	assert_true(slowest * rain_night >= 220.0, "langsamstes Auto bei Regen in der Nacht >= 220 km/h (%.1f)" % (slowest * rain_night))
	assert_true(env.grip("rain") < 1.0 and env.grip("snow") < env.grip("rain"), "Haftung")
	assert_eq(env.grip("normal"), 1.0, "normale Haftung")


func test_visibility() -> void:
	var c := cfg()
	var env := EnvironmentModel.new()
	env.setup(c)
	assert_eq(env.visibility_factor(12.0, "normal", false), 1.0, "klarer Tag")
	assert_true(env.visibility_factor(12.0, "rain", false) < 1.0, "Regen")
	assert_true(env.visibility_factor(12.0, "snow", false) < env.visibility_factor(12.0, "rain", false), "Schnee")
	assert_near(env.visibility_factor(2.0, "normal", false), 0.55, 0.0001, "Nacht")
	assert_near(env.visibility_factor(2.0, "rain", false), 0.65 * 0.55, 0.0001, "Regen in der Nacht (322 m)")
	# snow brightens the night: 0.5 * 0.75 (338 m) instead of 0.5 * 0.55 (248 m) – the stopping distance with the
	# halved braking must stay within the sight (docs/gameplay.md (i6))
	assert_near(env.visibility_factor(2.0, "snow", false), 0.5 * 0.75, 0.0001, "Schnee in der Nacht")
	assert_true(env.visibility_factor(2.0, "snow", false) < env.visibility_factor(12.0, "snow", false), "Nacht senkt die Sicht auch bei Schnee")
	var old_style := ConfigLoader.deep_merge(c, {"weather": {"night_visibility_factor": 0.5}})
	var env2 := EnvironmentModel.new()
	env2.setup(old_style)
	assert_near(env2.visibility_factor(2.0, "snow", false), 0.25, 0.0001, "eine Zahl gilt für jedes Wetter")
	assert_near(env.visibility_factor(12.0, "rain", true), float(ConfigLoader.lookup(c, "weather.tunnel_visibility_factor", 0.4)), 0.0001, "Tunnel")


func test_weather_picking_by_region() -> void:
	var c := cfg()
	var env := EnvironmentModel.new()
	env.setup(c)
	assert_eq(env.pick_weather(42, "north"), env.pick_weather(42, "north"), "deterministisch")
	var counts := {"normal": 0, "rain": 0, "snow": 0}
	for s in 4000:
		var w := env.pick_weather(s * 7919 + 13, "mediterranean")
		counts[w] = int(counts[w]) + 1
	var med: Dictionary = ConfigLoader.lookup(c, "weather.climate_weights.mediterranean", {})
	assert_near(float(counts["normal"]) / 4000.0, float(med["normal"]), 0.03, "Mittelmeer meist trocken")
	var alpine := {"normal": 0, "rain": 0, "snow": 0}
	for s in 4000:
		var w := env.pick_weather(s * 7919 + 13, "alpine")
		alpine[w] = int(alpine[w]) + 1
	assert_true(int(alpine["snow"]) > int(counts["snow"]) * 5, "Alpen: viel mehr Schnee")
	assert_eq(env.pick_weather(1, "unbekannt") in ["normal", "rain", "snow"], true, "unbekanntes Klima -> default")


func test_weather_race_modes() -> void:
	var fixed := EnvironmentModel.new()
	fixed.setup(Fx.config({"weather": {"race_mode": "fixed"}}))
	assert_eq(fixed.pick_weather(5, "north", "snow"), "snow", "fest: Wetter der Etappe")
	var fb := fixed.pick_weather(5, "north", "")
	assert_true(fb in ["normal", "rain", "snow"], "fest ohne Angabe -> Region")
	var rnd := EnvironmentModel.new()
	rnd.setup(Fx.config({"weather": {"race_mode": "random"}}))
	var counts := {"normal": 0, "rain": 0, "snow": 0}
	for s in 3000:
		var w := rnd.pick_weather(s * 104729 + 1, "mediterranean")
		counts[w] = int(counts[w]) + 1
	for w in counts:
		assert_near(float(counts[w]) / 3000.0, 1.0 / 3.0, 0.04, "zufällig gleichverteilt: " + str(w))
	var region := EnvironmentModel.new()
	region.setup(cfg())
	var plan := Fx.make_plan(cfg())
	var w1 := region.race_weather(plan, 99, 0)
	assert_eq(region.race_weather(plan, 99, 0), w1, "Rennwetter deterministisch")


func test_next_stage_starts_12h_later() -> void:
	var c := cfg()
	assert_eq(EnvironmentModel.next_stage_start(600.0, c), 600.0 + 12.0 * 60.0, "Pause 12 h")
	var clock := WorldClock.new()
	clock.setup(c, 8.0 * 60.0)
	clock.advance(400.0)
	var next := EnvironmentModel.next_stage_start(clock.world_minutes, c)
	assert_near(Units.hour_of_day(next), fposmod(8.0 + 400.0 * 12.0 / 3600.0 + 12.0, 24.0), 0.0001, "Startzeit verschiebt sich um die Fahrzeit")
