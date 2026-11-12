extends TestCase
## builders/bridge.gd (mode "Modern", package R5 – docs/renderer-modern-tunnel-bruecken.md) on the real bridges of the
## network, built headless without a renderer: the water lies on the terrain's water rows and reaches the ribbon's
## last ring; the banks follow Arcade's rule (a quay wall where the slope is one segment, an embankment elsewhere –
## grass in the bank colour, stone without one); the far quay wall faces the approaching camera; the pylons of the
## Köhlbrandbrücke are the bare model scaled to pylon_m (A-16) with the aviation light at pylon_m + 1.6 m blinking in
## Arcade's rhythm (M2ZS1) and dark at night; no stay cable reaches over a lane; nothing of the structure stands in the
## lanes; the props builder leaves the bridge parts to this builder; every bridge type of the data builds.

const Fair := preload("res://tests/race3d/fairness.gd")
const Bridge := preload("res://scripts/race3d/builders/bridge.gd")
const Props := preload("res://scripts/race3d/builders/props.gd")

var _net: Dictionary = {}
var _cfg: Dictionary = {}
var _tracks: Dictionary = {}


## Stands for the renderer: the facade members a builder reads, add_lamps and builder(id).
class FakeRenderer extends Node:
	var lamps: Array = []
	var builders: Dictionary = {}
	var view := {"camera_z": 0.0}

	func add_lamps(_parent: Node3D, list: Array) -> void:
		lamps.append_array(list)

	func builder(id: String) -> Object:
		return builders.get(id)


func _cleanup() -> void:
	ModelDB.release_all()
	ModernMaterials.drop_shared()


func _config() -> Dictionary:
	if _cfg.is_empty():
		_cfg = cfg()
	return _cfg


func _track(stage_id: String, from_id: String) -> Track:
	var key := stage_id + "|" + from_id
	if _tracks.has(key):
		return _tracks[key]
	if _net.is_empty():
		_net = Fair.load_network()
	for dir: Dictionary in Fair.directions(_net, [stage_id]):
		if str(dir["from"]) == from_id:
			var plan := StagePlan.build(dir["stage"], from_id, _net["cities"], _net["countries"], _config(), _net["city_db"])
			var t := Track.new()
			t.setup(plan, _config(), _net["scenery"])
			_tracks[key] = t
			return t
	return null


func _bridge(t: Track, bridge_name: String) -> Dictionary:
	for br: Dictionary in t.bridges:
		if str(br["name"]) == bridge_name:
			return br
	return {}


## The chunk contexts that hold a bridge (path and terrain profile built like the streamer does).
func _contexts(t: Track, br: Dictionary) -> Array[ChunkContext]:
	var out: Array[ChunkContext] = []
	var p := RoadPath3D.new()
	p.setup(t, 0, float(ConfigLoader.lookup(_config(), "road.curve_radius_at_1_m", 120.0)))
	var tp := TerrainProfile.new()
	tp.setup(p, t, ConfigLoader.lookup(_config(), "graphics.modern.terrain", {}), _net["scenery"])
	p.set_clear_reach(1842.0)
	var c0 := int(floor(float(br["z0"]) / t.seg_len / 32.0))
	var c1 := int(floor(float(br["z1"]) / t.seg_len / 32.0))
	for ci in range(c0, c1 + 1):
		p.ensure(mini((ci + 1) * 32 + 700, t.segment_count - 1))
		var ctx := ChunkContext.new()
		ctx.cfg = _config()
		ctx.scenery_db = _net["scenery"]
		ctx.levels = {"shadow_casters": 2, "details": 1}
		ctx.capture(ci, ci * 32, ci * 32 + 32, p, tp, t)
		out.append(ctx)
	return out


## Builds every chunk of a bridge: [[ctx, part], …].
func _build(t: Track, br: Dictionary, b: Object = null) -> Array:
	var builder: Object = b if b != null else Bridge.new()
	var out: Array = []
	for ctx: ChunkContext in _contexts(t, br):
		var inp: Variant = builder.call("collect", ctx)
		out.append([ctx, builder.call("build", ctx, inp)])
	return out


