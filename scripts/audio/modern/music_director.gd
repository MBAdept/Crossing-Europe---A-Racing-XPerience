class_name MusicDirector
extends ModernAudioModule
## Slot "music" of the Modern sound (contract D29, D30, §4.7; docs/audio-modern.md, section "Musik"): what plays on
## the bus MMusic. Packages AU-D1 (pieces, race piece with count-in and ending) and AU-D2 (rotation of three race
## pieces, interlude, ending variants, stingers).
##
## ModernAudio expects, beyond the hooks of ModernAudioModule:
##   set_context(context, args)   AudioManager.set_music_context: "title" | "menu" | "race_menu" | "race" | "result" | "off"
##   set_legacy(on)               AudioManager.set_music(on) of the existing menu code (see below)
##   set_race_music(on)           option "Musik im Rennen" (default on; the Arcade profile has no race music at all)
##   wanted() -> bool             menu music is on (handed to the Arcade player when the profile switches back)
##   context                      the context in force
##
## Pieces come from assets/audio/modern/music/manifest.json by their role:
##   "title"      the remastered title theme (title and menu screens; also the screens between stages while no
##                "interlude" exists). One Ogg file that loops from its intro's end.
##   "interlude"  the calm loop of the screens between stages: context "race_menu" and – with no piece of the role
##                "result" – "result"; it runs on from the result screen to the stage screen without a restart.
##   "race"       a race piece: one Ogg file = count-in + first phrase, then the loop body (loop_offset), plus the
##                ending named by its entry ("ending", role "race_ending") and its variants ("endings": {"rekord",
##                "finale"}), the stab at the finish line ("ziel") and the stingers ("stingers": {"busted",
##                "out_of_fuel"}) – all in the key of the piece, rendered with its master. Played as an
##                AudioStreamInteractive (build_race_stream): clip "lauf" loops by itself, the switch to an ending clip
##                happens at the next bar line of "lauf" (the ending starts at full level, the loop stops within
##                1 ms – FADE_DISABLED). The race pieces take turns, one per stage, in the order of their "rotation".
##   Without a Modern title the menu contexts play today's title theme (the AudioManager's stream); without a race
##   piece a race is silent.
##
## The race piece and the stage:
##   set_context("race")        a new stage: the next piece is armed (the menu music fades out), nothing plays yet;
##   event "stage_start"        {countdown_s}: play() is scheduled countdown_s − count-in later, so that the first
##                              downbeat after the count-in lands on the countdown's "LOS!" (the count-in is a whole
##                              bar: the interactive stream starts its first clip at 0 and counts bars from there);
##                              every "countdown" {n} re-anchors the schedule (n seconds before "LOS!"), and the wait
##                              is counted in physics steps – the clock of the countdown; the start comes in the frame
##                              nearest to its moment; while the tree is paused during the count-in the stream pauses
##                              too (the countdown stands still); after "LOS!" the pause only filters the music
##                              (ModernMix "pause");
##   event "go"                 the piece starts now if it has not (a countdown shorter than the count-in);
##   event "stage_finish"       {record, last_stage} (claimed: the AudioManager's "finish" jingle does not sound –
##                              ModernAudio.PLAY_EVENTS): the ending variant ("finale" on the last stage of a race,
##                              "rekord" for a new record, else the normal one) at the next bar line; unless that bar
##                              line is within ZIEL_MIN_S, the stab "ziel" sounds at once over the ducked loop. Without
##                              a playing piece ("Musik im Rennen: Aus", or before the piece started) the ending
##                              variant itself sounds at once as a one-shot (the finish sound of the stage).
##                              Leaving the stage for a menu context then holds the ending until it has rung out
##                              before the menu piece fades in (at most HOLD_MAX_S);
##   events "busted", "out_of_fuel"   the stinger of the piece on the next beat, over the music ducked by
##                              audio.modern.music.sting_duck_db – only while the piece plays (they are music);
##   no "stage_start" at all    (tools that drive without a session) the piece starts once the car has been driven
##                              for START_FALLBACK_S.
## Levels: the player plays at ctx.mix.music_context_db(context) + gain_db of the manifest entry; ducking under the
## car, the pause low-pass, the race EQ and the snapshot dips happen on the bus (ModernMix, ModernBuses). Crossfades and
## the ducking under a stinger move the player volume (ramped by the AudioServer per mix step: no clicks).
## The two switches: the game calls set_music(true/false) as it always did and, from wave 2 on, set_music_context
## next to it. The last call wins: set_music(false) = "off"; set_music(true) = "menu" unless a menu context
## ("title", "menu", "race_menu", "result") is already in force; a context call sets exactly that context.
## stop_all() does not stop music. Nothing here exists with the Arcade profile (ModernAudio only lives with Modern).

