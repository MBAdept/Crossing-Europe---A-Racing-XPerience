extends SceneTree
## R7a: sampling error of the kernel (no margin) against the exhaustive reference, per cam_step, on the unit cases.
const SynTrack := preload("res://tests/race3d/synthetic_track.gd")
const T := preload("res://tests/unit/race3d/test_sight_corridor.gd")


func _mk(curves: PackedFloat32Array, opts: Dictionary, cam: int, row: int, simple: float = 1.2) -> Array:
	var t: Track = SynTrack.new()
	var o := {"lanes": 2.0, "road": "landstrasse"}
	o.merge(opts, true)
	t.fill(ConfigLoader.load_merged(), curves, PackedFloat32Array(), o)
	var p := RoadPath3D.new()
	p.setup(t, 0, 120.0)
	var tp := TerrainProfile.new()
	tp.setup(p, t, {}, {})
	tp.sight.cam_step = cam
	tp.sight.row_step = row
	tp.sight.simple_turn = simple
	return [t, p, tp.sight]


func _initialize() -> void:
	var arc_n := int(round(PI * 0.85 * 90.0 / 3.0))
	var cases := [
		["long", SynTrack.join([SynTrack.straight(150), SynTrack.arc(400, 250.0), SynTrack.straight(150)]), {}, 230, 470],
		["short", SynTrack.join([SynTrack.straight(200), SynTrack.arc(20, 150.0), SynTrack.straight(200)]), {}, 120, 300],
		["before", SynTrack.join([SynTrack.straight(300), SynTrack.arc(200, 200.0), SynTrack.straight(150)]), {}, 180, 420],
		["s", SynTrack.join([SynTrack.straight(150), SynTrack.arc(80, 200.0), SynTrack.arc(80, -200.0), SynTrack.straight(150)]), {}, 120, 360],
		["hairpin", SynTrack.join([SynTrack.straight(40), SynTrack.arc(30, 90.0), SynTrack.straight(8), SynTrack.arc(arc_n, -90.0),
			SynTrack.straight(8), SynTrack.arc(30, 90.0), SynTrack.straight(80)]), {}, 58, 78 + arc_n + 20],
		["lanes", SynTrack.join([SynTrack.straight(150), SynTrack.arc(120, 300.0), SynTrack.straight(100)]),
			{"lanes": 3.0, "road": "autobahn", "fuel_lane": [150, 200]}, 150, 260],
	]
	var steps := [[1, 1, 1.2], [1, 1, 0.0]]
	for c: Array in cases:
		var ref: Array = []
		for st: Array in steps:
			var m := _mk(c[1], c[2], int(st[0]), int(st[1]), float(st[2]))
			var sc: SightCorridor = m[2]
			if ref.is_empty():
				var nb := int(ceil(300.0 / 3.0)) + 2
				ref = T._brute(m[0], m[1], sc, maxi(int(c[3]) - nb, 0), int(c[4]), int(c[3]), int(c[4]))
			var short := 0.0
			var short_at := ""
			var over := 0.0
			var t0 := Time.get_ticks_usec()
			for si in 2:
				var side := -1 if si == 0 else 1
				var r: PackedFloat32Array = ref[si]
				for j in range(int(c[3]), int(c[4]) + 1):
					var want := r[j - int(c[3])]
					var got := sc.width(j, side) - SightCorridor.MARGIN_M
					if want > 0.0:
						if want - got > short:
							short = want - got
							short_at = "%d/%d (%.1f)" % [j, side, want]
						over = maxf(over, got - want)
			print("STEPS %-8s cam %d row %d simple %.1f: short max %.3f at %s, over max %.3f, cameras %d, %.0f us/camera" % [c[0], int(st[0]), int(st[1]), float(st[2]), short, short_at, over,
				sc.cameras, float(sc.usec) / float(maxi(1, sc.cameras - sc.skipped))])
	quit(0)
