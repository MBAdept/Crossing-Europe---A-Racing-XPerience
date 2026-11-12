extends TestCase
## builders/terrain.gd, GroundLook and layers/far_ground.gd (mode "Modern", package terrain / props / far ground):
## the ribbon mesh is the kernel's ribbon (every vertex = ChunkContext.local() of a ring, ChunkContext.ground()
## lies on the mesh), stays inside the triangle budget, is watertight between chunks, faces up, has a skirt of no
## plan-view area, leaves tunnels out and lays the rings on the water; the colours follow Arcade's bands and its
## outskirts -> centre blend; the far ground lies below every loaded road.

const SynTrack := preload("res://tests/race3d/synthetic_track.gd")
const Fair := preload("res://tests/race3d/fairness.gd")
const TerrainBuilder := preload("res://scripts/race3d/builders/terrain.gd")
const FarGround := preload("res://scripts/race3d/layers/far_ground.gd")
const BUDGET_TRIANGLES := 1100


func _wiggly(n: int) -> PackedFloat32Array:
	var curves := PackedFloat32Array()
	curves.resize(n)
	for i in n:
		curves[i] = clampf(0.7 * sin(float(i) * 0.011) + 0.3 * sin(float(i) * 0.0047 + 0.5), -0.9, 0.9)
	return curves


func _syn_track(n: int, opts: Dictionary = {}) -> Track:
	var t: Track = SynTrack.new()
	t.fill(cfg(), _wiggly(n), SynTrack.grades(n, [[0, 0.03], [400, -0.05], [1100, 0.02]]), opts)
	return t


## Wide bends (R >= 480 m) over rolling ground: the path never comes near itself, so no ribbon is cut at a medial axis.
func _gentle_track(n: int) -> Track:
	var curves := PackedFloat32Array()
	curves.resize(n)
	for i in n:
		curves[i] = 0.25 * sin(float(i) * 0.004)
	var t: Track = SynTrack.new()
	t.fill(cfg(), curves, SynTrack.grades(n, [[0, 0.03], [400, -0.05], [1100, 0.02]]), {"hills": 3})
	return t


func _real_track(stage_id: String, from_first: bool) -> Track:
	var net := Fair.load_network()
	for dir: Dictionary in Fair.directions(net, [stage_id]):
		if (str(dir["from"]) == str(dir["stage"]["from"])) == from_first:
			var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg(), net["city_db"])
			var t := Track.new()
			t.setup(plan, cfg(), net["scenery"])
			return t
	return null


## The context of chunk `ci` of track t (path and terrain integrated far enough).
func _ctx(t: Track, ci: int, scenery: Dictionary = {}) -> ChunkContext:
	var p := RoadPath3D.new()
	p.setup(t, 0, float(ConfigLoader.lookup(cfg(), "road.curve_radius_at_1_m", 120.0)))
	var tp := TerrainProfile.new()
	tp.setup(p, t, ConfigLoader.lookup(cfg(), "graphics.modern.terrain", {}), scenery)
	p.set_clear_reach(1842.0)
	p.ensure(mini((ci + 1) * 32 + 700, t.segment_count - 1))
	var ctx := ChunkContext.new()
	ctx.cfg = cfg()
	ctx.scenery_db = scenery
	ctx.capture(ci, ci * 32, ci * 32 + 32, p, tp, t)
	return ctx


func _build(ctx: ChunkContext) -> Dictionary:
	var b := TerrainBuilder.new()
	return b.build(ctx, b.collect(ctx))


