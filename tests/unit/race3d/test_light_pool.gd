extends TestCase
## R4 (contract §6 R4, D8): the light pool of the mode "Modern" – the pure parts of scripts/race3d/layers/lights.gd.
## Real lights are capped at 2 spots + 8 omnis in every preset (the omni pool 2 / 4 / 8 by „Effekte“), the analytical
## pools on the ground follow Arcade's laws (lamp pools, traffic cones, the player's cone), the police beacon takes one
## omni and one pool at night, and the weather's spray reads the player's beam through beam_at().
## The cap along whole night stages is checked on the running renderer (tests/race3d/render/check_night.gd "deckel").

const Lights := preload("res://scripts/race3d/layers/lights.gd")


func test_light_cap_per_effects_level() -> void:
	for want: int in [0, 2, 4, 8, 12, 40]:
		var l: Node3D = Lights.new()
		l.call("setup", null)
		l.call("apply_quality", {"omni_pool": want})
		var omnis: Array = l.get("omnis")
		var spots: Array = l.get("spots")
		assert_eq(omnis.size(), mini(want, 8), "omni_pool %d: %d Punktlichter (höchstens 8)" % [want, mini(want, 8)])
		assert_true(spots.size() <= 2, "höchstens 2 Spots (Abblendlicht)")
		for o: OmniLight3D in omnis:
			assert_false(o.shadow_enabled, "Punktlichter ohne Schatten (D5/D8)")
			assert_eq(o.light_cull_mask & Lights.GROUND_LAYERS, 0, "Punktlichter lassen den Boden aus (Ebene 2)")
		for s: SpotLight3D in spots:
			assert_false(s.shadow_enabled, "Spots ohne Schatten")
			assert_eq(s.light_cull_mask & Lights.GROUND_LAYERS, 0, "Spots lassen den Boden aus")
		l.free()
	# the effects levels of the configuration: 2 / 4 / 8
	var levels: Array = ConfigLoader.lookup(cfg(), "graphics.levels.effects", [])
	assert_eq(levels.size(), 3, "drei Effekt-Stufen")
	var pools: Array[int] = []
	for e: Variant in levels:
		pools.append(int((e as Dictionary).get("omni_pool", -1)))
	assert_eq(pools, [2, 4, 8], "Punktlicht-Pool 2 / 4 / 8 (Bauplan §4.10)")
	var lc: Dictionary = ConfigLoader.lookup(cfg(), "graphics.modern.lights", {})
	assert_true(int(lc.get("pools_lamps", 0)) <= 16 and int(lc.get("pools_traffic", 0)) <= 6, "≤ 16 Lampen- und ≤ 6 Verkehrskegel")
	assert_true(int(lc.get("pools_lamps", 0)) + int(lc.get("pools_traffic", 0)) <= Lights.MAX_POOLS, "alle Kegel passen in pool_pos_r[22]")


func test_display_to_light_law() -> void:
	# Arcade adds light in display values: albedo × (ambient + level); the linear light that does the same
	var amb := Color(0.21, 0.26, 0.37)
	var l := Lights.display_to_light(0.55, Color.WHITE, amb)
	for ch in 3:
		var want := pow(amb[ch] + 0.55, 2.2) - pow(amb[ch], 2.2)
		assert_near(l[ch], want, 1.0e-5, "Kanal %d: (a + l)^2.2 − a^2.2" % ch)
	assert_eq(Lights.display_to_light(0.0, Color.WHITE, amb), Color.BLACK, "ohne Licht: nichts")
	var tinted := Lights.display_to_light(0.5, Lights.BEACON_COLOR, amb)
	assert_true(tinted.b > tinted.g and tinted.g > tinted.r, "das Blaulicht färbt blau")


func test_pool_centre() -> void:
	var down := Lights.pool_centre(Vector3(2.0, 8.0, -5.0), Vector3.DOWN, 8.0)
	assert_true(down.is_equal_approx(Vector3(2.0, 0.0, -5.0)), "Laterne: Kegel senkrecht unter der Leuchte")
	var tilted := Lights.pool_centre(Vector3(0.0, 8.0, 0.0), Vector3(0.5, -1.0, 0.0).normalized(), 8.0)
	assert_near(tilted.y, 0.0, 1.0e-5, "schräge Leuchte: Kegel auf dem Boden")
	assert_near(tilted.x, 4.0, 1.0e-4, "… dort, wo die Achse den Boden trifft")
	var wall := Lights.pool_centre(Vector3(0.0, 3.0, 0.0), Vector3(1.0, 0.0, 0.0), 3.0)
	assert_near(wall.x, Lights.WALL_POOL_M, 1.0e-5, "Wandlampe: höchstens 1,5 m vor der Wand")
	assert_near(wall.y, 0.0, 1.0e-5, "… auf dem Boden")


