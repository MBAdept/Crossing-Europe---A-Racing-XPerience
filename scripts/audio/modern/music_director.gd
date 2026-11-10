class_name MusicDirector
extends ModernAudioModule
## Slot "music" of the Modern sound: what plays on the bus MMusic (package AU-D1: remastered title theme, race
## tracks with count-in → loop body → bar-synced ending through AudioStreamInteractive, interlude, stingers).
## ModernAudio expects, beyond the hooks of ModernAudioModule:
##   set_context(context, args)   AudioManager.set_music_context: "title" | "menu" | "race_menu" | "race" | "result" | "off"
##   set_legacy(on)               AudioManager.set_music(on) of the existing menu code (see below)
##   set_race_music(on)           option "Musik im Rennen"
##   wanted() -> bool             menu music is on (handed to the Arcade player when the profile switches back)
##   context                      the context in force
## The level of a context is ctx.mix.music_context_db(context) on the players (ducking and dips happen on the bus).
## Events that matter here: "stage_start" {countdown_s}, "go", "stage_finish" {record, last_stage}, "busted",
## "out_of_fuel". stop_all() does not stop music.
##
## The two switches: the game calls set_music(true/false) as it always did and, from wave 2 on, set_music_context
## next to it. The last call wins: set_music(false) = "off"; set_music(true) = "menu" unless a menu context
## ("title", "menu", "race_menu", "result") is already in force; a context call sets exactly that context.
##
## Stand-in of wave 0: one looping piece per context with a crossfade between pieces – the Modern file of the
## context's role when the manifest of assets/audio/modern/music has one (roles "title", "interlude", "result",
## "race"; several race pieces are played in turn, one per stage), else for the menu contexts today's title theme
## (the AudioManager's stream) and for "race" nothing. The race piece fades out at "stage_finish".

const BUS := "MMusic"
const MENU_CONTEXTS: Array[String] = ["title", "menu", "race_menu", "result"]
const ROLE_OF := {"title": "title", "menu": "title", "race_menu": "interlude", "result": "result", "race": "race"}
const ARCADE_KEY := "arcade/music"

var context := "off"
var race_music := true
var fade_in_s := 0.4
var fade_out_s := 0.6
var _players: Array[AudioStreamPlayer] = []
var _key: Array[String] = ["", ""]       ## the piece each of the two players holds ("" = none)
var _level := PackedFloat32Array([0.0, 0.0])
var _target := PackedFloat32Array([0.0, 0.0])
var _db := PackedFloat32Array([0.0, 0.0])
var _cur := 0
var _race_index := -1
var _race_over := false


func _setup() -> void:
	fade_in_s = maxf(ctx.number("music.fade_in_s", fade_in_s), 0.01)
	fade_out_s = maxf(ctx.number("music.fade_out_s", fade_out_s), 0.01)
	for i in 2:
		var p := ctx.player(BUS, "Music%d" % i)
		if p != null:
			p.volume_db = -80.0
			_players.append(p)


func set_context(p_context: String, _args: Dictionary = {}) -> void:
	var c := p_context if ModernMix.CONTEXTS.has(p_context) else "off"
	if c == "race":
		_race_index += 1     # the next race piece for the next stage
		_race_over = false
	context = c


func set_legacy(on: bool) -> void:
	if not on:
		context = "off"
	elif not MENU_CONTEXTS.has(context):
		context = "menu"


func set_race_music(on: bool) -> void:
	race_music = on


func wanted() -> bool:
	return MENU_CONTEXTS.has(context)


func event(event_name: String, _args: Dictionary) -> void:
	if event_name == "stage_finish":
		_race_over = true


## The piece for the context in force: {key, stream, db} or {} for silence. Never a piece without a stream: a key
## that update() notes as started is not started again, so a stream that arrives later would stay silent for good
## (the Arcade title theme is synthesised in a thread when audio.music_file is missing – with the Modern profile
## active at boot it arrives after the menu context was set). While the stream is missing the answer is {}; the
## piece starts in the frame the stream exists.
func resolve() -> Dictionary:
	if context == "off" or not ROLE_OF.has(context):
		return {}
	if context == "race" and (not race_music or _race_over):
		return {}
	var role := str(ROLE_OF[context])
	var ids: Array[String] = []
	if ctx.assets != null:
		ids = ctx.assets.ids("music", "", role)
		if ids.is_empty() and role != "title" and role != "race":
			ids = ctx.assets.ids("music", "", "title")
	var db := ctx.mix.music_context_db(context) if ctx.mix != null else 0.0
	if not ids.is_empty():
		var id := ids[maxi(_race_index, 0) % ids.size()] if role == "race" else ids[0]
		var e := ctx.assets.entry("music", id)
		var s := ctx.assets.stream("music", id)
		return {"key": "music/" + id, "stream": s, "db": db + e.gain_db} if s != null else {}
	if context == "race":
		return {}
	var f: Variant = ctx.fallback_streams.get("music")
	return {"key": ARCADE_KEY, "stream": f, "db": db} if f is AudioStream else {}


func update(frame: ModernAudioFrame) -> void:
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
		elif i < _players.size() and _key[i] != "":
			_players[i].volume_db = linear_to_db(maxf(_level[i], 0.0001)) + _db[i]


func _start(i: int, key: String, stream: Variant) -> void:
	_key[i] = key
	_level[i] = 0.0
	if i < _players.size():
		var p := _players[i]
		p.stop()
		p.stream = stream as AudioStream if stream is AudioStream else null
		p.volume_db = -80.0
		if p.stream != null:
			p.play()


## The piece that is playing or fading in ("" = silence).
func current_key() -> String:
	return _key[_cur] if _target[_cur] > 0.0 else ""


func teardown() -> void:
	for p in _players:
		ModernAudioContext.free_player(p)
	_players.clear()
	_key = ["", ""]


func debug_state() -> Dictionary:
	var playing := false
	var pos := -1.0
	if _cur < _players.size() and _players[_cur].playing:
		playing = true
		pos = _players[_cur].get_playback_position()
	return {"context": context, "key": current_key(), "level": _level[_cur], "db": _db[_cur], "playing": playing,
		"position": pos, "race_music": race_music, "race_index": _race_index}