func test_mesh_is_the_kernels_ribbon_inside_the_budget() -> void:
	var t := _syn_track(1600, {"hills": 3})
	for ci: int in [3, 11, 20]:
		var ctx := _ctx(t, ci)
		var part := _build(ctx)
		var verts: PackedVector3Array = part["verts"]
		var norms: PackedVector3Array = part["normals"]
		var idx: PackedInt32Array = part["indices"]
		var n := ctx.rings
		var rows := ctx.row_count()
		assert_eq(rows, 33, "33 Reihen")
		assert_true(idx.size() / 3 <= BUDGET_TRIANGLES, "Stück %d: %d Dreiecke (Budget %d)" % [ci, idx.size() / 3, BUDGET_TRIANGLES])
		assert_eq(idx.size() / 3, 32 * 2 * (n - 1) * 2 + 32 * 2 * 2, "Dreiecke = Ringe + Schürze")
		assert_eq(verts.size(), rows * n * 2 + rows * 4, "Eckpunkte = Raster + Schürze")
		var worst := 0.0
		var flat_normals := 0
		for si in 2:
			var side := -1 if si == 0 else 1
			for i in rows:
				var z := float(ctx.seg_a + i) * ctx.seg_len
				for r in n:
					var v := si * rows * n + i * n + r
					var x := float(side) * (ctx.shoulder_edge(i, side) + ctx.ring_offset(i, side, r))
					worst = maxf(worst, verts[v].distance_to(ctx.local(z, x, ctx.ring_height(i, side, r))))
					if absf(norms[v].length() - 1.0) > 1.0e-4 or norms[v].y <= 0.05:
						flat_normals += 1
		assert_true(worst < 0.001, "jeder Rasterpunkt = ChunkContext.local() seines Rings (größte Abweichung %.5f m)" % worst)
		assert_eq(flat_normals, 0, "Normalen normiert und nach oben")
		for i in idx:
			assert_true(i >= 0 and i < verts.size(), "Index im Bereich")
			if i < 0 or i >= verts.size():
				return


func test_triangles_face_up_and_the_skirt_faces_outwards() -> void:
	var t := _syn_track(1600, {"hills": 2})
	var ctx := _ctx(t, 7)
	var part := _build(ctx)
	var verts: PackedVector3Array = part["verts"]
	var idx: PackedInt32Array = part["indices"]
	var grid := ctx.row_count() * ctx.rings * 2
	var down := 0
	var skirt_wrong := 0
	var skirt_area := 0.0
	var skirt := 0
	for q in range(0, idx.size(), 3):
		var a := verts[idx[q]]
		var b := verts[idx[q + 1]]
		var c := verts[idx[q + 2]]
		# front faces are clockwise: their geometric normal is (c - a) x (b - a)
		var nrm := (c - a).cross(b - a)
		if idx[q] < grid:
			if nrm.y <= 0.0:
				down += 1
		else:
			skirt += 1
			# plan-view area of a skirt triangle
			skirt_area += absf((b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)) * 0.5
			var si := (idx[q] - grid) / (ctx.row_count() * 2)
			var row := ((idx[q] - grid) % (ctx.row_count() * 2)) / 2
			var outward := ctx.rows_r[row] * (-1.0 if si == 0 else 1.0)
			if nrm.dot(outward) <= 0.0:
				skirt_wrong += 1
	assert_eq(down, 0, "kein Geländedreieck zeigt nach unten")
	assert_eq(skirt, 32 * 2 * 2, "Schürzendreiecke")
	assert_eq(skirt_wrong, 0, "die Schürze zeigt von der Straße weg")
	assert_true(skirt_area < 0.001, "die Schürze hat in der Draufsicht keine Fläche (%.6f m²)" % skirt_area)


func test_ground_lies_on_the_mesh() -> void:
	var t := _gentle_track(1600)
	var ctx := _ctx(t, 9)
	assert_true(ctx.ribbon_width(float(ctx.seg_a + 16) * 3.0, 1) > 200.0 and ctx.ribbon_width(float(ctx.seg_a + 16) * 3.0, -1) > 200.0,
		"ungekürztes Band auf beiden Seiten")
	var part := _build(ctx)
	var verts: PackedVector3Array = part["verts"]
	var idx: PackedInt32Array = part["indices"]
	var grid := ctx.row_count() * ctx.rings * 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var worst := 0.0
	var hits := 0
	for q in 60:
		var side := -1 if q % 2 == 0 else 1
		var z := (float(ctx.seg_a) + rng.randf_range(0.5, 31.5)) * ctx.seg_len
		var row := int(ctx.row_of(z))
		var x := float(side) * (ctx.shoulder_edge(row, side) + rng.randf_range(1.0, ctx.ribbon_width(z, side) * 0.9))
		var want := ctx.local(z, x, ctx.ground(z, x))
		for k in range(0, idx.size(), 3):
			if idx[k] >= grid:
				continue
			var a := verts[idx[k]]
			var b := verts[idx[k + 1]]
			var c := verts[idx[k + 2]]
			var det := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
			if absf(det) < 1.0e-9:
				continue
			var u := ((b.z - c.z) * (want.x - c.x) + (c.x - b.x) * (want.z - c.z)) / det
			var v := ((c.z - a.z) * (want.x - c.x) + (a.x - c.x) * (want.z - c.z)) / det
			if u < 0.0 or v < 0.0 or u + v > 1.0:
				continue
			worst = maxf(worst, absf(a.y * u + b.y * v + c.y * (1.0 - u - v) - want.y))
			hits += 1
			break
	assert_true(hits >= 55, "Stichproben treffen das Netz (%d von 60)" % hits)
	# between two rows the mesh is two flat triangles, ground() a bilinear patch: they differ by centimetres
	assert_true(worst < 0.15, "ChunkContext.ground() liegt auf dem Netz (größte Abweichung %.3f m)" % worst)


