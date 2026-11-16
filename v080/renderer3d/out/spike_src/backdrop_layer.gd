extends Node2D
## Spike: the arcade backdrop (RaceBackdrop: sky gradient, sun / moon / stars, clouds, panorama silhouettes of the
## scenery) drawn on a canvas layer that the 3D environment uses as its background (Environment.BG_CANVAS).

var proj: RoadProjection
var batch := GeoBatch.new()
var backdrop := RaceBackdrop.new()
var pal: Dictionary = {}
var heading := 0.0
var time := 0.0
var scen_id := ""
var bg: Dictionary = {}
var haze := 0.0
var base_y := -1.0


func setup(p: RoadProjection) -> void:
	proj = p
	backdrop.setup(proj, batch, 2.5)


func update(palette: Dictionary, head: float, t: float, scenery_id: String, background: Dictionary, hz: float, by: float) -> void:
	pal = palette
	heading = head
	time = t
	scen_id = scenery_id
	bg = background
	haze = hz
	base_y = by
	queue_redraw()


func _draw() -> void:
	if pal.is_empty() or proj == null:
		return
	batch.begin(get_canvas_item())
	backdrop.draw_sky(pal, heading, time)
	backdrop.draw_background(pal, scen_id, bg, heading, time, haze, base_y)
	batch.rect(Rect2(-40, base_y, proj.screen.x + 80, proj.screen.y - base_y + 40), pal["fog"])
	batch.flush()
