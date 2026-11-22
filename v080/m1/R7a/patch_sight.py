WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-1"
p = WT + '/tests/sim/modern_sight.gd'
s = open(p).read()


def rep(old, new):
    global s
    assert old in s, old[:80]
    s = s.replace(old, new, 1)


rep('''##   modern_sight_f7        the terrain is never above the road inside the sight corridor
''', '''##   modern_sight_f7        the terrain is never above the road inside the sight corridor, and the corridor is the
##                          envelope of the real sight lines (contract A-17): it reaches every sight line of an
##                          independent reference (every 7th camera row, every lane, Fair.sight_envelope()) and counts
##                          there as a bend's (nothing taller than 0.5 m stands in it)
''')
rep('''	var f7 := {"rows": 0, "sides": 0, "violations": 0, "worst_m": 0.0, "cut": 0, "min_limit_m": INF, "max_corridor_m": 0.0,
		"max_height_m": -INF, "raised": 0}''', '''	var f7 := {"rows": 0, "sides": 0, "violations": 0, "worst_m": 0.0, "cut": 0, "min_limit_m": INF, "max_corridor_m": 0.0,
		"max_height_m": -INF, "raised": 0, "env_sides": 0, "env_short": 0, "env_short_m": 0.0, "env_flag": 0, "env_over_sum": 0.0,
		"env_cams": 0, "sight_ms": 0.0}
	var env_opts := {"chord_max_m": float(ConfigLoader.lookup(cfg, "graphics.modern.terrain.corridor_chord_m", 300.0)),
		"camera_offset_m": float(ConfigLoader.lookup(cfg, "render.camera_distance_m", 9.0)), "cam_every": 7, "cam_offset": 3}''')
rep('''		t = Time.get_ticks_msec()
		var k := Fair.scan_corridor(geo, terr)
		times["f7"] += Time.get_ticks_msec() - t
		for key: String in ["rows", "sides", "violations", "cut", "raised"]:
			f7[key] = int(f7[key]) + int(k[key])''', '''		t = Time.get_ticks_msec()
		var env := Fair.sight_envelope(geo, profiles, env_opts)
		var k := Fair.scan_corridor(geo, terr, env)
		times["f7"] += Time.get_ticks_msec() - t
		for key: String in ["rows", "sides", "violations", "cut", "raised", "env_sides", "env_short", "env_flag"]:
			f7[key] = int(f7[key]) + int(k[key])
		f7["env_short_m"] = maxf(float(f7["env_short_m"]), float(k["env_short_m"]))
		f7["env_over_sum"] = float(f7["env_over_sum"]) + float(k["env_over_m"]) * float(k["env_sides"])
		f7["env_cams"] = int(f7["env_cams"]) + int(env["cameras"])
		f7["sight_ms"] = float(f7["sight_ms"]) + float((terr["terrain"] as TerrainProfile).sight.usec) / 1000.0''')
rep('''		float(f7["max_corridor_m"]), float(f7["max_height_m"]), int(f7["raised"])])''', '''		float(f7["max_corridor_m"]), float(f7["max_height_m"]), int(f7["raised"])])
	print("SIGHT F7 Hülle der Sichtlinien (A-17): %d Querschnittsseiten, die eine Sichtlinie der Stichprobe (%d Kamerareihen, jede 7., jede Spur) jenseits des Banketts kreuzt; Korridor schmaler: %d (höchstens %.2f m), nicht als Kurvenkorridor gezählt: %d; im Mittel %.2f m breiter als die Stichprobe; Kern %.1f s" % [
		int(f7["env_sides"]), int(f7["env_cams"]), int(f7["env_short"]), float(f7["env_short_m"]), int(f7["env_flag"]),
		float(f7["env_over_sum"]) / maxf(1.0, float(f7["env_sides"])), float(f7["sight_ms"]) / 1000.0])''')
rep('''	var ok7 := int(f7["violations"]) == 0 and int(f7["sides"]) > 0''', '''	var ok7 := int(f7["violations"]) == 0 and int(f7["sides"]) > 0 and int(f7["env_short"]) == 0 and int(f7["env_flag"]) == 0 \\
		and int(f7["env_sides"]) > 0''')
rep('''	print("CHECK modern_sight_f7       %s %d von %d Querschnittsseiten mit Gelände über der Fahrbahn im Sichtkorridor" % [
		"OK    " if ok7 else "FEHLER", int(f7["violations"]), int(f7["sides"])])''', '''	print("CHECK modern_sight_f7       %s %d von %d Querschnittsseiten mit Gelände über der Fahrbahn im Sichtkorridor; Hülle der Sichtlinien: %d von %d Seiten nicht abgedeckt, %d nicht als Kurvenkorridor gezählt" % [
		"OK    " if ok7 else "FEHLER", int(f7["violations"]), int(f7["sides"]), int(f7["env_short"]), int(f7["env_sides"]), int(f7["env_flag"])])''')
open(p, 'w').write(s)
print("patched")
