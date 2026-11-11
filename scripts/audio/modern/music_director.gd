class_name MusicDirector
extends ModernAudioModule
## Slot "music" of the Modern sound (contract D29, D30, §4.7; docs/audio-modern.md, section "Musik"): what plays on
## the bus MMusic. Package AU-D1.
##
## ModernAudio expects, beyond the hooks of ModernAudioModule:
##   set_context(context, args)   AudioManager.set_music_context: "title" | "menu" | "race_menu" | "race" | "result" | "off"
##   set_legacy(on)               AudioManager.set_music(on) of the existing menu code (see below)
##   set_race_music(on)           option "Musik im Rennen" (default on; the Arcade profile has no race music at all)
##   wanted() -> bool             menu music is on (handed to the Arcade player when the profile switches back)
##   context                      the context in force
##
## Pieces come from assets/audio/modern/music/manifest.json by their role:
##   "title"      the remastered title theme (title and menu screens; also "race_menu" and "result" while no
##                "interlude" / "result" piece exists). One Ogg file that loops from its intro's end.
##   "race"       a race piece: one Ogg file = count-in + first phrase, then the loop body (loop_offset), plus the
##                ending named by its entry ("ending": id, role "race_ending"). Played as an AudioStreamInteractive
##                (build_race_stream): clip "lauf" loops by itself, the switch to clip "schluss" happens at the next
##                bar line of "lauf" (the ending starts at full level, the loop stops within 1 ms – FADE_DISABLED).
##                Several race pieces are played in turn, one per stage.
##   Without a Modern title the menu contexts play today's title theme (the AudioManager's stream); without a race
##   piece a race is silent.
##
## The race piece and the stage:
##   set_context("race")        a new stage: the piece is armed (the menu music fades out), nothing plays yet;
##   event "stage_start"        {countdown_s}: play() is scheduled countdown_s − count-in later, so that the first
##                              downbeat after the count-in lands on the countdown's "LOS!" (the count-in is a whole
##                              bar: the interactive stream starts its first clip at 0 and counts bars from there);
##                              every "countdown" {n} re-anchors the schedule (n seconds before "LOS!"), and the wait
##                              is counted in physics steps – the clock of the countdown; the start comes in the frame
##                              nearest to its moment; while the tree is paused during the count-in the stream pauses
##                              too (the countdown stands still); after "LOS!" the pause only filters the music
##                              (ModernMix "pause");
##   event "go"                 the piece starts now if it has not (a countdown shorter than the count-in);
##   event "stage_finish"       the ending at the next bar line; a piece that never started stays silent;
##   no "stage_start" at all    (tools that drive without a session) the piece starts once the car has been driven
##                              for START_FALLBACK_S.
## Levels: the player plays at ctx.mix.music_context_db(context) + gain_db of the manifest entry; ducking under the
## car, the pause low-pass, the race EQ and the snapshot dips happen on the bus (ModernMix, ModernBuses). Crossfades
## move the player volume (ramped by the AudioServer per mix step: no clicks), equal power.
## The two switches: the game calls set_music(true/false) as it always did and, from wave 2 on, set_music_context
## next to it. The last call wins: set_music(false) = "off"; set_music(true) = "menu" unless a menu context
## ("title", "menu", "race_menu", "result") is already in force; a context call sets exactly that context.
## stop_all() does not stop music. Nothing here exists with the Arcade profile (ModernAudio only lives with Modern).

const BUS := "MMusic"
const MENU_CONTEXTS: Array[String] = ["title", "menu", "race_menu", "result"]
const ROLE_OF := {"title": "title", "menu": "title", "race_menu": "interlude", "result": "result", "race": "race"}
const ARCADE_KEY := "arcade/music"
const MAIN_CLIP := &"lauf"
const ENDING_CLIP := &"schluss"
## Race piece: armed (waiting for the stage), waiting (start scheduled), playing, ending (switched to the ending),
## over (the stage finished before the piece started – stays silent).
const RACE_IDLE := "idle"
const RACE_ARMED := "armed"
const RACE_WAITING := "waiting"
const RACE_PLAYING := "playing"
const RACE_ENDING := "ending"
const RACE_OVER := "over"
const START_FALLBACK_S := 0.5      ## no "stage_start": start once the car has been driven this long

