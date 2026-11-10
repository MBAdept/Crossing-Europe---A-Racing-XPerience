class_name ModernAudioModule
extends RefCounted
## Base class of a slot of the Modern sound (docs/audio-modern.md "Bausteine"). ModernAudio creates one object per
## slot (ModernAudio.SLOTS: env, engine, layers, road, impact, ambience, traffic, music, sfx), calls the hooks below
## in that order and frees it when the profile ends. A slot owns its players and its part of the configuration
## (audio.modern.<slot>); it gets everything else through `ctx` and the frame and never talks to another slot or
## to the AudioManager.
##
## A package replaces the content of its slot's file and keeps the class name and these hooks – nothing else has
## to change for it to be driven. Hooks a slot does not need stay as they are here.

var ctx: ModernAudioContext = null


## Called by ModernAudio before anything else.
func setup(p_ctx: ModernAudioContext) -> void:
	ctx = p_ctx
	_setup()


## Once, after `ctx` is set: read the configuration (ctx.modern), look up sounds (ctx.assets / ctx.stream()),
## create players under ctx.host on the slot's buses (ctx.player(), only while ctx.live). The buses and their base
## effects exist (ctx.buses).
func _setup() -> void:
	pass


## Session events (contract §4.7.2: "collision", "rail_hit", "radar_flash", "go", "countdown", "stage_finish",
## "refuel_start", "refuel_done") this slot turns into sound itself. ModernAudio then drops the AudioManager.play()
## of the same thing ("crash", "rail", "flash", "go", "beep", "finish", "fuel_start", "fuel_done") when the event
## arrives within 50 ms; a play() without its event still reaches play() below, 50 ms late.
func claims() -> PackedStringArray:
	return PackedStringArray()


## The car of the next stage (vehicle type id, AudioManager.set_vehicle) – load what it needs.
func set_vehicle(_id: String) -> void:
	pass


## AudioManager.set_track(): a stage starts (feed.has_track()) or is over.
func track_changed(_feed: AudioFeed) -> void:
	pass


## Once per frame – in the menus (frame.alive false), in a race and while the tree is paused (frame.paused).
func update(_frame: ModernAudioFrame) -> void:
	pass


## A session event (§4.7.2) or one the AudioFeed derived from the track ("joint", "pass_object", "tunnel_in",
## "tunnel_out", "bridge_in", "bridge_out", "cover_in", "cover_out").
func event(_event_name: String, _args: Dictionary) -> void:
	pass


## One-shot by its AudioManager name ("crash", "rail", "flash", "go", "beep", "finish", "fuel_start", "fuel_done",
## "ui_move", "ui_ok", "ui_back"). true = this slot took it (played or deliberately dropped); the slots are asked
## in the order of ModernAudio.SLOTS, the SfxBank last.
func play(_sound: String, _gain_db: float) -> bool:
	return false


## AudioManager.stop_all(): silent at once (new race, scene change). The music plays on.
func stop_all() -> void:
	pass


## The profile ends or the game quits: stop threads, free the players (ModernAudioContext.free_player), drop
## streams. The buses are removed right after.
func teardown() -> void:
	pass


## Plain data for tests and debugging.
func debug_state() -> Dictionary:
	return {}
