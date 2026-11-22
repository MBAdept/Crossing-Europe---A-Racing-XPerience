import sys
W = sys.argv[1]


def patch(path, pairs):
    s = open(path).read()
    for old, new in pairs:
        assert old in s, (path, old[:70])
        s = s.replace(old, new, 1)
    open(path, 'w').write(s)


patch(W + '/scripts/race3d/layers/lights.gd', [
    ('''			for pair: Array in _statics:
				var parent: Node3D = pair[0]
				if not parent.is_inside_tree() or not parent.is_visible_in_tree():
					# a chunk that is not in the tree yet – or still hidden while it is committed (FIX-RINT, B-01): rank
					# again in the next frame
					_rank_seg = -1
					continue
''', '''			var k := 0
			while k < _statics.size():
				var pair: Array = _statics[k]
				if not is_instance_valid(pair[0]):
					# FIX-RINT (B-01): a chunk dropped while it was still being committed never entered the tree (no
					# tree_exiting): its entries go here
					_static_count -= (pair[1] as Array).size()
					_statics.remove_at(k)
					continue
				k += 1
				var parent: Node3D = pair[0]
				if not parent.is_inside_tree():
					_rank_seg = -1          # a chunk that is not in the tree yet: rank again in the next frame
					continue
'''),
    ('''		if not is_instance_valid(node) or not (node as Node3D).is_inside_tree() or not (node as Node3D).is_visible_in_tree():
''', '''		if not is_instance_valid(node) or not (node as Node3D).is_inside_tree():
'''),
])

patch(W + '/scripts/race3d/layers/flares.gd', [
    ('''	_static.append([parent, list, Transform3D(), PackedVector3Array(), PackedVector3Array(), false])
''', '''	# [parent, lamps, transform, positions, directions, positions valid, parent was in the tree]
	_static.append([parent, list, Transform3D(), PackedVector3Array(), PackedVector3Array(), false, false])
'''),
    ('''		if not is_instance_valid(pv) or not (pv as Node3D).is_inside_tree():
			_static_count -= (e[1] as Array).size()
			_static.remove_at(i)
			continue
		var parent: Node3D = pv
		if not parent.is_visible_in_tree():
			# FIX-RINT (B-01): a chunk being committed over several frames hangs hidden – its lamps wait for it
			i += 1
			continue
''', '''		if not is_instance_valid(pv) or (bool(e[6]) and not (pv as Node3D).is_inside_tree()):
			_static_count -= (e[1] as Array).size()
			_static.remove_at(i)
			continue
		if not (pv as Node3D).is_inside_tree():
			# FIX-RINT (B-01): a chunk committed over several frames enters the tree when its last builder is done –
			# its lamps wait for it (a parent that LEFT the tree is forgotten above)
			i += 1
			continue
		e[6] = true
		var parent: Node3D = pv
'''),
])
print("ok")
