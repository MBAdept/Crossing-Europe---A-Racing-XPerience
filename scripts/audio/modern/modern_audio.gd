class_name ModernAudio
extends Node
## The sound profile "Modern" (contract D25, §4.7; docs/audio-modern.md). A second, self-contained sound next to the
## Arcade one: the AudioManager keeps its API and hands every call to this node while the profile is "modern"
## (AudioManager.set_profile builds it and frees it again). Arcade classes, files and buses are not changed by
## anything here – Modern only reads some of them (the SfxSynth streams, cycle banks and traffic sounds the
## AudioManager has loaded) while its own sounds do not exist yet.
##
## What this node does itself:
##   • owns the parts: buses (ModernBuses), mix plan (ModernMix), sound files (ModernAudioAssets), the track feed
##     (AudioFeed) and one object per slot (SLOTS) – created in start(), freed in shutdown();
##   • collects the API calls of a frame with the Arcade semantics (calls while the tree is paused or in the frame of
##     stop_all() are ignored; a session that stops calling counts as gone after ALIVE_S; explicit rain / skid win
##     over the HUD hints for a second) into one ModernAudioFrame and hands it to every slot, in SLOTS order;
##   • one-shots: play(name) goes to the first slot that takes it. A play() and the session event of the same
##     moment (PLAY_EVENTS) never sound twice: when a slot claims the event, the play() is dropped if the event
##     came within DEDUP_MS, or held that long for it – and played if no event comes;
##   • mix: feeds ModernMix the level of the car bus, holds the snapshots (pause while the tree is paused, siren
##     during a chase, result from "stage_finish" until the stage is left, impact on a collision) and writes
##     fader gains, low-passes and the music EQ to the buses;
##   • effects off: MSfx is muted when the volume "Effekte" is 0 and whenever the Arcade bus SFX is muted – that
##     is how the attract demo (and --mute-bus=SFX) silences the effects, without knowing the profile.
## Nothing here reads the graphics mode or the renderer (Rule 4), and nothing feeds back into the simulation
## (Rule 3): the feed only reads the track at and behind the car.
##
## Tests: start() and step() work without a scene tree (no players then); `force_live` plays also in headless
## runs; `clock_ms` replaces the wall clock of the one-shot timing.

const ALIVE_S := 0.35            ## the session counts as gone when it did not call for this long (as Arcade)
const DEDUP_MS := 50             ## a play() and its event within this time are one sound (contract §4.7.2)
const REPEAT_MS := 45            ## the same one-shot twice within this time is ignored (as Arcade)
## Slots in update order (and in the order they are asked for a one-shot): name -> class is fixed in start().
const SLOTS: Array[String] = ["env", "engine", "layers", "road", "impact", "ambience", "traffic", "music", "sfx"]
## AudioManager.play() name -> the session event of the same moment (contract §4.7.2).
const PLAY_EVENTS := {"crash": "collision", "rail": "rail_hit", "flash": "radar_flash", "go": "go", "beep": "countdown",
	"finish": "stage_finish", "fuel_start": "refuel_start", "fuel_done": "refuel_done"}
const ARCADE_SFX_BUS := "SFX"

## Tests: build players and play although the run is headless.
static var force_live := false

var ctx: ModernAudioContext = null
var buses: ModernBuses = null
var mix: ModernMix = null
var assets: ModernAudioAssets = null
var feed: AudioFeed = null
var frame: ModernAudioFrame = null
var env: EnvAcoustics = null
var engine: EngineAudio3 = null
var layers: VehicleLayers = null
var road: RoadAudio = null
var impact: ImpactAudio = null
var ambience: AmbienceAudio = null
var traffic: TrafficExtras = null
var music: MusicDirector = null
var sfx: SfxBank = null
var modules: Array[ModernAudioModule] = []
var started := false

## Tests: wall clock in ms for the one-shot timing (−1 = Time.get_ticks_msec()).
var clock_ms := -1
## Tests / headless: level of the key bus used instead of its meter while nothing plays (dBFS).
var key_db_override := ModernMix.KEY_FLOOR_DB
var plays: Dictionary = {}       ## one-shot name -> times it reached a slot
var dropped: Dictionary = {}     ## one-shot name -> times it was dropped for its event
var events_seen: Dictionary = {} ## event name -> count (session and feed events)

