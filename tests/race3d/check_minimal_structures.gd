extends SceneTree
## The minimal structures of the mode "Modern" that FIX1 added after the QA of M1 (docs/renderer-modern.md §14),
## checked headless in the real race scene with the shipped renderer:
##   godot --headless --path . -s res://tests/race3d/check_minimal_structures.gd [-- --only=tunnel,station]
## tools/run_tests.sh runs it through its generic hook (tests/race3d/check_*.gd).
##   tunnel     Hamburg – Hannover before the Elbtunnel: every tunnel segment of the loaded chunks has its tube
##              (builders/tunnel.gd), one portal with its hill, one cap at peek_m, lamps for the flare layer; the
##              tube material knows the camera is outside. Inside the
##              tunnel: the tube material names this tunnel's portal; the canvas stays dark while the exit is
##              beyond the sight (layers/backdrop.gd)
##   station    Kiel – Hamburg at the fuel stop: island and canopy on exactly the segments with those fuel-zone
##              flags (builders/station.gd), the front with its lettering, lamps with light pools
##   tore       the start gantry 14 m after the start line, the finish gantry at the finish (builders/gantry.gd);
##              the signs builder leaves both to it
##   wahrzeichen  Kiel – Hamburg km 80: landmarks beyond the committed chunks stand on the path up to Arcade's
##              landmark range (builders/props.gd), none twice; at 22:00 (km 77.4) up to render.landmark_far_m,
##              further than the night's sight alone allows (their illumination, M2INT)
##   bruecke    the Köhlbrand bridge: a railing on every water segment of the loaded chunks (builders/roadside.gd)
## Prints "CHECK <name> OK|FEHLER …" per check; exit code 0 when all pass.
## (The scene and the autoloads are accessed untyped: -s scripts compile before the autoloads exist.)

const RACE := "res://scenes/race/race.tscn"
const CHECKS := ["tunnel", "station", "tore", "wahrzeichen", "bruecke"]

