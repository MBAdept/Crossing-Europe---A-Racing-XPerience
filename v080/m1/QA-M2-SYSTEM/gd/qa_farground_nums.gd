extends SceneTree
## QA-M2-SYSTEM: the numbers behind tests/unit/race3d/test_terrain_builder.gd::test_far_ground_lies_below_the_water_of_a_bridge
## (same synthetic track, same bridge rows): plane with the water term, plane of the road alone, lowest water.

const SynTrack := preload("res://tests/race3d/synthetic_track.gd")


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var n := 1600
	var curves := PackedFloat32Array()
	curves.resize(n)
	for i in n:
		curves[i] = clampf(0.7 * sin(float(i) * 0.011) + 0.3 * sin(float(i) * 0.0047 + 0.5), -0.9, 0.9)
	var t: Track = SynTrack.new()
	t.fill(cfg, curves, SynTrack.grades(n, [[0, 0.03], [400, -0.05], [1100, 0.02]]), {})
	var seg := t.seg_len
	t.bridges.append({"z0": 301.0 * seg, "z1": 361.0 * seg, "depth": 9.0, "slope": 6.0, "type": "river"})
	for k in range(301, 361):
		var s := t.get_segment(k)
		s.water = true
		s.water_depth = 9.0
		s.water_level = -9.0
	var p := RoadPath3D.new()
	p.setup(t, 0, 120.0)
	p.ensure(1500)
	var fg = load("res://scripts/race3d/layers/far_ground.gd").new()
	var with_water: float = fg.target_height(p, t, 600.0, 900.0)
	var road_only: float = fg.lowest_road(p, 600.0, 900.0) - 4.0
	var water_lo := INF
	for k in range(301, 361):
		water_lo = minf(water_lo, p.height(k) - 9.0)
	print("FARGROUND with_water=%.3f road_only=%.3f water_lo=%.3f water_y=%.3f -> the water term %s" % [with_water, road_only,
		water_lo, float(fg.get("water_y")), "decides" if water_lo - 0.3 < road_only else "does NOT decide (water above the road plane)"])
	fg.free()
	quit(0)
