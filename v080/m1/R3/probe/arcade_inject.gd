extends RoadRenderer
## R3 scratch (not in the repo): the Arcade renderer with test cars added to its view – the Arcade half of the A/B
## pictures of placed vehicles (the Modern half uses tests/race3d/fixtures/vehicle_probe_renderer.gd).

static var inject: Array = []


func render(v: Dictionary) -> void:
	if inject.is_empty():
		super.render(v)
		return
	var w := v.duplicate()
	var cars: Array = (w.get("cars", []) as Array).duplicate()
	cars.append_array(inject)
	w["cars"] = cars
	super.render(w)
