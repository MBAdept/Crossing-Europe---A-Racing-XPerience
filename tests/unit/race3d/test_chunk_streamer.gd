extends TestCase
## ChunkContext, ChunkStreamer, BuilderRegistry and the debug road (kernel of the mode "Modern"): snapshots,
## chunk-local coordinates, loading and freeing by path distance, at most 16 chunks, sync mode = the same snapshot
## twice, threaded mode ends in the same snapshot, floating origin, camera jumps, the end of the road.

const SynTrack := preload("res://tests/race3d/synthetic_track.gd")
const Fair := preload("res://tests/race3d/fairness.gd")
const CHUNK_M := 96.0


## Records where the streamer calls a builder; builds no geometry.
class Probe extends ChunkBuilder:
	var main_id := OS.get_main_thread_id()
	var mutex := Mutex.new()
	var collects_off_main := 0
	var commits_off_main := 0
	var builds_on_main := 0
	var builds_off_main := 0
	var sprites := {}                 ## segment index -> JSON of the sprites the chunk snapshot holds

	func id() -> String:
		return "probe"

	func collect(ctx: ChunkContext) -> Variant:
		if OS.get_thread_caller_id() != main_id:
			collects_off_main += 1
		for i in ctx.segs.size() - 1:
			sprites[int(ctx.segs[i]["index"])] = JSON.stringify(ctx.segs[i]["sprites"])
		return {"rows": ctx.row_count()}

	func build(ctx: ChunkContext, input: Variant) -> Dictionary:
		mutex.lock()
		if OS.get_thread_caller_id() == main_id:
			builds_on_main += 1
		else:
			builds_off_main += 1
		mutex.unlock()
		var p := ctx.local(float(ctx.seg_a) * ctx.seg_len + 10.0, 2.0, 0.0)
		return {"rows": int((input as Dictionary)["rows"]), "index": ctx.index, "p": [snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)]}

	func commit(_ctx: ChunkContext, _part: Dictionary, parent: Node3D) -> void:
		if OS.get_thread_caller_id() != main_id:
			commits_off_main += 1
		var n := Node3D.new()
		n.name = "Probe"
		parent.add_child(n)

	func debug(part: Dictionary) -> Dictionary:
		return part


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


## [streamer, path, terrain] on track t.
func _streamer(t: Track, builders: Array, sync: bool, levels: Dictionary = {}) -> Array:
	var p := RoadPath3D.new()
	var tp := TerrainProfile.new()
	tp.setup(p, t, ConfigLoader.lookup(cfg(), "graphics.modern.terrain", {}), {})
	var st := ChunkStreamer.new()
	st.setup(p, tp, t, cfg(), levels, sync)
	for b: ChunkBuilder in builders:
		st.register(b)
	return [st, p, tp]


func _real_track(stage_id: String, from_first: bool, with_scenery: bool) -> Track:
	var net := Fair.load_network()
	for dir: Dictionary in Fair.directions(net, [stage_id]):
		if (str(dir["from"]) == str(dir["stage"]["from"])) == from_first:
			var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg(), net["city_db"])
			var t := Track.new()
			t.setup(plan, cfg(), net["scenery"] if with_scenery else {})
			return t
	return null


