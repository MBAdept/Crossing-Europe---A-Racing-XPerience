class_name SfxBank
extends ModernAudioModule
## Slot "sfx" of the Modern sound: the one-shots nobody else takes – menu sounds, countdown, radar flash, fuel,
## finish – on MUI and MSfx (and, if the impact slot leaves them, crash and guardrail on MImpact).
##
## play(name, gain_db) is asked last (after every other slot). A name is
##   • an AudioManager name ("ui_move", "beep", "flash", …): ROUTES gives its folder and bus; the sound is the
##     Modern file <folder>/<name> when the manifest has one (level: its gain_db, bus: its "bus" if set), else
##     today's SfxSynth stream with today's level (ARCADE_DB = AudioManager.ONESHOT_DB);
##   • "<folder>/<id>" of any one-shot in the manifests (stingers, new sounds of later packages).
## Variants ("files" in the manifest) are played in turn.

## AudioManager name -> [folder of the Modern file, bus]
const ROUTES := {
	"ui_move": ["ui", "MUI"], "ui_ok": ["ui", "MUI"], "ui_back": ["ui", "MUI"], "beep": ["ui", "MUI"], "go": ["ui", "MUI"],
	"finish": ["ui", "MUI"], "flash": ["sfx", "MSfx"], "fuel_start": ["sfx", "MSfx"], "fuel_done": ["sfx", "MSfx"],
	"crash": ["sfx", "MImpact"], "rail": ["sfx", "MImpact"],
}
## Levels of the Arcade streams (AudioManager.ONESHOT_DB; a test keeps the two tables equal).
const ARCADE_DB := {
	"crash": -1.0, "rail": -5.0, "flash": -3.0, "go": -4.0, "beep": -6.0, "finish": -3.0, "fuel_start": -5.0,
	"fuel_done": -4.0, "ui_move": -12.0, "ui_ok": -8.0, "ui_back": -9.0,
}
const VOICES := 4                ## players per bus

var counts: Dictionary = {}      ## name -> one-shots played (tests)
var sources: Dictionary = {}     ## name -> "modern" | "arcade" of the last play (tests)
var _pools: Dictionary = {}      ## bus -> ModernAudioVoices
var _variant: Dictionary = {}    ## "folder/id" -> next variant


func _setup() -> void:
	for bus: String in ["MUI", "MSfx"]:
		_pool(bus)


## The voices of a bus (created on first use; an unknown bus name plays on MSfx).
func _pool(bus: String) -> ModernAudioVoices:
	var b := bus if ModernBuses.names().has(bus) else "MSfx"
	if not _pools.has(b):
		_pools[b] = ModernAudioVoices.new().attach(ctx, b, VOICES, "Sfx" + b)
	return _pools[b]


func play(sound: String, gain_db: float) -> bool:
	var folder := ""
	var id := sound
	var bus := "MSfx"
	var fallback := ""
	if sound.contains("/"):
		folder = sound.get_slice("/", 0)
		id = sound.get_slice("/", 1)
		if not ctx.is_modern(folder, id):
			return false
	elif ROUTES.has(sound):
		folder = str(ROUTES[sound][0])
		bus = str(ROUTES[sound][1])
		fallback = sound
	else:
		return false
	var stream: AudioStream = null
	var db := gain_db
	var e: ModernAudioAssets.Entry = ctx.assets.entry(folder, id) if ctx.assets != null else null
	if e != null and e.kind != "bank":
		var key := folder + "/" + id
		var v := int(_variant.get(key, 0)) % e.files.size()
		_variant[key] = v + 1
		stream = ctx.assets.stream(folder, id, v)
		db += e.gain_db
		if e.bus != "":
			bus = e.bus
		sources[sound] = "modern"
	if stream == null and fallback != "":
		var f: Variant = ctx.fallback_streams.get(fallback)
		stream = f as AudioStream if f is AudioStream else null
		db = gain_db + float(ARCADE_DB.get(fallback, -4.0))
		sources[sound] = "arcade"
	counts[sound] = int(counts.get(sound, 0)) + 1
	_pool(bus).play(stream, db)
	return true


func stop_all() -> void:
	for bus: String in _pools:
		(_pools[bus] as ModernAudioVoices).stop_all()


func teardown() -> void:
	for bus: String in _pools:
		(_pools[bus] as ModernAudioVoices).release()
	_pools.clear()


func debug_state() -> Dictionary:
	return {"plays": counts.duplicate(), "sources": sources.duplicate()}
