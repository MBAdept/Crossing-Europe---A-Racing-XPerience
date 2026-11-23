extends TestCase
## builders/props.gd and PropLibrary (mode "Modern", package terrain / props / far ground): what a set is (model,
## sprite stand-in, nothing), where a prop stands (on ChunkContext.ground(), a model like a vehicle, mirrored under a
## mirrored node), what is left out (beyond the ribbon, inside a bend corridor, thinned by "Details"), the chunk LOD
## levels, the draw calls per set and chunk, the lamps handed to the renderer – and, on five sceneries of real stages,
## that a chunk's prop list is the list of its TrackSegment.sprites minus the documented drops.

const SynTrack := preload("res://tests/race3d/synthetic_track.gd")
const Fair := preload("res://tests/race3d/fairness.gd")
const Props := preload("res://scripts/race3d/builders/props.gd")
const DRAW_CALLS_PER_SET := 2


## Stands for the renderer: keeps what the builder registers.
class FakeRenderer extends RefCounted:
	var lamps: Array = []
	var parents: Array = []
	var view := {"camera_z": 0.0}

	func add_lamps(parent: Node3D, list: Array) -> void:
		lamps.append_array(list)
		parents.append(parent)


## Leaves nothing behind for the tests that follow (and for the end of the run): model caches and class materials.
func _cleanup() -> void:
	ModelDB.release_all()
	ModernMaterials.drop_shared()


## 1,200 segments: straight, then a right bend of 200 m radius from segment 400 to 700, then straight.
func _track() -> Track:
	var t: Track = SynTrack.new()
	t.fill(cfg(), SynTrack.join([SynTrack.straight(400), SynTrack.arc(300, 200.0), SynTrack.straight(500)]))
	return t


func _ctx(t: Track, ci: int, levels: Dictionary = {}, services: Dictionary = {}) -> ChunkContext:
	var p := RoadPath3D.new()
	p.setup(t, 0, float(ConfigLoader.lookup(cfg(), "road.curve_radius_at_1_m", 120.0)))
	var tp := TerrainProfile.new()
	tp.setup(p, t, ConfigLoader.lookup(cfg(), "graphics.modern.terrain", {}), {})
	p.set_clear_reach(1842.0)
	p.ensure(mini((ci + 1) * 32 + 700, t.segment_count - 1))
	var ctx := ChunkContext.new()
	ctx.cfg = cfg()
	ctx.levels = levels
	ctx.services = services
	ctx.capture(ci, ci * 32, ci * 32 + 32, p, tp, t)
	return ctx


## A prop set the shipped manifest still draws as a stand-in (its Arcade sprite): the first in sorted order. The
## content packages give one set after the other a model (AS3 the beech, AS4 the church) – the tests do not name one.
func _standin_set() -> String:
	for sid: String in ModelDB.set_ids():
		if sid.begins_with("props/") and str(ModelDB.resolve(sid).get("fallback", "")) == "sprite":
			return sid
	return ""


func _put(t: Track, seg: int, item: Dictionary) -> void:
	item["z"] = float(seg) * t.seg_len + float(item.get("dz", 1.0))
	item.erase("dz")
	t.get_segment(seg).sprites.append(item)


## x of a prop `off` metres beyond the shoulder (Track._prop_x with "outer").
func _x(t: Track, side: int, off: float) -> float:
	return float(side) * (1.5 * t.lane_w + t.shoulder_w + off)


## Transforms of a group's MultiMesh buffer (stride 12, or 16 with an instance colour).
func _transforms(buf: PackedFloat32Array, stride: int) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for i in buf.size() / stride:
		var o := i * stride
		out.append(Transform3D(Basis(Vector3(buf[o], buf[o + 4], buf[o + 8]), Vector3(buf[o + 1], buf[o + 5], buf[o + 9]),
			Vector3(buf[o + 2], buf[o + 6], buf[o + 10])), Vector3(buf[o + 3], buf[o + 7], buf[o + 11])))
	return out


func _same(a: Transform3D, b: Transform3D, eps: float = 1.0e-3) -> bool:
	return a.origin.distance_to(b.origin) < eps and a.basis.x.distance_to(b.basis.x) < eps and a.basis.y.distance_to(b.basis.y) < eps \
		and a.basis.z.distance_to(b.basis.z) < eps


## M2INT: static models draw "vpbr" without instance uniforms – every geometry instance whose material has them takes
## 16 slots of the global shader buffer, and the trees of AS3R (a vpbr trunk each) filled it on forest stages. Vehicles
## keep them (paint, lamps, fade, sun, fill, gloss, cross-fade are per car); the defaults stay; the class parameters
## of "vpbr" (the look) reach the static material too.
func test_static_vpbr_has_no_instance_uniforms() -> void:
	var mats := ModernMaterials.shared()
	var src := mats.shader("vpbr").code
	var st := ModernMaterials.static_code(src)
	assert_true(src.contains("instance uniform"), "vpbr selbst hat Instanz-Uniforms")
	assert_false(st.contains("instance uniform") or st.contains("instance_index"), "vpbr_static: keine Instanz-Uniforms mehr")
	assert_true(st.contains("uniform vec4 paint : source_color = vec4(0.5, 0.5, 0.52, 0.3);"), "Lack mit Farbhinweis und Vorgabe")
	assert_true(st.contains("uniform vec4 lamp_a = vec4(0.0);") and st.contains("uniform float fade = 1.0;")
		and st.contains("uniform float xfade = 0.0;"), "Lampen, Ausblendung und Überblendung mit ihren Vorgaben")
	mats.material("vpbr")
	mats.set_class_parameter("vpbr", "env_energy", 1.25)
	var stat := mats.material(ModernMaterials.VPBR_STATIC) as ShaderMaterial
	assert_true(stat != null and stat != mats.material("vpbr"), "eigenes Material für statische Modelle")
	assert_near(float(stat.get_shader_parameter("env_energy")), 1.25, 1.0e-6, "übernimmt die Klassenparameter, die vpbr schon hat")
	mats.set_class_parameter("vpbr", "env_energy", 1.5)
	assert_near(float(stat.get_shader_parameter("env_energy")), 1.5, 1.0e-6, "… und die späteren (Schlüssel vpbr|static)")
	assert_eq(ModernMaterials.class_for("vpbr", ModelDB.model("props/tree_oak")), ModernMaterials.VPBR_STATIC, "Baum: statisch")
	assert_eq(ModernMaterials.class_for("vpbr", ModelDB.model("traffic/sedan")), "vpbr", "Verkehrsauto: mit Instanz-Uniforms")
	assert_eq(ModernMaterials.class_for("vpbr", ModelDB.model("traffic/bus")), "vpbr", "Bus (heavy): mit Instanz-Uniforms")
	assert_eq(ModernMaterials.class_for("leaves", ModelDB.model("props/tree_oak")), "leaves", "andere Klassen bleiben")
	var trunks := 0
	for pv: Variant in ModelFactory.multimesh_parts("props/tree_oak", "lod0", mats):
		var m: Mesh = (pv as Dictionary)["mesh"]
		for s in m.get_surface_count():
			var sm := m.surface_get_material(s) as ShaderMaterial
			if sm != null and sm.shader != null and sm.shader.code.contains("lamp_a"):
				trunks += 1
				assert_false(sm.shader.code.contains("instance uniform"), "Eiche: vpbr-Fläche ohne Instanz-Uniforms")
	assert_true(trunks >= 1, "Eiche: Stamm (und Schattenwerfer) in vpbr_static (%d)" % trunks)
	var car := 0
	for pv: Variant in ModelFactory.multimesh_parts("traffic/sedan_red", "lod1", mats):
		var m2: Mesh = (pv as Dictionary)["mesh"]
		var sm2 := m2.surface_get_material(0) as ShaderMaterial
		if sm2 != null and sm2.shader != null and sm2.shader.code.contains("instance uniform"):
			car += 1
	assert_true(car >= 1, "Verkehrsauto: vpbr mit Instanz-Uniforms (%d)" % car)
	_cleanup()


func test_helpers_follow_arcade() -> void:
	for side: int in [-1, 1]:
		for flipped: bool in [false, true]:
			for sc: float in [1.0, 0.8]:
				assert_near(Props.edge_anchor_x(12.0 * float(side), side, flipped, 6.5, 3.25, sc),
					RoadRenderer.edge_anchor_x(12.0 * float(side), side, flipped, Vector2(6.5, 3.25), sc), 1.0e-5, "edge_anchor_x wie in Arcade")
	# a mirrored node (scale -1 in x) times mirror_x(T) is T with the model mirrored in its own x
	var t := Transform3D(Basis(Vector3.UP, 0.7).scaled(Vector3(1.3, 1.3, 1.3)), Vector3(4.0, -1.5, -20.0))
	var node := Transform3D(Basis.from_scale(Vector3(-1.0, 1.0, 1.0)), Vector3.ZERO)
	var want := t * Transform3D(Basis.from_scale(Vector3(-1.0, 1.0, 1.0)), Vector3.ZERO)
	assert_true(_same(node * Props.mirror_x(t), want), "gespiegelter Knoten x mirror_x(T) = T x Spiegelung")
	assert_true(Props.mirror_x(t).basis.determinant() > 0.0, "die Instanz selbst ist nicht gespiegelt (D24)")
	var seen := {}
	for i in 200:
		var h := Props.hash01(1000 + i, i % 5, 3)
		assert_true(h >= 0.0 and h < 1.0, "hash01 in 0..1")
		seen[int(h * 10.0)] = true
	assert_true(seen.size() >= 9, "hash01 streut")
	assert_eq(Props.hash01(77, 2, 5), Props.hash01(77, 2, 5), "hash01 ist stabil")


func test_lod_levels() -> void:
	assert_eq(Props.lod_level(0.0, -1, 60.0, 200.0), 0, "im Stück der Kamera: Stufe 0")
	assert_eq(Props.lod_level(59.0, -1, 60.0, 200.0), 0, "bis prop_lod0_m")
	assert_eq(Props.lod_level(61.0, -1, 60.0, 200.0), 1, "danach Stufe 1")
	assert_eq(Props.lod_level(61.0, 0, 60.0, 200.0), 0, "Hysterese: bleibt etwas länger auf 0")
	assert_eq(Props.lod_level(67.0, 0, 60.0, 200.0), 1, "… aber nicht lange")
	assert_eq(Props.lod_level(199.0, 2, 60.0, 200.0), 1, "bis prop_lod1_m")
	assert_eq(Props.lod_level(203.0, 1, 60.0, 200.0), 1, "Hysterese auf 1")
	assert_eq(Props.lod_level(260.0, 1, 60.0, 200.0), 2, "fern: Stufe 2")


func test_library_resolves_every_prop_set() -> void:
	var manifest: Dictionary = ConfigLoader.load_json("res://assets/sprites/manifest.json")
	var ids: Array = []
	for id: String in (manifest["sets"] as Dictionary):
		if id.begins_with("props/") or id.begins_with("landmarks/"):
			ids.append(id)
	assert_true(ids.size() >= 100, "Requisiten- und Wahrzeichen-Sets im Sprite-Manifest (%d)" % ids.size())
	var lib := PropLibrary.new()
	lib.request(ids, self)
	var guard := 0
	while lib.pending() > 0 and guard < 30000:
		OS.delay_msec(1)
		guard += 1
	assert_true(lib.ready(), "Bibliothek bereit")
	assert_eq(lib.fail_reason(), "", "kein Ausfall")
	var models := 0
	var sprites := 0
	for id: String in ids:
		var e: Dictionary = lib.sets[id]
		var kind := int(e["kind"])
		assert_true(kind == PropLibrary.MODEL or kind == PropLibrary.SPRITE, "%s ist Modell oder Vertretung" % id)
		assert_true(float(e["w"]) > 0.1 and float(e["h"]) > 0.1 and float(e["height"]) > 0.05, "%s hat Maße" % id)
		if kind == PropLibrary.MODEL:
			models += 1
			assert_true(ModelDB.has_model(id), "%s: Modell laut ModelDB" % id)
		else:
			sprites += 1
			assert_true(not lib.standin(id).is_empty(), "%s: Vertretung mit Netz und Material" % id)
	assert_eq(sprites, lib.fallback_sets, "fallback_sets zählt die Vertretungen")
	assert_true(models >= 4, "Referenzmodelle (%d)" % models)
	var oak: Dictionary = lib.sets["props/tree_oak"]
	assert_eq(str(oak["cls"]), "tree", "Eiche ist ein Baum")
	assert_true(bool(oak["veg"]) and float(oak["blob"]) > 0.0, "Vegetation mit Kontaktschatten")
	var oak_m: Dictionary = lib.models["props/tree_oak"]
	assert_eq(oak_m["reps"], ["lod0", "lod1", PropLibrary.IMPOSTOR], "Eiche: lod0, lod1, Fernbild")
	assert_true(bool(oak_m["caster"]), "Eiche hat einen Schattenwerfer")
	assert_eq((lib.models["props/farmhouse"] as Dictionary)["reps"], ["lod0", "lod0", "lod0"], "Bauernhaus: eine Stufe für alles")
	assert_true(bool((lib.sets["props/farmhouse"] as Dictionary)["mirror_left"]), "Bauernhaus wird links gespiegelt")
	var lamp_list: Array = (lib.models["props/streetlight"] as Dictionary)["lamps"]
	assert_eq(lamp_list.size(), 1, "Laterne: ein Lichtanker mit Richtung")
	var farm_lamps: Array = (lib.models["props/farmhouse"] as Dictionary)["lamps"]
	assert_eq(farm_lamps.size(), 1, "Bauernhaus: eine Wandlampe mit Anker (die Fenster leuchten über Kanal 12, ohne Anker)")
	assert_near(float(farm_lamps[0]["range"]), PropLibrary.WALL_RANGE_M, 0.001, "Wandlampe: kleiner Lichtkegel vor der Wand")
	assert_near(float(lamp_list[0]["range"]), PropLibrary.LAMP_RANGE_M, 0.001, "Laterne: Kegel wie Arcades Laternen")
	assert_near(float(lamp_list[0]["energy"]), PropLibrary.LAMP_ENERGY, 0.001, "… und deren Stärke")
	var station: Array = (lib.models["props/fuel_station"] as Dictionary)["lamps"]
	assert_eq(station.size(), 8, "Tankstelle: acht Lampen unter dem Dach")
	assert_near(float(station[0]["energy"]), PropLibrary.GROUP_ENERGY / 8.0, 0.001, "… die sich das Licht von Arcades Tankstellenkegel teilen")
	for b: Dictionary in (lib.models["props/wind_turbine"] as Dictionary)["lamps"]:
		assert_near(float(b["range"]), 0.0, 0.001, "Flugbefeuerung des Windrads: kein Lichtkegel am Boden, nur Schein")
	assert_eq(lib.mesh_parts("props/tree_oak", "lod0").size(), 2, "Eiche lod0: Netz und Schattenwerfer")
	assert_eq(lib.mesh_parts("props/tree_oak", PropLibrary.IMPOSTOR).size(), 1, "Eiche: Fernbild als Billboard")
	var birch: Dictionary = lib.sets["props/tree_birch"]
	assert_near(float(birch["w"]), 7.4396, 0.001, "Zellbreite in Metern aus dem Sprite-Manifest")
	assert_near(float(birch["h"]), 7.4396 * 320.0 / 176.0, 0.001, "… und Zellhöhe")
	assert_eq((birch["variants"] as Array).size(), 2, "Birke: zwei Samen-Varianten (AS1b)")
	var sb := _standin_set()
	assert_true(sb != "", "es gibt noch ein Requisiten-Set ohne Modell (sonst: Test-Manifest wie check_vehicles „kasten“)")
	if sb != "":
		assert_eq(int((lib.sets[sb] as Dictionary)["kind"]), PropLibrary.SPRITE, "%s: noch eine Vertretung" % sb)
	assert_eq(str((lib.sets["props/wind_turbine"] as Dictionary)["cls"]), "other", "Windrad: kein Baum, kein Haus")
	assert_near(float((lib.sets["props/wind_turbine"] as Dictionary)["blob"]), 0.0, 0.001, "hohe Bauwerke ohne Kontaktschatten")
	assert_eq(int((lib.sets["unknown/thing"] if lib.sets.has("unknown/thing") else {"kind": PropLibrary.NONE})["kind"]), PropLibrary.NONE, "unbekannt")
	lib.clear(self)
	_cleanup()


