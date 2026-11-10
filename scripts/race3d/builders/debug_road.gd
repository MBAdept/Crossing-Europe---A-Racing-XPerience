extends ChunkBuilder
## Debug road of the race3d kernel (v0.8.0): a plain vertex-colour road – asphalt, shoulders, edge lines – and the
## terrain rings of the TerrainProfile, unshaded, one mesh per chunk. It stands in for builders/road.gd until that
## exists (BuilderRegistry.create_all) and is the example of the three builder rules: every vertex comes from
## ChunkContext.local(), nothing depends on the chunk node's transform, nothing is cached in world space.
## Owner: race3d kernel.

const ASPHALT := Color(0.30, 0.31, 0.34)
const ASPHALT_ALT := Color(0.33, 0.34, 0.37)
const TUNNEL_ROAD := Color(0.24, 0.24, 0.26)
const SHOULDER := Color(0.47, 0.46, 0.42)
const LINE := Color(0.92, 0.92, 0.88)
const GRASS := Color(0.33, 0.52, 0.24)
const GRASS_ALT := Color(0.30, 0.48, 0.22)
const WATER := Color(0.24, 0.36, 0.44)
const EDGE_LINE_IN_M := 0.15       ## edge line from 0.15 m to 0.45 m inside the paved edge
const EDGE_LINE_OUT_M := 0.45
const LINE_LIFT_M := 0.02

var terrain_rings := true          ## also draw the terrain ribbon
var _material: StandardMaterial3D


func id() -> String:
	return "debug_road"


func build(ctx: ChunkContext, _input: Variant) -> Dictionary:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var rows := ctx.row_count()
	var sh := ctx.shoulder_w
	for i in rows - 1:
		var sa: Dictionary = ctx.segs[i]
		var z0 := float(ctx.seg_a + i) * ctx.seg_len
		var z1 := z0 + ctx.seg_len
		var ea := ctx.rows_edge[i]
		var eb := ctx.rows_edge[i + 1]
		var tunnel := bool(sa["tunnel"])
		var road := TUNNEL_ROAD if tunnel else (ASPHALT if (int(sa["index"]) / 2) % 2 == 0 else ASPHALT_ALT)
		# shoulders and asphalt
		_strip(ctx, verts, cols, idx, z0, z1, ea.x - sh, ea.x, eb.x - sh, eb.x, 0.0, SHOULDER)
		_strip(ctx, verts, cols, idx, z0, z1, ea.x, ea.y, eb.x, eb.y, 0.0, road)
		_strip(ctx, verts, cols, idx, z0, z1, ea.y, ea.y + sh, eb.y, eb.y + sh, 0.0, SHOULDER)
		# edge lines (a little above the asphalt)
		_strip(ctx, verts, cols, idx, z0, z1, ea.x + EDGE_LINE_IN_M, ea.x + EDGE_LINE_OUT_M, eb.x + EDGE_LINE_IN_M,
			eb.x + EDGE_LINE_OUT_M, LINE_LIFT_M, LINE)
		_strip(ctx, verts, cols, idx, z0, z1, ea.y - EDGE_LINE_OUT_M, ea.y - EDGE_LINE_IN_M, eb.y - EDGE_LINE_OUT_M,
			eb.y - EDGE_LINE_IN_M, LINE_LIFT_M, LINE)
		if not terrain_rings or tunnel or ctx.rings < 2:
			continue
		var ground := WATER if bool(sa["water"]) else (GRASS if (int(sa["index"]) / 4) % 2 == 0 else GRASS_ALT)
		for side: int in [-1, 1]:
			var base_a := ctx.shoulder_edge(i, side)
			var base_b := ctx.shoulder_edge(i + 1, side)
			for r in ctx.rings - 1:
				var xa0 := float(side) * (base_a + ctx.ring_offset(i, side, r))
				var xa1 := float(side) * (base_a + ctx.ring_offset(i, side, r + 1))
				var xb0 := float(side) * (base_b + ctx.ring_offset(i + 1, side, r))
				var xb1 := float(side) * (base_b + ctx.ring_offset(i + 1, side, r + 1))
				var o := verts.size()
				verts.append(ctx.local(z0, xa0, ctx.ring_height(i, side, r)))
				verts.append(ctx.local(z0, xa1, ctx.ring_height(i, side, r + 1)))
				verts.append(ctx.local(z1, xb1, ctx.ring_height(i + 1, side, r + 1)))
				verts.append(ctx.local(z1, xb0, ctx.ring_height(i + 1, side, r)))
				var c := ground.darkened(0.035 * float(r))
				for q in 4:
					cols.append(c)
				for q: int in [0, 1, 2, 0, 2, 3]:
					idx.append(o + q)
	var box := AABB()
	if verts.size() > 0:
		box = AABB(verts[0], Vector3.ZERO)
		for v in verts:
			box = box.expand(v)
	return {"verts": verts, "colors": cols, "indices": idx, "aabb": box}


## One quad between two rows: lateral x0..x1 on the near row (a) and on the far row (b), h above the road.
func _strip(ctx: ChunkContext, verts: PackedVector3Array, cols: PackedColorArray, idx: PackedInt32Array, z0: float, z1: float,
		xa0: float, xa1: float, xb0: float, xb1: float, h: float, col: Color) -> void:
	var o := verts.size()
	verts.append(ctx.local(z0, xa0, h))
	verts.append(ctx.local(z0, xa1, h))
	verts.append(ctx.local(z1, xb1, h))
	verts.append(ctx.local(z1, xb0, h))
	for q in 4:
		cols.append(col)
	for q: int in [0, 1, 2, 0, 2, 3]:
		idx.append(o + q)


func commit(_ctx: ChunkContext, part: Dictionary, parent: Node3D) -> void:
	var verts: PackedVector3Array = part.get("verts", PackedVector3Array())
	if verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = part["colors"]
	arrays[Mesh.ARRAY_INDEX] = part["indices"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.name = "DebugRoad"
	mi.mesh = mesh
	mi.material_override = _material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func debug(part: Dictionary) -> Dictionary:
	var verts: PackedVector3Array = part.get("verts", PackedVector3Array())
	var idx: PackedInt32Array = part.get("indices", PackedInt32Array())
	var box: AABB = part.get("aabb", AABB())
	var q := PackedInt32Array()
	q.resize(verts.size() * 3)
	for i in verts.size():
		var v := verts[i]
		q[i * 3] = int(round(v.x * 1000.0))
		q[i * 3 + 1] = int(round(v.y * 1000.0))
		q[i * 3 + 2] = int(round(v.z * 1000.0))
	return {"vertices": verts.size(), "triangles": idx.size() / 3, "checksum": hash(q),
		"aabb": [snappedf(box.position.x, 0.001), snappedf(box.position.y, 0.001), snappedf(box.position.z, 0.001),
			snappedf(box.size.x, 0.001), snappedf(box.size.y, 0.001), snappedf(box.size.z, 0.001)]}
