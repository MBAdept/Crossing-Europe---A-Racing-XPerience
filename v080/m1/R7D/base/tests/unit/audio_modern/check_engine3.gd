extends SceneTree
## The engine v3 of the sound profile "Modern" in a running game with playback (v0.8.0, contract §6 AU-B – thread
## bench and shutdown):
##   godot --headless --path . -s res://tests/unit/audio_modern/check_engine3.gd -- --graphics=arcade [--only=a,b]
## Started by tests/unit/audio_modern/test_engine3_checks.gd (so tools/run_tests.sh covers it). Headless the Dummy
## audio driver mixes as usual; ModernAudio.force_live builds the players.
##
##   thread     the engine mixer in its worker thread: a full-throttle run of the Gran Turismo with six main-thread
##              hitches of 400 ms – the generator never runs empty (0 underruns), the engine keeps playing through
##              every hitch, the worker really is a thread; render time per 1/60 s of sound is reported
##   sync       the same drive mixed on the main thread (audio.modern.engine_thread = false, as --audio-sync): it
##              plays, and the hitches empty the generator – the bench does tell the two apart
##   switch     10 × arcade ↔ modern with the engine thread and a preview running: every worker is joined, no stream
##              is left held, no node or bus stays behind
##   quit       the game quits while the engine thread is feeding the generator (no profile switch, no stop_all):
##              the process ends cleanly – this scenario always runs last
## Prints "CHECK <name> OK|FEHLER …" per scenario; exit code 0 when all pass. The AudioManager is accessed untyped
## (this script compiles before the autoloads exist).

const SCENARIOS: Array[String] = ["thread", "sync", "switch", "quit"]
const HITCH_MS := 400
const HITCHES := 6
const CAR := "gran_turismo"

var _am: Node
var _failed: Array[String] = []
var _wall0 := 0


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _wall0 > 100000:
		print("CHECK zeitlimit       FEHLER  nach 100 s abgebrochen")
		quit(2)
		return true
	return false


func _check(check_name: String, ok: bool, msg: String) -> void:
	print("CHECK %-8s %s  %s" % [check_name, "OK    " if ok else "FEHLER", msg])
	if not ok:
		_failed.append(check_name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _modern() -> Node:
	var m: Variant = _am.get("_modern")
	return m if m is Node else null


func _engine_dbg() -> Dictionary:
	var m := _modern()
	return ((m.call("debug_state") as Dictionary)["slots"] as Dictionary)["engine"] if m != null else {}


func _run() -> void:
	await _frames(3)
	_am = root.get_node_or_null("AudioManager")
	if _am == null:
		print("CHECK aufbau   FEHLER  AudioManager fehlt")
		quit(1)
		return
	ModernAudio.force_live = true
	Engine.max_fps = 60
	var only := CliArgs.get_string("only", "")
	for s in SCENARIOS:
		if only != "" and not only.split(",").has(s):
			continue
		await call("_scenario_" + s)
	print("CHECKS %s  (%d fehlgeschlagen, %.0f s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(),
		(Time.get_ticks_msec() - _wall0) / 1000.0])
	quit(0 if _failed.is_empty() else 1)


## Full throttle from a standstill for `seconds` with HITCHES main-thread hitches; returns what happened.
func _hitch_drive(seconds: float) -> Dictionary:
	var cfg := ConfigLoader.load_merged()
	var spec := VehicleModel.resolve_spec(cfg, CAR)
	var vmax := float(spec["vmax_kmh"])
	_am.call("set_vehicle", CAR)
	var t0 := Time.get_ticks_msec()
	var last := t0
	var v := 0.0
	var hitches := 0
	var next_hitch := 1.2
	var playing_always := true
	var silent_frames := 0
	var frames := 0
	var longest := 0.0
	while float(Time.get_ticks_msec() - t0) / 1000.0 < seconds:
		var now := Time.get_ticks_msec()
		var dt := float(now - last) / 1000.0
		last = now
		longest = maxf(longest, dt)
		v = VehicleModel.curve_speed(VehicleModel.curve_time(v, vmax, float(spec["accel_a0"]), float(spec["accel_q"])) + dt, vmax,
			float(spec["accel_a0"]), float(spec["accel_q"]))
		_am.call("set_engine", v, 1.0, vmax, true)
		await process_frame
		frames += 1
		var t := float(Time.get_ticks_msec() - t0) / 1000.0
		if CliArgs.has("trace") and frames < 90:
			var pf: Dictionary = _am.call("engine_perf")
			print("  Bild %d t=%.3f dt=%.3f Aussetzer %d Füllungen %d Abtastwerte %d" % [frames, t, dt, int(pf["skips"]), int(pf["frames"]), int(pf["samples"])])
		if t > 1.0:
			var dbg := _engine_dbg()
			if not bool(dbg.get("playing", false)):
				playing_always = false
			var unit: Variant = (_modern().get("engine") as Object).get("_unit")
			if unit != null and (unit.get("mix") as Object).call("is_silent"):
				silent_frames += 1
		if hitches < HITCHES and t >= next_hitch:
			hitches += 1
			next_hitch += (seconds - 1.6) / float(HITCHES)
			var sk0 := int((_am.call("engine_perf") as Dictionary)["skips"])
			OS.delay_msec(HITCH_MS)      # the main thread stands still: no frame, no call of the session
			if CliArgs.has("trace"):
				print("  Hänger %d bei %.2f s: Aussetzer davor %d, danach %d" % [hitches, t, sk0, int((_am.call("engine_perf") as Dictionary)["skips"])])
	var perf: Dictionary = _am.call("engine_perf")
	return {"perf": perf, "hitches": hitches, "playing": playing_always, "silent_frames": silent_frames, "frames": frames,
		"longest_frame_s": longest, "rpm": float((_am.call("engine_state") as Dictionary)["rpm"]), "threaded": bool(_engine_dbg().get("threaded", false))}


