W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1/"
def sub(path, old, new, count=1):
    p = W + path
    t = open(p, encoding="utf-8").read()
    n = t.count(old)
    assert n == count, (path, old[:70], n)
    t = t.replace(old, new)
    open(p, "w", encoding="utf-8").write(t)
C = "scripts/race3d/chunk_streamer.gd"
sub(C, """var _collects := 0
""", """var _collects := 0
## RINT-M2 (A-18: collect() of every layer and builder at most 2 ms per frame on the Deck preset): main-thread time of
## each builder's collect() – id -> [sum us, max us, calls]
var _collect_by: Dictionary = {}
""")
sub(C, """	for bld: ChunkBuilder in _builders:
		c.inputs.append(bld.collect(ctx))
	c.state = COLLECTED""", """	for bld: ChunkBuilder in _builders:
		var tb := Time.get_ticks_usec()
		c.inputs.append(bld.collect(ctx))
		var ub := Time.get_ticks_usec() - tb
		var st: Variant = _collect_by.get(bld.id())
		if st == null:
			_collect_by[bld.id()] = [ub, ub, 1]
		else:
			var a: Array = st
			a[0] = int(a[0]) + ub
			a[1] = maxi(int(a[1]), ub)
			a[2] = int(a[2]) + 1
	c.state = COLLECTED""")
sub(C, """		"commits": _commits, "rebases": _rebases, "restarts": _restarts}
""", """		"commits": _commits, "rebases": _rebases, "restarts": _restarts, "collect_by": _collect_by_ms()}


## collect() per builder: id -> {"avg_ms", "max_ms", "n"} (RINT-M2, A-18).
func _collect_by_ms() -> Dictionary:
	var out := {}
	for id: Variant in _collect_by:
		var a: Array = _collect_by[id]
		out[str(id)] = {"avg_ms": snappedf(float(a[0]) / maxf(1.0, float(a[2])) / 1000.0, 0.001),
			"max_ms": snappedf(float(a[1]) / 1000.0, 0.001), "n": int(a[2])}
	return out
""")
sub(C, """	_collect_us_max = 0
	_collect_us_sum = 0
	_collects = 0
""", """	_collect_us_max = 0
	_collect_us_sum = 0
	_collects = 0
	_collect_by.clear()
""")
print("ok")
