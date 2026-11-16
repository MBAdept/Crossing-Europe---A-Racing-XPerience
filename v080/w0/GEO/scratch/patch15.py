root = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-4/'

# --- fairness: farthest coordinate of the path -----------------------------------------------------------------------
p = root + 'tests/race3d/fairness.gd'
s = open(p).read()
a = '''	var mind := PackedFloat64Array()
	mind.resize(m)
	mind.fill(INF)
'''
b = '''	var max_abs := 0.0
	for i in m:
		max_abs = maxf(max_abs, maxf(absf(xs[i * step]), absf(zs[i * step])))
	var mind := PackedFloat64Array()
	mind.resize(m)
	mind.fill(INF)
'''
assert a in s
s = s.replace(a, b)
a = '''	return {"name": geo["name"], "length_m": float(n) * seg, "min_m": best, "min_km": float(best_i) * d_pt * kpm,'''
b = '''	return {"name": geo["name"], "length_m": float(n) * seg, "max_abs_m": max_abs, "min_m": best, "min_km": float(best_i) * d_pt * kpm,'''
assert a in s
s = s.replace(a, b)
a = '''## Closest approaches of the true path to itself. Points every `step` segments (12 m); pairs at least sep_min_m of
## path apart and closer than cell_m by air are found with a grid. Returns
## {min_m, min_km, min_sep_m (closest approach within sep_min_m..sep_max_m of path), near_m: {limit: metres of road'''
b = '''## Closest approaches of the true path to itself. Points every `step` segments (12 m); pairs at least sep_min_m of
## path apart and closer than cell_m by air are found with a grid. Returns
## {max_abs_m (largest |x| or |z| of the path relative to its start),
## min_m, min_km, min_sep_m (closest approach within sep_min_m..sep_max_m of path), near_m: {limit: metres of road'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)

# --- path check: print it --------------------------------------------------------------------------------------------
p = root + 'tests/sim/modern_path_check.gd'
s = open(p).read()
a = '''	var loop_sep := INF
	var loop_name := ""
	var loops: Array = []
	for p: Dictionary in rows:
		total_m += float(p["length_m"])
'''
b = '''	var loop_sep := INF
	var loop_name := ""
	var loops: Array = []
	var far_m := 0.0
	var far_name := ""
	for p: Dictionary in rows:
		total_m += float(p["length_m"])
		if float(p["max_abs_m"]) > far_m:
			far_m = float(p["max_abs_m"])
			far_name = str(p["name"])
'''
assert a in s
s = s.replace(a, b)
a = '''	if full:
		_print_ribbon(ribbons)
	var worst: Dictionary = rows[0] if not rows.is_empty() else {}'''
b = '''	print("PATH größte Koordinate eines Pfads ab seinem Start: %.1f km (%s) – 32-Bit-Raster dort %.1f mm ohne schwimmenden Ursprung" % [
		far_m / 1000.0, far_name, far_m * pow(2.0, -23.0) * 1000.0])
	if full:
		_print_ribbon(ribbons)
	var worst: Dictionary = rows[0] if not rows.is_empty() else {}'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)

# --- streamer: accept the whole configuration or its graphics.modern section ---------------------------------------
p = root + 'scripts/race3d/chunk_streamer.gd'
s = open(p).read()
a = '''	var m: Dictionary = ConfigLoader.lookup(cfg, "graphics.modern", {})
'''
b = '''	var m: Dictionary = ConfigLoader.lookup(cfg, "graphics.modern", {})
	if m.is_empty() and cfg.has("load_path_m"):
		m = cfg      # only the graphics.modern section was passed
'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)

# --- docs ------------------------------------------------------------------------------------------------------------
p = root + 'docs/renderer-modern.md'
s = open(p).read()
a = '''Der echte Pfad kreuzt sich bei 8 Etappenrichtungen selbst (2,5–6,6 km Weg auseinander, siehe 3.6). Deshalb:'''
b = '''Der echte Pfad kreuzt sich bei 8 Etappenrichtungen selbst (2,5–6,6 km Weg auseinander, siehe 3.7). Deshalb:'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)
print('patched')
