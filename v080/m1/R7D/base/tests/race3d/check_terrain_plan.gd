extends SceneTree
## Plan-view check of the terrain of the mode "Modern" (v0.8.0, contract §6 package R2; tools/run_tests.sh runs every
## tests/race3d/check_*.gd): inside everything that is loaded at the same time no piece of terrain may lie on top of
## another one – the ribbons of two parts of the road end before their medial axis, the ribbon on the inside of a
## bend ends before the centre of the bend (TerrainProfile), and builders/terrain.gd builds exactly those ribbons.
##   godot --headless --path . -s res://tests/race3d/check_terrain_plan.gd [-- --verbose] [--dump=<absolute folder>]
## Sampled: the twelve hardest stage directions (Fairness.HARDEST), in each the WINDOWS camera positions with the
## tightest bends (at least 1.5 km of road apart) plus the terrain reference positions T1–T4. At every position the
## chunks the streamer wants (visibility 900 m) are built by the terrain builder; per chunk, side and segment the
## strip from the shoulder to the outer edge (the union of its ring quads) is taken in plan view.
##   terrain_plan_overlap  no two strips of DIFFERENT PARTS of the road (more than SAME_BEND_ROWS rows apart, or on
##                         opposite sides) overlap by more than OVERLAP_TOLERANCE_M (separating axes); no strip is
##                         folded over itself
##   terrain_plan_tips     strips of the same bend (same side, at most SAME_BEND_ROWS rows apart; neighbours share
##                         an edge and are not tested): where the curvature changes along a bend, the tips of the
##                         ribbon on its inside could touch when the kernel cut every row by its OWN curvature
##                         only (kernel of wave 0: 71 pairs at 8 of 40 positions, at most 1.83 m). Since the
##                         assembly of M1 TerrainProfile also cuts by the sharpest curvature of the side nearby
##                         (_kappa()): none; with STRICT every such overlap fails.
##   terrain_plan_budget   every chunk stays within 1,100 terrain triangles
## --dump writes <folder>/plan_<id>.json for T1–T4 (rings, road, props with their drops, far ground) – the data of
## the top views (drawn by a script outside the repository). Exit code 1 when a check fails.
## Docs: docs/renderer-modern-gelaende.md. Owner: package terrain / props / far ground.

const Fair := preload("res://tests/race3d/fairness.gd")
const TerrainBuilder := preload("res://scripts/race3d/builders/terrain.gd")
const PropsBuilder := preload("res://scripts/race3d/builders/props.gd")
const FarGround := preload("res://scripts/race3d/layers/far_ground.gd")
const WINDOWS := 3
const WINDOW_GAP_M := 1500.0
const VISIBILITY_M := 900.0
const OVERLAP_TOLERANCE_M := 0.05
const SAME_BEND_ROWS := 120        ## 360 m of road: closer rows of one side belong to the same bend
const TIP_LIMIT_M := 3.0           ## deepest overlap of two ribbon tips of one bend that is still tolerated
const STRICT := true               ## the kernel cuts the inside ribbon also by the sharpest curvature nearby (RINT-A)
const BUDGET_TRIANGLES := 1100
const CELL_M := 160.0
## Terrain reference positions (contract §4.9.2): direction name, km.
var _details := 0                 ## --verbose: overlapping pairs still to be printed


## The members of the renderer facade (A-7) that layers/far_ground.gd reads in setup(): the dump asks the layer itself.
class DumpFacade extends Node:
	var cfg: Dictionary = {}
	var track: Track
	var world: Node3D

const REFERENCE := {"T1": ["kassel_wuerzburg__kassel", 46.5], "T2": ["kassel_wuerzburg__kassel", 61.9],
	"T3": ["saragossa_pau__saragossa", 172.8], "T4": ["saragossa_pau__saragossa", 198.8]}


