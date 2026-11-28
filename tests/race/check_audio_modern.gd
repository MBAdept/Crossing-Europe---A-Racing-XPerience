extends SceneTree
## render-check-timeout: 3600
## render-check-godot: --write-movie {tmp}/check_audio_modern.avi --resolution 320x180
## Movie-Maker scenarios of the Modern sound in the real race scene (package AU-E, contract wave 7; loudness plan of
## docs/audio-modern.md §6, results in §17). Movie Maker mixes the sound in the main thread, exactly mix_rate/fps frames
## per picture, so every run records the same samples: the checks are exact, not statistical. Needs a real renderer
## (Movie Maker does not run with the headless display server – Godot 4.7.2 aborts) and the engine mixer on the main
## thread (--audio-sync). The sound does not read the renderer (contract Rule 4), so the cheap Arcade picture drives
## the Modern sound (--graphics=arcade --sound=modern):
##   xvfb-run -a -s "-screen 0 640x360x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##       --resolution 320x180 --fixed-fps 60 --write-movie /tmp/x.avi -s res://tests/race/check_audio_modern.gd -- \
##       --graphics=arcade --sound=modern --audio-sync [--only=vollgas,ducking,…] [--cars=kompakt,…] [--out=/abs/dir]
## or simply `tools/run_render_checks.sh audio`.
## Scenarios (each prints "AUDIO-CHECK <name> OK|FEHLER <values>"; at the end "AUDIO-CHECKS OK|FEHLER"):
##   vollgas_<car>     Kiel – Hamburg km 30, standing 3 s, then full throttle through the gears for 16 s, no music:
##                     integrated loudness of the full-throttle part −16 ± 1.5 LUFS (plan "Vollgas"); then held at
##                     the car's top speed for TOP_S: audio.modern.loudness.top_speed_lufs ± top_speed_tol_db (plan
##                     "Höchsttempo", −15 ± 1); reported: short-term max/median, idle. Small speaker (Deck): the same sound through a 4th-order
##                     high-pass at 180 Hz – full throttle loses at most SPEAKER_MAX_LOSS_DB, idle stays above
##                     SPEAKER_IDLE_MIN_LUFS.
##   ducking           race music on: idle 6 s, full throttle 8 s, off the throttle 5 s, braking to a standstill and
##                     idle: the music (measured before and after the fader of MMusic) is ≥ 3 dB lower under full
##                     throttle, comes back to within 1 dB of no ducking within RECOVER_S of the car idling, and lies
##                     ≥ MUSIC_UNDER_MIN_DB under the whole mix at full throttle (plan: 8 dB).
##   vorbeifahrt_links / _rechts   a car in the neighbour lane is passed at 150 against 105 km/h: the traffic group
##                     (MWorld) is ≥ PASS_SIDE_DB louder on that side before and after the pass, its pitch falls
##                     through the pass (spectrum ratio after/before between DOPPLER_MIN and DOPPLER_MAX; with the
##                     game's doubled Doppler audio.traffic_doppler = 2 at this closing speed about 0.87, physical 0.93).
##   tunnelhall        a short noise burst through MWorld with the car standing (its group muted), measured after
##                     MEnv: reverberation time (T20) in the Elbtunnel between TUNNEL_RT_MIN and TUNNEL_RT_MAX, in the
##                     open at most OPEN_RT_MAX.
##   tunnel_lautheit   Gran Turismo at a steady 120 km/h into the Gotthard road tunnel, no music, no traffic: the
##                     whole mix (short-term median) inside is TUNNEL_LIFT_MIN_DB … TUNNEL_LIFT_MAX_DB louder than on
##                     the open road before the portal – the tunnel must be heard, but not drive the limiter.
##   schlimmster_fall  Gotthard road tunnel, Gran Turismo at 230 km/h, two trucks beside, the police 12 m behind with the siren,
##                     race music, a heavy crash into a truck, the tunnel wall with scraping, a second crash: true
##                     peak at the output ≤ −0.5 dBTP even at "Gesamtlautstärke" 1.0 (the Master fader is a plain
##                     gain after every limiter, so the signal before it is the 1.0 case), no sample at full scale.
## With --out=<abs dir> every scenario is also written as <name>.wav (16 bit, the signal at the output with the
## Master fader of the settings) and the values as results.json – the listening files of the AU-E report.
## The scene is accessed untyped (this script compiles before the autoloads the scene uses).

const Meter := preload("res://tests/race/audio_meter.gd")

const CARS: Array[String] = ["kompakt", "kombi", "limousine", "sportwagen", "gran_turismo"]
const FULL_THROTTLE_LUFS := -16.0
const FULL_THROTTLE_TOL_DB := 1.5
const TOP_S := 6.0                ## seconds at top speed after the full-throttle run
const SPEAKER_HZ := 180.0
const SPEAKER_MAX_LOSS_DB := 6.0
const SPEAKER_IDLE_MIN_LUFS := -40.0
const DUCK_MIN_DB := 3.0
const RECOVER_S := 1.5
const RECOVER_DB := 1.0
const MUSIC_UNDER_MIN_DB := 5.0
const PASS_SIDE_DB := 3.0
const DOPPLER_MIN := 0.80
const DOPPLER_MAX := 0.97
const TUNNEL_RT_MIN := 0.8
const TUNNEL_RT_MAX := 3.5
const OPEN_RT_MAX := 0.5
const TUNNEL_LIFT_MIN_DB := 1.0
const TUNNEL_LIFT_MAX_DB := 4.0
const WORST_TP_DBTP := -0.5
const FULL_SCALE := 0.999