var _time := 0.0
var _paused := false
var _engine_speed := 0.0
var _engine_throttle := 0.0
var _engine_vmax := 250.0
var _engine_active := false
var _engine_t := -100.0
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
var _vehicles: Array = []
var _listener: Dictionary = {}
var _traffic_t := -100.0
var _tunnel := false
var _state: Dictionary = {}
var _state_t := -100.0
var _stopped_frame := -1
var _result := false
var _music_context := "off"
var _last_play: Dictionary = {}
var _event_ms: Dictionary = {}
var _pending: Dictionary = {}    ## one-shot name -> [ms, gain_db]
var _claimed: Dictionary = {}    ## event name -> true
var _sfx_volume := 1.0
var _music_volume := 0.7


func _init() -> void:
	name = "ModernAudio"
	process_mode = Node.PROCESS_MODE_ALWAYS


# --- life cycle -----------------------------------------------------------------------------------

## Builds the profile: buses, mix, sound files, feed and every slot. cfg = the game configuration; opts (all
## optional): "streams" (AudioManager's streams by name), "arcade_traffic" (its TrafficAudio), "bank_provider"
## (Callable id -> EngineBank), "live" (create players; default: not headless), "sync" (no mixer thread), "quiet"
## (no start line in the log).
func start(cfg: Dictionary, opts: Dictionary = {}) -> void:
	if started:
		return
	started = true
	var modern: Variant = ConfigLoader.lookup(cfg, "audio.modern", {})
	ctx = ModernAudioContext.new()
	ctx.cfg = cfg
	ctx.modern = modern if modern is Dictionary else {}
	ctx.host = self
	ctx.live = bool(opts.get("live", DisplayServer.get_name() != "headless" or force_live))
	ctx.sync = bool(opts.get("sync", CliArgs.has("audio-sync") or not bool(ctx.value("engine_thread", true))))
	var streams: Variant = opts.get("streams", {})
	ctx.fallback_streams = streams if streams is Dictionary else {}
	var at: Variant = opts.get("arcade_traffic", null)
	ctx.arcade_traffic = at as TrafficAudio if at is TrafficAudio else null
	var bp: Variant = opts.get("bank_provider", Callable())
	ctx.bank_provider = bp if bp is Callable else Callable()
	buses = ModernBuses.new()
	buses.build(ctx.modern)
	ctx.buses = buses
	for bus_name in CliArgs.get_string("mute-bus", "").split(",", false):
		if ModernBuses.names().has(bus_name):
			buses.set_mute(bus_name, true)
	mix = ModernMix.new()
	mix.setup(ctx.modern)
	ctx.mix = mix
	assets = ModernAudioAssets.new()
	assets.use_placeholders = bool(ctx.value("placeholders", false))
	assets.load_all(str(ctx.value("assets_dir", ModernAudioAssets.ROOT)))
	for e in assets.errors:
		push_error("Modern-Klänge: %s" % e)
	ctx.assets = assets
	feed = AudioFeed.new()
	feed.setup(ctx.modern)
	frame = ModernAudioFrame.new()
	frame.feed = feed
	frame.live = ctx.live
	env = EnvAcoustics.new()
	engine = EngineAudio3.new()
	layers = VehicleLayers.new()
	road = RoadAudio.new()
	impact = ImpactAudio.new()
	ambience = AmbienceAudio.new()
	traffic = TrafficExtras.new()
	music = MusicDirector.new()
	sfx = SfxBank.new()
	modules = [env, engine, layers, road, impact, ambience, traffic, music, sfx]
	_claimed.clear()
	for m in modules:
		m.setup(ctx)
		for ev in m.claims():
			_claimed[ev] = true
	apply_volumes(_sfx_volume, _music_volume)
	if not bool(opts.get("quiet", false)):
		print("ModernAudio: Profil „Modern“ gestartet (%d Busse, %d Klangdateien%s%s)" % [ModernBuses.names().size(),
			assets.all_entries().size(), ", mit Platzhaltern" if assets.use_placeholders else "", "" if ctx.live else ", stumm"])


