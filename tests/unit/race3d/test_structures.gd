extends TestCase
## Structures of the mode "Modern" (R6, contract §6 wave 3: builders station, border, city, gantry, radar) – pure
## data, no scene tree: they stand where Arcade draws them, the fuel station on exactly Track's fuel lane, nothing of
## them over the lanes below the canopy and roof heights of Arcade (F1), the extra parts outside the sight corridor of a
## bend (F7), street lights every 33 m on alternating sides with their light pools, Arcade's countdown and flash rules,
## the lettering atlas, materials and shadows of the committed nodes.

const StationB := preload("res://scripts/race3d/builders/station.gd")
const BorderB := preload("res://scripts/race3d/builders/border.gd")
const CityB := preload("res://scripts/race3d/builders/city.gd")
const GantryB := preload("res://scripts/race3d/builders/gantry.gd")
const RadarB := preload("res://scripts/race3d/builders/radar.gd")
const SynTrack := preload("res://tests/race3d/synthetic_track.gd")
const Fair := preload("res://tests/race3d/fairness.gd")

const N := 32

var _net: Dictionary = {}
var _tracks: Dictionary = {}


func _network() -> Dictionary:
	if _net.is_empty():
		_net = Fair.load_network()
	return _net


## The real Track of a stage direction (from its first city), cached.
func _real(stage_id: String) -> Track:
	if _tracks.has(stage_id):
		return _tracks[stage_id]
	var net := _network()
	for dir: Dictionary in Fair.directions(net, [stage_id]):
		if str(dir["from"]) == str(dir["stage"]["from"]):
			var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg(), net["city_db"])
			var t := Track.new()
			t.setup(plan, cfg(), net["scenery"])
			_tracks[stage_id] = t
			return t
	return null


func _context(t: Track, chunk: int) -> ChunkContext:
	var p := RoadPath3D.new()
	p.setup(t, 0, float(ConfigLoader.lookup(cfg(), "road.curve_radius_at_1_m", 120.0)))
	var tp := TerrainProfile.new()
	tp.setup(p, t, ConfigLoader.lookup(cfg(), "graphics.modern.terrain", {}), t.scenery_db)
	p.ensure((chunk + 1) * N + 700)
	var ctx := ChunkContext.new()
	ctx.cfg = cfg()
	ctx.scenery_db = t.scenery_db
	ctx.capture(chunk, chunk * N, chunk * N + N, p, tp, t)
	return ctx


func _build(b: ChunkBuilder, ctx: ChunkContext) -> Dictionary:
	return b.build(ctx, b.collect(ctx))


func _chunk_of(t: Track, z: float) -> int:
	return int(floor(z / (float(N) * t.seg_len)))


## Road coordinates (z, x, h above the road) of a chunk-local point: the row whose segment holds it.
func _road_coords(ctx: ChunkContext, v: Vector3) -> Vector3:
	var best := 0
	for i in ctx.row_count() - 1:
		var along := (v - ctx.rows_o[i]).dot(ctx.rows_f[i])
		if along >= -0.001:
			best = i
	var t := clampf((v - ctx.rows_o[best]).dot(ctx.rows_f[best]) / ctx.seg_len, 0.0, 1.0)
	var z := (float(ctx.seg_a + best) + t) * ctx.seg_len
	var o := ctx.local(z, 0.0, 0.0)
	var r := ctx.rows_r[best].lerp(ctx.rows_r[best + 1], t).normalized()
	var x := (v - o).dot(r)
	return Vector3(z, x, v.y - ctx.local(z, x, 0.0).y)


# --- fuel station --------------------------------------------------------------------------------------------------