const BUS := "MMusic"
const MENU_CONTEXTS: Array[String] = ["title", "menu", "race_menu", "result"]
const ROLE_OF := {"title": "title", "menu": "title", "race_menu": "interlude", "result": "result", "race": "race"}
## A role without a piece of its own plays the next one of its list ("result" -> the interlude, then the title).
const ROLE_FALLBACK := {"result": ["interlude", "title"], "interlude": ["title"]}
const ARCADE_KEY := "arcade/music"
const MAIN_CLIP := &"lauf"
const ENDING_CLIP := &"schluss"
## Ending variants (manifest "endings" of a race piece) -> clip names of the interactive stream.
const VARIANT_CLIPS := {"rekord": &"schluss_rekord", "finale": &"schluss_finale"}
## Race piece: armed (waiting for the stage), waiting (start scheduled), playing, ending (switched to the ending),
## over (the stage finished before the piece started).
const RACE_IDLE := "idle"
const RACE_ARMED := "armed"
const RACE_WAITING := "waiting"
const RACE_PLAYING := "playing"
const RACE_ENDING := "ending"
const RACE_OVER := "over"
const START_FALLBACK_S := 0.5      ## no "stage_start": start once the car has been driven this long
const ZIEL_MIN_S := 0.3            ## the stab at the finish line only when the ending's bar line is further away
const HOLD_TAIL_S := 1.2           ## a held ending hands over this long before it has rung out completely
const HOLD_MAX_S := 10.0           ## … and never holds a menu piece back longer than this
const STING_EVENTS := {"busted": "busted", "out_of_fuel": "out_of_fuel"}

var context := "off"
var race_music := true
var fade_in_s := 0.4
var fade_out_s := 0.6
var sting_duck_db := -9.0          ## the race piece under a stinger (audio.modern.music.sting_duck_db)
var sting_attack_s := 0.05
var sting_release_s := 1.0

var race_phase := RACE_IDLE
var race_index := -1               ## stages with music context "race" so far − 1 (rotation of the race pieces)
var race_t := 0.0                  ## seconds the race piece has played (game time, without pauses)
var music_t := 0.0                 ## seconds the race stream has played (also during a pause after "LOS!") – its bar grid
var start_in := -1.0               ## seconds until the scheduled start (−1 = none)
var go_offset_s := NAN             ## at "go": race_t − count-in (0 = the downbeat lands on "LOS!"); NAN = not measured
var countdown_paused := false      ## the stream is paused because the tree is paused during the count-in
var ending_variant := ""           ## the ending asked for at the finish ("normal", "rekord", "finale")
var hold_left := 0.0               ## seconds a menu context still leaves the finish music alone
var stingers_played: Dictionary = {}   ## stinger id -> times (tests)
var last_sting := ""

var _players: Array[AudioStreamPlayer] = []
var _sting_player: AudioStreamPlayer = null
var _key: Array[String] = ["", ""]       ## the piece each of the two players holds ("" = none)
var _level := PackedFloat32Array([0.0, 0.0])
var _target := PackedFloat32Array([0.0, 0.0])
var _db := PackedFloat32Array([0.0, 0.0])
var _cur := 0
var _race_gen := 0
var _race_piece: Dictionary = {}         ## the piece of the current stage (race_piece())
var _alive_t := 0.0
var _streams: Dictionary = {}            ## piece id -> AudioStreamInteractive (built once per profile)
var _claims := PackedStringArray()
## stinger: the one waiting for its beat {"stream", "id", "db", "len_s", "at"} and the ducking of the race piece
var _sting_wait: Dictionary = {}
var _duck_db := 0.0
var _duck_hold := 0.0
var _duck_release_s := 1.0
var _hold_key := ""                      ## the race key a menu context keeps while hold_left runs ("" = the stinger)
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
	sting_duck_db = minf(ctx.number("music.sting_duck_db", sting_duck_db), 0.0)
	sting_release_s = maxf(ctx.number("music.sting_release_s", sting_release_s), 0.05)
	for i in 2:
		var p := ctx.player(BUS, "Music%d" % i)
		if p != null:
			p.volume_db = -80.0
			_players.append(p)
	_sting_player = ctx.player(BUS, "MusicSting")
	# the finish is music when a race piece brings its endings: the AudioManager's "finish" jingle (C major) would
	# sound against them – the director takes the event and makes the finish sound itself (ModernAudio.PLAY_EVENTS)
	_claims = PackedStringArray()
	for id in race_ids():
		var e := ctx.assets.entry("music", id)
		if e != null and str(e.meta.get("ending", "")) != "":
			_claims.append("stage_finish")
			break


