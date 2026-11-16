extends SceneTree
## Scratch tool (AS4): which stages place the sets of AS4, how often, where (first km per stage direction).
##   godot --headless --path . -s <this file> -- [--sets=a,b,...]

const Fair := preload("res://tests/race3d/fairness.gd")
const AS4 := ["props/church", "props/factory", "props/house_med", "props/building_block_a", "props/building_block_b",
	"props/building_oldtown", "props/building_shop", "props/building_tall", "props/bridge_lamp", "props/bridge_pylon",
	"props/bridge_truss_arch", "props/houseboat", "props/ferry_ship", "props/windmill", "props/barn"]


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var total := {}
	var where := {}
	var scales := {}
	for dir: Dictionary in Fair.directions(net, []):
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
				if not AS4.has(key):
					continue
				counts[key] = int(counts.get(key, 0)) + 1
				if not first.has(key):
					first[key] = snappedf(t.z_to_km(s.z), 0.1)
				var sc := float(it.get("scale", 1.0))
				var r: Array = scales.get(key, [INF, -INF])
				scales[key] = [minf(r[0], sc), maxf(r[1], sc)]
			t.update_window(s.z, 10.0)
		var label := str(dir["name"])
		for k: String in counts:
			total[k] = int(total.get(k, 0)) + int(counts[k])
			var w: Array = where.get(k, [])
			w.append("%s@%.1f(%d)" % [label, float(first[k]), int(counts[k])])
			where[k] = w
		print("DONE ", label, " ", counts)
	print("==== TOTAL")
	for k: String in AS4:
		print("%-28s %6d  scale %s  stages %d" % [k, int(total.get(k, 0)), str(scales.get(k, [])), (where.get(k, []) as Array).size()])
		var w: Array = where.get(k, [])
		print("    ", ", ".join(w.slice(0, 12)))
	quit(0)