func test_station_on_the_fuel_lane_of_the_slice_stage() -> void:
	var t := _real("kiel_hamburg")
	assert_true(t != null, "Etappe kiel_hamburg vorhanden")
	if t == null:
		return
	var lane: Dictionary = t.plan.fuel_lanes[0]
	var lz0 := t.km_to_z(float(lane["start_km"]))
	var lz1 := t.km_to_z(float(lane["end_km"]))
	var b: ChunkBuilder = StationB.new()
	var got := {"islands": 0, "canopies": 0, "fronts": 0, "letterings": 0, "pylons": 0}
	var want := {"islands": 0, "canopies": 0, "fronts": 0}
	var pumps := 0
	var low_over_lane := 0
	var checked := 0
	for c in range(_chunk_of(t, lz0 - 60.0), _chunk_of(t, lz1 + 60.0) + 1):
		var ctx := _context(t, c)
		for s in N:
			var fz := int(ctx.segs[s]["fuel_zone"])
			want["islands"] += 1 if (fz & TrackSegment.FUEL_ISLAND) != 0 else 0
			want["canopies"] += 1 if (fz & TrackSegment.FUEL_CANOPY) != 0 else 0
			want["fronts"] += 1 if (fz & TrackSegment.FUEL_CANOPY_FRONT) != 0 else 0
		var part := _build(b, ctx)
		if part.is_empty():
			continue
		for k: String in ["islands", "canopies", "pylons", "letterings"]:
			got[k] += int(part.get(k, 0))
		got["fronts"] += (part.get("fronts", []) as Array).size()
		var verts: PackedVector3Array = (part["arrays"] as Array)[Mesh.ARRAY_VERTEX]
		for rec: Array in part["edges"]:
			var idx := int(rec[0])
			var e := float(rec[1])
			var z := float(idx) * t.seg_len
			# the island stands beside the fully open fuel lane: the paved edge is Track's edge with the whole lane, the
			# lane's centre (Track.fuel_lane_x) half a lane inside it, refuelling possible there
			assert_near(t.fuel_lane_factor(z), 1.0, 1.0e-4, "Insel nur neben der ganz offenen Tankspur (Segment %d)" % idx)
			assert_near(e, t.road_edges_at(z).y, 1.0e-3, "Kante der Tankspur = Track.road_edges_at (Segment %d)" % idx)
			assert_near(t.fuel_lane_x(z) + t.lane_w * 0.5, e, 1.0e-3, "Mitte der Tankspur = Track.fuel_lane_x (Segment %d)" % idx)
			assert_true(t.fuel_lane_at(z + t.seg_len * 0.5), "neben der Insel kann getankt werden (Segment %d)" % idx)
			# the yellow kerb face of the island 0.35 m beyond that edge (a vertex of the mesh)
			var row := idx - ctx.seg_a
			var kerb := ctx.local(float(idx) * t.seg_len, e + StationB.ISLAND_IN, StationB.ISLAND_H)
			var found := false
			for v: Vector3 in verts:
				if v.distance_to(kerb) < 2.0e-3:
					found = true
					break
			assert_true(found, "Bordstein der Insel bei Kante + 0,35 m (Segment %d, Reihe %d)" % [idx, row])
		# the pumps (props of the props builder, AS1b) stand on the island
		for s in N:
			var fz2 := int(ctx.segs[s]["fuel_zone"])
			for it: Dictionary in ctx.segs[s]["sprites"]:
				if str(it.get("set", "")) == "props/fuel_pump" and (fz2 & TrackSegment.FUEL_ISLAND) != 0:
					var e2 := ctx.rows_edge[s].y
					assert_between(float(it["x"]) - e2, StationB.ISLAND_IN, StationB.ISLAND_OUT, "Zapfsäule auf der Insel")
					pumps += 1
		# F1: nothing of the station over the road or the fuel lane lower than Arcade's canopy (5.6 m) but its luminaires
		# (6 cm below the soffit, far above every sight line from the 3.4 m eye to a car)
		for v: Vector3 in verts:
			var rc := _road_coords(ctx, v)
			var ed := t.road_edges_at(rc.x)
			checked += 1
			if rc.y > ed.x and rc.y < ed.y + 0.3 and rc.z > 0.05 and rc.z < StationB.CANOPY_H - StationB.LAMP_DROP - 1.0e-3:
				low_over_lane += 1
	assert_true(want["islands"] > 10 and got["islands"] == want["islands"], "Insel auf jedem Inselsegment (%d von %d)" % [got["islands"], want["islands"]])
	assert_true(want["canopies"] > 4 and got["canopies"] == want["canopies"], "Dach auf jedem Dachsegment (%d von %d)" % [got["canopies"], want["canopies"]])
	assert_true(want["fronts"] >= 1 and got["fronts"] == want["fronts"], "Stirnblende an jedem Dachanfang (%d von %d)" % [got["fronts"], want["fronts"]])
	assert_eq(got["letterings"], got["fronts"], "jede Stirnblende mit dem Schriftzug TANKSTELLE")
	assert_eq(got["pylons"], 1, "eine Preissäule an der Einfahrt")
	assert_true(pumps >= 4, "Zapfsäulen auf der Insel (%d)" % pumps)
	assert_true(checked > 1000, "Ecken geprüft (%d)" % checked)
	assert_eq(low_over_lane, 0, "über Fahrbahn und Tankspur nichts unter der Dachhöhe von Arcade (5,6 m)")


