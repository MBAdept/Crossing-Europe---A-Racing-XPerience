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
## Owner: race3d kernel. Docs: docs/renderer-modern.md.


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
