extends SceneTree
## Fairness check of the mode "Modern" (tools/run_tests.sh): does the real-3D view show everything the player must
## react to in time? Rules F1–F3 and F7 of docs/renderer-modern.md, computed with the shipped camera
## (ChaseCamera3D, graphics.modern.camera) and the shipped terrain (TerrainProfile, graphics.modern.terrain) on the
## real roads (RoadPath3D):
##   modern_sight_f1        everything Arcade has on screen within 270 m is inside the Modern frustum: 0 cases
##                          (camera on the centreline, targets on the centre and ± one lane, 15 m … 270 m ahead)
##   modern_sight_f1_lanes  the same with the camera in the outer lanes and targets from lane to lane and at the
##                          roadside (± 9.4 m), 30 m … 260 m ahead: 0 cases
##   modern_sight_f2        beyond that: stopping sight distance at the fastest drivable speed <= 0.6 x the distance
##                          of a target Arcade shows and Modern not yet – dry, rain, snow, every sample of both scans
##   modern_sight_f3        crests: no vehicle (0.75 m) or sign (2.8 m) is seen later than in Arcade and then inside
##                          the stopping sight distance
##   modern_sight_f7        the terrain is never above the road inside the sight corridor
##   modern_sight_model     the fast inner loop agrees with ChaseCamera3D.transform() / project() and RoadProjection
##   godot --headless --path . -s res://tests/sim/modern_sight.gd [-- --full] [--stage=<id>[,<id>…]] [--verbose]
##       [--study-terrain[=100]]
## Normal run: the twelve hardest stage directions (tests/race3d/fairness.gd HARDEST; about 20 s). --full: the
## whole network (a good 2 minutes; at the milestones). --study-terrain: F3 over the ground of the design study (road
## height up to 100 m from the centreline) instead of the shipped terrain – reproduces its numbers, validates the
## method. Exit code 1 when a check fails – never relax a limit here without the project lead.
## Owner: race3d kernel.

const Fair := preload("res://tests/race3d/fairness.gd")
const F1_LIMIT_M := 270.0
const F1_LANES_LIMIT_M := 260.0
const F1_LANES_FROM_M := 30
const F2_RATIO := 0.60


