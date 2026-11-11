extends Node2D
## Canvas of the sign atlas (mode "Modern", contract §6 R3; docs/renderer-modern.md §10): draws road signs with
## Arcade's frozen SignPainter – the same boards, colours and lettering as in Arcade – into the SubViewport of a
## SignAtlas. Every job is one sign: its item (kind, text, value, country, road …; drawn without posts – the 3D signs
## have real posts) at the pixel position of its ground point, at `ppm` pixels per metre. Lit with white, fully
## opaque: the light of the 3D scene comes later, in assets/shaders/modern/sign.gdshader.
## Owner: R3.

var jobs: Array = []                 ## [{"item": Dictionary, "at": Vector2 (px of the ground point), "ppm": float}]
var batch := GeoBatch.new()
var painter := SignPainter.new()


func setup_painter(countries: Dictionary) -> void:
	painter.setup(self, batch)
	painter.countries = countries
	queue_redraw()


func _draw() -> void:
	batch.begin(get_canvas_item())
	for j: Dictionary in jobs:
		var at: Vector2 = j["at"]
		painter.draw(j["item"], Vector3(at.x, at.y, float(j["ppm"])), Color.WHITE, 1.0, Vector2.ZERO)
	batch.flush()
