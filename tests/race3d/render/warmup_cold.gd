extends SceneTree
## Cold-cache shader warm-up check of the mode "Modern" (v0.8.0, contract D10, §4.9.4, §6 R1) – once per milestone and
## NOT part of tools/run_render_checks.sh, which shares one warm shader cache between its files. Run it with an empty
## user folder and an empty Mesa shader cache:
##   MESA_SHADER_CACHE_DIR=$(mktemp -d) XDG_DATA_HOME=$(mktemp -d) xvfb-run -a -s "-screen 0 1280x720x24" \
##       godot --path . --rendering-driver opengl3 --audio-driver Dummy -s res://tests/race3d/render/warmup_cold.gd \
##       -- --graphics=modern [--stage=kiel_hamburg] [--from=kiel] [--km=2] [--hour=12] [--weather=normal]
##          [--gfx-preset=medium] [--no-prewarm] [--seconds=30]
## The stage runs in real time as a player drives it (threaded chunk builds, autopilot, traffic): from the moment the
## loading overlay goes, the renderer's frame probe records every frame of the first 30 s (perf_stats
## start_frame_ms_*). Verdict (contract §4.9.4): no frame longer than 3 × the median – and, as the measure that does
## not depend on how busy the machine is, no shader variant compiled during the drive: the Mesa shader cache
## (MESA_SHADER_CACHE_DIR) holds one file per compiled variant, a file that appears more than a second after the
## loading overlay (the cache writer is asynchronous) is a compile in the middle of the drive. Prints
## "RENDER-CHECK warmup_kalt OK|FEHLER …" with both, the preparation and warm-up times and the longest frames; exit
## code 0 when it passes. With --no-prewarm the same run without the warm-up (shows what the warm-up buys).
## (The scene and the autoloads are accessed untyped: -s scripts compile before the autoloads exist.)

