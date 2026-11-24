extends "res://scripts/race3d/modern_renderer.gd"
## Test double of the vehicle checks (R3): the SHIPPED Modern renderer with every layer and builder that exists, plus
## test cars added to the view of every frame (car dictionaries as the race session sends them: kind "car", id,
## set, z = rear, x, length, tail, brake, blink, blink_t, beacon, speed …) – the checks place vehicles where they need
## them (behind a crest, behind a truck, at 300 m) in an otherwise still scene. Static, so the check script sets it
## before the session creates the renderer (RaceRenderers.modern_script = this file).
## Owner: R3 (tests only).

static var inject: Array = []        ## cars appended to view.cars every frame
static var hide_player := false      ## the player car is not drawn (view.player.visible = false)


static func reset() -> void:
	inject = []
	hide_player = false


func render(p_view: Dictionary) -> void:
	if inject.is_empty() and not hide_player:
		super.render(p_view)
		return
	var v := p_view.duplicate()
	var cars: Array = (v.get("cars", []) as Array).duplicate()
	cars.append_array(inject)
	v["cars"] = cars
	if hide_player and v.get("player", null) is Dictionary:
		var pl: Dictionary = (v["player"] as Dictionary).duplicate()
		pl["visible"] = false
		v["player"] = pl
	super.render(v)