func test_context_snapshot() -> void:
	var t := _real_track("kiel_hamburg", true, true)
	assert_true(t != null, "Etappe kiel_hamburg vorhanden")
	if t == null:
		return
	var p := RoadPath3D.new()
	p.setup(t, 0, 120.0)
	var tp := TerrainProfile.new()
	tp.setup(p, t, {}, {})
	p.ensure(96 + 300)
	var ctx := ChunkContext.new()
	ctx.capture(2, 64, 96, p, tp, t)
	# every field of TrackSegment is in the snapshot
	var fields: Array[String] = []
	for prop: Dictionary in TrackSegment.new().get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(str(prop["name"]))
	fields.sort()
	var listed := ChunkContext.SEG_FIELDS.duplicate()
	listed.sort()
	assert_eq(listed, fields, "SEG_FIELDS = alle Felder von TrackSegment")
	var keys: Array = ctx.segs[0].keys()
	keys.sort()
	assert_eq(keys, Array(fields), "Schnappschuss enthält jedes Feld")
	assert_eq(ctx.segs.size(), 33, "33 Reihen")
	assert_eq(ctx.row_count(), 33, "row_count")
	var with_sprites := -1
	for i in 33:
		var s := t.get_segment(64 + i)
		assert_eq(int(ctx.segs[i]["index"]), 64 + i, "Reihe %d ist Segment %d" % [i, 64 + i])
		assert_eq(float(ctx.segs[i]["curve"]), s.curve, "curve")
		assert_eq(float(ctx.segs[i]["y"]), s.y, "y")
		assert_eq(str(ctx.segs[i]["road"]), s.road, "road")
		assert_eq(JSON.stringify(ctx.segs[i]["sprites"]), JSON.stringify(s.sprites), "sprites")
		if with_sprites < 0 and not s.sprites.is_empty():
			with_sprites = i
		assert_near(ctx.rows_edge[i].x, t.road_edges_at(s.z).x, 1.0e-5, "linker Fahrbahnrand")
		assert_near(ctx.rows_edge[i].y, t.road_edges_at(s.z).y, 1.0e-5, "rechter Fahrbahnrand")
		assert_near(ctx.floor_y[i], p.floor_y(64 + i) - ctx.origin.y, 1.0e-4, "Talsohle chunk-lokal")
		assert_near(ctx.shoulder_edge(i, 1), tp.edge(64 + i, 1), 1.0e-5, "shoulder_edge")
		for si in 2:
			var side := -1 if si == 0 else 1
			var x := tp.ring_offsets(64 + i, side)
			var h := tp.ring_heights(64 + i, side)
			for r in ctx.rings:
				assert_eq(ctx.ring_offset(i, side, r), x[r], "ring_x = TerrainProfile.ring_offsets")
				assert_eq(ctx.ring_height(i, side, r), h[r], "ring_h = TerrainProfile.ring_heights")
		assert_near(ctx.rows_r[i].length(), 1.0, 1.0e-5, "Rechtsvektor normiert")
		assert_near(ctx.rows_r[i].dot(ctx.rows_f[i]), 0.0, 1.0e-5, "rechts ⟂ voraus")
	assert_true(with_sprites >= 0, "im Stück stehen Requisiten oder Schilder")
	if with_sprites >= 0:
		# deep copy: changing the live segment afterwards does not change the snapshot
		var live := t.get_segment(64 + with_sprites)
		var before := JSON.stringify(ctx.segs[with_sprites]["sprites"])
		live.sprites[0]["x"] = 12345.0
		live.sprites.append({"kind": "prop", "set": "props/test"})
		assert_eq(JSON.stringify(ctx.segs[with_sprites]["sprites"]), before, "sprites sind tief kopiert")
	# chunk-local coordinates
	assert_true(ctx.rows_o[0].length() < 1.0e-6, "Ursprung des Stücks = Straßenmitte der ersten Reihe")
	assert_true(ctx.origin.distance_to(p.point(64)) < 1.0e-5, "origin = Pfadpunkt der ersten Reihe")
	var worst := 0.0
	for z: float in [192.0, 200.3, 250.0, 287.9]:
		for x: float in [-30.0, -5.6, 0.0, 9.0, 120.0]:
			worst = maxf(worst, (ctx.local(z, x, 1.5) + ctx.origin).distance_to(p.world(z, x, 1.5)))
	assert_true(worst <= 0.001, "local() + Stückposition = RoadPath3D.world() (%.5f m)" % worst)
	var f := ctx.frame(230.0, 12.0, 0.5)
	assert_true(f.origin.distance_to(ctx.local(230.0, 12.0, 0.5)) < 1.0e-6, "frame() steht auf local()")
	assert_true((-f.basis.z - RoadPath3D.fwd_of(p.heading_at(230.0))).length() < 1.0e-5, "frame(): -Z = Straßenrichtung")
	assert_near(f.basis.y.y, 1.0, 1.0e-6, "frame(): aufrecht")
	var fy := ctx.frame(230.0, 12.0, 0.5, PI * 0.5)
	assert_true((-fy.basis.z - RoadPath3D.right_of(p.heading_at(230.0))).length() < 1.0e-5, "yaw_rad +90° dreht nach rechts")
	assert_near(ctx.heading(230.0), p.heading_at(230.0), 1.0e-9, "heading()")
	# ground
	assert_near(ctx.ground(230.0, 0.0), 0.0, 1.0e-6, "auf der Fahrbahn: Fahrbahnniveau")
	assert_near(ctx.ground(230.0, 7.0), 0.0, 1.0e-6, "auf dem Bankett: Fahrbahnniveau")
	var e := tp.edge(70, 1)
	assert_near(ctx.ground(210.0, e + 10.0), tp.height(70, 1, 10.0), 1.0e-4, "rechts: Geländeprofil der Reihe")
	assert_near(ctx.ground(210.0, -(tp.edge(70, -1) + 55.0)), tp.height(70, -1, 55.0), 1.0e-4, "links: Geländeprofil der Reihe")
	assert_near(ctx.ground(211.5, e + 10.0), lerpf(tp.height(70, 1, 10.0), tp.height(71, 1, 10.0), 0.5), 1.0e-3, "zwischen zwei Reihen linear")
	assert_near(ctx.ribbon_width(210.0, 1), tp.limit(70, 1), 1.0e-3, "ribbon_width()")
	assert_true(ctx.in_corridor(210.0, 0.0) and ctx.in_corridor(210.0, e + 4.0), "Straße und Randstreifen liegen im Sichtkorridor")
	assert_false(ctx.in_corridor(210.0, e + tp.corridor_width(70, 1) + 3.0), "weiter außen nicht")
	# plain track values for the worker thread
	assert_near(ctx.seg_len, 3.0, 1.0e-6, "seg_len")
	assert_near(ctx.lane_w, t.lane_w, 1.0e-6, "lane_w")
	assert_near(ctx.shoulder_w, t.shoulder_w, 1.0e-6, "shoulder_w")
	assert_near(ctx.length_z, t.length_z, 1.0e-3, "length_z")


