extends SceneTree
## QA-M2-SYSTEM: the sound of a REAL race (race scene, Track, traffic, AudioFeed) with a sound profile, headless in real
## time (Dummy driver; ModernAudio.force_live as tools/audio/modern/capture_mix.gd does). Records the Master bus and
## applies the Master volume (= what reaches the sound card), and logs with the time of the recording:
##   feed   the AudioFeed state at the car whenever paving, deck, bridge, zone, city, tunnel or a wheel surface changes
##   play   every one-shot that reached a slot (ModernAudio.plays), with the count
##   event  every event ModernAudio saw (ModernAudio.events_seen: session and feed events, e.g. "joint", "collision")
##   pos    km, speed and state of the car every 0.25 s; music context / piece / phase on every change
##   godot --headless --path <tree> -s <this> -- --graphics=arcade --sound=modern --stage=kiel_hamburg \
##       --start-km=77 --seconds=60 --out=/abs/x.wav [--master=1.0] [--vehicle=limousine] [--hour=12]
##       [--weather=normal] [--seed=7] [--race-music=1] [--music] [--crash] [--start-speed=…] [--lane=…]
##   --crash: no autopilot, the car rolls at --start-speed (session CLI) into the traffic of its lane (--traffic-warmup).
## Output: <out>.wav (16 bit) and <out>.json {settings, log}. Exit 0 when the file was written.

var _am: Node
var _rec: AudioEffectRecord
var _scene: Node
var _t0 := 0
var _log: Array = []
var _last_feed: Dictionary = {}
var _last_plays: Dictionary = {}
var _last_events: Dictionary = {}
var _last_mod: Dictionary = {}
var _last_music: Dictionary = {}
var _next_pos := 0.0
var _finished := false
var _movie := false
var _f0 := 0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	return false


## Time of the recording: in Movie Maker mode (--movie, with --write-movie and --fixed-fps 60) the frames – the audio is
## mixed in lockstep with them, so the log and the WAV share one clock; else the wall clock.
func _now() -> float:
	if _movie:
		return float(Engine.get_process_frames() - _f0) / 60.0
	return (Time.get_ticks_usec() - _t0) / 1.0e6


func _run() -> void:
	for i in 3:
		await process_frame
	Engine.max_fps = 60
	_am = root.get_node("AudioManager")
	var st: Node = root.get_node("Settings")
	var profile := CliArgs.get_string("sound", "modern")
	var cfg: Dictionary = _am.get("_audio_cfg")
	ModernAudio.force_live = true
	_am.call("set_profile", "arcade")
	if not bool(_am.get("sounds_ready")):
		_am.call("_load_traffic_sounds", cfg)
		_am.call("_build_sounds")
		_am.call("_load_music", str(ConfigLoader.lookup(cfg, "audio.music_file", "")))
	_am.call("set_profile", profile)
	var master := CliArgs.get_float("master", 1.0)
	st.set("master_volume", master)
	st.call("apply")
	var rm := CliArgs.get_float("race-music", 1.0) > 0.5
	st.set("race_music", rm)
	_am.call("set_race_music", rm)
	await process_frame
	var c := ConfigLoader.load_merged()
	var crash := CliArgs.has("crash")
	var setup := {
		"mode": "single", "race_id": "",
		"stage_id": CliArgs.get_string("stage", "kiel_hamburg"),
		"from_city": CliArgs.get_string("from", ""),
		"vehicle": CliArgs.get_string("vehicle", "limousine"),
		"start_world_minutes": CliArgs.get_float("hour", 12.0) * 60.0,
		"weather": CliArgs.get_string("weather", "normal"),
		"start_km": CliArgs.get_float("start-km", 0.0),
		"autopilot": not crash,
		"autopilot_refuel": "never",
		"no_countdown": not CliArgs.has("countdown"),
		"seed": int(CliArgs.get_float("seed", 7.0)),
		"gfx": "arcade",
	}
	if CliArgs.has("music"):
		_am.call("set_music_context", "race", {})
	_rec = AudioEffectRecord.new()
	_rec.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, _rec)
	_rec.set_recording_active(true)
	_t0 = Time.get_ticks_usec()
	_movie = CliArgs.has("movie")
	_f0 = Engine.get_process_frames()
	_scene = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	_scene.set("setup", setup)
	_scene.connect("stage_finished", func(_r: Variant) -> void: _finished = true)
	root.add_child(_scene)
	var secs := CliArgs.get_float("seconds", 60.0)
	while _now() < secs and not _finished:
		_poll()
		await process_frame
	_poll()
	var total := _now()
	_rec.set_recording_active(false)
	var wav := _rec.get_recording()
	var gain := db_to_linear(AudioServer.get_bus_volume_db(0))
	var data := wav.data
	if absf(gain - 1.0) > 1.0e-6:
		for i in range(0, data.size(), 2):
			data.encode_s16(i, clampi(int(round(data.decode_s16(i) * gain)), -32768, 32767))
		wav.data = data
	var out := CliArgs.get_string("out", "user://qa_race_sound.wav")
	var err := wav.save_to_wav(out)
	var m: Variant = _am.get("_modern")
	var info := {"profile": str(_am.call("profile")), "setup": setup, "seconds": snappedf(total, 0.01),
		"mix_rate": int(wav.mix_rate), "master_db": AudioServer.get_bus_volume_db(0), "master_volume": master,
		"race_music": rm, "crash": crash, "finished": _finished, "log": _log,
		"plays": (m.get("plays") if m != null else {}), "events_seen": (m.get("events_seen") if m != null else {}),
		"dropped": (m.get("dropped") if m != null else {})}
	var f := FileAccess.open(out.get_basename() + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(info, "\t") + "\n")
	f.close()
	print("QA-RACE-SOUND %s (%s, %.1f s, finished %s) -> %s" % [out, info["profile"], total, str(_finished), error_string(err)])
	for j in range(AudioServer.get_bus_effect_count(0) - 1, -1, -1):
		if AudioServer.get_bus_effect(0, j) == _rec:
			AudioServer.remove_bus_effect(0, j)
	_scene.queue_free()
	_am.call("set_music", false)
	_am.call("stop_all")
	for i in 30:
		await process_frame
	_am.call("set_profile", "arcade")
	for i in 150:
		await process_frame
	quit(0 if err == OK else 1)


