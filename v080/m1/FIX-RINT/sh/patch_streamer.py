import sys
p = sys.argv[1]
s = open(p).read()


def rep(old, new):
    global s
    assert old in s, old[:80]
    s = s.replace(old, new, 1)


rep('''const COMMITTED := 3
''', '''const COMMITTED := 3
const COMMITTING := 4      ## FIX-RINT (B-01): in the tree, hidden, some builders still to commit
## FIX-RINT (QA-RINT-SYSTEM B-01): §4.10 allows 3 ms of chunk commit per frame ("Steam Deck", „Niedrig“, „Mittel“);
## whole chunks took 3.8–9.0 ms at most (mean 1.0–1.3 ms) in every measurement since the base. In the threaded mode a
## chunk is now committed builder by builder over several frames: a frame commits builders while its commit time is
## below COMMIT_BUDGET_MS (at least one builder per frame). The chunk node hangs in the tree, hidden, from the first
## step (the lamp layers keep its lamps – the flare layer drops a parent that is out of the tree) and is shown once
## every builder has committed; chunk_node() answers only then. Load and sync mode (flush()) commit whole chunks.
const COMMIT_BUDGET_MS := 2.0
''')
rep('''	var node: Node3D
	var build_us := 0
''', '''	var node: Node3D
	var build_us := 0
	var commit_i := 0          ## next builder to commit (COMMITTING)
''')
rep('''var _commit_us_max := 0
var _commit_us_sum := 0
var _commits := 0
''', '''var _commit_us_max := 0
var _commit_us_sum := 0
var _commits := 0
var _commit_steps := 0
var _frame_commit_us := 0          ## FIX-RINT: commit time of the current frame (all steps of one update())
## FIX-RINT (B-01): main-thread time of each builder's commit() – id -> [sum us, max us, calls]
var _commit_by: Dictionary = {}
''')
rep('''	# threaded mode: commit finished builds, nearest first
	var done := 0
	while done < commits_per_frame:
		var best: Chunk = null
		var best_d := 0
		for c: Chunk in _chunks.values():
			if c.state == BUILDING and WorkerThreadPool.is_task_completed(c.task):
				_finish_task(c)
			if c.state == COLLECTED:
				_build_now(c)
			if c.state == BUILT:
				var d := absi(c.index * chunk_segments + chunk_segments / 2 - cam_seg)
				if best == null or d < best_d:
					best = c
					best_d = d
		if best == null:
			break
		_commit(best)
		done += 1
''', '''	# threaded mode: commit finished builds, nearest first – a chunk begun in an earlier frame first –, under the
	# frame's time budget (B-01)
	var done := 0
	var t0 := Time.get_ticks_usec()
	var budget_us := int(COMMIT_BUDGET_MS * 1000.0)
	_frame_commit_us = 0
	while done < commits_per_frame:
		var best: Chunk = null
		var best_d := 0
		for c: Chunk in _chunks.values():
			if c.state == BUILDING and WorkerThreadPool.is_task_completed(c.task):
				_finish_task(c)
			if c.state == COLLECTED:
				_build_now(c)
			if c.state == BUILT or c.state == COMMITTING:
				var d := -1 if c.state == COMMITTING else absi(c.index * chunk_segments + chunk_segments / 2 - cam_seg)
				if best == null or d < best_d:
					best = c
					best_d = d
		if best == null:
			break
		_commit_step(best, t0, budget_us)
		if best.state == COMMITTED:
			done += 1
		if Time.get_ticks_usec() - t0 >= budget_us:
			break
	_commit_us_max = maxi(_commit_us_max, _frame_commit_us)
''')
rep('''		if c.state == BUILT:
			_commit(c)
''', '''		if c.state == BUILT or c.state == COMMITTING:
			_commit(c)
''')
rep('''## The chunk node of a chunk index (null when it is not committed).
func chunk_node(ci: int) -> Node3D:
	var c: Chunk = _chunks.get(ci)
	return c.node if c != null else null
''', '''## The chunk node of a chunk index (null when it is not committed – also while it is being committed, B-01).
func chunk_node(ci: int) -> Node3D:
	var c: Chunk = _chunks.get(ci)
	return c.node if c != null and c.state == COMMITTED else null
''')
rep('''func _commit(c: Chunk) -> void:
	var t0 := Time.get_ticks_usec()
	var node := Node3D.new()
	node.name = "Chunk%d" % c.index
	node.position = path.point(c.ctx.seg_a)
	for i in _builders.size():
		(_builders[i] as ChunkBuilder).commit(c.ctx, c.parts[i], node)
	add_child(node)
	c.node = node
	c.state = COMMITTED
	_commits += 1
	var us := Time.get_ticks_usec() - t0
	_commit_us_max = maxi(_commit_us_max, us)
	_commit_us_sum += us
''', '''## The whole chunk at once (load, sync mode, flush()) – or the rest of a chunk that _commit_step() began.
func _commit(c: Chunk) -> void:
	var t0 := Time.get_ticks_usec()
	var node := c.node
	if node == null:
		node = Node3D.new()
		node.name = "Chunk%d" % c.index
		node.position = path.point(c.ctx.seg_a)
	for i in range(c.commit_i, _builders.size()):
		_commit_builder(c, i, node)
	c.commit_i = _builders.size()
	if node.get_parent() == null:
		add_child(node)
	node.visible = true
	c.node = node
	c.state = COMMITTED
	_commits += 1
	var us := Time.get_ticks_usec() - t0
	_commit_us_max = maxi(_commit_us_max, us)
	_commit_us_sum += us


## B-01: commits builders of chunk c (BUILT or begun) while the frame's commit time since frame_t0 is below budget_us –
## at least one. The node is in the tree, hidden, from the first step and shown when the last builder is done.
func _commit_step(c: Chunk, frame_t0: int, budget_us: int) -> void:
	var t0 := Time.get_ticks_usec()
	if c.node == null:
		var node := Node3D.new()
		node.name = "Chunk%d" % c.index
		node.position = path.point(c.ctx.seg_a)
		node.visible = false
		add_child(node)
		c.node = node
		c.commit_i = 0
		c.state = COMMITTING
	var first := true
	while c.commit_i < _builders.size():
		if not first and Time.get_ticks_usec() - frame_t0 >= budget_us:
			break
		_commit_builder(c, c.commit_i, c.node)
		c.commit_i += 1
		first = false
	if c.commit_i >= _builders.size():
		c.node.visible = true
		c.state = COMMITTED
		_commits += 1
	var us := Time.get_ticks_usec() - t0
	_commit_steps += 1
	_commit_us_sum += us
	_frame_commit_us += us


func _commit_builder(c: Chunk, i: int, node: Node3D) -> void:
	var b0 := Time.get_ticks_usec()
	var b := _builders[i] as ChunkBuilder
	b.commit(c.ctx, c.parts[i], node)
	var us := Time.get_ticks_usec() - b0
	var id := b.id()
	var a: Array = _commit_by.get(id, [0, 0, 0])
	a[0] = int(a[0]) + us
	a[1] = maxi(int(a[1]), us)
	a[2] = int(a[2]) + 1
	_commit_by[id] = a
''')
rep('''		"commits": _commits, "rebases": _rebases, "restarts": _restarts, "collect_by": _collect_by_ms()}''',
    '''		"commits": _commits, "commit_steps": _commit_steps, "rebases": _rebases, "restarts": _restarts,
		"collect_by": _collect_by_ms(), "commit_by": _by_ms(_commit_by)}''')
rep('''func _collect_by_ms() -> Dictionary:
	var out := {}
	for id: Variant in _collect_by:
		var a: Array = _collect_by[id]''', '''func _collect_by_ms() -> Dictionary:
	return _by_ms(_collect_by)


## id -> [sum us, max us, calls] as id -> {"avg_ms", "max_ms", "n"}.
static func _by_ms(by: Dictionary) -> Dictionary:
	var out := {}
	for id: Variant in by:
		var a: Array = by[id]''')
rep('''	_commit_us_max = 0
	_commit_us_sum = 0
	_commits = 0
''', '''	_commit_us_max = 0
	_commit_us_sum = 0
	_commits = 0
	_commit_steps = 0
	_frame_commit_us = 0
	_commit_by.clear()
''')
open(p, 'w').write(s)
print("ok")
