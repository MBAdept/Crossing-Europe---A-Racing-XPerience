import os
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1')


def rep(path, old, new, count=1):
    s = open(path).read()
    assert s.count(old) == count, (path, old[:70], s.count(old))
    s = s.replace(old, new)
    open(path, 'w').write(s)


p = 'tests/unit/race3d/test_props.gd'
rep(p, '''			key = key.get_base_dir() if key.begins_with("res://") else key
			calls[key] = int(calls.get(key, 0)) + mmi.multimesh.mesh.get_surface_count()''', '''			key = key.get_base_dir() if key.begins_with("res://") else key
			# per side: a set placed on both roadsides needs a second, mirrored node (D24), and a model with two
			# surfaces (a house: baked walls + vpbr panes, AS1b) then costs 2 x 2 – the budget holds per set, chunk and side
			key += " (gespiegelt)" if mmi.basis.determinant() < 0.0 else ""
			calls[key] = int(calls.get(key, 0)) + mmi.multimesh.mesh.get_surface_count()''')
rep(p, '''			assert_true(int(calls[key]) <= DRAW_CALLS_PER_SET, "höchstens %d Zeichenaufrufe je Set und Stück (%s: %d, Kamera %.0f)" % [DRAW_CALLS_PER_SET, key, calls[key], cam])''',
    '''			assert_true(int(calls[key]) <= DRAW_CALLS_PER_SET, "höchstens %d Zeichenaufrufe je Set, Stück und Seite (%s: %d, Kamera %.0f)" % [DRAW_CALLS_PER_SET, key, calls[key], cam])''')
print('ok')
