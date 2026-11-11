extends SceneTree
## The music of the Modern sound in the running game (v0.8.0, contract §6 AU-D1 – acceptance):
##   godot --headless --path . -s res://tests/unit/audio_modern/check_music.gd -- --graphics=arcade [--only=a,b]
## Started by tests/unit/audio_modern/test_music_checks.gd (so tools/run_tests.sh covers it). Plays although the run is
## headless (ModernAudio.force_live; the Dummy driver mixes in real time).
##
##   interactive  the race piece as the MusicDirector builds it (AudioStreamInteractive), mixed offline in the
##                AudioServer's 512-frame steps: the main file plays sample for sample as written – count-in from
##                frame 0, the loop point: after the file's end the output equals the first, continuously decoded
##                pass over the loop start (gapless, nothing doubled); the switch to the ending during the loop comes
##                at the next bar line (within 3 ms: the engine reckons from its decoder, which runs up to 128 frames
##                ahead), leaves no gap (5-ms RMS never below the music around it − 12 dB) and no doubled downbeat (the
##                ending's first 100 ms less than 1 dB louder than the ending alone)
##   race         Kiel – Hamburg from a standing start with its countdown, autopilot, Modern profile: the music
##                starts with "stage_start" and the downbeat after the count-in lands on the "LOS!" beep (onsets in
##                the captured buses, real time), then at time scale 8 the car accelerates at full throttle – the
##                music on MMusic is ducked by >= 3 dB (captured after the fader against before the fader), and
##                after the session has gone it comes back to within 1 dB; every frame spans < 0.35 s of game time
##   arcade       the Arcade profile plays nothing new: no ModernAudio, no Modern bus, no file of
##                assets/audio/modern/music loaded – also after the music contexts and race events of a stage – and
##                its menu music is the title theme of v0.7.0
##   quit_menu    (own process) the game quits while the title remaster plays in the menu: the director's players
##   quit_race    (own process) … while the race piece plays: no "leaked at exit" (checked by the launcher)
## Prints "CHECK <name> OK|FEHLER …" per scenario; exit code 0 when all pass.

const SCENARIOS: Array[String] = ["interactive", "race", "arcade"]
const MUSIC_DIR := "res://assets/audio/modern/music/"
const RACE_SCENE := "res://scenes/race/race.tscn"
const STEP := 512
const MIX_RATE := 44100.0

var _am: Node
var _failed: Array[String] = []
var _wall0 := 0
var _sc: Node = null
var _frame_delta := 0.0


func _initialize() -> void:
	_wall0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(delta: float) -> bool:
	_frame_delta = delta
	if Time.get_ticks_msec() - _wall0 > 150000:
		print("CHECK zeitlimit       FEHLER  nach 150 s abgebrochen")
		quit(2)
		return true
	return false


