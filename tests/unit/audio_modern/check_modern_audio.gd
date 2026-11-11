extends SceneTree
## The two sound profiles in the running game (v0.8.0, contract §6 AU-A – acceptance):
##   godot --headless --path . -s res://tests/unit/audio_modern/check_modern_audio.gd -- --graphics=arcade [--live] [--only=a,b]
## Started twice by tests/unit/audio_modern/test_modern_checks.gd (so tools/run_tests.sh covers it); also runs under
## Xvfb with --audio-driver Dummy (then the AudioManager builds every Arcade bus by itself and both profiles play:
## what the scenarios expect of the playback follows the display, not the flag --live). On a display the race
## scenario takes its time scale from the measured frame time – software OpenGL draws a frame of the stage in
## 50–150 ms, and a frame must span well under ModernAudio.ALIVE_S of game time or the sound counts the session as
## gone. With --fixed-fps 60 a display run reaches the time scale 8 of the headless run.
##
##   arcade_boot    the game starts with the Arcade profile; its bus list and every effect parameter equal the
##                  fingerprint written from tag v0.7.0 (golden/arcade_v070_headless.json, with players
##                  arcade_v070_display.json)
##   new_api        the calls of contract §4.7.1 do nothing with the Arcade profile (buses, nodes, state unchanged)
##   modern_buses   set_profile("modern") adds the 22 Modern buses behind the Arcade ones and changes none of them
##   switch_20      20 × arcade ↔ modern with sound running: afterwards the same number of nodes, buses and
##                  children of the AudioManager, no orphan nodes, the Arcade buses as in v0.7.0; the generator
##                  streams held over their players (ModernAudioContext.keep_alive) are released a good 2 s later
##                  although the profile is Arcade again – then the plain object count is the one from before
##   delegation     with the Modern profile the existing API reaches ModernAudio and the Arcade sound does not run;
##                  back in Arcade the old engine works again; the menu music is handed over both ways
##   mix            (--live) a tone through the Modern buses, captured: the level chain of the plan, the music ducks
##                  while the car is driven flat out and comes back, the pause low-pass closes and opens, the race
##                  EQ of the music takes about 1 / 3 / 0 dB at 62 Hz / 500 Hz / 5 kHz
##   race           16 s of the test stage through its tunnel with the Modern profile and the placeholder sounds:
##                  the session's calls arrive (engine, traffic, tunnel reverb, feed, events, race music); without
##                  --live also the finish with Modern and the same 16 s with the Arcade profile – the same
##                  simulation at every second (Rule 3)
##   arcade_after   after all that: Arcade profile, the Arcade bus list as in v0.7.0, and the cycle bank both
##                  profiles played from still gives the seeded mixer output of v0.7.0 (SHA-256)
## --live: plays although the run is headless – builds the Arcade sounds as on a display (the AudioManager's own
## functions), ModernAudio.force_live, and switches the placeholders on for every scenario
## (audio.modern.placeholders; without --live only the race uses them).
## Prints "CHECK <name> OK|FEHLER …" per scenario; exit code 0 when all pass. The scene is accessed untyped (this
## script compiles before the autoloads exist).

const SCENARIOS: Array[String] = ["arcade_boot", "new_api", "modern_buses", "switch_20", "delegation", "mix", "race", "arcade_after"]
const GOLDEN_DIR := "res://tests/unit/audio_modern/golden"
const TOOL := "res://tests/unit/audio_modern/golden/arcade_golden.gd"
const RACE_SCENE := "res://scenes/race/race.tscn"

var _am: Node
var _tool: GDScript
var _golden: Array = []
var _golden_engine: Dictionary = {}   ## car -> {samples, sha256, …} of the seeded Arcade mixer output in v0.7.0
var _live := false       ## --live: playback forced in a headless run, placeholders in every scenario
var _plays := false      ## players exist and sound plays: --live or a display
var _failed: Array[String] = []
var _wall0 := 0
var _sc: Node = null
var _inject := false
var _frame_delta := 0.0  ## process time of the last frame (s, scaled by Engine.time_scale)
var _adaptive := false   ## race scenario on a display: the time scale follows the measured frame time (_drive)
var _race_ts := 8.0      ## time scale the race scenario ran with (the last one chosen)


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(delta: float) -> bool:
	_frame_delta = delta
	if Time.get_ticks_msec() - _wall0 > 170000:
		print("CHECK zeitlimit       FEHLER  nach 170 s abgebrochen")
		quit(2)
		return true
	return false


# --- helpers --------------------------------------------------------------------------------------