## Drives with the autopilot's steering (lane keeping, PD controller of the real car) and the scenario's pedals.
class Pilot extends Autopilot:
	var pedals_on := true      ## false: the autopilot's own pedals (target_kmh)
	var throttle := 0.0
	var brake := 0.0
	var lane := 1              ## the lane to hold (−1: the autopilot's choice)
	var steer_override := 0.0
	var steer_hold := false    ## true: steer_override instead of the lane

	func drive(session: Node) -> Dictionary:
		var out: Dictionary = super.drive(session)
		if pedals_on:
			out["throttle"] = throttle
			out["brake"] = brake
		var v: VehicleModel = session.vehicle
		if steer_hold:
			out["steer"] = steer_override
		elif lane >= 0:
			var track: Track = session.track
			out["steer"] = Autopilot.steer_to(v, track.lane_center_x(session.pos_z, lane), session.env.grip(session.weather))
		return out


var _sc: Node = null
var _pilot: Pilot = null
var _rate := 48000.0
var _caps: Dictionary = {}          ## name -> {"effect": AudioEffectCapture, "bus": String, "l", "r"}
var _frames := 0                    ## physics frames of the running scenario
var _results: Array = []
var _failed := 0
var _out := ""
var _master_gain := 1.0
var _on_physics: Callable = Callable()   ## per-frame control of the running scenario (before the session steps)
var _log: Array = []                ## per-frame values a scenario wants (e.g. distance of a car)
var _radars: Array = []             ## the radars of the running stage's plan (taken out while it runs)
var _radar_plan: Object = null
var _collisions_before := 0


func _initialize() -> void:
	_run.call_deferred()


func _physics_process(_delta: float) -> bool:
	if _sc != null and _sc.is_inside_tree():
		_frames += 1
		if _on_physics.is_valid():
			_on_physics.call(_frames)
	return false


func _process(_delta: float) -> bool:
	_pull()
	return false


func _am() -> Node:
	return root.get_node("AudioManager")


func _wants(scenario: String) -> bool:
	var only := CliArgs.get_string("only", "")
	if only == "":
		return true
	for o: String in only.split(",", false):
		if scenario.begins_with(o):
			return true
	return false


# --- recording ----------------------------------------------------------------------------------------------------

## Capture effect at the end of a bus (or before the effect of class `before`, e.g. the fader of MMusic).
func _add_capture(cap_name: String, bus: String, before: String = "") -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	var cap := AudioEffectCapture.new()
	cap.buffer_length = 0.5
	var at := -1
	if before != "":
		for j in AudioServer.get_bus_effect_count(idx):
			if AudioServer.get_bus_effect(idx, j).get_class() == before:
				at = j
	AudioServer.add_bus_effect(idx, cap, at)
	_caps[cap_name] = {"effect": cap, "bus": bus, "l": PackedFloat32Array(), "r": PackedFloat32Array()}


func _remove_captures() -> void:
	for cap_name: String in _caps:
		var c: Dictionary = _caps[cap_name]
		var idx := AudioServer.get_bus_index(str(c["bus"]))
		if idx < 0:
			continue
		for j in range(AudioServer.get_bus_effect_count(idx) - 1, -1, -1):
			if AudioServer.get_bus_effect(idx, j) == c["effect"]:
				AudioServer.remove_bus_effect(idx, j)
	_caps.clear()


func _pull() -> void:
	for cap_name: String in _caps:
		var c: Dictionary = _caps[cap_name]
		var cap: AudioEffectCapture = c["effect"]
		var n := cap.get_frames_available()
		if n <= 0:
			continue
		var buf := cap.get_buffer(n)
		var l: PackedFloat32Array = c["l"]
		var r: PackedFloat32Array = c["r"]
		var base := l.size()
		l.resize(base + n)
		r.resize(base + n)
		for i in n:
			l[base + i] = buf[i].x
			r[base + i] = buf[i].y


func _reset_recording() -> void:
	for cap_name: String in _caps:
		var c: Dictionary = _caps[cap_name]
		(c["effect"] as AudioEffectCapture).clear_buffer()
		c["l"] = PackedFloat32Array()
		c["r"] = PackedFloat32Array()


func _ch(cap_name: String, side: String) -> PackedFloat32Array:
	return (_caps[cap_name] as Dictionary)[side]


func _s(t: float) -> int:
	return int(round(t * _rate))


# --- scenes -------------------------------------------------------------------------------------------------------

