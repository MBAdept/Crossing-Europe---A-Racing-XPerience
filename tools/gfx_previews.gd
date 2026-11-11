extends SceneTree
## Preview pictures of the two graphics modes for the options (page GRAFIK) and the first-start chooser "GRAFIK
## WÄHLEN" (v0.8.0, docs/grafik-modi.md): the same road from the same simulation state, once drawn by Arcade and once
## by Modern – Kiel – Hamburg near km 2 at noon, dry, fixed traffic seed, the autopilot at cruising speed, without
## the HUD. Writes assets/ui/gfx_preview_arcade.webp and gfx_preview_modern.webp (960 × 540).
## Run through tools/gfx_previews.sh (Xvfb, software OpenGL); regenerate whenever the Modern renderer changes its
## look – the pictures show whatever renderer the tree contains.
##   godot --path . --rendering-driver opengl3 --audio-driver Dummy --fixed-fps 60 -s res://tools/gfx_previews.gd \
##         -- [--out=<dir>] [--only=arcade|modern] [--km=2.0] [--seconds=2.5] [--gfx-preset=high] --gfx-sync
## The race scene is loaded at run time (a -s script compiles before the autoloads exist).

const RACE_SCENE := "res://scenes/race/race.tscn"
const SIZE := Vector2i(960, 540)
const HUD_LAYERS: Array[int] = [5, 6]   ## HUD + pause menu, loading overlay (contract §4.4.4)

var _args: Dictionary = {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	_run.call_deferred()


func _setup(mode: String) -> Dictionary:
	return {"mode": "single", "race_id": "", "stage_id": "kiel_hamburg", "from_city": "kiel", "vehicle": "limousine",
		"start_world_minutes": 12.5 * 60.0, "weather": "normal", "start_km": float(str(_args.get("km", "2.0"))),
		"seed": 7, "autopilot": true, "autopilot_target": 130.0, "autopilot_speeding": false, "autopilot_refuel": "never",
		"no_countdown": true, "traffic_warmup": true, "start_speed_kmh": 125.0, "gfx": mode}


func _run() -> void:
	var out_dir := str(_args.get("out", ProjectSettings.globalize_path("res://assets/ui")))
	var modes: Array[String] = ["arcade", "modern"]
	if _args.has("only"):
		modes = [str(_args["only"])]
	var ok := true
	for mode in modes:
		ok = await _shoot(mode, out_dir.path_join("gfx_preview_%s.webp" % mode)) and ok
	quit(0 if ok else 1)


func _shoot(mode: String, path: String) -> bool:
	var scene: Node = (load(RACE_SCENE) as PackedScene).instantiate()
	scene.set("setup", _setup(mode))
	root.add_child(scene)
	# prepared (Modern: models, warm-up) and live
	var t0 := Time.get_ticks_msec()
	while not bool(scene.call("is_live")) and Time.get_ticks_msec() - t0 < 120000:
		await process_frame
	var drawn := str(scene.get("gfx"))
	# a fixed stretch of driving: the same simulation state in both modes (fixed fps, same seed)
	var frames := int(float(str(_args.get("seconds", "2.5"))) * 60.0)
	for i in frames:
		await process_frame
	for n in scene.find_children("*", "CanvasLayer", true, false):
		if HUD_LAYERS.has((n as CanvasLayer).layer):
			(n as CanvasLayer).visible = false
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
	var err := img.save_webp(path, true, 0.9)
	print("VORSCHAU %s (gezeichnet: %s) -> %s %s" % [mode, drawn, path, error_string(err)])
	scene.queue_free()
	for i in 4:
		await process_frame
	return err == OK and drawn == mode
