extends Node
## Autoload "AudioManager": engine (cycle banks per car, docs/motorsound.md), traffic pass-by sounds and the
## spatial siren (docs/verkehrsgeraeusche.md), room sound (tunnel reverb), wind, crash, radar flash, fuel,
## countdown/UI blips, rain, menu music. Owner: UI/audio module.
## Public API = contract (ARCHITECTURE.md §11). Effects and loops are synthesised at startup (SfxSynth) as
## AudioStreamWAV. The engine plays from the car's cycle bank (assets/audio/engines/<id>.json, EngineAudio
## through an AudioStreamGenerator); without a bank the old SfxSynth engine loops play (fallback).
## Menu music: the title theme audio.music_file (OGG Vorbis made by tools/audio/music_synth.py; its import loops
## it after the intro, docs/ui.md "Titelmelodie"); without the file the old SfxSynth loop is synthesised (fallback).
## Nothing is played in headless runs (the engine's gearbox still runs there, for engine_state()).
##
## Buses: Master / SFX / Music (created if missing), volumes from Settings (apply_volumes()); Room (→ SFX: early
## reflections, tunnel reverb) and Engine (→ Room: stereo width of the engine) from RoomAudio; TrafficV<n> and
## Siren (→ Room: low-pass of the air absorption) from TrafficAudio.
## Additions to §11 (documented in docs/ui.md):
##   apply_volumes()       – re-read Settings.master/sfx/music_volume
##   set_music(on)         – menu music on the Music bus (title theme from its start, intro once, then the loop)
##   hud_hints(state)      – called by the HUD each frame; derives rain, skid and siren distance
##                           when the race session does not set them explicitly (explicit calls win)
##   gear_for(speed, vmax) – virtual gearbox of the fallback loops (static, delegates to SfxSynth.gear_for)
##   set_vehicle(id)       – engine of the car (race session at setup); bank loaded lazily and cached
##   engine_state()        – {rpm, gear (0 = neutral), load, boost} of the race engine
##   preview_engine(id)    – vehicle selection: short rev blip of that car (no overlap with the last one)
##   bank_for(id), engine_perf()
##   set_traffic(vehicles, listener) – race session each frame: the renderer's car list (police car id −2) and
##                           the chase camera; nearby vehicles sound at their positions, the siren at the police car
##   set_environment(env)  – {"tunnel": bool} each frame: tunnel reverb fades in/out
##   traffic_state(), traffic_perf() – debug/tests
## Safety: loops and the engine fade out automatically when set_engine() is no longer called (scene left)
## and while the tree is paused (the engine then stops filling its generator); set_engine() calls while
## paused are ignored; play() ignores the same one-shot requested twice within 45 ms. The same holds for the
## traffic: no set_traffic() for 0.35 s or a paused tree fades all voices out; stop_all() silences them at once.
## Debug: --traffic-sounds=<traffic_sounds.json> (e.g. the test fixtures), --audio-config=key=value,… (audio.* for
## this run), --mute-bus=Engine (measure the traffic alone; muting SFX would also mute Room), --perf (AUDIO_PERF at exit).
##
## Sound profiles (v0.8.0, contract docs/dev/v080_contract.md §4.7.1, docs/audio-modern.md): everything above is the
## profile "arcade" and stays as it is. With the profile "modern" every call of this API is handed to a ModernAudio
## node (scripts/audio/modern/modern_audio.gd), which set_profile() builds and frees; the Arcade sound is then silent
## and does not run. Additions:
##   set_profile(id), profile()      – "arcade" | "modern"; idempotent; never during a stage
##   set_race_music(on)              – option "Musik im Rennen" (Modern)
##   set_music_context(ctx, args)    – "title" | "menu" | "race_menu" | "race" | "result" | "off"
##   set_track(track, plan)          – race session after building its track; (null, null) when it leaves
##   set_vehicle_state(state)        – race session every frame (keys: contract §4.7.2)
##   event(name, args)               – session events (contract §4.7.2)
## The last five do nothing with the Arcade profile (the music context and the race-music switch are remembered for
## the next change of profile). At start the profile is --sound=arcade|modern, else config audio.profile, else
## "arcade"; the stored setting "Klang" reaches set_profile() through GameFlow (Settings.sound()). This file never
## reads the graphics mode.

const ONESHOT_DB := {
	"crash": -1.0, "rail": -5.0, "flash": -3.0, "go": -4.0, "beep": -6.0, "finish": -3.0, "fuel_start": -5.0,
	"fuel_done": -4.0, "ui_move": -12.0, "ui_ok": -8.0, "ui_back": -9.0,
}
const LOOPS := ["engine_on", "engine_off", "wind", "rain", "skid"]
const ENGINE_DIR := "res://assets/audio/engines"
const ENGINE_FADE_S := 0.12      ## fade of the bank engine on pause / scene change / resume
const PREVIEW_DB := -2.0         ## vehicle-select blip relative to audio.engine_db
const TRAFFIC_SOUNDS := "res://assets/audio/traffic/traffic_sounds.json"
const ALIVE_S := 0.35            ## traffic counts as left when set_traffic() was not called for this long (as the engine)
const MUSIC_FILE := "res://assets/audio/music/title_theme.ogg"
## audio.music_db (−9 dB) is set for the title theme (mastered to −14 LUFS); the synthesised fallback loop (−20 LUFS)
## was mixed for −4 dB on the bus and gets the difference, so it keeps its old level.
const FALLBACK_MUSIC_DB := 5.0
const PROFILE_ARCADE := "arcade"
const PROFILE_MODERN := "modern"

