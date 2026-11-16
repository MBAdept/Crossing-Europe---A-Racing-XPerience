root = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-4/'
p = root + 'scripts/race3d/road_path.gd'
s = open(p).read()
a = '''## Sets the value clearance() gives for a free side (at least the widest terrain ribbon plus its margins).
func set_clear_max(m: float) -> void:
	if m != clear_max_m:
		clear_max_m = m
		_clear_cache.clear()
'''
b = '''## Sets the value clearance() gives for a free side (at least the widest terrain ribbon plus its margins).
func set_clear_max(m: float) -> void:
	if m != clear_max_m:
		clear_max_m = m
		_clear_cache.clear()


## Sets how far along the path (both directions) clearance() looks: the largest path distance between two parts of
## the road that can be loaded at the same time.
func set_clear_reach(m: float) -> void:
	if m != clear_reach_m:
		clear_reach_m = m
		_clear_cache.clear()
'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)

p = root + 'scripts/race3d/chunk_streamer.gd'
s = open(p).read()
a = '''	path.clear_reach_m = load_path_m + keep_behind_m + 2.0 * chunk_m
'''
b = '''	path.set_clear_reach(load_path_m + keep_behind_m + 2.0 * chunk_m)
'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)

p = root + 'tests/race3d/fairness.gd'
s = open(p).read()
a = '''	path.clear_reach_m = float(ConfigLoader.lookup(cfg, "graphics.modern.load_path_m", 1500.0)) \\
		+ float(ConfigLoader.lookup(cfg, "graphics.modern.keep_behind_m", 150.0)) + 2.0 * chunk_m
'''
b = '''	path.set_clear_reach(float(ConfigLoader.lookup(cfg, "graphics.modern.load_path_m", 1500.0))
		+ float(ConfigLoader.lookup(cfg, "graphics.modern.keep_behind_m", 150.0)) + 2.0 * chunk_m)
'''
assert a in s
s = s.replace(a, b)
a = '''	path.clear_reach_m = load_m + keep_m + 2.0 * chunk_m
'''
b = '''	path.set_clear_reach(load_m + keep_m + 2.0 * chunk_m)
'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)
print('patched')
