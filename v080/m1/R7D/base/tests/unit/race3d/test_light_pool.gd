extends TestCase
## R4 (contract §6 R4, D8): the light pool of the mode "Modern" – the pure parts of scripts/race3d/layers/lights.gd.
## Real lights are capped at 2 spots + 8 omnis in every preset (the omni pool 2 / 4 / 8 by „Effekte“), the analytical
## pools on the ground follow Arcade's laws (lamp pools, traffic cones, the player's cone), the police beacon takes one
## omni and one pool at night, and the weather's spray reads the player's beam through beam_at().
## The cap along whole night stages is checked on the running renderer (tests/race3d/render/check_night.gd "deckel").

const Lights := preload("res://scripts/race3d/layers/lights.gd")


## RINT-M2 (FIX-R6 note): a static lamp's energy is read from the builder's own dictionary every frame – the radar
## flash changes it per frame and lights the road under the camera with it; without that dictionary the energy given.
func test_static_lamp_energy_is_read_every_frame() -> void:
	var src := {"pos": Vector3.ZERO, "dir": Vector3.DOWN, "range": 9.0, "energy": 0.0}
	var e := {"energy": 0.0, "src": src}
	assert_near(Lights.entry_energy(e), 0.0, 1.0e-6, "aus")
	src["energy"] = 1.6
	assert_near(Lights.entry_energy(e), 1.6, 1.0e-6, "die Änderung im Eintrag des Bausteins gilt im selben Bild")
	src["energy"] = -1.0
	assert_near(Lights.entry_energy(e), 0.0, 1.0e-6, "nie negativ")
	assert_near(Lights.entry_energy({"energy": 0.7}), 0.7, 1.0e-6, "ohne Quelle: die gegebene Stärke")
	assert_near(Lights.entry_energy({}), 1.0, 1.0e-6, "ohne Angabe: 1")


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
			assert_eq(s.light_cull_mask & ModernRenderer.WARMUP_LAYER, 0, "Spots lassen die Aufwärm-Knoten aus")
		for o: OmniLight3D in omnis:
			assert_eq(o.light_cull_mask & ModernRenderer.WARMUP_LAYER, 0, "Punktlichter lassen die Aufwärm-Knoten aus")
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


## A-28 (RINT-M3, NACH-RINT N-01): a reflector registered on a node that never entered the tree (a chunk dropped while
## it was being committed) and that is then freed: the glints of the low beam skip and forget it – no SCRIPT ERROR,
## no frozen glints, the count back to 0. release_under() forgets what lies under a dropped chunk's node at once.
func test_reflectors_of_a_freed_node_are_forgotten() -> void:
	var l: Node3D = Lights.new()
	l.call("setup", null)
	l.call("_build_lights")      # (setup() without a renderer builds nothing; the glints are needed here)
	var part := Node3D.new()
	var refl := [{"pos": Vector3(0.0, 0.5, -10.0), "dir": Vector3(0.0, 0.0, 1.0), "color": Color.WHITE, "size": 0.1}]
	l.call("add_reflectors", part, refl)
	assert_eq(int(l.get("_reflector_count")), 1, "ein Reflektor gemeldet")
	part.free()
	l.set("_beam", 1.0)
	l.set("_beam_pos", Vector3(0.0, 0.66, 0.0))
	l.set("_beam_dir", Vector3(0.0, 0.0, -1.0))
	for i in 3:
		l.call("_update_glints")
	assert_eq(int(l.get("_reflector_count")), 0, "der freigegebene Knoten ist vergessen")
	assert_eq((l.get("_reflectors") as Array).size(), 0, "kein Eintrag bleibt")
	assert_eq(int(l.get("_glint_count")), 0, "kein Glanzpunkt")
	# release_under(): a chunk node (not in the tree) with a part below it; another chunk's part stays
	var chunk := Node3D.new()
	var below := Node3D.new()
	chunk.add_child(below)
	var other := Node3D.new()
	l.call("add_reflectors", below, refl)
	l.call("add_reflectors", other, refl)
	l.call("add_static", below, [{"pos": Vector3(0.0, 8.0, 0.0), "dir": Vector3.DOWN, "range": 9.0}])
	assert_eq(int(l.get("_static_count")), 1, "eine Lampe gemeldet")
	l.call("release_under", chunk)
	assert_eq(int(l.get("_reflector_count")), 1, "release_under(): nur der Reflektor unter dem Stück ist vergessen")
	assert_eq(int(l.get("_static_count")), 0, "… und seine Lampe")
	chunk.free()
	other.free()
	l.call("_update_glints")
	assert_eq(int(l.get("_reflector_count")), 0, "danach auch der andere freigegebene")
	l.free()


## A-28: the flare layer forgets the static lamps under a dropped chunk's node at once (release_under()).
func test_flares_release_the_lamps_of_a_dropped_chunk() -> void:
	var f: Node = (load("res://scripts/race3d/layers/flares.gd") as GDScript).new()
	var chunk := Node3D.new()
	var below := Node3D.new()
	chunk.add_child(below)
	var other := Node3D.new()
	var lamp := [{"pos": Vector3(0.0, 8.0, 0.0), "dir": Vector3.DOWN, "role": "street", "color": Color.WHITE, "size": 0.6}]
	f.call("add_static", below, lamp)
	f.call("add_static", other, lamp)
	assert_eq(int(f.get("_static_count")), 2, "zwei Lampen gemeldet")
	f.call("release_under", chunk)
	assert_eq(int(f.get("_static_count")), 1, "die Lampe unter dem Stück ist vergessen, die andere bleibt")
	chunk.free()
	other.free()
	f.call("release_under", null)
	assert_eq(int(f.get("_static_count")), 0, "freigegebene Knoten werden ebenfalls vergessen")
	f.free()


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


## R4 (cold-cache check N1): the warm-up nodes stand on their own render layer – the real positional lights leave it
## out, the warm-up lights of prewarm.gd reach it, so the four phases are the only light situations of a warm-up node
## (at night the headlights lit them in every phase and the "no positional light" variant of the sign shader was
## compiled during the drive). A ground node keeps its layer.
func test_warmup_layer_is_lit_by_the_warmup_lights_only() -> void:
	var pw := load("res://scripts/race3d/prewarm.gd") as Script
	var mask := int(pw.get_script_constant_map().get("LIGHT_MASK", 0)) if pw != null else 0
	assert_true((mask & ModernRenderer.WARMUP_LAYER) != 0, "die Aufwärm-Lichter erreichen die Aufwärm-Ebene")
	assert_eq(mask & Lights.GROUND_LAYERS, 0, "… und lassen den Boden aus")
	assert_eq(Lights.LIGHT_MASK & ModernRenderer.WARMUP_LAYER, 0, "die Lichter der Lichtebene lassen sie aus")
	var root := Node3D.new()
	var box := MeshInstance3D.new()
	var ground := MeshInstance3D.new()
	ground.layers = Lights.GROUND_LAYERS
	root.add_child(box)
	box.add_child(ground)
	ModernRenderer._warm_layer(root)
	assert_eq(box.layers, ModernRenderer.WARMUP_LAYER, "ein Aufwärm-Knoten liegt auf der Aufwärm-Ebene")
	assert_eq(ground.layers, Lights.GROUND_LAYERS, "ein Boden-Knoten behält seine Ebene")
	root.free()