func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + name:
			return "1"
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return default


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var verbose := _arg("verbose", "") != ""
	var dump := _arg("dump", "")
	_details = 24 if verbose else 0
	var names: Array = []
	names.append_array(Fair.HARDEST)
	var ref_by_dir := {}
	for id: String in REFERENCE:
		var dir_name := str(REFERENCE[id][0])
		if not names.has(dir_name):
			names.append(dir_name)
		if not ref_by_dir.has(dir_name):
			ref_by_dir[dir_name] = []
		(ref_by_dir[dir_name] as Array).append(id)
	var windows := 0
	var strips := 0
	var pairs := 0
	var overlaps := 0
	var overlaps_same_chunk := 0
	var folds := 0
	var worst := 0.0
	var worst_at := ""
	var max_tris := 0
	var chunks := 0
	var narrowest := INF
	var tips := 0
	var tip_worst := 0.0
	var tip_windows := 0
	for dir: Dictionary in Fair.directions(net, names):
		if not names.has(str(dir["name"])):
			continue
		var geo := Fair.build_geo(cfg, net, dir, net["scenery"])
		var track: Track = geo["track"]
		var spots: Array = []            # [id, camera z]
		for id: String in ref_by_dir.get(str(dir["name"]), []):
			spots.append([id, track.km_to_z(float(REFERENCE[id][1]))])
		if Fair.HARDEST.has(str(dir["name"])):
			for z: float in _tightest(geo, WINDOWS):
				spots.append(["", z])
		for spot: Array in spots:
			var res := _window(cfg, net, track, float(spot[1]), str(dir["name"]), str(spot[0]), dump)
			windows += 1
			strips += int(res["strips"])
			pairs += int(res["pairs"])
			overlaps += int(res["overlaps"])
			overlaps_same_chunk += int(res["same_chunk"])
			folds += int(res["folds"])
			chunks += int(res["chunks"])
			max_tris = maxi(max_tris, int(res["max_tris"]))
			narrowest = minf(narrowest, float(res["narrowest"]))
			tips += int(res["tips"])
			tip_worst = maxf(tip_worst, float(res["tip_worst"]))
			tip_windows += 1 if int(res["tips"]) > 0 else 0
			if float(res["worst"]) > worst:
				worst = float(res["worst"])
				worst_at = "%s km %.1f" % [str(dir["name"]), track.z_to_km(float(spot[1]))]
			if verbose:
				print("    %-36s km %6.1f %-3s %2d Stücke, %4d Streifen, %5d Paare geprüft, %d Überlappungen (%d im selben Stück), %d Faltungen, %d Bandspitzen einer Kurve (tiefste %.2f m), schmalstes Band %.0f m" % [
					str(dir["name"]), track.z_to_km(float(spot[1])), str(spot[0]), int(res["chunks"]), int(res["strips"]), int(res["pairs"]),
					int(res["overlaps"]), int(res["same_chunk"]), int(res["folds"]), int(res["tips"]), float(res["tip_worst"]), float(res["narrowest"])])
	var ok_overlap := overlaps == 0 and overlaps_same_chunk == 0 and folds == 0 and windows > 0
	print("CHECK %-22s %s  %d Kamerapositionen in %d Etappenrichtungen, %d Stücke, %d Streifen, %d Paare mit dem Trennachsen-Test: zwischen verschiedenen Straßenteilen %d Überlappungen zwischen Stücken, %d innerhalb eines Stücks, %d gefaltete Streifen%s; schmalstes Band %.0f m" % [
		"terrain_plan_overlap", "OK    " if ok_overlap else "FEHLER", windows, names.size(), chunks, strips, pairs, overlaps, overlaps_same_chunk,
		folds, "" if worst <= 0.0 else " (tiefste %.2f m bei %s)" % [worst, worst_at], narrowest])
	var ok_tips := tip_worst <= TIP_LIMIT_M and (tips == 0 or not STRICT)
	print("CHECK %-22s %s  %d Paare von Bandspitzen derselben Kurveninnenseite berühren sich an %d von %d Kamerapositionen, tiefste Überlappung %.2f m (Grenze %.1f m%s) – der Kern kürzt jede Reihe auch nach der stärksten Krümmung ihrer Seite in der Nähe" % [
		"terrain_plan_tips", "OK    " if ok_tips else "FEHLER", tips, tip_windows, windows, tip_worst, TIP_LIMIT_M, ", streng: keine erlaubt" if STRICT else ""])
	var ok_budget := max_tris <= BUDGET_TRIANGLES and chunks > 0
	print("CHECK %-22s %s  höchstens %d Geländedreiecke je Stück (Budget %d)" % ["terrain_plan_budget", "OK    " if ok_budget else "FEHLER",
		max_tris, BUDGET_TRIANGLES])
	var ok := ok_overlap and ok_tips and ok_budget
	print("==> Draufsicht-Prüfung des Geländes: %s (%.1f s)" % ["bestanden" if ok else "FEHLGESCHLAGEN", (Time.get_ticks_msec() - t0) / 1000.0])
	ModelDB.release_all()
	ModernMaterials.drop_shared()
	quit(0 if ok else 1)


