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
	p.stop()
	p.stream = null
	p.queue_free()
