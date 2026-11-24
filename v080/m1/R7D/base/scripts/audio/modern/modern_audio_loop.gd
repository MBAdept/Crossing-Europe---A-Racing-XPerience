class_name ModernAudioLoop
extends RefCounted
## One looping sound on a bus whose level and pitch follow a target every frame – for the natively mixed layers of
## the Modern sound (wind, tyres, turbo, rain, …): Godot mixes the loop, the script only moves volume and pitch
## (a player's volume change is ramped across the mix block, so this is click-free).
## Works without a player too (ctx.live false: headless, unit tests) – `level` then just follows the targets.

const SILENT := 0.002            ## below this level the player stops

var player: AudioStreamPlayer = null
var level := 0.0                 ## smoothed linear level 0..1 (before gain_db)
var pitch := 1.0
var gain_db := 0.0               ## fixed offset of this loop (manifest gain, slot level)


## Creates the player (when ctx.live and there is a stream) on `bus`. Returns itself.
func attach(ctx: ModernAudioContext, bus: String, stream: AudioStream, node_name: String = "") -> ModernAudioLoop:
	release()
	if stream != null:
		player = ctx.player(bus, node_name)
		if player != null:
			player.stream = stream
			player.volume_db = -80.0
	return self


## One frame: the level moves towards `target` (0..1) by the factor k (1 − exp(−dt / tau)), the pitch is set.
func drive(target: float, p_pitch: float, k: float) -> void:
	level = lerpf(level, clampf(target, 0.0, 4.0), clampf(k, 0.0, 1.0))
	pitch = clampf(p_pitch, 0.05, 8.0)
	if player == null:
		return
	if level < SILENT:
		if player.playing:
			player.stop()
		return
	if not player.playing:
		player.play()
	player.volume_db = linear_to_db(level) + gain_db
	player.pitch_scale = pitch


## Silent at once (stop_all).
func silence() -> void:
	level = 0.0
	if player != null and player.playing:
		player.stop()


func playing() -> bool:
	return player != null and player.playing


## Frees the player (teardown).
func release() -> void:
	ModernAudioContext.free_player(player)
	player = null
	level = 0.0