func test_neighbouring_chunks_share_their_row() -> void:
	var t := _syn_track(1600, {"hills": 3})
	var a := _ctx(t, 6)
	var b := _ctx(t, 7)
	var pa := _build(a)
	var pb := _build(b)
	var va: PackedVector3Array = pa["verts"]
	var vb: PackedVector3Array = pb["verts"]
	var n := a.rings
	var worst := 0.0
	for si in 2:
		for r in n:
			var wa := a.origin + va[si * 33 * n + 32 * n + r]
			var wb := b.origin + vb[si * 33 * n + r]
			worst = maxf(worst, wa.distance_to(wb))
	assert_true(worst < 0.002, "die gemeinsame Reihe zweier Stücke fällt zusammen (%.5f m)" % worst)


func test_no_terrain_in_tunnels_and_rings_on_the_water() -> void:
	var t := _syn_track(1600, {"tunnel": [300, 340], "water": [420, 440, 6.0]})
	var tun := _build(_ctx(t, 9))            # rows 288..320: the tunnel starts at 300
	var idx: PackedInt32Array = tun["indices"]
	assert_eq(idx.size() / 3, 12 * (2 * 6 * 2 + 2 * 2), "nur die zwölf Segmente vor dem Tunnel tragen Gelände")
	var ctx := _ctx(t, 13)                   # rows 416..448: water on 420..440
	var wat := _build(ctx)
	var custom: PackedFloat32Array = wat["custom"]
	var verts: PackedVector3Array = wat["verts"]
	var n := ctx.rings
	assert_eq(int(wat["water_rows"]), 20, "Wasserreihen")
	var row := 10                            # segment 426
	for r in range(1, n - 1):
		var v := 33 * n + row * n + r
		assert_eq(custom[v * 4 + 3], TerrainBuilder.WATER_STYLE, "Wasser ist im Stil markiert")
		assert_near(verts[v].y - ctx.rows_o[row].y, -6.0, 0.001, "die Ringe liegen auf dem Wasser")
	assert_true(custom[(33 * n + 30 * n + 2) * 4 + 3] >= 0.0, "hinter der Brücke wieder Land")


func test_bands_follow_arcade_and_fade_into_the_mean() -> void:
	var t := _real_track("kiel_hamburg", true)
	assert_true(t != null, "Etappe kiel_hamburg")
	if t == null:
		return
	var net := Fair.load_network()
	var scenery: Dictionary = net["scenery"]
	var ctx := _ctx(t, 20, scenery)
	var part := _build(ctx)
	var cols: PackedColorArray = part["colors"]
	var n := ctx.rings
	var band := maxi(1, int(ConfigLoader.lookup(cfg(), "render.stripes.grass", 4)))
	for i: int in [0, 5, 13, 22]:
		var seg: Dictionary = ctx.segs[i]
		var scen: Dictionary = scenery[str(seg["scenery"])]
		var g0 := GroundLook.grass(scen, 0)
		var g1 := GroundLook.grass(scen, 1)
		var want := g0 if (int(seg["index"]) / band) % 2 == 0 else g1
		var near := TerrainBuilder.band_tone(part, 33 * n + i * n)     # right side, at the shoulder
		var left := TerrainBuilder.band_tone(part, i * n)               # left side, at the shoulder
		var far := TerrainBuilder.band_tone(part, 33 * n + i * n + n - 1)
		assert_true(absf(near.r - want.r) + absf(near.g - want.g) + absf(near.b - want.b) < 0.01, "am Bankett: Arcades Band (Reihe %d)" % i)
		assert_true(absf(left.r - want.r) + absf(left.g - want.g) + absf(left.b - want.b) < 0.01, "links dasselbe Band (Reihe %d)" % i)
		var mean := g0.lerp(g1, 0.5)
		assert_true(absf(far.r - mean.r) + absf(far.g - mean.g) + absf(far.b - mean.b) < 0.01, "außen: das Mittel der beiden Töne")
		var c_near := cols[33 * n + i * n]
		assert_true(absf(c_near.r - mean.r) + absf(c_near.g - mean.g) + absf(c_near.b - mean.b) < 0.01, "Eckpunktfarbe = Mittel, das Band zeichnet der Shader")
		assert_near(c_near.a, 1.0, 0.001, "Landschaft: Vegetation")
	# the band phase steps by 1 / band width per segment and its parity is Arcade's band – also across chunks
	for ci: int in [20, 21, 37]:
		var cx := _ctx(t, ci, scenery)
		var px := _build(cx)
		var uv: PackedVector2Array = px["uv"]
		for i in cx.row_count():
			var idx := int(cx.segs[i]["index"])
			assert_eq(posmod(int(floor(uv[33 * cx.rings + i * cx.rings].y + 1.0e-4)), 2), (idx / band) % 2, "Stück %d Reihe %d: Bandphase = Arcades Band" % [ci, i])
	assert_eq(GroundLook.GROUND_BLEND_M, RoadRenderer.GROUND_BLEND_M, "Überblendlänge wie in Arcade")
	for z: float in [0.0, 800.0, 880.0, 925.0, 990.0, 1000.0, 1200.0]:
		assert_near(GroundLook.ground_blend(z, 1000.0), RoadRenderer.ground_blend(z, 1000.0), 1.0e-6, "ground_blend wie in Arcade")
	assert_near(GroundLook.ground_blend(500.0, 0.0), RoadRenderer.ground_blend(500.0, 0.0), 1.0e-6, "ohne Zentrum")


