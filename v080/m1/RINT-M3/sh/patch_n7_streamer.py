import sys
W = sys.argv[1]


def sub(path, old, new, count=1):
    p = W + '/' + path
    s = open(p, encoding='utf-8').read()
    assert old in s, (path, old[:90])
    s = s.replace(old, new, count)
    open(p, 'w', encoding='utf-8').write(s)


S = 'scripts/race3d/chunk_streamer.gd'
sub(S, '''	var commit_i := 0          ## next builder to commit (COMMITTING)
''', '''	var commit_i := 0          ## next builder to commit (COMMITTING)
	var commit_k := 0          ## A-28 (RINT-M3): next step of that builder (ChunkBuilder.commit_steps())
''')
# _commit: whole chunk (or the rest)
sub(S, '''	for i in range(c.commit_i, _builders.size()):
		_commit_builder(c, i, node)
	c.commit_i = _builders.size()''', '''	for i in range(c.commit_i, _builders.size()):
		var steps := _steps_of(c, i)
		for k in range(c.commit_k if i == c.commit_i else 0, steps):
			_commit_piece(c, i, k, node)
	c.commit_i = _builders.size()
	c.commit_k = 0''')
sub(S, '''## B-01: commits builders of chunk c (BUILT or begun) while the frame's commit time since frame_t0 is below budget_us –
## at least one per frame. The node enters the tree when the last builder is done.''', '''## B-01: commits builders of chunk c (BUILT or begun) while the frame's commit time since frame_t0 is below budget_us –
## at least one per frame. The node enters the tree when the last builder is done. A-28 (RINT-M3): the unit is one
## commit step of a builder (ChunkBuilder.commit_steps(): road, terrain and roadside split a large mesh into pieces),
## so a single large builder no longer takes the whole frame's budget at once.''')
sub(S, '''		c.node = node
		c.commit_i = 0
		c.state = COMMITTING
	var first := _frame_commit_us == 0     # at least one builder per frame
	while c.commit_i < _builders.size():
		# the next builder only when its mean commit time so far still fits (one builder may exceed the budget alone)
		if not first and Time.get_ticks_usec() - frame_t0 + _commit_estimate(c.commit_i) > budget_us:
			break
		_commit_builder(c, c.commit_i, c.node)
		c.commit_i += 1
		first = false''', '''		c.node = node
		c.commit_i = 0
		c.commit_k = 0
		c.state = COMMITTING
	var first := _frame_commit_us == 0     # at least one step per frame
	while c.commit_i < _builders.size():
		# the next step only when the mean commit time of a step of that builder so far still fits (one step may
		# exceed the budget alone)
		if not first and Time.get_ticks_usec() - frame_t0 + _commit_estimate(c.commit_i) > budget_us:
			break
		_commit_piece(c, c.commit_i, c.commit_k, c.node)
		c.commit_k += 1
		if c.commit_k >= _steps_of(c, c.commit_i):
			c.commit_i += 1
			c.commit_k = 0
		first = false''')
sub(S, '''## Mean commit() time of builder i so far in µs (0 before its first commit).''', '''## Mean time of one commit step of builder i so far in µs (0 before its first commit).''')
sub(S, '''func _commit_builder(c: Chunk, i: int, node: Node3D) -> void:
	var b0 := Time.get_ticks_usec()
	var b := _builders[i] as ChunkBuilder
	b.commit(c.ctx, c.parts[i], node)
	var us := Time.get_ticks_usec() - b0''', '''## A-28: the number of commit steps of builder i for chunk c (at least 1).
func _steps_of(c: Chunk, i: int) -> int:
	return maxi(1, (_builders[i] as ChunkBuilder).commit_steps(c.parts[i]))


## One commit step k of builder i; commit_by counts steps (sum, max, number) per builder id.
func _commit_piece(c: Chunk, i: int, k: int, node: Node3D) -> void:
	var b0 := Time.get_ticks_usec()
	var b := _builders[i] as ChunkBuilder
	b.commit_step(c.ctx, c.parts[i], node, k)
	var us := Time.get_ticks_usec() - b0''')
# corridor warming as its own part of update()
sub(S, '''	if not collected and not _commit_pending():
		_warm_corridor(cam_seg)   # A-17: a frame with nothing to collect or commit computes some sight corridor ahead
''', '''	if not collected and not _commit_pending():
		_warm_corridor(cam_seg)   # A-17: a frame with nothing to collect or commit computes some sight corridor ahead
		tu = _part_us("warm", tu)  # A-28 (RINT-M3, NACH-R7a NR7a-03): booked as its own part, not as "commit"
''')
print("ok streamer")

B = 'scripts/race3d/chunk_builder.gd'
p = W + '/' + B
s = open(p, encoding='utf-8').read()
s = s.replace('''## Owner: race3d kernel. Docs: docs/renderer-modern.md.
''', '''## A-28 (RINT-M3): a builder whose commit can exceed the frame's budget alone splits it into steps (commit_steps(),
## commit_step(); split_arrays() for one large mesh) – the chunk becomes visible only when every step is done.
## Owner: race3d kernel. Docs: docs/renderer-modern.md.

## A-28: a mesh is split into pieces of at most about this many vertices (pieces_for()), at most PIECES_MAX
const PIECE_VERTICES := 6000
const PIECES_MAX := 4
''', 1)
s += open(sys.argv[2], encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s)
print("ok builder")