func _scenario_thread() -> void:
	_am.call("set_profile", "modern")
	await _frames(2)
	var r: Dictionary = await _hitch_drive(7.5)
	var perf: Dictionary = r["perf"]
	var ok := int(r["hitches"]) == HITCHES and bool(r["threaded"]) and bool(perf.get("threaded", false)) and int(perf["skips"]) == 0 \
		and int(perf["frames"]) > 50 and bool(r["playing"]) and int(r["silent_frames"]) == 0 and float(r["longest_frame_s"]) >= 0.35
	_check("thread", ok, "Gran Turismo, Vollgas %.1f s mit %d Hängern des Hauptthreads à %d ms (längstes Bild %.2f s): Mischer im eigenen Thread %s, %d Aussetzer des Generators, Motor spielt durchgehend %s (ausgeblendet in %d Bildern); %d Füllungen, %.2f ms je Füllung (höchstens %.1f), %.3f ms Mischzeit je 1/60 s Klang; Drehzahl am Ende %.0f/min" % [
		7.5, int(r["hitches"]), HITCH_MS, float(r["longest_frame_s"]), str(r["threaded"]), int(perf["skips"]), str(r["playing"]),
		int(r["silent_frames"]), int(perf["frames"]), float(perf["avg_ms"]), float(perf["max_ms"]), float(perf.get("ms_per_frame", 0.0)), float(r["rpm"])])
	_am.call("stop_all")
	_am.call("set_profile", "arcade")
	await _frames(3)


func _scenario_sync() -> void:
	var modern_cfg: Dictionary = (_am.get("_audio_cfg") as Dictionary)["audio"]["modern"]
	var before := bool(modern_cfg.get("engine_thread", true))
	modern_cfg["engine_thread"] = false
	_am.call("set_profile", "modern")
	await _frames(2)
	var sync_ctx := bool((_modern().get("ctx") as Object).get("sync"))
	var r: Dictionary = await _hitch_drive(7.5)
	var perf: Dictionary = r["perf"]
	var ok := sync_ctx and not bool(r["threaded"]) and not bool(perf.get("threaded", true)) and int(perf["frames"]) > 50 \
		and int(perf["skips"]) >= 1 and int(perf["samples"]) > 100000
	_check("sync", ok, "dieselbe Fahrt, im Hauptthread gemischt (engine_thread = false): Mischer-Thread %s, %d Aussetzer des Generators bei %d Hängern (mit Thread: 0), %d Füllungen, %.2f ms je Füllung, %.3f ms Mischzeit je 1/60 s Klang" % [
		str(r["threaded"]), int(perf["skips"]), int(r["hitches"]), int(perf["frames"]), float(perf["avg_ms"]), float(perf.get("ms_per_frame", 0.0))])
	_am.call("stop_all")
	_am.call("set_profile", "arcade")
	modern_cfg["engine_thread"] = before
	await _frames(3)


func _scenario_switch() -> void:
	_am.call("set_profile", "arcade")
	await _frames(3)
	var t0 := Time.get_ticks_msec()
	while ModernAudioContext.kept_count() > 0 and Time.get_ticks_msec() - t0 < 4000:
		await process_frame
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var buses := AudioServer.bus_count
	var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var threaded_seen := 0
	for i in 10:
		_am.call("set_profile", "modern")
		_am.call("set_vehicle", ["kompakt", "kombi", "limousine", "sportwagen", "gran_turismo"][i % 5])
		_am.call("preview_engine", ["sportwagen", "gran_turismo"][i % 2])
		for k in 8:
			_am.call("set_engine", 120.0 + 10.0 * i, 1.0, 250.0, true)
			await process_frame
		if bool(_engine_dbg().get("threaded", false)):
			threaded_seen += 1
		if i % 2 == 0:
			_am.call("stop_all")
		_am.call("set_profile", "arcade")      # the worker is feeding the generator at this moment
		await process_frame
	t0 = Time.get_ticks_msec()
	while ModernAudioContext.kept_count() > 0 and Time.get_ticks_msec() - t0 < 4000:
		await process_frame
	await _frames(2)
	var nodes_after := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var objects_after := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var ok := threaded_seen == 10 and nodes_after == nodes and AudioServer.bus_count == buses and ModernAudioContext.kept_count() == 0 \
		and objects_after <= objects + 8
	_check("switch", ok, "10 × arcade ↔ modern mit laufendem Mischer-Thread (%d ×) und Vorschau: Knoten %d → %d, Busse %d → %d, gehaltene Streams danach %d, Objekte %d → %d" % [
		threaded_seen, nodes, nodes_after, buses, AudioServer.bus_count, ModernAudioContext.kept_count(), objects, objects_after])


func _scenario_quit() -> void:
	_am.call("set_profile", "modern")
	_am.call("set_vehicle", CAR)
	for i in 40:
		_am.call("set_engine", 140.0, 1.0, 270.0, true)
		await process_frame
	var dbg := _engine_dbg()
	var perf: Dictionary = _am.call("engine_perf")
	var ok := bool(dbg.get("threaded", false)) and bool(dbg.get("playing", false)) and int(perf["frames"]) > 0
	_check("quit", ok, "Spielende bei laufendem Mischer-Thread (%d Füllungen, spielt %s): der Prozess endet jetzt ohne Profilwechsel" % [
		int(perf["frames"]), str(dbg.get("playing", false))])
	# no set_profile("arcade"), no stop_all: quitting frees the tree, ModernAudio._exit_tree() stops the worker
