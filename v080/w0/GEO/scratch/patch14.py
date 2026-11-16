root = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-4/'
p = root + 'scripts/race3d/chunk_streamer.gd'
s = open(p).read()

a = '''## Per update(cam_z, visibility_m):
##  * the path is extended landmark_path_m ahead of the camera, trimmed far behind it and re-based when the camera
##    is more than rebase_m from the floating origin (signal rebased(shift): every origin-relative position the
##    renderer keeps moves by shift; the chunk nodes are moved here),
##  * a chunk is wanted when its near edge is at most load_path_m of path ahead AND at most
##    visibility + one chunk length away by air; at most max_chunks are held (when the rule wants more, the
##    farthest by air – in the fog at the end of the visibility – wait); a chunk is freed once its far edge lies
##    more than keep_behind_m behind the camera,
##  * a new chunk is collected on the main thread (ChunkContext.capture + ChunkBuilder.collect), built on the
##    WorkerThreadPool (ChunkBuilder.build) and committed on the main thread (ChunkBuilder.commit), at most
##    commits_per_frame chunks per update. The first update after a start or a camera jump loads everything that is
##    wanted at once (behind the loading overlay). With sync = true (--gfx-sync, tests) every update builds and
##    commits everything at once on the main thread, so the result depends on the camera position only.
## Before a chunk is collected the road is integrated clear_reach_m beyond it (RoadPath3D.clearance needs every part
## of the road that can be loaded together with it); that forces the Track generation ahead, which is harmless.
## Config: graphics.modern {chunk_segments, load_path_m, landmark_path_m, keep_behind_m, threaded_build,
## commits_per_frame, max_chunks, rebase_m}; levels: terrain_outer_m.
## Owner: race3d kernel. Docs: docs/renderer-modern.md.'''
b = '''## Per update(cam_z, visibility_m):
##  * the path is kept integrated load_path_m + one chunk + clear_reach_m ahead of the camera (3,438 m with the
##    shipped values, at least landmark_path_m; it grows by a segment per frame), trimmed far behind it and re-based
##    when the camera is more than rebase_m from the floating origin (signal rebased(shift): every origin-relative
##    position the renderer keeps moves by shift; the chunk nodes are moved here),
##  * a chunk is wanted when its near edge is at most load_path_m of path ahead AND at most
##    visibility + one chunk length away by air; at most max_chunks are held (when the rule wants more, the
##    farthest by air wait); a chunk is freed once its far edge lies more than keep_behind_m behind the camera,
##  * a new chunk is collected on the main thread (ChunkContext.capture + ChunkBuilder.collect), built on the
##    WorkerThreadPool (ChunkBuilder.build) and committed on the main thread (ChunkBuilder.commit): per update one
##    chunk is collected or at most commits_per_frame are committed. The first update after a start or a camera
##    jump loads everything that is wanted at once (behind the loading overlay). With sync = true (--gfx-sync,
##    tests) every update builds and commits everything at once on the main thread, so the result depends on the
##    camera position only.
## The path reaches that far because RoadPath3D.clearance needs every part of the road that can be loaded together
## with a chunk; it forces the Track generation ahead, which is harmless (the generator is sequential).
## Config: graphics.modern {chunk_segments, load_path_m, landmark_path_m, keep_behind_m, threaded_build,
## commits_per_frame, max_chunks, rebase_m}; levels: terrain_outer_m.
## Owner: race3d kernel. Docs: docs/renderer-modern.md.'''
assert a in s
s = s.replace(a, b)

a = '''## Adds a builder (before the first update). Its parts appear in every chunk in registration order.
func register(builder: ChunkBuilder) -> void:
	if builder != null:
		_builders.append(builder)
'''
b = '''## Adds a builder. Its parts appear in every chunk in registration order; chunks that exist already are dropped
## and built again with it.
func register(builder: ChunkBuilder) -> void:
	if builder == null:
		return
	if not _chunks.is_empty():
		clear()
	_builders.append(builder)
'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)
print('patched')
