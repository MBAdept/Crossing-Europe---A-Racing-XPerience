extends SceneTree

const SynTrack := preload("res://tests/race3d/synthetic_track.gd")
const TerrainBuilder := preload("res://scripts/race3d/builders/terrain.gd")


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var n := 1600
	var curves := PackedFloat32Array()
	curves.resize(n)
	for i in n:
		curves[i] = clampf(0.7 * sin(float(i) * 0.011) + 0.3 * sin(float(i) * 0.0047 + 0.5), -0.9, 0.9)
	var t: Track = SynTrack.new()
	t.fill(cfg, curves, SynTrack.grades(n, [[0, 0.03], [400, -0.05], [1100, 0.02]]), {"hills": 3})
	var p := RoadPath3D.new()
	p.setup(t, 0, 120.0)
	var tp := TerrainProfile.new()
	tp.setup(p, t, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), {})
	p.set_clear_reach(1842.0)
	p.ensure(9 * 32 + 32 + 700)
	var ctx := ChunkContext.new()
	ctx.cfg = cfg
	ctx.capture(9, 9 * 32, 9 * 32 + 32, p, tp, t)
	var b := TerrainBuilder.new()
	var part := b.build(ctx, b.collect(ctx))
	var verts: PackedVector3Array = part["verts"]
	var idx: PackedInt32Array = part["indices"]
	var grid := ctx.row_count() * ctx.rings * 2
	for i: int in [0, 8, 16, 24, 32]:
		var l := []
		var r := []
		for q in ctx.rings:
			l.append("%.0f/%.1f" % [ctx.ring_offset(i, -1, q), ctx.ring_height(i, -1, q)])
			r.append("%.0f/%.1f" % [ctx.ring_offset(i, 1, q), ctx.ring_height(i, 1, q)])
		print("row ", i, " curve ", ctx.segs[i]["curve"], " L ", l, " R ", r)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for q in 60:
		var side := -1 if q % 2 == 0 else 1
		var z := (float(ctx.seg_a) + rng.randf_range(0.5, 31.5)) * ctx.seg_len
		var row := int(ctx.row_of(z))
		var m := rng.randf_range(1.0, ctx.ribbon_width(z, side) * 0.9)
		var x := float(side) * (ctx.shoulder_edge(row, side) + m)
		var want := ctx.local(z, x, ctx.ground(z, x))
		var found := 0
		for k in range(0, idx.size(), 3):
			if idx[k] >= grid:
				continue
			var a := verts[idx[k]]
			var bb := verts[idx[k + 1]]
			var c := verts[idx[k + 2]]
			var det := (bb.z - c.z) * (a.x - c.x) + (c.x - bb.x) * (a.z - c.z)
			if absf(det) < 1.0e-9:
				continue
			var u := ((bb.z - c.z) * (want.x - c.x) + (c.x - bb.x) * (want.z - c.z)) / det
			var v := ((c.z - a.z) * (want.x - c.x) + (a.x - c.x) * (want.z - c.z)) / det
			if u < 0.0 or v < 0.0 or u + v > 1.0:
				continue
			var hm := a.y * u + bb.y * v + c.y * (1.0 - u - v)
			found += 1
			if absf(hm - want.y) > 0.2:
				print("q %d side %d row %.2f m %.1f: mesh %.2f ground %.2f (tri %d, grid side %d, row %d ring %d) hits so far %d" % [q, side, ctx.row_of(z), m, hm, want.y, k / 3,
					idx[k] / (33 * ctx.rings), (idx[k] % (33 * ctx.rings)) / ctx.rings, idx[k] % ctx.rings, found])
	quit(0)