## Ends the profile: every slot stops and frees its players, the buses are removed. The node itself is freed by
## its owner.
func shutdown() -> void:
	if not started:
		return
	started = false
	for m in modules:
		m.teardown()
	modules.clear()
	env = null
	engine = null
	layers = null
	road = null
	impact = null
	ambience = null
	traffic = null
	music = null
	sfx = null
	if assets != null:
		assets.release()
	if buses != null:
		buses.remove()
	_pending.clear()


func _exit_tree() -> void:
	shutdown()


func _process(delta: float) -> void:
	if started:
		step(delta, get_tree().paused)


# --- AudioManager API (delegated) -----------------------------------------------------------------

func set_engine(speed_kmh: float, throttle: float, vmax_kmh: float, active: bool) -> void:
	if _is_paused() or Engine.get_process_frames() == _stopped_frame:
		return
	_engine_speed = maxf(speed_kmh, 0.0)
	_engine_throttle = clampf(throttle, 0.0, 1.0)
	_engine_vmax = maxf(vmax_kmh, 60.0)
	_engine_active = active
	_engine_t = _time


func set_wind(speed_kmh: float) -> void:
	_wind_speed = maxf(speed_kmh, 0.0)


func set_siren(on: bool, distance01: float) -> void:
	_siren_on = on
	_siren_dist = clampf(distance01, 0.0, 1.0)


func set_rain(intensity: float) -> void:
	_rain_explicit = clampf(intensity, 0.0, 1.0)
	_rain_explicit_t = _time


func set_skid(amount01: float) -> void:
	_skid_explicit = clampf(amount01, 0.0, 1.0)
	_skid_explicit_t = _time


## One-shot by its AudioManager name (or "<folder>/<id>" of a Modern one-shot).
func play(sound_name: String, gain_db: float = 0.0) -> void:
	if not started:
		return
	var now := _now_ms()
	if now - int(_last_play.get(sound_name, -100000)) < REPEAT_MS:
		return
	_last_play[sound_name] = now
	var ev := str(PLAY_EVENTS.get(sound_name, ""))
	if ev != "" and _claimed.has(ev):
		if now - int(_event_ms.get(ev, -100000)) <= DEDUP_MS:
			dropped[sound_name] = int(dropped.get(sound_name, 0)) + 1
			return                      # its event already made the sound
		_pending[sound_name] = [now, gain_db]
		return
	_play_now(sound_name, gain_db)


func stop_all() -> void:
	_stopped_frame = Engine.get_process_frames()
	_engine_t = -100.0
	_siren_on = false
	_wind_speed = 0.0
	_rain_explicit = 0.0
	_skid_explicit = 0.0
	_hint_t = -100.0
	_traffic_t = -100.0
	_vehicles = []
	_tunnel = false
	_state = {}
	_state_t = -100.0
	_result = false
	_pending.clear()
	for m in modules:
		m.stop_all()


func set_traffic(vehicles: Array, listener: Dictionary) -> void:
	if _is_paused() or Engine.get_process_frames() == _stopped_frame:
		return
	_vehicles = vehicles
	_listener = listener
	_traffic_t = _time


func set_environment(env_state: Dictionary) -> void:
	if Engine.get_process_frames() == _stopped_frame:
		return
	_tunnel = bool(env_state.get("tunnel", false))


## The existing menu-music switch (see MusicDirector).
func set_music(on: bool) -> void:
	if music != null:
		music.set_legacy(on)
		_music_context = music.context


func hud_hints(state: Dictionary) -> void:
	_hint_t = _time
	var w := str(state.get("weather", "normal"))
	_hint_rain = 1.0 if (w == "rain" and not bool(state.get("in_tunnel", false))) else 0.0
	_hint_skid = clampf(float(state.get("understeer", 0.0)), 0.0, 1.0)
	var ps := str(state.get("police_state", "none"))
	_hint_chase = ps == "chase" or ps == "stopping"
	_hint_siren = clampf(1.0 - float(state.get("police_gap_m", 300.0)) / 420.0, 0.15, 1.0) if _hint_chase else -1.0


