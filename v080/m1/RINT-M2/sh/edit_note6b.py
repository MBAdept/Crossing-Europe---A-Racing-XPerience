W = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1/"
wald = '''extends "res://tests/race3d/render/check_instance_budget.gd"
## The instance-uniform check of check_instance_budget.gd on a forest stage at the preset "Hoch" WITH a full vehicle
## budget (M2INT, FIX-M2, RINT-M2): Dortmund – Frankfurt from km 40 (the Sauerland forest of contract §11.3 A-19) with
## the autopilot at 120 km/h, so the chunks stream in, and 48 test cars kept in view from the first picture on (the
## injected traffic of the base class: every car crosses every level of detail, the vehicle layer must reach 90 % of its
## INSTANCE_BUDGET or the check fails as "nicht belastet"). Every tree model of AS3R has a "vpbr" trunk: with the shared
## vpbr material each MultiMesh node of a chunk took 16 slots of the global shader buffer and the scene ran past it at
## T1, T4 and Dortmund – Frankfurt km 121 ("Too many instances using shader instance variables"). Static models draw
## with ModernMaterials.VPBR_STATIC (no instance uniforms); the vehicles keep theirs – with the budget full and the
## forest in view the whole scene must stay at or below SCENE_LIMIT.
## History: FIX-M2 cut the view time to 20 s (the check took 8–49 min under the shared load), which left the vehicle
## layer at 38 of 128 instances – it no longer loaded the budget (NACH-M2 N-02). The injected cars load it at once.
## render-check-timeout: 2400
## Render check (Xvfb): tools/run_render_checks.sh modern runs it.
## Prints "RENDER-CHECK instanzen_wald OK|FEHLER …"; exit code 0 when it passes.


func _race_setup() -> Dictionary:
	return {"mode": "single", "race_id": "", "stage_id": "dortmund_frankfurt", "from_city": "dortmund", "vehicle": "kombi",
		"start_world_minutes": 15.0 * 60.0, "weather": "normal", "start_km": 40.0, "autopilot": true, "seed": 12,
		"gfx": "modern", "no_countdown": true, "start_speed_kmh": 120.0}


func _preset() -> String:
	return "high"


func _sim_s() -> float:
	return 20.0


func _inject_n() -> int:
	return 48


func _check_name() -> String:
	return "instanzen_wald"
'''
stadt = '''extends "res://tests/race3d/render/check_instance_budget.gd"
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
'''
open(W + "tests/race3d/render/check_instance_budget_wald.gd", "w", encoding="utf-8").write(wald)
open(W + "tests/race3d/render/check_instance_budget_stadt.gd", "w", encoding="utf-8").write(stadt)
print("ok")
