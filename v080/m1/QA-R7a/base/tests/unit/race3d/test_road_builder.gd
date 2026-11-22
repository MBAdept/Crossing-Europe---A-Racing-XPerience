extends TestCase
## Road and roadside builders of the mode "Modern" (scripts/race3d/builders/road.gd, roadside.gd): the mesh of a chunk
## carries exactly what Arcade draws on its segments – edges, lane lines, the flags of fuel lane, checker,
## crosswalk, tunnel, bridge and guardrail – with every vertex on ChunkContext.local(), a watertight outer edge for
## the terrain, the vertex format the road shader reads, and guardrails, posts, reflectors and delineators where
## RoadRenderer._draw_structures puts them. Pure data: no scene tree, no renderer.

const RoadBuilder := preload("res://scripts/race3d/builders/road.gd")
const RoadsideBuilder := preload("res://scripts/race3d/builders/roadside.gd")
const SynTrack := preload("res://tests/race3d/synthetic_track.gd")
const Fair := preload("res://tests/race3d/fairness.gd")

const N := 32


func _context(t: Track, chunk: int, scenery: Dictionary = {}) -> ChunkContext:
	var p := RoadPath3D.new()
	p.setup(t, 0, float(ConfigLoader.lookup(cfg(), "road.curve_radius_at_1_m", 120.0)))
	var tp := TerrainProfile.new()
	tp.setup(p, t, ConfigLoader.lookup(cfg(), "graphics.modern.terrain", {}), scenery)
	p.ensure((chunk + 1) * N + 700)
	var ctx := ChunkContext.new()
	ctx.cfg = cfg()
	ctx.scenery_db = scenery
	ctx.capture(chunk, chunk * N, chunk * N + N, p, tp, t)
	return ctx


func _syn(n: int, opts: Dictionary = {}, curves: PackedFloat32Array = PackedFloat32Array()) -> Track:
	var t: Track = SynTrack.new()
	t.fill(cfg(), curves if not curves.is_empty() else SynTrack.straight(n), SynTrack.grades(n, [[0, 0.02], [200, -0.03]]), opts)
	return t


func _real(stage_id: String) -> Track:
	var net := Fair.load_network()
	for dir: Dictionary in Fair.directions(net, [stage_id]):
		if str(dir["from"]) == str(dir["stage"]["from"]):
			var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg(), net["city_db"])
			var t := Track.new()
			t.setup(plan, cfg(), net["scenery"])
			return t
	return null


func _build(ctx: ChunkContext) -> Dictionary:
	var b: ChunkBuilder = RoadBuilder.new()
	return b.build(ctx, b.collect(ctx))


## Per segment of a part: {"flags", "lines", "road", "kinds": Array of kinds, "x_min", "x_max", "first": first vertex}.
func _segments(part: Dictionary) -> Array:
	var arrays: Array = part["arrays"]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var c1: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM1]
	var out: Array = []
	var i := 0
	while i < uv.size():
		var kind := int(uv2[i].y)
		if kind == 0:
			out.append({"flags": int(c1[i * 4 + 2]), "lines": int(c1[i * 4]), "road": int(c1[i * 4 + 1]), "kinds": [], "first": i,
				"x_min": minf(uv[i].x, uv[i + 3].x), "x_max": maxf(uv[i + 1].x, uv[i + 2].x)})
		(out[out.size() - 1]["kinds"] as Array).append(kind)
		i += 4
	return out