## Vertices of a part's mesh arrays whose kind (UV2.x) is `kind` (-1: every kind).
static func _verts(arrays: Array, kind: float = -1.0) -> Array:
	var out: Array = []
	if arrays.is_empty():
		return out
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	for k in v.size():
		if kind < 0.0 or absf(uv2[k].x - kind) < 0.01:
			out.append([v[k], uv2[k], k])
	return out


## Road coordinates (z, x, h) of a chunk-local point: the boundary of the path (also beyond the chunk: a stay cable
## reaches 64 m past its pylon) whose cross-section holds it – lateral along its right vector, height above it.
static func _road_coords(ctx: ChunkContext, p: Vector3) -> Vector3:
	var w := p + ctx.origin
	var path := ctx.path
	var best := ctx.seg_a
	var bd := INF
	for k in range(maxi(path.first, ctx.seg_a - 40), mini(path.last(), ctx.seg_b + 40) + 1):
		var d := (w - path.point(k)).dot(RoadPath3D.fwd_of(path.heading(k)))
		if absf(d) < bd:
			bd = absf(d)
			best = k
	var rel := w - path.point(best)
	return Vector3(float(best) * ctx.seg_len + rel.dot(RoadPath3D.fwd_of(path.heading(best))), rel.dot(RoadPath3D.right_of(path.heading(best))), rel.y)


func test_water_lies_on_the_water_rows_out_to_the_ribbon() -> void:
	var t := _track("kiel_hamburg", "kiel")
	var br := _bridge(t, "Köhlbrandbrücke")
	assert_false(br.is_empty(), "Köhlbrandbrücke in den Daten")
	var built := _build(t, br)
	var checked := 0
	var widest := 0.0
	for e: Array in built:
		var ctx: ChunkContext = e[0]
		var part: Dictionary = e[1]
		for vt: Array in _verts(part.get("water", []), Bridge.K_WATER):
			var rc := _road_coords(ctx, vt[0])
			var k := int(round(rc.x / ctx.seg_len))
			var s := t.get_segment(k)
			if s.index != k or not s.water:
				continue
			checked += 1
			assert_near(rc.z, minf(s.water_level, 0.0) + Bridge.WATER_LIFT, 0.05,
				"Wasser bei km %.3f liegt %.2f m über der Wasserreihe des Geländes" % [t.z_to_km(rc.x), rc.z - minf(s.water_level, 0.0)])
			widest = maxf(widest, absf(rc.y))
	assert_true(checked > 200, "Wassereckpunkte geprüft (%d)" % checked)
	assert_true(widest >= 400.0, "das Wasser reicht bis zum letzten Ring des Bandes (%.0f m)" % widest)


func test_banks_follow_arcades_rule() -> void:
	var t := _track("kiel_hamburg", "kiel")
	# Elbbrücken: 3.6 m deep, no bank colour – the slope is one segment: two quay walls
	var elb := _bridge(t, "Elbbrücken")
	var walls := 0
	var grass := 0
	for e: Array in _build(t, elb):
		var part: Dictionary = e[1]
		walls += int((part.get("counts", {}) as Dictionary).get("walls", 0))
		grass += _verts(part.get("water", []), Bridge.K_GRASS).size()
	assert_eq(walls, 2, "Elbbrücken: zwei Kaimauern (Böschung über ein Segment)")
	assert_eq(grass, 0, "Elbbrücken: keine Grasböschung")
	# Köhlbrandbrücke: 9 m deep, slope 13.5 m, no bank colour – a stone embankment
	var kb := _bridge(t, "Köhlbrandbrücke")
	var stone := 0
	walls = 0
	for e: Array in _build(t, kb):
		var part: Dictionary = e[1]
		walls += int((part.get("counts", {}) as Dictionary).get("walls", 0))
		stone += _verts(part.get("water", []), Bridge.K_STONE).size()
	assert_eq(walls, 0, "Köhlbrandbrücke: keine senkrechte Mauer")
	assert_true(stone > 50, "Köhlbrandbrücke: Steinböschung in Arcades Kaifarbe (%d Eckpunkte)" % stone)
	# Holtenauer Hochbrücke: bank colour #5f7e4a – a grass embankment in that colour
	var tk := _track("rostock_kiel", "rostock")
	var hb := _bridge(tk, "Holtenauer Hochbrücke")
	assert_false(hb.is_empty(), "Holtenauer Hochbrücke in den Daten")
	var green := 0
	for e: Array in _build(tk, hb):
		var part: Dictionary = e[1]
		var arr: Array = part.get("water", [])
		if arr.is_empty():
			continue
		var col: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		for vt: Array in _verts(arr, Bridge.K_GRASS):
			var c: Color = col[int(vt[2])]
			green += 1 if c.g > c.r and c.g > c.b else 0
	assert_true(green > 50, "Holtenau: Grasböschung in der Uferfarbe (%d Eckpunkte)" % green)


