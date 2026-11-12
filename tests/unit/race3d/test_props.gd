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
	var tr := _transforms((groups["m|props/farmhouse|0"] as Dictionary)["buf"], 12)[0]
	assert_true(_same(tr, ctx.frame(z, x, ctx.ground(z, x))), "Bauernhaus rechts = ChunkContext.frame() auf dem Boden, Vorderkante bei x")
	assert_true(ctx.ground(z, x) < -0.5, "… und der Boden liegt dort unter der Fahrbahn")
	# on the left: mirrored node x instance = frame x mirror, scaled; the mirrored model's left extent faces the road
	var zl := 196.0 * 3.0 + 1.0
	var xl := _x(t, -1, 40.0) - float(e_farm["extent_l"]) * 0.9
	var trl := _transforms((groups["m|props/farmhouse|1"] as Dictionary)["buf"], 12)[0]
	var node := Transform3D(Basis.from_scale(Vector3(-1.0, 1.0, 1.0)), Vector3.ZERO)
	var want := ctx.frame(zl, xl, ctx.ground(zl, xl)).scaled_local(Vector3(0.9, 0.9, 0.9)) * node
	assert_true(_same(node * trl, want), "Bauernhaus links: gespiegelt, 0,9-fach, auf dem Boden")
	# the oak: upright, scaled, turned by its stable yaw
	var tro := _transforms((groups["m|%s|0" % oak_id] as Dictionary)["buf"], 12)[0]
	assert_near(tro.basis.y.y, 1.1, 1.0e-4, "Eiche steht aufrecht und ist 1,1-fach")
	assert_near(tro.basis.x.length(), 1.1, 1.0e-4, "gleichmäßig skaliert")
	var zo := 198.0 * 3.0 + 1.0
	assert_near(tro.origin.distance_to(ctx.local(zo, _x(t, 1, 12.0), ctx.ground(zo, _x(t, 1, 12.0)))), 0.0, 1.0e-3, "Eiche auf dem Boden")
	# stand-ins: origin on the ground, uniform scale, instance colour = tint; the left one mirrored in the node
	var bl: PackedFloat32Array = (groups["s|%s|1" % sb] as Dictionary)["buf"]
	assert_eq(bl.size(), 16, "Vertretung: Transformation und Farbe")
	assert_near(bl[12], 1.0, 0.01, "Tönung rot")
	assert_near(bl[13], 0.5, 0.01, "Tönung grün")
	var zb := 199.0 * 3.0 + 1.0
	var pb := ctx.local(zb, _x(t, -1, 9.0), ctx.ground(zb, _x(t, -1, 9.0)))
	assert_near((node * _transforms(bl, 16)[0]).origin.distance_to(pb), 0.0, 1.0e-3, "gespiegelte Vertretung steht an ihrem Ort")
	var br: PackedFloat32Array = (groups["s|%s|0" % sb] as Dictionary)["buf"]
	assert_eq(br.size(), 32, "rechts zwei Vertretungen (eine als Ersatz-Set)")
	assert_near(_transforms(br, 16)[1].basis.x.x, 0.5, 1.0e-4, "Ersatz-Set mit fallback_scale")
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
		var mirrored_nodes := 0
		for c: Node in holder.get_children():
			var mmi := c as MultiMeshInstance3D
			if not mmi.visible or mmi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY or mmi.name == &"Contact":
				continue
			var key := mmi.multimesh.mesh.resource_path if mmi.multimesh.mesh.resource_path != "" else str(mmi.multimesh.mesh.get_instance_id())
			key = key.get_base_dir() if key.begins_with("res://") else key
			# per side: a set placed on both roadsides needs a second, mirrored node (D24), and a model with two
			# surfaces (a house: baked walls + vpbr panes, AS1b) then costs 2 x 2 – the budget holds per set, chunk and side
			key += " (gespiegelt)" if mmi.basis.determinant() < 0.0 else ""
			calls[key] = int(calls.get(key, 0)) + mmi.multimesh.mesh.get_surface_count()
			if mmi.basis.determinant() < 0.0:
				mirrored_nodes += 1
		for key: String in calls:
			assert_true(int(calls[key]) <= DRAW_CALLS_PER_SET, "höchstens %d Zeichenaufrufe je Set, Stück und Seite (%s: %d, Kamera %.0f)" % [DRAW_CALLS_PER_SET, key, calls[key], cam])
		assert_eq(mirrored_nodes, 3, "drei gespiegelte Knoten (Bauernhaus, Buche, Laterne links)")
	parent.free()
	_cleanup()


