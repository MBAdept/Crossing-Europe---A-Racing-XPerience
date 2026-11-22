extends SceneTree
## QA-R7b: km of every landmark per stage direction (for picture positions).
const Fair := preload("res://tests/race3d/fairness.gd")

func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	for dir: Dictionary in Fair.directions(net):
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		for it: Dictionary in t.landmarks:
			var z := float(it["z"])
			var k := int(floor(z / t.seg_len))
			var curv := 0.0
			for kk in range(maxi(0, int(floor((z - 640.0) / t.seg_len))), k + 1):
				curv = maxf(curv, absf(t.get_segment(kk).curve))
			print("LMKM %s %s side=%d km=%.2f total=%.2f curve600=%.3f name=%s" % [str(dir["name"]), str(it["set"]), int(it["side"]), t.z_to_km(z),
				t.z_to_km(float(t.segment_count) * t.seg_len), curv, str(it.get("name", ""))])
	quit(0)
