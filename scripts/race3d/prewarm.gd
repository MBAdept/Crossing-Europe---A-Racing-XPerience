extends RefCounted
## Shader warm-up of a Modern stage (v0.8.0, contract D10), version 1. The GL Compatibility renderer compiles a
## program for every combination of material and light situation at its first use (0.5–1.9 s each on the software
## renderer of the development machine, a visible hitch on any machine). What a stage will show is therefore
## drawn once behind the loading cover:
##  * the real chunks of the start view (road, roadside, terrain, props) – the world is drawn while the stage is
##    prepared – and the nodes every hook hands over in warmup_nodes(), standing on the road in front of the camera;
##  * each of them in every light situation the stage can bring: the engine compiles separate programs for an
##    object that is reached by no positional light, by spot lights, by omni lights, or by both. The player's low
##    beam and the lamp pool of the lights layer come on at dusk and under the first street light – long after the
##    start. So the warm-up runs in PHASES ("plain", "spot", "omni", "spot_omni"), FRAMES drawn frames each, with
##    a spot and an omni light of its own at the camera that reach the whole start view (never the ground: render
##    layer 2 is left out, as by every real light).
## Shadow mode, split blending, filter quality, fog mode and the post path are constant for a stage and identical
## in every phase – that is why quality levels never change them while a stage runs.
## Not covered by version 1: materials that first appear far from the start and are not in any warmup_nodes()
## list (reported by the cold-cache check, docs/renderer-modern.md).
## Loaded by modern_renderer.gd only (no class name). Owner: renderer core (R1).

const PHASES: Array[String] = ["plain", "spot", "omni", "spot_omni"]
const FRAMES := 2                  ## drawn frames per phase
const LIGHT_MASK := 0xFFFFF & ~2   ## like every positional light of the lights layer: not the ground
const SPOT_RANGE_M := 220.0
const OMNI_RANGE_M := 90.0

var phase := -1                    ## index into PHASES while the warm-up runs, PHASES.size() when it is done
var _spot: SpotLight3D
var _omni: OmniLight3D
var _phase_from := 0


## Starts the warm-up: the two lights stand under `parent` (hidden until their phase).
func begin(parent: Node3D, frames_drawn: int) -> void:
	_spot = SpotLight3D.new()
	_spot.name = "WarmupSpot"
	_spot.shadow_enabled = false
	_spot.light_cull_mask = LIGHT_MASK
	_spot.spot_range = SPOT_RANGE_M
	_spot.spot_angle = 65.0
	_spot.light_energy = 0.4
	_spot.visible = false
	parent.add_child(_spot)
	_omni = OmniLight3D.new()
	_omni.name = "WarmupOmni"
	_omni.shadow_enabled = false
	_omni.light_cull_mask = LIGHT_MASK
	_omni.omni_range = OMNI_RANGE_M
	_omni.light_energy = 0.4
	_omni.visible = false
	parent.add_child(_omni)
	phase = 0
	_phase_from = frames_drawn
	_show()


## One step per frame: places the lights at the camera and moves on when the phase has been drawn. Returns true
## when every phase is done (the lights are freed then).
func step(frames_drawn: int, cam: Transform3D) -> bool:
	if phase < 0:
		return true
	if phase >= PHASES.size():
		return true
	if is_instance_valid(_spot):
		_spot.transform = cam
		_omni.transform = Transform3D(Basis.IDENTITY, cam.origin + cam.basis * Vector3(0.0, 0.0, -20.0))
	if frames_drawn - _phase_from < FRAMES:
		return false
	phase += 1
	_phase_from = frames_drawn
	if phase >= PHASES.size():
		finish()
		return true
	_show()
	return false


## Frees the lights (also when the warm-up is cut short).
func finish() -> void:
	phase = PHASES.size()
	if is_instance_valid(_spot):
		_spot.queue_free()
	if is_instance_valid(_omni):
		_omni.queue_free()
	_spot = null
	_omni = null


## 0..1 for the loading overlay.
func progress(frames_drawn: int) -> float:
	if phase < 0:
		return 0.0
	if phase >= PHASES.size():
		return 1.0
	return clampf((float(phase) + clampf(float(frames_drawn - _phase_from) / float(FRAMES), 0.0, 1.0)) / float(PHASES.size()), 0.0, 1.0)


static func frames_total() -> int:
	return PHASES.size() * FRAMES


func _show() -> void:
	var name := PHASES[phase]
	_spot.visible = name.contains("spot")
	_omni.visible = name.contains("omni")
