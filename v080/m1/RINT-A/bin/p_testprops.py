import os
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1')


def rep(path, old, new, count=1):
    s = open(path).read()
    assert s.count(old) == count, (path, old[:70], s.count(old))
    s = s.replace(old, new)
    open(path, 'w').write(s)


p = 'tests/unit/race3d/test_props.gd'
# library: the farmhouse got a wall lamp (AS1b), the station shares its light, the turbine's beacons light no ground
rep(p, '''	assert_true((lib.models["props/farmhouse"] as Dictionary)["lamps"].is_empty(), "Fensterlicht des Bauernhauses steckt im Atlas: kein Anker")''',
    '''	var farm_lamps: Array = (lib.models["props/farmhouse"] as Dictionary)["lamps"]
	assert_eq(farm_lamps.size(), 1, "Bauernhaus: eine Wandlampe mit Anker (die Fenster leuchten über Kanal 12, ohne Anker)")
	assert_near(float(farm_lamps[0]["range"]), PropLibrary.WALL_RANGE_M, 0.001, "Wandlampe: kleiner Lichtkegel vor der Wand")
	assert_near(float(lamp_list[0]["range"]), PropLibrary.LAMP_RANGE_M, 0.001, "Laterne: Kegel wie Arcades Laternen")
	assert_near(float(lamp_list[0]["energy"]), PropLibrary.LAMP_ENERGY, 0.001, "… und deren Stärke")
	var station: Array = (lib.models["props/fuel_station"] as Dictionary)["lamps"]
	assert_eq(station.size(), 8, "Tankstelle: acht Lampen unter dem Dach")
	assert_near(float(station[0]["energy"]), PropLibrary.GROUP_ENERGY / 8.0, 0.001, "… die sich das Licht von Arcades Tankstellenkegel teilen")
	for b: Dictionary in (lib.models["props/wind_turbine"] as Dictionary)["lamps"]:
		assert_near(float(b["range"]), 0.0, 0.001, "Flugbefeuerung des Windrads: kein Lichtkegel am Boden, nur Schein")''')
rep(p, '''	var birch: Dictionary = lib.sets["props/tree_birch"]
	assert_near(float(birch["w"]), 7.4396, 0.001, "Vertretung: Zellbreite in Metern aus dem Sprite-Manifest")
	assert_near(float(birch["h"]), 7.4396 * 320.0 / 176.0, 0.001, "… und Zellhöhe")''', '''	var birch: Dictionary = lib.sets["props/tree_birch"]
	assert_near(float(birch["w"]), 7.4396, 0.001, "Zellbreite in Metern aus dem Sprite-Manifest")
	assert_near(float(birch["h"]), 7.4396 * 320.0 / 176.0, 0.001, "… und Zellhöhe")
	assert_eq((birch["variants"] as Array).size(), 2, "Birke: zwei Samen-Varianten (AS1b)")
	assert_eq(int((lib.sets["props/tree_beech"] as Dictionary)["kind"]), PropLibrary.SPRITE, "Buche: noch eine Vertretung")''')
# placement: beech = stand-in (birch has a model since AS1b), oak by its chunk variant, farmhouse wall lamps
rep(p, '''	_put(t, 199, {"kind": "prop", "set": "props/tree_birch", "side": -1, "x": _x(t, -1, 9.0), "scale": 1.0, "mirror": true, "tint": "#ff8080"})
	_put(t, 200, {"kind": "prop", "set": "props/tree_birch", "side": 1, "x": _x(t, 1, 9.0), "scale": 1.2})''', '''	_put(t, 199, {"kind": "prop", "set": "props/tree_beech", "side": -1, "x": _x(t, -1, 9.0), "scale": 1.0, "mirror": true, "tint": "#ff8080"})
	_put(t, 200, {"kind": "prop", "set": "props/tree_beech", "side": 1, "x": _x(t, 1, 9.0), "scale": 1.2})''')
rep(p, '''	_put(t, 205, {"kind": "prop", "set": "props/does_not_exist", "fallback": "props/tree_birch", "fallback_scale": 0.5, "side": 1,''',
    '''	_put(t, 205, {"kind": "prop", "set": "props/does_not_exist", "fallback": "props/tree_beech", "fallback_scale": 0.5, "side": 1,''')
