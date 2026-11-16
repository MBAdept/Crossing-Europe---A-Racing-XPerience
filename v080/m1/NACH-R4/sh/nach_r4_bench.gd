extends SceneTree
## NACH-R4 scratch benchmark (not part of the game): cost of flares.gd road_profile() (7 height_at() calls), the
## per-frame work FIX-R4 added for every wet streak (one per car with lit rear lamps, one per static lamp with a streak).

func _initialize() -> void:
	var Flares: GDScript = load("res://scripts/race3d/layers/flares.gd")
	var SynTrack: GDScript = load("res://tests/race3d/synthetic_track.gd")
	var tc: Object = load("res://tests/test_case.gd").new()
	var cfg: Dictionary = tc.call("cfg")
	var n := 1400
	var curves := PackedFloat32Array()
	curves.resize(n)
	var t: Object = SynTrack.new()
	t.call("fill", cfg, curves, SynTrack.call("grades", n, [[0, 0.0], [300, 0.04], [600, 0.0]]))
	var p: Object = load("res://scripts/race3d/road_path.gd").new()
	p.call("setup", t, 0, 120.0)
	p.call("ensure", n - 2)
	var prof := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	var zlo: float = p.call("z_min")
	var zhi: float = float(p.call("last")) * float(p.get("seg_len"))
	var calls := 20000
	var t0 := Time.get_ticks_usec()
	for i in calls:
		Flares.call("road_profile", p, 1100.0 + float(i % 300), 800.0, zlo, zhi, prof)
	var us := float(Time.get_ticks_usec() - t0) / float(calls)
	print("NACH-R4 BENCH road_profile: %.2f us per call (%d calls); 100 streaks per frame = %.3f ms" % [us, calls, us * 100.0 / 1000.0])
	quit(0)
