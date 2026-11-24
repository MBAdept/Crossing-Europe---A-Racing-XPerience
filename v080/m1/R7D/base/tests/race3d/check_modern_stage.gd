extends SceneTree
## Headless checks of a whole stage in the graphics mode "Modern" with the shipped renderer core (v0.8.0, contract §6
## R1) – run by tools/run_tests.sh through its hook for tests/race3d/check_*.gd:
##   godot --headless --path . -s res://tests/race3d/check_modern_stage.gd [-- --only=<check>[,<check>…]]
##   ergebnis   Kiel – Hamburg driven by the autopilot from start to finish in Arcade and in Modern: the same result
##              (every key but gfx) – the renderer never feeds back into the simulation (Rule 3)
##   inhalt     what the renderer core shows on the slice stage: road and roadside in every chunk (Autobahn: three
##              lanes, edge lines, guardrails; the City Limits with curbs; the fuel lane; start and finish line),
##              the environment rig as `env` with exactly one shadow-casting DirectionalLight3D, backdrop, lights
##              and overlay layer, the road material registered for the light pools, the ground on render layer 2,
##              the quality states of the viewport set and put back
##   nacht      23:00 with traffic: the low beam is on (two spots, the cone's globals), traffic cones on the pool
##              materials, reflectors registered and glinting; by day none of it; police chase: the overlay shows
##   tunnel     Bern – Mailand km 186: tunnel light and tunnel fog, the sun's energy 0 (the light stays), the canvas
##              dark while no tunnel builder draws a tube; the ramp at the portal is a function of the position
##   waechter   the slowness watchdog steps the preset down (forced): medium -> low for the rest of the stage – the
##              viewport states follow, shadow casters stop casting, the session gets quality_lowered (HUD message,
##              result field gfx_lowered); shadow mode and filter of the stage stay
##   wechsel    an Arcade renderer after a Modern stage: the shared Modern materials are dropped (each mode holds
##              only its own assets); between two Modern stages they stay
##   kern_zeit  GDScript time of the renderer core per frame of a drive at 150 km/h (render() with what this
##              package ships – no vehicle, prop or terrain layer – plus the backdrop's canvas drawing):
##              at most 0.6 ms on average, a chunk is committed in at most 3 ms (the best of three rounds: the
##              machine is shared). Since the assembly of M1 the shipped renderer also updates terrain, props,
##              signs, far ground, vehicles and flares every frame, so this check runs the core alone
##              (tests/race3d/fixtures/core_renderer.gd: road, roadside, backdrop, lights, overlay)
##   renderer_zeit  the same drive with the WHOLE shipped renderer and the session's traffic moving along: at most
##              1.5 ms GDScript per frame on average (contract §4.10 / QA1). Both times are taken next to a reference
##              workload of this process and scaled to the VM's normal speed (fixtures/perf_clock.gd, RINT-B): the
##              shared machine's load no longer decides the result
## Prints "CHECK <name> OK|FEHLER …" per check; exit code 0 when all pass.
## (The scene and the autoloads are accessed untyped: -s scripts compile before the autoloads exist.)

const RACE := "res://scenes/race/race.tscn"
const CHECKS := ["inhalt", "nacht", "tunnel", "waechter", "wechsel", "kern_zeit", "renderer_zeit", "ergebnis"]
const CORE_MS := 0.6
const RENDERER_MS := 1.5           ## the whole renderer, contract §4.10 (render() avg, this VM) and QA1 (12 cars, headless)
const COMMIT_MS := 3.0
const PERF_CLOCK := preload("res://tests/race3d/fixtures/perf_clock.gd")
const CORE_FIXTURE := "res://tests/race3d/fixtures/core_renderer.gd"

