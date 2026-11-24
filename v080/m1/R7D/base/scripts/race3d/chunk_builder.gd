class_name ChunkBuilder
extends RefCounted
## Kernel of the mode "Modern" (v0.8.0): base class of everything that builds a part of a road chunk
## (scripts/race3d/builders/<name>.gd, listed in BuilderRegistry). One instance per renderer builds every chunk.
##
## Per chunk the ChunkStreamer calls, in this order:
##   collect(ctx)        main thread: a cheap extra snapshot of whatever build() needs beyond the ChunkContext
##                       (plain data only; may read ctx.path, ctx.terrain, ctx.track), or null
##   build(ctx, input)   WORKER THREAD (main thread in sync mode): arrays and plain data only – no nodes, no
##                       resources, no autoloads, no Track, no ctx.path / ctx.terrain / ctx.track
##   commit(ctx, part, parent)   main thread: ArrayMesh / MultiMesh / nodes under `parent` (the chunk node)
## and for debug_snapshot(): debug(part) -> plain data.
##
## Rules (they keep the fallback mapping of the contract possible): positions only through ChunkContext.local() /
## frame() / ground() (or RoadPath3D on the main thread); the chunk node's transform belongs to the streamer and is
## not static; rigid instances are placed with ChunkContext.frame(). A builder keeps no per-chunk state in itself –
## build() may run for several chunks at the same time.
## A-28 (RINT-M3): a builder whose commit can exceed the frame's budget alone splits it into steps (commit_steps(),
## commit_step(); split_arrays() for one large mesh) – the chunk becomes visible only when every step is done.
## Owner: race3d kernel. Docs: docs/renderer-modern.md.

## A-28: a mesh is split into pieces of at most about this many vertices (pieces_for()), at most PIECES_MAX –
## measured (Xvfb, llvmpipe, Kiel – Hamburg, probe commit_cost.gd): one commit of a roadside part (≈ 2.850 vertices) costs
## 0.21 ms median, in two pieces 0.10 ms each; road (≤ 900) 0.02 ms and terrain (≤ 600) 0.07 ms stay whole
const PIECE_VERTICES := 2000
const PIECES_MAX := 4


## Fixed id of the builder (= its file name without ".gd"); the key of its part in snapshots.
func id() -> String:
	return ""


func collect(_ctx: ChunkContext) -> Variant:
	return null


func build(_ctx: ChunkContext, _input: Variant) -> Dictionary:
	return {}


func commit(_ctx: ChunkContext, _part: Dictionary, _parent: Node3D) -> void:
	pass


func debug(_part: Dictionary) -> Dictionary:
	return {}


## A-28 (RINT-M3): commit in parts. A builder whose commit() can exceed the frame's budget on its own (one large
## ArrayMesh: the upload of its arrays) splits its part into pieces in build() (worker thread) and commits one piece per
## step – the streamer calls commit_steps(part) and commit_step(ctx, part, parent, k) for k = 0 .. steps − 1 (a builder
## without them commits in one step), and the chunk becomes visible only when every step of every builder is done.

## Number of commit steps of a built part (1: commit() does all of it).
func commit_steps(_part: Dictionary) -> int:
	return 1


## Step k of the commit of a part (k < commit_steps(part)); the default is the whole commit() at k = 0.
func commit_step(ctx: ChunkContext, part: Dictionary, parent: Node3D, k: int) -> void:
	if k == 0:
		commit(ctx, part, parent)


## Pieces for a mesh of `vertices` vertices: one per PIECE_VERTICES started, at most PIECES_MAX.
static func pieces_for(vertices: int, piece_vertices: int = PIECE_VERTICES) -> int:
	return clampi(int(ceil(float(vertices) / float(maxi(piece_vertices, 1)))), 1, PIECES_MAX)


## Splits the arrays of an indexed triangle mesh (Mesh.ARRAY_* layout, ARRAY_INDEX set) into `pieces` meshes of about
## equal triangle counts (pure, worker-safe): piece p keeps the triangles [p × n / pieces, (p + 1) × n / pieces) and the
## vertex range they use (min .. max index, re-based to 0) of every per-vertex array – also the CUSTOM arrays, whatever
## their number of floats per vertex. The same triangles, vertices and attributes as the whole: drawn with one material
## the pieces give the same picture as the whole mesh. One piece (or no index): [arrays].
static func split_arrays(arrays: Array, pieces: int) -> Array:
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
	var tris := idx.size() / 3
	if pieces <= 1 or tris < pieces * 2:
		return [arrays]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nv := verts.size()
	var out: Array = []
	for p in pieces:
		var t0 := tris * p / pieces
		var t1 := tris * (p + 1) / pieces
		var sub := idx.slice(t0 * 3, t1 * 3)
		var lo := nv
		var hi := -1
		for v: int in sub:
			lo = mini(lo, v)
			hi = maxi(hi, v)
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		for k in Mesh.ARRAY_MAX:
			if k == Mesh.ARRAY_INDEX or k >= arrays.size() or arrays[k] == null:
				continue
			var src: Variant = arrays[k]
			var per := 0
			match typeof(src):
				TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_COLOR_ARRAY:
					per = 1
				TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY:
					per = (src.size() / nv) if nv > 0 else 0
			if per <= 0:
				a[k] = src
				continue
			a[k] = src.slice(lo * per, (hi + 1) * per)
		for i in sub.size():
			sub[i] -= lo
		a[Mesh.ARRAY_INDEX] = sub
		out.append(a)
	return out