func _check(check_name: String, ok: bool, msg: String) -> void:
	print("CHECK %-14s %s  %s" % [check_name, "OK    " if ok else "FEHLER", msg])
	if not ok:
		_failed.append(check_name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _modern() -> Node:
	var m: Variant = _am.get("_modern")
	return m if m is Node else null


func _layout() -> Array:
	return _tool.call("bus_layout")


## Differences of the Arcade buses to the v0.7.0 fingerprint (Modern buses left out).
func _arcade_diff() -> Array[String]:
	return _tool.call("layout_diff", _golden, _layout(), ModernBuses.names())


func _counts() -> Dictionary:
	return {"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"buses": AudioServer.bus_count, "children": _am.get_child_count()}


func _bus_names() -> Array[String]:
	var out: Array[String] = []
	for i in AudioServer.bus_count:
		out.append(AudioServer.get_bus_name(i))
	return out


# --- the run --------------------------------------------------------------------------------------

func _run() -> void:
	await _frames(3)
	_am = root.get_node_or_null("AudioManager")
	_tool = load(TOOL)
	_live = CliArgs.has("live")
	if _am == null or _tool == null:
		print("CHECK aufbau         FEHLER  AudioManager oder Werkzeug fehlt")
		quit(1)
		return
	var headless := DisplayServer.get_name() == "headless"
	_plays = _live or not headless
	if _live:
		ModernAudio.force_live = true
		var cfg: Dictionary = _am.get("_audio_cfg")
		(cfg["audio"]["modern"] as Dictionary)["placeholders"] = true
		if headless and not bool(_am.get("sounds_ready")):
			# what AudioManager._ready() does on a display
			_am.call("set_profile", "arcade")
			_am.call("_load_traffic_sounds", cfg)
			_am.call("_build_sounds")
			_am.call("_load_music", str(ConfigLoader.lookup(cfg, "audio.music_file", "")))
			await _frames(2)
	var golden_file := "arcade_v070_headless.json" if (headless and not _live) else "arcade_v070_display.json"
	var g: Variant = ConfigLoader.load_json(GOLDEN_DIR.path_join(golden_file))
	_golden = (g as Dictionary).get("buses", []) if g is Dictionary else []
	_golden_engine = (g as Dictionary).get("engine", {}) if g is Dictionary else {}
	var only := CliArgs.get_string("only", "")
	for s in SCENARIOS:
		if only != "" and not only.split(",").has(s):
			continue
		if s == "mix" and not _live:
			continue
		await call("_scenario_" + s, golden_file)
	# leave nothing behind
	if _sc != null and is_instance_valid(_sc):
		_sc.queue_free()
	_am.call("set_music", false)
	_am.call("stop_all")
	_am.call("set_profile", "arcade")
	await _wait(0.3)
	print("CHECKS %s  (%d fehlgeschlagen, %.0f s%s)" % ["OK" if _failed.is_empty() else "FEHLER", _failed.size(),
		(Time.get_ticks_msec() - _wall0) / 1000.0, ", mit Wiedergabe" if _live else ""])
	quit(0 if _failed.is_empty() else 1)


func _scenario_arcade_boot(golden_file: String) -> void:
	# the profile the game starts with: --sound= > audio.profile > arcade
	var want := "arcade"
	for v: String in [CliArgs.get_string("sound", ""), str(ConfigLoader.lookup(ConfigLoader.load_merged(), "audio.profile", ""))]:
		if v == "arcade" or v == "modern":
			want = v
			break
	var booted := str(_am.call("profile"))
	_am.call("set_profile", "arcade")
	await _frames(2)
	var diff := _arcade_diff()
	var ok := booted == want and str(_am.call("profile")) == "arcade" and _modern() == null and not _golden.is_empty() \
		and diff.is_empty() and _layout().size() == _golden.size()
	_check("arcade_boot", ok, "Start mit Profil %s (erwartet %s); %d Busse %s wie in v0.7.0 (%s)%s" % [booted, want,
		AudioServer.bus_count, "mit allen Effektwerten" if diff.is_empty() else "NICHT", golden_file,
		"" if diff.is_empty() else " – " + "; ".join(diff.slice(0, 4))])


func _scenario_new_api(_g: String) -> void:
	var before := _counts()
	var layout := JSON.stringify(_layout())
	var engine_t: float = _am.get("_engine_t")
	_am.call("set_race_music", false)
	_am.call("set_music_context", "race", {"stage": "x"})
	_am.call("set_track", RefCounted.new(), null)
	_am.call("set_vehicle_state", {"z": 100.0, "x": 0.0, "speed": 120.0})
	for e: String in ["stage_start", "countdown", "go", "collision", "rail_hit", "radar_flash", "chase_start", "escaped",
			"busted", "refuel_start", "refuel_done", "out_of_fuel", "tow", "stage_finish"]:
		_am.call("event", e, {"n": 1})
	_am.call("set_track", null, null)
	await _frames(2)
	var ok := str(_am.call("profile")) == "arcade" and _modern() == null and _counts() == before \
		and JSON.stringify(_layout()) == layout and float(_am.get("_engine_t")) == engine_t \
		and str(_am.get("_music_ctx")) == "race" and not bool(_am.get("_race_music"))
	_am.call("set_race_music", true)
	_am.call("set_music_context", "menu")
	_check("new_api", ok, "set_race_music, set_music_context, set_track, set_vehicle_state und 14 Ereignisse mit dem Profil Arcade: nichts ändert sich (Knoten %s, Busse %d), Kontext und Schalter gemerkt" % [str(_counts()["nodes"]), AudioServer.bus_count])


func _scenario_modern_buses(_g: String) -> void:
	var names_before := _bus_names()
	_am.call("set_profile", "modern")
	await _frames(2)
	var m := _modern()
	var names := _bus_names()
	var modern_names := ModernBuses.names()
	var tail_ok := names.size() == names_before.size() + modern_names.size()
	for i in names_before.size():
		tail_ok = tail_ok and i < names.size() and names[i] == names_before[i]
	for i in modern_names.size():
		tail_ok = tail_ok and names_before.size() + i < names.size() and names[names_before.size() + i] == modern_names[i]
	var problems: Array = (m.call("debug_state") as Dictionary).get("bus_problems", ["?"]) if m != null else ["kein ModernAudio"]
	var diff := _arcade_diff()
	var ok := str(_am.call("profile")) == "modern" and m != null and tail_ok and problems.is_empty() and diff.is_empty()
	_am.call("set_profile", "modern")   # idempotent
	ok = ok and _modern() == m and AudioServer.bus_count == names.size()
	_check("modern_buses", ok, "%d Modern-Busse hinter den %d vorhandenen, Sends nach links (%s); Arcade-Busse dabei unverändert%s; zweites set_profile(\"modern\") ohne Wirkung" % [
		modern_names.size(), names_before.size(), "in Ordnung" if problems.is_empty() else str(problems),
		"" if diff.is_empty() else " NICHT: " + "; ".join(diff.slice(0, 3))])
	_am.call("set_profile", "arcade")
	await _frames(2)


func _scenario_switch_20(_g: String) -> void:
	_am.call("set_profile", "arcade")
	_am.call("stop_all")
	await _wait(0.25)
	var before := _counts()
	# generator streams are held for two seconds after their player went (ModernAudioContext.keep_alive): streams of
	# the scenarios before this one must be gone before the objects are counted
	await _until_released()
	var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var max_children := 0
	for i in 20:
		_am.call("set_profile", "modern")
		_am.call("set_vehicle", ["limousine", "kompakt", "gran_turismo", "kombi", "sportwagen"][i % 5])
		_am.call("set_music", i % 2 == 0)
		_am.call("set_music_context", "race" if i % 3 == 0 else "menu")
		for k in 3:
			_am.call("set_engine", 90.0 + 5.0 * i, 1.0, 240.0, true)
			_am.call("set_wind", 150.0)
			_am.call("set_rain", 1.0)
			_am.call("set_siren", true, 0.6)
			_am.call("set_traffic", [{"id": 1, "set": "traffic/sedan_blue", "z": 12.0, "x": 3.75, "length": 4.7, "speed": 100.0},
				{"id": -2, "set": "police/de", "z": -30.0, "x": 0.0, "length": 4.8, "speed": 160.0}], {"z": 0.0, "x": 0.0, "speed": 120.0})
			_am.call("set_environment", {"tunnel": k % 2 == 0})
			if k == 1:
				_am.call("play", "crash")
				_am.call("play", "ui_move")
				_am.call("preview_engine", "sportwagen")
			await process_frame
		max_children = maxi(max_children, _modern().get_child_count())
		_am.call("set_profile", "arcade")
		await _frames(2)
	_am.call("set_music", false)
	_am.call("stop_all")
	await _wait(0.25)
	var after := _counts()
	# the profile is Arcade again and no ModernAudio exists: the held generator streams must still be released
	var kept_at_end := ModernAudioContext.kept_count()
	var waited := await _until_released()
	var kept := ModernAudioContext.kept_count()
	var objects_after := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var diff := _arcade_diff()
	var ok := after == before and diff.is_empty() and kept == 0 and objects_after <= objects + 8 and (max_children > 0) == _plays \
		and (kept_at_end > 0) == _plays
	_check("switch_20", ok, "20 × arcade ↔ modern (%s): Knoten %d → %d, Busse %d → %d, Kinder des AudioManagers %d → %d, verwaiste Knoten %d → %d; %d gehaltene Generator-Streams %.1f s nach dem letzten Wechsel freigegeben (Profil Arcade, noch gehalten: %d), Objekte danach %d → %d; Arcade-Busse wie in v0.7.0%s" % [
		"mit bis zu %d Playern" % max_children if _plays else "ohne Wiedergabe", before["nodes"], after["nodes"], before["buses"],
		after["buses"], before["children"], after["children"], before["orphans"], after["orphans"], kept_at_end, waited, kept,
		objects, objects_after, "" if diff.is_empty() else " NICHT: " + "; ".join(diff.slice(0, 3))])


## Waits until no generator stream is held any more (at most 4 s – they are held for 2 s); returns the seconds waited.
func _until_released() -> float:
	var t0 := Time.get_ticks_msec()
	while ModernAudioContext.kept_count() > 0 and Time.get_ticks_msec() - t0 < 4000:
		await process_frame
	return float(Time.get_ticks_msec() - t0) / 1000.0


func _scenario_delegation(_g: String) -> void:
	# Arcade first: its own engine
	_am.call("set_profile", "arcade")
	_am.call("set_music_context", "menu")
	_am.call("set_music", true)
	_am.call("set_vehicle", "limousine")
	for i in 30:
		_am.call("set_engine", 160.0, 1.0, 245.0, true)
		await process_frame
	var arcade_rpm := float((_am.call("engine_state") as Dictionary)["rpm"])
	var arcade_music := bool(_am.get("_music_wanted"))
	# Modern: the same calls go to ModernAudio, the Arcade sound stands still
	_am.call("set_profile", "modern")
	var m := _modern()
	var handed := str((m.get("music") as Object).get("context")) == "menu" and not bool(_am.get("_music_wanted"))
	var arcade_t: float = _am.get("_engine_t")
	var arcade_eng: Variant = _am.get("_eng")
	_am.call("set_vehicle", "gran_turismo")
	for i in 40:
		_am.call("set_engine", 180.0, 1.0, 270.0, true)
		_am.call("set_wind", 180.0)
		_am.call("set_skid", 0.8)
		_am.call("set_rain", 1.0)
		_am.call("set_siren", true, 0.9)
		_am.call("set_traffic", [{"id": 7, "set": "traffic/truck_red", "z": 15.0, "x": 3.75, "length": 16.5, "speed": 88.0, "heavy": true}], {"z": 0.0, "x": 0.0, "speed": 180.0})
		_am.call("set_environment", {"tunnel": true})
		_am.call("hud_hints", {"weather": "rain", "understeer": 0.5, "police_state": "chase", "police_gap_m": 60.0})
		if i == 5:
			_am.call("play", "crash")
			_am.call("play", "ui_ok")
			_am.call("event", "collision", {"speed_kmh": 100.0, "heavy": true, "side": 1})
		await process_frame
	var st: Dictionary = m.call("debug_state")
	var slots: Dictionary = st["slots"]
	var modern_rpm := float((_am.call("engine_state") as Dictionary)["rpm"])
	var traffic: Dictionary = _am.call("traffic_state")
	var reached := bool(st["alive"]) and modern_rpm > 1000.0 and str(slots["engine"]["vehicle"]) == "gran_turismo" \
		and float(slots["road"]["wind"]) > 0.05 and float(slots["road"]["skid"]) > 0.05 and float(slots["ambience"]["rain"]) > 0.05 \
		and float(st["siren"]) > 0.5 and bool(st["tunnel"]) and float(slots["env"]["blend"]) > 0.0 \
		and int((st["plays"] as Dictionary).get("crash", 0)) == 1 and int((st["plays"] as Dictionary).get("ui_ok", 0)) == 1 \
		and int((st["events"] as Dictionary).get("collision", 0)) == 1 and traffic.has("tunnel_blend") \
		and (_am.call("engine_perf") as Dictionary).has("skips") and (_am.call("traffic_perf") as Dictionary).has("avg_ms")
	var live_ok := true
	if _plays:
		live_ok = bool(slots["engine"]["playing"]) and int(slots["traffic"]["voices"]) == 1 and bool(slots["traffic"]["ok"]) \
			and int((_am.call("engine_perf") as Dictionary)["frames"]) > 0
	# the Arcade side saw none of it: its engine time stamp and engine object are those from before, nothing plays
	var arcade_idle := float(_am.get("_engine_t")) == arcade_t and is_same(_am.get("_eng"), arcade_eng) \
		and str(_am.get("_vehicle_id")) == "limousine"
	for c in _am.get_children():
		if c is AudioStreamPlayer and (c as AudioStreamPlayer).playing:
			arcade_idle = false
	# a context change in Modern, then back: Arcade gets its menu music and its engine back
	_am.call("set_music_context", "race")
	_am.call("stop_all")
	_am.call("set_profile", "arcade")
	var race_handover := not bool(_am.get("_music_wanted"))   # "race" is not menu music
	_am.call("set_music", true)
	_am.call("set_vehicle", "limousine")
	for i in 30:
		_am.call("set_engine", 160.0, 1.0, 245.0, true)
		await process_frame
	var arcade_rpm2 := float((_am.call("engine_state") as Dictionary)["rpm"])
	_am.call("set_profile", "modern")
	var back_to_menu := str((_modern().get("music") as Object).get("context")) == "menu"
	_am.call("set_profile", "arcade")
	_am.call("set_music", false)
	_am.call("stop_all")
	await _frames(3)
	var ok := arcade_rpm > 1000.0 and arcade_music and handed and reached and live_ok and arcade_idle and race_handover \
		and arcade_rpm2 > 1000.0 and back_to_menu
	_check("delegation", ok, "Arcade-Motor %.0f/min; Modern: Aufrufe kommen an (Motor %.0f/min, Wind, Quietschen, Regen, Horn, Tunnel, Einmalklänge, Ereignis)%s, Arcade steht dabei still (%s); Menümusik übergeben (%s/%s/%s); zurück in Arcade läuft der alte Motor (%.0f/min)" % [
		arcade_rpm, modern_rpm, " – hörbar: Motor spielt, 1 Verkehrsstimme" if (_plays and live_ok) else ("" if not _plays else " – Wiedergabe FEHLT"),
		str(arcade_idle), str(handed), str(race_handover), str(back_to_menu), arcade_rpm2])


# --- mix (with playback only) -----------------------------------------------------------------------

func _tone(hz: float, seconds: float, peak: float) -> AudioStreamWAV:
	var rate := 44100
	var n := int(seconds * rate)
	var b := PackedByteArray()
	b.resize(n * 2)
	for i in n:
		b.encode_s16(i * 2, int(sin(TAU * hz * i / rate) * peak * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = b
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	return w


func _player(bus: String, stream: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	root.add_child(p)
	p.play()
	return p


## RMS level in dB of what a capture effect collected during `seconds`.
func _level(cap: AudioEffectCapture, seconds: float) -> float:
	cap.clear_buffer()
	await _wait(seconds)
	var fr := cap.get_buffer(cap.get_frames_available())
	if fr.is_empty():
		return -200.0
	var s := 0.0
	for v in fr:
		s += v.x * v.x + v.y * v.y
	return 10.0 * log(maxf(s / (2.0 * fr.size()), 1.0e-20)) / log(10.0)


func _scenario_mix(_g: String) -> void:
	_am.call("set_profile", "modern")
	_am.call("set_music", false)
	_am.call("stop_all")
	Engine.max_fps = 60
	await _wait(0.5)
	var m := _modern()
	var master_cap := AudioEffectCapture.new()
	master_cap.buffer_length = 1.0
	AudioServer.add_bus_effect(0, master_cap)
	var music_cap := AudioEffectCapture.new()
	music_cap.buffer_length = 1.0
	var mi := AudioServer.get_bus_index("MMusic")
	AudioServer.add_bus_effect(mi, music_cap)
	var buses: ModernBuses = m.get("buses")
	# 1. the level chain: a -20 dBFS sine (RMS -23) on MUI and on MMusic arrives at Master with the plan's gains
	var tone := _tone(1000.0, 0.5, 0.1)
	var p := _player("MUI", tone)
	var ui_db: float = await _level(master_cap, 0.35)
	p.bus = "MMusic"
	await _wait(0.1)
	var music_db: float = await _level(master_cap, 0.35)
	# (captured on Master as an effect, i.e. before the volume of Master itself)
	var want_ui := -23.01 + buses.path_db("MUI")
	var want_music := -23.01 + buses.path_db("MMusic")
	var chain_ok := absf(ui_db - want_ui) < 0.4 and absf(music_db - want_music) < 0.4
	# 2. ducking: the music (still playing) while the car is driven flat out, then after the session stopped calling
	var before: float = await _level(music_cap, 0.3)
	_am.call("set_vehicle", "limousine")
	var until := Time.get_ticks_msec() + 800
	var ducked := 0.0
	while Time.get_ticks_msec() < until + 300:
		_am.call("set_engine", 200.0, 1.0, 245.0, true)
		if Time.get_ticks_msec() >= until and ducked == 0.0:
			music_cap.clear_buffer()
			ducked = -1.0
		await process_frame
	var fr := music_cap.get_buffer(music_cap.get_frames_available())
	var sq := 0.0
	for v in fr:
		sq += v.x * v.x + v.y * v.y
	ducked = 10.0 * log(maxf(sq / (2.0 * maxf(fr.size(), 1.0)), 1.0e-20)) / log(10.0)
	var duck_state := float(((m.call("debug_state") as Dictionary)["mix"] as Dictionary)["duck_db"])
	_am.call("stop_all")
	await _wait(1.8)
	var after: float = await _level(music_cap, 0.3)
	var duck_ok := before - ducked >= 3.0 and absf(after - before) < 0.5 and duck_state <= -3.0
	# 3. pause: low-pass and dip on the music bus (a 5-kHz tone nearly disappears), back after the pause
	p.stream = _tone(5000.0, 0.5, 0.1)
	p.play()
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	await _wait(0.2)
	var open: float = await _level(music_cap, 0.3)
	paused = true
	await _wait(0.6)
	var closed: float = await _level(music_cap, 0.3)
	var lp := buses.lowpass_hz("MMusic")
	paused = false
	await _wait(0.8)
	var reopened: float = await _level(music_cap, 0.3)
	var pause_ok := open - closed >= 12.0 and absf(reopened - open) < 0.6 and lp < 2000.0
	# 4. race EQ of the music: in the context "race" (no race music plays here) tones at 62 Hz / 500 Hz / 5 kHz leave
	#    the bus about 1 / 3 / 0 dB lower than outside a race; neutral again afterwards
	_am.call("set_race_music", false)
	var eq_drop: Array[float] = []
	for hz: float in [62.0, 500.0, 5000.0]:
		p.stream = _tone(hz, 0.5, 0.1)
		p.play()
		_am.call("set_music_context", "off", {})
		await _wait(0.7)
		var flat: float = await _level(music_cap, 0.3)
		_am.call("set_music_context", "race", {})
		await _wait(0.7)
		var shaped: float = await _level(music_cap, 0.3)
		eq_drop.append(flat - shaped)
	_am.call("set_music_context", "off", {})
	_am.call("set_race_music", true)
	await _wait(0.7)
	var eq_ok := absf(eq_drop[0] - 1.0) < 0.4 and absf(eq_drop[1] - 3.0) < 0.4 and absf(eq_drop[2]) < 0.3 and not buses.music_eq_on()
	p.stop()
	p.queue_free()
	for j in range(AudioServer.get_bus_effect_count(mi) - 1, -1, -1):
		if AudioServer.get_bus_effect(mi, j) == music_cap:
			AudioServer.remove_bus_effect(mi, j)
	for j in range(AudioServer.get_bus_effect_count(0) - 1, -1, -1):
		if AudioServer.get_bus_effect(0, j) == master_cap:
			AudioServer.remove_bus_effect(0, j)
	Engine.max_fps = 0
	await _frames(3)
	_check("mix", chain_ok and duck_ok and pause_ok and eq_ok, "Pegelkette: Ton über MUI %.2f dB (Plan %.2f), über MMusic %.2f dB (Plan %.2f); Ducking: Musik %.2f → %.2f dB bei Vollgas (−%.1f dB, Zustand %.1f dB), danach %.2f dB; Pause: 5-kHz-Ton %.1f → %.1f dB (Tiefpass %.0f Hz), danach %.1f dB; Renn-EQ der Musik: 62 Hz −%.2f dB, 500 Hz −%.2f dB, 5 kHz −%.2f dB" % [
		ui_db, want_ui, music_db, want_music, before, ducked, before - ducked, duck_state, after, open, closed, lp, reopened,
		eq_drop[0], eq_drop[1], eq_drop[2]])
	_am.call("set_profile", "arcade")
	await _frames(2)


# --- race -----------------------------------------------------------------------------------------

func _launch(start_km: float, seed_value: int) -> void:
	var setup := {"mode": "single", "race_id": "", "stage_id": "dev_testetappe", "from_city": "", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "rain", "start_km": start_km, "autopilot": true, "no_countdown": true,
		"seed": seed_value, "traffic_warmup": true, "start_speed_kmh": 100.0, "gfx": "arcade"}
	_sc = (load(RACE_SCENE) as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)
	# a session of wave 0 (KERN) sends the sound hooks itself; before that merge this check sends them
	_inject = not ("audio_hooks" in _sc)
	if _inject:
		_am.call("set_track", _sc.get("track"), _sc.get("plan"))
		_am.call("event", "stage_start", {"countdown_s": 0.0})
		_am.call("event", "go", {})


func _sim_hash() -> int:
	var v: VehicleModel = _sc.get("vehicle")
	var fuel: FuelSystem = _sc.get("fuel")
	var traffic: TrafficSystem = _sc.get("traffic")
	var a := PackedFloat64Array([float(_sc.get("pos_z")), v.x, v.speed, fuel.fuel_l, float(_sc.get("stage_time")),
		float(_sc.get("penalty_time")), float(v.state)])
	for c in traffic.cars:
		a.append_array(PackedFloat64Array([float(c.id), c.z, c.x, c.speed, float(c.lane), 1.0 if c.braking else 0.0]))
	return hash(a.to_byte_array())


func _state_for_audio() -> Dictionary:
	var v: VehicleModel = _sc.get("vehicle")
	var track: Track = _sc.get("track")
	var z: float = _sc.get("pos_z")
	var edges := track.road_edges_at(z)
	var input: Dictionary = _sc.get("last_input")
	return {"z": z, "x": v.x, "speed": v.speed, "throttle": float(input.get("throttle", 0.0)), "brake": float(input.get("brake", 0.0)),
		"steer": float(input.get("steer", 0.0)), "understeer": v.understeer, "lat_speed": v.lat_speed, "off_road": v.off_road,
		"rail_contact": v.rail_contact, "road_left": edges.x, "road_right": edges.y, "shoulder_m": track.shoulder_w,
		"in_tunnel": track.is_tunnel_at(z - 9.0), "weather": str(_sc.get("weather")), "hour": 12.0,
		"crash": v.state == VehicleModel.State.CRASH, "finished": bool(_sc.get("finished"))}


## Drives the launched stage until game time `seconds` (or the finish); returns the per-second hashes and notes.
func _drive(seconds: float, until_finish: bool = false) -> Dictionary:
	var hashes: Array[int] = []
	var sec := -1
	var frames := 0
	var tunnel_frames := 0
	var max_rpm := 0.0
	var max_voices := 0
	var states := 0
	var total_frames := 0
	var alive_frames := 0
	var adapt_frames := 0
	var adapt_s := 0.0
	if _adaptive:
		_set_time_scale(1.0)
	var wall := Time.get_ticks_msec()
	while Time.get_ticks_msec() - wall < 60000:
		await physics_frame
		if _sc == null or not is_instance_valid(_sc):
			break
		var t: float = _sc.get("stage_time")
		if bool(_sc.get("running")) and not bool(_sc.get("finished")) and int(floor(t)) != sec:
			sec = int(floor(t))
			hashes.append(_sim_hash())
		if Engine.get_process_frames() != frames:
			frames = Engine.get_process_frames()
			if _adaptive and adapt_frames < ADAPT_SKIP_FRAMES + ADAPT_FRAMES:
				adapt_frames += 1
				if adapt_frames > ADAPT_SKIP_FRAMES:
					adapt_s += _frame_delta
				if adapt_frames == ADAPT_SKIP_FRAMES + ADAPT_FRAMES:
					_race_ts = clampf(floorf(FRAME_GAME_S_MAX / maxf(adapt_s / float(ADAPT_FRAMES), 0.001)), 1.0, 8.0)
					_set_time_scale(_race_ts)
			if _inject and bool(_sc.get("running")):
				_am.call("set_vehicle_state", _state_for_audio())
				states += 1
			max_rpm = maxf(max_rpm, float((_am.call("engine_state") as Dictionary).get("rpm", 0.0)))
			if bool(_sc.get("running")):
				total_frames += 1
				var mo := _modern()
				if mo != null and bool((mo.get("frame") as Object).get("alive")):
					alive_frames += 1
			var ts: Dictionary = _am.call("traffic_state")
			if float(ts.get("tunnel_blend", 0.0)) > 0.5:
				tunnel_frames += 1
			var n := 0
			for vo: Dictionary in ts.get("voices", []):
				n += 1 if int(vo["vehicle"]) != TrafficAudio.NONE else 0
			max_voices = maxi(max_voices, n)
		if until_finish:
			if bool(_sc.get("finished")) and float(_sc.get("vehicle").speed) < 60.0:
				break
		elif t >= seconds:
			break
	var out := {"hashes": hashes, "max_rpm": max_rpm, "tunnel_frames": tunnel_frames, "max_voices": max_voices,
		"injected_states": states, "frames": total_frames, "alive_frames": alive_frames,
		"km": float(_sc.get("pos_km")), "time": float(_sc.get("stage_time")),
		"finished": bool(_sc.get("finished")), "result": _sc.call("build_result")}
	return out


func _end_stage() -> void:
	if _inject:
		_am.call("set_track", null, null)
	_am.call("stop_all")
	if _sc != null and is_instance_valid(_sc):
		_sc.queue_free()
	_sc = null
	await _frames(3)


## Time scale of the race scenario. Headless it is 8 from the start: quick, and a frame still spans well under
## ModernAudio.ALIVE_S of game time (at 20 the session would count as gone between two frames – for the Arcade sound
## as well). On a display every drive starts in real time and takes its scale from the process time of its frames
## 5–10 (_drive): frame seconds × scale <= 0.15 s, at least 1, at most 8. With --fixed-fps 60 that is 8 (a frame is
## 1/60 s of process time however long it took to draw); software OpenGL without it draws a frame of the stage in
## 50–150 ms and gets 1 or 2. The simulation runs in fixed steps, so the scale does not change what is compared.
const ADAPT_SKIP_FRAMES := 4
const ADAPT_FRAMES := 6
const FRAME_GAME_S_MAX := 0.15


func _set_time_scale(ts: float) -> void:
	Engine.time_scale = ts
	Engine.physics_ticks_per_second = int(60.0 * ts)
	Engine.max_physics_steps_per_frame = 32


func _scenario_race(_g: String) -> void:
	_adaptive = DisplayServer.get_name() != "headless"
	_race_ts = 1.0 if _adaptive else 8.0
	_set_time_scale(_race_ts)
	# Modern with the placeholder sounds (also in the plain headless run, where the other scenarios use the shipped
	# setting without them): 16 s from km 49.4 through the Testtunnel (km 50–54), in the rain
	var modern_cfg: Dictionary = (_am.get("_audio_cfg") as Dictionary)["audio"]["modern"]
	var placeholders_before := bool(modern_cfg.get("placeholders", false))
	modern_cfg["placeholders"] = true
	_am.call("set_profile", "modern")
	_am.call("set_music_context", "race", {"stage": "dev_testetappe"})
	_launch(49.4, 5)
	var mod: Dictionary = await _drive(16.0)
	var st: Dictionary = _modern().call("debug_state")
	var events: Dictionary = st["events"]
	var feed: Dictionary = st["feed"]
	var music: Dictionary = st["slots"]["music"]
	await _end_stage()
	var modern_diff := _arcade_diff()   # the Arcade buses after a race with Modern: exactly as in v0.7.0
	var hooks := int(events.get("stage_start", 0)) >= 1 and int(events.get("go", 0)) >= 1 and bool(feed["valid"]) \
		and int(events.get("tunnel_in", 0)) == 1 and int(events.get("tunnel_out", 0)) == 1 \
		and int(mod["tunnel_frames"]) > 0 and float(mod["max_rpm"]) > 1500.0 and int(mod["alive_frames"]) > int(mod["frames"]) * 0.9 \
		and ((int(mod["max_voices"]) >= 1) == _plays) and int((st["plays"] as Dictionary).get("go", 0)) == 1
	# the race piece (since AU-D1 a real one – a placeholder never takes its turn) plays from "stage_start" on
	var music_ok := str(music["context"]) == "race" and str(music["key"]).begins_with("race/") \
		and str(music.get("race_phase", "")) == "playing" and bool(st["placeholders"])
	var text := "Teststadt – Testdorp ab km 49,4 im Regen, 16 s (Zeitraffer %d×) mit dem Profil Modern und Platzhaltern bis km %.2f: Motor bis %.0f/min, Sitzung in %d von %d Bildern da, Tunnelhall in %d Bildern, Feed gültig (Zone %s, Ereignisse %s), bis zu %d Verkehrsstimmen, Musik %s („%s“)" % [
		int(_race_ts), float(mod["km"]), float(mod["max_rpm"]), int(mod["alive_frames"]), int(mod["frames"]), int(mod["tunnel_frames"]), str(feed["zone"]),
		JSON.stringify(events), int(mod["max_voices"]), str(music["context"]), str(music["key"])]
	var ok := hooks and music_ok and (st["asset_errors"] as Array).is_empty() and modern_diff.is_empty()
	text += "; Arcade-Busse dabei unverändert" if modern_diff.is_empty() else "; ARCADE-BUSSE GEÄNDERT: " + "; ".join(modern_diff.slice(0, 3))
	if not _live:
		# the last 1.5 km to the finish with Modern
		_launch(128.5, 6)
		var fin: Dictionary = await _drive(0.0, true)
		var st_fin: Dictionary = _modern().call("debug_state")
		await _end_stage()
		var finish_ok := bool(fin["finished"]) and int((st_fin["plays"] as Dictionary).get("finish", 0)) == 1 \
			and (_inject or int((st_fin["events"] as Dictionary).get("stage_finish", 0)) == 1)
		# the same 16 s with the Arcade profile: the simulation does not depend on the sound profile (Rule 3)
		_am.call("set_profile", "arcade")
		_launch(49.4, 5)
		var arc: Dictionary = await _drive(16.0)
		await _end_stage()
		var ha: Array = arc["hashes"]
		var hm: Array = mod["hashes"]
		var first_diff := -1
		for i in mini(ha.size(), hm.size()):
			if ha[i] != hm[i]:
				first_diff = i
				break
		var same := ha.size() == hm.size() and ha.size() >= 15 and first_diff < 0 \
			and JSON.stringify(arc["result"]) == JSON.stringify(mod["result"]) and float(arc["km"]) == float(mod["km"])
		ok = ok and finish_ok and same
		text += "; Zieleinlauf ab km 128,5: im Ziel %s, Zielklang %d ×; dieselben 16 s mit dem Profil Arcade bis km %.2f: Simulation in %d / %d Sekunden gleich%s, Ergebnis gleich %s" % [
			str(fin["finished"]), int((st_fin["plays"] as Dictionary).get("finish", 0)), float(arc["km"]), hm.size(), ha.size(),
			"" if first_diff < 0 else " – ERSTE ABWEICHUNG in Sekunde %d" % first_diff,
			str(JSON.stringify(arc["result"]) == JSON.stringify(mod["result"]))]
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	Engine.max_physics_steps_per_frame = 8
	_am.call("set_profile", "arcade")
	modern_cfg["placeholders"] = placeholders_before
	_check("race", ok, text + (" (Hooks von dieser Prüfung gesendet: %d Zustände)" % int(mod["injected_states"]) if _inject else " (Hooks von der Rennsitzung)"))


func _scenario_arcade_after(golden_file: String) -> void:
	_am.call("set_profile", "arcade")
	_am.call("set_music", false)
	_am.call("stop_all")
	await _wait(0.3)
	# after an Arcade race the room and voice filters may rest a hair beside their start values (RoomAudio only
	# writes changes above 0.01 dB): compare names, sends, effect classes and everything that never moves
	var now := _layout()
	var names_ok := now.size() == _golden.size()
	var notes: Array[String] = []
	for i in mini(now.size(), _golden.size()):
		var a: Dictionary = now[i]
		var g: Dictionary = _golden[i]
		var ae: Array = a["effects"]
		var ge: Array = g["effects"]
		var same := str(a["name"]) == str(g["name"]) and str(a["send"]) == str(g["send"]) and ae.size() == ge.size() \
			and bool(a["mute"]) == bool(g["mute"]) and absf(float(a["volume_db"]) - float(g["volume_db"])) < 1.0e-4
		for j in mini(ae.size(), ge.size()):
			same = same and str(ae[j]["class"]) == str(ge[j]["class"]) and bool(ae[j]["enabled"]) == bool(ge[j]["enabled"])
		if not same:
			names_ok = false
			notes.append(str(a["name"]))
	var strict := _arcade_diff()
	var close := true
	for line in strict:
		close = close and (line.contains("tap1_level_db") or line.contains("tap2_level_db") or line.contains(".wet") or line.contains("cutoff_hz"))
	# the cycle bank both profiles played from (the AudioManager's cached object) still gives the seeded mixer
	# output of v0.7.0, sample for sample
	var bank: Variant = _am.call("bank_for", "limousine")
	var eh: Dictionary = _tool.call("engine_hash_bank", bank) if bank != null else {}
	var want_engine: Dictionary = _golden_engine.get("limousine", {})
	var engine_ok := eh.has("sha256") and str(eh["sha256"]) == str(want_engine.get("sha256", "?"))
	var ok := str(_am.call("profile")) == "arcade" and _modern() == null and names_ok and close and engine_ok
	_check("arcade_after", ok, "nach allem: Profil Arcade, %d Busse mit Sends, Pegeln und Effekten wie in v0.7.0 (%s)%s%s; Motor-Mischer mit der von beiden Profilen benutzten Bank der Limousine: %d Abtastwerte, SHA-256 %s" % [now.size(), golden_file,
		"" if notes.is_empty() else " – abweichend: " + ", ".join(notes),
		"" if strict.is_empty() else "; nach dem Arcade-Rennen ruhen %d Raumklang-/Filterwerte neben dem Startwert (wie in v0.7.0)" % strict.size(),
		int(eh.get("samples", 0)), "wie in v0.7.0" if engine_ok else "ANDERS als in v0.7.0"])
