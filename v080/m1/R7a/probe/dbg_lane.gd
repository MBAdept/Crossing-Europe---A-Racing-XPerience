extends SceneTree
const SynTrack := preload("res://tests/race3d/synthetic_track.gd")
const T := preload("res://tests/unit/race3d/test_sight_corridor.gd")

func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var t: Track = SynTrack.new()
	t.fill(cfg, SynTrack.join([SynTrack.straight(150), SynTrack.arc(120, 300.0), SynTrack.straight(100)]), PackedFloat32Array(),
		{"lanes": 3.0, "road": "autobahn", "fuel_lane": [150, 200]})
	var p := RoadPath3D.new()
	p.setup(t, 0, 120.0)
	var tp := TerrainProfile.new()
	tp.setup(p, t, {}, {})
	var sc: SightCorridor = tp.sight
	var j0 := 180
	var j1 := 196
	# brute per camera: which camera gives the max at each row
	for j in range(j0, j1 + 1):
		var best := -99.0
		var best_a := -1
		for a in range(j - 103, j):
			var r: Array = T._brute(t, p, sc, a, a, j, j)
			var v: float = (r[1] as PackedFloat32Array)[0]
			if v > best:
				best = v
				best_a = a
		print("row %d brute %.2f (camera %d, L %.1f) kernel %.2f" % [j, best, best_a, sc.chord_at(best_a), sc.width(j, 1)])
	quit(0)