var context := "off"
var race_music := true
var fade_in_s := 0.4
var fade_out_s := 0.6

var race_phase := RACE_IDLE
var race_index := -1               ## stages with music context "race" so far − 1 (rotation of the race pieces)
var race_t := 0.0                  ## seconds the race piece has played (game time, without pauses)
var start_in := -1.0               ## seconds until the scheduled start (−1 = none)
var go_offset_s := NAN             ## at "go": race_t − count-in (0 = the downbeat lands on "LOS!"); NAN = not measured
var countdown_paused := false      ## the stream is paused because the tree is paused during the count-in

var _players: Array[AudioStreamPlayer] = []
var _key: Array[String] = ["", ""]       ## the piece each of the two players holds ("" = none)
var _level := PackedFloat32Array([0.0, 0.0])
var _target := PackedFloat32Array([0.0, 0.0])
var _db := PackedFloat32Array([0.0, 0.0])
var _cur := 0
var _race_gen := 0
var _race_piece: Dictionary = {}         ## the piece of the current stage: {id, key, stream, db, countin_s, bpm, ending}
var _alive_t := 0.0
var _streams: Dictionary = {}            ## piece id -> AudioStreamInteractive (built once per profile)
## The clock of the scheduled start: the session's countdown runs in physics steps, so the start is counted in
## physics steps too (Engine.get_physics_frames(), without the paused ones) – a long frame, after which the physics
## catches up or drops time, then shifts the countdown and the music alike. Without physics (unit tests, tools that
## drive the slots themselves) the frame time counts once no physics step has come for WAIT_NO_PHYSICS_S.
var _sched_left := 0.0
var _phys_seen := 0
var _phys_steps := 0
var _wait_dt := 0.0
var _physics_runs := false               ## a physics step came while waiting: race_t is counted in steps too
const WAIT_NO_PHYSICS_S := 0.25


func _setup() -> void:
	fade_in_s = maxf(ctx.number("music.fade_in_s", fade_in_s), 0.01)
	fade_out_s = maxf(ctx.number("music.fade_out_s", fade_out_s), 0.01)
	for i in 2:
		var p := ctx.player(BUS, "Music%d" % i)
		if p != null:
			p.volume_db = -80.0
			_players.append(p)


# --- contexts ------------------------------------------------------------------------------------------------------

func set_context(p_context: String, _args: Dictionary = {}) -> void:
	var c := p_context if ModernMix.CONTEXTS.has(p_context) else "off"
	if c == "race":
		# every call is a new stage (also a restart of the same stage): the next race piece, armed
		race_index += 1
		_race_gen += 1
		_arm_race()
	elif race_phase != RACE_IDLE:
		race_phase = RACE_IDLE
		start_in = -1.0
	context = c


func set_legacy(on: bool) -> void:
	if not on:
		context = "off"
		if race_phase != RACE_IDLE:
			race_phase = RACE_IDLE
			start_in = -1.0
	elif not MENU_CONTEXTS.has(context):
		context = "menu"


func set_race_music(on: bool) -> void:
	race_music = on


func wanted() -> bool:
	return MENU_CONTEXTS.has(context)


func event(event_name: String, args: Dictionary) -> void:
	if context != "race":
		return
	match event_name:
		"stage_start":
			if race_phase == RACE_ARMED:
				var countdown := maxf(float(args.get("countdown_s", 0.0)), 0.0)
				_schedule(maxf(countdown - float(_race_piece.get("countin_s", 0.0)), 0.0))
				race_phase = RACE_WAITING
		"countdown":
			# each new countdown number is n seconds before "LOS!": schedule from the latest one
			if race_phase == RACE_WAITING:
				var left := float(args.get("n", 0)) - float(_race_piece.get("countin_s", 0.0))
				if left >= 0.0:
					_schedule(left)
		"go":
			if race_phase == RACE_ARMED or race_phase == RACE_WAITING:
				_start_race()
			if race_phase == RACE_PLAYING and is_nan(go_offset_s):
				# "go" comes inside a physics step: count the steps since the last frame as well
				var steps := _phys_steps + (Engine.get_physics_frames() - _phys_seen)
				var t := steps * _step_s() if _physics_runs else race_t
				go_offset_s = t - float(_race_piece.get("countin_s", 0.0))
		"stage_finish":
			if race_phase == RACE_PLAYING:
				race_phase = RACE_ENDING
				_switch_to_ending()
			elif race_phase == RACE_ARMED or race_phase == RACE_WAITING:
				race_phase = RACE_OVER
				start_in = -1.0