# --- border --------------------------------------------------------------------------------------------------------

func test_border_station_of_the_test_stage() -> void:
	var t := _real("dev_testetappe")
	assert_true(t != null and not t.plan.borders.is_empty(), "Testetappe mit Grenze")
	if t == null or t.plan.borders.is_empty():
		return
	var bz := t.km_to_z(float(t.plan.borders[0]["km"]))
	var b: ChunkBuilder = BorderB.new()
	var got := {"covers": 0, "fronts": 0, "pillars": 0, "pools": 0}
	var want := 0
	var letters: Array = []
	var low := 0
	for c in range(_chunk_of(t, bz - 40.0), _chunk_of(t, bz + 60.0) + 1):
		var ctx := _context(t, c)
		for s in N:
			want += 1 if str(ctx.segs[s]["cover"]) != "" else 0
		var part := _build(b, ctx)
		if part.is_empty():
			continue
		for k: String in got:
			got[k] += int(part.get(k, 0))
		letters.append_array(part.get("letterings", []))
		# the roof keeps Arcade's height over the road and its shoulders: nothing lower than its soffit (6 m) there but
		# the luminaires of the light bars (Arcade hangs them at 5.95 m, here 0.1 m below the soffit)
		for v: Vector3 in (part["arrays"] as Array)[Mesh.ARRAY_VERTEX]:
			var rc := _road_coords(ctx, v)
			var ed := t.road_edges_at(rc.x)
			if rc.y > ed.x - t.shoulder_w + 0.01 and rc.y < ed.y + t.shoulder_w - 0.01 and rc.z > 0.05 \
					and rc.z < BorderB.ROOF_H - BorderB.BAR_DROP - 0.02:      # (a rigid luminaire on a sloping road: ±1–2 cm)
				low += 1
	assert_true(want >= 5 and got["covers"] == want, "Dach auf jedem Segment der Grenzstation (%d von %d)" % [got["covers"], want])
	assert_eq(got["fronts"], 1, "eine Stirnblende")
	assert_eq(letters, ["NL"], "Stirnblende mit dem Namen des Landes (Tafel des Schriftatlas)")
	assert_true(got["pillars"] >= 2 and got["pillars"] <= 4, "Pfeiler: zwei vorn wie Arcade, höchstens zwei am Ende (%d)" % got["pillars"])
	assert_true(got["pools"] >= 1, "Arcades Lichtkegel auf der Straße (%d)" % got["pools"])
	assert_eq(low, 0, "über Fahrbahn und Banketten nichts unter 6 m (Arcades Dach)")
	assert_eq(BorderB.country_name(t, "NL"), "NEDERLAND", "Name wie Arcade: plan.borders name_local, groß")


# --- city ----------------------------------------------------------------------------------------------------------