func claims() -> PackedStringArray:
	return _claims


# --- contexts ------------------------------------------------------------------------------------------------------

func set_context(p_context: String, _args: Dictionary = {}) -> void:
	var c := p_context if ModernMix.CONTEXTS.has(p_context) else "off"
	if c == "race":
		# every call is a new stage (also a restart of the same stage): the next race piece, armed
		race_index += 1
		_race_gen += 1
		_arm_race()
	elif race_phase != RACE_IDLE:
		_leave_race(MENU_CONTEXTS.has(c))
	if c == "off":
		hold_left = 0.0
	context = c


func set_legacy(on: bool) -> void:
	if not on:
		context = "off"
		hold_left = 0.0
		if race_phase != RACE_IDLE:
			race_phase = RACE_IDLE
			start_in = -1.0
	elif not MENU_CONTEXTS.has(context):
		if race_phase != RACE_IDLE:
			_leave_race(true)
		context = "menu"


## The stage is left: an ending (or the finish sound) that still rings is held for a menu context – the menu piece
## follows it – and dropped for any other.
func _leave_race(to_menu: bool) -> void:
	if not to_menu:
		hold_left = 0.0
	elif hold_left > 0.0:
		_hold_key = str(_race_piece.get("key", "")) if race_phase == RACE_ENDING else ""
	race_phase = RACE_IDLE
	start_in = -1.0
	_sting_wait = {}


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
			_finish(bool(args.get("record", false)), bool(args.get("last_stage", false)))
		"busted", "out_of_fuel":
			if race_phase == RACE_PLAYING and race_audible():
				var sid := str((_race_piece.get("stingers", {}) as Dictionary).get(STING_EVENTS[event_name], ""))
				if sid != "":
					_queue_sting(sid, true)


## The finish: the ending variant at the next bar line (with the stab now), or – without a playing piece – the
## variant as the finish sound at once.
func _finish(record: bool, last_stage: bool) -> void:
	if race_phase == RACE_ENDING or race_phase == RACE_OVER:
		return
	ending_variant = "finale" if last_stage else ("rekord" if record else "normal")
	_sting_wait = {}
	var ends: Dictionary = _race_piece.get("ending_ids", {})
	var end_id := str(ends.get(ending_variant, ends.get("normal", "")))
	if race_phase == RACE_PLAYING and race_audible():
		race_phase = RACE_ENDING
		var to_bar := time_to_bar()
		if to_bar >= ZIEL_MIN_S and str(_race_piece.get("ziel", "")) != "":
			# the stab now, the loop ducked until the ending's bar line
			_queue_sting(str(_race_piece["ziel"]), false, maxf(to_bar - 0.03, 0.0), 0.03)
		_switch_to_ending(ending_variant)
		hold_left = minf(to_bar + _seconds_of(end_id) - HOLD_TAIL_S, HOLD_MAX_S)
	else:
		# no playing piece: the variant is the finish sound
		race_phase = RACE_OVER
		start_in = -1.0
		if end_id != "":
			_queue_sting(end_id, false)
			hold_left = minf(_seconds_of(end_id) - HOLD_TAIL_S, HOLD_MAX_S)


func _arm_race() -> void:
	race_phase = RACE_ARMED
	race_t = 0.0
	music_t = 0.0
	start_in = -1.0
	go_offset_s = NAN
	_alive_t = 0.0
	countdown_paused = false
	ending_variant = ""
	hold_left = 0.0
	_hold_key = ""
	_sting_wait = {}
	_duck_hold = 0.0
	_duck_db = 0.0
	if _sting_player != null:
		_sting_player.stop()
	_race_piece = race_piece(race_index)
	if not _race_piece.is_empty():
		_race_piece["key"] = "race/%s#%d" % [_race_piece["id"], _race_gen]