func _start(stage: String, from: String, km: float, vehicle: String, opts: Dictionary = {}) -> void:
	var setup := {"mode": "single", "race_id": "", "stage_id": stage, "from_city": from, "vehicle": vehicle,
		"start_world_minutes": float(opts.get("hour", 12.0)) * 60.0, "weather": str(opts.get("weather", "normal")),
		"start_km": km, "autopilot": true, "no_countdown": true, "seed": 5, "autopilot_speeding": true}
	_sc = (load("res://scenes/race/race.tscn") as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)
	await process_frame
	await process_frame
	var traffic: Object = _sc.get("traffic")
	var empty: Array[String] = []
	traffic.set("car_sets", empty)
	traffic.set("heavy_sets", empty)
	(traffic.get("cars") as Array).clear()
	# no radar of the stage: a flash would start a chase, and its siren would sound through every scenario (the
	# worst case sets its own chase)
	var plan: Object = _sc.get("plan")
	_radars = (plan.get("radars") as Array).duplicate()
	_radar_plan = plan
	(plan.get("radars") as Array).clear()
	_pilot = Pilot.new()
	_pilot.obey_radar = false
	_pilot.refuel_mode = "never"
	_pilot.lane = int(opts.get("lane", 1))
	_sc.set("autopilot", _pilot)
	var veh: Object = _sc.get("vehicle")
	var track: Object = _sc.get("track")
	veh.set("x", float(track.call("lane_center_x", _sc.get("pos_z"), _pilot.lane)))
	_sc.set("cam_x", veh.get("x"))
	veh.set("speed", float(opts.get("kmh", 0.0)))
	_am().call("set_music_context", str(opts.get("music", "off")), {"stage_id": stage, "race_id": ""})
	_master_gain = db_to_linear(AudioServer.get_bus_volume_db(0))
	_frames = 0
	_log.clear()
	_reset_recording()


func _stop() -> void:
	_on_physics = Callable()
	_am().call("set_music_context", "off", {})
	if _sc != null:
		_sc.queue_free()
		_sc = null
	_pilot = null
	if _radar_plan != null:   # the plan is the GameData cache: give it its radars back
		var r: Array = _radar_plan.get("radars")
		r.clear()
		r.append_array(_radars)
		_radar_plan = null
	for i in 30:   # let the stage's sounds go (stop_all, tails) before the next one starts
		await process_frame


## Waits until the scenario has run `seconds` of game time from its start (physics frames).
func _until(seconds: float) -> void:
	var target := int(round(seconds * 60.0))
	while _frames < target:
		await process_frame
	await process_frame   # the audio of the last frame is mixed after it
	_pull()


func _car(id: int, kind: String, lane: int, gap_m: float, kmh: float) -> Object:
	var traffic: Object = _sc.get("traffic")
	var track: Object = _sc.get("track")
	var veh: Object = _sc.get("vehicle")
	var db: Node = root.get_node("SpriteDB")
	var set_id := "traffic/truck_white" if kind == "truck" else "traffic/sedan_blue"
	var dims: Dictionary = db.call("object_size", set_id)
	var c := TrafficSystem.Car.new()
	c.id = id
	c.set_id = set_id
	c.length = float(dims.get("length_m", 4.5))
	c.width = float(dims.get("width_m", 1.8))
	c.height = float(dims.get("height_m", 1.5))
	c.heavy = kind == "truck"
	c.z = float(_sc.get("pos_z")) + float(veh.get("length_m")) * 0.5 + gap_m + c.length * 0.5
	c.lane = lane
	c.x = float(track.call("lane_center_x", c.z, lane))
	c.speed = kmh
	c.cruise_speed = kmh
	c.lane_cooldown = 1.0e9
	(traffic.get("cars") as Array).append(c)
	return c


func _cam_z() -> float:
	return float(_sc.get("pos_z")) - float((_sc.get("proj") as Object).get("cam_distance"))


# --- verdicts -----------------------------------------------------------------------------------------------------

func _verdict(check_name: String, ok: bool, values: Dictionary, text: String) -> void:
	print("AUDIO-CHECK %-22s %s  %s" % [check_name, "OK    " if ok else "FEHLER", text])
	if not ok:
		_failed += 1
	values["name"] = check_name
	values["ok"] = ok
	_results.append(values)