func test_city_lights_every_33_m_alternating_with_pools() -> void:
	var t := _real("dev_testetappe")
	if t == null:
		return
	var every := float(ConfigLoader.lookup(cfg(), "road.streetlight_every_m", 33.0))
	var cross_every := float(ConfigLoader.lookup(cfg(), "road.crosswalk_every_m", 330.0))
	var zc := t.km_to_z(t.plan.city_limits_km + 1.0)
	var b: ChunkBuilder = CityB.new()
	var lights: Array = []
	var lamps: Array = []
	var crosswalks: Array = []
	var want_cross: Array = []
	var fences := 0
	for c in range(_chunk_of(t, zc), _chunk_of(t, zc) + 4):
		var ctx := _context(t, c)
		for s in N:
			var sg: Dictionary = ctx.segs[s]
			if bool(sg["city"]) and not bool(sg["tunnel"]) and not bool(sg["water"]) and fposmod(float(sg["z"]), cross_every) < t.seg_len:
				want_cross.append(snappedf(float(sg["z"]), 0.001))
		var part := _build(b, ctx)
		lights.append_array(part.get("lights", []))
		lamps.append_array(part.get("lamps", []))
		crosswalks.append_array(part.get("crosswalks", []))
		fences += int(part.get("fence_segments", 0))
	assert_true(lights.size() >= 18, "Laternen in den City Limits (%d)" % lights.size())
	var by_side := {-1: [], 1: []}
	for l: Array in lights:
		(by_side[int(l[1])] as Array).append(float(l[0]))
	for side: int in [-1, 1]:
		var zs: Array = by_side[side]
		zs.sort()
		for i in range(1, zs.size()):
			assert_near(float(zs[i]) - float(zs[i - 1]), every, t.seg_len + 0.01, "Laternen je Seite alle %.0f m" % every)
	lights.sort_custom(func(a: Array, c: Array) -> bool: return float(a[0]) < float(c[0]))
	for i in range(1, lights.size()):
		assert_true(int(lights[i][1]) != int(lights[i - 1][1]), "Seiten wechseln sich ab (%.0f m)" % float(lights[i][0]))
	# every light has its lamp: lit at night, Arcade's pool (radius 9 m, 0.55 × lights at the centre)
	assert_true(lamps.size() >= lights.size(), "jede Laterne mit Lampe (%d Lampen, %d Laternen)" % [lamps.size(), lights.size()])
	for l: Dictionary in lamps:
		assert_eq(str(l["role"]), "street", "Rolle street (nachts an)")
		assert_near(float(l["range"]), CityB.LAMP_RANGE_M, 1.0e-6, "Lichtkegel 9 m")
		assert_near(float(l["energy"]), CityB.LAMP_ENERGY, 1.0e-6, "Stärke wie Arcade")
		assert_true((l["dir"] as Vector3).y < -0.5, "die Lampe schaut nach unten")
	assert_eq(crosswalks, want_cross, "Zebrastreifen-Daten = Regel der Fahrbahn")
	assert_true(fences > 20, "Zaun der Stadtlandschaft (%d Stücke)" % fences)


func test_city_fences_stay_out_of_bend_corridors() -> void:
	# a city section in a tight right bend: the pieces inside the bend's sight corridor are left out (F7)
	var curves := SynTrack.join([SynTrack.straight(120), SynTrack.arc(160, 140.0), SynTrack.straight(120)])
	var t: Track = SynTrack.new()
	t.fill(cfg(), curves, PackedFloat32Array(), {"road": "city", "lanes": 2.0, "city_from_segment": 0})
	var scen := {"city_test": {"fence": {"style": "wall", "color": "#9c7466", "x": 0.5, "h": 1.2, "gap_every_m": 0, "gap_m": 0}}}
	var b: ChunkBuilder = CityB.new()
	var drawn := 0
	var dropped := 0
	for c in range(4, 9):
		var ctx := _context(t, c)
		ctx.scenery_db = scen
		for s in ctx.segs.size():
			ctx.segs[s]["scenery"] = "city_test"
		var part := _build(b, ctx)
		drawn += int(part.get("fence_segments", 0))
		dropped += int(part.get("fence_dropped", 0))
		var arrays: Array = part.get("arrays", [])
		if arrays.is_empty():
			continue
		for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			var rc := _road_coords(ctx, v)
			if rc.z > 0.1:
				assert_false(ctx.in_bend_corridor(rc.x, rc.y * 0.98), "kein Zaun im Sichtkorridor der Kurve (z %.0f, x %.1f)" % [rc.x, rc.y])
	# 5 chunks × 32 segments × 2 sides: the inside of the bend (and the straights next to it: the corridor follows the
	# strongest curvature nearby) loses its pieces, the outside keeps them
	assert_true(dropped >= 60, "auf der Innenseite der Kurve fallen Stücke weg (%d)" % dropped)
	assert_true(drawn >= 140, "auf der Außenseite steht der Zaun (%d)" % drawn)
	assert_eq(drawn + dropped, 5 * 32 * 2, "jedes Segment, jede Seite: gezeichnet oder weggelassen")


# --- gantries ------------------------------------------------------------------------------------------------------

