extends SceneTree
## R6 helper: the columns station.column_plan() gives every fuel canopy of every stage direction – how many canopies
## keep both, one or none.
##   godot --headless --path . -s <this>

const Fair := preload("res://tests/race3d/fairness.gd")
const StationB := preload("res://scripts/race3d/builders/station.gd")


func _initialize() -> void:
	var cfg: Dictionary = ConfigLoader.load_merged()
	var net := Fair.load_network()
	var stats := {"canopies": 0, "both": 0, "front_only": 0, "end_only": 0, "none": 0}
	for dir: Dictionary in Fair.directions(net, []):
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		if plan.fuel_lanes.is_empty():
			continue
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		for zn: Dictionary in t.zones:
			if str(zn["kind"]) != "fuel_canopy":
				continue
			var r0 := floorf(float(zn["z0"]) / t.seg_len) * t.seg_len
			var r1 := ceilf(float(zn["z1"]) / t.seg_len) * t.seg_len
			var signs: Array = []
			for i in range(t.segment_index_at(r0), t.segment_index_at(r1 + StationB.SIGN_SCAN_M) + 1):
				var s := t.get_segment(i)
				for sp: Variant in s.sprites:
					var it: Dictionary = sp
					if str(it.get("kind", "")) == "sign" and int(it.get("side", 1)) > 0:
						signs.append(float(it.get("z", s.z)))
			var cols := StationB.column_plan(r0, r1, signs)
			stats["canopies"] += 1
			if cols.size() == 2:
				stats["both"] += 1
			elif cols.is_empty():
				stats["none"] += 1
				print("%s canopy km %.2f: keine Stütze" % [str(dir["name"]), t.z_to_km(r0)])
			elif str(cols[0][1]) == "front":
				stats["front_only"] += 1
			else:
				stats["end_only"] += 1
	print("COLUMNS ", JSON.stringify(stats))
	quit(0)