func test_straight_autobahn() -> void:
	var t := _syn(400)
	var ctx := _context(t, 2)
	var part := _build(ctx)
	var arrays: Array = part["arrays"]
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var c0: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	assert_eq(v.size(), N * 4, "zwei Dreiecke je Segment: vier Eckpunkte")
	assert_eq(idx.size(), N * 6, "… und sechs Indizes")
	assert_eq(int(part["triangles"]), N * 2, "Zähler")
	assert_eq(c0.size(), v.size() * 4, "CUSTOM0 je Eckpunkt")
	assert_eq((arrays[Mesh.ARRAY_CUSTOM1] as PackedFloat32Array).size(), v.size() * 4, "CUSTOM1 je Eckpunkt")
	assert_eq((arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size(), v.size(), "Bodenfarbe je Eckpunkt")
	var half := 3.0 * t.lane_w * 0.5
	var worst := 0.0
	var front := 0
	for s in N:
		var z0 := float(ctx.seg_a + s) * t.seg_len
		for q in 4:
			var i := s * 4 + q
			var z := z0 if q < 2 else z0 + t.seg_len
			worst = maxf(worst, v[i].distance_to(ctx.local(z, uv[i].x, 0.0)))
			assert_near(uv2[i].x, 0.0 if q < 2 else t.seg_len, 1.0e-6, "UV2.x: Meter ab der nahen Kante")
			assert_near(c0[i * 4], -half, 1.0e-5, "linker Asphaltrand")
			assert_near(c0[i * 4 + 1], half, 1.0e-5, "rechter Rand der Spuren")
			assert_near(c0[i * 4 + 2], half, 1.0e-5, "rechter Asphaltrand")
			assert_true(n[i].y > 0.99, "Normale nach oben, mit der Steigung geneigt")
		assert_near(uv[s * 4].x, -ctx.shoulder_edge(s, -1), 1.0e-6, "Außenkante links = Bankettkante des Geländes")
		assert_near(uv[s * 4 + 1].x, ctx.shoulder_edge(s, 1), 1.0e-6, "Außenkante rechts")
		assert_near(uv[s * 4].y, fposmod(z0, 1440.0), 1.0e-3, "UV.y: Straßenposition modulo z_period")
		# front faces are clockwise seen from above
		var a := v[idx[s * 6]]
		var b := v[idx[s * 6 + 1]]
		var c := v[idx[s * 6 + 2]]
		if (c - a).cross(b - a).y > 0.0:
			front += 1
	assert_true(worst < 1.0e-5, "jeder Eckpunkt liegt auf ChunkContext.local() (%.6f m)" % worst)
	assert_eq(front, N, "Vorderseiten zeigen nach oben")
	for seg: Dictionary in _segments(part):
		assert_eq(int(seg["flags"]), RoadBuilder.F_EDGE | RoadBuilder.F_RAIL_L | RoadBuilder.F_RAIL_R, "Autobahn: Randlinien, Leitplanke links und rechts")
		assert_eq(int(seg["lines"]), 2, "drei Spuren: zwei Leitlinien")
		assert_eq(int(seg["road"]), 0, "Straßentyp Autobahn")
	assert_eq(_build(ctx)["arrays"], arrays, "zweimal gebaut: dieselben Daten")


func test_period_and_checker() -> void:
	var b: Object = RoadBuilder.new()
	b.call("configure", cfg())
	var period := float(b.get("z_period"))
	for cycle: float in [18.0, 9.0, 6.0, 72.0]:
		assert_near(fposmod(period, cycle), 0.0, 1.0e-6, "z_period (%.0f m) ist ein Vielfaches von %.0f m" % [period, cycle])
	assert_true(period >= 1400.0, "… und lang genug für 32-Bit-Zahlen ohne sichtbare Naht")
	var t := _syn(400, {"finish_segment": 300})
	var first := _segments(_build(_context(t, 0)))
	for s in N:
		assert_eq((int(first[s]["flags"]) & RoadBuilder.F_CHECKER) != 0, s == 4, "Startlinie bei 14 m: nur Segment 4 (%d)" % s)
	var last := _segments(_build(_context(t, 9)))
	var marked: Array[int] = []
	for s in N:
		if (int(last[s]["flags"]) & RoadBuilder.F_CHECKER) != 0:
			marked.append(9 * N + s)
	# Arcade's rule: every segment whose middle is at most half a segment from the line – two when the line lies
	# exactly on a boundary, as on this synthetic track
	assert_true(is_equal_approx(fposmod(t.length_z, t.seg_len), 0.0), "die Ziellinie dieser Teststrecke liegt auf einer Segmentgrenze")
	assert_eq(marked.size(), 2, "Ziellinie auf einer Segmentgrenze: die beiden Segmente an ihr (wie in Arcade)")
	for m: int in marked:
		assert_true(absf(float(m) * t.seg_len + t.seg_len * 0.5 - t.length_z) <= t.seg_len * 0.5, "… Segment %d liegt an length_z" % m)


func test_lane_lines_with_fractional_lanes() -> void:
	for pair: Array in [[3.0, 2], [2.0, 1], [2.5, 2], [2.1, 1], [2.17, 2], [1.0, 0], [4.0, 3]]:
		var t := _syn(200, {"lanes": float(pair[0])})
		var segs := _segments(_build(_context(t, 1)))
		assert_eq(int(segs[5]["lines"]), int(pair[1]), "%.2f Spuren: %d Leitlinien (Arcade lässt die Linie näher als 0,6 m am rechten Rand weg)" % [float(pair[0]), int(pair[1])])
		assert_near(float(segs[5]["x_min"]), -float(pair[0]) * t.lane_w * 0.5 - t.shoulder_w, 1.0e-4, "Bandbreite folgt der Spurzahl")


func test_city_curbs_and_crosswalks() -> void:
	var t := _syn(400, {"lanes": 2.0, "road": "city", "city_from_segment": 40})
	var part := _build(_context(t, 3))
	var arrays: Array = part["arrays"]
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	assert_eq(int(part["triangles"]), N * 14, "City Limits: Band, zwei Bordsteinflächen, zwei Bordsteinkanten, zwei Gehwege je Segment")
	assert_eq(int(part["city_segments"]), N, "alle Segmente mit Bordstein")
	var ctx := _context(t, 3)
	var crosswalks := 0
	var segs := _segments(part)
	for s in N:
		var seg: Dictionary = segs[s]
		var flags := int(seg["flags"])
		assert_true((flags & RoadBuilder.F_CITY) != 0 and (flags & RoadBuilder.F_EDGE) == 0, "City Limits: Bordsteine, keine Randlinien")
		assert_eq(seg["kinds"], [0, 3, 2, 1, 3, 2, 1], "Reihenfolge der Flächen")
		assert_eq(int(seg["road"]), 2, "Straßentyp Stadt")
		assert_near(float(seg["x_min"]), -t.lane_w, 1.0e-5, "das Band endet am Asphalt")
		var z := float(ctx.seg_a + s) * t.seg_len
		var want := fposmod(z, float(ConfigLoader.lookup(cfg(), "road.crosswalk_every_m", 330.0))) < t.seg_len
		assert_eq((flags & RoadBuilder.F_CROSSWALK) != 0, want, "Zebrastreifen alle 330 m (Segment %d)" % (ctx.seg_a + s))
		crosswalks += 1 if want else 0
		# the sidewalk of the left side: its outer edge is the shoulder edge, 0.14 m above the road
		var f := int(seg["first"]) + 3 * 4
		assert_near(uv[f + 1].x, -ctx.shoulder_edge(s, -1), 1.0e-5, "Gehweg bis zur Bankettkante")
		assert_true(v[f].distance_to(ctx.local(z, uv[f].x, RoadBuilder.CURB_H)) < 1.0e-5, "Gehweg 0,14 m über der Fahrbahn")
	# the left curb face of the first segment is a vertical quad at the asphalt edge
	var face := int(segs[0]["first"]) + 4
	assert_near(v[face].distance_to(v[face + 1]), RoadBuilder.CURB_H, 1.0e-5, "Bordsteinkante 0,14 m hoch")
	assert_near(uv[face + 1].x, RoadBuilder.CURB_H, 1.0e-6, "… ihr UV.x ist die Höhe")


func test_tunnel_bridge_and_ground_colour() -> void:
	var t := _syn(400, {"tunnel": [70, 90], "water": [100, 120, 6.0]})
	var segs := _segments(_build(_context(t, 2)))
	for s in N:
		var i := 2 * N + s
		var flags := int(segs[s]["flags"])
		assert_eq((flags & RoadBuilder.F_TUNNEL) != 0, i >= 70 and i < 90, "Tunnel-Flag (%d)" % i)
		if i >= 70 and i < 90:
			assert_eq(flags & (RoadBuilder.F_RAIL_L | RoadBuilder.F_RAIL_R), 0, "im Tunnel keine Leitplanke")
	segs = _segments(_build(_context(t, 3)))
	for s in N:
		var i := 3 * N + s
		var deck := (int(segs[s]["flags"]) & RoadBuilder.F_DECK) != 0
		assert_eq(deck, i >= 100 and i < 120, "Brücken-Flag (%d)" % i)
		var out := t.lane_w * 1.5 + t.shoulder_w + (RoadBuilder.DECK_EXTRA_M if deck else 0.0)
		assert_near(float(segs[s]["x_max"]), out, 1.0e-4, "auf der Brücke 0,4 m mehr bis zum Geländer")
	# the ground colour beside the road is the mean of the scenery's two grass bands
	var scen := {"north_plain": {"grass": ["#406020", "#608040"]}}
	var ctx := _context(_syn(200), 1, scen)
	var cols: PackedColorArray = _build(ctx)["arrays"][Mesh.ARRAY_COLOR]
	assert_true(cols[0].is_equal_approx(Color("406020").lerp(Color("608040"), 0.5)), "Bodenfarbe: Mittel der beiden Grasbänder (%s)" % cols[0].to_html(false))
	assert_near(RoadBuilder.ground_blend(900.0, 1000.0), smoothstep(850.0, 1000.0, 900.0), 1.0e-6, "ground_blend wie RoadRenderer")
	assert_eq(RoadBuilder.ground_blend(1200.0, 1000.0), 0.0, "hinter dem Zentrumsbeginn 0")


func test_fuel_lane_of_the_slice_stage() -> void:
	var t := _real("kiel_hamburg")
	assert_true(t != null, "Etappe kiel_hamburg vorhanden")
	if t == null:
		return
	# the first fuel lane: its taper opens before start_km
	var lane: Dictionary = t.plan.fuel_lanes[0]
	var z0 := t.km_to_z(float(lane["start_km"]))
	var chunk := int(z0 / (float(N) * t.seg_len))
	var wedge := 0
	var wide := 0
	var edge := 0
	var rail_r := 0
	for c in [chunk, chunk + 1]:
		var ctx := _context(t, c)
		var segs := _segments(_build(ctx))
		for s in N:
			var sa: Dictionary = ctx.segs[s]
			var sb: Dictionary = ctx.segs[s + 1]
			var fa := float(sa["fuel_lane"])
			var fb := float(sb["fuel_lane"])
			var flags := int(segs[s]["flags"])
			var eb := ctx.rows_edge[s + 1]
			var want_wedge := fa > 0.05 and fa < 0.98 and fb > fa and int(sa["index"]) % 2 == 0 and eb.y + eb.x > 0.9
			assert_eq((flags & RoadBuilder.F_WEDGE) != 0, want_wedge, "Schraffurstreifen der öffnenden Tankspur (Segment %d, Breite %.2f)" % [int(sa["index"]), fa])
			assert_eq((flags & RoadBuilder.F_SEP_WIDE) != 0, fa > 0.02, "breite Trennlinie neben der Tankspur")
			assert_eq((flags & RoadBuilder.F_FUEL_EDGE) != 0, fa > 0.02 or fb > 0.02, "Randlinie der Tankspur")
			assert_eq((flags & RoadBuilder.F_RAIL_R) != 0, bool(sa["guardrail"]) and fa < 0.01 and fb < 0.01 and str(sa["cover"]) == "", "rechts keine Leitplanke neben der Tankspur")
			assert_near(float(segs[s]["x_max"]), maxf(ctx.rows_edge[s].y, eb.y) + t.shoulder_w, 1.0e-4, "das Band folgt der Tankspur")
			wedge += 1 if want_wedge else 0
			wide += 1 if fa > 0.02 else 0
			edge += 1 if (flags & RoadBuilder.F_FUEL_EDGE) != 0 else 0
			rail_r += 1 if (flags & RoadBuilder.F_RAIL_R) != 0 else 0
	assert_true(wedge >= 4 and wide >= 20 and edge >= wide and rail_r >= 1, "die Öffnung der Tankspur liegt in den geprüften Stücken (%d Schraffurstreifen, %d Segmente mit Tankspur)" % [wedge, wide])


func test_commit_and_roadside() -> void:
	var t := _syn(400)
	var ctx := _context(t, 2)
	var road: ChunkBuilder = RoadBuilder.new()
	var parent := Node3D.new()
	road.commit(ctx, road.build(ctx, road.collect(ctx)), parent)
	var mi := parent.get_node_or_null("Road") as MeshInstance3D
	assert_true(mi != null and mi.mesh != null, "commit() hängt das Netz ein")
	if mi != null:
		assert_eq(mi.layers, 2, "Boden-Ebene 2: kein Punktlicht erreicht die Straße")
		assert_eq(mi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "die Straße wirft keinen Schatten")
		var mat := mi.material_override as ShaderMaterial
		assert_true(mat != null and mat.shader != null and mat.shader.resource_path.ends_with("road.gdshader"), "Material mit dem Straßen-Shader")
		assert_true(mat == road.get("material"), "ein Material für alle Stücke")
		var fmt: int = (mi.mesh as ArrayMesh).surface_get_format(0)
		assert_true((fmt & Mesh.ARRAY_FORMAT_CUSTOM0) != 0 and (fmt & Mesh.ARRAY_FORMAT_CUSTOM1) != 0 and (fmt & Mesh.ARRAY_FORMAT_TEX_UV2) != 0, "Netz mit CUSTOM0, CUSTOM1 und UV2")
		assert_near((mat.get_shader_parameter("dash_cycle") as Vector3).x, 18.0, 1.0e-6, "Strichzyklus Autobahn 6 / 12 m")
		assert_near((mat.get_shader_parameter("dash_on") as Vector3).z, 3.0, 1.0e-6, "Strich in der Stadt 3 m")
	# roadside: rails on both sides of an Autobahn, posts every second segment, reflectors every 50 m
	var side: ChunkBuilder = RoadsideBuilder.new()
	var part := side.build(ctx, side.collect(ctx))
	assert_eq(int(part["rail_left"]), N, "Leitplanke links auf jedem Segment")
	assert_eq(int(part["rail_right"]), N, "… und rechts")
	assert_eq(int(part["posts"]), N, "Pfosten jedes zweite Segment auf beiden Seiten")
	assert_eq(int(part["delineators"]), 0, "keine Leitpfosten neben Leitplanken")
	var want_reflectors := 0
	for s in N:
		var z := float(ctx.seg_a + s) * t.seg_len
		if (ctx.seg_a + s) % 2 == 0 and fposmod(z, 50.0) < 6.0:
			want_reflectors += 2
	assert_eq((part["reflectors"] as Array).size(), want_reflectors, "Reflektor am ersten Pfosten nach jedem Vielfachen von 50 m")
	# on a level road: beam between 0.48 m and 0.80 m, posts from the ground, everything within 9 cm of the edge line
	var level: Track = SynTrack.new()
	level.fill(cfg(), SynTrack.straight(400))
	var fctx := _context(level, 2)
	var rv: PackedVector3Array = side.build(fctx, null)["arrays"][Mesh.ARRAY_VERTEX]
	var lo := INF
	var hi := -INF
	var out := 0.0
	var edge := fctx.shoulder_edge(0, 1)
	for vert: Vector3 in rv:
		lo = minf(lo, vert.y)
		hi = maxf(hi, vert.y)
		out = maxf(out, absf(absf(vert.x) - edge))
	assert_true(absf(lo) < 1.0e-4 and absf(hi - 0.8) < 1.0e-4, "Pfosten ab dem Boden, Planke bis 0,80 m (%.3f … %.3f)" % [lo, hi])
	assert_true(out < 0.1, "alles höchstens 10 cm von der Bankettkante (%.3f m)" % out)
	side.commit(ctx, part, parent)
	var rs := parent.get_node_or_null("Roadside") as MeshInstance3D
	assert_true(rs != null and rs.mesh != null and rs.layers == 1, "Leitplanken im Netz, auf der Ebene der Punktlichter")
	if rs != null:
		assert_eq(rs.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "ohne Qualitätsstufen (Schatten Aus) kein Schattenwerfer")
		assert_true((rs.material_override as ShaderMaterial).shader.resource_path.ends_with("vpbr.gdshader"), "Materialklasse vpbr")
	ctx.levels = {"shadow_casters": 1}
	var parent2 := Node3D.new()
	side.commit(ctx, part, parent2)
	assert_eq((parent2.get_node("Roadside") as MeshInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "ab „Schatten: Niedrig“ werfen Leitplanken Schatten")
	parent2.free()
	parent.free()
	# a country road: delineators instead of rails, on both sides every 50 m
	var land := _syn(400, {"lanes": 2.0, "road": "landstrasse"})
	for i in 400:
		land.get_segment(i).guardrail = false
	var lctx := _context(land, 2)
	var lpart := side.build(lctx, side.collect(lctx))
	assert_eq(int(lpart["rail_left"]) + int(lpart["rail_right"]), 0, "Landstraße: keine Leitplanke")
	var want_posts := 0
	var z2 := ceilf(float(lctx.seg_a) * 3.0 / 50.0) * 50.0
	while z2 < float(lctx.seg_a + N) * 3.0:
		want_posts += 2
		z2 += 50.0
	assert_eq(int(lpart["delineators"]), want_posts, "Leitpfosten alle 50 m auf beiden Seiten")
	assert_eq((lpart["reflectors"] as Array).size(), want_posts, "jeder mit Reflektor")
	assert_true(RoadsideBuilder.has_rail({"guardrail": true, "tunnel": false, "fuel_lane": 0.5, "cover": ""}, {"fuel_lane": 0.5}, -1), "neben der Tankspur: links weiter Leitplanke")
	assert_false(RoadsideBuilder.has_rail({"guardrail": true, "tunnel": false, "fuel_lane": 0.5, "cover": ""}, {"fuel_lane": 0.5}, 1), "… rechts nicht")
	assert_false(RoadsideBuilder.has_rail({"guardrail": true, "tunnel": true, "fuel_lane": 0.0, "cover": ""}, {"fuel_lane": 0.0}, -1), "im Tunnel keine")