func _poll() -> void:
	var t := snappedf(_now(), 0.001)
	var km := float(_scene.get("pos_km")) if _scene != null and _scene.get("pos_km") != null else -1.0
	var m: Variant = _am.get("_modern")
	if m != null:
		var feed: Variant = m.get("feed")
		if feed != null and bool(feed.get("valid")):
			var s: Dictionary = feed.call("state")
			var key := {"paving": s["paving"], "deck": s["deck"], "bridge": s["bridge"], "zone": s["zone"],
				"city": s["city"], "tunnel": s["tunnel"], "surface_l": s["surface_l"], "surface_r": s["surface_r"],
				"road": s["road"]}
			if key != _last_feed:
				_log.append({"t": t, "kind": "feed", "km": snappedf(km, 0.001), "state": key})
				_last_feed = key
		var plays: Dictionary = m.get("plays")
		for k: Variant in plays:
			if int(plays[k]) != int(_last_plays.get(k, 0)):
				_log.append({"t": t, "kind": "play", "name": str(k), "n": int(plays[k]), "km": snappedf(km, 0.001)})
		_last_plays = plays.duplicate()
		var ev: Dictionary = m.get("events_seen")
		for k: Variant in ev:
			if int(ev[k]) != int(_last_events.get(k, 0)):
				_log.append({"t": t, "kind": "event", "name": str(k), "n": int(ev[k]), "km": snappedf(km, 0.001)})
		_last_events = ev.duplicate()
		var ra: Variant = m.get("road")
		if ra != null:
			var rp: Dictionary = ra.get("played")
			for k: Variant in rp:
				var kk := "road_" + str(k)
				if int(rp[k]) != int(_last_mod.get(kk, 0)):
					_log.append({"t": t, "kind": "play", "name": kk, "n": int(rp[k]), "km": snappedf(km, 0.001)})
					_last_mod[kk] = int(rp[k])
		var ia: Variant = m.get("impact")
		if ia != null:
			var ic: Dictionary = ia.get("counts")
			for k: Variant in ic:
				var kk := "impact_" + str(k)
				if int(ic[k]) != int(_last_mod.get(kk, 0)):
					_log.append({"t": t, "kind": "play", "name": kk, "n": int(ic[k]), "km": snappedf(km, 0.001)})
					_last_mod[kk] = int(ic[k])
		var mu: Variant = m.get("music")
		if mu != null:
			var ms := {"context": str(mu.get("context")), "race_phase": str(mu.get("race_phase")),
				"race_index": int(mu.get("race_index")), "key": str((mu.get("_key") as Array)[int(mu.get("_cur"))]),
				"ending": str(mu.get("ending_variant")), "stingers": str(mu.get("stingers_played"))}
			if ms != _last_music:
				_log.append({"t": t, "kind": "music", "state": ms, "km": snappedf(km, 0.001)})
				_last_music = ms
	if t >= _next_pos and _scene != null:
		var v: Variant = _scene.get("vehicle")
		var mm: Variant = m.get("mix") if m != null else null
		_log.append({"t": t, "kind": "pos", "km": snappedf(km, 0.001),
			"speed": snappedf(float(v.get("speed")), 0.1) if v != null else -1.0,
			"state": int(v.get("state")) if v != null else -1,
			"duck_db": snappedf(float(mm.get("duck_db")), 0.01) if mm != null else 0.0})
		_next_pos = t + 0.25