func set_vehicle(id: String) -> void:
	_stopped_frame = -1
	if feed != null:
		feed.set_vehicle_width(float(ConfigLoader.lookup(ctx.cfg, "vehicles.types.%s.width_m" % id, 1.85)))
	for m in modules:
		m.set_vehicle(id)


func engine_state() -> Dictionary:
	return engine.state() if engine != null else {"rpm": 0.0, "gear": 0, "load": 0.0, "boost": 0.0}


func engine_perf() -> Dictionary:
	return engine.perf() if engine != null else {"avg_ms": 0.0, "max_ms": 0.0, "frames": 0, "samples": 0, "skips": 0}


func preview_engine(id: String) -> void:
	if engine != null:
		engine.preview(id)


func traffic_state() -> Dictionary:
	if traffic == null:
		return {}
	var s := traffic.state()
	s["tunnel_blend"] = env.blend() if env != null else 0.0
	return s


func traffic_perf() -> Dictionary:
	return traffic.perf() if traffic != null else {"avg_ms": 0.0, "max_ms": 0.0, "frames": 0, "apply_avg_ms": 0.0, "apply_max_ms": 0.0}


## Volume settings 0..1 "Effekte" and "Musik" on MSfx and MMusic, with the levels of the plan on every bus.
## ("Gesamtlautstärke" is on Master – AudioManager.apply_volumes.)
func apply_volumes(sfx_volume: float, music_volume: float) -> void:
	_sfx_volume = sfx_volume
	_music_volume = music_volume
	if mix == null or buses == null:
		return
	mix.set_volumes(sfx_volume, music_volume)
	for bus: String in mix.levels:
		if bus == "MSfx":
			buses.set_static_db(bus, mix.static_db(bus), mix.static_mute(bus) or mix.effects_muted)
		else:
			buses.set_static_db(bus, mix.static_db(bus), mix.static_mute(bus))


# --- contract §4.7.1 ------------------------------------------------------------------------------

func set_race_music(on: bool) -> void:
	if music != null:
		music.set_race_music(on)


func set_music_context(context: String, args: Dictionary = {}) -> void:
	if music != null:
		music.set_context(context, args)
		_music_context = music.context


## The race session after building its track; (null, null) when the stage is over.
func set_track(track: Object, plan: Object) -> void:
	if feed == null:
		return
	feed.set_track(track, plan)
	_result = false
	for m in modules:
		m.track_changed(feed)


## The car's state, every frame of a running stage (keys: contract §4.7.2).
func set_vehicle_state(state: Dictionary) -> void:
	if _is_paused() or Engine.get_process_frames() == _stopped_frame:
		return
	_state = state
	_state_t = _time


## A session event (contract §4.7.2).
func event(event_name: String, args: Dictionary = {}) -> void:
	if not started:
		return
	_event_ms[event_name] = _now_ms()
	for sound: String in PLAY_EVENTS:
		if PLAY_EVENTS[sound] == event_name and _pending.has(sound):
			_pending.erase(sound)
			dropped[sound] = int(dropped.get(sound, 0)) + 1
	match event_name:
		"collision":
			mix.trigger("impact")
		"stage_start":
			_result = false
		"stage_finish":
			_result = true
	_dispatch(event_name, args)


# --- the frame ------------------------------------------------------------------------------------