rep(p, '''	assert_true(groups.has("s|props/tree_birch|0") and groups.has("s|props/tree_birch|1"), "Birke: Vertretung, links mit Regel-Spiegelung")
	assert_true(groups.has("m|props/tree_oak|0") and not groups.has("m|props/tree_oak|1"), "Eiche: nie gespiegelt")''', '''	assert_true(groups.has("s|props/tree_beech|0") and groups.has("s|props/tree_beech|1"), "Buche: Vertretung, links mit Regel-Spiegelung")
	var oak_id := Props.chunk_variant(6, "props/tree_oak", (b.library.sets["props/tree_oak"] as Dictionary)["variants"])
	assert_true(oak_id.begins_with("props/tree_oak"), "Eiche: eine ihrer Varianten (%s)" % oak_id)
	assert_true(groups.has("m|%s|0" % oak_id) and not groups.has("m|%s|1" % oak_id), "Eiche: nie gespiegelt")''')
rep(p, '''	var tro := _transforms((groups["m|props/tree_oak|0"] as Dictionary)["buf"], 12)[0]''',
    '''	var tro := _transforms((groups["m|%s|0" % oak_id] as Dictionary)["buf"], 12)[0]''')
rep(p, '''	var bl: PackedFloat32Array = (groups["s|props/tree_birch|1"] as Dictionary)["buf"]''',
    '''	var bl: PackedFloat32Array = (groups["s|props/tree_beech|1"] as Dictionary)["buf"]''')
rep(p, '''	var br: PackedFloat32Array = (groups["s|props/tree_birch|0"] as Dictionary)["buf"]
	assert_eq(br.size(), 32, "rechts zwei Birken (eine als Ersatz-Set)")''', '''	var br: PackedFloat32Array = (groups["s|props/tree_beech|0"] as Dictionary)["buf"]
	assert_eq(br.size(), 32, "rechts zwei Buchen (eine als Ersatz-Set)")''')
rep(p, '''	# lamps of the two street lights, in the chunk's coordinates
	var lamps: Array = part["lamps"]
	assert_eq(lamps.size(), 2, "zwei Lampen")
	var anchor: Vector3 = (b.library.models["props/streetlight"] as Dictionary)["lamps"][0]["pos"]
	var zs := 201.0 * 3.0 + 1.0
	var fr := ctx.frame(zs, _x(t, 1, -0.6), ctx.ground(zs, _x(t, 1, -0.6)))
	assert_near((lamps[0]["pos"] as Vector3).distance_to(fr * anchor), 0.0, 1.0e-3, "Lampe rechts am Lichtanker des Modells")
	assert_true(absf((lamps[0]["pos"] as Vector3).x) < absf(fr.origin.x), "der Ausleger zeigt zur Straße")
	assert_true(absf((lamps[1]["pos"] as Vector3).x) < absf(_x(t, -1, -0.6)), "links ebenfalls (gespiegelt)")
	assert_near((lamps[1]["dir"] as Vector3).length(), 1.0, 1.0e-4, "Richtung normiert")
	assert_near(float(lamps[0]["range"]), PropLibrary.LAMP_RANGE_M, 0.001, "Lichtkegel wie Arcades Laternen")
	assert_true(lamps[0].has("color") and lamps[0].has("size") and lamps[0].has("energy") and str(lamps[0]["role"]) == "lights", "Felder aus A-7")
	# contact shadows: farmhouses, oak, birches – not the street lights''', '''	# lamps: the wall lamps of the two farmhouses (segments 195, 196), then the two street lights, in chunk coordinates
	var lamps: Array = part["lamps"]
	assert_eq(lamps.size(), 4, "vier Lampen: zwei Wandlampen der Bauernhäuser, zwei Laternen")
	assert_near(float(lamps[0]["range"]), PropLibrary.WALL_RANGE_M, 0.001, "Wandlampe des Bauernhauses")
	var anchor: Vector3 = (b.library.models["props/streetlight"] as Dictionary)["lamps"][0]["pos"]
	var zs := 201.0 * 3.0 + 1.0
	var fr := ctx.frame(zs, _x(t, 1, -0.6), ctx.ground(zs, _x(t, 1, -0.6)))
	assert_near((lamps[2]["pos"] as Vector3).distance_to(fr * anchor), 0.0, 1.0e-3, "Lampe rechts am Lichtanker des Modells")
	assert_true(absf((lamps[2]["pos"] as Vector3).x) < absf(fr.origin.x), "der Ausleger zeigt zur Straße")
	assert_true(absf((lamps[3]["pos"] as Vector3).x) < absf(_x(t, -1, -0.6)), "links ebenfalls (gespiegelt)")
	assert_near((lamps[3]["dir"] as Vector3).length(), 1.0, 1.0e-4, "Richtung normiert")
	assert_true((lamps[2]["dir"] as Vector3).y < -0.9, "die Laterne leuchtet nach unten")
	assert_near(float(lamps[2]["range"]), PropLibrary.LAMP_RANGE_M, 0.001, "Lichtkegel wie Arcades Laternen")
	assert_true(lamps[2].has("color") and lamps[2].has("size") and lamps[2].has("energy") and str(lamps[2]["role"]) == "lights", "Felder aus A-7")
	# contact shadows: farmhouses, oak, beeches – not the street lights''')