func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + name:
			return "1"
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return default


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var full := _arg("full", "") != ""
	var verbose := _arg("verbose", "") != ""
	var study_ribbon := float(_arg("study-terrain", "0"))
	if _arg("study-terrain", "") == "1":
		study_ribbon = 100.0
	var only: Array = Array(_arg("stage", "").split(",", false))
	if only.is_empty() and not full:
		only = Fair.HARDEST.duplicate()
	var dirs := Fair.directions(net, only)
	var proj := Fair.make_projection(cfg)
	var cam := Fair.make_camera(cfg, proj)
	var envs := Fair.envelopes(cfg)
	var times := {"geo": 0, "terrain": 0, "f12": 0, "lanes": 0, "f3": 0, "f7": 0}
	# totals
	var samples := 0
	var cams := 0
	var cases := {}
	var need_d := {}
	var f1_cases := 0
	var lanes := {"samples": 0, "f1_cases": 0, "first": INF, "cases": 0}
	var worst := {}
	for w: String in Fair.WEATHERS:
		worst[w] = {"ratio": 0.0}
	var max_yaw := 0.0
	var check_n := 0
	var check_bad := 0
	var check_vert := 0
	var f3 := {"targets": 0}
	for tg: String in ["car", "sign"]:
		f3[tg] = {"later": 0, "later30": 0, "earlier": 0, "short_a": 0, "short_3": 0, "fail": 0, "limited": 0,
			"da": PackedFloat32Array(), "d3": PackedFloat32Array(), "worst": []}
	var f7 := {"rows": 0, "sides": 0, "violations": 0, "worst_m": 0.0, "cut": 0, "min_limit_m": INF, "max_corridor_m": 0.0,
		"max_height_m": -INF, "raised": 0}
	var segments := 0
	for dir: Dictionary in dirs:
		var t := Time.get_ticks_msec()
		var geo := Fair.build_geo(cfg, net, dir)
		segments += int(geo["n"])
		times["geo"] += Time.get_ticks_msec() - t
		t = Time.get_ticks_msec()
		var terr := Fair.build_terrain(cfg, geo)
		times["terrain"] += Time.get_ticks_msec() - t
		t = Time.get_ticks_msec()
		var profiles := {}
		for w: String in Fair.WEATHERS:
			profiles[w] = Fair.speed_profile(geo, envs[w])
		# scan A: the sampling of the design study plus the near field
		var r := Fair.scan_frustum(geo, cam, proj, profiles, envs, {"f1_limit_m": F1_LIMIT_M, "near_from": 15})
		times["f12"] += Time.get_ticks_msec() - t
		samples += int(r["samples"])
		cams += int(r["cams"])
		f1_cases += int(r["f1_cases"])
		max_yaw = maxf(max_yaw, float(r["max_yaw_deg"]))
		for d: int in (r["cases"] as Dictionary):
			cases[d] = int(cases.get(d, 0)) + int(r["cases"][d])
			var nd: Array = need_d.get(d, [0.0, 0.0, 0.0])
			for wi in 3:
				nd[wi] = maxf(float(nd[wi]), float(r["max_need"][d][wi]))
			need_d[d] = nd
		# scan B: the camera in the outer lanes, targets from lane to lane and at the roadside
		t = Time.get_ticks_msec()
		var lane := (geo["track"] as Track).lane_w
		var rb := Fair.scan_frustum(geo, cam, proj, profiles, envs, {"f1_limit_m": F1_LANES_LIMIT_M, "near_from": F1_LANES_FROM_M,
			"cam_lats": [-lane, lane], "lats": [-2.5 * lane, -lane, 0.0, lane, 2.5 * lane]})
		times["lanes"] += Time.get_ticks_msec() - t
		lanes["samples"] = int(lanes["samples"]) + int(rb["samples"])
		lanes["f1_cases"] = int(lanes["f1_cases"]) + int(rb["f1_cases"])
		for d: int in (rb["cases"] as Dictionary):
			lanes["cases"] = int(lanes["cases"]) + int(rb["cases"][d])
			lanes["first"] = minf(float(lanes["first"]), float(d))
		for res: Dictionary in [r, rb]:
			check_n += int(res["check_samples"])
			check_bad += int(res["check_mismatch"])
			check_vert += int(res["check_vertical"])
			for w: String in Fair.WEATHERS:
				if float(res["worst"][w]["ratio"]) > float(worst[w]["ratio"]):
					worst[w] = res["worst"][w]
		t = Time.get_ticks_msec()
		var c := Fair.scan_crests(geo, terr, proj, profiles["normal"], float(envs["normal"]["seen_m"]), {"study_ribbon_m": study_ribbon})
		times["f3"] += Time.get_ticks_msec() - t
		f3["targets"] = int(f3["targets"]) + int(c["targets"])
		for tg: String in ["car", "sign"]:
			var a: Dictionary = f3[tg]
			var b: Dictionary = c[tg]
			for key: String in ["later", "later30", "earlier", "short_a", "short_3", "fail", "limited"]:
				a[key] = int(a[key]) + int(b[key])
			var da: PackedFloat32Array = a["da"]
			da.append_array(b["da"])
			a["da"] = da
			var d3: PackedFloat32Array = a["d3"]
			d3.append_array(b["d3"])
			a["d3"] = d3
			(a["worst"] as Array).append_array(b["worst"])
		t = Time.get_ticks_msec()
		var k := Fair.scan_corridor(geo, terr)
		times["f7"] += Time.get_ticks_msec() - t
		for key: String in ["rows", "sides", "violations", "cut", "raised"]:
			f7[key] = int(f7[key]) + int(k[key])
		f7["worst_m"] = maxf(float(f7["worst_m"]), float(k["worst_m"]))
		f7["min_limit_m"] = minf(float(f7["min_limit_m"]), float(k["min_limit_m"]))
		f7["max_corridor_m"] = maxf(float(f7["max_corridor_m"]), float(k["max_corridor_m"]))
		f7["max_height_m"] = maxf(float(f7["max_height_m"]), float(k["max_height_m"]))
		if verbose:
			print("SIGHT %-36s F1 %d/%d  F2 %.3f/%.3f/%.3f  F3 %d+%d von %d  F7 %d" % [dir["name"], int(r["f1_cases"]), int(rb["f1_cases"]),
				maxf(float(r["worst"]["normal"]["ratio"]), float(rb["worst"]["normal"]["ratio"])),
				maxf(float(r["worst"]["rain"]["ratio"]), float(rb["worst"]["rain"]["ratio"])),
				maxf(float(r["worst"]["snow"]["ratio"]), float(rb["worst"]["snow"]["ratio"])),
				int(c["car"]["fail"]), int(c["sign"]["fail"]), int(c["targets"]), int(k["violations"])])
	# report
	if study_ribbon > 0.0:
		print("SIGHT F3 mit dem Gelände der Entwurfsstudie (Fahrbahnhöhe bis %.0f m neben der Mitte) statt des ausgelieferten Geländes" % study_ribbon)
	print("SIGHT %d Etappenrichtungen (%s), %d Segmente, Kamera: Blick %.2f x Peilung %.0f m voraus, größter Blickwinkel %.1f°" % [
		dirs.size(), "ganzes Netz" if full else "Auswahl", segments, cam.look_gain, cam.look_m, max_yaw])
	print("SIGHT F1/F2: %d Kamerapositionen, %d Stichproben (Kamera in Fahrbahnmitte, Ziel 15 … 750 m voraus, Mitte und ± eine Spur)" % [cams, samples])
	var ds := cases.keys()
	ds.sort()
	if verbose or full:
		print("SIGHT   d (m): Fälle [Arcade im Bild, Modern nicht] / größter Anhalteweg dort trocken, Regen, Schnee (m)")
		for d: int in ds:
			print("SIGHT   %4d: %6d   %6.1f %6.1f %6.1f" % [d, int(cases[d]), float(need_d[d][0]), float(need_d[d][1]), float(need_d[d][2])])
	var first_d := int(ds[0]) if not ds.is_empty() else -1
	var total_cases := 0
	for d: int in ds:
		total_cases += int(cases[d])
	print("SIGHT   erster Fall bei %s, %d Fälle insgesamt" % [("%d m" % first_d) if first_d >= 0 else "–", total_cases])
	print("SIGHT   Kamera in den Außenspuren, Ziele in jeder Spur und am Fahrbahnrand (± 9,4 m), %d … 750 m voraus: %d Stichproben, erster Fall bei %s, %d Fälle insgesamt" % [
		F1_LANES_FROM_M, int(lanes["samples"]), ("%.0f m" % float(lanes["first"])) if float(lanes["first"]) < INF else "–", int(lanes["cases"])])
	for w: String in Fair.WEATHERS:
		var e: Dictionary = worst[w]
		if float(e["ratio"]) > 0.0:
			print("SIGHT   F2 %-6s ungünstigster Fall: Anhalteweg %.0f m bei %.0f km/h, Ziel %d m voraus = %.3f  (%s km %.1f)" % [
				w, float(e["need_m"]), float(e["v_kmh"]), int(e["d"]), float(e["ratio"]), e["name"], float(e["km"])])
	for tg: String in ["car", "sign"]:
		var a: Dictionary = f3[tg]
		var da: PackedFloat32Array = a["da"]
		var d3: PackedFloat32Array = a["d3"]
		var delta := PackedFloat32Array()
		delta.resize(da.size())
		for i in da.size():
			delta[i] = d3[i] - da[i]
		print("SIGHT F3 %-4s %d Ziele: gesehen ab (m) Arcade p10 %.0f p50 %.0f | Modern p10 %.0f p50 %.0f | durch Kuppen begrenzt %d" % [
			tg, da.size(), Fair.percentile(da, 10.0), Fair.percentile(da, 50.0), Fair.percentile(d3, 10.0), Fair.percentile(d3, 50.0), int(a["limited"])])
		print("SIGHT   Modern - Arcade (m): min %.0f p1 %.0f p50 %.0f max %.0f; Modern später um > 6 m: %d, > 30 m: %d; früher um > 6 m: %d" % [
			Fair.percentile(delta, 0.0), Fair.percentile(delta, 1.0), Fair.percentile(delta, 50.0), Fair.percentile(delta, 100.0),
			int(a["later"]), int(a["later30"]), int(a["earlier"])])
		print("SIGHT   näher als der Anhalteweg (trocken) gesehen: Arcade %d, Modern %d; später als Arcade UND innerhalb des Anhaltewegs: %d" % [
			int(a["short_a"]), int(a["short_3"]), int(a["fail"])])
		var list: Array = a["worst"]
		list.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
			return float(p["modern_m"]) - float(p["arcade_m"]) < float(q["modern_m"]) - float(q["arcade_m"]))
		for i in mini(6 if verbose or full else 2, list.size()):
			var it: Dictionary = list[i]
			print("SIGHT     %s km %.1f: Arcade %.0f m, Modern %.0f m (Anhalteweg %.0f m)%s" % [it["name"], float(it["km"]),
				float(it["arcade_m"]), float(it["modern_m"]), float(it["need_m"]), "  !!" if bool(it["fail"]) else ""])
	print("SIGHT F7 %d Querschnittsseiten: Gelände im Sichtkorridor über der Fahrbahn: %d (höchstens %.2f m); Band gekürzt an %d Seiten (schmalstes %.1f m), breitester Korridor %.1f m, höchstes Gelände %.2f m über der Fahrbahn, an %d Seiten über Fahrbahnniveau" % [
		int(f7["sides"]), int(f7["violations"]), float(f7["worst_m"]), int(f7["cut"]), float(f7["min_limit_m"]),
		float(f7["max_corridor_m"]), float(f7["max_height_m"]), int(f7["raised"])])
	var secs := float(Time.get_ticks_msec() - t0) / 1000.0
	print("SIGHT Zeit %.1f s: Strecken %.1f, Gelände %.1f, F1/F2 %.1f, Spuren %.1f, F3 %.1f, F7 %.1f" % [secs, float(times["geo"]) / 1000.0,
		float(times["terrain"]) / 1000.0, float(times["f12"]) / 1000.0, float(times["lanes"]) / 1000.0, float(times["f3"]) / 1000.0,
		float(times["f7"]) / 1000.0])
	# verdicts
	var ok1 := f1_cases == 0 and samples > 0
	var ok1b := int(lanes["f1_cases"]) == 0 and int(lanes["samples"]) > 0
	var ratios: Array[float] = []
	var ok2 := samples > 0
	for w: String in Fair.WEATHERS:
		ratios.append(float(worst[w]["ratio"]))
		if float(worst[w]["ratio"]) > F2_RATIO:
			ok2 = false
	var f3_fail := int(f3["car"]["fail"]) + int(f3["sign"]["fail"])
	var ok3 := f3_fail == 0 and int(f3["targets"]) > 0
	var ok7 := int(f7["violations"]) == 0 and int(f7["sides"]) > 0
	var okm := check_bad == 0 and check_vert == 0 and check_n > 0
	print("CHECK modern_sight_f1       %s %d Fälle bis %.0f m (erster Fall bei %s) in %d Stichproben, %d Etappenrichtungen" % [
		"OK    " if ok1 else "FEHLER", f1_cases, F1_LIMIT_M, ("%d m" % first_d) if first_d >= 0 else "–", samples, dirs.size()])
	print("CHECK modern_sight_f1_lanes %s %d Fälle bis %.0f m mit der Kamera in den Außenspuren (erster Fall bei %s) in %d Stichproben" % [
		"OK    " if ok1b else "FEHLER", int(lanes["f1_cases"]), F1_LANES_LIMIT_M,
		("%.0f m" % float(lanes["first"])) if float(lanes["first"]) < INF else "–", int(lanes["samples"])])
	print("CHECK modern_sight_f2       %s Anhalteweg / Entfernung höchstens %.3f trocken, %.3f Regen, %.3f Schnee (verlangt <= %.2f)" % [
		"OK    " if ok2 else "FEHLER", ratios[0], ratios[1], ratios[2], F2_RATIO])
	print("CHECK modern_sight_f3       %s %d von %d Zielen (Fahrzeug) und %d (Schild) später als in Arcade und innerhalb des Anhaltewegs" % [
		"OK    " if ok3 else "FEHLER", int(f3["car"]["fail"]), int(f3["targets"]), int(f3["sign"]["fail"])])
	print("CHECK modern_sight_f7       %s %d von %d Querschnittsseiten mit Gelände über der Fahrbahn im Sichtkorridor" % [
		"OK    " if ok7 else "FEHLER", int(f7["violations"]), int(f7["sides"])])
	print("CHECK modern_sight_model    %s %d Stichproben über ChaseCamera3D/RoadProjection nachgerechnet: %d abweichend, %d senkrecht außerhalb (%.0f s)" % [
		"OK    " if okm else "FEHLER", check_n, check_bad, check_vert, secs])
	quit(0 if ok1 and ok1b and ok2 and ok3 and ok7 and okm else 1)
