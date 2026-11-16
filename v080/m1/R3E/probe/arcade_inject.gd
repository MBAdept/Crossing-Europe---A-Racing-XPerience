extends RoadRenderer
## R3E scratch (not in the repo): the Arcade renderer with test cars added to its view – the Arcade half of the A/B
## pictures of placed vehicles (the Modern half uses tests/race3d/fixtures/vehicle_probe_renderer.gd).

static var inject: Array = []
static var hide_player := false


func render(v: Dictionary) -> void:
	if inject.is_empty() and not hide_player:
		super.render(v)
		return
	var w := v.duplicate()
	var cars: Array = (w.get("cars", []) as Array).duplicate()
	cars.append_array(inject)
	w["cars"] = cars
	if hide_player and w.get("player", null) is Dictionary:
		var pl: Dictionary = (w["player"] as Dictionary).duplicate()
		pl["visible"] = false
		w["player"] = pl
	super.render(w)