func _arm_race() -> void:
	race_phase = RACE_ARMED
	race_t = 0.0
	start_in = -1.0
	go_offset_s = NAN
	_alive_t = 0.0
	countdown_paused = false
	_race_piece = race_piece(race_index)
	if not _race_piece.is_empty():
		_race_piece["key"] = "race/%s#%d" % [_race_piece["id"], _race_gen]


func _start_race() -> void:
	race_phase = RACE_PLAYING
	start_in = -1.0
	race_t = 0.0
	# from here on the same physics clock measures how long the piece has played
	_phys_seen = Engine.get_physics_frames()
	_phys_steps = 0
	_wait_dt = 0.0


## Game seconds per physics step (the countdown's dt).
static func _step_s() -> float:
	return Engine.time_scale / float(Engine.physics_ticks_per_second)


## The start comes `left` seconds of game time after now (called from the session's events, inside a physics step).
func _schedule(left: float) -> void:
	_sched_left = left
	start_in = left
	_phys_seen = Engine.get_physics_frames()
	_phys_steps = 0
	_wait_dt = 0.0
	_physics_runs = false


## Game seconds since the last _schedule(): physics steps × their length, or the frame time without physics.
func _waited(frame: ModernAudioFrame) -> float:
	var now := Engine.get_physics_frames()
	if not frame.paused:
		_phys_steps += now - _phys_seen
		_wait_dt += frame.dt
	_phys_seen = now
	if _phys_steps > 0:
		_physics_runs = true
		return _phys_steps * _step_s()
	return _wait_dt if _wait_dt >= WAIT_NO_PHYSICS_S else 0.0


## Music ids of a role (sorted). Placeholders (visible only with audio.modern.placeholders) count only while the role
## has no real piece – a stand-in never takes the turn of a real one.
func _ids_for(role: String) -> Array[String]:
	var out: Array[String] = []
	if ctx == null or ctx.assets == null:
		return out
	var all := ctx.assets.ids("music", "music", role)
	for id in all:
		var e := ctx.assets.entry("music", id)
		if e != null and not e.placeholder:
			out.append(id)
	return out if not out.is_empty() else all


## The race piece for a stage (rotation over the manifest's "race" entries): {id, stream (main clip), ending
## (stream or null), db (gain_db of the entry), countin_s, bpm}; {} when there is none.
func race_piece(index: int) -> Dictionary:
	if ctx == null or ctx.assets == null:
		return {}
	var ids := _ids_for("race")
	if ids.is_empty():
		return {}
	var id := ids[maxi(index, 0) % ids.size()]
	var e := ctx.assets.entry("music", id)
	if e == null:
		return {}
	var bpm := e.bpm if e.bpm > 0.0 else 120.0
	var countin_beats := int(e.meta.get("countin_beats", 0))
	var ending_id := str(e.meta.get("ending", ""))
	return {"id": id, "main": ctx.assets.stream("music", id),
		"ending": ctx.assets.stream("music", ending_id) if ending_id != "" else null,
		"db": e.gain_db, "countin_s": countin_beats * 60.0 / bpm, "bpm": bpm, "bar_beats": e.bar_beats}


# --- the frame -----------------------------------------------------------------------------------------------------