func test_headlight_cone() -> void:
	var pos := Vector3.ZERO
	var dir := Vector3(0.0, 0.0, -1.0)
	var hot := Lights.headlight_shape(Vector3(0.0, 0.0, -8.0), pos, dir, 80.0)
	assert_between(hot, 0.9, 1.0, "Brennfleck vor dem Auto")
	assert_eq(Lights.headlight_shape(Vector3(0.0, 0.0, 5.0), pos, dir, 80.0), 0.0, "hinter dem Auto: nichts")
	assert_eq(Lights.headlight_shape(Vector3(0.0, 0.0, -85.0), pos, dir, 80.0), 0.0, "jenseits der Reichweite: nichts")
	assert_true(Lights.headlight_shape(Vector3(6.0, 0.0, -8.0), pos, dir, 80.0) < 0.1 * hot, "seitlich fällt der Kegel ab")
	assert_true(Lights.headlight_shape(Vector3(0.0, 0.0, -50.0), pos, dir, 80.0) < Lights.headlight_shape(Vector3(0.0, 0.0, -20.0), pos, dir, 80.0),
		"in der Ferne schwächer")


func test_beam_at() -> void:
	var l: Node3D = Lights.new()
	l.call("setup", null)
	assert_eq(float(l.call("beam_at", Vector3(0.0, 0.5, -10.0))), 0.0, "ohne Abblendlicht: kein Licht in der Luft")
	l.set("_beam", 0.95)
	l.set("_beam_pos", Vector3(0.0, 0.66, 0.0))
	l.set("_beam_dir", Vector3(0.0, 0.0, -1.0))
	var ahead := float(l.call("beam_at", Vector3(0.0, 0.66, -10.0)))
	assert_between(ahead, 0.8, 0.95, "auf der Achse 10 m voraus: fast die volle Stärke")
	assert_true(float(l.call("beam_at", Vector3(0.0, 4.0, -10.0))) < ahead * 0.5, "darüber weniger (Kegel in 3D)")
	assert_eq(float(l.call("beam_at", Vector3(0.0, 0.66, 10.0))), 0.0, "hinter den Scheinwerfern nichts")
	l.free()


func test_beacon_of() -> void:
	var police := {"kind": "car", "id": 1, "z": 140.0, "x": 1.8, "length": 4.8, "beacon": "a"}
	var view := {"cars": [{"kind": "car", "id": 2, "z": 120.0, "x": 0.0, "length": 4.5}, police]}
	var b := Lights.beacon_of(view, 100.0, 1.0, 0.0, 10000.0)
	assert_false(b.is_empty(), "nachts: das Blaulicht leuchtet")
	assert_near(float(b["z"]), 142.4, 1.0e-4, "in der Mitte des Polizeiautos")
	assert_eq(float(b["phase"]), 1.0, "Phase A: volle Stärke")
	police["beacon"] = "b"
	assert_eq(float(Lights.beacon_of(view, 100.0, 1.0, 0.0, 10000.0)["phase"]), 0.6, "Phase B: 0,6 (Arcade 0,45 / 0,7)")
	assert_true(Lights.beacon_of(view, 100.0, 0.0, 0.0, 10000.0).is_empty(), "bei Tag: kein Licht des Blaulichts")
	assert_true(Lights.beacon_of(view, -100.0, 1.0, 0.0, 10000.0).is_empty(), "zu weit voraus: nichts")
	assert_true(Lights.beacon_of(view, 100.0, 1.0, 0.0, 120.0).is_empty(), "außerhalb des Pfads: nichts")
	assert_true(Lights.beacon_of({"cars": [{"z": 130.0, "x": 0.0}]}, 100.0, 1.0, 0.0, 10000.0).is_empty(), "ohne Blaulicht: nichts")
