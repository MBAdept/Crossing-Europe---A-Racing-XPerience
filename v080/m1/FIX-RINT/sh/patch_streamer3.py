import sys
p = sys.argv[1]
s = open(p).read()


def rep(old, new):
    global s
    assert old in s, old[:80]
    s = s.replace(old, new, 1)


rep('''const COMMIT_BUDGET_MS := 2.0
''', '''const COMMIT_BUDGET_MS := 2.0
## FIX-RINT (QA-RINT-BILD F-08): a chunk left behind the camera leaves the tree at once (its lamps are forgotten, nothing
## of it is drawn) but is freed in pieces – child by child while a frame has used less than FREE_BUDGET_MS. Freeing a
## whole chunk in one frame was the streamer's hitch: update_ms_max "free" up to 141.7 ms, the "streamer" spikes of
## 8–144 ms all fell there (Kiel – Hamburg, "Steam Deck", Xvfb, measured). clear() frees everything at once.
const FREE_BUDGET_MS := 1.0
''')
rep('''var _update_us_max: Dictionary = {}  ## FIX-RINT (F-08): part of update() -> longest µs
''', '''var _update_us_max: Dictionary = {}  ## FIX-RINT (F-08): part of update() -> longest µs
var _trash: Array[Node] = []         ## FIX-RINT (F-08): chunk nodes out of the tree, freed in pieces (_free_trash())
''')
rep('''func clear() -> void:
	for c: Chunk in _chunks.values():
		_drop(c)
	_chunks.clear()
	_wanted.clear()
	_loaded = false
''', '''func clear() -> void:
	for c: Chunk in _chunks.values():
		_drop(c)
	_chunks.clear()
	_wanted.clear()
	_loaded = false
	_free_trash(-1)
''')
rep('''func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
''', '''func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_free_trash(-1)
''')
rep('''	var ahead := int(_ahead_m() / seg_len)
	var tu := Time.get_ticks_usec()
	path.ensure(cam_seg + ahead)
''', '''	var ahead := int(_ahead_m() / seg_len)
	var tu := Time.get_ticks_usec()
	_free_trash(int(FREE_BUDGET_MS * 1000.0))
	tu = _part_us("trash", tu)
	path.ensure(cam_seg + ahead)
''')
rep('''	if c.node != null:
		if c.node.get_parent() != null:
			c.node.get_parent().remove_child(c.node)
		c.node.free()
		c.node = null''', '''	if c.node != null:
		if c.node.get_parent() != null:
			c.node.get_parent().remove_child(c.node)
		_trash.append(c.node)          # F-08: freed in pieces by _free_trash()
		c.node = null


## F-08: frees nodes of dropped chunks – the last child of the last node first, while this call has used less than
## budget_us (at least one piece); budget_us < 0: everything now.
func _free_trash(budget_us: int) -> void:
	var t0 := Time.get_ticks_usec()
	var first := true
	while not _trash.is_empty():
		if budget_us >= 0 and not first and Time.get_ticks_usec() - t0 >= budget_us:
			return
		first = false
		var n: Node = _trash.back()
		if not is_instance_valid(n):
			_trash.pop_back()
			continue
		var k := n.get_child_count()
		if k > 0 and budget_us >= 0:
			var ch := n.get_child(k - 1)
			n.remove_child(ch)
			ch.free()
		else:
			_trash.pop_back()
			n.free()''')
open(p, 'w').write(s)
print("ok")
