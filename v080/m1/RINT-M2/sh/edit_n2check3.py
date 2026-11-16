W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1/"
p = W + "tests/race3d/render/check_night.gd"
t = open(p, encoding="utf-8").read()
a = t.index("## RINT-M2 (NACH-R4 N2): the reflections of the STATIC lamps follow the road too")
b = t.index("func _capture() -> Image:")
new = '''## RINT-M2 (NACH-R4 N2): the reflections of the STATIC lamps follow the road too. The wet night of "spiegelung"
## (Kassel – Würzburg before the crest T2, the road climbs ahead) with LAMP_TEST_N street lamps put on the climb through
## renderer.add_lamps() (A-7, as a builder does): the flare layer puts their wet streaks, every one with a road profile
## (layers/flares.gd _lamp_profile(), cached per lamp while the camera moves less than PROFILE_KEEP_M), and on the climb
## the profiles are not flat (at least LAMP_PROFILE_MIN_M) – a broken profile (flat: the old level streak that stood in
## the air over a climbing road, QA-R4 B1) fails here. Also: the cache works (fewer profiles computed than streaks put).
func _check_laternen() -> void:
	var p: Array[String] = []
	var sc: Node = await _launch_probe({"stage_id": "kassel_wuerzburg", "from_city": "kassel", "start_km": 61.6, "vehicle": "kombi", "seed": 12})
	var r: Node = sc.get("renderer")
	var view: Dictionary = r.get("view")
	var path: RoadPath3D = r.get("path")
	var cam_z := float(view["camera_z"])
	var rise := path.height_at(cam_z + 250.0) - path.height_at(cam_z)
	var holder := Node3D.new()
	holder.name = "LampTest"
	(r.get("world") as Node3D).add_child(holder)
	var lamps: Array = []
	for k in LAMP_TEST_N:
		var z := cam_z + 90.0 + 40.0 * float(k)
		lamps.append({"pos": path.world(z, 6.5, 8.0), "dir": Vector3.DOWN, "role": "street", "color": Color(1.0, 0.85, 0.6),
			"size": 0.6, "range": 12.0, "energy": 1.0})
	r.call("add_lamps", holder, lamps)
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
	_keep(await _capture(), "laternen_steigung")
	_need(p, rise >= 3.0, "die Straße steigt vor der Kamera (%.1f m auf 250 m)" % rise)
	_need(p, n_last >= LAMP_TEST_N, "Spiegelungen der Laternen auf der nassen Steigung (%d von %d)" % [n_last, LAMP_TEST_N])
	_need(p, prof_max >= LAMP_PROFILE_MIN_M, "ihre Profile folgen der Straße (größte Höhe %.2f m, mindestens %.2f m)" % [prof_max, LAMP_PROFILE_MIN_M])
	_need(p, computed > 0 and computed < puts, "Profile zwischengespeichert (%d gerechnet für %d Streifen)" % [computed, puts])
	holder.queue_free()
	await _free(sc)
	_report("laternen", p, "Kassel – Würzburg km 61,6, 22 Uhr Regen, Steigung %.1f m: %d Laternenstreifen je Bild, Profil bis %.2f m, %d von %d gerechnet" % [
		rise, n_last, prof_max, computed, puts])


'''
t = t[:a] + new + t[b:]
t = t.replace("const LAMP_RAMP_KMS: Array[float] = [77.9, 78.2, 77.3, 78.5]   ## laternen: starts tried on the ramps of the bridge\n",
              "const LAMP_TEST_N := 4              ## laternen: street lamps put on the climb\n")
open(p, "w", encoding="utf-8").write(t)
print("ok")