func _write_wav(file_name: String, cap_name: String, gain: float) -> void:
	if _out == "":
		return
	var l := _ch(cap_name, "l")
	var r := _ch(cap_name, "r")
	var data := PackedByteArray()
	data.resize(l.size() * 4)
	for i in l.size():
		data.encode_s16(4 * i, clampi(int(round(l[i] * gain * 32767.0)), -32768, 32767))
		data.encode_s16(4 * i + 2, clampi(int(round(r[i] * gain * 32767.0)), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = true
	wav.mix_rate = int(_rate)
	wav.data = data
	wav.save_to_wav(_out.path_join(file_name + ".wav"))


# --- run ----------------------------------------------------------------------------------------------------------

func _run() -> void:
	_out = CliArgs.get_string("out", "")
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	if Engine.get_write_movie_path() == "":
		print("AUDIO-CHECK %-22s FEHLER  ohne Movie Maker (--write-movie <datei>.avi --fixed-fps 60) mischt der Ton nicht im Takt der Bilder" % "aufbau")
		print("AUDIO-CHECKS FEHLER  (1 fehlgeschlagen)")
		quit(1)
		return
	await process_frame
	if str(_am().call("profile")) != "modern":
		_am().call("set_profile", "modern")
		await process_frame
	var st: Dictionary = _am().get("_modern").call("debug_state")
	_rate = AudioServer.get_mix_rate()
	if not bool(st.get("sync", false)) or not bool(st.get("live", false)):
		_verdict("aufbau", false, {}, "Motor-Mischer im Hauptthread und Wiedergabe nötig (--audio-sync), Zustand sync %s live %s" % [st.get("sync"), st.get("live")])
	_add_capture("master", "Master")
	_add_capture("world", "MWorld")
	_add_capture("env", "MEnv")
	_add_capture("music_pre", "MMusic", "AudioEffectAmplify")
	_add_capture("music_post", "MMusic")
	_add_capture("pre_limiter", "MMaster", "AudioEffectHardLimiter")
	_add_capture("post_limiter", "MMaster")
	var cars: Array[String] = []
	for c: String in CliArgs.get_string("cars", ",".join(CARS)).split(",", false):
		cars.append(c)
	for car: String in cars:
		if _wants("vollgas_" + car):
			await _vollgas(car)
	if _wants("ducking"):
		await _ducking()
	if _wants("vorbeifahrt"):
		await _passby(0, "vorbeifahrt_links")
		await _passby(2, "vorbeifahrt_rechts")
	if _wants("tunnelhall"):
		await _tunnel_rt()
	if _wants("tunnel_lautheit"):
		await _tunnel_lift()
	if _wants("schlimmster_fall"):
		await _worst()
	_remove_captures()
	if _out != "":
		var f := FileAccess.open(_out.path_join("results.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify({"mix_rate": _rate, "master_gain": _master_gain, "results": _results}, "  "))
		f.close()
	print("AUDIO-CHECKS %s  (%d fehlgeschlagen, %d Szenarien)" % ["OK" if _failed == 0 else "FEHLER", _failed, _results.size()])
	quit(0 if _failed == 0 else 1)


## Full throttle through the gears from a standstill (Kiel – Hamburg km 30, open motorway, no music).
func _vollgas(car: String) -> void:
	await _start("kiel_hamburg", "kiel", 30.0, car)
	var t_go := 3.0
	var t_end := t_go + 16.0
	_on_physics = func(f: int) -> void:
		var t := f / 60.0
		_pilot.throttle = 1.0 if t >= t_go else 0.0
		_pilot.brake = 0.0 if t >= t_go else 1.0
		if t >= t_end:   # then held at the car's top speed, flat out (plan "Höchsttempo")
			var v: Object = _sc.get("vehicle")
			v.set("speed", float(v.get("vmax_effective")))
	await _until(t_end)
	var kmh := float((_sc.get("vehicle") as Object).get("speed"))
	await _until(t_end + TOP_S)
	var vmax := float((_sc.get("vehicle") as Object).get("speed"))
	await _stop()
	var g := _master_gain
	var l := _scaled(_ch("master", "l"), g)
	var r := _scaled(_ch("master", "r"), g)
	var c := Meter.power_sum(Meter.k_weight(l, _rate), Meter.k_weight(r, _rate))
	var ft := Meter.integrated(c, _rate, t_go + 1.0, t_end)
	var st := Meter.series(c, _rate, t_go + 1.0, t_end, 3.0, 0.1)
	var idle := Meter.integrated(c, _rate, 0.5, t_go)
	var hl := Meter.highpass4(l, _rate, SPEAKER_HZ)
	var hr := Meter.highpass4(r, _rate, SPEAKER_HZ)
	var ch := Meter.power_sum(Meter.k_weight(hl, _rate), Meter.k_weight(hr, _rate))
	var ft_hp := Meter.integrated(ch, _rate, t_go + 1.0, t_end)
	var idle_hp := Meter.integrated(ch, _rate, 0.5, t_go)
	var top := Meter.integrated(c, _rate, t_end + 1.0, t_end + TOP_S)
	var top_plan := float(ConfigLoader.lookup(ConfigLoader.load_merged(), "audio.modern.loudness.top_speed_lufs", -15.0))
	var top_tol := float(ConfigLoader.lookup(ConfigLoader.load_merged(), "audio.modern.loudness.top_speed_tol_db", 1.0))
	var ok_level := absf(ft - FULL_THROTTLE_LUFS) <= FULL_THROTTLE_TOL_DB and absf(top - top_plan) <= top_tol
	var ok_speaker := ft - ft_hp <= SPEAKER_MAX_LOSS_DB and idle_hp >= SPEAKER_IDLE_MIN_LUFS
	var values := {"full_throttle_lufs": ft, "short_term_max": Meter.max_of(st), "short_term_median": Meter.median_of(st),
		"idle_lufs": idle, "speaker_full_throttle_lufs": ft_hp, "speaker_idle_lufs": idle_hp, "end_kmh": kmh,
		"top_speed_lufs": top, "top_kmh": vmax}
	_write_wav("vollgas_" + car, "master", g)
	_verdict("vollgas_" + car, ok_level and ok_speaker, values,
		"Vollgas %.1f LUFS (Plan %.0f ± %.1f; Kurzzeit höchstens %.1f, Median %.1f), %.0f km/h nach 16 s; Höchsttempo %.0f km/h %.1f LUFS (Plan %.0f ± %.0f); Stand %.1f LUFS; kleiner Lautsprecher (Hochpass %.0f Hz): Vollgas %.1f LUFS (−%.1f dB, höchstens −%.0f), Stand %.1f LUFS (mindestens %.0f)" % [
			ft, FULL_THROTTLE_LUFS, FULL_THROTTLE_TOL_DB, values["short_term_max"], values["short_term_median"], kmh, vmax, top, top_plan, top_tol,
			idle, SPEAKER_HZ, ft_hp, ft - ft_hp, SPEAKER_MAX_LOSS_DB, idle_hp, SPEAKER_IDLE_MIN_LUFS])


static func _scaled(x: PackedFloat32Array, g: float) -> PackedFloat32Array:
	if is_equal_approx(g, 1.0):
		return x
	var y := PackedFloat32Array()
	y.resize(x.size())
	for i in x.size():
		y[i] = x[i] * g
	return y


## The music under the car: idle, full throttle, coasting, braking to a standstill, idle again.
func _ducking() -> void:
	await _start("kiel_hamburg", "kiel", 30.0, "gran_turismo", {"music": "race"})
	var t_ft := 6.0
	var t_off := 14.0
	var t_brake := 19.0
	var t_end := 30.0
	var stop_t := [-1.0]
	_on_physics = func(f: int) -> void:
		var t := f / 60.0
		var v := float((_sc.get("vehicle") as Object).get("speed"))
		_pilot.throttle = 1.0 if t >= t_ft and t < t_off else 0.0
		_pilot.brake = 1.0 if t < t_ft or t >= t_brake else 0.0
		if t >= t_brake and v < 0.5 and stop_t[0] < 0.0:
			stop_t[0] = t
	await _until(t_end)
	await _stop()
	var pre_c := _power("music_pre")
	var post_c := _power("music_post")
	var mc := Meter.power_sum(Meter.k_weight(_scaled(_ch("master", "l"), _master_gain), _rate),
		Meter.k_weight(_scaled(_ch("master", "r"), _master_gain), _rate))
	# the music's own fader level (bus volume: plan + "Musik" setting) is a constant after the capture
	var mus_gain_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("MMusic")) if AudioServer.get_bus_index("MMusic") >= 0 else 0.0
	var duck_ft := _duck(pre_c, post_c, t_ft + 1.5, t_off)
	var duck_idle := _duck(pre_c, post_c, 3.0, t_ft)
	var stopped := stop_t[0] as float
	var duck_after := _duck(pre_c, post_c, stopped + RECOVER_S, t_end) if stopped > 0.0 else -99.0
	# loudness of the music as it reaches the output: after its fader, its bus volume and the Master fader (the sum
	# compressor works on the whole mix and is left out – a few tenths at most)
	var music_ft := Meter.integrated(post_c, _rate, t_ft + 1.5, t_off) + mus_gain_db + linear_to_db(_master_gain)
	var mix_ft := Meter.integrated(mc, _rate, t_ft + 1.5, t_off)
	var music_level := Meter.integrated(pre_c, _rate, 3.0, t_end)
	var ok := duck_ft <= -DUCK_MIN_DB and absf(duck_idle) <= 0.5 and stopped > 0.0 and duck_after >= -RECOVER_DB \
		and mix_ft - music_ft >= MUSIC_UNDER_MIN_DB and music_level > -60.0
	_write_wav("ducking", "master", _master_gain)
	_verdict("ducking", ok, {"duck_full_throttle_db": duck_ft, "duck_idle_db": duck_idle, "duck_after_stop_db": duck_after,
		"stopped_s": stopped, "music_full_throttle_lufs": music_ft, "mix_full_throttle_lufs": mix_ft, "music_pre_lufs": music_level},
		"Musik unter Vollgas %.1f dB (mindestens −%.0f), im Stand %.1f dB, %.1f s nach dem Halt %.1f dB (höchstens −%.0f); Vollgas: Mischung %.1f LUFS, Musik %.1f LUFS (%.1f dB darunter, mindestens %.0f)" % [
			duck_ft, DUCK_MIN_DB, duck_idle, RECOVER_S, duck_after, RECOVER_DB, mix_ft, music_ft, mix_ft - music_ft, MUSIC_UNDER_MIN_DB])


## Gain reduction of the Modern limiter (end of MMaster) in 50-ms blocks: RMS before it minus after it, over blocks
## louder than −40 dBFS. Returns {"max_db", "share_1db", "share_3db"} (shares of the blocks).
func _limiter_gr(t0: float, t1: float) -> Dictionary:
	var pl := _ch("pre_limiter", "l")
	var pr := _ch("pre_limiter", "r")
	var ql := _ch("post_limiter", "l")
	var qr := _ch("post_limiter", "r")
	var w := _s(0.05)
	var n := 0
	var n1 := 0
	var n3 := 0
	var mx := 0.0
	var i := _s(t0)
	var end := mini(_s(t1), mini(pl.size(), ql.size()))
	while i + w <= end:
		var a := 0.5 * (Meter.rms_db(pl, i, i + w) + Meter.rms_db(pr, i, i + w))
		var b := 0.5 * (Meter.rms_db(ql, i, i + w) + Meter.rms_db(qr, i, i + w))
		if a > -40.0:
			var gr := a - b
			n += 1
			mx = maxf(mx, gr)
			if gr > 1.0:
				n1 += 1
			if gr > 3.0:
				n3 += 1
		i += w
	return {"max_db": mx, "share_1db": float(n1) / maxf(n, 1), "share_3db": float(n3) / maxf(n, 1)}


func _power(cap_name: String) -> PackedFloat64Array:
	return Meter.power_sum(Meter.k_weight(_ch(cap_name, "l"), _rate), Meter.k_weight(_ch(cap_name, "r"), _rate))


## Ducking (dB, negative = lower) of the music in [t0, t1): loudness after the fader minus before it.
func _duck(pre_c: PackedFloat64Array, post_c: PackedFloat64Array, t0: float, t1: float) -> float:
	var w := _s(t1) - _s(t0)
	return Meter.window_lufs(post_c, _s(t0), w) - Meter.window_lufs(pre_c, _s(t0), w)


## A car in the neighbour lane (0 = left, 2 = right) passed at 150 against 105 km/h.
func _passby(lane: int, check_name: String) -> void:
	await _start("kiel_hamburg", "kiel", 30.0, "limousine", {"kmh": 150.0, "lane": 1})
	_pilot.pedals_on = false
	_pilot.target_kmh = 150.0
	var car: Object = _car(9001, "car", lane, 28.0, 105.0)
	var rel: Array = []   # [t, car z − listener z] per frame
	_on_physics = func(f: int) -> void:
		(car as TrafficSystem.Car).speed = 105.0
		(_sc.get("vehicle") as Object).set("speed", 150.0)
		rel.append([f / 60.0, (car as TrafficSystem.Car).z - _cam_z()])
		if CliArgs.has("voice-trace"):
			var tm: Object = _am().get("_modern").get("traffic").get("model")
			var vs: Array = (tm.call("state") as Dictionary)["voices"]
			for v: Dictionary in vs:
				if int(v["vehicle"]) == 9001:
					print("TRACE %.3f dz %.2f pan %.3f dop %.4f dist %.2f gl %s gr %s pitch %s cut %.0f" % [f / 60.0, rel[-1][1], v["pan"], v["doppler"], v["distance"], str(v["left"]), str(v["right"]), str(v["pitch"]), v["cutoff"]])
	await _until(8.0)
	await _stop()
	var t_pass := -1.0
	for e: Array in rel:
		if float(e[1]) <= 0.0:
			t_pass = float(e[0])
			break
	var l := _ch("world", "l")
	var r := _ch("world", "r")
	var ok := t_pass > 2.0
	var bal_before := 0.0
	var bal_after := 0.0
	var ratio := {"ratio": 1.0, "steps": 0.0, "corr": 0.0}
	if ok:
		bal_before = Meter.balance_db(l, r, _s(t_pass - 1.5), _s(t_pass - 0.3))
		bal_after = Meter.balance_db(l, r, _s(t_pass + 0.3), _s(t_pass + 1.5))
		# 0.5-s windows 0.7 s before and after the pass (the car 9–15 m away, nearly along the road): long enough to
		# resolve the engine's low orders (around 60 Hz) – a 0.17-s window followed the loop's firing pattern, not
		# the pitch, and gave 1.09 on one side
		var n := _s(0.5)
		var spa := Meter.log_spectrum(l, r, _s(t_pass - 0.7) - n, n, _rate, 40.0, 1000.0, 48)
		var spb := Meter.log_spectrum(l, r, _s(t_pass + 0.7), n, _rate, 40.0, 1000.0, 48)
		ratio = Meter.spectrum_ratio(spa, spb, 48, 24)
	var side := -1.0 if lane == 0 else 1.0   # left: L over R positive
	var ok_side := ok and bal_before * -side >= PASS_SIDE_DB and bal_after * -side >= PASS_SIDE_DB
	var ok_doppler := ok and float(ratio["ratio"]) >= DOPPLER_MIN and float(ratio["ratio"]) <= DOPPLER_MAX
	_write_wav(check_name, "world", 1.0)
	_verdict(check_name, ok_side and ok_doppler, {"t_pass": t_pass, "balance_before_db": bal_before, "balance_after_db": bal_after,
		"doppler_ratio": ratio["ratio"], "doppler_corr": ratio["corr"]},
		"Vorbeifahrt bei %.2f s: links über rechts %.1f dB vorher, %.1f dB nachher (mindestens %.0f dB auf der Seite des Autos); Tonhöhe nachher/vorher %.3f (%.2f Halbtöne, Band %.2f–%.3f, Korrelation %.2f)" % [
			t_pass, bal_before, bal_after, PASS_SIDE_DB, float(ratio["ratio"]), 12.0 * log(float(ratio["ratio"])) / log(2.0), DOPPLER_MIN, DOPPLER_MAX, float(ratio["corr"])])


## Reverberation of the tunnel and of the open road: a noise burst through MWorld, the car standing, its group muted.
func _tunnel_rt() -> void:
	var rts := {}
	for place: String in ["tunnel", "open"]:
		if place == "tunnel":
			var plan: StagePlan = root.get_node("GameData").call("get_stage_plan", "hamburg_hannover", "hamburg")
			var t: Dictionary = plan.tunnels[0]
			await _start("hamburg_hannover", "hamburg", float(t.get("start_km", 5.0)) + 0.4, "limousine")
		else:
			await _start("kiel_hamburg", "kiel", 30.0, "limousine")
		_pilot.brake = 1.0
		var car_bus := AudioServer.get_bus_index("MCar")
		AudioServer.set_bus_mute(car_bus, true)
		var p := AudioStreamPlayer.new()
		p.bus = "MWorld"
		p.stream = _burst()
		_sc.add_child(p)
		var t_burst := 3.0
		_on_physics = func(f: int) -> void:
			if f == int(t_burst * 60.0):
				p.play()
		await _until(t_burst + 3.5)
		var tunnel_now := bool(_am().get("_modern").call("debug_state").get("tunnel", false))
		await _stop()
		AudioServer.set_bus_mute(car_bus, false)
		var l := _ch("env", "l")
		var r := _ch("env", "r")
		# the burst starts within the frame after t_burst: begin the curve at the largest sample there
		var i0 := _s(t_burst)
		var best := i0
		for i in range(i0, mini(i0 + _s(0.1), l.size())):
			if absf(l[i]) + absf(r[i]) > absf(l[best]) + absf(r[best]):
				best = i
		var curve := Meter.schroeder_db(l, r, best, _s(3.0), _rate)
		rts[place] = {"rt60": Meter.rt60(curve), "tunnel_flag": tunnel_now}
		_write_wav("tunnelhall_" + place, "env", 1.0)
	var rt_t := float((rts["tunnel"] as Dictionary)["rt60"])
	var rt_o := float((rts["open"] as Dictionary)["rt60"])
	var ok := bool((rts["tunnel"] as Dictionary)["tunnel_flag"]) and rt_t >= TUNNEL_RT_MIN and rt_t <= TUNNEL_RT_MAX and rt_o <= OPEN_RT_MAX
	_verdict("tunnelhall", ok, {"tunnel_rt60_s": rt_t, "open_rt60_s": rt_o},
		"Nachhallzeit (T20) im Elbtunnel %.2f s (Band %.1f–%.1f s), auf freier Strecke %.2f s (höchstens %.1f s)" % [rt_t, TUNNEL_RT_MIN, TUNNEL_RT_MAX, rt_o, OPEN_RT_MAX])


## The same steady drive before and in the Gotthard road tunnel: how much louder the tunnel makes the whole mix.
func _tunnel_lift() -> void:
	var plan: StagePlan = root.get_node("GameData").call("get_stage_plan", "bern_mailand", "bern")
	var tun: Dictionary = {}
	for t: Dictionary in plan.tunnels:
		if float(t["end_km"]) - float(t["start_km"]) > float(tun.get("end_km", 0.0)) - float(tun.get("start_km", 0.0)):
			tun = t
	var t0_km := float(tun.get("start_km", 5.0)) - 1.8
	await _start("bern_mailand", "bern", t0_km, "gran_turismo", {"kmh": 120.0, "lane": 1})
	_pilot.pedals_on = false
	_pilot.target_kmh = 120.0
	var enter := [-1.0]
	_on_physics = func(f: int) -> void:
		if enter[0] < 0.0 and bool(_am().get("_modern").get("frame").get("tunnel")):
			enter[0] = f / 60.0
	await _until(16.0)
	await _stop()
	var t_in := float(enter[0])
	var c := Meter.power_sum(Meter.k_weight(_scaled(_ch("master", "l"), _master_gain), _rate),
		Meter.k_weight(_scaled(_ch("master", "r"), _master_gain), _rate))
	var ok := t_in > 4.5
	var out_st := Meter.series(c, _rate, 0.5, t_in - 0.3, 3.0, 0.1) if ok else PackedFloat32Array([-70.0])
	var in_st := Meter.series(c, _rate, t_in + 1.5, 16.0, 3.0, 0.1) if ok else PackedFloat32Array([-70.0])
	var lift := Meter.median_of(in_st) - Meter.median_of(out_st)
	var gr := _limiter_gr(0.5, 16.0)
	ok = ok and lift >= TUNNEL_LIFT_MIN_DB and lift <= TUNNEL_LIFT_MAX_DB
	_write_wav("tunnel_lautheit", "master", _master_gain)
	_verdict("tunnel_lautheit", ok, {"enter_s": t_in, "outside_lufs": Meter.median_of(out_st), "inside_lufs": Meter.median_of(in_st), "lift_db": lift,
		"inside_max": Meter.max_of(in_st), "limiter": gr},
		"120 km/h: vor dem Portal %.1f LUFS, im Tunnel %.1f LUFS (Kurzzeit, Median; Kamera im Tunnel ab %.2f s) – %+.1f dB (Band %.0f … %.0f dB); Begrenzer höchstens %.1f dB" % [
			Meter.median_of(out_st), Meter.median_of(in_st), t_in, lift, TUNNEL_LIFT_MIN_DB, TUNNEL_LIFT_MAX_DB, float(gr["max_db"])])


## 5 ms of white noise at −12 dBFS with a 1-ms fade (fixed seed).
func _burst() -> AudioStreamWAV:
	var n := int(_rate * 0.005)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var amp := db_to_linear(-12.0)
	var fade := int(_rate * 0.001)
	for i in n:
		var g := minf(1.0, minf(float(i) / fade, float(n - 1 - i) / fade))
		data.encode_s16(2 * i, int(round(rng.randf_range(-1.0, 1.0) * amp * g * 32767.0)))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(_rate)
	w.data = data
	return w


## Tunnel + trucks + siren + crash + music (contract AU-C1/AU-E).
func _worst() -> void:
	# the Gotthard road tunnel (16.9 km of the plan): the Elbtunnel (3.3 km) is left after 11 s at this pace
	var plan: StagePlan = root.get_node("GameData").call("get_stage_plan", "bern_mailand", "bern")
	var tun: Dictionary = {}
	for t: Dictionary in plan.tunnels:
		if float(t["end_km"]) - float(t["start_km"]) > float(tun.get("end_km", 0.0)) - float(tun.get("start_km", 0.0)):
			tun = t
	await _start("bern_mailand", "bern", float(tun.get("start_km", 5.0)) + 0.3, "gran_turismo",
		{"music": "race", "kmh": 230.0, "lane": 1})
	_pilot.throttle = 1.0
	_collisions_before = int(((_am().get("_modern").call("debug_state") as Dictionary).get("events", {}) as Dictionary).get("collision", 0))
	var veh: Object = _sc.get("vehicle")
	var police: Object = _sc.get("police")
	var beside: Array = [_car(9101, "truck", 2, -6.0, 85.0), _car(9102, "truck", 0, -14.0, 88.0)]
	var crash_truck: Array = [null, null]
	var outside := [0]   # frames with the camera outside the tunnel
	_on_physics = func(f: int) -> void:
		var t := f / 60.0
		if f == 1:   # a real chase (siren, snapshot "siren"), held: no escape, no pulling over
			police.call("_start_chase", 230.0)
			police.set("_window", 1.0e6)
		police.set("gap_m", 12.0)
		if f > 30 and not bool(_am().get("_modern").get("frame").get("tunnel")):
			outside[0] += 1
			if CliArgs.has("voice-trace") and int(outside[0]) % 20 == 1:
				print("OUTSIDE f %d km %.3f cam_km %.3f speed %.1f state %d" % [f, float(_sc.get("pos_km")), (_sc.get("track") as Object).call("z_to_km", _cam_z()), float(veh.get("speed")), int(veh.get("state"))])
		for c: Object in beside:   # keep the trucks beside the car
			(c as TrafficSystem.Car).z = float(_sc.get("pos_z")) + (-6.0 if (c as TrafficSystem.Car).lane == 2 else -14.0)
		if t < 2.5:
			veh.set("speed", 230.0)
		if f == 60 * 2:
			crash_truck[0] = _car(9103, "truck", 1, 30.0, 80.0)
		if t >= 5.0 and t < 8.0:   # into the tunnel wall on the right and along it
			_pilot.steer_hold = true
			_pilot.steer_override = 1.0
		elif t >= 8.0:
			_pilot.steer_hold = false
			_pilot.lane = 1
		if f == 60 * 9:
			crash_truck[1] = _car(9104, "truck", 1, 22.0, 60.0)
	await _until(14.0)
	var events: Dictionary = (_am().get("_modern").call("debug_state") as Dictionary).get("events", {})
	await _stop()
	var l := _ch("master", "l")
	var r := _ch("master", "r")
	var tp := Meter.true_peak(l, r, 0, l.size(), 6.0)
	var tp1 := Meter.db(float(tp["true_peak"]))                     # Gesamtlautstärke 1.0
	var tp_std := tp1 + linear_to_db(_master_gain)                  # the settings' Master fader
	var fs := Meter.count_at_least(l, r, 0, l.size(), FULL_SCALE)
	var c := Meter.power_sum(Meter.k_weight(_scaled(l, _master_gain), _rate), Meter.k_weight(_scaled(r, _master_gain), _rate))
	var lufs := Meter.integrated(c, _rate, 0.5, 14.0)
	var mom := Meter.max_of(Meter.series(c, _rate, 0.5, 14.0, 0.4, 0.1))
	var gr := _limiter_gr(0.5, 14.0)
	var collisions := int(events.get("collision", 0)) - _collisions_before
	var ok: bool = tp1 <= WORST_TP_DBTP and fs == 0 and collisions >= 2 and int(outside[0]) == 0
	_write_wav("schlimmster_fall", "master", _master_gain)
	_verdict("schlimmster_fall", ok, {"true_peak_dbtp_master1": tp1, "true_peak_dbtp": tp_std, "sample_peak_db": Meter.db(float(tp["sample_peak"])),
		"full_scale_samples": fs, "lufs": lufs, "momentary_max": mom, "collisions": collisions, "frames_outside_tunnel": outside[0],
		"limiter": gr},
		"True Peak %.2f dBTP bei Gesamtlautstärke 1,0 (höchstens %.1f), %.2f dBTP mit der Einstellung; %d Abtastwerte auf Vollaussteuerung; %.1f LUFS, momentan höchstens %.1f; Begrenzer höchstens %.1f dB, %.0f %% der Zeit über 1 dB, %.0f %% über 3 dB; %d Zusammenstöße (mindestens 2); %d Bilder mit der Kamera außerhalb des Tunnels (0)" % [
			tp1, WORST_TP_DBTP, tp_std, fs, lufs, mom, float(gr["max_db"]), 100.0 * float(gr["share_1db"]), 100.0 * float(gr["share_3db"]), collisions, outside[0]])
