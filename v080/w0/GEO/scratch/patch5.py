root = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-4/'
p = root + 'tests/sim/modern_path_check.gd'
s = open(p).read()
a = '''			if peak > cmax + 1.0e-4 or float(p["min_m"]) < INF or float(p["loop_sep_m"]) < LOOP_MIN_SEP_M:'''
b = '''			if peak > cmax + 1.0e-4 or float(p["min_m"]) < MIN_CLEAR_M or float(p["loop_sep_m"]) < LOOP_MIN_SEP_M:'''
assert a in s
s = s.replace(a, b)
a = '''			# the bound must hold: no curve beyond the limit of the stage, no approach below the grid cell (300 m)'''
b = '''			# the bound must hold: no curve beyond the limit of the stage, no approach, no early loop'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)

p = root + 'tests/sim/modern_sight.gd'
s = open(p).read()
a = '''##   godot --headless --path . -s res://tests/sim/modern_sight.gd [-- --full] [--stage=<id>[,<id>…]] [--verbose]
##       [--study-terrain[=100]]'''
b = '''##   godot --headless --path . -s res://tests/sim/modern_sight.gd [-- --full] [--stage=<id>[,<id>…]] [--verbose]
##       [--study-terrain[=100]] [--wide]'''
assert a in s
s = s.replace(a, b)
a = '''## method. Exit code 1 when a check fails – never relax a limit here without the project lead.'''
b = '''## method. --wide: additional information (no check) – the frustum check with the camera in every lane and targets
## from shoulder to shoulder. Exit code 1 when a check fails – never relax a limit here without the project lead.'''
assert a in s
s = s.replace(a, b)
a = '''	var only: Array = Array(_arg("stage", "").split(",", false))
	if only.is_empty() and not full:'''
b = '''	var wide := _arg("wide", "") != ""
	var wide_stats := {"samples": 0, "f1_cases": 0, "nearest": INF, "first": INF, "cases": 0}
	var only: Array = Array(_arg("stage", "").split(",", false))
	if only.is_empty() and not full:'''
assert a in s
s = s.replace(a, b)
a = '''		t = Time.get_ticks_msec()
		var c := Fair.scan_crests('''
b = '''		if wide:
			var lane := (geo["track"] as Track).lane_w
			var rw := Fair.scan_frustum(geo, cam, proj, profiles, envs, {"f1_limit_m": F1_LIMIT_M, "near_from": 15, "cam_step": 4,
				"cam_lats": [-lane, 0.0, lane], "lats": [-2.5 * lane, -lane, 0.0, lane, 2.5 * lane], "check_every": 1 << 40})
			wide_stats["samples"] = int(wide_stats["samples"]) + int(rw["samples"])
			wide_stats["f1_cases"] = int(wide_stats["f1_cases"]) + int(rw["f1_cases"])
			wide_stats["nearest"] = minf(float(wide_stats["nearest"]), float(rw["f1_nearest_m"]))
			for d: int in (rw["cases"] as Dictionary):
				wide_stats["cases"] = int(wide_stats["cases"]) + int(rw["cases"][d])
				wide_stats["first"] = minf(float(wide_stats["first"]), float(d))
		t = Time.get_ticks_msec()
		var c := Fair.scan_crests('''
assert a in s
s = s.replace(a, b)
a = '''	for tg: String in ["car", "sign"]:
		var a: Dictionary = f3[tg]
		var da: PackedFloat32Array = a["da"]
		var d3: PackedFloat32Array = a["d3"]
		var delta := PackedFloat32Array()'''
b = '''	if wide:
		print("SIGHT   weit (Kamera in jeder Spur, Ziele von Bankett zu Bankett ± 9,4 m, keine Prüfung): %d Stichproben, %d Fälle bis %.0f m%s, %d Fälle insgesamt (erster bei %s)" % [
			int(wide_stats["samples"]), int(wide_stats["f1_cases"]), F1_LIMIT_M,
			(" (nächster bei %.0f m)" % float(wide_stats["nearest"])) if float(wide_stats["nearest"]) < INF else "",
			int(wide_stats["cases"]), ("%.0f m" % float(wide_stats["first"])) if float(wide_stats["first"]) < INF else "–"])
	for tg: String in ["car", "sign"]:
		var a: Dictionary = f3[tg]
		var da: PackedFloat32Array = a["da"]
		var d3: PackedFloat32Array = a["d3"]
		var delta := PackedFloat32Array()'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)
print('patched')