## The piece for the context in force: {key, stream, db, race} or {} for silence. Never a piece without a stream: a
## key that update() notes as started is not started again, so a stream that arrives later would stay silent for good
## (the Arcade title theme is synthesised in a thread when audio.music_file is missing – with the Modern profile
## active at boot it arrives after the menu context was set). While the stream is missing the answer is {}; the
## piece starts in the frame the stream exists.
func resolve() -> Dictionary:
	if context == "off" or not ROLE_OF.has(context):
		return {}
	var db := ctx.mix.music_context_db(context) if ctx.mix != null else 0.0
	if context == "race":
		if not race_music or _race_piece.is_empty():
			return {}
		if race_phase != RACE_PLAYING and race_phase != RACE_ENDING:
			return {}
		var s := race_stream(_race_piece)
		return {"key": str(_race_piece["key"]), "stream": s, "db": db + float(_race_piece["db"]), "race": true} if s != null else {}
	var role := str(ROLE_OF[context])
	var ids := _ids_for(role)
	if ids.is_empty() and role != "title":
		ids = _ids_for("title")
	if not ids.is_empty():
		var e := ctx.assets.entry("music", ids[0])
		var st := ctx.assets.stream("music", ids[0])
		return {"key": "music/" + ids[0], "stream": st, "db": db + e.gain_db} if st != null else {}
	var f: Variant = ctx.fallback_streams.get("music")
	return {"key": ARCADE_KEY, "stream": f, "db": db} if f is AudioStream else {}


func update(frame: ModernAudioFrame) -> void:
	_step_race(frame)
	var want := resolve()
	var key := str(want.get("key", ""))
	if key != _key[_cur] or _target[_cur] <= 0.0:
		if key == "":
			_target[_cur] = 0.0
		else:
			var other := 1 - _cur
			if _key[_cur] == key:
				other = _cur            # the piece is still there (fading out): bring it back
			elif _key[other] != key:
				_start(other, key, want.get("stream"))
				if bool(want.get("race", false)):
					_level[other] = 1.0      # the count-in starts as composed (no fade-in over its first beats)
			_target[_cur] = 0.0
			_cur = other
			_target[_cur] = 1.0
			_db[_cur] = float(want.get("db", 0.0))
	elif key != "":
		_db[_cur] = float(want.get("db", 0.0))
	for i in 2:
		var up := _target[i] > _level[i]
		_level[i] = move_toward(_level[i], _target[i], frame.dt / (fade_in_s if up else fade_out_s))
		if _level[i] <= 0.0 and _target[i] <= 0.0 and _key[i] != "":
			_key[i] = ""
			if i < _players.size():
				_players[i].stop()
				_players[i].stream_paused = false
		elif i < _players.size() and _key[i] != "":
			# equal-power crossfade (the two pieces are uncorrelated)
			_players[i].volume_db = linear_to_db(maxf(sin(_level[i] * PI * 0.5), 0.0001)) + _db[i]
	_pause_countin(frame)


## Scheduled start, start fallback and the clock of the race piece.
func _step_race(frame: ModernAudioFrame) -> void:
	if context != "race":
		return
	match race_phase:
		RACE_WAITING:
			start_in = _sched_left - _waited(frame)
			# start in the frame nearest to the planned moment (the next frame would be about frame.dt late):
			# the start is off by at most half a frame instead of up to a whole one
			if not frame.paused and start_in <= 0.5 * frame.dt:
				_start_race()
		RACE_ARMED:
			if frame.alive:
				_alive_t += frame.dt
				if _alive_t >= START_FALLBACK_S:
					_start_race()
		RACE_PLAYING, RACE_ENDING:
			if _physics_runs:
				var now := Engine.get_physics_frames()
				if not frame.paused:
					_phys_steps += now - _phys_seen
				_phys_seen = now
				race_t = _phys_steps * _step_s()
			elif not frame.paused:
				race_t += frame.dt


## While the tree is paused during the count-in, the race stream pauses with the countdown (it continues in sync).
func _pause_countin(frame: ModernAudioFrame) -> void:
	var want := frame.paused and context == "race" and race_phase == RACE_PLAYING \
		and race_t < float(_race_piece.get("countin_s", 0.0))
	if want == countdown_paused:
		return
	countdown_paused = want
	if _cur < _players.size() and _key[_cur] == str(_race_piece.get("key", "")):
		_players[_cur].stream_paused = want


func _start(i: int, key: String, stream: Variant) -> void:
	_key[i] = key
	_level[i] = 0.0
	if i < _players.size():
		var p := _players[i]
		p.stop()
		p.stream_paused = false
		p.stream = stream as AudioStream if stream is AudioStream else null
		p.volume_db = -80.0
		if p.stream != null:
			p.play()


