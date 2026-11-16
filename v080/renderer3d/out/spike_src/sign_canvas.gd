extends Node2D
## Spike: one road sign drawn by the arcade SignPainter into a SubViewport (transparent), used as a texture in 3D.

var item: Dictionary = {}
var ppm := 64.0
var size := Vector2(384, 448)
var batch := GeoBatch.new()
var signs := SignPainter.new()


func configure(it: Dictionary, countries: Dictionary, px_per_m: float, sz: Vector2) -> void:
	item = it
	ppm = px_per_m
	size = sz
	signs.setup(self, batch)
	signs.countries = countries
	queue_redraw()


func _draw() -> void:
	if item.is_empty():
		return
	batch.begin(get_canvas_item())
	signs.draw(item, Vector3(size.x * 0.5, size.y - 2.0, ppm), Color.WHITE, 1.0, Vector2.ZERO)
	batch.flush()