func test_placement_drops_and_lamps() -> void:
	var t := _track()
	var sb := _standin_set()     # a set the manifest still draws as its Arcade sprite (AS3: no longer the beech)
	assert_true(sb != "", "es gibt noch ein Requisiten-Set ohne Modell")
	# chunk 6 = segments 192..224 (straight)
	_put(t, 195, {"kind": "prop", "set": "props/farmhouse", "side": 1, "x": _x(t, 1, 40.0), "scale": 1.0, "align": "edge"})
	_put(t, 196, {"kind": "prop", "set": "props/farmhouse", "side": -1, "x": _x(t, -1, 40.0), "scale": 0.9, "align": "edge"})
	_put(t, 198, {"kind": "prop", "set": "props/tree_oak", "side": 1, "x": _x(t, 1, 12.0), "scale": 1.1})
	_put(t, 199, {"kind": "prop", "set": sb, "side": -1, "x": _x(t, -1, 9.0), "scale": 1.0, "mirror": true, "tint": "#ff8080"})
	_put(t, 200, {"kind": "prop", "set": sb, "side": 1, "x": _x(t, 1, 9.0), "scale": 1.2})
	_put(t, 201, {"kind": "object", "obj": "streetlight", "side": 1, "x": _x(t, 1, -0.6), "scale": 1.0})
	_put(t, 202, {"kind": "object", "obj": "streetlight", "side": -1, "x": _x(t, -1, -0.6), "scale": 1.0})
	_put(t, 203, {"kind": "prop", "set": "props/tree_oak", "side": 1, "x": _x(t, 1, 700.0), "scale": 1.0})        # beyond the ribbon
	_put(t, 204, {"kind": "prop", "set": "props/does_not_exist", "side": 1, "x": _x(t, 1, 5.0), "scale": 1.0})    # no such set
	_put(t, 205, {"kind": "prop", "set": "props/does_not_exist", "fallback": sb, "fallback_scale": 0.5, "side": 1,
		"x": _x(t, 1, 6.0), "scale": 1.0})
	_put(t, 206, {"kind": "sign", "sign": "limit", "side": 1, "x": _x(t, 1, 1.0), "scale": 1.0})                 # not a prop
	var fake := FakeRenderer.new()
	var ctx := _ctx(t, 6, {}, {"renderer": fake})
	var b := Props.new()
	var part := b.build(ctx, b.collect(ctx))
	assert_eq((part["list"] as Array).size(), 8, "acht Requisiten gezeichnet")
	assert_eq(part["dropped"], {"ribbon": 1, "corridor": 0, "missing": 1, "density": 0}, "ausgelassen: jenseits des Bands, Set fehlt")
	var groups: Dictionary = part["groups"]
	assert_true(groups.has("m|props/farmhouse|0") and groups.has("m|props/farmhouse|1"), "Bauernhaus: rechts normal, links gespiegelt")
	assert_true(groups.has("s|%s|0" % sb) and groups.has("s|%s|1" % sb), "%s: Vertretung, links mit Regel-Spiegelung" % sb)
	var oak_id := Props.chunk_variant(6, "props/tree_oak", (b.library.sets["props/tree_oak"] as Dictionary)["variants"])
	assert_true(oak_id.begins_with("props/tree_oak"), "Eiche: eine ihrer Varianten (%s)" % oak_id)
	assert_true(groups.has("m|%s|0" % oak_id) and not groups.has("m|%s|1" % oak_id), "Eiche: nie gespiegelt")
	assert_true(groups.has("m|props/streetlight|0") and groups.has("m|props/streetlight|1"), "Laternen beider Seiten")
	# the farmhouse on the right: like a vehicle on the ground, its near edge at x
	var e_farm: Dictionary = b.library.sets["props/farmhouse"]
	var z := 195.0 * 3.0 + 1.0
	var x := _x(t, 1, 40.0) + float(e_farm["extent_l"])
	var tr := _transforms((groups["m|props/farmhouse|0"] as Dictionary)["buf"], Props.INSTANCE_FLOATS)[0]
	assert_true(_same(tr, ctx.frame(z, x, ctx.ground(z, x))), "Bauernhaus rechts = ChunkContext.frame() auf dem Boden, Vorderkante bei x")
	assert_true(ctx.ground(z, x) < -0.5, "… und der Boden liegt dort unter der Fahrbahn")
	# on the left: mirrored node x instance = frame x mirror, scaled; the mirrored model's left extent faces the road
	var zl := 196.0 * 3.0 + 1.0
	var xl := _x(t, -1, 40.0) - float(e_farm["extent_l"]) * 0.9
	var trl := _transforms((groups["m|props/farmhouse|1"] as Dictionary)["buf"], Props.INSTANCE_FLOATS)[0]
	var node := Transform3D(Basis.from_scale(Vector3(-1.0, 1.0, 1.0)), Vector3.ZERO)
	var want := ctx.frame(zl, xl, ctx.ground(zl, xl)).scaled_local(Vector3(0.9, 0.9, 0.9)) * node
	assert_true(_same(node * trl, want), "Bauernhaus links: gespiegelt, 0,9-fach, auf dem Boden")
	# the oak: upright, scaled, turned by its stable yaw
	var tro := _transforms((groups["m|%s|0" % oak_id] as Dictionary)["buf"], Props.INSTANCE_FLOATS)[0]
	assert_near(tro.basis.y.y, 1.1, 1.0e-4, "Eiche steht aufrecht und ist 1,1-fach")
	assert_near(tro.basis.x.length(), 1.1, 1.0e-4, "gleichmäßig skaliert")
	var zo := 198.0 * 3.0 + 1.0
	assert_near(tro.origin.distance_to(ctx.local(zo, _x(t, 1, 12.0), ctx.ground(zo, _x(t, 1, 12.0)))), 0.0, 1.0e-3, "Eiche auf dem Boden")
	# stand-ins: origin on the ground, uniform scale, instance colour = tint, empty custom data (RINT-M2: see
	# Props.NO_CUSTOM); the left one mirrored in the node
	var bl: PackedFloat32Array = (groups["s|%s|1" % sb] as Dictionary)["buf"]
	assert_eq(bl.size(), 20, "Vertretung: Transformation, Farbe und leere Custom-Daten")
	assert_near(bl[12], 1.0, 0.01, "Tönung rot")
	assert_near(bl[13], 0.5, 0.01, "Tönung grün")
	assert_near(bl[19], 0.0, 1.0e-6, "Custom-Daten a = 0: keine zweite Tönung")
	var zb := 199.0 * 3.0 + 1.0
	var pb := ctx.local(zb, _x(t, -1, 9.0), ctx.ground(zb, _x(t, -1, 9.0)))
	assert_near((node * _transforms(bl, 20)[0]).origin.distance_to(pb), 0.0, 1.0e-3, "gespiegelte Vertretung steht an ihrem Ort")
	var br: PackedFloat32Array = (groups["s|%s|0" % sb] as Dictionary)["buf"]
	assert_eq(br.size(), 40, "rechts zwei Vertretungen (eine als Ersatz-Set)")
	assert_near(_transforms(br, 20)[1].basis.x.x, 0.5, 1.0e-4, "Ersatz-Set mit fallback_scale")
	# lamps: the wall lamps of the two farmhouses (segments 195, 196), then the two street lights, in chunk coordinates
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
	# contact shadows: farmhouses, oak and the three stand-ins if their class has one – not the street lights
	var sb_blob := float((b.library.sets[sb] as Dictionary).get("blob", 0.0)) > 0.0
	assert_eq(int(part["blob_n"]), 3 + (3 if sb_blob else 0), "Kontaktschatten (%s: %s)" % [sb, "mit" if sb_blob else "ohne"])
	# commit: nodes, mirrored nodes, lamps at the renderer, draw calls per set
	var parent := Node3D.new()
	b.commit(ctx, part, parent)
	var holder := parent.get_child(0) as Node3D
	assert_eq(fake.lamps.size(), 4, "add_lamps() über ctx.services")
	assert_true(fake.parents[0] == holder, "… mit dem Requisiten-Knoten des Stücks als parent")
	for cam: float in [600.0, 480.0, 250.0]:
		fake.view["camera_z"] = cam
		b.update({"camera_z": cam}, 0.0)
		var calls := {}
		var mirrored_sets := {}
		for c: Node in holder.get_children():
			var mmi := c as MultiMeshInstance3D
			if not mmi.visible or mmi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY or mmi.name == &"Contact":
				continue
			var key := mmi.multimesh.mesh.resource_path if mmi.multimesh.mesh.resource_path != "" else str(mmi.multimesh.mesh.get_instance_id())
			key = key.get_base_dir() if key.begins_with("res://") else key
			# per side: a set placed on both roadsides needs a second, mirrored node (D24), and a model with two
			# surfaces (a house: baked walls + vpbr panes, AS1b) then costs 2 x 2 – the budget holds per set, chunk and side
			key += " (gespiegelt)" if mmi.basis.determinant() < 0.0 else ""
			# R7c: per representation – while the instances of a chunk cross a level boundary (the dither cross-fade)
			# two neighbouring levels of a set are drawn, each within the budget
			var rep := str(mmi.get_meta(&"rep", ""))
			var per: Dictionary = calls.get(key, {})
			per[rep] = int(per.get(rep, 0)) + mmi.multimesh.mesh.get_surface_count()
			calls[key] = per
			if mmi.basis.determinant() < 0.0:
				mirrored_sets[key] = true
		for key: String in calls:
			var per: Dictionary = calls[key]
			assert_true(per.size() <= 2, "höchstens zwei Stufen eines Sets zugleich (Überblenden: %s %s, Kamera %.0f)" % [key, str(per.keys()), cam])
			for rep: String in per:
				assert_true(int(per[rep]) <= DRAW_CALLS_PER_SET, "höchstens %d Zeichenaufrufe je Set, Stufe, Stück und Seite (%s %s: %d, Kamera %.0f)" % [DRAW_CALLS_PER_SET, key, rep, per[rep], cam])
		assert_eq(mirrored_sets.size(), 3, "drei gespiegelte Sets (Bauernhaus, Buche, Laterne links)")
	parent.free()
	_cleanup()


