extends SceneTree
## QA lens 1: the race session in Modern, frame by frame (run headless or under Xvfb).
##   -- --qa=<real|slow_pause|leave> [--graphics=modern] [--gfx-debug=fail] [--frames=N] [--stage=…]
## real        the shipped renderer (stub of wave 0): marker, preparation, sprite sheets, result
## slow_pause  the seam probe with a long preparation; the pause key is pressed while the stage is prepared

const PROBE := "res://tests/race3d/fixtures/seam_probe_renderer.gd"
const RACE := "res://scenes/race/race.tscn"

var _marker := ""
var _sig: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _key(code: Key) -> void:
	for pr: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pr
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		for i in 3:
			await process_frame


func _m() -> String:
	return "M" if FileAccess.file_exists(_marker) else "-"

func _run() -> void:
	var settings: Node = root.get_node("Settings")
	var sprites: Node = root.get_node("SpriteDB")
	_marker = ProjectSettings.globalize_path(str(settings.get("marker_path")))
	var what := CliArgs.get_string("qa", "real")
	var frames := int(CliArgs.get_float("frames", 400.0))
	var renderers: GDScript = load("res://scripts/race/race_renderers.gd")
	var probe: GDScript = load(PROBE)
	var setup := {"mode": "single", "race_id": "", "stage_id": CliArgs.get_string("stage", "kiel_hamburg"), "from_city": "", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 20.0, "autopilot": what != "slow_pause", "seed": 3}
	if what == "slow_pause":
		renderers.set("modern_script", PROBE)
		probe.call("reset")
		probe.set("prepare_frames", 240)
		probe.set("marker_path", _marker)
		setup["gfx"] = "modern"
	print("QA start marker=%s effective=%s loads=%d" % [_m(), str(settings.call("effective_graphics")), int(sprites.get("loads"))])
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	sc.connect("stage_aborted", func(r: String) -> void: _sig.append("stage_aborted:" + r))
	sc.connect("restart_requested", func() -> void: _sig.append("restart_requested"))
	root.add_child(sc)
	print("QA added marker=%s gfx=%s state=%d renderer=%s preloaded=%d loads=%d" % [_m(), str(sc.get("gfx")), int(sc.get("_gfx_state")),
		str((sc.get("renderer") as Node).get_script().resource_path.get_file()) if sc.get("renderer") != null else "null",
		(sc.get("preloaded_sets") as Array).size(), int(sprites.get("loads"))])
	var t0 := Time.get_ticks_msec()
	var last := ""
	var went_live := -1
	var marker_gone := -1
	for f in frames:
		await process_frame
		var state := int(sc.get("_gfx_state"))
		var steps := int(sc.get("_sim_steps"))
		var live := bool(sc.call("is_live"))
		var line := "state=%d live=%s steps=%s marker=%s paused=%s loading=%s menu=%s" % [state, live, "0" if steps == 0 else ">0", _m(), paused,
			sc.get("_loading") != null, (sc.get("pause_menu") as Control).visible]
		if line != last:
			print("QA f%03d %5d ms  %s  (sim_steps %d, countdown %.2f, pos_z %.1f)" % [f, Time.get_ticks_msec() - t0, line, steps, float(sc.get("countdown")), float(sc.get("pos_z"))])
			last = line
		if live and went_live < 0:
			went_live = f
		if went_live >= 0 and marker_gone < 0 and _m() == "-":
			marker_gone = Time.get_ticks_msec() - t0
		if what == "slow_pause":
			if f == 30:
				print("QA --- pause key pressed while the stage is prepared (frame 30)")
				await _key(KEY_P)
			if f == 200:
				var menu: Control = sc.get("pause_menu")
				var lay: CanvasLayer = sc.get("_loading")
				var fo := root.gui_get_focus_owner()
				print("QA --- frame 200: paused=%s, pause menu visible=%s on layer %d, loading overlay %s on layer %d, focus on '%s', probe frames prepared %s, progress %.2f" % [
					paused, menu.visible, (menu.get_parent() as CanvasLayer).layer, "present" if lay != null else "gone", lay.layer if lay != null else -1,
					(fo as Button).text if fo is Button else str(fo), str((sc.get("renderer") as Node).call("is_prepared")), float((sc.get("renderer") as Node).call("prepare_progress"))])
				print("QA --- player presses 'down' and 'accept' on what he cannot see")
				await _key(KEY_DOWN)
				await _key(KEY_ENTER)
			if f == 215:
				print("QA --- afterwards: scene valid=%s in tree=%s paused=%s aborted=%s restart=%s" % [is_instance_valid(sc), is_instance_valid(sc) and sc.is_inside_tree(), paused, str(_sig), ""])
				break
	if what != "slow_pause":
		print("QA went live at frame %d, marker gone %d ms after start (wall), time_scale %.1f" % [went_live, marker_gone, Engine.time_scale])
		var res: Dictionary = sc.call("build_result")
		print("QA result gfx=%s gfx_fallback=%s" % [str(res.get("gfx")), str(res.get("gfx_fallback", "<none>"))])
		var log: Array = sprites.get("load_log")
		var kinds := {}
		for id: String in log:
			var k := id.split("/")[0]
			kinds[k] = int(kinds.get(k, 0)) + 1
		print("QA sprite sheets loaded: %d %s" % [log.size(), str(kinds)])
		var hud: Node = sc.get("hud")
		var msgs: Variant = hud.get("_messages") if hud != null else null
		print("QA aspect=%d (0 ignore,1 keep,4 expand) " % int(root.content_scale_aspect))
		var perf: Dictionary = sc.call("perf_stats")
		print("QA perf mode=%s vehicles=%s frames=%s" % [str(perf.get("mode", "arcade")), str(perf.get("vehicles", "?")), str(perf.get("frames", "?"))])
	renderers.set("modern_script", renderers.get("MODERN_SCRIPT"))
	if is_instance_valid(sc):
		sc.queue_free()
	await process_frame
	await process_frame
	print("QA end marker=%s" % _m())
	paused = false
	quit(0)