func test_registry() -> void:
	assert_eq(BuilderRegistry.BUILDERS, ["road", "roadside", "terrain", "props", "signs", "tunnel", "bridge", "station", "border",
		"city", "gantry", "radar", "landmarks"] as Array[String], "alle Builder des Bauplans in fester Reihenfolge")
	assert_eq(BuilderRegistry.LAYERS, ["backdrop", "far_ground", "lights", "vehicles", "flares", "weather", "overlay", "post"] as Array[String],
		"alle Ebenen des Bauplans")
	var all := BuilderRegistry.create_all()
	assert_true(all.size() >= 1, "mindestens die Straße (oder ihre Debug-Vertretung)")
	var ids: Array[String] = []
	for b: ChunkBuilder in all:
		ids.append(b.id())
	if BuilderRegistry.has_builder("road"):
		assert_eq(ids[0], "road", "die Straße steht vorn")
		assert_false(ids.has("debug_road"), "ohne Debug-Straße, sobald es builders/road.gd gibt")
	else:
		assert_eq(ids[0], "debug_road", "die Debug-Straße vertritt die fehlende Straße")
		assert_true(BuilderRegistry.create_all(false).size() == all.size() - 1, "ohne Vertretung fehlt sie")
	# fixed order, missing files skipped
	var want: Array[String] = []
	for n: String in BuilderRegistry.BUILDERS:
		if FileAccess.file_exists(BuilderRegistry.builder_path(n)):
			want.append(n)
	assert_eq(BuilderRegistry.existing_builders(), want, "vorhandene Dateien, fehlende übersprungen")
	var got: Array[String] = []
	for id: String in ids:
		if id != "debug_road":
			got.append(id)
	assert_eq(got, want, "create_all() in der Reihenfolge der Liste; id() = Dateiname")
	assert_true(BuilderRegistry.create("gibt_es_nicht") == null, "fehlende Datei: null, kein Fehler")
	assert_true(BuilderRegistry.create_layer("gibt_es_nicht") == null, "fehlende Ebene: null, kein Fehler")
	assert_eq(BuilderRegistry.create(BuilderRegistry.DEBUG_ROAD).id(), "debug_road", "Debug-Straße lässt sich immer erzeugen")
	for n: String in BuilderRegistry.existing_layers():
		assert_true(BuilderRegistry.LAYERS.has(n), "nur Ebenen der Liste")