var _failed: Array[String] = []
var _settings: Node
var _wall0 := 0


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	_settings = root.get_node("Settings")
	_settings.call("disarm_crash_guard")
	var cli := CliArgs.all()
	var only := str(cli.get("only", ""))
	cli.erase("graphics")
	for c: String in CHECKS:
		if only == "" or only.split(",").has(c):
			await call("_check_" + c)
	_settings.call("disarm_crash_guard")
	print("CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(), (Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)


# --- helpers ---------------------------------------------------------------------------------------------------

func _report(check: String, problems: Array[String], msg: String) -> void:
	var ok := problems.is_empty()
	print("CHECK %-11s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems)])
	if not ok:
		_failed.append(check)


func _need(problems: Array[String], cond: bool, what: String) -> void:
	if not cond:
		problems.append(what)


## A Modern stage, prepared (synchronous chunk builds), standing still at its start view.
func _launch(extra: Dictionary) -> Node:
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 2.0, "autopilot": true, "seed": 11,
		"gfx": "modern", "no_countdown": true, "start_speed_kmh": 0.0}
	setup.merge(extra, true)
	CliArgs.all()["gfx-sync"] = true
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	root.add_child(sc)
	CliArgs.all().erase("gfx-sync")
	var n := 0
	while n < 600 and not bool(sc.call("is_live")):
		await process_frame
		n += 1
	for i in 3:
		await process_frame
	return sc


func _free(sc: Node) -> void:
	sc.queue_free()
	await process_frame
	await process_frame
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP


## Sum of an integer key of one builder's debug parts over the loaded chunks; also the chunks' segment ranges.
func _parts(r: Object, builder_id: String) -> Array:
	var snap: Dictionary = r.call("debug_snapshot")
	var out: Array = []
	for c: Dictionary in snap.get("chunks", []):
		var part: Variant = (c.get("parts", {}) as Dictionary).get(builder_id)
		out.append([int(c.get("seg_a", 0)), int(c.get("seg_b", 0)), part if part is Dictionary else {}])
	return out


func _sum(parts: Array, key: String) -> int:
	var n := 0
	for p: Array in parts:
		n += int((p[2] as Dictionary).get(key, 0))
	return n


# --- tunnel ----------------------------------------------------------------------------------------------------

func _check_tunnel() -> void:
	var p: Array[String] = []
	var sc: Node = await _launch({"stage_id": "hamburg_hannover", "from_city": "hamburg", "start_km": 3.6, "seed": 13})
	var r: Object = sc.get("renderer")
	var trk: Object = sc.get("track")
	_need(p, r.call("builder", "tunnel") != null, "der Builder tunnel ist registriert")
	var parts := _parts(r, "tunnel")
	var want := 0
	for e: Array in parts:
		for i in range(int(e[0]), int(e[1])):
			want += 1 if bool((trk.call("get_segment", i) as Object).get("tunnel")) else 0
	var segs := _sum(parts, "segments")
	_need(p, want > 20 and segs == want, "jedes Tunnelsegment der geladenen Stücke hat seine Röhre (%d von %d)" % [segs, want])
	_need(p, _sum(parts, "portals") == 1 and _sum(parts, "portal_triangles") > 50, "ein Portal mit Hügel (%d)" % _sum(parts, "portals"))
	_need(p, _sum(parts, "caps") == 1, "eine Kappe bei peek_m (%d)" % _sum(parts, "caps"))
	_need(p, _sum(parts, "lamps") >= 2 * int(float(segs) * 3.0 / 12.0) - 2, "Lampen alle 12 m auf beiden Seiten (%d)" % _sum(parts, "lamps"))
	var mat: Variant = (r.call("builder", "tunnel") as Object).call("tube_material")
	_need(p, mat is ShaderMaterial and float((mat as ShaderMaterial).get_shader_parameter("cam_tunnel_z")) < -1.0e8, "die Röhre weiß: Kamera draußen")
	await _free(sc)
	# inside the tunnel
	sc = await _launch({"stage_id": "hamburg_hannover", "from_city": "hamburg", "start_km": 5.0, "seed": 13})
	r = sc.get("renderer")
	trk = sc.get("track")
	var cam_z := float((r.get("view") as Dictionary).get("camera_z", 0.0))
	var t: Dictionary = (trk.get("plan") as Object).call("tunnel_at", float(trk.call("z_to_km", cam_z)))
	var portal_z := float(ceili(float(trk.call("km_to_z", float(t.get("start_km", 0.0)))) / float(trk.get("seg_len")) - 1.0e-6)) * float(trk.get("seg_len"))
	mat = (r.call("builder", "tunnel") as Object).call("tube_material")
	_need(p, not t.is_empty() and is_equal_approx(float((mat as ShaderMaterial).get_shader_parameter("cam_tunnel_z")), portal_z),
		"im Tunnel: die Röhre kennt ihr Portal (%.1f)" % portal_z)
	var exit_d := float(trk.call("km_to_z", float(t.get("end_km", 0.0)))) - cam_z
	var vis := float((r.get("view") as Dictionary).get("visibility_m", 900.0))
	var bd: Dictionary = (r.call("debug_snapshot") as Dictionary).get("backdrop", {})
	_need(p, bool(bd.get("flat", false)) == (exit_d > vis), "Leinwand dunkel, solange die Ausfahrt jenseits der Sicht liegt (Ausfahrt %.0f m, Sicht %.0f m, flach %s)" % [exit_d, vis, str(bd.get("flat"))])
	await _free(sc)
	_report("tunnel", p, "Elbtunnel: %d Tunnelsegmente mit Röhre, Portal, Kappe, %d Lampen; innen Portal %.0f, Ausfahrt in %.0f m" % [segs, _sum(parts, "lamps"), portal_z, exit_d])


# --- station ---------------------------------------------------------------------------------------------------

func _check_station() -> void:
	var p: Array[String] = []
	var sc: Node = await _launch({"start_km": 13.9})
	var r: Object = sc.get("renderer")
	var trk: Object = sc.get("track")
	var parts := _parts(r, "station")
	var want_island := 0
	var want_canopy := 0
	var want_front := 0
	for e: Array in parts:
		for i in range(int(e[0]), int(e[1])):
			var fz := int((trk.call("get_segment", i) as Object).get("fuel_zone"))
			want_island += 1 if (fz & 1) != 0 else 0
			want_canopy += 1 if (fz & 2) != 0 else 0
			want_front += 1 if (fz & 4) != 0 else 0
	_need(p, want_island > 0 and _sum(parts, "islands") == want_island, "Insel auf jedem Inselsegment (%d von %d)" % [_sum(parts, "islands"), want_island])
	_need(p, want_canopy > 0 and _sum(parts, "canopies") == want_canopy, "Dach auf jedem Dachsegment (%d von %d)" % [_sum(parts, "canopies"), want_canopy])
	_need(p, _sum(parts, "fronts") == want_front and want_front >= 1, "Stirnblende mit Schrift (%d von %d)" % [_sum(parts, "fronts"), want_front])
	_need(p, _sum(parts, "lamps") > 0, "Dachlampen (%d)" % _sum(parts, "lamps"))
	var labels := 0
	for n: Node in root.find_children("*", "Label3D", true, false):
		labels += 1 if (n as Label3D).text == "TANKSTELLE" else 0
	_need(p, labels == want_front, "Schriftzug TANKSTELLE (%d)" % labels)
	await _free(sc)
	_report("station", p, "Tankstelle: %d Insel- und %d Dachsegmente, %d Stirnblende(n), %d Lampen" % [want_island, want_canopy, want_front, _sum(parts, "lamps")])


# --- gantries --------------------------------------------------------------------------------------------------

func _check_tore() -> void:
	var p: Array[String] = []
	var sc: Node = await _launch({"start_km": 0.0})
	var r: Object = sc.get("renderer")
	var kinds: Array = []
	for e: Array in _parts(r, "gantry"):
		kinds.append_array((e[2] as Dictionary).get("gantries", []))
	_need(p, kinds.count("start") == 1, "Starttor am Start (%s)" % str(kinds))
	await _free(sc)
	sc = await _launch({"start_km": 94.5})
	r = sc.get("renderer")
	kinds = []
	for e: Array in _parts(r, "gantry"):
		kinds.append_array((e[2] as Dictionary).get("gantries", []))
	_need(p, kinds.count("finish") == 1, "Zieltor am Ziel (%s)" % str(kinds))
	var ziel := 0
	for n: Node in root.find_children("*", "Label3D", true, false):
		ziel += 1 if (n as Label3D).text == "ZIEL" else 0
	_need(p, ziel == 1, "Schrift ZIEL (%d)" % ziel)
	await _free(sc)
	_report("tore", p, "Starttor und Zieltor mit Schrift")


# --- landmarks -------------------------------------------------------------------------------------------------

func _check_wahrzeichen() -> void:
	var p: Array[String] = []
	var day: Array = await _far_landmarks({"start_km": 80.0}, p)
	# M2INT: at night Arcade draws the illumination of landmarks up to render.landmark_far_m whatever the sight
	# (RoadRenderer._draw_far_landmarks) – the lit Elbphilharmonie over the Köhlbrandbrücke at 22:00
	var night: Array = await _far_landmarks({"start_km": 77.4, "start_world_minutes": 22.0 * 60.0}, p)
	_need(p, float(night[1]) > float(night[2]) + 1.0, "nachts weiter als die Wahrzeichenreichweite der Sicht (%.0f m gegen %.0f m)" % [float(night[1]), float(night[2])])
	_report("wahrzeichen", p, "%d Wahrzeichen jenseits der Stücke, Reichweite %.0f m; 22 Uhr km 77,4: %d bis %.0f m (Sicht allein %.0f m)" % [
		int(day[0]), float(day[1]), int(night[0]), float(night[1]), float(night[2])])


## Launches the stage with `extra` and checks that exactly the landmarks beyond the committed chunks up to the far
## reach of builders/props.gd stand on the path. Returns [count, far reach, landmark range of the sight alone].
func _far_landmarks(extra: Dictionary, p: Array[String]) -> Array:
	var sc: Node = await _launch(extra)
	var r: Object = sc.get("renderer")
	var trk: Object = sc.get("track")
	var props: Object = r.call("builder", "props")
	var far: Dictionary = props.get("_far")
	var st: Object = r.get("streamer")
	var chunk_m := float(int(st.get("chunk_segments"))) * float(trk.get("seg_len"))
	var view: Dictionary = r.get("view")
	var cam_z := float(view.get("camera_z", 0.0))
	var reach := float(props.call("far_reach", view))
	var by_sight := float(props.call("landmark_range", float(view.get("visibility_m", 900.0))))
	var expected := 0
	var lms: Array = trk.get("landmarks")
	for li in lms.size():
		var z := float((lms[li] as Dictionary)["z"])
		if z - cam_z > 0.0 and z - cam_z <= reach and st.call("chunk_node", int(floor(z / chunk_m))) == null:
			expected += 1
			_need(p, far.has(li), "%s (%.0f m) steht jenseits der Stücke" % [str((lms[li] as Dictionary).get("set")), z - cam_z])
	_need(p, far.size() == expected and expected >= 1, "nur Wahrzeichen jenseits der Stücke bis zur Reichweite %.0f m (%d von %d, km %.1f)" % [reach, far.size(), expected, float(extra.get("start_km", 0.0))])
	await _free(sc)
	return [expected, reach, by_sight]


# --- bridge railing --------------------------------------------------------------------------------------------

func _check_bruecke() -> void:
	var p: Array[String] = []
	var sc: Node = await _launch({"start_km": 80.0})
	var r: Object = sc.get("renderer")
	var trk: Object = sc.get("track")
	var parts := _parts(r, "roadside")
	var want := 0
	for e: Array in parts:
		for i in range(int(e[0]), int(e[1])):
			var s: Object = trk.call("get_segment", i)
			want += 1 if bool(s.get("water")) and not bool(s.get("tunnel")) else 0
	_need(p, want > 0 and _sum(parts, "railing_segments") == want, "Geländer auf jedem Brückensegment (%d von %d)" % [_sum(parts, "railing_segments"), want])
	await _free(sc)
	_report("bruecke", p, "Köhlbrandbrücke: %d Segmente mit Geländer" % want)
