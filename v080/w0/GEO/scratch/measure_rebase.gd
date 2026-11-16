extends SceneTree
## Scratch (GEO): measured precision of the floating origin on a 42-km synthetic road and on the real stage whose
## true path reaches farthest from its start.

const SynTrack := preload("res://tests/race3d/synthetic_track.gd")
const Fair := preload("res://tests/race3d/fairness.gd")


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var n := 14000
	var curves := PackedFloat32Array()
	curves.resize(n)
	for i in n:
		curves[i] = 0.35 * sin(float(i) * 0.011) + 0.2 * sin(float(i) * 0.0037)
	var t: Track = SynTrack.new()
	t.fill(cfg, curves)
	var rx := PackedFloat64Array()
	var rz := PackedFloat64Array()
	rx.resize(n)
	rz.resize(n)
	var x := 0.0
	var z := 0.0
	var a := 0.0
	for i in n:
		rx[i] = x
		rz[i] = z
		var da := float(curves[i]) / 120.0 * 3.0
		x += sin(a + da * 0.5) * 3.0
		z -= cos(a + da * 0.5) * 3.0
		a += da
	var far := 0.0
	for i in n:
		far = maxf(far, Vector2(rx[i], rz[i]).length())
	for rebase: bool in [true, false]:
		var p := RoadPath3D.new()
		p.setup(t, 0, 120.0)
		var ox := 0.0
		var oz := 0.0
		var worst := 0.0
		var worst_shift := 0.0
		var rebases := 0
		var cam := 0
		while cam < n - 700:
			p.ensure(cam + 640)
			if rebase and p.origin_distance(cam) > 2000.0:
				var before := p.point(cam + 300)
				var shift := p.rebase(cam)
				worst_shift = maxf(worst_shift, (p.point(cam + 300) - (before + shift)).length())
				ox = rx[cam]
				oz = rz[cam]
				rebases += 1
			for k: int in [cam, cam + 150, cam + 633]:
				var q := p.point(k)
				worst = maxf(worst, Vector2(q.x - (rx[k] - ox), q.z - (rz[k] - oz)).length())
			cam += 32
		print("REBASE synthetic 42 km (farthest %.1f km from the start), %s: worst position error %.3f mm; rebase jump error %.3f mm; %d rebases" % [
			far / 1000.0, "floating origin every 2 km" if rebase else "origin at the start", worst * 1000.0, worst_shift * 1000.0, rebases])
	# the real network: farthest distance of the true path from its start
	var net := Fair.load_network()
	var best := 0.0
	var best_name := ""
	for dir: Dictionary in Fair.directions(net, ["saragossa_pau", "bukarest_sibiu", "sibiu_timisoara", "wien_budapest", "berlin_warschau", "bordeaux_san_sebastian"]):
		var geo := Fair.build_geo(cfg, net, dir)
		var xs: PackedFloat64Array = geo["x"]
		var zs: PackedFloat64Array = geo["z"]
		for i in range(0, xs.size(), 16):
			var d := maxf(absf(xs[i]), absf(zs[i]))
			if d > best:
				best = d
				best_name = str(geo["name"])
	print("REBASE real stages sampled: largest |coordinate| of the true path %.1f km (%s) -> 32-bit spacing %.2f mm without re-basing" % [
		best / 1000.0, best_name, best * pow(2.0, -23.0) * 1000.0])
	quit(0)