var sounds_ready := false
var _streams: Dictionary = {}
var _loop_players: Dictionary = {}
var _oneshots: Array[AudioStreamPlayer] = []
var _next_oneshot := 0
var _music: AudioStreamPlayer
var _music_wanted := false
var _music_thread_task := -1
var _music_samples := PackedFloat32Array()
var _last_play: Dictionary = {}
var _time := 0.0

var _gears := 6
var _idle_hz := 38.0
var _max_hz := 175.0
var _engine_speed := 0.0
var _engine_throttle := 0.0
var _engine_vmax := 250.0
var _engine_active := false
var _engine_t := -100.0
var _throttle_s := 0.0
var _pitch_s := 0.5
var _gear := 1
var _shift_dip := 0.0
var _wind_speed := 0.0
var _siren_on := false
var _siren_dist := 0.3
var _rain_explicit := 0.0
var _rain_explicit_t := -100.0
var _skid_explicit := 0.0
var _skid_explicit_t := -100.0
var _hint_t := -100.0
var _hint_rain := 0.0
var _hint_skid := 0.0
var _hint_siren := -1.0
var _hint_chase := false
var _vol: Dictionary = {}

# engine v2 (cycle banks)
var _bank_dir := ENGINE_DIR
var _bank_override := ""
var _banks: Dictionary = {}
var _vehicle_id := ""
var _eng: EngineAudio = null
var _eng_start_pending := false
var _fb_gearbox: EngineGearbox = null
var _engine_db := -3.0
var _engine_latency := 0.07
var _engine_buffer := 0.25
## Queue of the engine generator in the first ENGINE_START_WINDOW_S after the engine started (start of a stage): the
## first frames of a race take long (shader compilation, texture uploads – on a Steam Deck more than the 70 ms of
## engine_latency_s), the queue ran empty and the start clip stuttered (QA v0.5.1, measured with the Dummy driver).
var _engine_start_latency := 0.2
var _eng_started_at := -100.0
const ENGINE_START_WINDOW_S := 1.0
var _preview_on := true
var _preview: EngineAudio = null
var _preview_next: EngineAudio = null
var _preview_t := 0.0
var _stopped_frame := -1

# traffic, siren and room sound (docs/verkehrsgeraeusche.md)
var _traffic: TrafficAudio = null
var _room: RoomAudio = null
var _traffic_vehicles: Array = []
var _traffic_listener: Dictionary = {}
var _traffic_t := -100.0
var _tunnel := false

# sound profile "modern" (v0.8.0): null = the Arcade profile, everything in this file as before.
# Untyped and loaded at run time (MODERN_SCRIPT) on purpose: a variable typed ModernAudio makes this autoload compile
# all of scripts/audio/modern at every start of the game, also when the profile stays Arcade (measured: 19 scripts,
# +82 … +118 ms on "Load Autoloads", +3.6 MiB static memory). An Arcade start loads nothing of the Modern sound –
# tests/unit/audio_modern/check_arcade_lean.gd holds that.
const MODERN_SCRIPT := "res://scripts/audio/modern/modern_audio.gd"
var _modern = null
var _audio_cfg: Dictionary = {}
var _race_music := true
var _music_ctx := ""             ## last set_music_context() ("" = never called)
var _music_ctx_args: Dictionary = {}
var _music_ctx_last := false     ## that call came after the last set_music()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg: Dictionary = ConfigLoader.load_merged()
	_gears = int(ConfigLoader.lookup(cfg, "audio.engine_gears", 6))
	_idle_hz = float(ConfigLoader.lookup(cfg, "audio.engine_idle_hz", 38.0))
	_max_hz = float(ConfigLoader.lookup(cfg, "audio.engine_max_hz", 175.0))
	_engine_db = float(ConfigLoader.lookup(cfg, "audio.engine_db", -3.0))
	_engine_latency = clampf(float(ConfigLoader.lookup(cfg, "audio.engine_latency_s", 0.07)), 0.02, 0.2)
	_engine_buffer = clampf(float(ConfigLoader.lookup(cfg, "audio.engine_buffer_s", 0.25)), _engine_latency * 2.0, 1.0)
	_engine_start_latency = clampf(float(ConfigLoader.lookup(cfg, "audio.engine_start_latency_s", 0.2)), _engine_latency, _engine_buffer * 0.85)
	_preview_on = bool(ConfigLoader.lookup(cfg, "audio.engine_preview", true))
	_bank_dir = str(ConfigLoader.lookup(cfg, "audio.engine_bank_dir", ENGINE_DIR))
	_bank_override = CliArgs.get_string("engine-bank", "")
	_fb_gearbox = EngineGearbox.generic(250.0, _gears)
	_ensure_buses()
	var room_cfg := _with_audio_overrides(cfg)
	_room = RoomAudio.new()
	_room.setup(room_cfg)
	_room.attach("SFX")
	_traffic = TrafficAudio.new()
	_traffic.setup(room_cfg)
	apply_volumes()
	for bus_name in CliArgs.get_string("mute-bus", "").split(",", false):
		if AudioServer.get_bus_index(bus_name) >= 0:
			AudioServer.set_bus_mute(AudioServer.get_bus_index(bus_name), true)
	_audio_cfg = room_cfg
	var settings: Node = get_node_or_null("/root/Settings")
	if settings != null and settings.get("race_music") is bool:
		_race_music = bool(settings.get("race_music"))
	if DisplayServer.get_name() == "headless":
		set_profile(_boot_profile())
		return
	_load_traffic_sounds(room_cfg)
	_build_sounds()
	if bool(ConfigLoader.lookup(cfg, "audio.menu_music", true)):
		if not _load_music(str(ConfigLoader.lookup(cfg, "audio.music_file", MUSIC_FILE))):
			_music_thread_task = WorkerThreadPool.add_task(_generate_music, false, "menu music")
	set_profile(_boot_profile())