const RACE := "res://scenes/race/race.tscn"
const FACTOR := 3.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("RENDER-CHECK warmup_kalt FEHLER  braucht einen echten Renderer (Xvfb + --rendering-driver opengl3)")
		quit(1)
		return
	var cli := CliArgs.all()
	var seconds := float(cli.get("seconds", "30"))
	var hour := float(cli.get("hour", "12"))
	var setup := {"mode": "single", "race_id": "", "stage_id": str(cli.get("stage", "kiel_hamburg")), "from_city": str(cli.get("from", "kiel")),
		"vehicle": "limousine", "start_world_minutes": hour * 60.0, "weather": str(cli.get("weather", "normal")),
		"start_km": float(cli.get("km", "2")), "autopilot": true, "autopilot_refuel": "auto", "seed": 11, "gfx": "modern",
		"no_countdown": true, "start_speed_kmh": 120.0, "traffic_warmup": true}
	if not cli.has("gfx-preset"):
		cli["gfx-preset"] = "medium"
	var t0 := Time.get_ticks_msec()
	var sc: Node = (load(RACE) as PackedScene).instantiate()
	sc.set("setup", setup)
	root.add_child(sc)
	var r: Variant = null
	while Time.get_ticks_msec() - t0 < 600000:
		await process_frame
		if cli.has("no-hud"):
			# diagnosis: without the HUD (its canvas shaders are drawn first when the loading cover goes – UI, both modes)
			for c: Node in sc.get_children():
				if c is CanvasLayer and (c as CanvasLayer).layer == 5:
					(c as CanvasLayer).visible = false
		r = sc.get("renderer")
		if r != null and r is ModernRenderer and (r as ModernRenderer).is_prepared():
			break
	if not (r is ModernRenderer) or not (r as ModernRenderer).healthy():
		print("RENDER-CHECK warmup_kalt FEHLER  die Etappe läuft nicht in Modern (%s)" % (str((r as ModernRenderer).fail_reason()) if r is ModernRenderer else "kein Modern-Renderer"))
		quit(1)
		return
	var mr: ModernRenderer = r
	var live_ms := Time.get_ticks_msec()
	# the Mesa shader cache holds one file per compiled shader variant: a file that appears during the drive is a
	# program that was compiled then (the cache writer is asynchronous – what appears in the first second still
	# belongs to the warm-up frames)
	var cache_dir := OS.get_environment("MESA_SHADER_CACHE_DIR")
	var known := {}
	if cache_dir != "":
		for f: String in _cache_files(cache_dir):
			known[f] = true
	var first_seen := {}
	while Time.get_ticks_msec() - live_ms < int((seconds + 1.0) * 1000.0):
		await process_frame
		if cache_dir != "":
			for f: String in _cache_files(cache_dir):
				if not known.has(f) and not first_seen.has(f):
					first_seen[f] = float(Time.get_ticks_msec() - live_ms) / 1000.0
	if cache_dir != "":
		await create_timer(1.5).timeout
		for f: String in _cache_files(cache_dir):
			if not known.has(f) and not first_seen.has(f):
				first_seen[f] = seconds + 1.0
	var compiled: Array[String] = []
	for f: String in first_seen:
		if float(first_seen[f]) > 1.0:
			compiled.append("%.1f s" % float(first_seen[f]))
	compiled.sort()
	var st: Dictionary = mr.perf_stats()
	var probe: Object = mr.get("_probe")
	var frames: PackedFloat32Array = probe.call("start_frames_ms")
	var sorted := frames.duplicate()
	sorted.sort()
	var median := float(sorted[sorted.size() / 2]) if not sorted.is_empty() else 0.0
	var worst := float(sorted[sorted.size() - 1]) if not sorted.is_empty() else 0.0
	var over: Array[String] = []
	var t := 0.0
	for i in frames.size():
		t += frames[i] / 1000.0
		if frames[i] > FACTOR * median:
			over.append("Bild %d bei %.1f s: %.0f ms" % [i, t, frames[i]])
	var top: Array[String] = []
	for i in mini(5, sorted.size()):
		top.append("%.0f" % sorted[sorted.size() - 1 - i])
	var ok := not frames.is_empty() and over.is_empty() and compiled.is_empty()
	var cache_note := "Shader-Cache nicht beobachtet (MESA_SHADER_CACHE_DIR fehlt)"
	if cache_dir != "":
		cache_note = "%d Shader-Varianten im Cache vor dem Start, während der Fahrt %d neu übersetzt%s" % [known.size(), compiled.size(),
			"" if compiled.is_empty() else " (bei " + ", ".join(compiled.slice(0, 12)) + ")"]
	print("RENDER-CHECK warmup_kalt %s  %s km %s %s Uhr, %s%s: %s; %d Bilder in den ersten %.0f s nach dem Ladebild, Median %.1f ms, längstes %.0f ms (Grenze %.0f ms), die fünf längsten %s ms; Vorbereitung %.0f ms (Selbsttest %.0f ms, Aufwärmen %.0f ms, %d Aufwärm-Knoten)%s" % [
		"OK    " if ok else "FEHLER", str(setup["stage_id"]), str(setup["start_km"]), str(hour), str(cli.get("gfx-preset", "")),
		" ohne Aufwärmen" if cli.has("no-prewarm") else "", cache_note, frames.size(), seconds, median, worst, FACTOR * median, ", ".join(top),
		float(st.get("prepare_ms", 0.0)), float(st.get("selftest_ms", 0.0)), float(st.get("prewarm_ms", 0.0)), int(st.get("warmup_nodes", 0)),
		"" if over.is_empty() else "  –  Bilder über der Grenze: " + "; ".join(over.slice(0, 12))])
	sc.queue_free()
	await process_frame
	ModernMaterials.drop_shared()
	quit(0 if ok else 1)


## Every file below `dir` (relative paths).
func _cache_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	_collect(dir, "", out)
	return out


func _collect(base: String, rel: String, out: Array[String]) -> void:
	var d := DirAccess.open(base.path_join(rel))
	if d == null:
		return
	for f in d.get_files():
		out.append(rel.path_join(f))
	for sub in d.get_directories():
		_collect(base, rel.path_join(sub), out)