func test_gantries_and_the_countdown_rule() -> void:
	var t := _real("kiel_hamburg")
	if t == null:
		return
	var g: ChunkBuilder = GantryB.new()
	var p0 := _build(g, _context(t, 0))
	var kinds: Array = []
	for gg: Dictionary in p0.get("gantries", []):
		kinds.append(str(gg["kind"]))
		assert_near(float(gg["z"]), 14.0, 1.0e-3, "Starttor 14 m nach der Startlinie")
		assert_eq((gg["lamps"] as Array).size(), 3, "drei Countdown-Lampen")
	assert_eq(kinds, ["start"], "Starttor im ersten Stück")
	assert_eq(p0.get("letterings", []), ["START"], "Banner START (Tafel)")
	var cf := _chunk_of(t, t.length_z)
	var ctx1 := _context(t, cf)
	var p1 := _build(g, ctx1)
	kinds = []
	for gg: Dictionary in p1.get("gantries", []):
		kinds.append(str(gg["kind"]))
	assert_eq(kinds, ["finish"], "Zieltor am Ziel")
	assert_eq(p1.get("letterings", []), ["ZIEL"], "Banner ZIEL (Tafel)")
	# the banner key from the Track (prepare) is the one the chunk computes
	var row := clampi(int(floor(ctx1.row_of(t.length_z))), 0, N)
	var ed: Vector2 = GantryB.edges_at(t, t.length_z)
	assert_near(ed.x, -ctx1.shoulder_edge(row, -1), 1.0e-4, "linke Kante wie das Stück")
	assert_near(ed.y, ctx1.shoulder_edge(row, 1), 1.0e-4, "rechte Kante wie das Stück")
	# Arcade's rule (RoadRenderer._start_light_glows): red, one more each second; all green from 0 to -2 s; else off
	var cases := [[3.0, [1, 0, 0]], [2.4, [1, 0, 0]], [2.0, [1, 1, 0]], [1.0, [1, 1, 1]], [0.4, [1, 1, 1]], [0.0, [2, 2, 2]],
		[-1.5, [2, 2, 2]], [-2.5, [0, 0, 0]], [-1000.0, [0, 0, 0]]]
	for c: Array in cases:
		for k in 3:
			var st: Array = GantryB.lamp_state(float(c[0]), k)
			var want: int = (c[1] as Array)[k]
			var got := 0 if float(st[1]) <= 0.0 else (2 if st[0] == GantryB.LIGHT_GREEN else 1)
			assert_eq(got, want, "Countdown %.1f s, Lampe %d" % [float(c[0]), k])


# --- radar ---------------------------------------------------------------------------------------------------------

func test_radar_cameras_and_flash() -> void:
	var t := _real("kiel_hamburg")
	if t == null:
		return
	var r: Dictionary = t.plan.radars[0]
	var zr := t.km_to_z(float(r["km"]) + 0.25)
	var b: ChunkBuilder = RadarB.new()
	var cams := 0
	var items := 0
	for c in range(_chunk_of(t, zr) - 1, _chunk_of(t, zr) + 2):
		var ctx := _context(t, c)
		for s in N:
			for it: Dictionary in ctx.segs[s]["sprites"]:
				items += 1 if RadarB.is_camera(it) else 0
		cams += (_build(b, ctx).get("cameras", []) as Array).size()
	assert_true(items >= 1 and cams == items, "ein Blitz an jedem Blitzer (%d von %d)" % [cams, items])
	var e := {}
	RadarB.flash_entry(e, 0.0)
	assert_near(float(e["energy"]), 0.0, 1.0e-6, "ohne Blitz kein Schein")
	RadarB.flash_entry(e, 0.04)
	assert_near(float(e["energy"]), 0.0, 1.0e-6, "unter 0,05 kein Schein (Arcade)")
	RadarB.flash_entry(e, 1.0)
	assert_near(float(e["size"]) * RadarB.FLARE_K, RadarB.FLASH_R_M, 1.0e-4, "Radius 6 m beim vollen Blitz (Arcade)")
	RadarB.flash_entry(e, 0.5)
	assert_near(float(e["size"]) * RadarB.FLARE_K, RadarB.FLASH_R_M * 0.5, 1.0e-4, "Radius mit dem Blitz")
	assert_near(float(e["energy"]), RadarB.FLASH_GAIN * 0.5, 1.0e-6, "Stärke mit dem Blitz")


