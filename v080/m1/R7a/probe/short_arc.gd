extends SceneTree
const SynTrack := preload("res://tests/race3d/synthetic_track.gd")

func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	for lanes: Array in [[2.0, "landstrasse"], [3.0, "autobahn"]]:
		var t: Track = SynTrack.new()
		t.fill(cfg, SynTrack.join([SynTrack.straight(200), SynTrack.arc(20, 150.0), SynTrack.straight(200)]), PackedFloat32Array(), {"lanes": lanes[0], "road": lanes[1]})
		var p := RoadPath3D.new()
		p.setup(t, 0, 120.0)
		var tp := TerrainProfile.new()
		tp.setup(p, t, {}, {})
		var best := -99.0
		var at := 0
		for k in range(150, 280):
			if tp.sight.width(k, 1) > best:
				best = tp.sight.width(k, 1)
				at = k
		print("SHORT lanes %.0f: L %.0f m, widest %.1f m at row %d (apex 210), apex %.1f m" % [lanes[0], tp.sight.chord_at(170), best, at, tp.sight.width(210, 1)])
	quit(0)
