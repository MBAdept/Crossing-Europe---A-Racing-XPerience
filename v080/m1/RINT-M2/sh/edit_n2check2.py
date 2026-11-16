W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1/"
p = W + "tests/race3d/render/check_night.gd"
t = open(p, encoding="utf-8").read()
old = '''	var p: Array[String] = []
	var sc: Node = await _launch_probe({"start_km": 77.6, "weather": "rain"})
	var r: Node = sc.get("renderer")
	Engine.time_scale = 1.0'''
new = '''	var p: Array[String] = []
	# the first start on the ramp of the Köhlbrandbrücke where the road rises at least 2 m over the next 150 m
	var sc: Node = null
	var r: Node = null
	var km_used := 0.0
	for km: float in LAMP_RAMP_KMS:
		sc = await _launch_probe({"start_km": km, "weather": "rain"})
		r = sc.get("renderer")
		var path: RoadPath3D = r.get("path")
		var cz := float((r.get("view") as Dictionary)["camera_z"])
		km_used = km
		if absf(path.height_at(cz + 150.0) - path.height_at(cz)) >= 2.0:
			break
		if km != LAMP_RAMP_KMS[LAMP_RAMP_KMS.size() - 1]:
			await _free(sc)
	Engine.time_scale = 1.0'''
assert t.count(old) == 1
t = t.replace(old, new)
old2 = '''	_report("laternen", p, "Köhlbrandbrücke km 77,6, 22 Uhr Regen: %d Laternenstreifen je Bild, Profil bis %.2f m, %d von %d gerechnet" % [
		n_last, prof_max, computed, puts])'''
new2 = '''	_report("laternen", p, "Köhlbrandbrücke km %.1f, 22 Uhr Regen: %d Laternenstreifen je Bild, Profil bis %.2f m, %d von %d gerechnet" % [
		km_used, n_last, prof_max, computed, puts])'''
assert t.count(old2) == 1
t = t.replace(old2, new2)
old3 = "const LAMP_PROFILE_MIN_M := 0.3   ## laternen: the largest height of a lamp streak's profile on the ramp\n"
new3 = old3 + "const LAMP_RAMP_KMS: Array[float] = [77.9, 78.2, 77.3, 78.5]   ## laternen: starts tried on the ramps of the bridge\n"
assert t.count(old3) == 1
t = t.replace(old3, new3)
t = t.replace("## RINT-M2 (NACH-R4 N2): the reflections of the STATIC lamps follow the road too – Kiel – Hamburg km 77.6 at 22:00 in the\n## rain, on the ramp of the Köhlbrandbrücke under its lamps:",
              "## RINT-M2 (NACH-R4 N2): the reflections of the STATIC lamps follow the road too – Kiel – Hamburg at 22:00 in the rain,\n## on a ramp of the Köhlbrandbrücke under its lamps (LAMP_RAMP_KMS, the first with a rise of 2 m over 150 m):")
open(p, "w", encoding="utf-8").write(t)
print("ok")
