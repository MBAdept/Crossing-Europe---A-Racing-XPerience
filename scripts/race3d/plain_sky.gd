extends CanvasLayer
## Built-in plain backdrop of the Modern renderer (skeleton of wave 1, v0.8.0): what ModernRenderer puts on canvas
## layer -10 – the background of the 3D picture (Environment.BG_CANVAS) – while scripts/race3d/layers/backdrop.gd
## does not exist. Arcade's sky gradient of the palette above the horizon row (sky_top -> sky_mid -> sky_bottom,
## the same rows as RaceBackdrop.draw_sky), the fog colour below it (contract D16: the canvas below the horizon is
## filled with the fog colour). No sun, no clouds, no silhouettes – that is the backdrop layer.
## Any window size: the horizon stays on render.horizon_y_frac of the height (the camera's rule, D12/D13).
## --gfx-debug=cover fills the whole canvas with magenta (terrain cover checks count those pixels); with the camera
## inside a tunnel the canvas is the tunnel's darkness.
## Duck-typed like a layer: setup(renderer), update(view, dt), snapshot(). Loaded by the renderer only.
## Owner: renderer package (R1 replaces it by layers/backdrop.gd). Docs: docs/renderer-modern.md.

const BACKDROP_LAYER := -10
const COVER := Color(1.0, 0.0, 1.0)
const MARGIN := 40.0               ## drawn beyond every edge: camera shake moves the picture


## Draws the gradient. Colours and geometry are plain members; the layer redraws it when one of them changes.
class Fill extends Control:
	var top := Color.BLACK
	var mid := Color.BLACK
	var bottom := Color.BLACK
	var fog := Color.BLACK
	var flat := false                ## one colour (`fog`) over everything
	var horizon_frac := 0.45
	var shake := Vector2.ZERO

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_set_transform(shake)
		if flat:
			draw_rect(Rect2(-MARGIN, -MARGIN, w + 2.0 * MARGIN, h + 2.0 * MARGIN), fog)
			return
		var hy := horizon_frac * h
		var my := hy * 0.52
		_band(-MARGIN, my, top, mid, w)
		_band(my, hy + 3.0, mid, bottom, w)
		draw_rect(Rect2(-MARGIN, hy, w + 2.0 * MARGIN, h - hy + MARGIN), fog)

	func _band(y0: float, y1: float, c0: Color, c1: Color, w: float) -> void:
		draw_polygon(PackedVector2Array([Vector2(-MARGIN, y0), Vector2(w + MARGIN, y0), Vector2(w + MARGIN, y1), Vector2(-MARGIN, y1)]),
			PackedColorArray([c0, c0, c1, c1]))


var fill: Fill
var _cover := false
var _signature: Array = []


func _init() -> void:
	layer = BACKDROP_LAYER
	fill = Fill.new()
	fill.name = "Fill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fill)


func setup(renderer: Node) -> void:
	if renderer == null:
		return
	var flags: Variant = renderer.get("debug_flags")
	_cover = flags is Array and (flags as Array).has("cover")
	var proj: RoadProjection = renderer.get("proj")
	if proj != null:
		fill.horizon_frac = proj.horizon_y / maxf(1.0, proj.screen.y)


func update(view: Dictionary, _dt: float) -> void:
	var pal: Dictionary = view.get("palette", {})
	var tunnel := bool(view.get("camera_in_tunnel", false))
	fill.flat = _cover or tunnel
	fill.top = pal.get("sky_top", Color.BLACK)
	fill.mid = pal.get("sky_mid", Color.BLACK)
	fill.bottom = pal.get("sky_bottom", Color.BLACK)
	fill.fog = COVER if _cover else (Palette.TUNNEL_FOG if tunnel else pal.get("fog", Color.BLACK))
	fill.shake = view.get("shake", Vector2.ZERO)
	var sig := [fill.flat, fill.top, fill.mid, fill.bottom, fill.fog, fill.shake, fill.size]
	if sig != _signature:
		_signature = sig
		fill.queue_redraw()


## Colour the canvas shows at a row of a picture of `height` logical pixels (tests; the middle of the picture
## width, no shake).
func color_at(row: float, height: float) -> Color:
	if fill.flat:
		return fill.fog
	var hy := fill.horizon_frac * height
	var my := hy * 0.52
	if row >= hy:
		return fill.fog
	if row < my:
		return fill.top.lerp(fill.mid, clampf((row + MARGIN) / (my + MARGIN), 0.0, 1.0))
	return fill.mid.lerp(fill.bottom, clampf((row - my) / (hy + 3.0 - my), 0.0, 1.0))


func snapshot() -> Dictionary:
	return {"backdrop": {"plain": true, "cover": _cover, "flat": fill.flat, "horizon_frac": fill.horizon_frac}}
