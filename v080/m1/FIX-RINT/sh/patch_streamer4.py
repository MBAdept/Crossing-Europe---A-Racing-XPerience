import sys
p = sys.argv[1]
s = open(p).read()


def rep(old, new):
    global s
    assert old in s, old[:80]
    s = s.replace(old, new, 1)


rep('''const FREE_BUDGET_MS := 1.0
''', '''const FREE_BUDGET_MS := 1.0
## … and only TRASH_DELAY updates after it left the tree: freeing a mesh the renderer may still be drawing from (the
## frame before) made the driver wait for that frame – single frees of up to 134 ms on llvmpipe right after the drop
## (measured, update_ms_max "trash"; inferred: a GPU sync on delete).
const TRASH_DELAY := 4
''')
rep('''var _trash: Array[Node] = []         ## FIX-RINT (F-08): chunk nodes out of the tree, freed in pieces (_free_trash())
''', '''var _trash: Array[Node] = []         ## FIX-RINT (F-08): chunk nodes out of the tree, oldest first, freed in pieces
var _trash_age := PackedInt32Array() ## … the updates since each left the tree
''')
rep('''		_trash.append(c.node)          # F-08: freed in pieces by _free_trash()
''', '''		_trash.append(c.node)          # F-08: freed in pieces by _free_trash()
		_trash_age.append(0)
''')
rep('''func _free_trash(budget_us: int) -> void:
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
			n.free()''', '''func _free_trash(budget_us: int) -> void:
	var t0 := Time.get_ticks_usec()
	var first := true
	if budget_us >= 0:
		for i in _trash_age.size():
			_trash_age[i] += 1
	while not _trash.is_empty():
		if budget_us >= 0 and (_trash_age[0] < TRASH_DELAY or (not first and Time.get_ticks_usec() - t0 >= budget_us)):
			return
		var n: Node = _trash[0]
		if not is_instance_valid(n):
			_trash.remove_at(0)
			_trash_age.remove_at(0)
			continue
		first = false
		var k := n.get_child_count()
		if k > 0 and budget_us >= 0:
			var ch := n.get_child(k - 1)
			n.remove_child(ch)
			ch.free()
		else:
			_trash.remove_at(0)
			_trash_age.remove_at(0)
			n.free()''')
open(p, 'w').write(s)
print("ok")