func test_debug_road_builder() -> void:
	var t := _syn_track(1200)
	var p := RoadPath3D.new()
	p.setup(t, 0, 120.0)
	var tp := TerrainProfile.new()
	tp.setup(p, t, {}, {})
	var ctx := ChunkContext.new()
	ctx.capture(3, 96, 128, p, tp, t)
	var b := BuilderRegistry.create(BuilderRegistry.DEBUG_ROAD)
	var part := b.build(ctx, b.collect(ctx))
	var verts: PackedVector3Array = part["verts"]
	var idx: PackedInt32Array = part["indices"]
	# per segment: 3 road strips + 2 edge lines + 2 sides x 6 ring quads
	assert_eq(verts.size(), 32 * (5 + 12) * 4, "Eckpunkte")
	assert_eq(idx.size(), 32 * (5 + 12) * 6, "Indizes")
	for i in idx:
		if i < 0 or i >= verts.size():
			fail("Index außerhalb der Eckpunkte")
			break
	# the first quad is the left shoulder of the first segment, taken from ChunkContext.local()
	var e := ctx.rows_edge[0]
	assert_true(verts[0].distance_to(ctx.local(288.0, e.x - 2.5, 0.0)) < 1.0e-6, "Eckpunkte aus ChunkContext.local()")
	assert_true(verts[1].distance_to(ctx.local(288.0, e.x, 0.0)) < 1.0e-6, "(Fahrbahnrand)")
	var d := b.debug(part)
	assert_eq(int(d["vertices"]), verts.size(), "debug(): Eckpunkte")
	assert_eq(int(d["triangles"]), idx.size() / 3, "debug(): Dreiecke")
	assert_eq(int(b.debug(b.build(ctx, null))["checksum"]), int(d["checksum"]), "zweimal gebaut: gleiche Prüfsumme")
	var box: Array = d["aabb"]
	assert_true(float(box[3]) > 400.0 and float(box[5]) > 50.0, "das Stück reicht mit dem Gelände weit zur Seite")
	var parent := Node3D.new()
	b.commit(ctx, part, parent)
	assert_eq(parent.get_child_count(), 1, "ein Netz je Stück")
	var mi := parent.get_child(0) as MeshInstance3D
	assert_true(mi != null and mi.mesh != null and mi.mesh.get_surface_count() == 1, "ArrayMesh mit einer Oberfläche")
	if mi != null and mi.mesh != null:
		assert_eq((mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), verts.size(), "Netz enthält die Eckpunkte")
	parent.free()