func test_far_quay_wall_faces_the_camera_and_reaches_into_the_water() -> void:
	var t := _track("kiel_hamburg", "kiel")
	var elb := _bridge(t, "Elbbrücken")
	var z1 := float(elb["z1"])
	var depth := float(elb["depth"])
	var found := 0
	var lo := INF
	var hi := -INF
	for e: Array in _build(t, elb):
		var ctx: ChunkContext = e[0]
		var arr: Array = (e[1] as Dictionary).get("water", [])
		if arr.is_empty():
			continue
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for vt: Array in _verts(arr, Bridge.K_STONE):
			var rc := _road_coords(ctx, vt[0])
			if absf(rc.x - (z1 - ctx.seg_len)) > 0.2 or absf(rc.y) < 12.0:
				continue
			var nn: Vector3 = n[int(vt[2])]
			var row := clampi(int(round(ctx.row_of(rc.x))), 0, ctx.row_count() - 1)
			if absf(nn.y) > 0.5:
				continue
			found += 1
			assert_true(nn.dot(ctx.rows_f[row]) < -0.9, "die ferne Kaimauer schaut zur Kamera zurück")
			lo = minf(lo, rc.z)
			hi = maxf(hi, rc.z)
	assert_true(found >= 4, "ferne Kaimauer der Elbbrücken gefunden (%d Eckpunkte)" % found)
	assert_true(lo <= -depth - Bridge.WALL_FOOT_M + 0.05, "die Mauer reicht ins Wasser (%.2f m)" % lo)
	assert_true(hi >= -1.5, "und bis zum Ufer hinauf (%.2f m)" % hi)


func test_koehlbrand_pylons_beacons_and_cables() -> void:
	var t := _track("kiel_hamburg", "kiel")
	var kb := _bridge(t, "Köhlbrandbrücke")
	var built := _build(t, kb)
	var pylons := 0
	var beacons := 0
	var cables := 0
	var height := 95.0
	for e: Array in built:
		var ctx: ChunkContext = e[0]
		var part: Dictionary = e[1]
		for p: Dictionary in part.get("pylons", []):
			pylons += 1
			var tr: Transform3D = p["t"]
			assert_near(tr.basis.get_scale().y, height / Bridge.PYLON_MODEL_H, 0.001, "Pylon auf pylon_m skaliert (A-16)")
		for l: Dictionary in part.get("lamps", []):
			if not l.has("blink"):
				continue
			beacons += 1
			var b: Vector3 = l["blink"]
			assert_near(b.x, 1.6, 1.0e-6, "Takt 1,6 s wie Arcade")
			assert_near(b.y, 0.8, 1.0e-6, "0,8 s an")
			assert_near(absf(b.z), 0.4, 1.0e-6, "Phase ± 0,4 s je Seite")
			var rc := _road_coords(ctx, l["pos"])
			assert_near(rc.z, height + 1.6, 0.3, "Flugbefeuerung auf pylon_m + 1,6 m (Arcade)")
			assert_eq(l["color"], Bridge.BEACON_COLOR, "rot")
			assert_near(float(l["range"]), 0.0, 1.0e-6, "kein Lichtkegel am Boden")
		cables += int((part.get("counts", {}) as Dictionary).get("cables", 0))
	assert_eq(pylons, 4, "vier Pylone (Arcade: zwei Paare bei 0,27 und 0,73 der Länge)")
	assert_eq(beacons, 4, "eine Flugbefeuerung je Pylon")
	assert_eq(cables, 4 * 2 * Bridge.CABLES_PER_SIDE, "sieben Seile nach vorn und hinten je Pylon")


