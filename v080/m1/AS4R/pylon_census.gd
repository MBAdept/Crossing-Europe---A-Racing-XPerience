extends SceneTree
## AS4R scratch: every cable-stayed bridge of the network: length, pylons (z, x, side, height_m, cables), the room for a
## cable fan (distance pylon -> nearer bridge end), the bend radius at the pylon (from TrackSegment.curve).
##   godot --headless --path . -s res://tools/kritik/pylon_census.gd

const Fair := preload("res://tests/race3d/fairness.gd")


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var r1 := float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 0.0))
	print("curve_radius_at_1_m ", r1)
	for dir: Dictionary in Fair.directions(net, []):
		var plan := StagePlan.build(dir["stage"], str(dir["from"]), net["cities"], net["countries"], cfg, net["city_db"])
		var t := Track.new()
		t.setup(plan, cfg, net["scenery"])
		var n := t.segment_index_at(t.km_to_z(plan.length_km)) - 1
		var printed := {}
		for i in range(0, n):
			var s := t.get_segment(i)
			for it: Dictionary in s.sprites:
				if str(it.get("set", "")) != "props/bridge_pylon":
					continue
				var z := float(it.get("z", s.z))
				var br: Dictionary = {}
				for b: Dictionary in t.bridges:
					if z >= float(b["z0"]) - 1.0 and z <= float(b["z1"]) + 1.0:
						br = b
				var key := "%s|%d" % [dir["name"], int(br.get("z0", 0))]
				if not printed.has(key):
					printed[key] = true
					print("BRUECKE %s %s km %.2f-%.2f len %.1f depth %.1f" % [dir["name"], str(br.get("name", "")),
						float(br.get("km0", 0)), float(br.get("km1", 0)), float(br.get("z1", 0)) - float(br.get("z0", 0)),
						float(br.get("depth", 0))])
				var e := t.road_edges_at(z)
				var c := s.curve
				var rad := (r1 / absf(c)) if absf(c) > 1e-4 else INF
				print("  PYLON z %.1f side %d x %.2f edges (%.2f, %.2f) height_m %.0f cables %.1f to_z0 %.1f to_z1 %.1f curve %.3f R %.0f" % [
					z, int(it.get("side", 0)), float(it.get("x", 0)), e.x, e.y, float(it.get("height_m", 0)),
					float(it.get("cables", 0)), z - float(br.get("z0", 0)), float(br.get("z1", 0)) - z, c, rad])
			t.update_window(s.z, 10.0)
	quit(0)
