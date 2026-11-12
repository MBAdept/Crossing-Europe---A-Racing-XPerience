extends "res://tests/race3d/render/check_instance_budget.gd"
## The instance-uniform check of check_instance_budget.gd on a forest stage at the preset "Hoch" (M2INT): Kassel –
## Würzburg from km 46.5 (the spruces and pines of the reference position T1) with the autopilot at 120 km/h, so the
## chunks stream in while the traffic passes. Every tree model of AS3R has a "vpbr" trunk: with the shared vpbr
## material each MultiMesh node of a chunk took 16 slots of the global shader buffer and the scene ran past it at T1,
## T4 and Dortmund – Frankfurt km 121 ("Too many instances using shader instance variables"). Static models draw with
## ModernMaterials.VPBR_STATIC now (no instance uniforms); the vehicles keep theirs.
## Render check (Xvfb): tools/run_render_checks.sh modern runs it.
## Prints "RENDER-CHECK instanzen_wald OK|FEHLER …"; exit code 0 when it passes.


func _race_setup() -> Dictionary:
	return {"mode": "single", "race_id": "", "stage_id": "kassel_wuerzburg", "from_city": "kassel", "vehicle": "kombi",
		"start_world_minutes": 15.0 * 60.0, "weather": "normal", "start_km": 46.5, "autopilot": true, "seed": 12,
		"gfx": "modern", "no_countdown": true, "start_speed_kmh": 120.0}


func _preset() -> String:
	return "high"


func _check_name() -> String:
	return "instanzen_wald"
