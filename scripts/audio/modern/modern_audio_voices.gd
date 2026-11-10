class_name ModernAudioVoices
extends RefCounted
## A small pool of players for one-shots on one bus (round robin, the oldest voice is cut when all are busy) – the
## Modern counterpart of the AudioManager's eight one-shot players. Without players (ctx.live false) play() only
## counts, so the logic above it stays testable.

var bus := ""
var players: Array[AudioStreamPlayer] = []
var played := 0                  ## one-shots started (or counted while not live)
var last_stream: AudioStream = null
var last_db := 0.0
var _next := 0


func attach(ctx: ModernAudioContext, p_bus: String, voices: int, node_name: String = "") -> ModernAudioVoices:
	release()
	bus = p_bus
	for i in maxi(voices, 1):
		var p := ctx.player(bus, ("%s%d" % [node_name, i]) if node_name != "" else "")
		if p == null:
			break
		players.append(p)
	return self


## Starts a one-shot. false without a stream.
func play(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> bool:
	if stream == null:
		return false
	played += 1
	last_stream = stream
	last_db = volume_db
	if players.is_empty():
		return true
	var p := players[_next]
	_next = (_next + 1) % players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = clampf(pitch, 0.05, 8.0)
	p.play()
	return true


func stop_all() -> void:
	for p in players:
		if is_instance_valid(p):
			p.stop()


func busy() -> int:
	var n := 0
	for p in players:
		if is_instance_valid(p) and p.playing:
			n += 1
	return n


func release() -> void:
	for p in players:
		ModernAudioContext.free_player(p)
	players.clear()
	_next = 0