var _failed: Array[String] = []
var _renderers: GDScript
var _settings: Node
var _wall0 := 0
var _result: Dictionary = {}


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	_renderers = load("res://scripts/race/race_renderers.gd")
	_settings = root.get_node("Settings")
	_settings.call("disarm_crash_guard")
	var cli := CliArgs.all()
	var cli_graphics: Variant = cli.get("graphics", null)
	cli.erase("graphics")   # these checks choose the mode themselves
	var only := str(cli.get("only", ""))
	for c: String in CHECKS:
		if only == "" or only.split(",").has(c):
			await call("_check_" + c)
	_speed(1.0)
	_settings.call("disarm_crash_guard")
	if cli_graphics != null:
		cli["graphics"] = cli_graphics
	print("CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(), (Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)


# --- helpers ---------------------------------------------------------------------------------------------------

func _report(check: String, problems: Array[String], msg: String) -> void:
	var ok := problems.is_empty()
	print("CHECK %-10s %s  %s%s" % [check, "OK    " if ok else "FEHLER", msg, "" if ok else "  –  FEHLT: " + "; ".join(problems)])
	if not ok:
		_failed.append(check)


func _need(problems: Array[String], cond: bool, what: String) -> void:
	if not cond:
		problems.append(what)


func _speed(ts: float) -> void:
	Engine.time_scale = ts
	Engine.physics_ticks_per_second = maxi(1, int(round(60.0 * ts)))
	Engine.max_physics_steps_per_frame = clampi(int(ceil(ts)) * 2, 8, 128)


func _launch(extra: Dictionary) -> Node:
	var setup := {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 2.0, "autopilot": true, "autopilot_refuel": "never",
		"seed": 11, "gfx": "modern", "no_countdown": true, "start_speed_kmh": 120.0, "traffic_warmup": true}
	setup.merge(extra, true)
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	root.add_child(sc)
	return sc


func _free(sc: Node) -> void:
	sc.queue_free()
	await process_frame
	await process_frame
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP   # GameFlow does this between stages


func _until(cond: Callable, max_frames: int = 6000) -> int:
	var n := 0
	while not bool(cond.call()) and n < max_frames:
		await process_frame
		n += 1
	return n


## Starts a Modern stage and waits until it runs. Returns [scene, renderer].
func _stage(extra: Dictionary, steps: int = 5) -> Array:
	var sc := _launch(extra)
	await _until(func() -> bool: return int(sc.get("_sim_steps")) >= steps)
	return [sc, sc.get("renderer")]


func _file(obj: Variant) -> String:
	if obj == null or not (obj is Object) or (obj as Object).get_script() == null:
		return ""
	return str(((obj as Object).get_script() as Script).resource_path).get_file()


func _parts(r: ModernRenderer, builder_id: String) -> Array:
	var out: Array = []
	for c: Dictionary in r.debug_snapshot().get("chunks", []):
		var parts: Dictionary = c.get("parts", {})
		if parts.has(builder_id):
			out.append(parts[builder_id])
	return out


func _count(node: Node, cls: String) -> int:
	var n := 1 if node.is_class(cls) else 0
	for c: Node in node.get_children():
		n += _count(c, cls)
	return n


# --- inhalt ----------------------------------------------------------------------------------------------------

func _check_inhalt() -> void:
	var p: Array[String] = []
	_speed(10.0)
	var vp := root.get_viewport()
	var msaa0 := vp.msaa_3d
	var scale0 := vp.scaling_3d_scale
	CliArgs.all()["gfx-preset"] = "medium"
	var st: Array = await _stage({"start_km": 0.0, "start_speed_kmh": 0.0, "no_countdown": true})
	var sc: Node = st[0]
	var r: ModernRenderer = st[1]
	_need(p, str(sc.get("gfx")) == "modern" and r.is_prepared() and r.healthy(), "Modern-Etappe läuft")
	var snap := r.debug_snapshot()
	var builders: Array = snap.get("builders", [])
	_need(p, builders.has("road") and builders.has("roadside") and not (builders.has("debug_road") and builders.has("terrain")),
		"Builder road und roadside (%s)" % str(builders))
	var layers: Array = snap.get("layers", [])
	_need(p, layers.has("backdrop") and layers.has("lights") and layers.has("overlay"), "Ebenen backdrop, lights, overlay (%s)" % str(layers))
	# environment rig: `env`, one shadow-casting directional light in the whole renderer, post path pinned
	var env_snap: Dictionary = snap.get("environment", {})
	_need(p, r.env != null and not bool(env_snap.get("plain", true)) and bool(env_snap.get("shadow", false)) and bool(env_snap.get("post_pinned", false)),
		"Umgebungs-Rig als env, Schattenlicht, Nachbearbeitung fest an")
	_need(p, _count(r, "DirectionalLight3D") == 1, "genau ein DirectionalLight3D (%d)" % _count(r, "DirectionalLight3D"))
	var sun: DirectionalLight3D = r.env.get("sun")
	_need(p, sun != null and sun.shadow_enabled and sun.light_energy > 0.3 and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
		"Mittel: Sonne mit Schatten, zwei Kaskaden")
	_need(p, float(env_snap.get("share", 0.0)) > 0.4 and not bool(env_snap.get("moon", true)), "Mittag: die Hälfte des Lichts ist gerichtet")
	var fog: Array = env_snap.get("fog", [])
	_need(p, fog.size() == 3 and bool(fog[0]) and absf(float(fog[1]) - 0.45 * r.visibility_m) < 0.5 and absf(float(fog[2]) - r.visibility_m) < 0.5,
		"Tiefennebel von 0,45 × bis 1,0 × Sichtweite (%s bei %.0f m)" % [str(fog), r.visibility_m])
	# quality states of the viewport
	var rs: Dictionary = snap.get("render_state", {})
	_need(p, int(rs.get("msaa", -1)) == 2 and is_equal_approx(float(rs.get("scale_3d", 0.0)), 1.0) and int(rs.get("shadow_atlas", 0)) == 2048,
		"Mittel: MSAA 2×, 100 %%, Atlas 2048 (%s)" % str(rs))
	_need(p, vp.msaa_3d == Viewport.MSAA_2X, "MSAA am Viewport gesetzt")
	# road: every chunk, three lanes with two lane lines, edge lines, guardrails; the start line in the first chunk
	var roads := _parts(r, "road")
	var chunks: Array = snap.get("chunks", [])
	_need(p, chunks.size() >= 8 and roads.size() == chunks.size(), "Straße in jedem Stück (%d von %d)" % [roads.size(), chunks.size()])
	var flags_all := 0
	var lines := 0
	var tris := 0
	for part: Dictionary in roads:
		flags_all |= int(part.get("flags", 0))
		lines = maxi(lines, int(part.get("lines_max", 0)))
		tris += int(part.get("triangles", 0))
		_need(p, int(part.get("segments", 0)) == 32 and int(part.get("triangles", 0)) >= 64, "32 Segmente je Stück")
	_need(p, (flags_all & 1) != 0 and (flags_all & 16) != 0 and (flags_all & 256) != 0 and (flags_all & 512) != 0 and lines == 2,
		"Autobahn am Start: Randlinien, Startlinie, Leitplanken beidseits, zwei Leitlinien (Flags %d, %d Linien)" % [flags_all, lines])
	var sides := _parts(r, "roadside")
	var rails := 0
	var posts := 0
	var reflectors := 0
	for part: Dictionary in sides:
		rails += int(part.get("rail_left", 0)) + int(part.get("rail_right", 0))
		posts += int(part.get("posts", 0))
		reflectors += int(part.get("reflectors", 0))
	_need(p, rails >= roads.size() * 60 and posts >= rails / 2 - 4 and reflectors >= 8, "Leitplanken mit Pfosten und Reflektoren (%d Segmente, %d Pfosten, %d Reflektoren)" % [rails, posts, reflectors])
	# the ground: road meshes on render layer 2, casting no shadow; roadside meshes cast (medium)
	var ground := 0
	var casting := 0
	var road_nodes := 0
	for c: Node in r.streamer.get_children():
		var road := c.get_node_or_null("Road") as MeshInstance3D
		var side := c.get_node_or_null("Roadside") as MeshInstance3D
		if road != null:
			road_nodes += 1
			if road.layers == 2 and road.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				ground += 1
		if side != null and side.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON and side.layers == 1:
			casting += 1
	_need(p, road_nodes == chunks.size() and ground == road_nodes and casting >= road_nodes - 1, "Straße auf Boden-Ebene 2 ohne Schattenwurf, Leitplanken werfen Schatten (%d / %d / %d)" % [road_nodes, ground, casting])
	_need(p, int(snap.get("pool_materials", 0)) >= 1 and r.pool_materials().has(r.builder("road").get("material")), "Straßenmaterial für die Lichtkegel angemeldet")
	var lights: Dictionary = snap.get("lights", {})
	_need(p, int(lights.get("spot", -1)) == 0 and int(lights.get("pools", -1)) == 0 and float(lights.get("beam", 1.0)) == 0.0 and int(lights.get("reflectors", 0)) == reflectors,
		"bei Tag: kein Scheinwerfer, kein Lichtkegel; Reflektoren angemeldet (%s)" % str(lights))
	var back: Dictionary = snap.get("backdrop", {})
	_need(p, not bool(back.get("plain", true)) and is_equal_approx(float(back.get("horizon_frac", 0.0)), 0.45) and not bool(back.get("flat", true)),
		"Hintergrund: RaceBackdrop, Horizont auf 45 %% (%s)" % str(back))
	# the fuel lane and the City Limits further down the stage
	await _free(sc)
	st = await _stage({"start_km": 14.2})
	sc = st[0]
	r = st[1]
	flags_all = 0
	for part: Dictionary in _parts(r, "road"):
		flags_all |= int(part.get("flags", 0))
	_need(p, (flags_all & 2) != 0 and (flags_all & 4) != 0, "Tankspur: breite Trennlinie und Randlinie (Flags %d)" % flags_all)
	await _free(sc)
	st = await _stage({"start_km": 86.0, "start_speed_kmh": 50.0})
	sc = st[0]
	r = st[1]
	var city := 0
	flags_all = 0
	for part: Dictionary in _parts(r, "road"):
		city += int(part.get("city_segments", 0))
		flags_all |= int(part.get("flags", 0))
	_need(p, city >= 200 and (flags_all & 1024) != 0 and (flags_all & 32) != 0, "City Limits: Bordsteine und Zebrastreifen (%d Segmente, Flags %d)" % [city, flags_all])
	await _free(sc)
	_need(p, vp.msaa_3d == msaa0 and is_equal_approx(vp.scaling_3d_scale, scale0), "nach der Etappe sind MSAA und 3D-Auflösung wie vorher")
	CliArgs.all().erase("gfx-preset")
	_report("inhalt", p, "Kiel – Hamburg: Straße (%d Dreiecke in %d Stücken) mit Markierungen, %d Leitplankensegmente, %d Reflektoren; Rig mit einem Schattenlicht; Ebenen %s; Boden auf Ebene 2; Qualitätszustände gesetzt und zurückgegeben" % [
		tris, roads.size(), rails, reflectors, str(layers)])


# --- nacht -----------------------------------------------------------------------------------------------------

func _check_nacht() -> void:
	var p: Array[String] = []
	_speed(4.0)
	var st: Array = await _stage({"start_world_minutes": 23.0 * 60.0, "start_km": 30.0, "start_speed_kmh": 130.0}, 120)
	var sc: Node = st[0]
	var r: ModernRenderer = st[1]
	var lights: Dictionary = r.debug_snapshot().get("lights", {})
	_need(p, int(lights.get("spot", 0)) == 2 and float(lights.get("beam", 0.0)) > 0.9, "Abblendlicht: zwei Spots, volle Stärke (%s)" % str(lights))
	var layer: Node = r.layer("lights")
	var spots: Array = layer.get("spots")
	var ok_spots := spots.size() == 2
	for s: SpotLight3D in spots:
		ok_spots = ok_spots and s.visible and not s.shadow_enabled and (s.light_cull_mask & 2) == 0 and s.light_energy > 0.5
	_need(p, ok_spots, "Spots ohne Schatten, sie lassen die Boden-Ebene aus")
	_need(p, _count(r, "SpotLight3D") <= 2 and _count(r, "OmniLight3D") <= 8, "höchstens 2 Spots und 8 Punktlichter (D8)")
	var player: Dictionary = (r.view as Dictionary).get("player", {})
	var nose := r.road_to_world(float(player.get("z", 0.0)) + float(player.get("length", 4.6)), float(player.get("x", 0.0)), 0.66)
	_need(p, (spots[0] as SpotLight3D).position.distance_to(nose) < 1.0, "die Spots sitzen an der Wagenfront")
	# reflectors inside the low beam glint while the stage runs
	var seen_glints := 0
	var mat: ShaderMaterial = r.builder("road").get("material")
	for i in 600:
		await process_frame
		seen_glints = maxi(seen_glints, int((r.debug_snapshot().get("lights", {}) as Dictionary).get("glints", 0)))
		if seen_glints > 0:
			break
	_need(p, seen_glints >= 1, "Reflektoren im Lichtkegel glänzen (%d)" % seen_glints)
	# traffic ahead within 140 m: its cones go onto the road material. Fed with one car 60 m ahead of the camera
	# (whether the seeded traffic comes that close in a given number of frames is not the question here); the
	# next frame of the session sends its own view again.
	var tview: Dictionary = (r.view as Dictionary).duplicate()
	var tcar := {"kind": "car", "id": 9001, "set": "traffic/sedan", "z": float(tview["camera_z"]) + 60.0, "x": 0.0, "length": 4.5,
		"tail": 1.0, "brake": 0.0, "speed": 100.0}
	tview["cars"] = [tcar]
	var lights_layer: Node = r.layer("lights")
	lights_layer.call("update", tview, 0.0)
	var cones := int((r.debug_snapshot().get("lights", {}) as Dictionary).get("pools_traffic", 0))
	var n := int(mat.get_shader_parameter("pool_count"))
	_need(p, cones == 1 and n >= 1, "Lichtkegel des Verkehrs auf dem Straßenmaterial (%d Kegel, pool_count %d)" % [cones, n])
	if cones == 1 and n >= 1:
		var col: PackedVector4Array = mat.get_shader_parameter("pool_col")
		var dir: PackedVector4Array = mat.get_shader_parameter("pool_dir")
		var pos: PackedVector4Array = mat.get_shader_parameter("pool_pos_r")
		var at := r.road_to_world(float(tcar["z"]) + 4.5, 0.0, 0.0)
		_need(p, col.size() == 22 and col[n - 1].w > 0.5 and Vector3(dir[n - 1].x, dir[n - 1].y, dir[n - 1].z).length() > 0.9 and col[n - 1].x > 0.05,
			"Verkehrskegel: Art 1 mit Richtung und Lichtwert")
		_need(p, Vector3(pos[n - 1].x, pos[n - 1].y, pos[n - 1].z).distance_to(at) < 0.01 and is_equal_approx(pos[n - 1].w, 34.0),
			"der Kegel beginnt an der Wagenfront, Reichweite 34 m (Arcade)")
	# a car behind the camera or beyond 140 m gives no cone (Arcade's rule)
	tcar["z"] = float(tview["camera_z"]) + 150.0
	lights_layer.call("update", tview, 0.0)
	_need(p, int((r.debug_snapshot().get("lights", {}) as Dictionary).get("pools_traffic", -1)) == 0, "kein Kegel jenseits von 140 m")
	var seen_cones := cones
	var amb: Vector3 = mat.get_shader_parameter("pool_ambient")
	var pal: Dictionary = (r.view as Dictionary).get("palette", {})
	_need(p, amb != null and absf(amb.x - (pal["ambient"] as Color).r) < 1.0e-4, "pool_ambient = Umgebungslicht der Palette")
	var env_snap: Dictionary = r.debug_snapshot().get("environment", {})
	_need(p, bool(env_snap.get("moon", false)) and float(env_snap.get("share", 0.0)) > 0.1 and bool(env_snap.get("shadow", false)), "Nacht: Mondlicht mit Schatten")
	# a police chase: the overlay shows its lights
	var overlay: Node = r.layer("overlay")
	var rect: ColorRect = overlay.get("rect")
	_need(p, rect != null and not rect.visible, "ohne Verfolgung zeigt die Overlay-Ebene nichts")
	var view: Dictionary = (r.view as Dictionary).duplicate()
	view["chase01"] = 0.8
	overlay.call("update", view, 0.016)
	_need(p, rect.visible and overlay.layer == 2 and bool((overlay.call("snapshot") as Dictionary)["overlay"]["visible"]), "Verfolgung: Lichter auf Canvas-Ebene 2")
	view["chase01"] = 0.0
	overlay.call("update", view, 0.016)
	_need(p, not rect.visible, "… und wieder aus")
	await _free(sc)
	_report("nacht", p, "23 Uhr: Abblendlicht mit zwei Spots (Boden ausgenommen), %d Verkehrskegel auf dem Straßenmaterial, %d Reflexe; Mondlicht; Verfolgungslichter auf Ebene 2" % [seen_cones, seen_glints])


# --- tunnel ----------------------------------------------------------------------------------------------------

func _check_tunnel() -> void:
	var p: Array[String] = []
	_speed(4.0)
	var st: Array = await _stage({"stage_id": "bern_mailand", "from_city": "bern", "start_km": 186.0, "start_speed_kmh": 100.0}, 30)
	var sc: Node = st[0]
	var r: ModernRenderer = st[1]
	var view: Dictionary = r.view
	_need(p, bool(view.get("camera_in_tunnel", false)), "Bern – Mailand km 186: Kamera im Tunnel")
	var snap := r.debug_snapshot()
	var env_snap: Dictionary = snap.get("environment", {})
	var sun: DirectionalLight3D = r.env.get("sun")
	_need(p, float(env_snap.get("tunnel01", 0.0)) == 1.0 and sun.light_energy == 0.0 and sun.shadow_enabled and sun.visible,
		"Tunnel: Energie 0, das Licht bleibt bestehen (D5)")
	var fc: Array = env_snap.get("fog_color", [])
	_need(p, fc.size() == 3 and absf(float(fc[0]) - Palette.TUNNEL_FOG.r) < 0.001, "Nebel in der Tunnelfarbe")
	var fog: Array = env_snap.get("fog", [])
	_need(p, fog.size() == 3 and absf(float(fog[1]) - 12.0) < 0.01 and float(fog[2]) > 200.0 and float(fog[2]) < 300.0, "Tunnelnebel ab 12 m über die Dunkelstrecke (%s)" % str(fog))
	var amb: Array = env_snap.get("ambient", [])
	_need(p, amb.size() == 3 and float(amb[0]) > float(amb[2]) * 1.5, "warmes Tunnellicht (%s)" % str(amb))
	_need(p, bool((snap.get("backdrop", {}) as Dictionary).get("flat", false)), "ohne Tunnel-Builder ist die Canvas-Ebene dunkel")
	var lights: Dictionary = snap.get("lights", {})
	_need(p, float(lights.get("beam", 0.0)) >= 0.34, "Abblendlicht im Tunnel auch bei Tag (%.2f)" % float(lights.get("beam", 0.0)))
	var flags_all := 0
	for part: Dictionary in _parts(r, "road"):
		flags_all |= int(part.get("flags", 0))
	_need(p, (flags_all & 64) != 0, "Tunnelsegmente in der Straße")
	# the ramp at the portal: a function of the position
	var rig: Node = r.env
	var z0: float = r.track.km_to_z(float((r.track.plan.tunnels[0] as Dictionary)["start_km"]))
	for t: Dictionary in r.track.plan.tunnels:
		if float(view["camera_z"]) >= r.track.km_to_z(float(t["start_km"])) and float(view["camera_z"]) <= r.track.km_to_z(float(t["end_km"])):
			z0 = r.track.km_to_z(float(t["start_km"]))
	var before: float = rig.call("tunnel_blend", r.track, z0 - 30.0)
	var at: float = rig.call("tunnel_blend", r.track, z0)
	var inside: float = rig.call("tunnel_blend", r.track, z0 + 30.0)
	_need(p, before == 0.0 and at > 0.1 and at < 0.9 and inside == 1.0, "Rampe am Portal (%.2f / %.2f / %.2f)" % [before, at, inside])
	await _free(sc)
	_report("tunnel", p, "Bern – Mailand km 186: Tunnellicht %s, Nebel %s, Sonne mit Energie 0, Canvas dunkel, Abblendlicht %.2f; Rampe am Portal %.2f" % [
		str(amb), str(fog), float(lights.get("beam", 0.0)), at])


# --- waechter --------------------------------------------------------------------------------------------------

func _check_waechter() -> void:
	var p: Array[String] = []
	_speed(4.0)
	CliArgs.all()["gfx-preset"] = "medium"
	var st: Array = await _stage({"no_countdown": false, "start_km": 0.0, "start_speed_kmh": 0.0}, 3)
	CliArgs.all().erase("gfx-preset")
	var sc: Node = st[0]
	var r: ModernRenderer = st[1]
	var vp := root.get_viewport()
	var got: Array[String] = []
	r.quality_lowered.connect(func(preset: String) -> void: got.append(preset))
	var levels: Dictionary = r.levels
	var streamer_levels: Dictionary = r.streamer.levels
	_need(p, str(levels.get("preset", "")) == "medium" and int(levels.get("shadow_casters", 0)) == 2, "die Etappe läuft auf „Mittel“")
	var stats: Dictionary = r.perf_stats()
	_need(p, str(stats.get("watchdog", "x")) == "" and str(stats.get("quality_lowered", "x")) == "", "headless urteilt der Wächter nicht von selbst")
	var splits := int(levels.get("shadow_splits", 0))
	var filter := int(levels.get("shadow_filter", -1))
	r.call("_lower_quality")
	_need(p, got.size() == 1 and got[0] == "low", "Signal quality_lowered(\"low\") (%s)" % str(got))
	_need(p, str(r.levels.get("preset", "")) == "low" and int(r.levels.get("shadow_casters", 9)) == 0 and int(r.levels.get("msaa", 9)) == 0,
		"die Stufen der Etappe sind die von „Niedrig“")
	_need(p, int(r.levels.get("shadow_splits", 0)) == splits and int(r.levels.get("shadow_filter", -1)) == filter, "Schattenmodus und Filter der Etappe bleiben (keine neue Shader-Variante)")
	_need(p, is_same(r.levels, levels) and is_same(r.streamer.levels, streamer_levels) and int(streamer_levels.get("shadow_casters", 9)) == 0,
		"Streamer und Stücke sehen die gesenkten Stufen")
	_need(p, vp.msaa_3d == Viewport.MSAA_DISABLED and is_equal_approx(vp.scaling_3d_scale, 0.75), "Viewport: ohne MSAA, 75 %")
	var casting := 0
	for c: Node in r.streamer.get_children():
		var side := c.get_node_or_null("Roadside") as MeshInstance3D
		if side != null and side.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			casting += 1
	_need(p, casting == 0, "kein Stück wirft mehr Schatten (%d)" % casting)
	var sun: DirectionalLight3D = r.env.get("sun")
	_need(p, sun.shadow_enabled, "das Licht behält seinen Schatten (D5)")
	_need(p, str(sc.get("gfx_lowered")) == "low", "die Sitzung merkt sich die gesenkte Voreinstellung")
	var res: Dictionary = sc.call("build_result")
	_need(p, str(res.get("gfx_lowered", "")) == "low" and str(res.get("gfx", "")) == "modern", "Ergebnisfelder gfx und gfx_lowered")
	r.call("_lower_quality")
	_need(p, got.size() == 1, "nur ein Schritt je Etappe")
	_need(p, str(r.perf_stats().get("quality_lowered", "")) == "low", "perf_stats: quality_lowered")
	await _free(sc)
	_need(p, is_equal_approx(vp.scaling_3d_scale, 1.0), "nach der Etappe ist die 3D-Auflösung wieder wie vorher")
	_report("waechter", p, "Wächter senkt „Mittel“ auf „Niedrig“: Signal, Stufen, Viewport (ohne MSAA, 75 %), keine Schattenwerfer; Schattenmodus bleibt; Sitzung: gfx_lowered")


# --- wechsel ---------------------------------------------------------------------------------------------------

func _check_wechsel() -> void:
	var p: Array[String] = []
	_speed(4.0)
	var st: Array = await _stage({})
	var sc: Node = st[0]
	var shared := ModernMaterials.shared()
	_need(p, bool(_renderers.get("modern_used")), "RaceRenderers merkt sich die Modern-Etappe")
	await _free(sc)
	st = await _stage({})
	sc = st[0]
	_need(p, is_same(ModernMaterials.shared(), shared), "zwischen zwei Modern-Etappen bleiben die Materialien")
	await _free(sc)
	var arcade := _launch({"gfx": "arcade"})
	await _until(func() -> bool: return int(arcade.get("_sim_steps")) >= 3)
	_need(p, not bool(_renderers.get("modern_used")) and ModernMaterials._shared == null, "Arcade nach Modern: die gemeinsamen Modern-Materialien sind fort")
	_need(p, str(arcade.get("gfx")) == "arcade" and _file(arcade.get("renderer")) == "road_renderer.gd", "die Etappe zeichnet der Arcade-Renderer")
	await _free(arcade)
	st = await _stage({})
	sc = st[0]
	var r: ModernRenderer = st[1]
	_need(p, r.is_prepared() and r.healthy() and not is_same(ModernMaterials.shared(), shared), "die nächste Modern-Etappe baut ihre Materialien neu")
	await _free(sc)
	_report("wechsel", p, "Arcade-Renderer nach Modern gibt die Modern-Materialien frei; zwischen Modern-Etappen bleiben sie")


# --- kern_zeit -------------------------------------------------------------------------------------------------

func _check_kern_zeit() -> void:
	var p: Array[String] = []
	var best := {}
	_renderers.set("modern_script", CORE_FIXTURE)
	for round_i in 3:
		var m := await _drive_time({"start_speed_kmh": 150.0}, 1500, false)
		_need(p, int(m["commits"]) >= 4, "die Fahrt hat Stücke geladen (%d)" % int(m["commits"]))
		if best.is_empty() or float(m["total_ms"]) < float(best["total_ms"]):
			best = m
		best["commit_ms"] = minf(float(best.get("commit_ms", INF)), float(m["commit_ms"]))
		if float(best["total_ms"]) <= CORE_MS * 0.7 and float(best["commit_ms"]) <= COMMIT_MS * 0.7:
			break
	_renderers.set("modern_script", str(_renderers.get("MODERN_SCRIPT")))
	_need(p, float(best["total_ms"]) <= CORE_MS, "Renderer-Kern höchstens %.1f ms GDScript je Bild bei normalem Tempo der Maschine (%.3f ms)" % [CORE_MS, float(best["total_ms"])])
	_need(p, float(best["commit_ms"]) <= COMMIT_MS, "ein Stück hängt in höchstens %.0f ms ein (%.2f ms)" % [COMMIT_MS, float(best["commit_ms"])])
	_report("kern_zeit", p, "Renderer-Kern %.3f ms GDScript je Bild bei normalem Tempo über %d Bilder bei 150 km/h (%s); Einhängen eines Stücks höchstens %.2f ms" % [
		float(best["total_ms"]), int(best["frames"]), str(best["parts"]), float(best["commit_ms"])])


## RINT-B: the WHOLE shipped renderer (every builder and layer of the push) on a drive at 150 km/h with the session's
## traffic moving along with the camera: render() GDScript per frame at most RENDERER_MS on average at the VM's normal
## speed (contract §4.10 / QA1: 1.5 ms at 12 cars, headless). Next to the core budget of kern_zeit.
func _check_renderer_zeit() -> void:
	var p: Array[String] = []
	var best := {}
	for round_i in 2:
		var m := await _drive_time({"start_speed_kmh": 150.0}, 900, true)
		if best.is_empty() or float(m["total_ms"]) < float(best["total_ms"]):
			best = m
		if float(best["total_ms"]) <= RENDERER_MS * 0.7:
			break
	_need(p, int(best["cars"]) >= 8, "Verkehr in Sicht während der Messung (im Mittel %d Autos)" % int(best["cars"]))
	_need(p, float(best["total_ms"]) <= RENDERER_MS, "ganzer Renderer höchstens %.1f ms GDScript je Bild bei normalem Tempo der Maschine (%.3f ms)" % [
		RENDERER_MS, float(best["total_ms"])])
	_report("renderer_zeit", p, "ganzer Renderer (alle Builder und Ebenen) %.3f ms GDScript je Bild bei normalem Tempo, %d Bilder bei 150 km/h mit im Mittel %d Autos (%s); Einhängen höchstens %.2f ms" % [
		float(best["total_ms"]), int(best["frames"]), int(best["cars"]), str(best["parts"]), float(best["commit_ms"])])


## Drives the renderer of a stopped session with the views of a drive at 150 km/h and 60 frames per second and times
## render() (wall clock, next to a reference workload of this process: fixtures/perf_clock.gd scales the times to the
## VM's normal speed). with_cars: the cars of the session's view move along with the camera (they keep their distance).
## Returns {"total_ms": render() + the backdrop's share of canvas drawing, normal speed; "render_ms", "raw_ms",
## "worst_ms", "factor", "commit_ms", "commits", "frames", "cars" (mean in the view), "parts" (text)}.
func _drive_time(extra: Dictionary, frames: int, with_cars: bool) -> Dictionary:
	_speed(1.0)
	var st: Array = await _stage(extra)
	var sc: Node = st[0]
	var r: Node = st[1]
	sc.set_process(false)
	sc.set_physics_process(false)
	var view: Dictionary = (r.get("view") as Dictionary).duplicate()
	var player: Dictionary = (view["player"] as Dictionary).duplicate()
	view["player"] = player
	var cars: Array = []
	if with_cars:
		for c: Variant in view.get("cars", []):
			if c is Dictionary:
				cars.append((c as Dictionary).duplicate())
	view["cars"] = cars
	var step := 150.0 / 3.6 / 60.0
	var streamer: Variant = r.get("streamer")
	streamer.call("reset_stats")
	var back: Node = r.call("layer", "backdrop")
	var clock: RefCounted = PERF_CLOCK.new()
	var total := 0
	var worst := 0
	var car_sum := 0
	for i in frames:
		view["camera_z"] = float(view["camera_z"]) + step
		player["z"] = float(player["z"]) + step
		for c: Dictionary in cars:
			c["z"] = float(c.get("z", 0.0)) + step
		view["time"] = float(view["time"]) + 1.0 / 60.0
		view["dt"] = 1.0 / 60.0
		if i % 5 == 0:
			clock.call("sample_reference")
		var t0 := Time.get_ticks_usec()
		r.call("render", view)
		var us := Time.get_ticks_usec() - t0
		total += us
		worst = maxi(worst, us)
		car_sum += cars.size()
		if i % 50 == 49:
			await process_frame   # the worker threads of the chunk builds and the canvas get their turn
	var k: float = clock.call("factor")
	var raw_ms := float(total) / float(frames) / 1000.0
	# the backdrop draws on its canvas item outside render(): its share per frame
	var paint_ms := 0.0
	var redraw_share := 0.0
	if back != null:
		var canvas: CanvasItem = back.get("canvas")
		var t1 := Time.get_ticks_usec()
		for i in 40:
			back.call("paint", canvas)
		paint_ms = float(Time.get_ticks_usec() - t1) / 40.0 / 1000.0
		var asked := int((back.call("snapshot") as Dictionary)["backdrop"]["frames"])
		# headless nothing is drawn: the share is what update() asked for – every 0.09 s of view time by day
		redraw_share = minf(1.0, (1.0 / 60.0) / 0.09) if asked > 0 else 0.0
	var stats: Dictionary = streamer.call("stats")
	var out := {"render_ms": raw_ms * k, "raw_ms": raw_ms, "worst_ms": float(worst) / 1000.0, "factor": k,
		"total_ms": (raw_ms + paint_ms * redraw_share) * k, "commit_ms": float(stats.get("commit_ms_max", 0.0)),
		"commits": int(stats.get("commits", 0)), "frames": frames, "cars": car_sum / maxi(frames, 1)}
	out["parts"] = "render() %.3f ms (Wanduhr %.3f ms, Referenz × %.2f, längstes Bild %.2f ms) + Hintergrund %.3f ms × %.2f" % [
		float(out["render_ms"]), raw_ms, k, float(out["worst_ms"]), paint_ms * k, redraw_share]
	await _free(sc)
	return out


# --- ergebnis --------------------------------------------------------------------------------------------------

func _on_finished(result: Dictionary) -> void:
	_result = result


func _drive(mode: String) -> Dictionary:
	_result = {}
	var sc := _launch({"gfx": mode, "start_km": 0.0, "start_speed_kmh": 0.0, "no_countdown": true, "autopilot_refuel": "auto", "traffic_warmup": false})
	sc.connect("stage_finished", _on_finished)
	var t0 := Time.get_ticks_msec()
	while _result.is_empty() and Time.get_ticks_msec() - t0 < 240000:
		await process_frame
	var out := _result.duplicate(true)
	out["_renderer"] = _file(sc.get("renderer"))
	await _free(sc)
	return out


func _check_ergebnis() -> void:
	var p: Array[String] = []
	_speed(40.0)
	var arcade: Dictionary = await _drive("arcade")
	var modern: Dictionary = await _drive("modern")
	_speed(1.0)
	_need(p, str(arcade.get("_renderer", "")) == "road_renderer.gd" and str(modern.get("_renderer", "")) == "modern_renderer.gd", "beide Renderer am Werk")
	arcade.erase("_renderer")
	modern.erase("_renderer")
	_need(p, not arcade.is_empty() and not modern.is_empty(), "beide Etappen kommen ins Ziel")
	_need(p, str(arcade.get("gfx", "")) == "arcade" and str(modern.get("gfx", "")) == "modern" and not modern.has("gfx_fallback"), "Ergebnisfeld gfx")
	var differ: Array[String] = []
	for k: Variant in arcade.keys():
		if str(k) != "gfx" and (not modern.has(k) or str(modern[k]) != str(arcade[k])):
			differ.append(str(k))
	for k: Variant in modern.keys():
		if not arcade.has(k):
			differ.append(str(k))
	_need(p, differ.is_empty(), "ERGEBNIS gleich bis auf gfx (verschieden: %s)" % str(differ))
	_report("ergebnis", p, "Kiel – Hamburg mit dem Autopiloten: ERGEBNIS in Arcade und Modern gleich (%d Schlüssel, Zeit %s s, %s Tankstopps)" % [
		arcade.size(), str(arcade.get("time_s", arcade.get("total_time_s", "?"))), str(arcade.get("refuels", "?"))])