## RINT-M2 (A-19): the placement tint ("tint", times "fallback_tint") reaches a MODEL instance as its MultiMesh custom data
## (r, g, b, 1) – the shaders multiply the albedo by it as Arcade multiplies the sprite; an untinted model gets white
## (its picture stays as it was); never an instance uniform. Stand-ins keep it as their instance colour.
func test_model_instances_carry_the_placement_tint() -> void:
	var t := _track()
	_put(t, 195, {"kind": "prop", "set": "props/farmhouse", "side": 1, "x": _x(t, 1, 40.0), "scale": 1.0, "tint": "#e8b8a4"})
	_put(t, 197, {"kind": "prop", "set": "props/farmhouse", "side": 1, "x": _x(t, 1, 40.0), "scale": 1.0})
	_put(t, 199, {"kind": "prop", "set": "props/does_not_exist", "fallback": "props/farmhouse", "fallback_tint": "#808080",
		"tint": "#ff8080", "side": 1, "x": _x(t, 1, 40.0), "scale": 1.0})
	var ctx := _ctx(t, 6)
	var b := Props.new()
	var part := b.build(ctx, b.collect(ctx))
	var g: Dictionary = (part["groups"] as Dictionary).get("m|props/farmhouse|0", {})
	assert_eq(int(g.get("n", 0)), 3, "drei Bauernhäuser in einer Gruppe")
	var buf: PackedFloat32Array = g.get("buf", PackedFloat32Array())
	assert_eq(buf.size(), 3 * Props.INSTANCE_FLOATS, "je Instanz Transformation, Farbe (weiß) und Tönung (12 + 4 + 4)")
	if buf.size() == 60:
		var want := Color("#e8b8a4")
		for k in 4:
			assert_near(buf[12 + k], 1.0, 1.0e-6, "Instanzfarbe eines Modells weiß [%d]" % k)
		assert_near(buf[16], want.r, 1.0e-4, "getönt: rot")
		assert_near(buf[17], want.g, 1.0e-4, "getönt: grün")
		assert_near(buf[18], want.b, 1.0e-4, "getönt: blau")
		# R7c: a = 1 + phase (rotor and sway phase per instance) – the shaders read the tint for a > 0.5
		assert_between(buf[19], 1.0, 1.999, "getönt: a = 1 + Phase (die Shader lesen die Tönung bei a > 0,5)")
		for k in 3:
			assert_near(buf[20 + 16 + k], 1.0, 1.0e-6, "ungetönt: weiß (Bild unverändert) [%d]" % k)
		assert_between(buf[20 + 19], 1.0, 1.999, "ungetönt: a = 1 + Phase")
		var fb := Color("#ff8080") * Color("#808080")
		assert_near(buf[40 + 16], fb.r, 1.0e-4, "Ersatz-Set: tint × fallback_tint (rot)")
		assert_near(buf[40 + 17], fb.g, 1.0e-4, "Ersatz-Set: tint × fallback_tint (grün)")
	var parent := Node3D.new()
	b.commit(ctx, part, parent)
	var holder := parent.get_child(0) as Node3D
	var models := 0
	for c: Node in holder.get_children():
		var mmi := c as MultiMeshInstance3D
		if mmi == null or mmi.name == &"Contact":
			continue
		models += 1
		assert_true(mmi.multimesh.use_custom_data, "Modell-Knoten trägt die Tönung als Instanzdaten (%s)" % mmi.multimesh.mesh.resource_path)
		assert_true(mmi.multimesh.use_colors, "… und eine (weiße) Instanzfarbe – siehe Props.NO_CUSTOM")
		assert_eq(mmi.multimesh.instance_count, 3, "drei Instanzen")
	assert_true(models >= 1, "Knoten des Modells gebaut (%d)" % models)
	# Godot's Compatibility renderer reads INSTANCE_CUSTOM wrongly unless a MultiMesh has colours AND custom data
	# (measured: bright green tints, see Props.NO_CUSTOM): _mmi() makes every node so, a stand-in's buffer carries
	# NO_CUSTOM (headless there are no stand-ins in a chunk: the builder's node maker directly)
	var one := PackedFloat32Array()
	Props._put(one, Transform3D.IDENTITY)
	one.append_array(PackedFloat32Array([1.0, 0.5, 0.5, 1.0]))
	one.append_array(PackedFloat32Array(Props.NO_CUSTOM))
	var sn := Props._mmi({"mesh": QuadMesh.new()}, one, 1, false)
	assert_true(sn.multimesh.use_colors and sn.multimesh.use_custom_data, "Vertretung: Farbe und Custom-Daten")
	assert_eq((Props.NO_CUSTOM as Array).size(), 4, "NO_CUSTOM: vier Werte")
	assert_near(float(Props.NO_CUSTOM[3]), 0.0, 1.0e-6, "NO_CUSTOM: a = 0 (die Shader tönen nicht)")
	sn.free()
	# the shaders read it: custom data, a > 0.5, multiplied into the albedo
	var mats := ModernMaterials.shared()
	for cls: String in ["baked", "leaves", "billboard", "vpbr"]:
		var code := mats.shader(cls).code
		assert_true(code.contains("INSTANCE_CUSTOM.a > 0.5 ? INSTANCE_CUSTOM.rgb : vec3(1.0)") and code.contains("v_tint"),
			"%s liest die Tönung aus den Instanzdaten" % cls)
		assert_false(code.contains("instance uniform vec4 tint") or code.contains("instance uniform vec3 tint"), "%s: keine Instanz-Uniform dafür" % cls)
	assert_true(_code_only(ModernMaterials.static_code(mats.shader("vpbr").code)).contains("alb *= v_tint"), "vpbr_static multipliert die Albedo")
	# FIX-RINT (QA-RINT-SYSTEM B-02): every class MULTIPLIES its colour by the tint – reading it is not enough (a shader
	# that reads v_tint but drops the multiplication left the pink houses of S4 white with every check green); comments
	# do not count
	var baked := _code_only(mats.shader("baked").code)
	assert_true(baked.contains("a.rgb *= v_tint;"), "baked multipliert die Albedo mit der Tönung")
	var leaves := _code_only(mats.shader("leaves").code)
	var rx := RegEx.create_from_string("ALBEDO\\s*=[^;]*\\*\\s*v_tint\\s*;")
	assert_true(rx.search(leaves) != null, "leaves multipliert ALBEDO mit der Tönung")
	var board := _code_only(mats.shader("billboard").code)
	assert_true(board.contains("vec3 tint = COLOR.rgb * v_tint;") and board.contains("t.rgb * tint"),
		"billboard multipliert das Bild mit Instanzfarbe × Tönung")
	parent.free()
	_cleanup()


## Shader code without its comments (// to the end of the line, /* … */).
static func _code_only(code: String) -> String:
	var rx := RegEx.create_from_string("/\\*[\\s\\S]*?\\*/|//[^\\n]*")
	return rx.sub(code, "", true)


func test_chunk_lod_shows_one_representation() -> void:
	# R7c: the chunk switches on the representations whose distance band holds at least one of its instances (the
	# shaders choose per instance, with the cross-fade): far from the band edges exactly one, inside a band both
	# neighbours. (FIX-R7c, QR7c-07: this note stands inside the function, so that the assembly with FIX-RINT, which
	# adds a helper right above it, merges without a conflict.)
	var t := _track()
	_put(t, 198, {"kind": "prop", "set": "props/tree_oak", "side": 1, "x": _x(t, 1, 12.0), "scale": 1.0})
	_put(t, 210, {"kind": "prop", "set": "props/tree_oak", "side": -1, "x": _x(t, -1, 20.0), "scale": 1.0})
	var ctx := _ctx(t, 6)
	var b := Props.new()
	b.apply_quality({"prop_lod0_m": 60.0, "prop_lod1_m": 200.0, "shadow_casters": 2, "shadow_distance_m": 120.0, "deco_density": 1.0})
	var part := b.build(ctx, b.collect(ctx))
	var parent := Node3D.new()
	b.commit(ctx, part, parent)
	var holder := parent.get_child(0)
	# the oaks stand at z 595 and 631 (1 m into their segments), 14 and 22 m beside the centre line
	var zi := 198.0 * 3.0 + 1.0
	for probe: Array in [[zi + 5.0, ["lod0"], true], [zi - 100.0, ["lod1"], true], [zi - 125.0, ["lod1"], true],
			[zi - 61.0, ["lod0", "lod1"], true], [zi - 400.0, [PropLibrary.IMPOSTOR], false]]:
		b.update({"camera_z": float(probe[0])}, 0.0)
		var shown: Array = []
		var caster := false
		for c: Node in holder.get_children():
			var n3 := c as MultiMeshInstance3D
			if not n3.visible or n3.name == &"Contact":
				continue
			if n3.has_meta(&"caster"):
				caster = true
				assert_eq(n3.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "der Schattenwerfer ist nur im Schattendurchgang")
			else:
				shown.append(str(n3.get_meta(&"rep")))
				assert_eq(n3.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "das sichtbare Netz der Eiche wirft selbst nicht")
				assert_eq(n3.multimesh.instance_count, 2, "beide Eichen in einem MultiMesh")
		shown.sort()
		var want: Array = probe[1]
		assert_eq(shown, want, "Kamera %.0f m vor der ersten Eiche: %s" % [zi - float(probe[0]), str(want)])
		assert_eq(caster, bool(probe[2]), "Schattenwerfer nur in Reichweite der Schattenkarte")
	# the bands on the level materials: lod0 fades out where lod1 fades in, the impostor takes over at the end of lod1
	var bands := b.model_bands("props/tree_oak")
	var b0: Vector4 = bands["lod0"]
	var b1: Vector4 = bands["lod1"]
	var bi: Vector4 = bands[PropLibrary.IMPOSTOR]
	assert_near(b0.z, b1.x, 1.0e-4, "lod0 blendet aus, wo lod1 einblendet (Anfang)")
	assert_near(b0.w, b1.y, 1.0e-4, "… und Ende des Bandes")
	assert_near(b1.z, bi.x, 1.0e-4, "lod1 → Fernbild: dasselbe Band")
	assert_near((b0.z + b0.w) * 0.5, 60.0, 1.0e-3, "Mitte des Bandes = prop_lod0_m × 60 / 60")
	for mat: ShaderMaterial in b.library.rep_materials("props/tree_oak", "lod0"):
		assert_eq(mat.get_shader_parameter("lod_band"), b0, "das Band steht auf dem Material von lod0")
		for l: Array in Props.PROP_LOOK:
			assert_eq(mat.get_shader_parameter(str(l[0])), l[1], "Requisitenbild %s auf dem Material" % str(l[0]))
	for mat: ShaderMaterial in b.library.rep_materials("props/tree_oak", "lod1"):
		assert_eq(mat.get_shader_parameter("lod_band"), b1, "… und auf dem von lod1")
	parent.free()
	# "Schatten: Aus" / "Niedrig": no caster nodes at all
	var b2 := Props.new()
	b2.apply_quality({"shadow_casters": 1})
	var parent2 := Node3D.new()
	b2.commit(ctx, b2.build(ctx, b2.collect(ctx)), parent2)
	for c: Node in parent2.get_child(0).get_children():
		assert_true(not c.has_meta(&"caster"), "ohne Baum-Schatten kein Schattenwerfer-Knoten")
	parent2.free()
	_cleanup()


func test_bend_corridor_and_density() -> void:
	var t := _track()
	# chunk 13 = segments 416..448: the first 100 m of the right bend (R = 200 m), its inside is the right roadside –
	# the sight lines of the fast approach cross it there (corridor of A-17: 37–43 m beyond the shoulder)
	for i in 8:
		_put(t, 418 + i * 3, {"kind": "prop", "set": "props/tree_birch", "side": 1, "x": _x(t, 1, 12.0 + float(i)), "scale": 1.0})
		_put(t, 419 + i * 3, {"kind": "prop", "set": "props/tree_birch", "side": -1, "x": _x(t, -1, 12.0 + float(i)), "scale": 1.0})
	_put(t, 444, {"kind": "prop", "set": "props/farmhouse", "side": 1, "x": _x(t, 1, 30.0), "scale": 1.0})
	_put(t, 445, {"kind": "prop", "set": "props/radar_camera", "side": 1, "x": _x(t, 1, 0.3), "scale": 1.0, "offset": 0.3})
	_put(t, 446, {"kind": "prop", "set": "props/tree_oak", "side": 1, "x": _x(t, 1, 20.0), "scale": 1.0, "offset": 20.0})
	var ctx := _ctx(t, 13)
	assert_true(ctx.in_bend_corridor(424.0 * 3.0, _x(t, 1, 15.0)), "Kurveninnenseite: Sichtkorridor")
	assert_false(ctx.in_bend_corridor(424.0 * 3.0, _x(t, -1, 15.0)), "Außenseite: kein Kurvenkorridor")
	var b := Props.new()
	var part := b.build(ctx, b.collect(ctx))
	var d: Dictionary = part["dropped"]
	assert_eq(int(d["corridor"]), 10, "innen fallen die acht Birken, das Bauernhaus und der Parkbaum weg")
	var kept := {}
	for e: Array in part["list"]:
		kept[str(e[2])] = int(kept.get(str(e[2]), 0)) + 1
	assert_eq(int(kept.get("props/tree_birch", 0)), 8, "außen bleiben die acht Birken")
	assert_eq(int(kept.get("props/radar_camera", 0)), 1, "ein Radarkasten bleibt immer stehen (Regel 9)")
	assert_false(kept.has("props/farmhouse"), "kein Haus im Sichtkorridor")
	# ground cover: a set on the list stays, at most 0.5 m high
	var input: Dictionary = b.collect(ctx)
	input["cover"] = ["props/tree_birch"]
	var covered := b.build(ctx, input)
	var small := 0
	for e: Array in covered["list"]:
		if str(e[2]) == "props/tree_birch" and float(e[3]) > 0.0:
			small += 1
			assert_true(float(e[5]) * float((b.library.sets["props/tree_birch"] as Dictionary)["height"]) <= 0.5 + 1.0e-3, "Bodenbewuchs höchstens 0,5 m")
	assert_eq(small, 8, "mit Liste bleiben die acht Sets innen als Bodenbewuchs")
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
	assert_eq((part_c["list"] as Array).size(), (part["list"] as Array).size(), "die Streckenliste bleibt dieselbe")
	# "Details: Niedrig" thins small decoration only
	var t2 := _track()
	for i in 30:
		_put(t2, 193 + i, {"kind": "prop", "set": "props/tree_birch", "side": 1 if i % 2 == 0 else -1, "x": _x(t2, 1 if i % 2 == 0 else -1, 10.0), "scale": 1.0, "dz": 0.5})
		_put(t2, 193 + i, {"kind": "prop", "set": "props/farmhouse", "side": 1, "x": _x(t2, 1, 60.0), "scale": 1.0, "dz": 1.5})
		_put(t2, 193 + i, {"kind": "prop", "set": "props/wind_turbine", "side": -1, "x": _x(t2, -1, 100.0), "scale": 1.0, "dz": 2.5})
	var ctx2 := _ctx(t2, 6)
	var b3 := Props.new()
	b3.apply_quality({"deco_density": 0.6})
	var thin := b3.build(ctx2, b3.collect(ctx2))
	var counts: Dictionary = thin["counts"]
	assert_eq(int(counts.get("props/farmhouse", 0)), 30, "Häuser werden nie ausgedünnt")
	assert_eq(int(counts.get("props/wind_turbine", 0)), 30, "Windräder auch nicht")
	assert_between(float(counts.get("props/tree_birch", 0)), 12.0, 24.0, "von 30 Birken bleiben bei 0,6 etwa 18")
	assert_eq(int((thin["dropped"] as Dictionary)["density"]), 30 - int(counts.get("props/tree_birch", 0)), "ausgedünnte Birken gezählt")
	_cleanup()


