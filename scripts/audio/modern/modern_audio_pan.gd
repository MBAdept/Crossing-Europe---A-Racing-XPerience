class_name ModernAudioPan
extends RefCounted
## Panned players for the slots of the Modern sound that place a sound left or right (package AU-C1: the wheels of
## one side, a guardrail, a collision, a passed object). Godot's AudioStreamPlayer has no pan; an
## AudioStreamPlayer2D in a small SubViewport with its own listener does (the pattern of the Arcade TrafficAudio):
## its output is L = V·(1 − p), R = V·p with p = 0.5 + 0.5 · x / PAN_PX – a linear law, so a centred player is
## 6 dB lower per channel than a plain one. apply() hides that: a player at pan 0 sounds exactly like a plain
## AudioStreamPlayer at the same level, and any pan keeps the power (equal-power law, √2·cos / √2·sin).
## Without a display (ctx.live false) nothing here is created; the slots keep their state.

const PAN_PX := 64.0              ## half width of the listener's world: x = ±PAN_PX is fully left / right
const SILENT := 0.0005            ## below this linear gain a player stops


## The SubViewport with its listener under `host` (null without a host in the tree).
static func make_viewport(host: Node, node_name: String) -> SubViewport:
	if host == null or not host.is_inside_tree():
		return null
	var vp := SubViewport.new()
	vp.name = node_name
	vp.size = Vector2i(int(PAN_PX), int(PAN_PX))
	vp.audio_listener_enable_2d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(vp)
	var lis := AudioListener2D.new()
	vp.add_child(lis)
	lis.make_current()
	return vp


## A panned player on `bus` in the viewport (null without one).
static func player(vp: SubViewport, bus: String, node_name: String = "") -> AudioStreamPlayer2D:
	if vp == null:
		return null
	var p := AudioStreamPlayer2D.new()
	if node_name != "":
		p.name = node_name
	p.bus = bus
	p.max_distance = 1.0e6
	p.attenuation = 1.0
	var strength := float(ProjectSettings.get_setting("audio/general/2d_panning_strength", 0.5))
	p.panning_strength = clampf(1.0 / maxf(strength, 0.01), 0.0, 3.0)   # x = ±PAN_PX → fully left / right
	p.area_mask = 0
	p.volume_db = -80.0
	vp.add_child(p)
	return p


## Channel gains (left, right) of the equal-power law for pan −1..1, scaled so that pan 0 gives (1, 1).
static func gains(pan: float) -> Vector2:
	var th := (clampf(pan, -1.0, 1.0) + 1.0) * PI * 0.25
	return Vector2(cos(th), sin(th)) * sqrt(2.0)


## Sets level (linear gain, as for a plain player) and pan of a panned player; values that did not change are not
## sent again. Returns false when the gain is below SILENT (the caller stops the player).
static func apply(p: AudioStreamPlayer2D, gain: float, pan: float) -> bool:
	if p == null or gain < SILENT:
		return false
	var g := gains(pan)
	var s := g.x + g.y
	var db := linear_to_db(gain * s)
	if absf(p.volume_db - db) > 0.02:
		p.volume_db = db
	var x := (2.0 * g.y / s - 1.0) * PAN_PX
	if absf(p.position.x - x) > 0.01:
		p.position = Vector2(x, 0.0)
	return true


## Stops and frees a panned player (its streams are imported files, nothing to keep alive).
static func free_player(p: Node) -> void:
	if p == null or not is_instance_valid(p):
		return
	if p is AudioStreamPlayer2D:
		(p as AudioStreamPlayer2D).stop()
		(p as AudioStreamPlayer2D).stream = null
	p.queue_free()
