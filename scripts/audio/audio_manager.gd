extends Node
## Autoload "AudioManager": procedural sound (engine tied to speed with a virtual gearbox, wind,
## siren, crash, radar flash, fuel, countdown/UI blips, rain, menu music). Owner: UI/audio module.
## Public API = contract (ARCHITECTURE.md §11). All sounds are synthesised at startup (SfxSynth) as
## AudioStreamWAV – works with any audio driver incl. "Dummy". Nothing is generated in headless runs.
##
## Buses: Master / SFX / Music (created if missing), volumes from Settings (apply_volumes()).
## Additions to §11 (documented in docs/ui.md):
##   apply_volumes()       – re-read Settings.master/sfx/music_volume
##   set_music(on)         – menu music loop on the Music bus
##   hud_hints(state)      – called by the HUD each frame; derives rain, skid and siren distance
##                           when the race session does not set them explicitly (explicit calls win)
##   gear_for(speed, vmax) – virtual gearbox (static, delegates to SfxSynth.gear_for)
## Safety: loops fade out automatically when set_engine() is no longer called (scene left) and
## while the tree is paused; play() ignores the same one-shot requested twice within 45 ms.

const ONESHOT_DB := {
	"crash": -1.0, "flash": -3.0, "go": -4.0, "beep": -6.0, "finish": -3.0, "fuel_start": -5.0,
	"fuel_done": -4.0, "ui_move": -12.0, "ui_ok": -8.0, "ui_back": -9.0,
}
const LOOPS := ["engine_on", "engine_off", "wind", "rain", "siren", "skid"]

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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg: Dictionary = ConfigLoader.load_merged()
	_gears = int(ConfigLoader.lookup(cfg, "audio.engine_gears", 6))
	_idle_hz = float(ConfigLoader.lookup(cfg, "audio.engine_idle_hz", 38.0))
	_max_hz = float(ConfigLoader.lookup(cfg, "audio.engine_max_hz", 175.0))
	_ensure_buses()
	apply_volumes()
	if DisplayServer.get_name() == "headless":
		return
	_build_sounds()
	if bool(ConfigLoader.lookup(cfg, "audio.menu_music", true)):
		_music_thread_task = WorkerThreadPool.add_task(_generate_music, false, "menu music")


func _exit_tree() -> void:
	if _music_thread_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_thread_task)
		_music_thread_task = -1


func _ensure_buses() -> void:
	for bus_name in ["SFX", "Music"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


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
		p.bus = "SFX"
		p.volume_db = -80.0
		add_child(p)
		_loop_players[n] = p
		_vol[n] = 0.0
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


func _generate_music() -> void:
	_music_samples = SfxSynth.music_loop()
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
	if _music_wanted:
		_music.play()


# --- public API (ARCHITECTURE.md §11) ----------------------------------------------------------

## Engine sound: speed (km/h), throttle 0..1, current vmax, active = engine running.
func set_engine(speed_kmh: float, throttle: float, vmax_kmh: float, active: bool) -> void:
	_engine_speed = maxf(speed_kmh, 0.0)
	_engine_throttle = clampf(throttle, 0.0, 1.0)
	_engine_vmax = maxf(vmax_kmh, 60.0)
	_engine_active = active
	_engine_t = _time


func set_wind(speed_kmh: float) -> void:
	_wind_speed = maxf(speed_kmh, 0.0)


## Police siren on/off; distance01 = 1 close … 0 far.
func set_siren(on: bool, distance01: float) -> void:
	_siren_on = on
	_siren_dist = clampf(distance01, 0.0, 1.0)


func set_rain(intensity: float) -> void:
	_rain_explicit = clampf(intensity, 0.0, 1.0)
	_rain_explicit_t = _time


func set_skid(amount01: float) -> void:
	_skid_explicit = clampf(amount01, 0.0, 1.0)
	_skid_explicit_t = _time


## One-shot effects: "crash", "flash", "go", "beep", "finish", "fuel_start", "fuel_done", "ui_move",
## "ui_ok", "ui_back".
func play(sound_name: String) -> void:
	if not sounds_ready or not _streams.has(sound_name) or _oneshots.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(sound_name, -100000)) < 45:
		return
	_last_play[sound_name] = now
	var p := _oneshots[_next_oneshot]
	_next_oneshot = (_next_oneshot + 1) % _oneshots.size()
	p.stream = _streams[sound_name]
	p.volume_db = float(ONESHOT_DB.get(sound_name, -4.0))
	p.play()


func stop_all() -> void:
	for n in _loop_players:
		(_loop_players[n] as AudioStreamPlayer).stop()
		_vol[n] = 0.0
	for p in _oneshots:
		p.stop()
	_engine_t = -100.0
	_siren_on = false
	_wind_speed = 0.0
	_rain_explicit = 0.0
	_skid_explicit = 0.0
	_hint_t = -100.0


# --- additions -----------------------------------------------------------------------------

## Menu music on/off (Music bus).
func set_music(on: bool) -> void:
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


## Virtual gearbox: gear (1..gears) and rpm fraction (0..1 within the gear) – see SfxSynth.gear_for.
static func gear_for(speed_kmh: float, vmax_kmh: float, gears: int = 6) -> Vector2:
	return SfxSynth.gear_for(speed_kmh, vmax_kmh, gears)


func _process(delta: float) -> void:
	_time += delta
	if not sounds_ready:
		return
	var paused := get_tree().paused
	var alive := (_time - _engine_t) < 0.35 and not paused
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
	if alive:
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
	# siren
	var siren := 0.0
	if _siren_on and (alive or hints):
		var d := _hint_siren if (hints and _hint_siren >= 0.0) else _siren_dist
		siren = lerpf(0.18, 0.8, d)
		if hints and not _hint_chase:
			siren = 0.0
	_loop("siren", siren, 1.0, k_slow)


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