## The shipped manifest with the models of `set_ids` taken away (each a sprite stand-in, as a set without a model is
## shown); the meshes of every other set stay those of the shipped models ("root", like tests/race3d/check_vehicles.gd
## "kasten"). "" when it cannot be written. Load the shipped manifest again with ModelDB.load_manifest() afterwards.
func _manifest_without_models(set_ids: Array) -> String:
	var src: Variant = JSON.parse_string(FileAccess.get_file_as_string(ModelDB.ROOT + ModelDB.MANIFEST))
	if not src is Dictionary:
		return ""
	var m: Dictionary = src
	m["root"] = ModelDB.ROOT
	var sets: Dictionary = m["sets"]
	for sid: String in set_ids:
		sets[sid] = {"fallback": "sprite"}
	var path := "user://test_props_manifest_without_models.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(m))
	f.close()
	return path


## The pylons of a cable-stayed bridge as the track places them ("prefer_proc": Arcade draws them procedurally,
## concrete grey at night, with a blinking red aviation light) and one plain item of the same set.
func _pylon_track() -> Track:
	var t := _track()
	_put(t, 197, {"kind": "prop", "set": "props/bridge_pylon", "proc": "pylon", "prefer_proc": true, "side": 1,
		"x": _x(t, 1, 1.3), "offset": 1.3, "height_m": 80.0, "cables": 40.0, "bridge": "cable_stayed", "color": ""})
	_put(t, 197, {"kind": "prop", "set": "props/bridge_pylon", "proc": "pylon", "prefer_proc": true, "side": -1,
		"x": _x(t, -1, 1.3), "offset": 1.3, "height_m": 80.0, "cables": 40.0, "bridge": "cable_stayed", "color": "", "dz": 1.5})
	_put(t, 205, {"kind": "prop", "set": "props/bridge_pylon", "side": 1, "x": _x(t, 1, 30.0), "scale": 1.0})
	return t


## M2ZS1 (merge of the first test build into M2): since AS4R the pylon is a MODEL (props/bridge_pylon: concrete, head and
## aviation light in one baked atlas) – both sides as the model (the left one mirrored, mirror_left), no stand-in. Its
## night atlas is the sprite's floodlit pylon, which Arcade never shows: the pylons of the bridge (prefer_proc) get a
## copy of the material without it (emit_energy 0, "md|" groups; the 22:00 pictures of the Köhlbrandbrücke glowed light
## grey), the same set without prefer_proc keeps it. The red aviation light is a lamp anchor of each pylon, high up (no
## light pool), blinking like Arcade's.
func test_bridge_pylon_is_a_model_with_its_aviation_light() -> void:
	var t := _pylon_track()
	var ctx := _ctx(t, 6)
	var b := Props.new()
	var part := b.build(ctx, b.collect(ctx))
	var groups: Dictionary = part["groups"]
	assert_eq(int((b.library.sets["props/bridge_pylon"] as Dictionary)["kind"]), PropLibrary.MODEL, "Pylon: Modell (AS4R)")
	assert_true(groups.has("md|props/bridge_pylon|0") and groups.has("md|props/bridge_pylon|1"),
		"Brückenpylone beider Seiten als dunkles Modell (links gespiegelt) – %s" % str(groups.keys()))
	assert_true(groups.has("m|props/bridge_pylon|0"), "derselbe Satz ohne prefer_proc: das Modell wie es ist")
	for key: String in groups:
		assert_false(key.begins_with("d|") or key.begins_with("s|props/bridge_pylon"), "keine Vertretung, wenn das Modell da ist (%s)" % key)
	var parent := Node3D.new()
	b.commit(ctx, part, parent)
	var dark := 0
	var lit := 0
	for c: Node in (parent.get_child(0).get_children() if parent.get_child_count() > 0 else []):
		var mmi := c as MultiMeshInstance3D
		if mmi == null or mmi.name == &"Contact" or mmi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			continue
		if mmi.material_override is ShaderMaterial:
			var mo := mmi.material_override as ShaderMaterial
			# (a parameter that was never set reads null: float(null) would abort the test – QA-M2-SYSTEM M2S-04)
			var emit: Variant = mo.get_shader_parameter("emit_energy")
			var night: Variant = mo.get_shader_parameter("night_albedo")
			assert_true(emit is float or emit is int, "dunkler Pylon: emit_energy gesetzt (%s)" % str(emit))
			assert_true(night is float or night is int, "dunkler Pylon: night_albedo gesetzt (%s)" % str(night))
			assert_near(float(emit) if (emit is float or emit is int) else -1.0, 0.0, 1.0e-6, "dunkler Pylon: ohne Nachtatlas (Flutlicht)")
			assert_near(float(night) if (night is float or night is int) else -1.0, Props.PYLON_NIGHT_ALBEDO, 1.0e-6,
				"dunkler Pylon: nachts Beton × Umgebungslicht wie Arcade (night_albedo)")
			assert_true(Props.PYLON_NIGHT_ALBEDO < 1.0, "… also dunkler als das beleuchtete Modell")
			dark += 1
		else:
			lit += 1
	assert_eq(dark, 2, "zwei dunkle Pylon-Knoten (rechts und gespiegelt links)")
	assert_eq(lit, 1, "das Set ohne prefer_proc behält sein Material")
	parent.free()
	var beacons: Array = []
	for l: Dictionary in part["lamps"]:
		if (l["pos"] as Vector3).y > PropLibrary.BEACON_MIN_H_M:
			beacons.append(l)
	assert_eq(beacons.size(), 3, "eine Flugbefeuerung je Pylon (zwei der Brücke, eins für sich)")
	var phases: Array = []
	for l: Dictionary in beacons:
		var c: Color = l["color"]
		assert_true(c.r > 0.9 and c.g < 0.3 and c.b < 0.3, "rot wie Arcades Warnlicht (%s)" % str(c))
		assert_eq(float(l["range"]), 0.0, "hoch oben: kein Lichtkegel am Boden")
		if l.has("blink"):
			var bv: Vector3 = l["blink"]
			assert_near(bv.x, 1.6, 1.0e-6, "Takt wie Arcade: 1,6 s")
			assert_near(bv.y, 0.8, 1.0e-6, "davon 0,8 s an")
			phases.append(snappedf(bv.z, 0.001))
	phases.sort()
	assert_eq(phases, [-0.4, 0.4], "die zwei Pylone der Brücke blinken, um ± 0,4 s versetzt (Seite); das Set ohne proc nicht")
	_cleanup()


## M2ZS1: the blinking aviation light (layers/flares.gd blink_lit, view.time): lit 0.8 s of every 1.6 s, the two sides
## 0.4 s apart, only at night (Arcade: lights > 0.2) – a lamp without a rhythm is always lit.
func test_pylon_beacon_blinks_like_arcade() -> void:
	var flares: GDScript = load("res://scripts/race3d/layers/flares.gd")
	var right := Vector3(Props.PYLON_BLINK.x, Props.PYLON_BLINK.y, Props.PYLON_BLINK.z)
	var left := Vector3(Props.PYLON_BLINK.x, Props.PYLON_BLINK.y, -Props.PYLON_BLINK.z)
	var lit := 0
	var both := 0
	var n := 160
	for i in n:
		var t := 10.005 + float(i) * 0.01                   # 1.6 s in steps of 10 ms, never on a switching instant
		var r: bool = flares.blink_lit(right, t, 1.0)
		var l: bool = flares.blink_lit(left, t, 1.0)
		# Arcade: on while fmod(time + side × 0.4, 1.6) < 0.8
		assert_eq(r, fmod(t + 0.4, 1.6) < 0.8, "rechts wie Arcade bei t = %.2f s" % t)
		assert_eq(l, fmod(t - 0.4, 1.6) < 0.8, "links wie Arcade bei t = %.2f s" % t)
		lit += 1 if r else 0
		both += 1 if r and l else 0
	assert_near(float(lit) / float(n), 0.5, 0.02, "die Hälfte der Zeit an")
	assert_near(float(both) / float(n), 0.0, 0.02, "die zwei Seiten im Wechsel (um 0,8 s versetzt)")
	assert_false(flares.blink_lit(right, 10.0, 0.2), "bei Tag und in der Dämmerung (lights ≤ 0,2) aus")
	assert_true(flares.blink_lit(null, 10.0, 0.0), "eine Lampe ohne Takt bleibt an")


## QA-WASSER B2: the pylon of a cable-stayed bridge ("prefer_proc": Arcade draws it procedurally, concrete grey at
## night) is a stand-in without the sprite's light layer (a floodlit pylon) and without the player's headlights;
## every other stand-in of the set keeps both. Since AS4R the pylon has a model (test above): the stand-in is the
## fallback when the model is missing – a test manifest without it (M2ZS1).
func test_procedural_bridge_pylon_stand_in_stays_dark_at_night() -> void:
	var manifest := _manifest_without_models(["props/bridge_pylon"])
	assert_true(manifest != "" and ModelDB.load_manifest(manifest), "Test-Manifest ohne das Pylon-Modell")
	var t := _pylon_track()
	var ctx := _ctx(t, 6)
	var b := Props.new()
	var part := b.build(ctx, b.collect(ctx))
	var groups: Dictionary = part["groups"]
	assert_eq(int((b.library.sets["props/bridge_pylon"] as Dictionary)["kind"]), PropLibrary.SPRITE, "Pylon ohne Modell: Sprite-Vertretung")
	assert_true(groups.has("d|props/bridge_pylon|0") and groups.has("d|props/bridge_pylon|1"), "Brückenpylone beider Seiten: dunkle Vertretung")
	assert_true(groups.has("s|props/bridge_pylon|0"), "derselbe Satz ohne prefer_proc: gewöhnliche Vertretung")
	var parent := Node3D.new()
	b.commit(ctx, part, parent)
	var dark := 0
	var plain := 0
	var standin_mat: Variant = b.library.standin("props/bridge_pylon").get("material")
	assert_true(standin_mat is ShaderMaterial, "die Vertretung des Pylons ist geladen")
	for c: Node in (parent.get_child(0).get_children() if parent.get_child_count() > 0 else []):
		var mmi := c as MultiMeshInstance3D
		if mmi == null or mmi.name == &"Contact" or not (mmi.material_override is ShaderMaterial):
			continue
		var mat := mmi.material_override as ShaderMaterial
		var lr: Vector4 = mat.get_shader_parameter("lights_rect")
		if lr.z == 0.0:
			dark += 1
			var hc: Vector3 = mat.get_shader_parameter("headlight_color")
			assert_eq(hc, Vector3.ZERO, "dunkler Pylon: kein Scheinwerferlicht auf dem 88-m-Billboard")
			assert_true(mat != standin_mat, "eigenes Material, das der Vertretung bleibt")
		else:
			plain += 1
	assert_eq(dark, 2, "zwei dunkle Pylon-Knoten (rechts und gespiegelt links)")
	assert_eq(plain, 1, "die gewöhnliche Vertretung behält ihre Lichtebene")
	if standin_mat is ShaderMaterial:
		var std: Vector4 = (standin_mat as ShaderMaterial).get_shader_parameter("lights_rect")
		assert_true(std.z > 0.0, "die Vertretung selbst hat die Lichtebene des Sprites weiter")
	parent.free()
	_cleanup()
	assert_true(ModelDB.load_manifest() and ModelDB.has_model("props/bridge_pylon"), "ausgeliefertes Manifest wieder geladen")