# --- lettering atlas -----------------------------------------------------------------------------------------------

func test_panel_atlas_layout() -> void:
	var a := StationB.PanelAtlas.new()
	var noop := func(_p: SignPainter, _b: GeoBatch, _r: Rect2, _ppm: float, _n: bool) -> void: pass
	var specs: Array = [{"key": "a", "w": 5.1, "h": 0.85, "ppm": 96.0, "glow": true, "draw": noop},
		{"key": "b", "w": 2.2, "h": 3.8, "ppm": 72.0, "glow": true, "draw": noop},
		{"key": "c", "w": 21.0, "h": 1.6, "ppm": 56.0, "draw": noop}, {"key": "a", "w": 9.0, "h": 9.0, "draw": noop}]
	a.prepare(specs, null)
	assert_true(a.ready and a.placeholder, "ohne Halter: Platzhalter-Atlas, sofort fertig")
	assert_eq(a.entries.size(), 3, "drei Tafeln (ein Schlüssel nur einmal)")
	assert_true(a.emission != null, "Nachtbild, wenn eine Tafel leuchtet")
	var rects: Array = a.entries.values()
	var gap := Vector2(float(StationB.PanelAtlas.PAD) / float(a.size.x), float(StationB.PanelAtlas.PAD) / float(a.size.y))
	for i in rects.size():
		var ri: Rect2 = rects[i]
		assert_true(ri.position.x >= 0.0 and ri.position.y >= 0.0 and ri.end.x <= 1.0 and ri.end.y <= 1.0, "Zelle im Atlas")
		for j in range(i + 1, rects.size()):
			var rj: Rect2 = rects[j]
			assert_false(ri.grow_individual(gap.x * 0.9, gap.y * 0.9, gap.x * 0.9, gap.y * 0.9).intersects(rj), "Zellen mit Rand getrennt")
	var ra: Rect2 = a.uv("a")
	assert_near(ra.size.x * float(a.size.x), ceilf(5.1 * 96.0), 1.0, "Zellbreite = Breite × Pixel je Meter")
	assert_eq(a.uv("fehlt"), Rect2(), "unbekannte Tafel: leeres Rechteck")


# --- nodes: materials and shadows ----------------------------------------------------------------------------------

func test_committed_nodes_static_material_and_shadow_rule() -> void:
	var t := _real("kiel_hamburg")
	if t == null:
		return
	var mats := ModernMaterials.shared()
	var vstatic := mats.material(ModernMaterials.VPBR_STATIC)
	var lane: Dictionary = t.plan.fuel_lanes[0]
	var cases := [[StationB.new(), _chunk_of(t, t.km_to_z(float(lane["start_km"])) + 120.0)], [GantryB.new(), 0]]
	for c: Array in cases:
		var b: ChunkBuilder = c[0]
		for casters: int in [0, 1]:
			var ctx := _context(t, int(c[1]))
			ctx.levels = {"shadow_casters": casters}
			var part := _build(b, ctx)
			assert_false(part.is_empty(), "%s: etwas gebaut" % b.id())
			var parent := Node3D.new()
			b.commit(ctx, part, parent)
			var geo: Array = []
			_collect_geometry(parent, geo)
			assert_true(geo.size() >= 2, "%s: Knoten (%d)" % [b.id(), geo.size()])
			for gi: GeometryInstance3D in geo:
				if casters == 0:
					assert_eq(gi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s: mit „Schatten: Aus“ wirft %s nichts" % [b.id(), gi.name])
				var m := gi.material_override
				if m is ShaderMaterial and (m as ShaderMaterial).shader == mats.shader("vpbr"):
					fail("%s: %s mit dem vpbr-Material mit Instanz-Uniforms" % [b.id(), gi.name])
				if String(gi.name) in ["Station", "Gantry"]:
					assert_true(m == vstatic, "%s: %s im statischen vpbr (keine Instanz-Uniforms)" % [b.id(), gi.name])
					if casters == 1:
						assert_eq(gi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "%s: Bauten werfen mit Bauten-Werfern" % b.id())
			parent.free()


func _collect_geometry(n: Node, out: Array) -> void:
	if n is GeometryInstance3D:
		out.append(n)
	for ch: Node in n.get_children():
		_collect_geometry(ch, out)