func test_no_cable_reaches_over_a_lane() -> void:
	for case: Array in [["kiel_hamburg", "kiel", "Köhlbrandbrücke"], ["frankfurt_koeln", "frankfurt", "Severinsbrücke"],
			["slavonski_brod_belgrad", "slavonski_brod", "Ada-Brücke"]]:
		var t := _track(str(case[0]), str(case[1]))
		var br := _bridge(t, str(case[2]))
		if br.is_empty():
			fail("%s fehlt" % case[2])
			continue
		var lowest := INF
		var worst := ""
		for e: Array in _build(t, br):
			var ctx: ChunkContext = e[0]
			var inp: Variant = Bridge.new().call("collect", ctx)
			for c: Array in (inp as Dictionary).get("cables", []):
				for q in 11:
					var p: Vector3 = (c[0] as Vector3).lerp(c[1], float(q) / 10.0)
					var rc := _road_coords(ctx, p)
					var row := clampi(int(round(ctx.row_of(rc.x))), 0, ctx.row_count() - 1)
					var lanes := ctx.rows_edge[row].y if rc.y > 0.0 else -ctx.rows_edge[row].x
					var beyond := absf(rc.y) - lanes
					if beyond < lowest:
						lowest = beyond
						worst = "km %.3f, %.2f m neben der Spur, %.1f m hoch" % [t.z_to_km(rc.x), beyond, rc.z]
		assert_true(lowest >= 1.5, "%s: kein Seil über einer Spur (nächstes: %s)" % [case[2], worst])


func test_structure_keeps_out_of_the_lanes() -> void:
	# beside and below the deck only: no vertex of the structure over the lanes (and the first metre of their shoulder)
	# below 5.5 m – the stay cables end on the deck's edge, 0.1 m inside the railing (Arcade)
	for case: Array in [["kiel_hamburg", "kiel", "Elbbrücken"], ["kiel_hamburg", "kiel", "Köhlbrandbrücke"],
			["kassel_wuerzburg", "kassel", "Ludwigsbrücke"], ["mailand_venedig", "mailand", "Ponte della Libertà"],
			["bremen_amsterdam", "bremen", "Singel"]]:
		var t := _track(str(case[0]), str(case[1]))
		var br := _bridge(t, str(case[2]))
		if br.is_empty():
			fail("%s fehlt" % case[2])
			continue
		var bad := 0
		var example := ""
		for e: Array in _build(t, br):
			var ctx: ChunkContext = e[0]
			for vt: Array in _verts((e[1] as Dictionary).get("struct", [])):
				var rc := _road_coords(ctx, vt[0])
				var row := clampi(int(round(ctx.row_of(rc.x))), 0, ctx.row_count() - 1)
				var edge := (ctx.rows_edge[row].y if rc.y > 0.0 else -ctx.rows_edge[row].x) + 1.0
				if rc.z > 0.15 and rc.z < 5.5 and absf(rc.y) < edge:
					bad += 1
					example = "x %.2f h %.2f (Kante %.2f)" % [rc.y, rc.z, edge]
		assert_eq(bad, 0, "%s: nichts vom Tragwerk über der Fahrbahn (%s)" % [case[2], example])