## QA-WASSER B1: a landmark that Arcade draws procedurally and that has neither a sprite nor a model (Belgrad,
## Hannover, Leipzig, Dortmund, Calais, Madrid) was dropped by Modern ("missing"); now the fallback set of its stage
## plan entry stands in, with fallback_scale and fallback_tint. Checked on every city of data/cities.json with such a
## landmark, on a real track that ends there.
func test_procedural_landmarks_without_sprite_or_model_get_their_fallback() -> void:
	var net := Fair.load_network()
	var db: Dictionary = net["city_db"]
	var lib := PropLibrary.new()
	var all_sets: Array = []
	var lm_sets: Dictionary = db.get("landmark_sets", {})
	for set_id: String in lm_sets:
		all_sets.append(set_id)
		var fb := str((lm_sets[set_id] as Dictionary).get("fallback", ""))
		if fb != "" and not all_sets.has(fb):
			all_sets.append(fb)
	for cid: String in (db.get("cities", {}) as Dictionary):
		for lm_v: Variant in ((db["cities"] as Dictionary)[cid] as Dictionary).get("landmarks", []):
			var placed := str((lm_v as Dictionary).get("set", ""))     # a city may place a set of the catalogue of props
			if placed != "" and not all_sets.has(placed):
				all_sets.append(placed)
	lib.request(all_sets, self)
	var guard := 0
	while lib.pending() > 0 and guard < 30000:
		OS.delay_msec(1)
		guard += 1
	# every landmark a city places is drawable in Modern: model, sprite or the fallback set of its catalogue entry
	var cities_of := {}            # procedural landmark without sprite or model -> city
	for cid: String in (db.get("cities", {}) as Dictionary):
		for lm_v: Variant in ((db["cities"] as Dictionary)[cid] as Dictionary).get("landmarks", []):
			var set_id := str((lm_v as Dictionary).get("set", ""))
			var kind := int((lib.sets.get(set_id, {"kind": PropLibrary.NONE}) as Dictionary)["kind"])
			if kind != PropLibrary.NONE:
				continue
			var entry := CityData.landmark_entry(db, set_id, lm_v)
			var fb := str(entry.get("fallback", ""))
			assert_true(entry.has("proc"), "%s (%s): ohne Sprite und Modell zeichnet Arcade es prozedural" % [set_id, cid])
			assert_true(fb != "" and int((lib.sets.get(fb, {"kind": PropLibrary.NONE}) as Dictionary)["kind"]) != PropLibrary.NONE,
				"%s (%s): Ersatz-Set %s ist in Modern Modell oder Vertretung" % [set_id, cid, fb])
			cities_of[set_id] = cid
	assert_true(cities_of.size() >= 6, "die sechs prozeduralen Wahrzeichen ohne Sprite und Modell gefunden (%s)" % str(cities_of))
	lib.clear(self)
	# on EVERY real track into each of those cities (M2ZS1: every approach, 20 in all; FIX-WASSER-R checked one per
	# city): the landmark's chunk draws the fallback set – as its sprite stand-in ("l|<set>|0", tinted with
	# fallback_tint) or, since AS4R gave props/church and props/building_tall a model, as that model ("m|<model>|0":
	# a model carries its own colours, no tint) – in both cases with fallback_scale, under the landmark law (the
	# group's "landmark" flag) and never mirrored
	var approaches := 0
	for set_id: String in cities_of:
		var cid := str(cities_of[set_id])
		var into := 0
		for dir: Dictionary in Fair.directions(net):
			var st: Dictionary = dir["stage"]
			var to_id := str(st["to"]) if str(dir["from"]) == str(st["from"]) else str(st["from"])
			if to_id != cid:
				continue
			var t := _real_track(str(st["id"]), str(dir["from"]), net)
			assert_true(t != null, "%s: Etappe %s" % [set_id, str(dir["name"])])
			if t == null:
				continue
			into += 1
			_check_landmark_fallback(t, set_id, "%s (%s, %s)" % [set_id, cid, str(dir["name"])])
		assert_true(into >= 1, "%s: mindestens eine Etappe nach %s" % [set_id, cid])
		approaches += into
	assert_true(approaches >= 20, "alle Anfahrten in die sechs Städte geprüft (%d)" % approaches)
	_cleanup()


## The chunk of landmark `set_id` on track t draws the fallback set of its stage-plan entry (see the test above).
func _check_landmark_fallback(t: Track, set_id: String, what: String) -> void:
	var fbs := Props.landmark_fallbacks(t)
	assert_true(fbs.has(set_id), "%s: der Etappenplan nennt das Ersatz-Set" % what)
	var lm: Dictionary = {}
	for l: Dictionary in t.landmarks:
		if str(l["set"]) == set_id:
			lm = l
	assert_false(lm.is_empty(), "%s: Wahrzeichen auf der Strecke" % what)
	if lm.is_empty() or not fbs.has(set_id):
		return
	assert_false(lm.has("fallback"), "%s: die Strecke streicht das Ersatz-Set (Arcade zeichnet prozedural)" % what)
	var k := int(floor(float(lm["z"]) / t.seg_len))
	var ctx := _ctx(t, k / 32)
	var b := Props.new()
	var part := b.build(ctx, b.collect(ctx))
	var fb := str(fbs[set_id])
	var found := false
	for e: Array in part["list"]:
		var it: Dictionary = t.get_segment(int(e[0])).sprites[int(e[1])]
		if bool(it.get("landmark", false)) and str(it["set"]) == set_id:
			found = true
			assert_eq(str(e[2]), fb, "%s: gezeichnet als %s" % [what, fb])
			assert_near(float(e[5]), float(it.get("scale", 1.0)) * float(it.get("fallback_scale", 1.0)), 1.0e-3,
				"%s: mit fallback_scale" % what)
	assert_true(found, "%s: das Wahrzeichen steht in seinem Stück" % what)
	var g: Dictionary = {}
	for key: String in part["groups"]:
		var gg: Dictionary = (part["groups"] as Dictionary)[key]
		if str(gg["set"]) == fb and bool(gg.get("landmark", false)):
			g = gg
	assert_false(g.is_empty(), "%s: als Wahrzeichen gezeichnet (Gesetz der Wahrzeichen)" % what)
	if g.is_empty():
		return
	assert_false(bool(g["mirror"]), "%s: nie gespiegelt" % what)
	var is_model := str(g["model"]) != ""
	assert_eq(is_model, ModelDB.has_model(fb), "%s: %s als %s" % [what, fb, "Modell" if is_model else "Vertretung"])
	if not is_model and lm.has("fallback_tint"):
		var buf: PackedFloat32Array = g["buf"]
		var want := Color(str(lm["fallback_tint"]))
		assert_near(buf[12], want.r, 0.01, "%s: Tönung aus fallback_tint (rot)" % what)
		assert_near(buf[14], want.b, 0.01, "%s: … (blau)" % what)


# --- five sceneries of real stages -------------------------------------------------------------------------------

func _real_track(stage_id: String, from_city: String, net: Dictionary) -> Track:
	for dir: Dictionary in Fair.directions(net, [stage_id]):
		if str(dir["from"]) == from_city:
			var plan := StagePlan.build(dir["stage"], from_city, net["cities"], net["countries"], cfg(), net["city_db"])
			var t := Track.new()
			t.setup(plan, cfg(), net["scenery"])
			return t
	return null


## What the builder must draw of segment `k`, from the track itself and the kernel's TerrainProfile (not from the
## chunk snapshot): [[item index, set id]] and the drops.
func _expected(t: Track, tp: TerrainProfile, lib: PropLibrary, k: int, dropped: Dictionary) -> Array:
	var out: Array = []
	var s := t.get_segment(k)
	for j in s.sprites.size():
		var it: Dictionary = s.sprites[j]
		var set_id := ""
		if str(it.get("kind", "prop")) == "prop":
			set_id = str(it.get("set", ""))
		elif str(it.get("kind", "")) == "object" and str(it.get("obj", "")) == "streetlight":
			set_id = "props/streetlight"
		if set_id == "":
			continue
		var e: Dictionary = lib.sets.get(set_id, {})
		var sc := float(it.get("scale", 1.0))
		if e.is_empty() or int(e["kind"]) == PropLibrary.NONE:
			var fb := str(it.get("fallback", ""))
			if fb == "" and bool(it.get("landmark", false)):
				fb = str(Props.landmark_fallbacks(t).get(set_id, ""))   # a procedural landmark: the plan's fallback
			e = lib.sets.get(fb, {})
			if e.is_empty() or int(e["kind"]) == PropLibrary.NONE:
				dropped["missing"] += 1
				continue
			sc *= float(it.get("fallback_scale", 1.0))
		var side := int(it.get("side", 1))
		var x := float(it.get("x", 0.0))
		var z := float(it.get("z", s.z))
		var is_model := int(e["kind"]) == PropLibrary.MODEL
		var flipped := side < 0 and not bool(it.get("landmark", false)) and (bool(e["mirror_left"]) or (not is_model and bool(it.get("mirror", false))))
		if it.has("fit_w"):
			sc = float(it["fit_w"]) / maxf(0.5, float(e["width"]))
		if it.has("align") and side != 0:
			x = RoadRenderer.edge_anchor_x(x, side, flipped, Vector2(float(e["extent_l"]), float(e["extent_r"])), sc)
		if side != 0:
			var f := clampf(z / t.seg_len - float(k), 0.0, 1.0)
			var beyond := absf(x) - tp.edge(k, side)
			if beyond > lerpf(tp.limit(k, side), tp.limit(k + 1, side), f) - Props.RIBBON_MARGIN_M:
				dropped["ribbon"] += 1
				continue
			var m := absf(x) - lerpf(tp.edge(k, side), tp.edge(k + 1, side), f)
			var corr := lerpf(tp.corridor_width(k, side), tp.corridor_width(k + 1, side), f)
			var in_bend := corr > tp.corridor_min_m - t.shoulder_w + 0.5 and m > 0.0 and m <= corr
			if in_bend and (not it.has("offset") or bool(e["veg"])) and not bool(it.get("landmark", false)):
				dropped["corridor"] += 1
				continue
		out.append([j, str(e["set"])])
	return out


func test_chunk_list_is_the_tracks_list_minus_the_documented_drops() -> void:
	var net := Fair.load_network()
	var sceneries := {}
	var total := 0
	var total_dropped := {"ribbon": 0, "corridor": 0, "missing": 0, "density": 0}
	for where: Array in [["kiel_hamburg", "kiel", 2.5], ["kiel_hamburg", "kiel", 84.0], ["kassel_wuerzburg", "kassel", 46.5],
			["saragossa_pau", "saragossa", 198.8], ["saragossa_pau", "saragossa", 40.0], ["dortmund_frankfurt", "dortmund", 121.0]]:
		var t := _real_track(str(where[0]), str(where[1]), net)
		assert_true(t != null, "Etappe %s" % where[0])
		if t == null:
			continue
		var cam_z := t.km_to_z(float(where[2]))
		var p := RoadPath3D.new()
		var tp := TerrainProfile.new()
		tp.setup(p, t, ConfigLoader.lookup(cfg(), "graphics.modern.terrain", {}), net["scenery"])
		var st := ChunkStreamer.new()
		st.setup(p, tp, t, cfg(), {}, true)
		var b := Props.new()
		st.register(b)
		st.update(cam_z, 900.0)
		var snap := st.snapshot()
		assert_true((snap["chunks"] as Array).size() >= 8, "%s km %.0f: Stücke geladen (%d)" % [where[0], where[2], (snap["chunks"] as Array).size()])
		for ch: Dictionary in snap["chunks"]:
			var part: Dictionary = ch["parts"]["props"]
			var got := {}
			for e: Array in part.get("list", []):
				got["%d/%d" % [int(e[0]), int(e[1])]] = str(e[2])
			var want := {}
			var dropped := {"ribbon": 0, "corridor": 0, "missing": 0, "density": 0}
			for k in range(int(ch["seg_a"]), int(ch["seg_b"])):
				sceneries[t.get_segment(k).scenery] = true
				for e: Array in _expected(t, tp, b.library, k, dropped):
					want["%d/%d" % [k, int(e[0])]] = str(e[1])
			assert_eq(got, want, "%s km %.0f, Stück %d: Requisitenliste = Streckenliste minus Auslassungen" % [where[0], where[2], int(ch["index"])])
			assert_eq(part.get("dropped", dropped), dropped, "%s km %.0f, Stück %d: Auslassungen nach Grund" % [where[0], where[2], int(ch["index"])])
			total += got.size()
			for key: String in dropped:
				total_dropped[key] += int(dropped[key])
		st.clear()
		st.free()
	assert_true(sceneries.size() >= 5, "mindestens fünf Landschaften geprüft (%s)" % str(sceneries.keys()))
	assert_true(total > 300, "Requisiten verglichen (%d)" % total)
	assert_true(int(total_dropped["corridor"]) > 0, "an einer der Stellen liegt ein Kurvenkorridor (%s)" % str(total_dropped))
	_cleanup()