func _exit_tree() -> void:
	if _modern != null:
		_modern.shutdown()   # its players, threads and buses; the node goes with this one (--perf: its own AUDIO_PERF)
	elif CliArgs.has("perf") and _traffic != null and _traffic.perf_calls > 0:
		print("AUDIO_PERF ", JSON.stringify({"traffic": traffic_perf(), "engine": engine_perf()}))
	if _traffic != null:
		_traffic.detach()
	if _music_thread_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_thread_task)
		_music_thread_task = -1
	# quit paths that skip the menus (e.g. the screenshotter of --screenshot runs) quit while the title theme plays:
	# release its stream and playback here, otherwise Godot reports them as "resources still in use at exit"
	if _music != null:
		_music.stop()
		_music.stream = null
	_streams.clear()


func _ensure_buses() -> void:
	for bus_name in ["SFX", "Music"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	# safety limiter on the master: engine, close trucks, siren and crash can coincide (no clipping)
	var master := AudioServer.get_bus_index("Master")
	var has_limiter := false
	for i in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, i) is AudioEffectHardLimiter:
			has_limiter = true
	if not has_limiter:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = float(ConfigLoader.lookup(ConfigLoader.load_merged(), "audio.limiter_ceiling_db", -0.8))
		lim.release = 0.12
		AudioServer.add_bus_effect(master, lim)


## Applies Settings.master/sfx/music_volume (0..1) to the buses.
func apply_volumes() -> void:
	var master := 0.8
	var sfx := 1.0
	var music := 0.7
	var st: Node = get_node_or_null("/root/Settings")
	if st != null:
		master = float(st.get("master_volume"))
		sfx = float(st.get("sfx_volume"))
		music = float(st.get("music_volume"))
	var offset := float(ConfigLoader.lookup(ConfigLoader.load_merged(), "audio.master_db", 0.0))
	_set_bus("Master", master, offset)
	_set_bus("SFX", sfx, 0.0)
	_set_bus("Music", music, float(ConfigLoader.lookup(ConfigLoader.load_merged(), "audio.music_db", -4.0)))
	if _modern != null:
		_modern.apply_volumes(sfx, music)


## Debug/measurements: --audio-config=engine_width=0,traffic_db=-3 overrides audio.* keys of the traffic and room
## sound for this run (numbers, true/false or text), without touching the shared user:// configuration.
static func _with_audio_overrides(cfg: Dictionary) -> Dictionary:
	var pairs := CliArgs.get_string("audio-config", "").split(",", false)
	if pairs.is_empty():
		return cfg
	var out := cfg.duplicate(true)
	var audio: Dictionary = out.get("audio", {})
	for pair in pairs:
		var k := pair.get_slice("=", 0).strip_edges()
		var v := pair.get_slice("=", 1).strip_edges()
		if k == "":
			continue
		if v.is_valid_float():
			audio[k] = v.to_float()
		elif v == "true" or v == "false":
			audio[k] = v == "true"
		else:
			audio[k] = v
		print("AudioManager: audio.%s = %s (--audio-config)" % [k, v])
	out["audio"] = audio
	return out


## Traffic sounds (docs/verkehrsgeraeusche.md §1): audio.traffic_sounds (default TRAFFIC_SOUNDS), debug
## --traffic-sounds=<path>. A missing file only means no traffic sound (no error); an unusable one is reported.
func _load_traffic_sounds(cfg: Dictionary) -> void:
	var path := CliArgs.get_string("traffic-sounds", str(ConfigLoader.lookup(cfg, "audio.traffic_sounds", TRAFFIC_SOUNDS)))
	if not FileAccess.file_exists(path):
		print("AudioManager: keine Verkehrsgeräusche (%s fehlt)" % path)
		return
	var t0 := Time.get_ticks_msec()
	if _traffic.load_sounds(path):
		print("AudioManager: Verkehrsgeräusche %s geladen in %d ms (%d Klänge, %d Klassen)" % [path,
			Time.get_ticks_msec() - t0, _traffic.sounds.size(), _traffic.classes.size()])
	else:
		for e in _traffic.errors:
			push_error("Verkehrsgeräusche %s: %s" % [path, e])
	for w in _traffic.warnings:
		push_warning("Verkehrsgeräusche %s: %s" % [path, w])


