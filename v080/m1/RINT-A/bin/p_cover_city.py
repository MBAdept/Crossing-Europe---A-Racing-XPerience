import os
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1')


def rep(path, old, new, count=1):
    s = open(path).read()
    assert s.count(old) == count, (path, old[:70], s.count(old))
    s = s.replace(old, new)
    open(path, 'w').write(s)


p = 'scripts/race3d/builders/props.gd'
rep(p, '''		if reason == "corridor" and bool(e["veg"]) and not cover.is_empty():''',
    '''		if reason == "corridor" and bool(e["veg"]) and not cover.is_empty() and not bool(seg.get("city", false)):''')
rep(p, '''## from the 3.4 m eye) – one for a bush, COVER_PER_TREE scattered over the crown's footprint for a tree. Pieces that
## would lie on the shoulder are left out; the ribbon test of drop_reason() applies to each. Plain items for _place().''',
    '''## from the 3.4 m eye) – one for a bush, COVER_PER_TREE scattered over the crown's footprint for a tree. Pieces that
## would lie on the shoulder are left out; the ribbon test of drop_reason() applies to each. Plain items for _place().
## Not inside the City Limits: the ground there is paved (grass tufts on the pavement of a city centre, seen at C1).''')
rep(p, '''##               (0.5 m) high – one for a bush, three for a tree (cover_pieces(); debug "cover", list "cover_list");''',
    '''##               (0.5 m) high – one for a bush, three for a tree, not in the City Limits (cover_pieces(); debug
##               "cover", list "cover_list");''')

p = 'docs/renderer-modern-gelaende.md'
rep(p, '''über seinen Fuß verteilt (höchstens 2,5 m), nie näher als 0,8 m an der Fahrbahnkante (`cover_pieces()`; Liste `cover_list`, `debug().cover`).''',
    '''über seinen Fuß verteilt (höchstens 2,5 m), nie näher als 0,8 m an der Fahrbahnkante, nicht in den City Limits (dort ist der Boden Pflaster; `cover_pieces()`; Liste `cover_list`, `debug().cover`).''')
p = 'docs/renderer-modern.md'
rep(p, '''  ein Stück je Busch, drei je Baum über seinen Fuß verteilt, nie näher als 0,8 m an der Fahrbahnkante. Felsen und''',
    '''  ein Stück je Busch, drei je Baum über seinen Fuß verteilt, nie näher als 0,8 m an der Fahrbahnkante, nicht in den
  City Limits (Grasbüschel auf dem Pflaster eines Stadtzentrums, gesehen an C1). Felsen und''')
print('ok')
