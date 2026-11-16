import os
os.chdir('/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1')


def rep(path, old, new):
    s = open(path).read()
    assert s.count(old) == 1, (path, old[:70])
    s = s.replace(old, new)
    open(path, 'w').write(s)


p = 'scripts/race3d/builders/props.gd'
rep(p, '''		var px := x + dx
		var pz := z + dz
''', '''		var px := x + dx
		var pz := clampf(z + dz, float(ctx.seg_a) * ctx.seg_len, float(ctx.seg_b) * ctx.seg_len - 0.01)
''')
# prepare(): the ground-cover sets are modern-only (no sprite): the stage list never names them
rep(p, '''	for obj: String in OBJECT_SETS:
		wanted.append(str(OBJECT_SETS[obj]))
	# a set that is missing is drawn by its fallback set''', '''	for obj: String in OBJECT_SETS:
		wanted.append(str(OBJECT_SETS[obj]))
	for c: Variant in _cover_sets:
		if not wanted.has(str(c)):
			wanted.append(str(c))       # ground cover of the bend corridors: modern-only sets, never in the stage list
	# a set that is missing is drawn by its fallback set''')
rep(p, '''	for obj: String in OBJECT_SETS:
		if not lib.sets.has(str(OBJECT_SETS[obj])):
			wanted.append(str(OBJECT_SETS[obj]))
	if not wanted.is_empty() or not lib.ready():''', '''	for obj: String in OBJECT_SETS:
		if not lib.sets.has(str(OBJECT_SETS[obj])):
			wanted.append(str(OBJECT_SETS[obj]))
	for c: Variant in _cover_sets:
		if not lib.sets.has(str(c)) and not wanted.has(str(c)):
			wanted.append(str(c))
	if not wanted.is_empty() or not lib.ready():''')
rep(p, '''	return {"props": (part.get("list", []) as Array).size(), "groups": per_group, "counts": part.get("counts", {}),
		"dropped": part.get("dropped", {}), "lamps": (part.get("lamps", []) as Array).size(), "contact": int(part.get("blob_n", 0)),
		"list": part.get("list", [])}''', '''	return {"props": (part.get("list", []) as Array).size(), "groups": per_group, "counts": part.get("counts", {}),
		"dropped": part.get("dropped", {}), "lamps": (part.get("lamps", []) as Array).size(), "contact": int(part.get("blob_n", 0)),
		"list": part.get("list", []), "cover": (part.get("cover_list", []) as Array).size()}''')
# header doc
rep(p, '''##   "corridor"  decorative scenery inside the sight corridor of a bend (fairness rule F7): scenery-rule props and all
##               vegetation; sets listed in graphics.modern.props.bend_cover stay, scaled down to at most
##               bend_cover_max_h_m (0.5 m) – the list is empty until such ground-cover models exist''', '''##   "corridor"  decorative scenery inside the sight corridor of a bend (fairness rule F7): scenery-rule props and all
##               vegetation. A dropped plant is replaced by ground cover (amendment A-3): pieces of the sets of
##               graphics.modern.props.bend_cover (props/cover_bush, props/cover_grass), at most bend_cover_max_h_m
##               (0.5 m) high – one for a bush, three for a tree (cover_pieces(); debug "cover", list "cover_list");
##               a set of that list that the track itself places stays, scaled down to that height''')
rep(p, '''## sprite anchor) on ChunkContext.ground(), trees, plants and rocks with a stable random yaw and variant; a SPRITE''',
    '''## sprite anchor) on ChunkContext.ground(), trees, plants and rocks with a stable random yaw, one variant model per
## chunk and set (chunk_variant(): a set costs at most its surfaces in draw calls per chunk and side); a SPRITE''')
print('ok')