func _start_race() -> void:
	race_phase = RACE_PLAYING
	start_in = -1.0
	race_t = 0.0
	music_t = 0.0
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


## Music ids of a role (sorted by "rotation", then id). Placeholders (visible only with audio.modern.placeholders)
## count only while the role has no real piece – a stand-in never takes the turn of a real one.
func _ids_for(role: String) -> Array[String]:
	var out: Array[String] = []
	if ctx == null or ctx.assets == null:
		return out
	var all := ctx.assets.ids("music", "music", role)
	for id in all:
		var e := ctx.assets.entry("music", id)
		if e != null and not e.placeholder:
			out.append(id)
	var use := out if not out.is_empty() else all
	use.sort_custom(func(a: String, b: String) -> bool:
		var ra := int(ctx.assets.entry("music", a).meta.get("rotation", 99))
		var rb := int(ctx.assets.entry("music", b).meta.get("rotation", 99))
		return ra < rb or (ra == rb and a < b))
	return use


## The race pieces in the order they take turns.
func race_ids() -> Array[String]:
	return _ids_for("race")


## The race piece for a stage (rotation over the manifest's "race" entries): {id, main (stream), ending (stream or
## null), variants {"rekord": stream, "finale": stream}, ending_ids {"normal", "rekord", "finale"}, ziel (id),
## stingers {"busted": id, "out_of_fuel": id}, db (gain_db of the entry), countin_s, bpm, bar_beats, bar_s}; {} when
## there is none.
func race_piece(index: int) -> Dictionary:
	if ctx == null or ctx.assets == null:
		return {}
	var ids := race_ids()
	if ids.is_empty():
		return {}
	var id := ids[maxi(index, 0) % ids.size()]
	var e := ctx.assets.entry("music", id)
	if e == null:
		return {}
	var bpm := e.bpm if e.bpm > 0.0 else 120.0
	var countin_beats := int(e.meta.get("countin_beats", 0))
	var ending_id := str(e.meta.get("ending", ""))
	var ending_ids := {}
	if ending_id != "" and ctx.assets.has("music", ending_id):
		ending_ids["normal"] = ending_id
	var variants := {}
	var ends: Variant = e.meta.get("endings", {})
	if ends is Dictionary:
		for v: String in VARIANT_CLIPS:
			var vid := str((ends as Dictionary).get(v, ""))
			if vid != "" and ctx.assets.has("music", vid):
				ending_ids[v] = vid
				variants[v] = ctx.assets.stream("music", vid)
	var stingers := {}
	var st: Variant = e.meta.get("stingers", {})
	if st is Dictionary:
		for k: String in (st as Dictionary):
			var sid := str((st as Dictionary)[k])
			if sid != "" and ctx.assets.has("music", sid):
				stingers[k] = sid
	var ziel := str(e.meta.get("ziel", ""))
	return {"id": id, "main": ctx.assets.stream("music", id),
		"ending": ctx.assets.stream("music", ending_id) if ending_id != "" else null, "variants": variants,
		"ending_ids": ending_ids, "ziel": ziel if ziel != "" and ctx.assets.has("music", ziel) else "",
		"stingers": stingers, "db": e.gain_db, "countin_s": countin_beats * 60.0 / bpm, "bpm": bpm,
		"bar_beats": e.bar_beats, "bar_s": maxf(e.bar_beats, 1) * 60.0 / bpm}


## The race piece can be heard: the option is on and the current player holds it.
func race_audible() -> bool:
	return race_music and not _race_piece.is_empty() and _cur < 2 and _key[_cur] == str(_race_piece.get("key", "")) \
		and _target[_cur] > 0.0


## Seconds to the next bar line of the race stream (its bar grid starts at the file's frame 0 – the count-in is one
## whole bar – and the loop body is whole bars long).
func time_to_bar() -> float:
	var bar := float(_race_piece.get("bar_s", 0.0))
	if bar <= 0.0:
		return 0.0
	var into := fposmod(music_t, bar)
	return bar - into if into > 1.0e-4 else 0.0


## Seconds to the next beat of the race stream.
func time_to_beat() -> float:
	var beat := float(_race_piece.get("bar_s", 0.0)) / maxf(float(_race_piece.get("bar_beats", 4)), 1.0)
	if beat <= 0.0:
		return 0.0
	var into := fposmod(music_t, beat)
	return beat - into if into > 1.0e-4 else 0.0