## Camera positions (road z) of the `count` tightest bends of a direction, at least WINDOW_GAP_M apart.
func _tightest(geo: Dictionary, count: int) -> Array[float]:
	var curve: PackedFloat32Array = geo["curve"]
	var seg := float(geo["seg"])
	var nz := int(geo["nz"])
	var order: Array = []
	for k in range(40, nz - 400, 8):
		order.append([absf(curve[k]), k])
	order.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]) or (float(a[0]) == float(b[0]) and int(a[1]) < int(b[1])))
	var out: Array[float] = []
	for e: Array in order:
		var z := float(e[1]) * seg - 120.0      # the bend lies ahead of the camera
		var far := true
		for o: float in out:
			far = far and absf(o - z) >= WINDOW_GAP_M
		if far and z > 200.0:
			out.append(z)
			if out.size() >= count:
				break
	return out


## One camera position: builds the chunks the streamer wants and tests their strips.
func _window(cfg: Dictionary, net: Dictionary, track: Track, cam_z: float, dir_name: String, id: String, dump: String) -> Dictionary:
	var p := RoadPath3D.new()
	var tp := TerrainProfile.new()
	tp.setup(p, track, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), net["scenery"])
	var st := ChunkStreamer.new()
	st.setup(p, tp, track, cfg, {}, true)
	st.update(cam_z, VISIBILITY_M)
	var builder := TerrainBuilder.new()
	var quads: Array = []            # [chunk, side, row, PackedVector2Array of 4 corners, min, max]
	var max_tris := 0
	var folds := 0
	var narrowest := INF
	var dumped: Array = []
	var snap := st.snapshot()
	for ch: Dictionary in snap["chunks"]:
		var ctx := ChunkContext.new()
		ctx.cfg = cfg
		ctx.scenery_db = net["scenery"]
		ctx.capture(int(ch["index"]), int(ch["seg_a"]), int(ch["seg_b"]), p, tp, track)
		var part := builder.build(ctx, builder.collect(ctx))
		var verts: PackedVector3Array = part["verts"]
		var idx: PackedInt32Array = part["indices"]
		max_tris = maxi(max_tris, idx.size() / 3)
		var n := ctx.rings
		var rows := ctx.row_count()
		for si in 2:
			for i in rows - 1:
				if bool(ctx.segs[i]["tunnel"]):
					continue
				var a := verts[si * rows * n + i * n] + ctx.origin
				var b := verts[si * rows * n + i * n + n - 1] + ctx.origin
				var c := verts[si * rows * n + (i + 1) * n + n - 1] + ctx.origin
				var d := verts[si * rows * n + (i + 1) * n] + ctx.origin
				var poly := PackedVector2Array([Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z), Vector2(d.x, d.z)])
				narrowest = minf(narrowest, Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)))
				# a strip whose outer edge runs against its inner edge is folded over itself
				if (poly[2] - poly[1]).dot(poly[3] - poly[0]) < 0.0 and (poly[2] - poly[1]).length() > 0.01:
					folds += 1
				var lo := Vector2(minf(minf(poly[0].x, poly[1].x), minf(poly[2].x, poly[3].x)), minf(minf(poly[0].y, poly[1].y), minf(poly[2].y, poly[3].y)))
				var hi := Vector2(maxf(maxf(poly[0].x, poly[1].x), maxf(poly[2].x, poly[3].x)), maxf(maxf(poly[0].y, poly[1].y), maxf(poly[2].y, poly[3].y)))
				quads.append([int(ch["index"]), si, int(ch["seg_a"]) + i, poly, lo, hi])
		if dump != "" and id != "":
			dumped.append(_dump_chunk(ctx, part, track))
	# broad phase: a grid in plan view; a pair is tested in the cell that holds the lower corner of the overlap of
	# its bounding boxes
	var cells := {}
	for q in quads.size():
		var lo: Vector2 = quads[q][4]
		var hi: Vector2 = quads[q][5]
		for cx in range(int(floor(lo.x / CELL_M)), int(floor(hi.x / CELL_M)) + 1):
			for cy in range(int(floor(lo.y / CELL_M)), int(floor(hi.y / CELL_M)) + 1):
				var key := Vector2i(cx, cy)
				if not cells.has(key):
					cells[key] = []
				(cells[key] as Array).append(q)
	var pairs := 0
	var overlaps := 0
	var same_chunk := 0
	var worst := 0.0
	var tips := 0
	var tip_worst := 0.0
	for key: Vector2i in cells:
		var list: Array = cells[key]
		for u in list.size():
			var qa: Array = quads[list[u]]
			for v in range(u + 1, list.size()):
				var qb: Array = quads[list[v]]
				# neighbours along the road share an edge (the same side) or the road itself (opposite sides)
				if absi(int(qa[2]) - int(qb[2])) <= 1:
					continue
				var lo := Vector2(maxf((qa[4] as Vector2).x, (qb[4] as Vector2).x), maxf((qa[4] as Vector2).y, (qb[4] as Vector2).y))
				var hi := Vector2(minf((qa[5] as Vector2).x, (qb[5] as Vector2).x), minf((qa[5] as Vector2).y, (qb[5] as Vector2).y))
				if lo.x >= hi.x or lo.y >= hi.y:
					continue
				if Vector2i(int(floor(lo.x / CELL_M)), int(floor(lo.y / CELL_M))) != key:
					continue      # counted in another cell
				pairs += 1
				var depth := _penetration(qa[3], qb[3])
				if depth > OVERLAP_TOLERANCE_M:
					if _details > 0 and not (int(qa[1]) == int(qb[1]) and absi(int(qa[2]) - int(qb[2])) <= SAME_BEND_ROWS and depth < 1.0):
						_details -= 1
						var wa := ((qa[3] as PackedVector2Array)[0]).distance_to((qa[3] as PackedVector2Array)[1])
						var wb := ((qb[3] as PackedVector2Array)[0]).distance_to((qb[3] as PackedVector2Array)[1])
						print("        Überlappung %.3f m: Stück %d Seite %d Reihe %d (Band %.0f m)  x  Stück %d Seite %d Reihe %d (Band %.0f m)" % [depth,
							int(qa[0]), int(qa[1]), int(qa[2]), wa, int(qb[0]), int(qb[1]), int(qb[2]), wb])
					if int(qa[1]) == int(qb[1]) and absi(int(qa[2]) - int(qb[2])) <= SAME_BEND_ROWS:
						tips += 1
						tip_worst = maxf(tip_worst, depth)
						continue
					worst = maxf(worst, depth)
					if int(qa[0]) == int(qb[0]):
						same_chunk += 1
					else:
						overlaps += 1
	if dump != "" and id != "":
		_write_dump(dump, id, dir_name, track, p, st, cam_z, dumped, cfg)
	var out := {"chunks": (snap["chunks"] as Array).size(), "strips": quads.size(), "pairs": pairs, "overlaps": overlaps,
		"same_chunk": same_chunk, "folds": folds, "worst": worst, "max_tris": max_tris, "narrowest": narrowest, "tips": tips,
		"tip_worst": tip_worst}
	st.clear()
	st.free()
	return out


