extends SceneTree
## Scratch benchmark: track generation of all stage directions + inner-loop throughput.

func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net: Dictionary = ConfigLoader.load_json("res://data/network.json")
	var countries: Dictionary = (ConfigLoader.load_json("res://data/countries.json") as Dictionary).get("countries", {})
	var cities := {}
	for c: Dictionary in net.get("cities", []):
		cities[str(c["id"])] = c
	var t0 := Time.get_ticks_msec()
	var total := 0
	var dirs := 0
	var maxn := 0
	for s: Dictionary in net.get("stages", []):
		if bool(s.get("dev", false)):
			continue
		for from_id: String in [str(s["from"]), str(s["to"])]:
			var plan := StagePlan.build(s, from_id, cities, countries, cfg)
			var track := Track.new()
			track.setup(plan, cfg, {})
			var n := track.segment_count
			var curve := PackedFloat32Array()
			curve.resize(n)
			for i in n:
				curve[i] = track.get_segment(i).curve
			total += n
			maxn = maxi(maxn, n)
			dirs += 1
	var t1 := Time.get_ticks_msec()
	print("GEN %d dirs, %d segments (max %d) in %d ms = %.1f us/segment" % [dirs, total, maxn, t1 - t0, float(t1 - t0) * 1000.0 / float(total)])
	# inner loop throughput
	var n2 := 3000000
	var a := PackedFloat64Array()
	a.resize(1024)
	for i in 1024:
		a[i] = float(i) * 0.37
	var acc := 0.0
	var bad := 0
	var t2 := Time.get_ticks_usec()
	var cy := 0.8
	var sy := 0.6
	for i in n2:
		var j := i & 1023
		var tx: float = a[j] - a[(j + 7) & 1023]
		var tz: float = a[(j + 13) & 1023] - a[(j + 5) & 1023]
		var vx := tx * cy - tz * sy
		var vz := tx * sy + tz * cy
		var sxa := (a[(j + 3) & 1023] - a[j]) * 711.0 / 150.0
		if absf(sxa) <= 640.0 and not (vz > 0.5 and absf(vx) * 711.0 <= 640.0 * vz):
			bad += 1
		acc += vx
	var t3 := Time.get_ticks_usec()
	print("LOOP %d iterations in %d us = %.3f us/iter (bad %d, acc %f)" % [n2, t3 - t2, float(t3 - t2) / float(n2), bad, acc])
	quit(0)