func _switch_to_ending() -> void:
	if _cur >= _players.size() or _key[_cur] != str(_race_piece.get("key", "")):
		return
	var p := _players[_cur]
	if not p.playing or not p.has_stream_playback():
		return
	var pb := p.get_stream_playback() as AudioStreamPlaybackInteractive
	if pb == null:
		return
	if _race_piece.get("ending") is AudioStream:
		pb.switch_to_clip_by_name(ENDING_CLIP)
	else:
		_target[_cur] = 0.0      # no ending: the loop fades out


## The interactive stream of a race piece (built once per piece and profile).
func race_stream(piece: Dictionary) -> AudioStream:
	var id := str(piece.get("id", ""))
	if _streams.has(id):
		return _streams[id]
	var main: Variant = piece.get("main")
	if not (main is AudioStream):
		return null
	var s := build_race_stream(main, piece.get("ending") as AudioStream if piece.get("ending") is AudioStream else null)
	_streams[id] = s
	return s


## Clip "lauf" (count-in, first phrase and the loop body: an Ogg file that loops from its loop_offset by itself) and
## clip "schluss" (the ending). lauf -> schluss at the next bar line of "lauf" (bpm and bar_beats of its import), the
## ending from its start at full level, the loop cut within 1 ms (FADE_DISABLED: the engine's quickest fade). Any
## longer fade-out lets the loop's next downbeat sound under the ending's first hit – measured over all 88 bar lines
## of race piece 1: the first 100 ms of the ending +1.7 to +4.3 dB louder and true peaks up to +2.2 dBTP (file level)
## for fades of 1/16 to 1/2 beat, against +0.02 dB and the ending's own −2.95 dBTP with the cut, which the ending's
## downbeat masks (it starts with kick, crash and impact). No auto-advance: measured on
## Godot 4.7.2, a clip that auto-advances starts its successor up to one mix step plus the decoder's lead (128 frames)
## too early – a doubled join (docs/audio-modern.md "Musik"); the intro is therefore part of the looping file.
static func build_race_stream(main: AudioStream, ending: AudioStream) -> AudioStreamInteractive:
	var s := AudioStreamInteractive.new()
	s.clip_count = 2 if ending != null else 1
	s.set_clip_name(0, MAIN_CLIP)
	s.set_clip_stream(0, main)
	s.set_clip_auto_advance(0, AudioStreamInteractive.AUTO_ADVANCE_DISABLED)
	if ending != null:
		s.set_clip_name(1, ENDING_CLIP)
		s.set_clip_stream(1, ending)
		s.set_clip_auto_advance(1, AudioStreamInteractive.AUTO_ADVANCE_DISABLED)
		s.add_transition(0, 1, AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BAR,
			AudioStreamInteractive.TRANSITION_TO_TIME_START, AudioStreamInteractive.FADE_DISABLED, 1.0)
	s.initial_clip = 0
	return s


## The piece that is playing or fading in ("" = silence).
func current_key() -> String:
	return _key[_cur] if _target[_cur] > 0.0 else ""


func teardown() -> void:
	for p in _players:
		ModernAudioContext.free_player(p)
	_players.clear()
	_key = ["", ""]
	_streams.clear()
	_race_piece = {}


func debug_state() -> Dictionary:
	var playing := false
	var pos := -1.0
	var clip := -1
	if _cur < _players.size() and _players[_cur].playing:
		playing = true
		pos = _players[_cur].get_playback_position()
		if _players[_cur].has_stream_playback():
			var pb := _players[_cur].get_stream_playback() as AudioStreamPlaybackInteractive
			if pb != null:
				clip = pb.get_current_clip_index()
	return {"context": context, "key": current_key(), "level": _level[_cur], "db": _db[_cur], "playing": playing,
		"position": pos, "race_music": race_music, "race_index": race_index, "race_phase": race_phase,
		"race_t": race_t, "start_in": start_in, "go_offset_s": null if is_nan(go_offset_s) else go_offset_s, "clip": clip,
		"countin_s": float(_race_piece.get("countin_s", 0.0)), "race_piece": str(_race_piece.get("id", "")),
		"countdown_paused": countdown_paused}
