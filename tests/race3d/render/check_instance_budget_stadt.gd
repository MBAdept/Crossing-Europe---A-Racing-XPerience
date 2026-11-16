extends "res://tests/race3d/render/check_instance_budget.gd"
## The instance-uniform check of check_instance_budget.gd at a city finish at the preset "Hoch" WITH a full vehicle
## budget (RINT-M2, contract §11.3 A-19): Würzburg – Nürnberg from km 106 into Nürnberg at 50 km/h – the city
## buildings of AS5a (baked, vpbr_static), the street furniture and lamps of R6, the city builder, the finish – with 48
## injected test cars (the vehicle layer must reach 90 % of its INSTANCE_BUDGET, see the base class). Nothing of the
## city may take instance uniforms: the whole scene stays at or below SCENE_LIMIT and the engine never refuses.
## render-check-timeout: 2400
## Render check (Xvfb): tools/run_render_checks.sh modern runs it.
## Prints "RENDER-CHECK instanzen_stadt OK|FEHLER …"; exit code 0 when it passes.


func _race_setup() -> Dictionary:
	return {"mode": "single", "race_id": "", "stage_id": "wuerzburg_nuernberg", "from_city": "wuerzburg", "vehicle": "limousine",
		"start_world_minutes": 12.0 * 60.0, "weather": "normal", "start_km": 106.0, "autopilot": true, "seed": 11,
		"gfx": "modern", "no_countdown": true, "start_speed_kmh": 50.0}


func _preset() -> String:
	return "high"


func _sim_s() -> float:
	return 20.0


func _inject_n() -> int:
	return 48


func _check_name() -> String:
	return "instanzen_stadt"
