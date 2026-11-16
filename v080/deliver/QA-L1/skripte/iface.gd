extends SceneTree
## QA lens 1: interfaces of contract §4.1–§4.5 against the code, by reflection.

var bad := 0

func _m(script: Script, name: String) -> Dictionary:
	for m: Dictionary in script.get_script_method_list():
		if str(m["name"]) == name:
			return m
	return {}

func _sig(script: Script, name: String, args: Array, defaults: int = 0, ret: int = -1, is_static: bool = false) -> void:
	var m := _m(script, name)
	var label := "%s.%s" % [script.resource_path.get_file(), name]
	if m.is_empty():
		print("IFACE FEHLT   %s" % label)
		bad += 1
		return
	var got: Array = []
	for a: Dictionary in m["args"]:
		got.append("%s:%d" % [a["name"], int(a["type"])])
	var want: Array = []
	for a: Variant in args:
		want.append(str(a))
	var names_got: Array = []
	for a: Dictionary in m["args"]:
		names_got.append(str(a["name"]))
	var problems: Array = []
	if names_got.size() != args.size():
		problems.append("Argumentzahl %d statt %d (%s)" % [names_got.size(), args.size(), ", ".join(names_got)])
	else:
		for i in args.size():
			var w := str(args[i]).split(":")
			if w[0] != "*" and w[0] != names_got[i]:
				problems.append("Argument %d heißt %s statt %s" % [i, names_got[i], w[0]])
			if w.size() > 1 and int(w[1]) != int((m["args"][i] as Dictionary)["type"]):
				problems.append("Argument %s Typ %d statt %s" % [names_got[i], int((m["args"][i] as Dictionary)["type"]), w[1]])
	if (m["default_args"] as Array).size() != defaults:
		problems.append("Vorgabewerte %d statt %d %s" % [(m["default_args"] as Array).size(), defaults, str(m["default_args"])])
	if ret >= 0 and int((m["return"] as Dictionary)["type"]) != ret:
		problems.append("Rückgabetyp %d statt %d" % [int((m["return"] as Dictionary)["type"]), ret])
	var st := (int(m["flags"]) & METHOD_FLAG_STATIC) != 0
	if st != is_static:
		problems.append("static %s statt %s" % [st, is_static])
	if problems.is_empty():
		print("IFACE ok      %s(%s) defaults=%s" % [label, ", ".join(names_got), str(m["default_args"])])
	else:
		print("IFACE ABWEICHUNG %s: %s" % [label, "; ".join(problems)])
		bad += 1

func _signal(script: Script, name: String, args: Array) -> void:
	for s: Dictionary in script.get_script_signal_list():
		if str(s["name"]) == name:
			var got: Array = []
			for a: Dictionary in s["args"]:
				got.append("%s:%d" % [a["name"], int(a["type"])])
			if got == args:
				print("IFACE ok      signal %s.%s(%s)" % [script.resource_path.get_file(), name, ", ".join(got)])
			else:
				print("IFACE ABWEICHUNG signal %s.%s(%s) statt (%s)" % [script.resource_path.get_file(), name, ", ".join(got), ", ".join(args)])
				bad += 1
			return
	print("IFACE FEHLT   signal %s.%s" % [script.resource_path.get_file(), name])
	bad += 1

func _const(script: Script, name: String, want: Variant) -> void:
	var c := script.get_script_constant_map()
	if not c.has(name):
		print("IFACE FEHLT   const %s.%s" % [script.resource_path.get_file(), name])
		bad += 1
	elif typeof(c[name]) != typeof(want) or c[name] != want:
		print("IFACE ABWEICHUNG const %s.%s = %s statt %s" % [script.resource_path.get_file(), name, str(c[name]), str(want)])
		bad += 1
	else:
		print("IFACE ok      const %s.%s = %s" % [script.resource_path.get_file(), name, str(c[name])])

func _prop(script: Script, name: String, type: int = -1) -> void:
	for p: Dictionary in script.get_script_property_list():
		if str(p["name"]) == name:
			if type >= 0 and int(p["type"]) != type:
				print("IFACE ABWEICHUNG var %s.%s Typ %d statt %d" % [script.resource_path.get_file(), name, int(p["type"]), type])
				bad += 1
			else:
				print("IFACE ok      var %s.%s (Typ %d)" % [script.resource_path.get_file(), name, int(p["type"])])
			return
	print("IFACE FEHLT   var %s.%s" % [script.resource_path.get_file(), name])
	bad += 1