## Depth by which two convex polygons overlap (0 = apart or touching): the smallest overlap over the edge normals of
## both (separating-axis test).
func _penetration(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var depth := INF
	for poly: PackedVector2Array in [a, b]:
		for i in poly.size():
			var e := poly[(i + 1) % poly.size()] - poly[i]
			if e.length_squared() < 1.0e-8:
				continue
			var axis := Vector2(-e.y, e.x).normalized()
			var a0 := INF
			var a1 := -INF
			for pt in a:
				var s := pt.dot(axis)
				a0 = minf(a0, s)
				a1 = maxf(a1, s)
			var b0 := INF
			var b1 := -INF
			for pt in b:
				var s := pt.dot(axis)
				b0 = minf(b0, s)
				b1 = maxf(b1, s)
			var o := minf(a1, b1) - maxf(a0, b0)
			if o <= 0.0:
				return 0.0
			depth = minf(depth, o)
	return depth if depth < INF else 0.0


# --- top views (data only) ---------------------------------------------------------------------------------------

func _dump_chunk(ctx: ChunkContext, part: Dictionary, track: Track) -> Dictionary:
	var verts: PackedVector3Array = part["verts"]
	var n := ctx.rings
	var rows := ctx.row_count()
	var rings: Array = []
	for si in 2:
		for i in rows:
			var row: Array = []
			for r in n:
				var v := verts[si * rows * n + i * n + r] + ctx.origin
				row.append([snappedf(v.x, 0.01), snappedf(v.z, 0.01), snappedf(v.y, 0.01)])
			rings.append(row)
	var road: Array = []
	for i in rows:
		var o := ctx.rows_o[i] + ctx.origin
		var r := ctx.rows_r[i]
		var e := ctx.rows_edge[i]
		road.append([snappedf(o.x + r.x * e.x, 0.01), snappedf(o.z + r.z * e.x, 0.01), snappedf(o.x + r.x * e.y, 0.01), snappedf(o.z + r.z * e.y, 0.01),
			snappedf(o.y, 0.01), 1 if bool(ctx.segs[i]["tunnel"]) else 0, 1 if bool(ctx.segs[i]["water"]) else 0])
	# props: what the props builder draws and what it leaves out
	var pb := PropsBuilder.new()
	var input: Dictionary = pb.collect(ctx)
	var props: Array = []
	for i in rows - 1:
		var seg: Dictionary = ctx.segs[i]
		var sprites: Array = seg["sprites"]
		for j in sprites.size():
			var it: Dictionary = sprites[j]
			var set_id := PropsBuilder.item_set(it, input)
			if set_id == "":
				continue
			var e: Dictionary = (input["sets"] as Dictionary).get(set_id, {})
			if e.is_empty() or int(e["kind"]) == PropLibrary.NONE:
				e = (input["sets"] as Dictionary).get(str(it.get("fallback", "")), {})
			if e.is_empty() or int(e["kind"]) == PropLibrary.NONE:
				continue
			var side := int(it.get("side", 1))
			var z := float(it.get("z", seg["z"]))
			var x := float(it.get("x", 0.0))
			var reason := PropsBuilder.drop_reason(ctx, it, e, z, x, side, int(seg["index"]), j, 1.0, [])
			var w := ctx.local(z, x, 0.0) + ctx.origin
			props.append([snappedf(w.x, 0.01), snappedf(w.z, 0.01), str(e["cls"]), reason, int(e["kind"])])
	return {"index": ctx.index, "rings": rings, "ring_count": n, "rows": rows, "road": road, "props": props,
		"scenery": str(ctx.segs[0]["scenery"])}


func _write_dump(folder: String, id: String, dir_name: String, track: Track, p: RoadPath3D, st: ChunkStreamer, cam_z: float,
		chunks: Array, cfg: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var proj := Fair.make_projection(cfg)
	var cam := Fair.make_camera(cfg, proj)
	var view := {"camera_z": cam_z, "camera_x": 0.0, "camera_y": p.height_at(cam_z + proj.cam_distance) + proj.cam_height}
	var tr := cam.transform(view, p)
	var fwd := -tr.basis.z
	# the far-ground plane where the layer puts it (FIX-WASSER-R, QA-WASSER B5): its own rule – below the lowest road
	# AND below the lowest water of the loaded window – through a stand-in of the renderer facade
	var facade := DumpFacade.new()
	facade.cfg = cfg
	facade.track = track
	var far := FarGround.new()
	far.setup(facade)
	var far_y: float = far.target_height(p, track, cam_z, VISIBILITY_M)
	far.free()
	facade.free()
	var data := {"id": id, "direction": dir_name, "km": track.z_to_km(cam_z), "camera": [tr.origin.x, tr.origin.z, tr.origin.y],
		"forward": [fwd.x, fwd.z], "far_y": far_y, "visibility_m": VISIBILITY_M, "chunks": chunks}
	var f := FileAccess.open(folder.path_join("plan_%s.json" % id), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()