## R7c (A-22, lead decision 1): the distance bands of the levels – per model from its max_dist_m (or the override of
## graphics.modern.props.lod0_m) scaled with Details, complementary at every level boundary, a model of one level always
## shown, a building's last level endless.
func test_lod_bands_per_model() -> void:
	var fade := Props.LOD_FADE
	var ref := Vector2(Props.LOD_REF_M, Props.LOD1_REF_M)
	var tree := Props.lod_bands(["lod0", "lod1", PropLibrary.IMPOSTOR], Vector2(60.0, 200.0), 60.0, 200.0, ref, 0.0, fade)
	assert_eq((tree as Dictionary).size(), 3, "Baum: drei Darstellungen")
	var t0: Vector4 = tree["lod0"]
	var t1: Vector4 = tree["lod1"]
	var ti: Vector4 = tree[PropLibrary.IMPOSTOR]
	assert_true(t0.x < 0.0 and t0.y < 0.0, "lod0 von Anfang an sichtbar")
	assert_near((t0.z + t0.w) * 0.5, 60.0, 1.0e-3, "lod0 endet bei 60 m (Mittel)")
	assert_near(t0.w - t0.z, 2.0 * 7.2, 1.0e-3, "Band ±12 % = ±7,2 m")
	assert_near(t1.x, t0.z, 1.0e-4, "lod1 beginnt, wo lod0 ausblendet")
	assert_near((t1.z + t1.w) * 0.5, 200.0, 1.0e-3, "lod1 endet bei 200 m")
	assert_near(ti.x, t1.z, 1.0e-4, "Fernbild beginnt, wo lod1 ausblendet")
	assert_true(ti.w >= Props.LOD_ENDLESS, "Fernbild bis ans Ende")
	# Details "Hoch": twice the distances
	var hi := Props.lod_bands(["lod0", "lod1", PropLibrary.IMPOSTOR], Vector2(60.0, 200.0), 120.0, 350.0, ref, 0.0, fade)
	assert_near(((hi["lod0"] as Vector4).z + (hi["lod0"] as Vector4).w) * 0.5, 120.0, 1.0e-3, "Hoch: lod0 bis 120 m")
	# a building: lod1 is its last level (reps lod0, lod1, lod1), endless
	var house := Props.lod_bands(["lod0", "lod1", "lod1"], Vector2(60.0, 0.0), 60.0, 200.0, ref, 0.0, fade)
	assert_eq((house as Dictionary).size(), 2, "Haus: zwei Darstellungen")
	assert_true((house["lod1"] as Vector4).w >= Props.LOD_ENDLESS, "lod1 eines Hauses bis ans Ende")
	# the half-timbered house: lod0 at 35 m on "Mittel" (override), 70 m on "Hoch", 23.3 m on "Niedrig"
	for row: Array in [[60.0, 35.0], [120.0, 70.0], [40.0, 23.333]]:
		var fw := Props.lod_bands(["lod0", "lod1", "lod1"], Vector2(60.0, 0.0), float(row[0]), 200.0, ref, 35.0, fade)
		var f0: Vector4 = fw["lod0"]
		assert_near((f0.z + f0.w) * 0.5, float(row[1]), 1.0e-2, "Fachwerk: lod0 bis %.1f m bei prop_lod0_m %.0f" % [row[1], row[0]])
		assert_true(f0.w - f0.z >= 2.0 * fade.y - 1.0e-4, "Band mindestens ±%.0f m" % fade.y)
	# one level: always
	var one := Props.lod_bands(["lod0", "lod0", "lod0"], Vector2.ZERO, 60.0, 200.0, ref, 0.0, fade)
	assert_eq((one as Dictionary).size(), 1, "eine Stufe: eine Darstellung")
	assert_true((one["lod0"] as Vector4).x < 0.0 and (one["lod0"] as Vector4).w >= Props.LOD_ENDLESS, "eine Stufe: immer sichtbar")
	# the configured override reaches the builder
	var b := Props.new()
	b._read_config(cfg())
	b.apply_quality({"prop_lod0_m": 60.0, "prop_lod1_m": 200.0})
	# measured shimmer (lead decision 3): lod0 of the half-timbered and the Paris houses ends at 30 m on "Mittel" (their
	# beams, railings and frames flicker 1–1.4 % in lod0 at 40–60 m, the sprite 0–0.3 %). FIX-R7c (QR7c-01): the other city
	# houses keep their own max_dist_m (60 m on "Mittel") – the Speicher's lod1 has flat doors, the level of the sprite
	assert_near(b.lod0_override("props/city_german_old_fachwerk"), 30.0, 1.0e-4, "Konfiguration: Fachwerk lod0 30 m")
	for mid: String in ["props/city_german_old_fachwerk_b", "props/city_paris_haussmann", "props/city_paris_corner"]:
		assert_near(b.lod0_override(mid), 30.0, 1.0e-4, "Konfiguration: %s lod0 30 m" % mid.get_file())
	for mid: String in ["props/city_dutch_canal", "props/city_hanse_speicher", "props/city_hanse_kontor", "props/city_german_gruenderzeit"]:
		assert_near(b.lod0_override(mid), 0.0, 1.0e-4, "%s: kein Ersatz, eigenes max_dist_m (QR7c-01)" % mid.get_file())
	assert_near(b.lod0_override("props/farmhouse"), 0.0, 1.0e-4, "Bauernhaus: kein Ersatz (eigenes max_dist_m)")


## R7c: the static vpbr variant carries the level band, the far light and the rotor phase (static_code() patches the
## source of vpbr.gdshader – a changed line there would silently drop a patch: every marker must be in the result);
## every level of a static model has materials of its own, vehicles share theirs.
func test_static_materials_per_mesh_and_injection() -> void:
	var mats := ModernMaterials.shared()
	var code := ModernMaterials.static_code(mats.shader("vpbr").code)
	for marker: String in ModernMaterials.STATIC_MARKERS:
		assert_true(code.contains(marker), "vpbr_static enthält „%s“" % marker)
	for cls: String in ["baked", "leaves", "billboard"]:
		var c := mats.shader(cls).code
		assert_true(c.contains("inc/lod_band.gdshaderinc") and c.contains("ce_lod_discard(v_lod_d"), "%s blendet die Stufen über" % cls)
	var m0 := ModelFactory.multimesh_parts("props/tree_oak", "lod0", mats)
	var m1 := ModelFactory.multimesh_parts("props/tree_oak", "lod1", mats)
	assert_true(not m0.is_empty() and not m1.is_empty(), "Eiche lod0 und lod1 geladen")
	if not m0.is_empty() and not m1.is_empty():
		var a := ((m0[0] as Dictionary)["mesh"] as Mesh).surface_get_material(0)
		var c := ((m1[0] as Dictionary)["mesh"] as Mesh).surface_get_material(0)
		assert_true(a != null and c != null and a != c, "lod0 und lod1 der Eiche haben eigene Materialien")
	var v0 := ModelFactory.multimesh_parts("traffic/sedan_red", "lod1", mats)
	var v1 := ModelFactory.multimesh_parts("traffic/sedan_red", "lod2", mats)
	if not v0.is_empty() and not v1.is_empty():
		assert_eq(((v0[0] as Dictionary)["mesh"] as Mesh).surface_get_material(0), ((v1[0] as Dictionary)["mesh"] as Mesh).surface_get_material(0),
			"Fahrzeuge teilen ihr vpbr-Material")
	_cleanup()


## R7c (A-16): the phase of rotors and sway comes from the instance data (stable per item), not from the origin-relative
## position, which jumps at every rebase; cliffs turn at most ±20° away from the road (face_road); rocks stand on the
## lowest point of their footprint (ground_sink).
func test_instance_phase_and_tags() -> void:
	var t := _track()
	_put(t, 198, {"kind": "prop", "set": "props/wind_turbine", "side": 1, "x": _x(t, 1, 40.0), "scale": 1.0})
	for k in 6:
		_put(t, 200 + k * 2, {"kind": "prop", "set": "props/cliff", "side": 1 if k % 2 == 0 else -1, "x": _x(t, 1 if k % 2 == 0 else -1, 25.0), "scale": 1.0})
	var ctx := _ctx(t, 6)
	var b := Props.new()
	var part := b.build(ctx, b.collect(ctx))
	var g: Dictionary = (part["groups"] as Dictionary).get("m|props/wind_turbine|0", {})
	var buf: PackedFloat32Array = g.get("buf", PackedFloat32Array())
	assert_eq(buf.size(), Props.INSTANCE_FLOATS, "ein Windrad")
	if buf.size() == Props.INSTANCE_FLOATS:
		assert_near(buf[19] - 1.0, Props.instance_phase(198, 0), 1.0e-5, "Phase des Windrads aus Segment und Nummer")
	# the same item seen from a chunk context with another floating origin: the same phase
	var p2 := RoadPath3D.new()
	p2.setup(t, 0, float(ConfigLoader.lookup(cfg(), "road.curve_radius_at_1_m", 120.0)))
	p2.set_clear_reach(1842.0)
	p2.ensure(900)
	p2.rebase(150)
	var tp2 := TerrainProfile.new()
	tp2.setup(p2, t, ConfigLoader.lookup(cfg(), "graphics.modern.terrain", {}), {})
	var ctx2 := ChunkContext.new()
	ctx2.cfg = cfg()
	ctx2.capture(6, 192, 224, p2, tp2, t)
	var part2 := b.build(ctx2, b.collect(ctx2))
	var g2: Dictionary = (part2["groups"] as Dictionary).get("m|props/wind_turbine|0", {})
	var buf2: PackedFloat32Array = g2.get("buf", PackedFloat32Array())
	assert_eq(buf2.size(), Props.INSTANCE_FLOATS, "dasselbe Windrad nach dem Verschieben des Ursprungs")
	if buf.size() == Props.INSTANCE_FLOATS and buf2.size() == Props.INSTANCE_FLOATS:
		assert_near(buf2[19], buf[19], 1.0e-6, "nach dem Verschieben des Ursprungs dieselbe Phase")
	# face_road: every cliff within ±20° of facing the road (its local -Z along the road forward)
	var lib := b.library
	assert_true(bool((lib.sets["props/cliff"] as Dictionary).get("face_road", false)), "Klippe trägt face_road")
	assert_true(bool((lib.sets["props/cliff"] as Dictionary).get("ground_sink", false)), "Klippe trägt ground_sink")
	var n := 0
	for key: String in part["groups"]:
		var gg: Dictionary = (part["groups"] as Dictionary)[key]
		if str(gg["set"]) != "props/cliff":
			continue
		for tr: Transform3D in _transforms(gg["buf"], Props.INSTANCE_FLOATS):
			var fwd: Vector3 = ctx.rows_f[ctx.row_count() / 2]
			var mz := -tr.basis.z.normalized()
			var ang := rad_to_deg(acos(clampf(Vector3(mz.x, 0.0, mz.z).normalized().dot(Vector3(fwd.x, 0.0, fwd.z).normalized()), -1.0, 1.0)))
			assert_true(ang <= Props.FACE_ROAD_DEG + 1.5, "Klippe höchstens 20° aus der Straßenrichtung gedreht (%.1f°)" % ang)
			n += 1
	assert_eq(n, 6, "sechs Klippen geprüft")
	# ground_sink: never above the ground at its anchor
	var h0 := ctx.ground(600.0, 30.0)
	assert_true(Props.sink_height(ctx, 600.0, 30.0, 6.0, h0) <= h0 + 1.0e-5, "abgesenkt höchstens auf den Boden am Anker")
	_cleanup()


## R7c (lead decision 6): a model may name props to place with itself ("attach" in model.json); props.gd places them as
## ordinary instances of their own sets (own level of detail), mirrored with the model on the left roadside. Built and
## tested with a test manifest (no shipped model uses it yet).
func test_model_attachments() -> void:
	var src: Variant = JSON.parse_string(FileAccess.get_file_as_string(ModelDB.ROOT + ModelDB.MANIFEST))
	assert_true(src is Dictionary, "Manifest gelesen")
	if not src is Dictionary:
		return
	var m: Dictionary = src
	m["root"] = ModelDB.ROOT
	(m["models"]["props/farmhouse"] as Dictionary)["attach"] = [{"prop": "props/tree_oak", "offset": [4.0, 0.0, -6.0], "scale": 0.8},
		{"prop": "props/bush_round", "offset": [-3.0, 0.0, -2.0]}]
	var path := "user://test_props_manifest_attach.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(m))
	f.close()
	ModelDB.release_all()
	ModernMaterials.drop_shared()
	assert_true(ModelDB.load_manifest(path), "Test-Manifest mit Anbauten geladen")
	var t := _track()
	var x := _x(t, 1, 40.0)
	_put(t, 196, {"kind": "prop", "set": "props/farmhouse", "side": 1, "x": x, "scale": 1.0})
	_put(t, 206, {"kind": "prop", "set": "props/farmhouse", "side": -1, "x": -x, "scale": 1.0})
	var ctx := _ctx(t, 6)
	var b := Props.new()
	var part := b.build(ctx, b.collect(ctx))
	var att: Array = part.get("attach_list", [])
	assert_eq(att.size(), 4, "zwei Häuser × zwei Anbauten (%s)" % str(att))
	var found_right := false
	var found_left := false
	for e: Array in att:
		if str(e[2]) == "props/tree_oak" and absf(float(e[4]) - (196.0 * 3.0 + 1.0 + 6.0)) < 0.01:
			found_right = absf(float(e[3]) - (x + 4.0)) < 0.01 and absf(float(e[5]) - 0.8) < 1.0e-4
		if str(e[2]) == "props/tree_oak" and absf(float(e[4]) - (206.0 * 3.0 + 1.0 + 6.0)) < 0.01:
			found_left = absf(float(e[3]) - (-x - 4.0)) < 0.01
	assert_true(found_right, "Eiche 4 m rechts und 6 m hinter dem Haus, Maßstab 0,8")
	assert_true(found_left, "links gespiegelt: 4 m weiter von der Straße weg")
	assert_eq(int((part["counts"] as Dictionary).get("props/tree_oak", 0)), 2, "die Eichen als Instanzen ihres Sets gezählt")
	var groups: Dictionary = part["groups"]
	var oak_groups := 0
	for key: String in groups:
		if str((groups[key] as Dictionary)["set"]) == "props/tree_oak":
			oak_groups += 1
	assert_true(oak_groups >= 1, "eigene Gruppe der Eiche (eigene Detailstufen)")
	assert_eq((part["list"] as Array).size(), 2, "die Streckenliste bleibt die der Strecke (zwei Häuser)")
	ModelDB.release_all()
	ModernMaterials.drop_shared()
	assert_true(ModelDB.load_manifest() and not ModelDB.model("props/farmhouse").has("attach"), "ausgeliefertes Manifest wieder geladen")
	_cleanup()


## R7c: the slowness watchdog lowers the preset during the countdown – the bands on the materials AND on the level
## nodes already committed follow at once (a node keeping its old band would hide instances the shader shows).
func test_quality_lowered_moves_the_bands() -> void:
	var t := _track()
	_put(t, 198, {"kind": "prop", "set": "props/tree_oak", "side": 1, "x": _x(t, 1, 12.0), "scale": 1.0})
	var ctx := _ctx(t, 6)
	var b := Props.new()
	b.apply_quality({"prop_lod0_m": 60.0, "prop_lod1_m": 200.0, "shadow_casters": 2, "shadow_distance_m": 120.0, "deco_density": 1.0})
	var parent := Node3D.new()
	b.commit(ctx, b.build(ctx, b.collect(ctx)), parent)
	b.quality_lowered({"prop_lod0_m": 40.0, "prop_lod1_m": 120.0, "shadow_casters": 0, "shadow_distance_m": 0.0, "deco_density": 0.6})
	var want: Dictionary = b.model_bands("props/tree_oak")
	assert_near(((want["lod0"] as Vector4).z + (want["lod0"] as Vector4).w) * 0.5, 40.0, 1.0e-3, "neues Band: lod0 bis 40 m")
	var seen := 0
	for c: Node in parent.get_child(0).get_children():
		if c.has_meta(&"band") and str(c.get_meta(&"model", "")) == "props/tree_oak":
			assert_eq(c.get_meta(&"band"), want[str(c.get_meta(&"rep"))], "Knoten %s mit dem neuen Band" % str(c.get_meta(&"rep")))
			seen += 1
	assert_eq(seen, 3, "drei Stufenknoten der Eiche")
	for mat: ShaderMaterial in b.library.rep_materials("props/tree_oak", "lod0"):
		assert_eq(mat.get_shader_parameter("lod_band"), want["lod0"], "Material von lod0 mit dem neuen Band")
		assert_eq(mat.get_shader_parameter("shadow_far"), Vector2.ZERO, "ohne Schattenwerfer kein Fernlicht")
	parent.free()
	_cleanup()


