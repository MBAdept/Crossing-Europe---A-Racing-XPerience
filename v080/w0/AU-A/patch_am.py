#!/usr/bin/env python3
"""Applies the v0.8.0 delegation to scripts/audio/audio_manager.gd (run once on the v0.7.0 file)."""
import sys

P = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3/scripts/audio/audio_manager.gd"
s = open(P, encoding="utf-8").read()


def rep(old: str, new: str) -> None:
    global s
    if s.count(old) != 1:
        sys.exit("Anker %d-mal gefunden:\n%s" % (s.count(old), old))
    s = s.replace(old, new)


# --- header -------------------------------------------------------------------------------------
rep('''## Debug: --traffic-sounds=<traffic_sounds.json> (e.g. the test fixtures), --audio-config=key=value,… (audio.* for
## this run), --mute-bus=Engine (measure the traffic alone; muting SFX would also mute Room), --perf (AUDIO_PERF at exit).
''', '''## Debug: --traffic-sounds=<traffic_sounds.json> (e.g. the test fixtures), --audio-config=key=value,… (audio.* for
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
''')

rep('''const FALLBACK_MUSIC_DB := 5.0
''', '''const FALLBACK_MUSIC_DB := 5.0
const PROFILE_ARCADE := "arcade"
const PROFILE_MODERN := "modern"
''')

rep('''var _traffic_t := -100.0
var _tunnel := false

''', '''var _traffic_t := -100.0
var _tunnel := false

# sound profile "modern" (v0.8.0): null = the Arcade profile, everything in this file as before
var _modern: ModernAudio = null
var _audio_cfg: Dictionary = {}
var _race_music := true
var _music_ctx := ""             ## last set_music_context() ("" = never called)
var _music_ctx_args: Dictionary = {}
var _music_ctx_last := false     ## that call came after the last set_music()

''')

# --- _ready -------------------------------------------------------------------------------------
rep('''	if DisplayServer.get_name() == "headless":
		return
	_load_traffic_sounds(room_cfg)
	_build_sounds()
	if bool(ConfigLoader.lookup(cfg, "audio.menu_music", true)):
		if not _load_music(str(ConfigLoader.lookup(cfg, "audio.music_file", MUSIC_FILE))):
			_music_thread_task = WorkerThreadPool.add_task(_generate_music, false, "menu music")
''', '''	_audio_cfg = room_cfg
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
''')

rep('''func _exit_tree() -> void:
	if CliArgs.has("perf") and _traffic != null and _traffic.perf_calls > 0:
''', '''func _exit_tree() -> void:
	if _modern != null:
		_modern.shutdown()   # its players, threads and buses; the node goes with this one
	if CliArgs.has("perf") and _traffic != null and _traffic.perf_calls > 0:
''')

rep('''	_set_bus("Music", music, float(ConfigLoader.lookup(ConfigLoader.load_merged(), "audio.music_db", -4.0)))
''', '''	_set_bus("Music", music, float(ConfigLoader.lookup(ConfigLoader.load_merged(), "audio.music_db", -4.0)))
	if _modern != null:
		_modern.apply_volumes(sfx, music)
''')

# --- delegation of the existing API -------------------------------------------------------------
rep('''func set_engine(speed_kmh: float, throttle: float, vmax_kmh: float, active: bool) -> void:
	if is_inside_tree() and get_tree().paused:
''', '''func set_engine(speed_kmh: float, throttle: float, vmax_kmh: float, active: bool) -> void:
	if _modern != null:
		_modern.set_engine(speed_kmh, throttle, vmax_kmh, active)
		return
	if is_inside_tree() and get_tree().paused:
''')

rep('''func set_wind(speed_kmh: float) -> void:
	_wind_speed = maxf(speed_kmh, 0.0)
''', '''func set_wind(speed_kmh: float) -> void:
	if _modern != null:
		_modern.set_wind(speed_kmh)
		return
	_wind_speed = maxf(speed_kmh, 0.0)
''')

rep('''func set_siren(on: bool, distance01: float) -> void:
	_siren_on = on
''', '''func set_siren(on: bool, distance01: float) -> void:
	if _modern != null:
		_modern.set_siren(on, distance01)
		return
	_siren_on = on
''')

rep('''func set_rain(intensity: float) -> void:
	_rain_explicit = clampf(intensity, 0.0, 1.0)
''', '''func set_rain(intensity: float) -> void:
	if _modern != null:
		_modern.set_rain(intensity)
		return
	_rain_explicit = clampf(intensity, 0.0, 1.0)
''')

