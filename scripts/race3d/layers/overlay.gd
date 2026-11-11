extends CanvasLayer
## Overlay layer of the mode "Modern" (v0.8.0, contract §4.4.4): 2D overlays of a race on canvas layer 2 – above the
## 3D picture and the screen post of layer 1, below the HUD (5). Today: the lights of a police chase at the two
## lower corners of the picture (view.chase01, assets/shaders/modern/overlay.gdshader – Arcade's
## RoadRenderer._draw_overlays at any aspect ratio). The radar flash is the HUD's own (hud.flash) in both modes.
## One ColorRect, hidden while nothing is shown: outside a chase the layer costs one comparison per frame.
## The sides change with view.time (no wall clock; the picture freezes with the paused tree).
## Duck-typed layer: setup(renderer), update(view, dt), snapshot(). Owner: renderer core (R1).

const OVERLAY_LAYER := 2
const CHASE_MIN := 0.02            ## below this strength nothing is drawn (Arcade)
const SWAPS_PER_S := 2.5

var rect: ColorRect
var material: ShaderMaterial

var _chase := 0.0
var _swap := false
var _size := Vector2.ZERO


func _init() -> void:
	layer = OVERLAY_LAYER
	rect = ColorRect.new()
	rect.name = "Chase"
	rect.color = Color.BLACK
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.visible = false
	add_child(rect)


func setup(_renderer: Node) -> void:
	material = ShaderMaterial.new()
	material.shader = ModernMaterials.shared().shader("overlay")
	rect.material = material


func update(view: Dictionary, _dt: float) -> void:
	var chase := clampf(float(view.get("chase01", 0.0)), 0.0, 1.0)
	if chase <= CHASE_MIN:
		if rect.visible:
			rect.visible = false
			_chase = 0.0
		return
	var swap := fmod(float(view.get("time", 0.0)) * SWAPS_PER_S, 1.0) >= 0.5
	if not rect.visible:
		rect.visible = true
	if chase != _chase:
		_chase = chase
		material.set_shader_parameter("chase", chase)
	if swap != _swap:
		_swap = swap
		material.set_shader_parameter("swap", 1.0 if swap else 0.0)
	if rect.size != _size:
		_size = rect.size
		material.set_shader_parameter("rect_size", _size)


func snapshot() -> Dictionary:
	return {"overlay": {"chase": snappedf(_chase, 0.0001), "visible": rect.visible, "swap": _swap}}
