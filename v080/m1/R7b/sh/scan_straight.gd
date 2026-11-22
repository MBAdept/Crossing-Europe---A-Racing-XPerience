extends SceneTree
## scratch: landmarks with a straight approach of 640 m (every stage direction)
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
			var mc := 0.0
			var k0 := int(floor((z - 640.0) / t.seg_len))
			for k in range(maxi(k0, 0), int(floor(z / t.seg_len)) + 1):
				mc = maxf(mc, absf(t.get_segment(k).curve))
			if mc <= 0.03:
				print("GERADE %s %s %s km %.2f curve %.4f side %d" % [str(dir["stage"]["id"]), str(dir["from"]), str(it["set"]), t.z_to_km(z), mc, int(it["side"])])
	quit(0)
