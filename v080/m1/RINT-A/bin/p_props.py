import os
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1')
p = 'scripts/race3d/builders/props.gd'
s = open(p).read()
a = s.index('func build(ctx: ChunkContext, input: Variant) -> Dictionary:')
b = s.index('## Set id an item of TrackSegment.sprites is drawn with here')
new_build = '''func build(ctx: ChunkContext, input: Variant) -> Dictionary:
	var inp: Dictionary = input if input is Dictionary else {}
	# out: what the chunk part collects – groups: key -> {"model" | "set", "mirror", "buf": PackedFloat32Array, "n"}
	var out := {"groups": {}, "blobs": PackedFloat32Array(), "blob_n": 0, "lamps": [], "list": [], "cover_list": [], "counts": {},
		"dropped": {"ribbon": 0, "corridor": 0, "missing": 0, "density": 0}}
	var rows := ctx.row_count()
	for i in rows - 1:
		var seg: Dictionary = ctx.segs[i]
		var sprites: Array = seg["sprites"]
		for j in sprites.size():
			_place(ctx, inp, out, i, seg, j, sprites[j], false)
	return {"groups": out["groups"], "blobs": out["blobs"], "blob_n": out["blob_n"], "lamps": out["lamps"], "list": out["list"],
		"cover_list": out["cover_list"], "counts": out["counts"], "dropped": out["dropped"],
		"z0": float(ctx.seg_a) * ctx.seg_len, "z1": float(ctx.seg_b) * ctx.seg_len}


## One item of a segment (row i of the chunk, item j of TrackSegment.sprites) into the part `out` (build(), worker
## thread). is_cover: a piece of ground cover that stands in for a dropped plant (the list "cover_list", not "list").
static func _place(ctx: ChunkContext, inp: Dictionary, out: Dictionary, i: int, seg: Dictionary, j: int, it: Dictionary,
		is_cover: bool) -> void:
	var sets: Dictionary = inp.get("sets", {})
	var models: Dictionary = inp.get("models", {})
	var density := float(inp.get("density", 1.0))
	var casters := int(inp.get("casters", 2))
	var cover: Array = inp.get("cover", [])
	var cover_max_h := float(inp.get("cover_max_h", 0.5))
	var dropped: Dictionary = out["dropped"]
	var seg_index := int(seg["index"])
	var set_id := item_set(it, inp)
	if set_id == "":
		return
	var sc := float(it.get("scale", 1.0))
	var tint := Color(str(it["tint"])) if it.has("tint") else Color.WHITE
	var e: Dictionary = sets.get(set_id, {})
	if e.is_empty() or int(e["kind"]) == PropLibrary.NONE:
		var fb := str(it.get("fallback", ""))
		e = sets.get(fb, {}) if fb != "" else {}
		if e.is_empty() or int(e["kind"]) == PropLibrary.NONE:
			if not is_cover:
				dropped["missing"] += 1
			return
		sc *= float(it.get("fallback_scale", 1.0))
		if it.has("fallback_tint"):
			tint *= Color(str(it["fallback_tint"]))
	if it.has("fit_w"):
		sc = float(it["fit_w"]) / maxf(0.5, float(e["width"]))      # overhead structures span the whole deck
	var side := int(it.get("side", 1))
	var z := float(it.get("z", seg["z"]))
	var x := float(it.get("x", 0.0))
	var landmark := bool(it.get("landmark", false))
	var is_model := int(e["kind"]) == PropLibrary.MODEL
	var flipped := side < 0 and not landmark and (bool(e["mirror_left"]) or (not is_model and bool(it.get("mirror", false))))
	if it.has("align") and side != 0:
		x = edge_anchor_x(x, side, flipped, float(e["extent_l"]), float(e["extent_r"]), sc)
	var reason := drop_reason(ctx, it, e, z, x, side, seg_index, j, density, cover)
	if reason != "":
		if is_cover:
			return
		dropped[reason] += 1
		if reason == "corridor" and bool(e["veg"]) and not cover.is_empty():
			# A-3 (lead decision): ground cover of at most 0.5 m stands in for the plant the sight corridor drops
			for c: Dictionary in cover_pieces(ctx, it, e, z, x, side, seg_index, j, cover, sets):
				_place(ctx, inp, out, i, seg, int(c["j"]), c, true)
		return
	if side != 0 and not it.has("offset") and cover.has(str(e["set"])) and ctx.in_bend_corridor(z, x):
		sc = minf(sc, cover_max_h / maxf(0.01, float(e["height"])))   # ground cover inside the corridor
	var h := 0.0
	if it.has("h"):
		h = float(it["h"])              # given relative to the road (ships on the water)
	elif not it.has("bridge"):
		h = ctx.ground(z, x)
	var key := ""
	var model_id := ""
	var tr: Transform3D
	if is_model:
		model_id = chunk_variant(ctx.index, str(e["set"]), e["variants"])
		var yaw := hash01(seg_index, j, 5) * TAU if bool(e["veg"]) or str(e["cls"]) == "rock" else 0.0
		tr = ctx.frame(z, x, h, yaw).scaled_local(Vector3(sc, sc, sc))
		key = "m|%s|%d" % [model_id, 1 if flipped else 0]
		var lamps: Array = out["lamps"]
		for lamp: Dictionary in (models.get(model_id, {}) as Dictionary).get("lamps", []):
			var lp: Vector3 = lamp["pos"]
			var ld: Vector3 = lamp["dir"]
			if flipped:
				lp.x = -lp.x
				ld.x = -ld.x
			var entry := lamp.duplicate()
			entry["pos"] = tr * lp
			entry["dir"] = (tr.basis * ld).normalized()
			entry["size"] = float(lamp["size"]) * sc
			lamps.append(entry)
	else:
		tr = Transform3D(Basis.from_scale(Vector3(sc, sc, sc)), ctx.local(z, x, h))
		key = "s|%s|%d" % [str(e["set"]), 1 if flipped else 0]
	var groups: Dictionary = out["groups"]
	var g: Dictionary = groups.get(key, {})
	if g.is_empty():
		g = {"model": model_id, "set": str(e["set"]), "mirror": flipped, "buf": PackedFloat32Array(), "n": 0}
		groups[key] = g
	var buf: PackedFloat32Array = g["buf"]
	_put(buf, mirror_x(tr) if flipped else tr)
	if not is_model:
		buf.append_array(PackedFloat32Array([tint.r, tint.g, tint.b, 1.0]))
	g["buf"] = buf
	g["n"] = int(g["n"]) + 1
	# contact shadow on the ground plane under the prop
	if float(e["blob"]) > 0.0 and not it.has("h") and not it.has("bridge") and not landmark:
		var w := float(e["width"]) * sc
		var r := maxf(0.3, w * (0.45 if str(e["cls"]) == "tree" else 0.55))
		var p0 := ctx.local(z, x, h)
		var px := ctx.local(z, x + SLOPE_PROBE_M, ctx.ground(z, x + SLOPE_PROBE_M))
		var pz := ctx.local(z + SLOPE_PROBE_M, x, ctx.ground(z + SLOPE_PROBE_M, x))
		var tx := (px - p0).normalized()
		var n := tx.cross(pz - p0).normalized()
		if n.y < 0.2:
			n = Vector3.UP
			tx = ctx.rows_r[i]
		var tz := tx.cross(n).normalized()
		var blobs: PackedFloat32Array = out["blobs"]
		_put(blobs, Transform3D(Basis(tx * r, n, tz * r), p0 + n * BLOB_LIFT_M))
		var real := 1.0 if is_model and casters >= int(e["cast"]) else 0.0
		blobs.append_array(PackedFloat32Array([float(e["height"]) / maxf(0.1, float(e["width"])), float(e["blob"]), real, 0.0]))
		out["blobs"] = blobs
		out["blob_n"] = int(out["blob_n"]) + 1
	var counts: Dictionary = out["counts"]
	counts[str(e["set"]) if is_cover else set_id] = int(counts.get(str(e["set"]) if is_cover else set_id, 0)) + 1
	(out["cover_list"] if is_cover else out["list"]).append([seg_index, j, str(e["set"]), snappedf(x, 0.001), snappedf(z, 0.001),
		snappedf(sc, 0.0001), 1 if flipped else 0, int(e["kind"])])


## Variant model of a set in a chunk (§4.6.6 variants): ONE per chunk and set, by a stable hash of the chunk index and
## the set – every instance of the set in the chunk shares the seed variant, so a set costs one node per mirror state
## and at most its surfaces in draw calls per chunk (two for a card tree) instead of that per variant. The trees of
## neighbouring chunks differ; inside a chunk the random yaw per tree hides the repetition.
static func chunk_variant(chunk_index: int, set_id: String, variants: Array) -> String:
	if variants.is_empty():
		return ""
	var k := int(hash01(chunk_index, set_id.hash() & 0xffff, 3) * float(variants.size())) % variants.size()
	return str(variants[k])


## Ground cover for a plant the sight corridor of a bend drops (amendment A-3, lead decision): pieces of the sets of
## graphics.modern.props.bend_cover (props/cover_bush, props/cover_grass: at most 0.5 m – they cannot hide a vehicle
## from the 3.4 m eye) – one for a bush, COVER_PER_TREE scattered over the crown's footprint for a tree. Pieces that
## would lie on the shoulder are left out; the ribbon test of drop_reason() applies to each. Plain items for _place().
static func cover_pieces(ctx: ChunkContext, it: Dictionary, e: Dictionary, z: float, x: float, side: int, seg_index: int, item: int,
		cover: Array, sets: Dictionary) -> Array:
	var usable: Array = []
	for c: Variant in cover:
		var ce: Dictionary = sets.get(str(c), {})
		if not ce.is_empty() and int(ce["kind"]) == PropLibrary.MODEL:
			usable.append(str(c))
	if usable.is_empty() or side == 0:
		return []
	var n := COVER_PER_TREE if str(e["cls"]) == "tree" else 1
	var spread := clampf(float(e["width"]) * float(it.get("scale", 1.0)) * 0.35, 0.0, COVER_SPREAD_M)
	var out: Array = []
	for k in n:
		var dz := (hash01(seg_index, item * 8 + k, 13) - 0.5) * 2.0 * spread if n > 1 else 0.0
		var dx := (hash01(seg_index, item * 8 + k, 17) - 0.5) * 2.0 * spread if n > 1 else 0.0
		var px := x + dx
		var pz := z + dz
		var row := clampi(int(floor(ctx.row_of(pz))), 0, ctx.row_count() - 1)
		if absf(px) - ctx.shoulder_edge(row, side) < COVER_MIN_BEYOND_M:
			continue
		var set_id := str(usable[int(hash01(seg_index, item * 8 + k, 19) * float(usable.size())) % usable.size()])
		out.append({"kind": "prop", "set": set_id, "side": side, "x": px, "z": pz,
			"scale": lerpf(0.8, 1.15, hash01(seg_index, item * 8 + k, 23)), "j": COVER_ITEM_BASE + item * 8 + k})
	return out


'''
s = s[:a] + new_build + s[b:]
# constants
old = '''const LOD_STEP_M := 2.0            ## update() looks at the chunk levels again after this much driving
'''
new = '''const LOD_STEP_M := 2.0            ## update() looks at the chunk levels again after this much driving
const COVER_PER_TREE := 3          ## pieces of ground cover for a tree dropped in a bend corridor (one for a bush)
const COVER_SPREAD_M := 2.5        ## … scattered at most this far around its foot
const COVER_MIN_BEYOND_M := 0.8    ## … and never closer than this to the paved edge
const COVER_ITEM_BASE := 100000    ## item numbers of the pieces (hashes, lists): beyond every real item
'''
assert s.count(old) == 1
s = s.replace(old, new)
open(p, 'w').write(s)
print('ok')