func _set_bus(bus_name: String, linear: float, offset_db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)) + offset_db)
	AudioServer.set_bus_mute(idx, linear <= 0.001)


func _build_sounds() -> void:
	var t0 := Time.get_ticks_msec()
	_streams["engine_on"] = SfxSynth.to_wav(SfxSynth.engine_loop(true), true)
	_streams["engine_off"] = SfxSynth.to_wav(SfxSynth.engine_loop(false), true)
	_streams["wind"] = SfxSynth.to_wav(SfxSynth.wind_loop(), true)
	_streams["rain"] = SfxSynth.to_wav(SfxSynth.rain_loop(), true)
	_streams["siren"] = SfxSynth.to_wav(SfxSynth.siren_loop(), true)
	_streams["skid"] = SfxSynth.to_wav(SfxSynth.skid_loop(), true)
	_streams["crash"] = SfxSynth.to_wav(SfxSynth.crash())
	_streams["rail"] = SfxSynth.to_wav(SfxSynth.rail_hit())
	_streams["flash"] = SfxSynth.to_wav(SfxSynth.radar_flash())
	_streams["beep"] = SfxSynth.to_wav(SfxSynth.beep(784.0, 0.18, 4.0))
	_streams["go"] = SfxSynth.to_wav(SfxSynth.beep(1568.0, 0.7, 2.5))
	_streams["finish"] = SfxSynth.to_wav(SfxSynth.finish_jingle())
	_streams["fuel_start"] = SfxSynth.to_wav(SfxSynth.fuel_start())
	_streams["fuel_done"] = SfxSynth.to_wav(SfxSynth.fuel_done())
	_streams["ui_move"] = SfxSynth.to_wav(SfxSynth.ui_tick())
	_streams["ui_ok"] = SfxSynth.to_wav(SfxSynth.ui_two_tone(880.0, 1320.0))
	_streams["ui_back"] = SfxSynth.to_wav(SfxSynth.ui_two_tone(660.0, 440.0))
	for n in LOOPS:
		var p := AudioStreamPlayer.new()
		p.stream = _streams[n]
		p.bus = RoomAudio.ENGINE_BUS if n.begins_with("engine") else "SFX"
		p.volume_db = -80.0
		add_child(p)
		_loop_players[n] = p
		_vol[n] = 0.0
	_traffic.siren_stream = _streams["siren"]
	_traffic.attach(self, RoomAudio.ROOM_BUS)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_oneshots.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	sounds_ready = true
	print("AudioManager: Klänge erzeugt in %d ms" % (Time.get_ticks_msec() - t0))


## Title theme (docs/ui.md "Titelmelodie"): an imported audio stream - the OGG's import settings loop it after the
## intro (loop_offset). Missing or unusable -> false, the synthesised loop plays instead.
func _load_music(path: String) -> bool:
	if path == "" or not ResourceLoader.exists(path):
		print("AudioManager: keine Titelmelodie (%s fehlt) – synthetisierte Menümusik" % path)
		return false
	var t0 := Time.get_ticks_msec()
	var s: Variant = load(path)
	if not (s is AudioStream):
		push_warning("Titelmelodie %s ist kein Audiostream – synthetisierte Menümusik" % path)
		return false
	print("AudioManager: Titelmelodie %s geladen in %d ms" % [path, Time.get_ticks_msec() - t0])
	_streams["music"] = s
	_music.stream = s
	_music.volume_db = 0.0
	if _music_wanted:
		_music.play()
	return true


func _generate_music() -> void:
	var t0 := Time.get_ticks_msec()
	_music_samples = SfxSynth.music_loop()
	print("AudioManager: Menümusik erzeugt in %d ms" % (Time.get_ticks_msec() - t0))
	_on_music_ready.call_deferred()


func _on_music_ready() -> void:
	if _music_thread_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_thread_task)
		_music_thread_task = -1
	if _music_samples.is_empty() or _music == null:
		return
	_streams["music"] = SfxSynth.to_wav(_music_samples, true)
	_music_samples = PackedFloat32Array()
	_music.stream = _streams["music"]
	_music.volume_db = FALLBACK_MUSIC_DB
	if _music_wanted:
		_music.play()


# --- public API (ARCHITECTURE.md §11) ----------------------------------------------------------

## Engine sound: speed (km/h), throttle 0..1, current vmax, active = engine running.
## Ignored while the tree is paused (the engine fades out then; the values from before the pause stay) and
## in the frame of stop_all() (a race scene that is being freed must not restart the engine).
func set_engine(speed_kmh: float, throttle: float, vmax_kmh: float, active: bool) -> void:
	if _modern != null:
		_modern.set_engine(speed_kmh, throttle, vmax_kmh, active)
		return
	if is_inside_tree() and get_tree().paused:
		return
	if Engine.get_process_frames() == _stopped_frame:
		return
	_engine_speed = maxf(speed_kmh, 0.0)
	_engine_throttle = clampf(throttle, 0.0, 1.0)
	_engine_vmax = maxf(vmax_kmh, 60.0)
	_engine_active = active
	_engine_t = _time