func test_city_blends_outskirts_into_the_centre() -> void:
	var net := Fair.load_network()
	var scenery: Dictionary = net["scenery"]
	var city := {"center_z": 5000.0, "center": "city_hanse_center", "outskirts": "city_hanse_outskirts"}
	var out := GroundLook.grass_mean(scenery["city_hanse_outskirts"])
	var cen := GroundLook.grass_mean(scenery["city_hanse_center"])
	assert_eq(GroundLook.ground_tone("city_hanse_outskirts", true, 4000.0, scenery, city), out, "weit vor dem Zentrum: Randbezirk")
	var mid := GroundLook.ground_tone("city_hanse_outskirts", true, 4925.0, scenery, city)
	assert_near(mid.r, lerpf(out.r, cen.r, 0.5), 0.01, "auf halbem Weg: die Mitte")
	var st_out := GroundLook.style_at("city_hanse_outskirts", true, 4000.0, scenery, city)
	var st_cen := GroundLook.style_at("city_hanse_center", true, 5200.0, scenery, city)
	assert_near(float(st_out["nature"]), 1.0, 0.001, "Randbezirk: Gärten")
	assert_near(float(st_cen["nature"]), 0.0, 0.001, "Zentrum: Pflaster")
	var st_mid := GroundLook.style_at("city_hanse_outskirts", true, 4925.0, scenery, city)
	assert_near(float(st_mid["nature"]), 0.5, 0.01, "dazwischen überblendet")
	var over := GroundLook.style("heath", scenery["heath"], {"heath": {"accent": "#102030", "amount": 0.9}})
	assert_eq(over["accent"], Color("#102030"), "Konfiguration überschreibt die Akzentfarbe")
	assert_near(float(over["amount"]), 0.9, 0.001, "… und den Anteil")
	for id: String in scenery:
		var st := GroundLook.style(id, scenery[id])
		assert_true(float(st["amount"]) >= 0.0 and float(st["amount"]) <= 1.0 and st["accent"] is Color, "Stil für %s" % id)


func test_noise_texture_is_deterministic_and_shared() -> void:
	var a := GroundLook.noise_texture()
	var b := GroundLook.noise_texture()
	assert_true(a == b, "eine Textur, solange jemand sie hält")
	assert_eq(a.get_width(), GroundLook.NOISE_SIZE, "Größe")
	var img := a.get_image()
	assert_true(img.has_mipmaps(), "mit Mipmaps")
	var first := img.get_data().slice(0, 4096)
	a = null
	b = null
	img = null
	var c := GroundLook.noise_texture()
	assert_eq(c.get_image().get_data().slice(0, 4096), first, "neu erzeugt: dieselben Werte")
	# the four channels really differ and use their range
	var data := c.get_image().get_data()
	var lo := [255, 255, 255, 255]
	var hi := [0, 0, 0, 0]
	for i in range(0, 256 * 256 * 4, 4):
		for ch in 4:
			lo[ch] = mini(lo[ch], data[i + ch])
			hi[ch] = maxi(hi[ch], data[i + ch])
	for ch in 4:
		assert_true(hi[ch] - lo[ch] > 150, "Kanal %d nutzt seinen Wertebereich (%d … %d)" % [ch, lo[ch], hi[ch]])