## Acceptance: sync mode gives the same snapshot twice; at most 16 chunks; freed behind the camera.
func test_sync_mode_is_deterministic() -> void:
	var snaps: Array = []
	for run in 2:
		var t := _syn_track(3000)
		var probe := Probe.new()
		var m := _streamer(t, [BuilderRegistry.create(BuilderRegistry.DEBUG_ROAD), probe], true)
		var st: ChunkStreamer = m[0]
		var out: Array[String] = []
		var cam_z := 20.0
		var max_chunks := 0
		while cam_z < 7000.0:
			st.update(cam_z, 900.0)
			max_chunks = maxi(max_chunks, st.chunk_count())
			assert_eq(st.pending_count(), 0, "sync: nach jedem update() ist alles gebaut und eingehängt")
			assert_eq(st.get_child_count(), st.chunk_count(), "ein Knoten je Stück")
			var snap := st.snapshot()
			var lo := 1 << 30
			var hi := -1
			for c: Dictionary in snap["chunks"]:
				lo = mini(lo, int(c["index"]))
				hi = maxi(hi, int(c["index"]))
				assert_eq(str(c["state"]), "committed", "Zustand")
				assert_true(float(int(c["index"]) + 1) * CHUNK_M >= cam_z - 150.0 - 0.01, "kein Stück liegt ganz hinter cam - 150 m")
				assert_true(c["parts"].has("debug_road") and c["parts"].has("probe"), "Teile aller Builder")
			assert_true(float(lo) * CHUNK_M <= maxf(0.0, cam_z - 150.0) + 0.01, "geladen ab 150 m hinter der Kamera")
			assert_true(float(hi + 1) * CHUNK_M >= minf(cam_z + 700.0, 8900.0), "und weit voraus (bis Stück %d bei Kamera %.0f m)" % [hi, cam_z])
			out.append(JSON.stringify(snap))
			cam_z += 53.0
		assert_true(max_chunks <= 16, "höchstens 16 Stücke (größte Zahl %d)" % max_chunks)
		assert_true(max_chunks >= 11, "bei 900 m Sicht etwa 11 und mehr (%d)" % max_chunks)
		assert_eq(probe.collects_off_main + probe.commits_off_main + probe.builds_off_main, 0, "sync: alles im Hauptthread")
		snaps.append(out)
		st.clear()
		assert_eq(st.get_child_count(), 0, "clear() räumt alle Knoten ab")
		st.free()
	assert_eq((snaps[0] as Array).size(), (snaps[1] as Array).size(), "gleich viele Schnappschüsse")
	var same := true
	for i in (snaps[0] as Array).size():
		if snaps[0][i] != snaps[1][i]:
			same = false
			break
	assert_true(same, "zwei Läufe im Sync-Modus: gleiche Schnappschüsse")


## Acceptance: threaded mode ends in the same snapshot; builds run on worker threads, at most one commit per update.
func test_threaded_mode_matches_sync() -> void:
	var finals: Array[String] = []
	for sync: bool in [true, false]:
		var t := _syn_track(3000)
		var probe := Probe.new()
		var m := _streamer(t, [BuilderRegistry.create(BuilderRegistry.DEBUG_ROAD), probe], sync)
		var st: ChunkStreamer = m[0]
		var cam_z := 20.0
		var committed_before := 0
		var first := true
		var late := 0
		while cam_z < 3600.0:
			st.update(cam_z, 900.0)
			var committed := int(st.stats()["commits"])
			if not sync:
				if first:
					assert_eq(st.pending_count(), 0, "beim Laden wird alles Sichtbare sofort eingehängt")
				else:
					assert_true(committed - committed_before <= 1, "danach höchstens ein Stück je update()")
					late = maxi(late, st.pending_count())
			committed_before = committed
			first = false
			assert_true(st.chunk_count() <= 16, "höchstens 16 Stücke")
			cam_z += 9.0
		st.flush()
		assert_true(st.is_idle(), "flush(): nichts mehr offen")
		finals.append(JSON.stringify(st.snapshot()))
		assert_eq(probe.collects_off_main + probe.commits_off_main, 0, "collect() und commit() immer im Hauptthread")
		if sync:
			assert_eq(probe.builds_off_main, 0, "sync: build() im Hauptthread")
		else:
			assert_true(probe.builds_off_main > 0, "threaded: build() läuft auf Arbeiter-Threads (%d von %d)" % [probe.builds_off_main, probe.builds_off_main + probe.builds_on_main])
		st.clear()
		st.free()
	assert_eq(finals[1], finals[0], "threaded endet im selben Schnappschuss wie sync")