rep('''func set_skid(amount01: float) -> void:
	_skid_explicit = clampf(amount01, 0.0, 1.0)
''', '''func set_skid(amount01: float) -> void:
	if _modern != null:
		_modern.set_skid(amount01)
		return
	_skid_explicit = clampf(amount01, 0.0, 1.0)
''')

rep('''func play(sound_name: String, gain_db: float = 0.0) -> void:
	if not sounds_ready or not _streams.has(sound_name) or _oneshots.is_empty():
''', '''func play(sound_name: String, gain_db: float = 0.0) -> void:
	if _modern != null:
		_modern.play(sound_name, gain_db)
		return
	if not sounds_ready or not _streams.has(sound_name) or _oneshots.is_empty():
''')

rep('''func stop_all() -> void:
	for n in _loop_players:
''', '''func stop_all() -> void:
	if _modern != null:
		_modern.stop_all()
		return
	for n in _loop_players:
''')

rep('''func set_traffic(vehicles: Array, listener: Dictionary) -> void:
	if is_inside_tree() and get_tree().paused:
''', '''func set_traffic(vehicles: Array, listener: Dictionary) -> void:
	if _modern != null:
		_modern.set_traffic(vehicles, listener)
		return
	if is_inside_tree() and get_tree().paused:
''')

rep('''func set_environment(env: Dictionary) -> void:
	if Engine.get_process_frames() == _stopped_frame:
''', '''func set_environment(env: Dictionary) -> void:
	if _modern != null:
		_modern.set_environment(env)
		return
	if Engine.get_process_frames() == _stopped_frame:
''')

rep('''func traffic_state() -> Dictionary:
	if _traffic == null:
''', '''func traffic_state() -> Dictionary:
	if _modern != null:
		return _modern.traffic_state()
	if _traffic == null:
''')

rep('''func traffic_perf() -> Dictionary:
	if _traffic == null or _traffic.perf_calls == 0:
''', '''func traffic_perf() -> Dictionary:
	if _modern != null:
		return _modern.traffic_perf()
	if _traffic == null or _traffic.perf_calls == 0:
''')

rep('''func set_music(on: bool) -> void:
	_music_wanted = on
''', '''func set_music(on: bool) -> void:
	_music_ctx_last = false
	if _modern != null:
		_modern.set_music(on)
		return
	_set_arcade_music(on)


func _set_arcade_music(on: bool) -> void:
	_music_wanted = on
''')

rep('''func hud_hints(state: Dictionary) -> void:
	_hint_t = _time
''', '''func hud_hints(state: Dictionary) -> void:
	if _modern != null:
		_modern.hud_hints(state)
		return
	_hint_t = _time
''')

rep('''func set_vehicle(id: String) -> void:
	_vehicle_id = id
''', '''func set_vehicle(id: String) -> void:
	if _modern != null:
		_modern.set_vehicle(id)
		return
	_vehicle_id = id
''')

rep('''func engine_state() -> Dictionary:
	if _eng != null:
''', '''func engine_state() -> Dictionary:
	if _modern != null:
		return _modern.engine_state()
	if _eng != null:
''')

rep('''func engine_perf() -> Dictionary:
	if _eng == null or _eng.perf_calls == 0:
''', '''func engine_perf() -> Dictionary:
	if _modern != null:
		return _modern.engine_perf()
	if _eng == null or _eng.perf_calls == 0:
''')

rep('''func preview_engine(id: String) -> void:
	if not _preview_on or not sounds_ready:
''', '''func preview_engine(id: String) -> void:
	if _modern != null:
		_modern.preview_engine(id)
		return
	if not _preview_on or not sounds_ready:
''')

rep('''func _process(delta: float) -> void:
	_time += delta
	var paused := get_tree().paused
''', '''func _process(delta: float) -> void:
	_time += delta
	if _modern != null:
		return   # profile "modern": the Arcade sound was stopped by set_profile() and does not run
	var paused := get_tree().paused
''')

# --- contract §4.7.1 ----------------------------------------------------------------------------
rep('''# --- additions -----------------------------------------------------------------------------

''', '''# --- sound profiles (v0.8.0, contract §4.7.1) ------------------------------------------------

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
		_modern = ModernAudio.new()
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
		var music_on := _modern.music != null and _modern.music.wanted()
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

''')

open(P, "w", encoding="utf-8").write(s)
print("audio_manager.gd gepatcht")