func test_chunk_lod_shows_one_representation() -> void:
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
	var z0 := 192.0 * 3.0
	for probe: Array in [[z0 + 10.0, "lod0", true], [z0 - 100.0, "lod1", true], [z0 - 150.0, "lod1", true], [z0 - 400.0, PropLibrary.IMPOSTOR, false]]:
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
		assert_eq(shown, [str(probe[1])], "Kamera %.0f m vor dem Stück: %s" % [z0 - float(probe[0]), probe[1]])
		assert_eq(caster, bool(probe[2]), "Schattenwerfer nur in Reichweite der Schattenkarte")
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
	# chunk 16 = segments 512..544: inside the right bend (R = 200 m): its inside is the right roadside
	for i in 8:
		_put(t, 514 + i * 3, {"kind": "prop", "set": "props/tree_birch", "side": 1, "x": _x(t, 1, 12.0 + float(i)), "scale": 1.0})
		_put(t, 515 + i * 3, {"kind": "prop", "set": "props/tree_birch", "side": -1, "x": _x(t, -1, 12.0 + float(i)), "scale": 1.0})
	_put(t, 540, {"kind": "prop", "set": "props/farmhouse", "side": 1, "x": _x(t, 1, 30.0), "scale": 1.0})
	_put(t, 541, {"kind": "prop", "set": "props/radar_camera", "side": 1, "x": _x(t, 1, 0.3), "scale": 1.0, "offset": 0.3})
	_put(t, 542, {"kind": "prop", "set": "props/tree_oak", "side": 1, "x": _x(t, 1, 20.0), "scale": 1.0, "offset": 20.0})
	var ctx := _ctx(t, 16)
	assert_true(ctx.in_bend_corridor(520.0 * 3.0, _x(t, 1, 15.0)), "Kurveninnenseite: Sichtkorridor")
	assert_false(ctx.in_bend_corridor(520.0 * 3.0, _x(t, -1, 15.0)), "Außenseite: kein Kurvenkorridor")
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
## aviation light in one baked atlas, no light layer of a sprite) – both sides as the model (the left one mirrored,
## mirror_left), no dark stand-in, and the red aviation light as a lamp anchor of each pylon, high up (no light pool).
func test_bridge_pylon_is_a_model_with_its_aviation_light() -> void:
	var t := _pylon_track()
	var ctx := _ctx(t, 6)
	var b := Props.new()
	var part := b.build(ctx, b.collect(ctx))
	var groups: Dictionary = part["groups"]
	assert_eq(int((b.library.sets["props/bridge_pylon"] as Dictionary)["kind"]), PropLibrary.MODEL, "Pylon: Modell (AS4R)")
	assert_true(groups.has("m|props/bridge_pylon|0") and groups.has("m|props/bridge_pylon|1"),
		"Brückenpylone beider Seiten als Modell (links gespiegelt) – %s" % str(groups.keys()))
	for key: String in groups:
		assert_false(key.begins_with("d|") or key.begins_with("s|props/bridge_pylon"), "keine Vertretung, wenn das Modell da ist (%s)" % key)
	var beacons: Array = []
	for l: Dictionary in part["lamps"]:
		if (l["pos"] as Vector3).y > PropLibrary.BEACON_MIN_H_M:
			beacons.append(l)
	assert_eq(beacons.size(), 3, "eine Flugbefeuerung je Pylon (zwei der Brücke, eins für sich)")
	for l: Dictionary in beacons:
		var c: Color = l["color"]
		assert_true(c.r > 0.9 and c.g < 0.3 and c.b < 0.3, "rot wie Arcades Warnlicht (%s)" % str(c))
		assert_eq(float(l["range"]), 0.0, "hoch oben: kein Lichtkegel am Boden")
	_cleanup()


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