func set_wind(speed_kmh: float) -> void:
	if _modern != null:
		_modern.set_wind(speed_kmh)
		return
	_wind_speed = maxf(speed_kmh, 0.0)


## Police siren on/off; distance01 = 1 close … 0 far.
func set_siren(on: bool, distance01: float) -> void:
	if _modern != null:
		_modern.set_siren(on, distance01)
		return
	_siren_on = on
	_siren_dist = clampf(distance01, 0.0, 1.0)


func set_rain(intensity: float) -> void:
	if _modern != null:
		_modern.set_rain(intensity)
		return
	_rain_explicit = clampf(intensity, 0.0, 1.0)
	_rain_explicit_t = _time


func set_skid(amount01: float) -> void:
	if _modern != null:
		_modern.set_skid(amount01)
		return
	_skid_explicit = clampf(amount01, 0.0, 1.0)
	_skid_explicit_t = _time


## One-shot effects: "crash", "flash", "go", "beep", "finish", "fuel_start", "fuel_done", "ui_move",
## "ui_ok", "ui_back".
## One-shot sound; gain_db is added to its base level (e.g. a guardrail hit scaled by the impact).
func play(sound_name: String, gain_db: float = 0.0) -> void:
	if _modern != null:
		_modern.play(sound_name, gain_db)
		return
	if not sounds_ready or not _streams.has(sound_name) or _oneshots.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(sound_name, -100000)) < 45:
		return
	_last_play[sound_name] = now
	var p := _oneshots[_next_oneshot]
	_next_oneshot = (_next_oneshot + 1) % _oneshots.size()
	p.stream = _streams[sound_name]
	p.volume_db = float(ONESHOT_DB.get(sound_name, -4.0)) + gain_db
	p.play()


func stop_all() -> void:
	if _modern != null:
		_modern.stop_all()
		return
	for n in _loop_players:
		(_loop_players[n] as AudioStreamPlayer).stop()
		_vol[n] = 0.0
	for p in _oneshots:
		p.stop()
	if _eng != null:
		_eng.detach()
		_eng.reset()
	_stop_preview()
	if _fb_gearbox != null:
		_fb_gearbox.reset()
	_stopped_frame = Engine.get_process_frames()
	_engine_t = -100.0
	_siren_on = false
	_wind_speed = 0.0
	_rain_explicit = 0.0
	_skid_explicit = 0.0
	_hint_t = -100.0
	_traffic_t = -100.0
	_traffic_vehicles = []
	_tunnel = false
	if _traffic != null:
		_traffic.reset()
	if _room != null:
		_room.reset()


# --- sound profiles (v0.8.0, contract §4.7.1) ------------------------------------------------

## Sound profile: "arcade" = this file as before, "modern" = the calls go to a ModernAudio node built here (any
## other id counts as "arcade"). Idempotent. On a change the sound of the old profile stops at once and the menu
## music continues in the new one. Never called during a stage.
func set_profile(id: String) -> void:
	var want := PROFILE_MODERN if id == PROFILE_MODERN else PROFILE_ARCADE
	if want == profile():
		return
	if want == PROFILE_MODERN:
		var music_on := _music_wanted
		stop_all()   # the Arcade sound (no ModernAudio yet)
		_set_arcade_music(false)
		_modern = (load(MODERN_SCRIPT) as GDScript).new()
		add_child(_modern)
		_modern.start(_audio_cfg if not _audio_cfg.is_empty() else ConfigLoader.load_merged(),
			{"streams": _streams, "arcade_traffic": _traffic, "bank_provider": Callable(self, "bank_for")})
		_modern.set_race_music(_race_music)
		# the music calls so far, in their order (the last one wins – MusicDirector)
		if _music_ctx != "" and not _music_ctx_last:
			_modern.set_music_context(_music_ctx, _music_ctx_args)
		_modern.set_music(music_on)
		if _music_ctx != "" and _music_ctx_last:
			_modern.set_music_context(_music_ctx, _music_ctx_args)
	else:
		var music_on: bool = _modern.music != null and _modern.music.wanted()
		_modern.shutdown()
		_modern.queue_free()
		_modern = null
		_stopped_frame = -1
		_set_arcade_music(music_on)
	apply_volumes()


func profile() -> String:
	return PROFILE_MODERN if _modern != null else PROFILE_ARCADE


## Profile at start: --sound=arcade|modern, else config audio.profile, else "arcade".
static func _boot_profile() -> String:
	for v: String in [CliArgs.get_string("sound", ""), str(ConfigLoader.lookup(ConfigLoader.load_merged(), "audio.profile", ""))]:
		if v == PROFILE_ARCADE or v == PROFILE_MODERN:
			return v
	return PROFILE_ARCADE


## Option "Musik im Rennen" of the Modern profile (Arcade has no music in races).
func set_race_music(on: bool) -> void:
	_race_music = on
	if _modern != null:
		_modern.set_race_music(on)