func _initialize() -> void:
	var S: Script = load("res://scripts/core/settings.gd")
	print("--- §4.1 Settings")
	_const(S, "SETTINGS_VERSION", 3)
	_const(S, "FULLSCREEN_CHOICE_SINCE", 2)
	_prop(S, "graphics_mode", TYPE_STRING); _prop(S, "sound_profile", TYPE_STRING); _prop(S, "gfx_preset", TYPE_STRING)
	_prop(S, "gfx_custom", TYPE_DICTIONARY); _prop(S, "race_music", TYPE_BOOL)
	_signal(S, "graphics_changed", ["mode:%d" % TYPE_STRING])
	_signal(S, "quality_changed", ["quality:%d" % TYPE_DICTIONARY])
	_signal(S, "sound_profile_changed", ["profile:%d" % TYPE_STRING])
	_sig(S, "effective_graphics", [], 0, TYPE_DICTIONARY)
	_sig(S, "is_modern", [], 0, TYPE_BOOL)
	_sig(S, "quality", [], 0, TYPE_DICTIONARY)
	_sig(S, "quality_levels", [], 0, TYPE_DICTIONARY)
	_sig(S, "sound", [], 0, TYPE_STRING)
	_sig(S, "adapter_tier", [], 0, TYPE_STRING)
	_sig(S, "fullscreen_stored_as_choice", ["*:%d" % TYPE_DICTIONARY], 0, TYPE_BOOL, true)
	print("--- §4.1 Gfx")
	var G: Script = load("res://scripts/core/gfx.gd")
	_const(G, "ARCADE", "arcade"); _const(G, "MODERN", "modern")
	var po: Array[String] = ["deck", "low", "medium", "high", "custom"]
	_const(G, "PRESET_ORDER", po)
	var qk: Array[String] = ["shadows", "details", "scale", "aa", "effects"]
	_const(G, "QUALITY_KEYS", qk)
	var ss: Array[int] = [50, 67, 75, 85, 100, 125, 150]
	_const(G, "SCALE_STEPS", ss)
	_const(G, "BOOT_MARKER", "user://modern_start.lock")
	_sig(G, "classify_adapter", ["adapter:%d" % TYPE_STRING, "vendor:%d" % TYPE_STRING, "api:%d" % TYPE_STRING, "gamescope:%d" % TYPE_BOOL], 3, TYPE_STRING, true)
	_sig(G, "recommended_mode", ["tier:%d" % TYPE_STRING], 0, TYPE_STRING, true)
	_sig(G, "recommended_preset", ["tier:%d" % TYPE_STRING], 0, TYPE_STRING, true)
	_sig(G, "resolve_mode", ["chosen:%d" % TYPE_STRING, "cli:%d" % TYPE_STRING, "force:%d" % TYPE_STRING, "marker:%d" % TYPE_BOOL], 0, TYPE_DICTIONARY, true)
	_sig(G, "quality", ["preset:%d" % TYPE_STRING, "custom:%d" % TYPE_DICTIONARY, "presets:%d" % TYPE_DICTIONARY], 0, TYPE_DICTIONARY, true)
	_sig(G, "preset_of", ["q:%d" % TYPE_DICTIONARY, "presets:%d" % TYPE_DICTIONARY], 0, TYPE_STRING, true)
	_sig(G, "sanitized", ["q:%d" % TYPE_DICTIONARY], 0, TYPE_DICTIONARY, true)
	_sig(G, "with_cli", ["q:%d" % TYPE_DICTIONARY, "preset_arg:%d" % TYPE_STRING, "set_arg:%d" % TYPE_STRING, "presets:%d" % TYPE_DICTIONARY], 0, TYPE_DICTIONARY, true)
	_sig(G, "levels", ["q:%d" % TYPE_DICTIONARY, "gfx_cfg:%d" % TYPE_DICTIONARY], 0, TYPE_DICTIONARY, true)
	_sig(G, "watchdog_verdict", ["median_ms:%d" % TYPE_FLOAT, "p95_ms:%d" % TYPE_FLOAT, "target_ms:%d" % TYPE_FLOAT, "wd_cfg:%d" % TYPE_DICTIONARY, "lowest:%d" % TYPE_BOOL], 0, TYPE_STRING, true)
	print("    Gfx base:", G.get_instance_base_type(), " global class:", G.get_global_name())
	var T: Script = load("res://scripts/core/gfx_self_test.gd")
	_sig(T, "run", ["parent:%d" % TYPE_OBJECT, "frames:%d" % TYPE_INT], 1, TYPE_DICTIONARY, true)
	print("--- §4.4 seam")
	var RR: Script = load("res://scripts/race/race_renderers.gd")
	_sig(RR, "create", ["mode:%d" % TYPE_STRING], 0, TYPE_OBJECT, true)
	print("    RaceRenderers global class:", RR.get_global_name())
	var MR: Script = load("res://scripts/race3d/modern_renderer.gd")
	print("    ModernRenderer base:", MR.get_instance_base_type(), " global:", MR.get_global_name())
	_sig(MR, "setup", ["*", "*", "*", "*"], 0)
	_sig(MR, "render", ["view:%d" % TYPE_DICTIONARY], 0)
	_sig(MR, "perf_stats", [], 0, TYPE_DICTIONARY)
	_sig(MR, "apply_quality", ["*:%d" % TYPE_DICTIONARY], 0)
	_sig(MR, "prepare", ["ctx:%d" % TYPE_DICTIONARY], 0)
	_sig(MR, "is_prepared", [], 0, TYPE_BOOL)
	_sig(MR, "prepare_progress", [], 0, TYPE_FLOAT)
	_sig(MR, "healthy", [], 0, TYPE_BOOL)
	_sig(MR, "fail_reason", [], 0, TYPE_STRING)
	_sig(MR, "debug_snapshot", [], 0, TYPE_DICTIONARY)
	_sig(MR, "world_to_screen", ["z:%d" % TYPE_FLOAT, "x:%d" % TYPE_FLOAT, "h:%d" % TYPE_FLOAT], 0, TYPE_VECTOR3)
	_signal(MR, "quality_lowered", ["preset:%d" % TYPE_STRING])
	var RRd: Script = load("res://scripts/race/road_renderer.gd")
	_sig(RRd, "setup", ["*", "*", "*", "*"], 0)
	_sig(RRd, "render", ["*:%d" % TYPE_DICTIONARY], 0)
	_sig(RRd, "perf_stats", [], 0, TYPE_DICTIONARY)
	print("--- §4.5 kernel")
	var P: Script = load("res://scripts/race3d/road_path.gd")
	_sig(P, "setup", ["*:%d" % TYPE_OBJECT, "start_index:%d" % TYPE_INT, "curve_radius_at_1:%d" % TYPE_FLOAT], 0)
	_sig(P, "ensure", ["index:%d" % TYPE_INT], 0)
	_prop(P, "first", TYPE_INT)
	_sig(P, "last", [], 0, TYPE_INT)
	_sig(P, "point", ["k:%d" % TYPE_INT], 0, TYPE_VECTOR3)
	_sig(P, "heading", ["k:%d" % TYPE_INT], 0, TYPE_FLOAT)
	_sig(P, "centre_at", ["z:%d" % TYPE_FLOAT], 0, TYPE_VECTOR3)
	_sig(P, "heading_at", ["z:%d" % TYPE_FLOAT], 0, TYPE_FLOAT)
	_sig(P, "world", ["z:%d" % TYPE_FLOAT, "x:%d" % TYPE_FLOAT, "h:%d" % TYPE_FLOAT], 0, TYPE_VECTOR3)
	_sig(P, "frame_at", ["z:%d" % TYPE_FLOAT, "x:%d" % TYPE_FLOAT, "h:%d" % TYPE_FLOAT], 2, TYPE_TRANSFORM3D)
	_sig(P, "rebase", ["to_index:%d" % TYPE_INT], 0, TYPE_VECTOR3)
	_sig(P, "trim", ["before_index:%d" % TYPE_INT], 0)
	_sig(P, "clearance", ["k:%d" % TYPE_INT, "side:%d" % TYPE_INT], 0, TYPE_FLOAT)
	_sig(P, "floor_y", ["k:%d" % TYPE_INT], 0, TYPE_FLOAT)
	_sig(P, "right_of", ["a:%d" % TYPE_FLOAT], 0, TYPE_VECTOR3, true)
	_sig(P, "fwd_of", ["a:%d" % TYPE_FLOAT], 0, TYPE_VECTOR3, true)
	var C: Script = load("res://scripts/race3d/chase_camera.gd")
	_sig(C, "setup", ["proj:%d" % TYPE_OBJECT, "cam_cfg:%d" % TYPE_DICTIONARY], 0)
	_sig(C, "look_yaw", ["path:%d" % TYPE_OBJECT, "cam_z:%d" % TYPE_FLOAT], 0, TYPE_FLOAT)
	_sig(C, "transform", ["view:%d" % TYPE_DICTIONARY, "path:%d" % TYPE_OBJECT], 0, TYPE_TRANSFORM3D)
	_sig(C, "frustum", ["viewport_size:%d" % TYPE_VECTOR2, "shake:%d" % TYPE_VECTOR2], 0, TYPE_DICTIONARY)
	_sig(C, "project", ["cam:%d" % TYPE_TRANSFORM3D, "fr:%d" % TYPE_DICTIONARY, "viewport_size:%d" % TYPE_VECTOR2, "p:%d" % TYPE_VECTOR3], 0, TYPE_VECTOR3, true)
	var TP: Script = load("res://scripts/race3d/terrain_profile.gd")
	_sig(TP, "setup", ["path:%d" % TYPE_OBJECT, "track:%d" % TYPE_OBJECT, "terrain_cfg:%d" % TYPE_DICTIONARY, "scenery_db:%d" % TYPE_DICTIONARY], 0)
	_sig(TP, "ring_offsets", ["k:%d" % TYPE_INT, "side:%d" % TYPE_INT], 0, TYPE_PACKED_FLOAT32_ARRAY)
	_sig(TP, "height", ["k:%d" % TYPE_INT, "side:%d" % TYPE_INT, "lateral_m:%d" % TYPE_FLOAT], 0, TYPE_FLOAT)
	_sig(TP, "corridor_width", ["k:%d" % TYPE_INT, "side:%d" % TYPE_INT], 0, TYPE_FLOAT)
	var CC: Script = load("res://scripts/race3d/chunk_context.gd")
	for pr: Array in [["index", TYPE_INT], ["seg_a", TYPE_INT], ["seg_b", TYPE_INT], ["segs", TYPE_ARRAY], ["rows_o", TYPE_PACKED_VECTOR3_ARRAY],
			["rows_r", TYPE_PACKED_VECTOR3_ARRAY], ["rows_f", TYPE_PACKED_VECTOR3_ARRAY], ["rows_edge", TYPE_PACKED_VECTOR2_ARRAY],
			["floor_y", TYPE_PACKED_FLOAT32_ARRAY], ["ring_x", TYPE_PACKED_FLOAT32_ARRAY], ["ring_h", TYPE_PACKED_FLOAT32_ARRAY],
			["path", TYPE_OBJECT], ["terrain", TYPE_OBJECT], ["cfg", TYPE_DICTIONARY], ["scenery_db", TYPE_DICTIONARY], ["levels", TYPE_DICTIONARY], ["sync", TYPE_BOOL]]:
		_prop(CC, pr[0], pr[1])
	_sig(CC, "local", ["z:%d" % TYPE_FLOAT, "x:%d" % TYPE_FLOAT, "h:%d" % TYPE_FLOAT], 0, TYPE_VECTOR3)
	_sig(CC, "frame", ["z:%d" % TYPE_FLOAT, "x:%d" % TYPE_FLOAT, "h:%d" % TYPE_FLOAT, "yaw_rad:%d" % TYPE_FLOAT], 1, TYPE_TRANSFORM3D)
	_sig(CC, "ground", ["z:%d" % TYPE_FLOAT, "x:%d" % TYPE_FLOAT], 0, TYPE_FLOAT)
	var CB: Script = load("res://scripts/race3d/chunk_builder.gd")
	_sig(CB, "id", [], 0, TYPE_STRING)
	_sig(CB, "collect", ["*:%d" % TYPE_OBJECT], 0)
	_sig(CB, "build", ["*:%d" % TYPE_OBJECT, "*"], 0, TYPE_DICTIONARY)
	_sig(CB, "commit", ["*:%d" % TYPE_OBJECT, "*:%d" % TYPE_DICTIONARY, "*:%d" % TYPE_OBJECT], 0)
	_sig(CB, "debug", ["*:%d" % TYPE_DICTIONARY], 0, TYPE_DICTIONARY)
	var CS: Script = load("res://scripts/race3d/chunk_streamer.gd")
	_sig(CS, "setup", ["*:%d" % TYPE_OBJECT, "*:%d" % TYPE_OBJECT, "*:%d" % TYPE_OBJECT, "*:%d" % TYPE_DICTIONARY, "*:%d" % TYPE_DICTIONARY, "*:%d" % TYPE_BOOL], 0)
	_sig(CS, "register", ["builder:%d" % TYPE_OBJECT], 0)
	_sig(CS, "update", ["cam_z:%d" % TYPE_FLOAT, "visibility_m:%d" % TYPE_FLOAT], 0)
	_sig(CS, "chunk_count", [], 0, TYPE_INT)
	_sig(CS, "snapshot", [], 0, TYPE_DICTIONARY)
	var BR: Script = load("res://scripts/race3d/builder_registry.gd")
	var bl: Array[String] = ["road", "roadside", "terrain", "props", "signs", "tunnel", "bridge", "station", "border", "city", "gantry", "radar", "landmarks"]
	_const(BR, "BUILDERS", bl)
	var ll: Array[String] = ["vehicles", "flares", "backdrop", "far_ground", "lights", "weather", "overlay", "post"]
	var have: Array = (BR.get_script_constant_map()["LAYERS"] as Array).duplicate()
	have.sort(); var want := ll.duplicate(); want.sort()
	print("IFACE %s LAYERS (Menge) %s" % ["ok     " if have == Array(want) else "ABWEICHUNG", str(BR.get_script_constant_map()["LAYERS"])])
	print("--- §4.3 config keys")
	var cfg := ConfigLoader.load_merged()
	for k: String in ["graphics.force_mode", "graphics.presets.deck", "graphics.presets.low", "graphics.presets.medium", "graphics.presets.high",
			"graphics.levels.shadows", "graphics.levels.details", "graphics.levels.aa", "graphics.levels.effects",
			"graphics.modern.camera.look_gain", "graphics.modern.camera.look_m", "graphics.modern.camera.yaw_max_deg", "graphics.modern.camera.near_m",
			"graphics.modern.camera.far_m", "graphics.modern.chunk_segments", "graphics.modern.load_path_m", "graphics.modern.landmark_path_m",
			"graphics.modern.keep_behind_m", "graphics.modern.threaded_build", "graphics.modern.commits_per_frame", "graphics.modern.fog.begin_frac",
			"graphics.modern.fog.end_frac", "graphics.modern.terrain.rings_m", "graphics.modern.terrain.inside_bend_factor",
			"graphics.modern.terrain.floor_window_m", "graphics.modern.terrain.floor_drop_m", "graphics.modern.terrain.far_ground_drop_m",
			"graphics.modern.lights.spots", "graphics.modern.lights.pools_lamps", "graphics.modern.lights.pools_traffic", "graphics.modern.sky_update_s",
			"graphics.modern.prewarm", "graphics.watchdog.countdown_min_fps", "graphics.watchdog.slow_factor", "graphics.watchdog.too_slow_factor",
			"graphics.benchmark.seconds", "graphics.benchmark.scenes", "graphics.budgets.deck.draw_calls", "graphics.budgets.low", "graphics.budgets.medium",
			"graphics.budgets.high", "audio.profile", "audio.modern"]:
		var v: Variant = ConfigLoader.lookup(cfg, k, null)
		if v == null:
			print("IFACE FEHLT   config %s" % k)
			bad += 1
	print("IFACE config keys geprüft")
	print("IFACE ERGEBNIS: %d Abweichungen" % bad)
	quit(0 if bad == 0 else 1)