# --- FIX-R7c: guards of the R7c rules (QA-R7c QR7c-02: 11 of 17 one-line mutations stayed green) -----------------

## Shader code without its comments (// to the end of the line, /* … */) – a rule a comment only mentions does not count.
## (Named apart from FIX-RINT's _code_only(), which the assembly brings into this file.)
static func _shader_code(code: String) -> String:
	var rx := RegEx.create_from_string("/\\*[\\s\\S]*?\\*/|//[^\\n]*")
	return rx.sub(code, "", true)


## QR7c-02 (a, U7): the far light of the configuration reaches the materials of a building that casts – the class value
## (building 0.78) and a model's own value (Haussmann 0.72) – with the shadow reach of the level (fade from 85 %); a
## building that does not cast at the shadow level keeps the full sun.
func test_far_light_reaches_the_materials() -> void:
	var t := _track()
	_put(t, 196, {"kind": "prop", "set": "props/farmhouse", "side": 1, "x": _x(t, 1, 40.0), "scale": 1.0})
	_put(t, 204, {"kind": "prop", "set": "props/city_paris_haussmann", "side": 1, "x": _x(t, 1, 12.0), "scale": 1.0})
	var ctx := _ctx(t, 6)
	var b := Props.new()
	b._read_config(cfg())
	b.apply_quality({"prop_lod0_m": 60.0, "prop_lod1_m": 200.0, "shadow_casters": 2, "shadow_distance_m": 120.0, "deco_density": 1.0})
	var parent := Node3D.new()
	b.commit(ctx, b.build(ctx, b.collect(ctx)), parent)
	var fs: Dictionary = ConfigLoader.lookup(cfg(), "graphics.modern.props.far_sun", {})
	assert_true(float(fs.get("building", 1.0)) < 0.99, "Konfiguration: Fernlicht der Gebäude (%s)" % str(fs.get("building")))
	var want := {"props/farmhouse": float(fs.get("props/farmhouse", fs.get("building", 1.0))),
		"props/city_paris_haussmann": float(fs.get("props/city_paris_haussmann", fs.get("building", 1.0)))}
	assert_true(absf(float(want["props/city_paris_haussmann"]) - float(want["props/farmhouse"])) > 0.01, "Haussmann hat einen eigenen Wert")
	for sid: String in want:
		var mid := ""
		for v: Variant in (b.library.sets[sid] as Dictionary).get("variants", []):
			mid = str(v)
		var n := 0
		for rep: String in b.model_bands(mid):
			for mat: ShaderMaterial in b.library.rep_materials(mid, rep):
				assert_near(float(mat.get_shader_parameter("far_sun")), float(want[sid]), 1.0e-4, "%s %s: far_sun aus der Konfiguration" % [sid.get_file(), rep])
				assert_eq(mat.get_shader_parameter("shadow_far"), Vector2(102.0, 120.0), "%s %s: Fernlicht ab 85 %% der Schattenreichweite" % [sid.get_file(), rep])
				n += 1
		assert_true(n >= 2, "%s: Materialien beider Stufen geprüft (%d)" % [sid.get_file(), n])
	parent.free()
	# "Schatten: Niedrig" (casters 1): buildings do not cast – full sun, no far light
	var b2 := Props.new()
	b2._read_config(cfg())
	b2.apply_quality({"prop_lod0_m": 60.0, "prop_lod1_m": 200.0, "shadow_casters": 1, "shadow_distance_m": 80.0, "deco_density": 1.0})
	var parent2 := Node3D.new()
	b2.commit(ctx, b2.build(ctx, b2.collect(ctx)), parent2)
	for mat: ShaderMaterial in b2.library.rep_materials(str((b2.library.sets["props/farmhouse"] as Dictionary)["variants"][0]), "lod1"):
		assert_near(float(mat.get_shader_parameter("far_sun")), 1.0, 1.0e-6, "ohne Schattenwurf: volle Sonne")
		assert_eq(mat.get_shader_parameter("shadow_far"), Vector2.ZERO, "ohne Schattenwurf: kein Fernlicht")
	parent2.free()
	_cleanup()


## QR7c-02 (b, R3/R4/R5/R6/U8 and QR7c-06): the rules of R7c in the shader code itself, comments stripped – the far
## light lowers the directional light to far_sun, the cut-out tests a coarser mip, a lit window replaces the facade
## colour, the impostor's relief goes with the night, the sway phase comes from the instance data, a standing camera
## narrows the band.
func test_shader_rules_of_the_far_lod() -> void:
	var mats := ModernMaterials.shared()
	var band := _shader_code(FileAccess.get_file_as_string("res://assets/shaders/modern/inc/lod_band.gdshaderinc"))
	var rx_far := RegEx.create_from_string("float\\s+ce_far_attenuation\\s*\\([^)]*\\)\\s*\\{\\s*if\\s*\\([^)]*\\)\\s*\\{\\s*return\\s+att;\\s*\\}\\s*return\\s+mix\\(\\s*att\\s*,\\s*min\\(\\s*att\\s*,\\s*far_sun\\s*\\)\\s*,\\s*smoothstep\\(\\s*shadow_far\\.x\\s*,\\s*shadow_far\\.y\\s*,\\s*depth\\s*\\)\\s*\\)\\s*;\\s*\\}")
	assert_true(rx_far.search(band) != null, "Fernlicht: gerichtetes Licht jenseits der Schatten auf far_sun (ce_far_attenuation)")
	assert_true(band.contains("global uniform float ce_lod_still;") and band.contains("float still = clamp(ce_lod_still, 0.0, 1.0);") and band.contains("b = vec4(b.y - w.x, b.y, b.w - w.y, b.w);"),
		"stehende Kamera: das Band zieht sich zusammen (ce_lod_still)")
	var baked := _shader_code(mats.shader("baked").code)
	assert_true(baked.contains("float att = ce_far_attenuation(ATTENUATION, LIGHT_IS_DIRECTIONAL, v_lod_depth);"), "baked: light() nimmt das Fernlicht")
	assert_true(baked.contains("DIFFUSE_LIGHT += LIGHT_COLOR * att * ndl"), "baked: diffuses Licht mit dem Fernlicht")
	assert_true(baked.contains("texture(albedo_tex, UV, cutout_bias).a < 0.5"), "baked_cutout: Alphatest aus der gröberen Mip (cutout_bias)")
	assert_true(baked.contains("float cover_k = window_cover *") and baked.contains("alb * (1.0 - cover_k)"),
		"baked: ein leuchtendes Fenster ersetzt die Fassadenfarbe (window_cover)")
	assert_true(baked.contains("albedo_bias * smoothstep(albedo_bias_m.x, albedo_bias_m.y, dist)"), "baked: Farb-Mip-Bias mit der Entfernung")
	var board := _shader_code(mats.shader("billboard").code)
	assert_true(board.contains("t.rgb = mix(t.rgb, mean, relief_night * clamp(ce_night, 0.0, 1.0));"), "Fernbild: Relief nachts zurückgenommen")
	var leaves := _shader_code(mats.shader("leaves").code)
	assert_true(leaves.contains("INSTANCE_CUSTOM.a > 0.5 ? fract(INSTANCE_CUSTOM.a) * 37.0"), "Laub: Wiegen aus der Phase der Instanz")
	assert_false(RegEx.create_from_string("float\\s+tree\\s*=\\s*wp\\.").search(leaves) != null, "Laub: keine Phase allein aus der Weltlage")
	assert_true(leaves.contains("ce_far_attenuation("), "Laub: Fernlicht")
	_cleanup()


## QR7c-02 (c, U3): the phase differs from item to item (rotors and crowns do not turn and sway in step) and stays in
## [0, 1) – custom a = 1 + phase < 2.
func test_instance_phases_differ() -> void:
	var seen := {}
	for seg in [198, 199, 640, 5123]:
		for item in 4:
			var p := Props.instance_phase(seg, item)
			assert_between(p, 0.0, 0.999, "Phase in [0, 1)")
			seen[snappedf(p, 0.001)] = true
	assert_true(seen.size() >= 14, "16 Gegenstände, (fast) alle mit eigener Phase (%d verschiedene)" % seen.size())
	var t := _track()
	_put(t, 198, {"kind": "prop", "set": "props/wind_turbine", "side": 1, "x": _x(t, 1, 40.0), "scale": 1.0})
	_put(t, 205, {"kind": "prop", "set": "props/wind_turbine", "side": 1, "x": _x(t, 1, 60.0), "scale": 1.0})
	var ctx := _ctx(t, 6)
	var b := Props.new()
	var part := b.build(ctx, b.collect(ctx))
	var buf: PackedFloat32Array = ((part["groups"] as Dictionary).get("m|props/wind_turbine|0", {}) as Dictionary).get("buf", PackedFloat32Array())
	assert_eq(buf.size(), 2 * Props.INSTANCE_FLOATS, "zwei Windräder in einer Gruppe")
	if buf.size() == 2 * Props.INSTANCE_FLOATS:
		assert_true(absf(buf[19] - buf[Props.INSTANCE_FLOATS + 19]) > 0.01, "zwei Windräder drehen nicht im Gleichschritt (%.3f / %.3f)" % [buf[19], buf[Props.INSTANCE_FLOATS + 19]])
	_cleanup()


## A spot of the synthetic track whose ground falls by at least `drop` metres within `r` of it (right roadside, chunk ci):
## Vector3(z, x, the lowest ground of the circle) – (0, 0, 0) when there is none.
func _slope_spot(ctx: ChunkContext, r: float, drop: float) -> Vector3:
	for row in range(2, ctx.row_count() - 3):
		var z := (float(ctx.seg_a) + float(row) + 0.5) * ctx.seg_len
		for k in 40:
			var x := ctx.shoulder_edge(row, 1) + 2.0 + float(k) * 1.5
			if absf(x) - ctx.shoulder_edge(row, 1) > ctx.ribbon_width(z, 1) - 4.0:
				break
			var h0 := ctx.ground(z, x)
			var low := h0
			for q in 8:
				var a := float(q) * TAU / 8.0
				low = minf(low, ctx.ground(z + cos(a) * r, x + sin(a) * r))
			if h0 - low >= drop:
				return Vector3(z, x, low)
	return Vector3.ZERO


## QR7c-02 (d, U4/U5): on a slope a rock stands on the lowest ground point of its footprint (ground_sink: a concrete
## height below the ground at its anchor) and heather leans with the ground (ground_align: tilted, at most 30°).
func test_ground_sink_and_align_on_a_slope() -> void:
	var t := _track()
	var ctx := _ctx(t, 6)
	var lib := PropLibrary.new()
	lib.request(["props/rock_a", "props/heather"], self)
	var guard := 0
	while lib.pending() > 0 and guard < 20000:
		OS.delay_msec(1)
		guard += 1
	var rock: Dictionary = lib.sets.get("props/rock_a", {})
	assert_true(bool(rock.get("ground_sink", false)), "Fels trägt ground_sink")
	assert_true(bool((lib.sets.get("props/heather", {}) as Dictionary).get("ground_align", false)), "Heide trägt ground_align")
	var r := 0.5 * maxf(float(rock.get("width", 1.0)), float(rock.get("length", rock.get("width", 1.0))))
	var spot := Vector3.ZERO
	var ci := 6
	for c in [6, 2, 10, 14, 20, 26, 30]:
		ctx = _ctx(t, c)
		spot = _slope_spot(ctx, r, 0.05)
		if spot != Vector3.ZERO:
			ci = c
			break
	assert_true(spot != Vector3.ZERO, "ein Hang neben der Straße gefunden (Boden fällt um ≥ 5 cm im Umkreis %.2f m)" % r)
	if spot == Vector3.ZERO:
		lib.clear(self)
		_cleanup()
		return
	var h0 := ctx.ground(spot.x, spot.y)
	assert_near(Props.sink_height(ctx, spot.x, spot.y, r, h0), spot.z, 1.0e-4, "sink_height = tiefster Punkt des Umkreises")
	assert_true(spot.z < h0 - 0.04, "tiefer als der Boden am Anker (%.3f < %.3f)" % [spot.z, h0])
	# the builder places them so (seg_index from the spot; the item at the spot's z)
	var seg := int(floor(spot.x / t.seg_len))
	_put(t, seg, {"kind": "prop", "set": "props/rock_a", "side": 1, "x": spot.y, "scale": 1.0, "dz": spot.x - float(seg) * t.seg_len})
	_put(t, seg, {"kind": "prop", "set": "props/heather", "side": 1, "x": spot.y, "scale": 1.0, "dz": spot.x - float(seg) * t.seg_len})
	ctx = _ctx(t, ci)
	var b := Props.new()
	var part := b.build(ctx, b.collect(ctx))
	var rock_y := INF
	var heather_up := Vector3.ZERO
	for key: String in part["groups"]:
		var g: Dictionary = (part["groups"] as Dictionary)[key]
		for tr: Transform3D in _transforms(g["buf"], Props.INSTANCE_FLOATS):
			if str(g["set"]) == "props/rock_a":
				rock_y = tr.origin.y
			elif str(g["set"]) == "props/heather":
				heather_up = tr.basis.y.normalized()
	assert_near(rock_y, ctx.local(spot.x, spot.y, spot.z).y, 1.0e-3, "Fels steht auf dem tiefsten Punkt seines Fußes")
	var n := (ctx.local(spot.x, spot.y + Props.SLOPE_PROBE_M, ctx.ground(spot.x, spot.y + Props.SLOPE_PROBE_M)) - ctx.local(spot.x, spot.y, h0)).cross(
		ctx.local(spot.x + Props.SLOPE_PROBE_M, spot.y, ctx.ground(spot.x + Props.SLOPE_PROBE_M, spot.y)) - ctx.local(spot.x, spot.y, h0)).normalized()
	if n.y < 0.0:
		n = -n
	var tilt := rad_to_deg(heather_up.angle_to(Vector3.UP))
	assert_true(tilt > 0.5 and tilt <= Props.ALIGN_MAX_DEG + 0.1, "Heide zum Hang geneigt (%.1f°)" % tilt)
	assert_true(heather_up.angle_to(n) < Vector3.UP.angle_to(n), "… zur Geländenormalen hin")
	lib.clear(self)
	_cleanup()