## Where the game is, for the music of the Modern profile: "title" | "menu" | "race_menu" (screens between stages) |
## "race" | "result" | "off". Arcade: remembered only (its menu music follows set_music()).
func set_music_context(ctx: String, args: Dictionary = {}) -> void:
	_music_ctx = ctx
	_music_ctx_args = args
	_music_ctx_last = true
	if _modern != null:
		_modern.set_music_context(ctx, args)


## The race session after building its track; (null, null) when it leaves the stage. Arcade: nothing.
func set_track(track: Object, plan: Object) -> void:
	if _modern != null:
		_modern.set_track(track, plan)


## The car's state, every frame of a race (keys: contract §4.7.2). Arcade: nothing.
func set_vehicle_state(state: Dictionary) -> void:
	if _modern != null:
		_modern.set_vehicle_state(state)


## Session event (contract §4.7.2: "stage_start", "countdown", "go", "collision", "rail_hit", "radar_flash",
## "chase_start", "escaped", "busted", "refuel_start", "refuel_done", "out_of_fuel", "tow", "stage_finish").
## Arcade: nothing.
func event(event_name: String, args: Dictionary = {}) -> void:
	if _modern != null:
		_modern.event(event_name, args)


# --- additions -----------------------------------------------------------------------------

## Traffic pass-by sounds and the spatial siren (docs/verkehrsgeraeusche.md), called by the race session each frame:
## vehicles = the renderer's car list [{id, set, z (rear), x, length, speed (km/h), heavy?}], the police car with
## id −2; listener = the chase camera {z, x, speed (km/h)} (TrafficAudio adds audio.traffic_listener_ahead_m).
## Ignored while paused and in the frame of stop_all(); without calls for ALIVE_S everything fades out.
func set_traffic(vehicles: Array, listener: Dictionary) -> void:
	if _modern != null:
		_modern.set_traffic(vehicles, listener)
		return
	if is_inside_tree() and get_tree().paused:
		return
	if Engine.get_process_frames() == _stopped_frame:
		return
	_traffic_vehicles = vehicles
	_traffic_listener = listener
	_traffic_t = _time


## Surroundings of the listener: {"tunnel": bool} (camera in a tunnel) – the tunnel reverb fades in and out.
func set_environment(env: Dictionary) -> void:
	if _modern != null:
		_modern.set_environment(env)
		return
	if Engine.get_process_frames() == _stopped_frame:
		return
	_tunnel = bool(env.get("tunnel", false))


## Debug/tests: voices of the last frame (TrafficAudio.state()) plus the room blend.
func traffic_state() -> Dictionary:
	if _modern != null:
		return _modern.traffic_state()
	if _traffic == null:
		return {}
	var s: Dictionary = _traffic.state()
	s["tunnel_blend"] = _room.blend if _room != null else 0.0
	return s


## GDScript time of the traffic voices per frame (update + apply): {avg_ms, max_ms, frames, apply_avg_ms,
## apply_max_ms (pushing the values to the players alone)}.
func traffic_perf() -> Dictionary:
	if _modern != null:
		return _modern.traffic_perf()
	if _traffic == null or _traffic.perf_calls == 0:
		return {"avg_ms": 0.0, "max_ms": 0.0, "frames": 0, "apply_avg_ms": 0.0, "apply_max_ms": 0.0}
	return {"avg_ms": _traffic.perf_us_sum / 1000.0 / _traffic.perf_calls, "max_ms": _traffic.perf_us_max / 1000.0,
		"frames": _traffic.perf_calls, "apply_avg_ms": _traffic.perf_apply_us_sum / 1000.0 / _traffic.perf_calls,
		"apply_max_ms": _traffic.perf_apply_us_max / 1000.0}


## Menu music on/off (Music bus). On starts the title theme from its beginning (the intro plays once, then the
## loop); while it plays, further set_music(true) calls change nothing - it keeps running (attract mode, screens).
func set_music(on: bool) -> void:
	_music_ctx_last = false
	if _modern != null:
		_modern.set_music(on)
		return
	_set_arcade_music(on)


func _set_arcade_music(on: bool) -> void:
	_music_wanted = on
	if _music == null:
		return
	if on and _music.stream != null and not _music.playing:
		_music.play()
	elif not on and _music.playing:
		_music.stop()


## HUD state of the current frame (see Hud.update_state): fallback values for rain, skid and the
## siren distance. Explicit set_rain/set_skid calls of the last second take precedence.
func hud_hints(state: Dictionary) -> void:
	if _modern != null:
		_modern.hud_hints(state)
		return
	_hint_t = _time
	var w := str(state.get("weather", "normal"))
	_hint_rain = 1.0 if (w == "rain" and not bool(state.get("in_tunnel", false))) else 0.0
	_hint_skid = clampf(float(state.get("understeer", 0.0)), 0.0, 1.0)
	var ps := str(state.get("police_state", "none"))
	_hint_chase = ps == "chase" or ps == "stopping"
	if _hint_chase:
		_hint_siren = clampf(1.0 - float(state.get("police_gap_m", 300.0)) / 420.0, 0.15, 1.0)
	else:
		_hint_siren = -1.0


## Virtual gearbox of the fallback loops: gear (1..gears) and rpm fraction (0..1 within the gear) – see
## SfxSynth.gear_for.
static func gear_for(speed_kmh: float, vmax_kmh: float, gears: int = 6) -> Vector2:
	return SfxSynth.gear_for(speed_kmh, vmax_kmh, gears)


