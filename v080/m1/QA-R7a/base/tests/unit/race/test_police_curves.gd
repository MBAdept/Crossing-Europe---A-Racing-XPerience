extends TestCase
## Police chases with the curve physics on real stages: the police car brakes for curves as well (race session:
## SessionRules.police_curve_cap_kmh -> PoliceSystem.update), so every radar chase can be escaped. The whole
## network (every radar × car × dry day / rain at night) is checked by tests/sim/check_escapes.gd in
## tools/run_tests.sh; here the curviest radar stages (no escape at all before the fix).

const Esc := preload("res://tests/sim/escape_sim.gd")
const Fx := preload("res://tests/sim/fixtures.gd")
## Radar zones on curviness-2/3 stretches (review: erfurt_kassel km 100, san_sebastian_burgos km 50/170 could not be
## escaped by any car while the police drove 220 km/h through the curves).
const CURVY := ["erfurt_kassel", "san_sebastian_burgos"]


func _network_plan(stage_id: String, reverse: bool = false) -> StagePlan:
	var net: Variant = ConfigLoader.load_json("res://data/network.json")
	var ctry: Variant = ConfigLoader.load_json("res://data/countries.json")
	var cities := {}
	for c: Dictionary in (net as Dictionary).get("cities", []):
		cities[str(c["id"])] = c
	for st: Dictionary in (net as Dictionary).get("stages", []):
		if str(st["id"]) == stage_id:
			return StagePlan.build(st, str(st["to"] if reverse else st["from"]), cities, (ctry as Dictionary).get("countries", {}), cfg())
	return null


## The session samples the curves ahead every police.curve_step_m within police.curve_lookahead_m: the same braking
## envelope as the exact one over every segment (EscapeSim.police_cap), within a few km/h.
func test_session_cap_matches_braking_envelope() -> void:
	var plan := _network_plan("san_sebastian_burgos")
	assert_true(plan != null, "Etappe vorhanden")
	var track := Track.new()
	track.setup(plan, cfg(), {})
	var police := PoliceSystem.new()
	police.setup(cfg(), plan)
	var road := Esc.road_arrays(track)
	for grip: float in [1.0, 0.72]:
		var exact := Esc.police_cap(road, police, grip)
		var compared := 0
		var worst := 0.0
		var z := 0.0
		while z < track.length_z - 400.0:
			var k := track.segment_index_at(z)
			var e := float(exact[k])
			if e < 230.0:
				var s := SessionRules.police_curve_cap_kmh(track, police, float(k) * track.seg_len, grip)
				assert_true(s >= e - 0.01, "nie unter der exakten Grenze (km %.1f: %.1f < %.1f)" % [track.z_to_km(z), s, e])
				worst = maxf(worst, s - e)
				compared += 1
			z += 37.0
		assert_true(compared > 100, "kurvige Etappe: %d Vergleichspunkte" % compared)
		assert_true(worst < 4.0, "Abtastung weicht höchstens %.1f km/h ab" % worst)
	# on a straight there is no limit, and the limit is the police car's curve speed right in a curve
	var straight := Track.new()
	straight.setup(Fx.make_plan(cfg(), 50.0), cfg(), {})
	assert_eq(SessionRules.police_curve_cap_kmh(straight, police, 500.0, 1.0), INF, "Gerade (Kurvigkeit 0): keine Grenze")


## Every radar chase on the curviest radar stages can be escaped by every car, by day and in rain at night, by a
## good driver (97 % of the car's curve limit, braking with only 10 m/s²) – with the old police (220 km/h through
## every curve) many of them could not.
func test_curvy_radar_chases_can_be_escaped() -> void:
	var opts := {"stages": CURVY, "margin": 0.97, "brake_mps2": 10.0}
	var res := Esc.sweep(cfg(), opts)
	assert_true(int(res["radars"]) >= 6, "Radarfelder der kurvigen Etappen (%d)" % int(res["radars"]))
	var flashed := 0
	for key: String in res["total"]:
		flashed += int(res["flashed"].get(key, 0))
		assert_eq(int(res["fails"].get(key, 0)), 0, "%s: jede Verfolgung zu entkommen %s" % [key, str((res["failures"] as Array).slice(0, 2))])
	assert_true(flashed >= 60, "Verfolgungen gefahren (%d)" % flashed)
	# the same drivers against a police car that ignores the curves (old model): caught again and again
	var old := cfg().duplicate(true)
	old["police"]["lat_grip"] = 1000.0
	var res_old := Esc.sweep(old, opts)
	var fails_old := 0
	for key: String in res_old["fails"]:
		fails_old += int(res_old["fails"][key])
	assert_true(fails_old >= 10, "Polizei mit 220 durch die Kurven: %d Verfolgungen ohne Entkommen" % fails_old)