## A whole drive on a real mountain stage like the race session does it: the track window is cut behind the camera.
func test_real_stage_limits_rebase_and_trim() -> void:
	var t := _real_track("saragossa_pau", true, false)
	assert_true(t != null, "Etappe saragossa_pau vorhanden")
	if t == null:
		return
	var probe := Probe.new()
	var m := _streamer(t, [probe], true)
	var st: ChunkStreamer = m[0]
	var p: RoadPath3D = m[1]
	var shifts: Array[Vector3] = []
	st.rebased.connect(func(s: Vector3) -> void: shifts.append(s))
	var cam_z := 16800.0                # km 168: the climbing bends of the stage
	var max_chunks := 0
	var max_path := 0
	var far := 0.0
	while cam_z < 21500.0:
		t.update_window(cam_z, 960.0)   # Arcade's window, cut 192 m behind the camera
		st.update(cam_z, 900.0)
		max_chunks = maxi(max_chunks, st.chunk_count())
		max_path = maxi(max_path, p.last() - p.first)
		far = maxf(far, p.origin_distance(int(cam_z / 3.0)))
		cam_z += 41.0
	assert_true(max_chunks <= 16, "höchstens 16 Stücke auf der Bergstrecke (%d)" % max_chunks)
	assert_true(shifts.size() >= 1, "der Ursprung wurde verlegt (%d-mal)" % shifts.size())
	assert_eq(int(st.stats()["rebases"]), shifts.size(), "Signal je Verlegung")
	assert_true(far <= 2000.0 + 45.0, "die Kamera bleibt höchstens 2 km vom Ursprung (%.0f m)" % far)
	assert_true(max_path <= int((150.0 + 2.0 * p.clear_reach_m + 1596.0) / 3.0) + 400, "der Pfad wird hinten gekürzt (%d Grenzen)" % max_path)
	assert_true(float(p.last()) * 3.0 - cam_z <= 1500.0 + 96.0 + p.clear_reach_m + 45.0, "und reicht höchstens %.0f m vor die Kamera" % (float(p.last()) * 3.0 - cam_z))
	assert_true(p.first > 4000, "(erste Grenze jetzt %d)" % p.first)
	assert_eq(int(st.stats()["restarts"]), 1, "ein einziger Start, kein Neuaufbau unterwegs")
	# after the re-bases every chunk node still stands on its first row
	var worst := 0.0
	for c: Dictionary in st.snapshot()["chunks"]:
		var node := st.chunk_node(int(c["index"]))
		worst = maxf(worst, node.position.distance_to(p.point(int(c["seg_a"]))))
	assert_true(worst <= 0.001, "Stückknoten stehen nach dem Verlegen auf ihrer ersten Reihe (%.5f m)" % worst)
	# a short jump ahead stays inside the integrated path: the streamer just carries on
	cam_z = 22300.0
	t.update_window(cam_z, 960.0)
	st.update(cam_z, 900.0)
	assert_eq(int(st.stats()["restarts"]), 1, "Sprung um 800 m: kein Neuaufbau")
	assert_true(st.chunk_count() >= 10, "Stücke an der neuen Position (%d)" % st.chunk_count())
	# a jump beyond the integrated path (it reaches about 3.4 km ahead; the track window moved on): a new start there
	assert_true(float(p.last()) * 3.0 < 25950.0, "der Pfad reicht nicht bis zum Sprungziel (%.0f m)" % (float(p.last()) * 3.0))
	cam_z = 25950.0
	t.update_window(cam_z, 960.0)
	st.update(cam_z, 900.0)
	assert_eq(int(st.stats()["restarts"]), 2, "Sprung über das Pfadende hinaus: Neuaufbau")
	var lo := 1 << 30
	for c: Dictionary in st.snapshot()["chunks"]:
		lo = mini(lo, int(c["index"]))
		assert_eq(str(c["state"]), "committed", "nach dem Neuaufbau ist alles eingehängt")
	assert_true(float(lo + 1) * CHUNK_M >= cam_z - 192.0 - CHUNK_M and st.chunk_count() >= 3, "Stücke rund um die neue Position (%d ab Stück %d)" % [st.chunk_count(), lo])
	# the camera behind everything the track still holds: no endless restart, the oldest road is streamed
	st.update(20000.0, 900.0)
	st.update(20010.0, 900.0)
	assert_eq(int(st.stats()["restarts"]), 2, "Kamera hinter dem Streckenfenster: kein Neuaufbau in jedem Bild")
	assert_true(st.chunk_count() >= 3, "die älteste vorhandene Straße bleibt geladen")
	st.clear()
	st.free()


