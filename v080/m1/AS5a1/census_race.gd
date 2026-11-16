extends SceneTree
## Scratch tool (AS5a1): which props/city_* sets the race Kiel - Nürnberg (both routes, race direction) and the
## whole network place, how often, at which lateral distance, scale and tint.
##   godot --headless --path . -s <this file> -- [--all]

const Fair := preload("res://tests/race3d/fairness.gd")
# stage id -> start city in race direction
const RACE := {"kiel_hamburg": "kiel", "hamburg_hannover": "hamburg", "hannover_kassel": "hannover",
	"kassel_wuerzburg": "kassel", "wuerzburg_nuernberg": "wuerzburg", "hamburg_bremen": "hamburg",
	"bremen_dortmund": "bremen", "dortmund_frankfurt": "dortmund", "frankfurt_wuerzburg": "frankfurt"}


func _initialize() -> void:
	var all := OS.get_cmdline_user_args().has("--all")
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var total := {}
	var where := {}
	var info := {}
	for dir: Dictionary in Fair.directions(net, [] if all else RACE.keys()):
		var sid := str((dir["stage"] as Dictionary)["id"])
		if not all and str(dir["from"]) != str(RACE[sid]):
			continue
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		var n := t.segment_index_at(t.km_to_z(plan.length_km)) - 1
		var counts := {}
		var first := {}
		for i in range(0, n):
			var s := t.get_segment(i)
			for it: Dictionary in s.sprites:
				if str(it.get("kind", "prop")) != "prop":
					continue
				var key := str(it.get("set", ""))
				if not key.begins_with("props/city_"):
					continue
				counts[key] = int(counts.get(key, 0)) + 1
				if not first.has(key):
					first[key] = snappedf(t.z_to_km(s.z), 0.1)
				var d: Dictionary = info.get(key, {"sc0": INF, "sc1": -INF, "x0": INF, "x1": -INF, "tints": {}, "align": 0,
					"left": 0, "right": 0})
				var sc := float(it.get("scale", 1.0))
				var x := absf(float(it.get("x", 0.0)))
				d["sc0"] = minf(float(d["sc0"]), sc)
				d["sc1"] = maxf(float(d["sc1"]), sc)
				d["x0"] = minf(float(d["x0"]), x)
				d["x1"] = maxf(float(d["x1"]), x)
				if it.has("tint"):
					var tt: Dictionary = d["tints"]
					tt[str(it["tint"])] = int(tt.get(str(it["tint"]), 0)) + 1
				if it.has("align"):
					d["align"] = int(d["align"]) + 1
				if int(it.get("side", 1)) < 0:
					d["left"] = int(d["left"]) + 1
				else:
					d["right"] = int(d["right"]) + 1
				info[key] = d
			t.update_window(s.z, 10.0)
		var label := str(dir["name"])
		for k: String in counts:
			total[k] = int(total.get(k, 0)) + int(counts[k])
			var w: Array = where.get(k, [])
			w.append("%s@%.1f(%d)" % [label, float(first[k]), int(counts[k])])
			where[k] = w
		print("DONE ", label, " ", counts)
	print("==== TOTAL")
	var keys := total.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(total[a]) > int(total[b]))
	for k: Variant in keys:
		var d: Dictionary = info[k]
		print("%-34s %6d  scale %.2f..%.2f  |x| %.1f..%.1f  L/R %d/%d  align %d  tints %s" % [k, int(total[k]),
			float(d["sc0"]), float(d["sc1"]), float(d["x0"]), float(d["x1"]), int(d["left"]), int(d["right"]),
			int(d["align"]), str(d["tints"])])
		var w: Array = where.get(k, [])
		print("    ", ", ".join(w.slice(0, 14)))
	quit(0)