func _check(check_name: String, ok: bool, msg: String) -> void:
	print("CHECK %-12s %s  %s" % [check_name, "OK    " if ok else "FEHLER", msg])
	if not ok:
		_failed.append(check_name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _modern() -> Node:
	var m: Variant = _am.get("_modern")
	return m if m is Node else null


func _run() -> void:
	await _frames(3)
	_am = root.get_node_or_null("AudioManager")
	if _am == null:
		print("CHECK aufbau       FEHLER  AudioManager fehlt")
		quit(1)
		return
	var only := CliArgs.get_string("only", "")
	var run: Array[String] = []
	for s in (only.split(",", false) if only != "" else SCENARIOS):
		run.append(str(s))
	# the Arcade sounds exist as on a display (beeps for the countdown), the Modern profile plays headless
	var cfg: Dictionary = _am.get("_audio_cfg")
	if not bool(_am.get("sounds_ready")):
		_am.call("_load_traffic_sounds", cfg)
		_am.call("_build_sounds")
		_am.call("_load_music", str(ConfigLoader.lookup(cfg, "audio.music_file", "")))
	ModernAudio.force_live = true
	for s in run:
		match s:
			"interactive":
				_scenario_interactive()
			"race":
				await _scenario_race()
			"arcade":
				await _scenario_arcade()
			"quit_menu":
				await _scenario_quit(false)
				return
			"quit_race":
				await _scenario_quit(true)
				return
			"quit_arcade":
				# reference (not run by the launcher): quitting with the Arcade menu music playing, as in v0.7.0
				_am.call("set_profile", "arcade")
				_am.call("set_music", true)
				await _frames(60)
				_check("quit_arcade", true, "Arcade-Menümusik spielt beim Beenden")
				quit(0)
				return
			_:
				_check(s, false, "unbekanntes Szenario")
	_am.call("set_profile", "arcade")
	_am.call("set_music", false)
	_am.call("stop_all")
	await _frames(20)
	quit(0 if _failed.is_empty() else 1)


# --- offline mixing --------------------------------------------------------------------------------

## Mixes a playback in the AudioServer's steps (pass started = false to start it from 0 here).
func _mix(pb: AudioStreamPlayback, frames: int, started: bool = false) -> PackedVector2Array:
	if not started:
		pb.start(0.0)
	var out := PackedVector2Array()
	while out.size() < frames:
		var blk := pb.mix_audio(1.0, STEP)
		out.append_array(blk)
		if blk.size() < STEP:      # a finished stream returns less: silence
			var pad := PackedVector2Array()
			pad.resize(STEP - blk.size())
			out.append_array(pad)
	return out


func _rms_db(x: PackedVector2Array, a: int, n: int) -> float:
	var s := 0.0
	for i in range(maxi(a, 0), mini(a + n, x.size())):
		s += x[i].length_squared() * 0.5
	return 10.0 * log(maxf(s / maxf(n, 1), 1.0e-20)) / log(10.0)


## The race pieces of the manifest (role "race", not placeholders) in the order of their rotation.
func _race_ids() -> Array[String]:
	var a := ModernAudioAssets.new()
	a.load_all()
	var rows: Array = []
	for id in a.ids("music", "music", "race"):
		var e := a.entry("music", id)
		rows.append([int(e.meta.get("rotation", 99)), id])
	rows.sort()
	var out: Array[String] = []
	for r: Array in rows:
		out.append(str(r[1]))
	return out


func _scenario_interactive() -> void:
	var t0 := Time.get_ticks_msec()
	var ok := true
	var parts: Array[String] = []
	var ids := _race_ids()
	if ids.size() < 3:
		_check("interactive", false, "Rennstücke fehlen (%s)" % str(ids))
		return
	for i in ids.size():
		# the whole main file of every piece, the normal ending after the loop point; the ending variants and the stab
		# of the first piece in its first pass (the same transition, other clips)
		var r := _interactive_piece(ids[i], "schluss", true)
		ok = ok and bool(r["ok"])
		parts.append(str(r["text"]))
	for v: String in ["schluss_rekord", "schluss_finale"]:
		var r := _interactive_piece(ids[1], v, false)
		ok = ok and bool(r["ok"])
		parts.append(str(r["text"]))
	var z := _loop_seam("zwischenspiel")
	ok = ok and bool(z["ok"])
	parts.append(str(z["text"]))
	_check("interactive", ok, "; ".join(parts) + "; %d ms" % (Time.get_ticks_msec() - t0))


## A race piece as the MusicDirector builds it (AudioStreamInteractive), mixed offline in the AudioServer's 512-frame
## steps: the main file frame for frame until the switch, after its end the first pass over the loop start again; the
## switch to the ending clip `clip_name` at the next bar line (asked for 1.234 s into the second pass, or – second_pass
## false – 31.3 s into the first): within 3 ms, no gap, no doubled downbeat.
func _interactive_piece(id: String, clip_name: String, second_pass: bool) -> Dictionary:
	var main: AudioStreamOggVorbis = load(MUSIC_DIR + id + ".ogg")
	var ending: AudioStreamOggVorbis = load(MUSIC_DIR + id + "_schluss.ogg")
	var variant: AudioStreamOggVorbis = load(MUSIC_DIR + id + "_" + clip_name + ".ogg")
	if main == null or ending == null or variant == null:
		return {"ok": false, "text": "%s: Klangdateien fehlen" % id}
	var variants := {}
	for v: String in MusicDirector.VARIANT_CLIPS:
		var vs: AudioStreamOggVorbis = load(MUSIC_DIR + id + "_" + str(MusicDirector.VARIANT_CLIPS[v]) + ".ogg")
		if vs != null:
			variants[v] = vs
	var length := int(round(main.get_length() * MIX_RATE))
	var off := int(main.loop_offset * MIX_RATE)
	var bar := 4.0 * 60.0 / main.bpm
	var switch_at := (length + int(1.234 * MIX_RATE)) if second_pass else int(31.3 * MIX_RATE)
	switch_at -= switch_at % STEP
	# 1. the main file alone (its own playback): reference of the first pass and of the loop
	var ref := _mix(main.instantiate_playback(), (length if second_pass else switch_at) + int(3.0 * MIX_RATE))
	var after_loop := 0.0
	if second_pass:
		for k in range(2, int(2.0 * MIX_RATE)):
			after_loop = maxf(after_loop, (ref[length + k] - ref[off + k]).length())
	# 2. the interactive stream of the director: the same until the switch
	var s := MusicDirector.build_race_stream(main, ending, variants)
	var pb := s.instantiate_playback() as AudioStreamPlaybackInteractive
	pb.start(0.0)
	var out := _mix(pb, switch_at, true)
	var same := 0.0
	for i in range(0, out.size(), 7 if second_pass else 3):
		same = maxf(same, (out[i] - ref[i]).length())
	pb.switch_to_clip_by_name(StringName(clip_name))
	out.append_array(_mix(pb, int(4.0 * MIX_RATE), true))
	# where the ending starts: its own output once the loop has faded out, matched against the mix. Every clip
	# reaches the output 2 frames late (the engine's cubic resampler), so output frame k shows file frame k − 2 –
	# in the second pass k − 2 − length + off. Ideal start: the ending's frame 0 where the main shows its bar line.
	var end_ref := _mix(variant.instantiate_playback(), int(2.0 * MIX_RATE))
	var bar_frames := bar * MIX_RATE
	var f_out := float(switch_at - 2 - (length - off if second_pass else 0))
	var f_bar := ceilf(f_out / bar_frames) * bar_frames
	var to_bar := (f_bar - f_out) / MIX_RATE
	var bar_frame := int(round(f_bar)) + (length - off if second_pass else 0)
	var best := 0
	var best_err := INF
	var w0 := int(0.35 * MIX_RATE)
	for d in range(-400, 400):
		var err := 0.0
		for k in range(w0, w0 + 4000, 5):
			err += (out[bar_frame + d + k] - end_ref[k]).length_squared()
		if err < best_err:
			best_err = err
			best = d
	# no gap: 5-ms RMS from 50 ms before to 300 ms after the bar line never far below the music before it
	var before := _rms_db(out, bar_frame - int(bar * MIX_RATE), int(bar * MIX_RATE))
	var lowest := 0.0
	for k in range(-int(0.05 * MIX_RATE), int(0.3 * MIX_RATE), 220):
		lowest = minf(lowest, _rms_db(out, bar_frame + best + k, 220) - before)
	var clip := pb.get_current_clip_index()
	var want_clip := -1
	for c in s.clip_count:
		if s.get_clip_name(c) == StringName(clip_name):
			want_clip = c
	var ms_off := best / MIX_RATE * 1000.0
	# no doubled downbeat: the first 100 ms of the ending in the mix are as loud as the ending alone (the loop stops
	# at the bar line instead of fading out under the ending's first hit)
	var bump := _rms_db(out, bar_frame + best, 4410) - _rms_db(end_ref, 0, 4410)
	var ok := after_loop < 1.0e-6 and same < 1.0e-6 and ms_off <= 0.5 and ms_off >= -3.0 and lowest > -12.0 \
		and clip == want_clip and best_err < 1.0e-6 and bump < 1.0
	var text := "%s %s (%s): " % [id, clip_name, "nach der Schleife" if second_pass else "im ersten Durchgang"]
	if second_pass:
		text += "Hauptdatei %d Frames, Schleife ab Frame %d, nach dem Dateiende Abweichung %s zum ersten Durchgang; " % [
			length, off, String.num_scientific(after_loop)]
	text += ("bis zum Wechsel Frame für Frame (Abweichung %s); %.3f s vor dem Taktstrich angefordert – Beginn %.2f ms %s " +
		"dem Taktstrich (Restfehler %s), Clip %d; leisestes 5-ms-Fenster %.1f dB unter der Musik davor; erste 100 ms " +
		"%+.2f dB gegenüber dem Clip allein") % [String.num_scientific(same), to_bar, absf(ms_off),
		"vor" if ms_off < 0.0 else "nach", String.num_scientific(best_err), clip, -lowest, bump]
	return {"ok": ok, "text": text + (" OK" if ok else " FEHLER")}


## A plain looping piece (the interlude): after the end of the file the output equals the first pass over the loop
## start (its intro is the loop's own end, so the seam lies inside the music).
func _loop_seam(id: String) -> Dictionary:
	var main: AudioStreamOggVorbis = load(MUSIC_DIR + id + ".ogg")
	if main == null:
		return {"ok": false, "text": "%s fehlt" % id}
	var length := int(round(main.get_length() * MIX_RATE))
	var off := int(main.loop_offset * MIX_RATE)
	var ref := _mix(main.instantiate_playback(), length + int(3.0 * MIX_RATE))
	var after_loop := 0.0
	for k in range(2, int(2.0 * MIX_RATE)):
		after_loop = maxf(after_loop, (ref[length + k] - ref[off + k]).length())
	var level := _rms_db(ref, off, int(2.0 * MIX_RATE))
	var ok := main.loop and after_loop < 1.0e-6 and level > -40.0
	return {"ok": ok, "text": "%s: %d Frames, Schleife ab Frame %d, nach dem Dateiende Abweichung %s zum ersten Durchgang (Pegel dort %.1f dBFS)%s" % [
		id, length, off, String.num_scientific(after_loop), level, " OK" if ok else " FEHLER"]}


# --- the race ---------------------------------------------------------------------------------------

func _set_time_scale(ts: float) -> void:
	Engine.time_scale = ts
	Engine.physics_ticks_per_second = int(60.0 * ts)
	Engine.max_physics_steps_per_frame = 32


## A capture on a bus at an effect index (−1 = at the end of the chain).
func _capture(bus: String, at: int) -> AudioEffectCapture:
	var c := AudioEffectCapture.new()
	c.buffer_length = 2.0
	var i := AudioServer.get_bus_index(bus)
	AudioServer.add_bus_effect(i, c, at)
	return c


## Index of the fader (the scripted gain: ducking, snapshot dips) in the effect chain of a bus; −1 = none.
func _fader_index(bus: String) -> int:
	var i := AudioServer.get_bus_index(bus)
	for j in range(AudioServer.get_bus_effect_count(i) - 1, -1, -1):
		if AudioServer.get_bus_effect(i, j) is AudioEffectAmplify:
			return j
	return -1


func _remove_effect(bus: String, fx: AudioEffect) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	for j in range(AudioServer.get_bus_effect_count(i) - 1, -1, -1):
		if AudioServer.get_bus_effect(i, j) == fx:
			AudioServer.remove_bus_effect(i, j)


func _drain(c: AudioEffectCapture, into: PackedVector2Array) -> int:
	var n := c.get_frames_available()
	if n > 0:
		into.append_array(c.get_buffer(n))
	return n


## Onsets of a capture: start frames of the 5-ms windows that rise above floor_db after at least 150 ms below it.
func _onsets(x: PackedVector2Array, floor_db: float) -> Array[int]:
	var out: Array[int] = []
	var quiet := 0
	var w := 220
	for a in range(0, x.size() - w, w):
		var db := _rms_db(x, a, w)
		if db > floor_db:
			if quiet >= 30:
				out.append(a)
			quiet = 0
		else:
			quiet += 1
	return out


const ENV_W := 220      ## 5-ms windows of the envelopes


## 5-ms RMS envelope (dB) of x from frame a on, n windows.
func _env(x: PackedVector2Array, a: int, n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for j in n:
		out.append(_rms_db(x, a + j * ENV_W, ENV_W))
	return out


## Frame of the capture at which frame 0 of the file played: the file's envelope (count-in) slid over the capture's,
## best mean absolute difference in dB after removing the level difference (player volume, EQ). Search from lo to hi
## (frames of the capture) on the 5-ms grid, then in 10-frame steps around the best window.
func _file_start(x: PackedVector2Array, file_env: PackedFloat32Array, lo: int, hi: int) -> Dictionary:
	var best := -1
	var best_err := INF

	var score := func(start: int) -> float:
		var e := _env(x, start, file_env.size())
		var diff := 0.0
		var cnt := 0
		for j in file_env.size():
			if file_env[j] > -60.0:
				diff += e[j] - file_env[j]
				cnt += 1
		if cnt == 0:
			return INF
		var off := diff / cnt
		var err := 0.0
		for j in file_env.size():
			if file_env[j] > -60.0:
				err += absf(e[j] - file_env[j] - off)
		return err / cnt

	lo = maxi(lo, 0)
	hi = maxi(hi, lo)
	var cap := _env(x, lo, (hi - lo) / ENV_W + file_env.size())
	for c in range(0, (hi - lo) / ENV_W):
		var diff := 0.0
		var cnt := 0
		for j in file_env.size():
			if file_env[j] > -60.0:
				diff += cap[c + j] - file_env[j]
				cnt += 1
		if cnt == 0:
			continue
		var off := diff / cnt
		var err := 0.0
		for j in file_env.size():
			if file_env[j] > -60.0:
				err += absf(cap[c + j] - file_env[j] - off)
		err /= cnt
		if err < best_err:
			best_err = err
			best = lo + c * ENV_W
	if best < 0:
		return {"frame": -1, "err": INF}
	var fine := best
	for start in range(best - ENV_W, best + ENV_W, 10):
		var err: float = score.call(start)
		if err < best_err:
			best_err = err
			fine = start
	return {"frame": fine, "err": best_err}


## First frame near `near` where the capture rises above `level` (a sharp onset: the "LOS!" tone).
func _onset_near(x: PackedVector2Array, near: int, level: float = 0.01) -> int:
	for i in range(maxi(near - 2 * ENV_W, 0), mini(near + 2 * ENV_W, x.size())):
		if absf(x[i].x) > level or absf(x[i].y) > level:
			return i
	return near


func _launch(stage: String, start_km: float) -> void:
	var setup := {"mode": "single", "race_id": "", "stage_id": stage, "from_city": "", "vehicle": "kompakt",
		"start_world_minutes": 11.0 * 60.0, "weather": "normal", "start_km": start_km, "autopilot": true,
		"seed": 7, "traffic_warmup": true, "start_speed_kmh": 0.0, "gfx": "arcade"}
	_sc = (load(RACE_SCENE) as PackedScene).instantiate()
	_sc.set("setup", setup)
	root.add_child(_sc)


func _scenario_race() -> void:
	_am.call("set_profile", "modern")
	await _frames(2)
	var m := _modern()
	if m == null:
		_check("race", false, "ModernAudio fehlt")
		return
	# captures right before and right after the music's fader (the ducking and the dips act there; EQ and filter
	# come before it) and at the end of MUI (the countdown sounds) – added together while the mixer is locked, so all
	# three see the same mix steps
	var fader := _fader_index("MMusic")
	if fader < 0:
		_check("race", false, "kein Fader auf MMusic")
		return
	AudioServer.lock()
	var post := _capture("MMusic", -1)
	var pre := _capture("MMusic", fader)
	var ui := _capture("MUI", -1)
	AudioServer.unlock()
	_am.call("set_music", false)
	_am.call("set_music_context", "race", {"stage_id": "kiel_hamburg"})
	_set_time_scale(1.0)
	_launch("kiel_hamburg", 2.0)
	var x_pre := PackedVector2Array()
	var x_post := PackedVector2Array()
	var x_ui := PackedVector2Array()
	var go_frame := -1
	var wall := Time.get_ticks_msec()
	var burst := 0              # the most frames the driver mixed between two short frames of the game: its burst
	var frame_times := PackedFloat32Array()
	var countin_frame_max := 0.0   # the longest frame between the music's start and "LOS!" (real time)
	var director: Object = m.get("music")
	# 1. countdown and the first half second after "LOS!" in real time
	while Time.get_ticks_msec() - wall < 15000:
		await process_frame
		_drain(pre, x_pre)
		var got := _drain(post, x_post)
		_drain(ui, x_ui)
		if _frame_delta < 0.05:
			burst = maxi(burst, got)
		if bool(_sc.get("_stage_start_sent")) if _sc != null else false:
			frame_times.append(_frame_delta)
			if go_frame < 0 and str(director.get("race_phase")) == "playing":
				countin_frame_max = maxf(countin_frame_max, _frame_delta)
		if go_frame < 0 and _sc != null and bool(_sc.get("running")):
			go_frame = x_post.size()
		if go_frame >= 0 and x_post.size() > go_frame + int(0.8 * MIX_RATE):
			break
	var st: Dictionary = (m.get("music") as Object).call("debug_state")
	var go_offset: Variant = st.get("go_offset_s")
	# the capture before the fader may have started one mix step later than the other two: index x_pre with this
	var pre_lag := x_post.size() - x_pre.size()
	# onsets: the four countdown sounds on MUI (three beeps, "LOS!"), the downbeat in the music
	var dump := CliArgs.get_string("dump", "")
	if dump != "":
		_dump(dump.path_join("countdown_mmusic_pre.f32"), x_pre)
		_dump(dump.path_join("countdown_mmusic_post.f32"), x_post)
		_dump(dump.path_join("countdown_mui.f32"), x_ui)
	var on_ui := _onsets(x_ui, -45.0)
	var go_ui := _onset_near(x_ui, on_ui[on_ui.size() - 1]) if not on_ui.is_empty() else -1
	var music_started := str(st.get("race_phase", "")) == "playing" and str(st.get("key", "")).begins_with("race/")
	# 2. full throttle, sped up as far as a frame stays well under 0.35 s of game time (from the frames of the
	# countdown: 0.15 s of game time per frame, 1 to 8): the ducking (after the fader against before it)
	var sorted_times := frame_times.duplicate()
	sorted_times.sort()
	var median_frame := sorted_times[sorted_times.size() / 2] if not sorted_times.is_empty() else 0.02
	var p90_frame := sorted_times[int(sorted_times.size() * 0.9)] if not sorted_times.is_empty() else 0.02
	var ts := clampf(floorf(0.1 / maxf(p90_frame, 0.001)), 1.0, 2.0)
	_set_time_scale(ts)
	var idle_db := _gain_db(x_pre, x_post, maxi(go_ui - int(1.2 * MIX_RATE), 0), int(0.8 * MIX_RATE), pre_lag)
	var frame_game_max := 0.0
	var duck_db := 0.0
	var mix_duck := 0.0
	wall = Time.get_ticks_msec()
	var t_start: float = _sc.get("stage_time")
	while Time.get_ticks_msec() - wall < 20000:
		await process_frame
		frame_game_max = maxf(frame_game_max, _frame_delta)
		_drain(pre, x_pre)
		_drain(post, x_post)
		_drain(ui, x_ui)
		if float(_sc.get("stage_time")) - t_start > 7.0:
			break
	var v: Variant = _sc.get("vehicle")
	var speed: float = (v as Object).get("speed") if v is Object else 0.0
	var throttle := float((_sc.get("last_input") as Dictionary).get("throttle", 0.0))
	# the fader's effect in 50-ms windows over the last second of full throttle: median and deepest
	var gains := PackedFloat32Array()
	for a in range(x_post.size() - int(1.0 * MIX_RATE), x_post.size() - 2205, 2205):
		gains.append(_gain_db(x_pre, x_post, a, 2205, pre_lag) - idle_db)
	gains.sort()
	duck_db = gains[gains.size() / 2] if not gains.is_empty() else 0.0
	var duck_deepest := gains[0] if not gains.is_empty() else 0.0
	mix_duck = float((m.get("mix") as Object).get("duck_db"))
	# 3. the session goes (the stage is left, the race piece plays on): the music comes back
	_set_time_scale(1.0)
	_sc.queue_free()
	_sc = null
	wall = Time.get_ticks_msec()
	while Time.get_ticks_msec() - wall < 2500:
		await process_frame
		_drain(pre, x_pre)
		_drain(post, x_post)
		_drain(ui, x_ui)
	var back_db := _gain_db(x_pre, x_post, x_post.size() - int(0.3 * MIX_RATE), int(0.25 * MIX_RATE), pre_lag) - idle_db
	# where the race file started in the capture (its count-in matched), its first downbeat one bar later – computed
	# now, after the drive (it takes a moment and must not stretch a frame of the race)
	var main: AudioStreamOggVorbis = load(MUSIC_DIR + "linke_spur.ogg")
	var bar_f := int(round(4.0 * 60.0 / main.bpm * MIX_RATE))
	var file_env := _env(_mix(main.instantiate_playback(), bar_f), 0, bar_f / ENV_W - 4)
	var fs := _file_start(x_pre, file_env, go_ui - pre_lag - int(4.0 * MIX_RATE), go_ui - pre_lag) if go_ui >= 0 else {"frame": -1, "err": INF}
	var downbeat := int(fs["frame"]) + pre_lag + bar_f
	var land_ms := (downbeat - go_ui) / MIX_RATE * 1000.0
	_set_time_scale(1.0)
	Engine.physics_ticks_per_second = 60
	Engine.max_physics_steps_per_frame = 8
	for fx: Array in [["MMusic", pre], ["MMusic", post], ["MUI", ui]]:
		_remove_effect(str(fx[0]), fx[1])
	# the downbeat against the "LOS!" tone in the output. The Dummy driver of a headless run starts every sound at the
	# next of its bursts (4096 frames, 93 ms): the downbeat lies a fixed part of a burst after the music's start
	# (80182 frames = 19.58 bursts), the tone right on a burst – the two land up to one burst apart (measured
	# +53.4 ms, one burst more when the tone's frame came early). A real driver mixes in 512-frame steps (11.6 ms) –
	# there the director's frame dominates (inferred). The director's own clock is checked to one frame plus one
	# physics step (go_offset_s).
	# Both bounds grow with the longest frame of the count-in: a frame that runs several physics steps at once (the
	# physics catching up on a loaded machine) moves the start by up to that frame; with steady frames they are tight.
	var step := 1.0 / 60.0
	var game_tol := maxf(countin_frame_max, step) + step + 0.002
	var land_tol := 1000.0 * (burst / MIX_RATE + maxf(countin_frame_max, step)) + 40.0
	var game_ok := go_offset != null and absf(float(go_offset)) <= game_tol
	var ok := music_started and game_ok and go_ui >= 0 and on_ui.size() >= 4 and absf(land_ms) <= land_tol and float(fs["err"]) < 3.0 and duck_db <= -3.0 \
		and absf(back_db) <= 1.0 and frame_game_max < 0.35
	_check("race", ok, ("Kiel – Hamburg ab km 2 mit Countdown: Rennstück %s (%s); %d Einsätze auf MUI, der Schlag nach dem Einzähler kommt %.1f ms %s „LOS!“ (Abgleich des Einzählers %.2f dB) " +
		"– erlaubt %.0f ms (Treiber mischt in Schüben von %d Frames, Bilder im Countdown im Median %.0f ms, im Einzähler bis %.0f ms); Spielzeit-Abstand im Director %s s (erlaubt %.0f ms); " +
		"Vollgas bei Zeitraffer %d (%.0f km/h, Gas %.2f): Musik nach dem Fader %.1f dB gegenüber dem Countdown (Median über 1 s, tiefstes 50-ms-Fenster %.1f dB; Mischung %.1f dB), " +
		"ohne Sitzung wieder %.1f dB; längstes Bild %.3f s Spielzeit") % [
		str(st.get("key", "")), str(st.get("race_phase", "")), on_ui.size(), absf(land_ms), "nach" if land_ms >= 0.0 else "vor", float(fs["err"]),
		land_tol, burst, median_frame * 1000.0, countin_frame_max * 1000.0, str(go_offset), game_tol * 1000.0, int(ts), speed, throttle, duck_db, duck_deepest, mix_duck, back_db, frame_game_max])
	_am.call("set_music_context", "menu")
	_am.call("set_profile", "arcade")
	await _frames(5)


## --dump=<dir>: a capture as raw interleaved float32 stereo (44.1 kHz) for a closer look.
func _dump(path: String, x: PackedVector2Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	for v in x:
		f.store_float(v.x)
		f.store_float(v.y)
	f.close()


## Level after the fader against before it (dB) over n frames from a: what the fader, EQ and filters do to the music.
func _gain_db(x_pre: PackedVector2Array, x_post: PackedVector2Array, a: int, n: int, pre_lag: int) -> float:
	return _rms_db(x_post, a, n) - _rms_db(x_pre, a - pre_lag, n)


# --- Arcade ------------------------------------------------------------------------------------------

func _music_files() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(MUSIC_DIR):
		if f.ends_with(".ogg"):
			out.append(MUSIC_DIR + f)
	return out


func _scenario_arcade() -> void:
	_am.call("set_profile", "arcade")
	await _frames(3)
	var cached_before: Array[String] = []
	for f in _music_files():
		if ResourceLoader.has_cached(f):
			cached_before.append(f)
	# the menu, a whole stage's calls and the race context: with Arcade nothing of the Modern music may load or play
	_am.call("set_music", true)
	_am.call("set_music_context", "title")
	await _frames(5)
	_am.call("set_music", false)
	_am.call("set_music_context", "race", {"stage_id": "kiel_hamburg"})
	for ev in ["stage_start", "countdown", "go", "stage_finish"]:
		_am.call("event", ev, {"countdown_s": 3.0, "n": 1})
	await _frames(5)
	_am.call("set_music_context", "result")
	_am.call("set_music", true)
	await _frames(5)
	var loaded: Array[String] = []
	for f in _music_files():
		if ResourceLoader.has_cached(f) and not cached_before.has(f):
			loaded.append(f.get_file())
	var buses: Array[String] = []
	for i in AudioServer.bus_count:
		var n := AudioServer.get_bus_name(i)
		if n.begins_with("M") and n != "Master" and n != "Music":
			buses.append(n)
	var music_player: Variant = _am.get("_music")
	var arcade_stream := ""
	if music_player is AudioStreamPlayer and (music_player as AudioStreamPlayer).stream != null:
		arcade_stream = (music_player as AudioStreamPlayer).stream.resource_path
	var players := 0
	for c in _am.get_children():
		if c is AudioStreamPlayer and (c as AudioStreamPlayer).playing:
			players += 1
	var ok := _modern() == null and buses.is_empty() and loaded.is_empty() and str(_am.call("profile")) == "arcade" \
		and arcade_stream.ends_with("assets/audio/music/title_theme.ogg")
	_check("arcade", ok, "Profil Arcade nach Menü, Rennkontext und Etappenereignissen: ModernAudio %s, Modern-Busse %s, geladene Modern-Musik %s, Menümusik %s (%d Player spielen)" % [
		"keins" if _modern() == null else "DA", "keine" if buses.is_empty() else str(buses),
		"keine" if loaded.is_empty() else str(loaded), arcade_stream, players])
	_am.call("set_music", false)
	await _frames(3)


# --- quitting while music plays (own process) -----------------------------------------------------------

func _scenario_quit(race: bool) -> void:
	_am.call("set_profile", "modern")
	await _frames(2)
	if race:
		_am.call("set_music", false)
		_am.call("set_music_context", "race", {"stage_id": "x"})
		_am.call("event", "stage_start", {"countdown_s": 0.0})
	else:
		_am.call("set_music", true)
		_am.call("set_music_context", "title")
	var wall := Time.get_ticks_msec()
	while Time.get_ticks_msec() - wall < 1500:
		await process_frame
	var m := _modern()
	var st: Dictionary = (m.get("music") as Object).call("debug_state")
	var playing := bool(st.get("playing", false))
	# the profile ends while the music plays (what ModernAudio._exit_tree does when the game quits): every player of
	# the director stops and is freed at once; the engine frees a stopped playback only after its mixer has faded it out
	# and a later frame of the main thread has run – the Dummy driver of a headless run mixes in bursts of 93 ms, so
	# the game waits 0.3 s before quit() – then nothing may be left ("leaked at exit" is checked by the launcher). An
	# immediate quit() leaves the engine no such time, with either profile (docs/audio-modern.md, "Beenden").
	m.call("shutdown")
	var players := 0
	for c in m.get_children():
		if c is AudioStreamPlayer and not (c as AudioStreamPlayer).is_queued_for_deletion():
			players += 1
	wall = Time.get_ticks_msec()
	while Time.get_ticks_msec() - wall < 300:
		await process_frame
	_check("quit_race" if race else "quit_menu", playing and players == 0,
		"Musik spielte (%s, %s); Profil beendet: %d Player übrig, 0,3 s später quit()" % [str(st.get("key", "")), str(st.get("race_phase", "")), players])
	quit(0 if _failed.is_empty() else 1)
