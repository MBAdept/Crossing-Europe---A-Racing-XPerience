#!/usr/bin/env python3
"""QA-R6: writes tests/race3d/check_qa_zeit.gd into a project copy (argv[1]) – check_modern_stage.gd with one check
"qa_zeit": the renderer's GDScript time per frame at normal speed (renderer_zeit's method) at R6 places of DEV."""
import re, sys

proj = sys.argv[1]
src = open(proj + "/tests/race3d/check_modern_stage.gd").read()
src = re.sub(r'const CHECKS := \[[^\]]*\]', 'const CHECKS := ["qa_zeit"]', src, count=1)
src += '''

## QA-R6: renderer time at the R6 places of the test stage (best of two rounds each), next to the plain Autobahn.
func _check_qa_zeit() -> void:
	var places := [["autobahn", 30.0, 150.0, 12], ["station", 18.4, 150.0, 12], ["border", 64.2, 150.0, 12],
		["city", 109.6, 100.0, 12], ["start", 0.0, 60.0, 12], ["station_night", 18.4, 150.0, 21], ["city_night", 109.6, 100.0, 21]]
	for pl: Array in places:
		var best := {}
		for round_i in 2:
			var m := await _drive_time({"stage_id": "dev_testetappe", "from_city": "dev_start", "start_km": float(pl[1]),
				"start_speed_kmh": float(pl[2]), "start_world_minutes": float(pl[3]) * 60.0}, 600, true)
			if best.is_empty() or float(m["total_ms"]) < float(best["total_ms"]):
				best = m
		print("QA-ZEIT %s %s" % [str(pl[0]), JSON.stringify(best)])
	var p: Array[String] = []
	_report("qa_zeit", p, "siehe QA-ZEIT-Zeilen")
'''
open(proj + "/tests/race3d/check_qa_zeit.gd", "w").write(src)
print("written")
