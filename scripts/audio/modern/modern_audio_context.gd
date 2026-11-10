class_name ModernAudioContext
extends RefCounted
## What every slot of the Modern sound gets from ModernAudio (ModernAudioModule.ctx): configuration, sound files,
## buses, the mix plan, the node that owns the players, and the Arcade resources the stand-in slots fall back to.
## Slots read from it; they never reach into the AudioManager or into another slot.

var cfg: Dictionary = {}                 ## the game configuration (with --audio-config overrides)
var modern: Dictionary = {}              ## cfg.audio.modern
var host: Node = null                    ## parent of every player (the ModernAudio node)
## Players exist and sound plays. False in headless runs and unit tests: the slots then only keep their state
## (gearbox, voices, contexts) – as the Arcade AudioManager, which plays nothing headless.
var live := false
## Engine mixer on the main thread: --audio-sync or audio.modern.engine_thread = false (tests, Movie Maker).
var sync := false
var buses: ModernBuses = null
var assets: ModernAudioAssets = null
var mix: ModernMix = null
## AudioManager's own streams by name – the SfxSynth sounds ("crash", "wind", "ui_move", …) and the title theme
## ("music"). Read only; a name is missing while Arcade has not built it (headless).
var fallback_streams: Dictionary = {}
## The Arcade TrafficAudio with its loaded sounds (read only), null without it.
var arcade_traffic: TrafficAudio = null
## vehicle id -> EngineBank (the Arcade cycle bank, cached by the AudioManager), null without a bank.
var bank_provider := Callable()


## A value of audio.modern by its dotted path.
func value(path: String, default: Variant = null) -> Variant:
	return ConfigLoader.lookup(modern, path, default)


func number(path: String, default: float = 0.0) -> float:
	var v: Variant = ConfigLoader.lookup(modern, path, default)
	return float(v) if (v is float or v is int) else default


## The stream of a Modern sound; without one (or while it is only a placeholder) the Arcade stream `fallback`
## ("" = none). null = nothing to play.
func stream(folder: String, id: String, fallback: String = "") -> AudioStream:
	var s: AudioStream = assets.stream(folder, id) if assets != null else null
	if s == null and fallback != "":
		var f: Variant = fallback_streams.get(fallback)
		if f is AudioStream:
			s = f
	return s


## True when the sound comes from a Modern file (not from the Arcade fallback).
func is_modern(folder: String, id: String) -> bool:
	return assets != null and assets.has(folder, id)


## A player under the host on a Modern bus (null while not live).
func player(bus: String, node_name: String = "") -> AudioStreamPlayer:
	if not live or host == null:
		return null
	var p := AudioStreamPlayer.new()
	if node_name != "":
		p.name = node_name
	p.bus = bus
	host.add_child(p)
	return p


## Stops a player, releases its stream and frees it (teardown of a slot).
static func free_player(p: AudioStreamPlayer) -> void:
	if p == null or not is_instance_valid(p):
		return
	if p.stream is AudioStreamGenerator:
		keep_alive(p.stream)
	p.stop()
	p.stream = null
	p.queue_free()


## Streams that must outlive their playback: [[stream, release at ticks ms], …]
static var _kept: Array = []
const KEEP_ALIVE_MS := 2000


## Holds a reference to a generator stream for KEEP_ALIVE_MS. Call it before the player of an
## AudioStreamGenerator is stopped and freed: the engine's AudioStreamGeneratorPlayback keeps a plain pointer to
## its AudioStreamGenerator and the audio thread still mixes a fade-out block after stop(). When the player is
## freed in the same frame, the stream goes with it and the mixer reads the sample rate from freed memory.
## Measured (Godot 4.7.2, profile switches with a running engine and a preview, playback forced in a headless run):
## without this the audio thread hung in 4 of 29 runs – spinning in the resampler with a sample rate of −2.1e37
## read through the dangling pointer, the main thread blocked on the audio lock; with it 0 of 30
## (docs/audio-modern.md "Fallen").
static func keep_alive(stream: Resource) -> void:
	release_kept()
	if stream != null:
		_kept.append([stream, Time.get_ticks_msec() + KEEP_ALIVE_MS])


## Number of streams held at the moment (tests: they are not leaks).
static func kept_count() -> int:
	return _kept.size()


## Drops the kept streams whose time is over (called every frame by ModernAudio).
static func release_kept() -> void:
	if _kept.is_empty():
		return
	var now := Time.get_ticks_msec()
	while not _kept.is_empty() and int(_kept[0][1]) <= now:
		_kept.pop_front()