## Engine of the car (the race session calls it at setup with its vehicle id): its cycle bank is loaded
## lazily and cached; the next set_engine() starts the engine (start clip of the bank). Without a usable
## bank the old SfxSynth engine loops play.
func set_vehicle(id: String) -> void:
	if _modern != null:
		_modern.set_vehicle(id)
		return
	_vehicle_id = id
	_stopped_frame = -1
	var vmax := float(ConfigLoader.lookup(ConfigLoader.load_merged(), "vehicles.types.%s.vmax_kmh" % id, 250.0))
	_fb_gearbox = EngineGearbox.generic(vmax, _gears)
	if _eng != null:
		_eng.detach()
	_eng = null
	_eng_start_pending = false
	var bank := bank_for(id)
	if bank != null:
		_eng = EngineAudio.new(bank)
		_eng.level = db_to_linear(_engine_db)
		_eng.reset()
		_eng_start_pending = true


## Cycle bank of a car (cached, also misses). null = no usable bank (missing or invalid -> fallback loops).
## Debug: --engine-bank=<path/to/bank.json> uses that bank for every car.
func bank_for(id: String) -> EngineBank:
	var path := _bank_override if _bank_override != "" else _bank_dir.path_join(id + ".json")
	if _banks.has(path):
		return _banks[path]
	var bank: EngineBank = null
	if FileAccess.file_exists(path):
		var t0 := Time.get_ticks_msec()
		var b := EngineBank.load_file(path)
		if b.ok():
			bank = b
			print("AudioManager: Motorbank %s geladen in %d ms" % [b.summary(), Time.get_ticks_msec() - t0])
			for w in b.warnings:
				push_warning("Motorbank %s: %s" % [path, w])
		else:
			for e in b.errors:
				push_error("Motorbank %s: %s" % [path, e])
	else:
		print("AudioManager: keine Motorbank für \"%s\" – bisheriger Motorklang" % id)
	_banks[path] = bank
	return bank


## Engine state of the race car (tests, HUD): {rpm, gear (0 = neutral, 1..n), load 0..1, boost 0..1}.
## Without a bank: the generic gearbox that runs alongside the fallback loops.
func engine_state() -> Dictionary:
	if _modern != null:
		return _modern.engine_state()
	if _eng != null:
		return _eng.state()
	if _fb_gearbox != null:
		return {"rpm": _fb_gearbox.rpm, "gear": _fb_gearbox.gear, "load": _fb_gearbox.load, "boost": 0.0}
	return {"rpm": 0.0, "gear": 0, "load": 0.0, "boost": 0.0}


## Render time of the bank engine (live playback): {avg_ms, max_ms per filling call, frames = filling calls,
## samples rendered, skips = generator underruns of the current playback}.
func engine_perf() -> Dictionary:
	if _modern != null:
		return _modern.engine_perf()
	if _eng == null or _eng.perf_calls == 0:
		return {"avg_ms": 0.0, "max_ms": 0.0, "frames": 0, "samples": 0, "skips": 0}
	return {"avg_ms": _eng.perf_us_sum / 1000.0 / _eng.perf_calls, "max_ms": _eng.perf_us_max / 1000.0,
		"frames": _eng.perf_calls, "samples": _eng.perf_samples, "skips": _eng.skips()}


## Vehicle selection: a short rev blip of that car (idle -> blip -> idle, EngineAudio.PREVIEW_S). A running
## blip fades out first and the new one follows in the same stream – they never overlap. Needs the car's
## cycle bank (no blip with the fallback loops) and config audio.engine_preview.
func preview_engine(id: String) -> void:
	if _modern != null:
		_modern.preview_engine(id)
		return
	if not _preview_on or not sounds_ready:
		return
	var bank := bank_for(id)
	if bank == null:
		return
	var e := EngineAudio.new(bank)
	e.level = db_to_linear(_engine_db + PREVIEW_DB)
	e.start(false)
	if _preview == null:
		_preview = e
		_preview_t = 0.0
		_preview.attach(self, "SFX", _engine_buffer)
	else:
		_preview.fade_to(0.0, 0.04)
		_preview_next = e


func _stop_preview() -> void:
	if _preview != null:
		_preview.detach()
	_preview = null
	_preview_next = null


func _process_preview(delta: float) -> void:
	if _preview == null:
		return
	if _preview_next != null and _preview.is_silent():
		_preview_next.take_output(_preview, self, "SFX", _engine_buffer)
		_preview = _preview_next
		_preview_next = null
		_preview_t = 0.0
	_preview_t += delta
	var thr := 0.0
	if _preview_next == null:
		thr = EngineAudio.preview_throttle(_preview_t)
		if _preview_t >= EngineAudio.PREVIEW_S - 0.25:
			_preview.fade_to(0.0, 0.25)
	_preview.update(delta, 0.0, thr, 0.0, false)
	_preview.pump(_engine_latency, delta)
	if _preview_next == null and _preview.is_silent() and _preview_t > EngineAudio.PREVIEW_S + 0.5:
		_stop_preview()