rep(p, '''	assert_eq(fake.lamps.size(), 2, "add_lamps() über ctx.services")''', '''	assert_eq(fake.lamps.size(), 4, "add_lamps() über ctx.services")''')
rep(p, '''		assert_eq(mirrored_nodes, 3, "drei gespiegelte Knoten (Bauernhaus, Birke, Laterne links)")''',
    '''		assert_eq(mirrored_nodes, 3, "drei gespiegelte Knoten (Bauernhaus, Buche, Laterne links)")''')
# ground cover replaces the dropped plants of the corridor
rep(p, '''	assert_eq(small, 8, "mit Liste bleiben die acht Sets innen als Bodenbewuchs")
	assert_eq(int((covered["dropped"] as Dictionary)["corridor"]), 2, "… Haus und Parkbaum nicht")''', '''	assert_eq(small, 8, "mit Liste bleiben die acht Sets innen als Bodenbewuchs")
	assert_eq(int((covered["dropped"] as Dictionary)["corridor"]), 2, "… Haus und Parkbaum nicht")
	# A-3 with the shipped list (props/cover_bush, props/cover_grass): each dropped plant becomes ground cover
	var shipped: Dictionary = b.collect(ctx)
	assert_eq(shipped["cover"], ["props/cover_bush", "props/cover_grass"], "Bodendecker aus graphics.modern.props.bend_cover")
	var part_c := b.build(ctx, shipped)
	var pieces: Array = part_c["cover_list"]
	assert_eq(int((part_c["dropped"] as Dictionary)["corridor"]), 10, "die Auslassungen bleiben gezählt")
	assert_true(pieces.size() >= 9 * 2 and pieces.size() <= 9 * Props.COVER_PER_TREE, "drei Stücke je weggelassenem Baum (%d)" % pieces.size())
	for e: Array in pieces:
		var cid := str(e[2])
		assert_true(cid == "props/cover_bush" or cid == "props/cover_grass", "Bodendecker-Set (%s)" % cid)
		assert_true(float(e[5]) * float((b.library.sets[cid] as Dictionary)["height"]) <= 0.5 + 1.0e-3, "höchstens 0,5 m hoch")
		var row := clampi(int(floor(ctx.row_of(float(e[4])))), 0, ctx.row_count() - 1)
		assert_true(absf(float(e[3])) - ctx.shoulder_edge(row, 1) >= Props.COVER_MIN_BEYOND_M - 1.0e-3, "nicht auf dem Bankett")
		assert_true(ctx.in_bend_corridor(float(e[4]), float(e[3])), "im Sichtkorridor, wo die Pflanze stand")
	assert_eq((part_c["list"] as Array).size(), (part["list"] as Array).size(), "die Streckenliste bleibt dieselbe")''')
print('ok')