## QR7c-02 (e, U10, F7) and QR7c-08: an attached tree inside the sight corridor of a bend is left out like any tree (the
## house, placed by an event, stays); an attachment that would stand beyond the chunk is not placed by it (its ground and
## corridor would be those of the edge row); at most ATTACH_MAX attachments per model.
func test_attachments_respect_the_corridor_and_the_chunk() -> void:
	var src: Variant = JSON.parse_string(FileAccess.get_file_as_string(ModelDB.ROOT + ModelDB.MANIFEST))
	if not src is Dictionary:
		assert_true(false, "Manifest gelesen")
		return
	var m: Dictionary = src
	m["root"] = ModelDB.ROOT
	(m["models"]["props/farmhouse"] as Dictionary)["attach"] = [{"prop": "props/tree_oak", "offset": [4.0, 0.0, -6.0], "scale": 0.8}]
	var path := "user://test_props_manifest_attach2.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(m))
	f.close()
	ModelDB.release_all()
	ModernMaterials.drop_shared()
	assert_true(ModelDB.load_manifest(path), "Test-Manifest mit Anbau geladen")
	var t := _track()
	# a spot inside a bend corridor on the right (inside of the right bend), whatever the corridor's law
	var spot := Vector2.ZERO
	var ci := -1
	for c in range(12, 22):
		var ctx0 := _ctx(t, c)
		for row in range(3, 20):
			var z := (float(ctx0.seg_a) + float(row) + 0.5) * ctx0.seg_len
			for k in 30:
				var x := ctx0.shoulder_edge(row, 1) + 3.0 + float(k)
				if ctx0.in_bend_corridor(z, x) and ctx0.in_bend_corridor(z, x + 2.0) and ctx0.in_bend_corridor(z - 3.0, x):
					spot = Vector2(z, x)
					ci = c
					break
			if ci >= 0:
				break
		if ci >= 0:
			break
	assert_true(ci >= 0, "ein Kurvenkorridor rechts gefunden")
	if ci < 0:
		_cleanup()
		return
	# the house 6 m before and 4 m left of the spot, "offset": placed by an event, it stays in the corridor
	var hz := spot.x - 6.0
	var seg := int(floor(hz / t.seg_len))
	_put(t, seg, {"kind": "prop", "set": "props/farmhouse", "side": 1, "x": spot.y - 4.0, "scale": 1.0, "offset": spot.y - 4.0,
		"dz": hz - float(seg) * t.seg_len})
	# a second house on the straight, 2 m before the end of chunk 30: its tree (6 m on) would stand in chunk 31
	var zc := float(31 * 32) * t.seg_len - 2.0
	var seg2 := int(floor(zc / t.seg_len))
	_put(t, seg2, {"kind": "prop", "set": "props/farmhouse", "side": 1, "x": _x(t, 1, 40.0), "scale": 1.0, "dz": zc - float(seg2) * t.seg_len})
	var ctx := _ctx(t, ci)
	var b := Props.new()
	var part := b.build(ctx, b.collect(ctx))
	assert_eq((part["list"] as Array).size(), 1, "das Haus steht (Ereignis, kein Schmuck)")
	assert_eq((part["attach_list"] as Array).size(), 0, "die angebaute Eiche im Kurvenkorridor fehlt (%s)" % str(part["attach_list"]))
	assert_true(int((part["dropped"] as Dictionary)["corridor"]) >= 1, "als Kurvenkorridor gezählt")
	var ctx2 := _ctx(t, 30)
	var part2 := b.build(ctx2, b.collect(ctx2))
	assert_eq((part2["list"] as Array).size(), 1, "Haus am Ende des Stücks")
	assert_eq((part2["attach_list"] as Array).size(), 0, "sein Anbau jenseits des Stücks wird hier nicht gestellt")
	ModelDB.release_all()
	ModernMaterials.drop_shared()
	assert_true(ModelDB.load_manifest(), "ausgeliefertes Manifest wieder geladen")
	_cleanup()


## QR7c-06: the standing camera – ce_lod_still goes to 1 within LOD_STILL_S below LOD_STILL_SPEED and back to 0 when the
## camera drives off; the builder follows the camera's motion along the road (no change while dt is 0: the stage is
## prepared). The lod0_m override still works per tag (none in the shipped configuration since QR7c-01).
func test_standing_camera_narrows_the_bands() -> void:
	var s := 0.0
	for i in 12:
		s = Props.still_step(s, 0.0, 1.0 / 60.0)
	assert_near(s, 12.0 / 60.0 / Props.LOD_STILL_S, 1.0e-4, "steigt mit der Zeit (0,2 s)")
	for i in 60:
		s = Props.still_step(s, 0.5, 1.0 / 60.0)
	assert_near(s, 1.0, 1.0e-6, "steht: 1 nach LOD_STILL_S")
	assert_near(Props.still_step(s, 20.0, 0.0), 1.0, 1.0e-6, "dt 0 (Vorbereitung): unverändert")
	s = Props.still_step(s, 20.0, 0.1)
	assert_near(s, 1.0 - 0.1 / Props.LOD_STILL_S, 1.0e-4, "fährt an: das Band öffnet sich über die Zeit")
	var b := Props.new()
	assert_near(b.lod_still(), 1.0, 1.0e-6, "Start einer Etappe: stehende Kamera")
	b.update({"camera_z": 100.0}, 1.0 / 60.0)
	for i in 30:
		b.update({"camera_z": 100.0 + float(i + 1) * 0.5}, 1.0 / 60.0)    # 30 m/s
	assert_near(b.lod_still(), 0.0, 1.0e-6, "fährt mit 30 m/s: Band offen")
	for i in 30:
		b.update({"camera_z": 115.0}, 1.0 / 60.0)
	assert_near(b.lod_still(), 1.0, 1.0e-6, "steht 0,5 s: hart")
	# with the view's own clock (Rule 10): the same view drawn twice changes nothing (check_weather draws a view twice
	# and wants the same picture); the clock, not dt, drives the ramp
	var c := Props.new()
	c.update({"camera_z": 0.0, "time": 10.0}, 1.0 / 60.0)
	for i in 12:
		c.update({"camera_z": float(i + 1) * 0.5, "time": 10.0 + float(i + 1) / 60.0}, 1.0 / 60.0)
	var s12 := c.lod_still()
	assert_near(s12, 1.0 - 12.0 / 60.0 / Props.LOD_STILL_S, 1.0e-4, "fährt an: nach der Uhr der Ansicht")
	var v13 := {"camera_z": 6.5, "time": 10.2 + 1.0 / 60.0}
	c.update(v13, 1.0 / 60.0)
	var s13 := c.lod_still()
	assert_true(s13 < s12 - 0.01, "ein Bild weiter gefahren: weiter offen (%.3f)" % s13)
	c.update(v13, 1.0 / 60.0)
	c.update(v13, 1.0 / 60.0)
	assert_near(c.lod_still(), s13, 1.0e-6, "dieselbe Ansicht noch zweimal: unverändert (trotz dt > 0)")
	# the tag override of graphics.modern.props.lod0_m still works (a configuration may name a tag again)
	b._lod0_override = {"tag:city": 42.0}
	assert_near(b.lod0_override("props/city_dutch_canal"), 42.0, 1.0e-4, "Ersatz je Tag")
	assert_near(b.lod0_override("props/farmhouse"), 0.0, 1.0e-4, "ohne Tag: kein Ersatz")


## QR7c-03 / QR7c-05: the chunk walks its level nodes only when the span of its instances crosses a threshold (not at every
## look), and a node is on from LOD_STEP_M before its band to LOD_STEP_M after it.
func test_chunk_lod_walks_only_at_thresholds() -> void:
	var t := _track()
	_put(t, 198, {"kind": "prop", "set": "props/tree_oak", "side": 1, "x": _x(t, 1, 12.0), "scale": 1.0})
	var ctx := _ctx(t, 6)
	var b := Props.new()
	b.apply_quality({"prop_lod0_m": 60.0, "prop_lod1_m": 200.0, "shadow_casters": 2, "shadow_distance_m": 120.0, "deco_density": 1.0})
	var parent := Node3D.new()
	b.commit(ctx, b.build(ctx, b.collect(ctx)), parent)
	var holder := parent.get_child(0)
	var lo: PackedFloat32Array = holder.get_meta(&"thr_lo")
	var hi: PackedFloat32Array = holder.get_meta(&"thr_hi")
	var bands := b.model_bands("props/tree_oak")
	var b0: Vector4 = bands["lod0"]
	var b1: Vector4 = bands["lod1"]
	assert_true(lo.has(b1.x - Props.LOD_STEP_M) and hi.has(b0.w + Props.LOD_STEP_M), "Schwellen: Bandanfang − 2 m, Bandende + 2 m")
	var zi := 198.0 * 3.0 + 1.0
	# far from every threshold the key stays while the camera moves 4 m (two looks)
	b.update({"camera_z": zi - 100.0}, 0.0)
	var key: Variant = holder.get_meta(&"span_key")
	b.update({"camera_z": zi - 97.0}, 0.0)
	assert_eq(holder.get_meta(&"span_key"), key, "keine Schwelle gekreuzt: Schlüssel bleibt (kein Gang über die Kinder)")
	# lod0 switches on 2 m before its band: the oak's nearest distance at b0.w + 1 m
	var lat := absf(_x(t, 1, 12.0))
	# no camera in the tree: path distances – the camera b0.w + 1 m before the oak
	b.update({"camera_z": zi - (b0.w + 1.0)}, 0.0)
	var on0 := false
	for c: Node in holder.get_children():
		if c.has_meta(&"band") and str(c.get_meta(&"rep")) == "lod0":
			on0 = (c as Node3D).visible
	assert_true(on0, "lod0 schon 1 m vor seinem Band an (Spielraum LOD_STEP_M, %.1f m seitlich)" % lat)
	parent.free()
	_cleanup()


## QR7c-04: the far mip bias of the colour per model – the half-timbered houses keep it from 30 m against their painted
## beams, every other model gets it only from 60 m (full at 150 m): the white window frames of far facades turned grey
## with R7c's 1.25 from 30 m (1.09 levels at 100 m, now 0.52), while without any bias the Barockhaus flickers 2.5 x its
## sprite at 150 m (sparkcam, measured).
func test_albedo_bias_per_model() -> void:
	var b := Props.new()
	b._read_config(cfg())
	for mid: String in ["props/city_german_old_fachwerk", "props/city_german_old_fachwerk_b"]:
		assert_eq(b.albedo_bias_of(mid), Vector3(1.25, 30.0, 120.0), "%s: 1,25 von 30 bis 120 m" % mid.get_file())
	for mid: String in ["props/city_german_old_barock", "props/city_hanse_kontor", "props/farmhouse"]:
		assert_eq(b.albedo_bias_of(mid), Vector3(1.25, 60.0, 150.0), "%s: 1,25 erst von 60 bis 150 m" % mid.get_file())
	b._albedo_bias = {"default": 0.5}
	assert_eq(b.albedo_bias_of("props/farmhouse"), Vector3(0.5, 30.0, 120.0), "eine Zahl: 30 bis 120 m")
	b._read_config(cfg())
	var t := _track()
	_put(t, 198, {"kind": "prop", "set": "props/city_german_old_fachwerk", "side": 1, "x": _x(t, 1, 12.0), "scale": 1.0})
	_put(t, 204, {"kind": "prop", "set": "props/city_german_old_barock", "side": 1, "x": _x(t, 1, 12.0), "scale": 1.0})
	var ctx := _ctx(t, 6)
	var parent := Node3D.new()
	b.commit(ctx, b.build(ctx, b.collect(ctx)), parent)
	for row: Array in [["props/city_german_old_fachwerk", Vector2(30.0, 120.0)], ["props/city_german_old_barock", Vector2(60.0, 150.0)]]:
		var mid := str((b.library.sets[str(row[0])] as Dictionary)["variants"][0])
		var n := 0
		for mat: ShaderMaterial in b.library.rep_materials(mid, "lod1"):
			if mat.shader != null and mat.shader.code.contains("albedo_bias"):
				assert_near(float(mat.get_shader_parameter("albedo_bias")), 1.25, 1.0e-4, "%s lod1: albedo_bias auf dem Material" % mid.get_file())
				assert_eq(mat.get_shader_parameter("albedo_bias_m"), row[1], "%s lod1: albedo_bias_m auf dem Material" % mid.get_file())
				n += 1
		assert_true(n >= 1, "%s: baked-Material geprüft" % mid.get_file())
	parent.free()
	_cleanup()