## Bank engine (or the generic gearbox of the fallback): runs also headless, so engine_state() works there.
func _process_engine(delta: float, alive: bool) -> void:
	if _eng == null:
		if _fb_gearbox != null and alive:
			_fb_gearbox.update(delta, _engine_speed, _engine_throttle, _engine_vmax, _engine_active)
		return
	if alive:
		if _eng_start_pending:
			_eng_start_pending = false
			_eng.start(true)
			_eng_started_at = _time
		_eng.update(delta, _engine_speed, _engine_throttle, _engine_vmax, _engine_active)
		_eng.fade_to(1.0, ENGINE_FADE_S)
	else:
		_eng.fade_to(0.0, ENGINE_FADE_S)
	if sounds_ready:
		if _eng.player == null and not _eng.is_silent():
			_eng.attach(self, RoomAudio.ENGINE_BUS, _engine_buffer)
		_eng.pump(_engine_latency if _time - _eng_started_at > ENGINE_START_WINDOW_S else _engine_start_latency, delta)


func _process(delta: float) -> void:
	_time += delta
	if _modern != null:
		return   # profile "modern": the Arcade sound was stopped by set_profile() and does not run
	var paused := get_tree().paused
	var alive := (_time - _engine_t) < 0.35 and not paused
	_process_engine(delta, alive)
	if not sounds_ready:
		return
	_process_preview(delta)
	var k_fast := 1.0 - exp(-delta / 0.06)
	var k_slow := 1.0 - exp(-delta / 0.25)
	# engine with virtual gearbox
	var gv := gear_for(_engine_speed, _engine_vmax, _gears)
	var gear := int(gv.x)
	if gear != _gear and alive:
		if gear > _gear:
			_shift_dip = 1.0
		_gear = gear
	_shift_dip = maxf(0.0, _shift_dip - delta / 0.14)
	var freq := lerpf(_idle_hz, _max_hz, clampf(gv.y, 0.0, 1.0))
	if _engine_speed < 3.0:
		freq = _idle_hz + (_max_hz - _idle_hz) * 0.45 * _engine_throttle
	if not _engine_active:
		freq = _idle_hz * 1.05 + (_max_hz - _idle_hz) * 0.5 * _engine_throttle
	_throttle_s = lerpf(_throttle_s, _engine_throttle, k_fast)
	_pitch_s = lerpf(_pitch_s, freq / SfxSynth.ENGINE_BASE_HZ, k_fast if _shift_dip <= 0.0 else k_fast * 2.0)
	var base := 0.0
	if alive and _eng == null:
		base = (0.5 + 0.25 * _throttle_s) * (1.0 - 0.45 * _shift_dip)
		if not _engine_active:
			base *= 0.75
	_loop("engine_on", base * (0.25 + 0.75 * _throttle_s), _pitch_s, k_fast)
	_loop("engine_off", base * (1.0 - 0.6 * _throttle_s), _pitch_s, k_fast)
	# wind
	var wind := 0.0
	if alive:
		wind = pow(clampf((_wind_speed - 35.0) / 220.0, 0.0, 1.0), 1.4) * 0.55
	_loop("wind", wind, 0.85 + 0.4 * clampf(_wind_speed / 250.0, 0.0, 1.2), k_slow)
	# rain, skid: explicit within the last second, else HUD hints
	var hints := (_time - _hint_t) < 0.5 and not paused
	var rain := _rain_explicit if (_time - _rain_explicit_t) < 1.0 else (_hint_rain if hints else 0.0)
	_loop("rain", rain * 0.38 if not paused else 0.0, 1.0, k_slow)
	var skid := _skid_explicit if (_time - _skid_explicit_t) < 1.0 else (_hint_skid if hints else 0.0)
	_loop("skid", clampf(skid - 0.15, 0.0, 1.0) * 0.45 if alive else 0.0, 1.0 + 0.05 * sin(_time * 9.0), k_fast)
	# siren: on/off and its centred level as before; TrafficAudio places it at the police car when the race session
	# sends that (set_traffic), with distance law and Doppler
	var siren := 0.0
	if _siren_on and (alive or hints):
		var d := _hint_siren if (hints and _hint_siren >= 0.0) else _siren_dist
		siren = lerpf(0.18, 0.8, d)
		if hints and not _hint_chase:
			siren = 0.0
	_traffic.set_siren(siren > 0.0, siren)
	# traffic voices (fade out while paused or when the race session stopped calling) and the room
	var traffic_alive := (_time - _traffic_t) < ALIVE_S and not paused
	_traffic.update(delta, _traffic_vehicles if traffic_alive else [], _traffic_listener, traffic_alive)
	_traffic.apply()
	_room.update(delta, _tunnel)


func _loop(n: String, target: float, pitch: float, k: float) -> void:
	var p: AudioStreamPlayer = _loop_players.get(n)
	if p == null:
		return
	var v := lerpf(float(_vol.get(n, 0.0)), target, k)
	_vol[n] = v
	if v < 0.002:
		if p.playing:
			p.stop()
		return
	if not p.playing:
		p.play()
	p.volume_db = linear_to_db(v)
	p.pitch_scale = clampf(pitch, 0.05, 8.0)