func test_props_builder_leaves_the_bridge_parts_to_this_builder() -> void:
	var t := _track("kiel_hamburg", "kiel")
	var kb := _bridge(t, "Köhlbrandbrücke")
	var r := FakeRenderer.new()
	var items := 0
	for ctx: ChunkContext in _contexts(t, kb):
		for seg: Dictionary in ctx.segs:
			for it: Dictionary in seg["sprites"]:
				if it.has("bridge"):
					items += 1
					assert_true(str(Props.item_set(it, {"skip_bridge": true})) == "", "Brückenteil %s geht an den Brücken-Builder" % str(it.get("set", "")))
					assert_true(str(Props.item_set(it, {"skip_bridge": false})) != "", "ohne Brücken-Builder zeichnet es der Requisiten-Builder")
	assert_true(items > 0, "Brückenteile auf der Köhlbrandbrücke")
	# the duck-typed contract: a renderer that has a "bridge" builder makes the props builder skip them
	r.builders["bridge"] = Bridge.new()
	var props2: Object = Props.new()
	props2.call("setup", r)
	assert_true(bool(props2.get("_skip_bridge")), "props.gd erkennt den Brücken-Builder über renderer.builder(\"bridge\")")
	r.free()


func test_dark_pylon_material_at_night() -> void:
	var b: Object = Bridge.new()
	var parts: Array = b.call("_parts", Bridge.PYLON_SET)
	if parts.is_empty():
		fail("Modell props/bridge_pylon_bare fehlt")
		return
	var node := MultiMeshInstance3D.new()
	b.call("_dark_override", node, parts[0])
	var m := node.material_override as ShaderMaterial
	assert_true(m != null, "der Pylon bekommt eine eigene Materialkopie")
	if m != null:
		assert_near(float(m.get_shader_parameter("emit_energy")), 0.0, 1.0e-6, "ohne Nachtatlas (M2ZS1)")
		assert_near(float(m.get_shader_parameter("night_albedo")), Bridge.PYLON_NIGHT_ALBEDO, 1.0e-6, "night_albedo 0,45 (M2ZS1)")
	node.free()


func test_every_bridge_type_builds() -> void:
	# one direction per type of the data (CityData.BRIDGE_TYPES) – the full scan of all 122 bridges is
	# check_tunnel_bridge.gd -- --full
	var cases := [["kiel_hamburg", "kiel", "Köhlbrandbrücke", "cable_stayed"], ["kiel_hamburg", "kiel", "Elbbrücken", "truss_arch"],
		["kassel_wuerzburg", "kassel", "Ludwigsbrücke", "stone_arch"], ["bremen_amsterdam", "bremen", "Singel", "canal"],
		["mailand_venedig", "mailand", "Ponte della Libertà", "causeway"], ["budapest_wien", "budapest", "Reichsbrücke", "river"]]
	var seen := {}
	for case: Array in cases:
		var t := _track(str(case[0]), str(case[1]))
		var br := _bridge(t, str(case[2]))
		if br.is_empty():
			fail("%s fehlt" % case[2])
			continue
		assert_eq(str(br["type"]), str(case[3]), "%s ist %s" % [case[2], case[3]])
		var sums := {}
		for e: Array in _build(t, br):
			var c: Dictionary = (e[1] as Dictionary).get("counts", {})
			for k: String in c:
				sums[k] = int(sums.get(k, 0)) + int(c[k])
		seen[str(br["type"])] = true
		assert_true(int(sums.get("water_quads", 0)) > 20, "%s: Wasser" % case[2])
		assert_true(int(sums.get("bank_quads", 0)) > 0, "%s: Ufer" % case[2])
		match str(br["type"]):
			"cable_stayed":
				assert_true(int(sums.get("pylons", 0)) >= 2 and int(sums.get("cables", 0)) > 0, "%s: Pylone und Seile" % case[2])
			"truss_arch":
				assert_true(int(sums.get("truss", 0)) > 10 and int(sums.get("portals", 0)) > 2, "%s: Fachwerk und Portale" % case[2])
			"stone_arch", "canal", "causeway":
				assert_true(int(sums.get("arches", 0)) > 3, "%s: Bögen" % case[2])
			_:
				assert_true(int(sums.get("piers", 0)) >= 1, "%s: Pfeiler" % case[2])
	for typ: String in CityData.BRIDGE_TYPES:
		assert_true(seen.has(typ), "Brückentyp %s gebaut" % typ)