func _seconds_of(id: String) -> float:
	var e := ctx.assets.entry("music", id) if ctx != null and ctx.assets != null and id != "" else null
	return e.seconds() if e != null else 0.0


# --- stingers ------------------------------------------------------------------------------------------------------

## A stinger of the piece: on the next beat (on_beat) or now; the race piece is ducked while it plays (duck_s: how
## long, −1 = the stinger's musical length; release_s: how fast it comes back, −1 = sting_release_s).
func _queue_sting(id: String, on_beat: bool, duck_s: float = -1.0, release_s: float = -1.0) -> void:
	var e := ctx.assets.entry("music", id)
	if e == null:
		return
	var bars := float(e.meta.get("bars", 1))
	var len_s := bars * float(_race_piece.get("bar_s", 60.0 / maxf(e.bpm, 1.0) * 4.0))
	var db := (ctx.mix.music_context_db("race") if ctx.mix != null else 0.0) + e.gain_db
	_sting_wait = {"id": id, "stream": ctx.assets.stream("music", id), "db": db,
		"duck_s": len_s if duck_s < 0.0 else duck_s, "release_s": sting_release_s if release_s < 0.0 else release_s,
		"in": time_to_beat() if on_beat else 0.0}


func _step_sting(frame: ModernAudioFrame) -> void:
	if not _sting_wait.is_empty():
		var left := float(_sting_wait["in"])
		if left <= 0.5 * frame.dt:
			var id := str(_sting_wait["id"])
			last_sting = id
			stingers_played[id] = int(stingers_played.get(id, 0)) + 1
			if _sting_player != null and _sting_wait["stream"] is AudioStream:
				_sting_player.stop()
				_sting_player.stream = _sting_wait["stream"]
				_sting_player.volume_db = float(_sting_wait["db"])
				_sting_player.play()
			if race_audible() or race_phase == RACE_ENDING:
				_duck_hold = float(_sting_wait["duck_s"])
				_duck_release_s = float(_sting_wait["release_s"])
			_sting_wait = {}
		else:
			_sting_wait["in"] = left - frame.dt
	# the race piece under the stinger: down in sting_attack_s, held, back in _duck_release_s
	if _duck_hold > 0.0:
		_duck_db = move_toward(_duck_db, sting_duck_db, absf(sting_duck_db) * frame.dt / sting_attack_s)
		_duck_hold -= frame.dt
	else:
		_duck_db = move_toward(_duck_db, 0.0, absf(sting_duck_db) * frame.dt / maxf(_duck_release_s, 0.01))


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
	if hold_left > 0.0:
		# the finish music of the stage rings out first: the race piece's ending keeps playing, or (finish sound
		# on the stinger player) the menu piece waits
		if _hold_key != "" and _key[_cur] == _hold_key and _target[_cur] > 0.0:
			return {"key": _hold_key, "stream": null, "db": _db[_cur], "race": true}
		if _hold_key == "":
			return {}
	var role := str(ROLE_OF[context])
	var ids := _ids_for(role)
	for fb: String in ROLE_FALLBACK.get(role, ["title"] if role != "title" else []):
		if not ids.is_empty():
			break
		ids = _ids_for(fb)
	if not ids.is_empty():
		var e := ctx.assets.entry("music", ids[0])
		var st := ctx.assets.stream("music", ids[0])
		return {"key": "music/" + ids[0], "stream": st, "db": db + e.gain_db} if st != null else {}
	var f: Variant = ctx.fallback_streams.get("music")
	return {"key": ARCADE_KEY, "stream": f, "db": db} if f is AudioStream else {}


func update(frame: ModernAudioFrame) -> void:
	_step_race(frame)
	if hold_left > 0.0 and not frame.paused:
		hold_left = maxf(hold_left - frame.dt, 0.0)
		if hold_left <= 0.0:
			_hold_key = ""
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
	_step_sting(frame)
	var race_key := str(_race_piece.get("key", ""))
	for i in 2:
		var up := _target[i] > _level[i]
		_level[i] = move_toward(_level[i], _target[i], frame.dt / (fade_in_s if up else fade_out_s))
		if _level[i] <= 0.0 and _target[i] <= 0.0 and _key[i] != "":
			_key[i] = ""
			if i < _players.size():
				_players[i].stop()
				_players[i].stream_paused = false
		elif i < _players.size() and _key[i] != "":
			# equal-power crossfade (the two pieces are uncorrelated); the race piece ducks under a stinger
			var duck := _duck_db if _key[i] == race_key or _key[i] == _hold_key else 0.0
			_players[i].volume_db = linear_to_db(maxf(sin(_level[i] * PI * 0.5), 0.0001)) + _db[i] + duck
	_pause_countin(frame)


