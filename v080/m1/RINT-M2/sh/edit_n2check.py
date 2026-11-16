W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1/"


def sub(path, old, new, c=1):
    p = W + path
    t = open(p, encoding="utf-8").read()
    assert t.count(old) == c, (path, old[:60], t.count(old))
    t = t.replace(old, new)
    open(p, "w", encoding="utf-8").write(t)


N = "tests/race3d/render/check_night.gd"
sub(N, 'const CHECKS := ["fahrbahn", "spielerauto", "verdeckung", "blaulicht", "nass_kegel", "spiegelung"]',
    'const CHECKS := ["fahrbahn", "spielerauto", "verdeckung", "blaulicht", "nass_kegel", "spiegelung", "laternen"]')
sub(N, 'const OWN_FILE := ["nass_kegel", "spiegelung"]', 'const OWN_FILE := ["nass_kegel", "spiegelung", "laternen"]')
sub(N, """func _check_spiegelung() -> void:""", """## RINT-M2 (NACH-R4 N2): the reflections of the STATIC lamps follow the road too – Kiel – Hamburg km 77.6 at 22:00 in the
## rain, on the ramp of the Köhlbrandbrücke under its lamps: the flare layer puts wet streaks of static lamps, every
## one with a road profile (layers/flares.gd _lamp_profile(), cached per lamp while the camera moves less than
## PROFILE_KEEP_M), and on the ramp the profiles are not flat (at least LAMP_PROFILE_MIN_M) – a broken profile (flat,
## the old level streak that stood in the air over a climbing road, QA-R4 B1) fails here. Also: the cache works (fewer
## profiles computed than streaks put over the frames).
func _check_laternen() -> void:
	var p: Array[String] = []
	var sc: Node = await _launch_probe({"start_km": 77.6, "weather": "rain"})
	var r: Node = sc.get("renderer")
	Engine.time_scale = 1.0
	var puts := 0
	var prof_max := 0.0
	var n_last := 0
	for i in 40:
		await process_frame
		var snap: Dictionary = (r.call("debug_snapshot") as Dictionary).get("lights", {})
		var n := int(snap.get("lamp_streak_profiles", 0))
		puts += n
		n_last = maxi(n_last, n)
		prof_max = maxf(prof_max, float(snap.get("lamp_streak_profile_max_m", 0.0)))
	Engine.time_scale = 0.0
	var snap2: Dictionary = (r.call("debug_snapshot") as Dictionary).get("lights", {})
	var computed := int(snap2.get("lamp_streak_profiles_computed", 0))
	_keep(await _capture(), "laternen_koehlbrand")
	_need(p, n_last >= 4, "Spiegelungen der Laternen auf der nassen Rampe (%d)" % n_last)
	_need(p, prof_max >= LAMP_PROFILE_MIN_M, "ihre Profile folgen der Rampe (größte Höhe %.2f m, mindestens %.2f m)" % [prof_max, LAMP_PROFILE_MIN_M])
	_need(p, computed > 0 and computed < puts, "Profile zwischengespeichert (%d gerechnet für %d Streifen)" % [computed, puts])
	await _free(sc)
	_report("laternen", p, "Köhlbrandbrücke km 77,6, 22 Uhr Regen: %d Laternenstreifen je Bild, Profil bis %.2f m, %d von %d gerechnet" % [
		n_last, prof_max, computed, puts])


func _capture() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _check_spiegelung() -> void:""")
sub(N, 'const STEPS := 30\n', 'const STEPS := 30\nconst LAMP_PROFILE_MIN_M := 0.3   ## laternen: the largest height of a lamp streak\'s profile on the ramp\n')
sub("tests/race3d/render/check_night_nass.gd", '''		CliArgs.all()["only"] = "nass_kegel,spiegelung"''', '''		CliArgs.all()["only"] = "nass_kegel,spiegelung,laternen"''')
sub("tests/race3d/render/check_night_nass.gd", '''## check_night.gd stays inside tools/run_render_checks.sh's time per file.''', '''## check_night.gd stays inside tools/run_render_checks.sh's time per file. RINT-M2: "laternen" (the static lamps'
## reflections follow the road on the ramp of the Köhlbrandbrücke, NACH-R4 N2).''')
print("ok")