## One frame (called by _process; tests call it directly).
func step(delta: float, paused: bool) -> void:
	if not started or delta <= 0.0:
		return
	_time += delta
	_paused = paused
	var f := frame
	f.dt = delta
	f.time = _time
	f.paused = paused
	f.live = ctx.live
	f.alive = (_time - _engine_t) < ALIVE_S and not paused
	f.speed = _engine_speed
	f.throttle = _engine_throttle
	f.vmax = _engine_vmax
	f.active = _engine_active
	f.wind_speed = _wind_speed
	var hints := (_time - _hint_t) < 0.5 and not paused
	f.rain = _rain_explicit if (_time - _rain_explicit_t) < 1.0 else (_hint_rain if hints else 0.0)
	f.skid = _skid_explicit if (_time - _skid_explicit_t) < 1.0 else (_hint_skid if hints else 0.0)
	var siren := 0.0
	if _siren_on and (f.alive or hints):
		siren = lerpf(0.18, 0.8, _hint_siren if (hints and _hint_siren >= 0.0) else _siren_dist)
		if hints and not _hint_chase:
			siren = 0.0
	f.siren_level = siren
	f.siren_on = siren > 0.0
	f.traffic_alive = (_time - _traffic_t) < ALIVE_S and not paused
	f.vehicles = _vehicles if f.traffic_alive else []
	f.listener = _listener
	f.tunnel = _tunnel
	f.has_state = (_time - _state_t) < ALIVE_S and not paused and not _state.is_empty()
	f.state = _state if f.has_state else {}
	f.music_context = _music_context
	if f.has_state:
		feed.update(f.state)
		for e in feed.events:
			_dispatch(str(e.get("name", "")), e)
	else:
		feed.valid = false
		feed.events.clear()
	# one-shots that waited for their event in vain
	if not _pending.is_empty():
		var now := _now_ms()
		for sound: String in _pending.keys():
			var p: Array = _pending[sound]
			if now - int(p[0]) > DEDUP_MS:
				_pending.erase(sound)
				_play_now(sound, float(p[1]))
	# mix
	var mute_request := mix.static_mute("MSfx") or _arcade_effects_muted()
	mix.set_active("pause", paused)
	mix.set_active("siren", f.siren_on)
	mix.set_active("result", _result)
	mix.step(delta, _key_db(), mute_request, buses.peak_db("MEnv") if ctx.live else ModernMix.KEY_FLOOR_DB)
	f.effects_muted = mix.effects_muted
	# slots
	for m in modules:
		m.update(f)
		if m == engine:
			f.engine = engine.state()
	_apply_mix()


func _apply_mix() -> void:
	for bus in ModernBuses.FADER_BUSES:
		buses.set_gain_db(bus, mix.gain_db(bus))
	for bus in ModernBuses.LOWPASS_BUSES:
		buses.set_lowpass_hz(bus, mix.lowpass_hz(bus))
	buses.set_music_eq(_music_context == "race")
	buses.set_mute("MSfx", mix.effects_muted)


func _key_db() -> float:
	if ctx.live and key_db_override <= ModernMix.KEY_FLOOR_DB:
		return buses.peak_db(mix.duck_key)
	return key_db_override


## The Arcade effects bus is muted: volume "Effekte" 0, the attract demo, --mute-bus=SFX.
func _arcade_effects_muted() -> bool:
	var idx := AudioServer.get_bus_index(ARCADE_SFX_BUS)
	return idx >= 0 and AudioServer.is_bus_mute(idx)


func _is_paused() -> bool:
	return get_tree().paused if is_inside_tree() else _paused


func _now_ms() -> int:
	return clock_ms if clock_ms >= 0 else Time.get_ticks_msec()


func _play_now(sound: String, gain_db: float) -> void:
	if sound == "crash":
		mix.trigger("impact")
	for m in modules:
		if m.play(sound, gain_db):
			plays[sound] = int(plays.get(sound, 0)) + 1
			return


func _dispatch(event_name: String, args: Dictionary) -> void:
	if event_name == "":
		return
	events_seen[event_name] = int(events_seen.get(event_name, 0)) + 1
	for m in modules:
		m.event(event_name, args)


# --- debug ----------------------------------------------------------------------------------------

## Plain data of the whole profile for tests and debugging.
func debug_state() -> Dictionary:
	if not started:
		return {"started": false}
	var slots := {}
	for i in modules.size():
		slots[SLOTS[i]] = modules[i].debug_state()
	return {"started": true, "live": ctx.live, "sync": ctx.sync, "time": _time, "alive": frame.alive,
		"paused": frame.paused, "rain": frame.rain, "skid": frame.skid, "siren": frame.siren_level,
		"tunnel": frame.tunnel, "has_state": frame.has_state, "mix": mix.state(), "feed": feed.state(),
		"slots": slots, "plays": plays.duplicate(), "dropped": dropped.duplicate(), "events": events_seen.duplicate(),
		"music_context": _music_context, "placeholders": assets.use_placeholders,
		"asset_errors": assets.errors.duplicate(), "bus_problems": buses.verify()}