## Scheduled start, start fallback and the clocks of the race piece.
func _step_race(frame: ModernAudioFrame) -> void:
	# the stream's own clock: it runs while the piece plays – also in a pause after "LOS!" (only filtered then)
	if (race_phase == RACE_PLAYING or race_phase == RACE_ENDING) and not countdown_paused:
		music_t += frame.dt
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


func _switch_to_ending(variant: String) -> void:
	if _cur >= _players.size() or _key[_cur] != str(_race_piece.get("key", "")):
		return
	var p := _players[_cur]
	if not p.playing or not p.has_stream_playback():
		return
	var pb := p.get_stream_playback() as AudioStreamPlaybackInteractive
	if pb == null:
		return
	var variants: Dictionary = _race_piece.get("variants", {})
	if VARIANT_CLIPS.has(variant) and variants.get(variant) is AudioStream:
		pb.switch_to_clip_by_name(VARIANT_CLIPS[variant])
	elif _race_piece.get("ending") is AudioStream:
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
	var s := build_race_stream(main, piece.get("ending") as AudioStream if piece.get("ending") is AudioStream else null,
		piece.get("variants", {}))
	_streams[id] = s
	return s


## Clip "lauf" (count-in, first phrase and the loop body: an Ogg file that loops from its loop_offset by itself), clip
## "schluss" (the ending) and the variants ("schluss_rekord", "schluss_finale"). lauf -> every ending at the next bar
## line of "lauf" (bpm and bar_beats of its import), the ending from its start at full level, the loop cut within 1 ms
## (FADE_DISABLED: the engine's quickest fade). Any longer fade-out lets the loop's next downbeat sound under the
## ending's first hit – measured over all 88 bar lines of race piece 1: the first 100 ms of the ending +1.7 to +4.3 dB
## louder and true peaks up to +2.2 dBTP (file level) for fades of 1/16 to 1/2 beat, against +0.02 dB and the ending's
## own −2.95 dBTP with the cut, which the ending's downbeat masks (it starts with kick, crash and impact). No
## auto-advance: measured on Godot 4.7.2, a clip that auto-advances starts its successor up to one mix step plus the
## decoder's lead (128 frames) too early – a doubled join (docs/audio-modern.md "Musik"); the intro is therefore part
## of the looping file.
static func build_race_stream(main: AudioStream, ending: AudioStream, variants: Dictionary = {}) -> AudioStreamInteractive:
	var s := AudioStreamInteractive.new()
	var clips: Array = [[MAIN_CLIP, main]]
	if ending != null:
		clips.append([ENDING_CLIP, ending])
	for v: String in VARIANT_CLIPS:
		if variants.get(v) is AudioStream:
			clips.append([VARIANT_CLIPS[v], variants[v]])
	s.clip_count = clips.size()
	for i in clips.size():
		s.set_clip_name(i, clips[i][0])
		s.set_clip_stream(i, clips[i][1])
		s.set_clip_auto_advance(i, AudioStreamInteractive.AUTO_ADVANCE_DISABLED)
		if i > 0:
			s.add_transition(0, i, AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BAR,
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
	ModernAudioContext.free_player(_sting_player)
	_sting_player = null
	_key = ["", ""]
	_streams.clear()
	_race_piece = {}
	_sting_wait = {}


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
		"race_t": race_t, "music_t": music_t, "start_in": start_in,
		"go_offset_s": null if is_nan(go_offset_s) else go_offset_s, "clip": clip,
		"countin_s": float(_race_piece.get("countin_s", 0.0)), "race_piece": str(_race_piece.get("id", "")),
		"countdown_paused": countdown_paused, "ending_variant": ending_variant, "hold_left": hold_left,
		"duck_db": _duck_db, "last_sting": last_sting, "sting_waiting": str(_sting_wait.get("id", "")),
		"stingers_played": stingers_played.duplicate(), "rotation": race_ids(), "claims": Array(_claims),
		"sting_playing": _sting_player != null and _sting_player.playing}