## M2INT (finding FIX-ZS1-B1, ferries on meadow under the Köhlbrandbrücke): where the loaded window crosses water, the
## plane lies below the water the terrain draws (TrackSegment.water_level), not only below the road. M2ZS1: since the
## merge of the first test build there is one rule, FIX-WASSER's FarGround.target_height() (the water of the bridges
## of Track.bridges, WATER_MARGIN_M below it; tests/unit/race3d/test_far_ground_water.gd on real stages) – this test
## keeps guarding it on a synthetic track: a bridge zone as Track._mark_bridge marks it, a water row between two road
## samples (every 4th row) included.
func test_far_ground_lies_below_the_water_of_a_bridge() -> void:
	var t := _syn_track(1600)
	var seg := t.seg_len
	t.bridges.append({"z0": 301.0 * seg, "z1": 361.0 * seg, "depth": 9.0, "slope": 6.0, "type": "river"})
	for k in range(301, 361):
		var s := t.get_segment(k)
		s.water = true
		s.water_depth = 9.0
		s.water_level = -9.0
	var p := RoadPath3D.new()
	p.setup(t, 0, 120.0)
	p.ensure(1500)
	var fg := FarGround.new()
	var drop := 4.0                                          # graphics.modern.terrain.far_ground_drop_m, the default
	var with_water := fg.target_height(p, t, 600.0, 900.0)
	var road_only := fg.lowest_road(p, 600.0, 900.0) - drop
	var water_lo := INF
	for k in range(301, 361):
		water_lo = minf(water_lo, p.height(k) - 9.0)
	assert_near(fg.water_y, water_lo, 1.0e-3, "tiefstes Wasser des Fensters: jede Wasserreihe gelesen (%.3f, Wasser %.3f)"
		% [fg.water_y, water_lo])
	assert_true(with_water <= water_lo - FarGround.WATER_MARGIN_M + 1.0e-4,
		"unter dem Wasser der Brücke (%.2f, Wasser %.2f)" % [with_water, water_lo])
	assert_true(with_water <= road_only + 1.0e-4, "nie über der tiefsten Fahrbahn − Abstand (%.2f / %.2f)" % [with_water, road_only])
	assert_near(fg.target_height(p, t, 3600.0, 900.0), fg.lowest_road(p, 3600.0, 900.0) - drop, 1.0e-4,
		"ohne Wasser im Fenster: wie die Fahrbahn allein")
	assert_eq(fg.water_y, INF, "ohne Wasser im Fenster: kein Wasserstand")
	fg.free()


func test_far_ground_lies_below_every_loaded_road() -> void:
	var t := _syn_track(1600, {"hills": 3})
	var p := RoadPath3D.new()
	p.setup(t, 0, 120.0)
	p.ensure(1500)
	var fg := FarGround.new()
	for cam_z: float in [200.0, 900.0, 1700.0, 2600.0]:
		var lo := fg.lowest_road(p, cam_z, 900.0)
		var k0 := maxi(0, int((cam_z - 150.0) / 3.0))
		var k1 := mini(p.last(), int((cam_z + 900.0 + 96.0) / 3.0))
		var true_lo := INF
		for k in range(k0, k1 + 1):
			true_lo = minf(true_lo, p.height(k))
		assert_true(lo <= true_lo + 0.6, "tiefste Fahrbahn des Fensters bei z = %.0f (%.2f, wirklich %.2f)" % [cam_z, lo, true_lo])
		assert_true(lo >= true_lo - 30.0, "… und nicht weit darunter")
	fg.free()
	var mesh := FarGround.sector_mesh()
	assert_eq(mesh.get_surface_count(), 1, "ein Netz je Sektor")
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var top := 0.0
	var reach := 0.0
	for v in verts:
		top = maxf(top, v.y)
		reach = maxf(reach, Vector2(v.x, v.z).length())
	assert_near(top, 1.0, 0.001, "der Kragen reicht bis y = 1 (der Knoten wird auf die Augenhöhe skaliert)")
	assert_near(reach, FarGround.RADIUS_M, 0.01, "Radius")
