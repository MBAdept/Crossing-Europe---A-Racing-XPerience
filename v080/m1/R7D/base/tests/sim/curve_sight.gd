extends SceneTree
## Sight check of all stages (both directions): is braking from the moment a curve becomes visible always
## enough? Rules: tests/sim/sight_check.gd (fog visibility, crests, curve warning signs, reaction time).
##   godot --headless --path . -s res://tests/sim/curve_sight.gd -- [--stage=<id>|all] [--vehicle=gran_turismo]
##       [--weather=snow] [--night] [--reaction=1.0] [--top-speed] [--no-signs] [--tolerance=0.05]
## --top-speed: approach every curve at the top speed (as out of a long straight) instead of accelerating out
## of the previous curve; --no-signs: ignore the curve warning signs.
## --traffic: the traffic case instead of the curves (sight_check.gd check_traffic: stop for the slowest traffic of
## the weather from the moment it comes out of the fog or over a crest), with [--hour=19.5] [--queue=0.9]
## [--target-h=0.75] [--step=15] [--margin=2] [--no-crests] (only the fog: the part the weather decides).
## Output: "SIGHT {...}" per stage direction, "SIGHT-WORST {...}" for the 8 worst stretches, "SIGHT-RESULT",
## exit code 1 if any margin < 0.
## Owner: gameplay module (diagnostics only, no autoloads).

const Sight := preload("res://tests/sim/sight_check.gd")


func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + name:
			return "1"
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return default


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net: Dictionary = ConfigLoader.load_json("res://data/network.json")
	var countries: Dictionary = (ConfigLoader.load_json("res://data/countries.json") as Dictionary).get("countries", {})
	var cities := {}
	for c: Dictionary in net.get("cities", []):
		cities[str(c["id"])] = c
	var opts := {"vehicle": _arg("vehicle", "gran_turismo"), "weather": _arg("weather", "normal"), "night": _arg("night", "") != "",
		"reaction": float(_arg("reaction", "1.0")), "top_speed": _arg("top-speed", "") != "", "signs": _arg("no-signs", "") == "",
		"tolerance": float(_arg("tolerance", "0.05"))}
	var traffic := _arg("traffic", "") != ""
	if traffic:
		opts["curve_tolerance"] = opts["tolerance"]
		if _arg("hour", "") != "":
			opts["hour"] = float(_arg("hour", "12"))
		opts["queue_factor"] = float(_arg("queue", "0.9"))
		opts["target_h"] = float(_arg("target-h", "0.75"))
		opts["step_m"] = float(_arg("step", "15"))
		opts["margin_m"] = float(_arg("margin", "2"))
		opts["crests"] = _arg("no-crests", "") == ""
	var which := _arg("stage", "all")
	var worst: Array = []
	var bad := 0
	var checked := 0
	for s: Dictionary in net.get("stages", []):
		if which != "all" and str(s["id"]) != which:
			continue
		for from_id: String in [str(s["from"]), str(s["to"])]:
			var plan := StagePlan.build(s, from_id, cities, countries, cfg)
			var r: Dictionary = Sight.check_traffic(cfg, plan, opts) if traffic else Sight.check(cfg, plan, opts)
			print("SIGHT ", JSON.stringify(r["summary"]))
			worst.append_array((r["cases"] as Array).slice(0, 3))
			checked += 1
			if r["summary"]["min_margin_m"] != null and float(r["summary"]["min_margin_m"]) < 0.0:
				bad += 1
	worst.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["margin_m"]) < float(b["margin_m"]))
	for i in mini(8, worst.size()):
		print("SIGHT-WORST ", JSON.stringify(worst[i]))
	print("SIGHT-RESULT %s (%d von %d Etappenrichtungen mit negativer Reserve)" % ["OK" if bad == 0 else "FEHLER", bad, checked])
	quit(0 if bad == 0 else 1)