func test_end_of_the_road_and_visibility() -> void:
	var t := _syn_track(1000)                 # 3 km, the last boundary is 999
	var m := _streamer(t, [Probe.new()], true)
	var st: ChunkStreamer = m[0]
	st.update(2700.0, 900.0)
	var last: Dictionary = (st.snapshot()["chunks"] as Array).back()
	assert_eq(int(last["index"]), 31, "letztes Stück beginnt bei Segment 992")
	assert_eq(int(last["seg_b"]), 999, "und endet an der letzten Grenze der Strecke")
	assert_eq(int(last["parts"]["probe"]["rows"]), 8, "Teilstück mit 8 Reihen")
	st.update(2990.0, 900.0)
	assert_true(st.chunk_count() >= 1, "am Streckenende bleibt das letzte Stück")
	# short sight (tunnel, snow): fewer chunks are wanted; wanted_for() does not load anything
	var m2 := _streamer(_syn_track(3000), [Probe.new()], true)
	var st2: ChunkStreamer = m2[0]
	st2.update(600.0, 900.0)
	var far := st2.wanted_for(600.0, 900.0)
	var near := st2.wanted_for(600.0, 360.0)
	assert_true(near.size() < far.size() and near.size() >= 5, "360 m Sicht: %d statt %d Stücke gewünscht" % [near.size(), far.size()])
	assert_eq(far.size(), st2.chunk_count(), "wanted_for() = was update() lädt")
	for ci: int in near:
		assert_true(far.has(ci), "die nahen Stücke sind dieselben")
	st.clear()
	st.free()
	st2.clear()
	st2.free()


## Contract D3 at the level of the streamer: forcing the generation far ahead leaves the road as Arcade sees it, and
## a chunk snapshot already holds the signs that are inserted into the road later.
func test_streamer_keeps_the_track_and_sees_late_signs() -> void:
	var a := _real_track("kassel_wuerzburg", true, true)
	var b := _real_track("kassel_wuerzburg", true, true)
	assert_true(a != null and b != null, "Etappe kassel_wuerzburg vorhanden")
	if a == null or b == null:
		return
	var probe := Probe.new()
	var m := _streamer(a, [probe], true)
	var st: ChunkStreamer = m[0]
	var cam_z := 0.0
	var checked := 0
	var with_signs := 0
	while cam_z < 7000.0:
		a.update_window(cam_z, 960.0)
		st.update(cam_z, 900.0)
		b.update_window(cam_z, 960.0)
		# everything Arcade can see now (b) is the same road in a (generation forced far ahead by the streamer)
		var k0 := b.segment_index_at(cam_z)
		for k in range(k0, k0 + 300, 9):
			var sa := a.get_segment(k)
			var sb := b.get_segment(k)
			if sa.curve != sb.curve or sa.y != sb.y or sa.lanes != sb.lanes or JSON.stringify(sa.sprites) != JSON.stringify(sb.sprites):
				fail("Segment %d unterscheidet sich (Kamera %.0f m)" % [k, cam_z])
				return
			# the chunk snapshot taken long before holds the same sprites, warning signs included
			if probe.sprites.has(k):
				checked += 1
				if str(probe.sprites[k]) != JSON.stringify(sb.sprites):
					fail("Schnappschuss von Segment %d weicht von der Strecke ab, wie Arcade sie zeichnet (Kamera %.0f m)" % [k, cam_z])
					return
				if str(probe.sprites[k]).contains("\"sign\":\"curve\"") or str(probe.sprites[k]).contains("\"sign\":\"crest\""):
					with_signs += 1
		cam_z += 60.0
	assert_true(checked > 2000, "%d Segmente gegen die Schnappschüsse verglichen" % checked)
	assert_true(with_signs > 0, "darunter nachträglich eingefügte Warnschilder (%d)" % with_signs)
	assert_true(a.window_size() > b.window_size() + 300, "der Streamer erzeugt die Strecke weit voraus (%d gegen %d Segmente im Fenster)" % [a.window_size(), b.window_size()])
	st.clear()
	st.free()
