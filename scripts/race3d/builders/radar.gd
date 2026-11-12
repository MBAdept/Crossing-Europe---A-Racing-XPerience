extends ChunkBuilder
## Radar builder of the mode "Modern" (v0.8.0, contract §6 R6, renderer inventory B/C): the camera flash of the speed
## cameras. The posts themselves are the speed-camera model of the props builder (props/radar_camera, AS1b) at Arcade's
## places (Track: 0.25 km into a radar zone and again in its middle, 0.3 m beyond the shoulder); without the model the
## props builder shows Arcade's sprite. This builder finds the same items and puts a flash lamp at each camera head
## (Arcade's camera box 2.55 – 3.4 m above the road: RoadRenderer._radar_cam), facing the approaching traffic.
## The flash follows view.radar_flash01 like Arcade (the session sets it to 1 when the car is flashed and lets it fall
## within radar.flash_s): every camera in sight flashes, as in Arcade, with Arcade's glow – white, radius 6 m × flash
## (at least a few pixels) – through the flare layer (renderer.add_lamps(), role "on", strength and size set every
## frame from the view; nothing reads the wall clock, the paused picture stands still). The HUD's white flash over
## the screen is the same in both modes.
## Builder rules: build() on worker threads – ctx snapshot only. Owner: R6 (wave 3). Docs: docs/renderer-modern-bauten.md.

const CAMERA_SET := "props/radar_camera"
const HEAD_H := 2.85               ## height of the flash above the ground (Arcade's box 2.55 – 3.4 m, its centre 2.97 m)
const HEAD_FRONT := 0.45           ## the flash sits this far in front of the post (towards the approaching camera)
const FLASH_R_M := 6.0             ## Arcade: glow radius 6 m × flash
const FLASH_GAIN := 2.0            ## flare strength per unit of flash (the flare adds colour × 0.5 × strength; Arcade alpha = flash)
const FLASH_COLOUR := Color(1.0, 1.0, 1.0)
const FLARE_K := 0.9               ## layers/flares.gd STATIC_K: glow radius = size × this

var _flashes: Array = []           ## [[parent Node3D, lamp dictionary], …] of the committed cameras (main thread)
var _level := 0.0


func id() -> String:
	return "radar"


## WORKER THREAD.
func build(ctx: ChunkContext, _input: Variant) -> Dictionary:
	var cams: Array = []
	for i in ctx.row_count() - 1:
		var seg: Dictionary = ctx.segs[i]
		for it: Dictionary in seg["sprites"]:
			if not is_camera(it):
				continue
			var z := float(it.get("z", seg["z"]))
			var x := float(it.get("x", 0.0))
			var g := ctx.ground(z, x)
			var f := ctx.frame(z, x, g)
			cams.append({"pos": f * Vector3(0.0, HEAD_H, HEAD_FRONT), "dir": f.basis.z, "z": snappedf(z, 0.001), "x": snappedf(x, 0.001)})
	if cams.is_empty():
		return {}
	return {"cameras": cams}


## True for a speed camera item of the Track (its set, or Arcade's procedural camera).
static func is_camera(it: Dictionary) -> bool:
	return str(it.get("set", "")) == CAMERA_SET or str(it.get("proc", "")) == "radar_cam" or str(it.get("obj", "")) == "radar_cam"


func commit(ctx: ChunkContext, part: Dictionary, parent: Node3D) -> void:
	var cams: Array = part.get("cameras", [])
	if cams.is_empty():
		return
	var lamps: Array = []
	for c: Dictionary in cams:
		var entry := {"pos": c["pos"], "dir": c["dir"], "role": "on", "color": FLASH_COLOUR, "size": 0.0, "range": 0.0, "energy": 0.0}
		flash_entry(entry, _level)
		lamps.append(entry)
		_flashes.append([parent, entry])
	var renderer: Variant = ctx.services.get("renderer")
	if renderer != null:
		(renderer as Object).call(&"add_lamps", parent, lamps)


## Every frame (main thread): Arcade's flash on every committed camera.
func update(view: Dictionary, _dt: float) -> void:
	_level = clampf(float(view.get("radar_flash01", 0.0)), 0.0, 1.0)
	var i := _flashes.size() - 1
	while i >= 0:
		var e: Array = _flashes[i]
		if not is_instance_valid(e[0]) or not (e[0] as Node).is_inside_tree():
			_flashes.remove_at(i)
		else:
			flash_entry(e[1], _level)
		i -= 1


## The flare of a camera at flash level f (0..1): Arcade's glow – nothing below 0.05, else radius 6 m × f, strength f.
static func flash_entry(entry: Dictionary, f: float) -> void:
	if f <= 0.05:
		entry["energy"] = 0.0
		entry["size"] = 0.0
		return
	entry["energy"] = FLASH_GAIN * f
	entry["size"] = FLASH_R_M * f / FLARE_K


func debug(part: Dictionary) -> Dictionary:
	var out: Array = []
	for c: Dictionary in part.get("cameras", []):
		out.append([c["z"], c["x"]])
	return {"cameras": out}
