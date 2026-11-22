extends SceneTree
const SynTrack := preload("res://tests/race3d/synthetic_track.gd")

func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var envs := SightCorridor.envelopes(cfg)
	for e: Dictionary in envs:
		print("ENV safe1 %.1f m/s vtop %.1f m/s brake %.2f" % [e["safe1"], e["vtop"], e["brake"]])
	for R: float in [140.0, 200.0, 300.0, 400.0, 600.0, 1200.0]:
		var t: Track = SynTrack.new()
		t.fill(cfg, SynTrack.join([SynTrack.straight(400), SynTrack.arc(300, R), SynTrack.straight(500)]))
		var p := RoadPath3D.new()
		p.setup(t, 0, 120.0)
		var tp := TerrainProfile.new()
		tp.setup(p, t, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), {})
		print("R %5.0f: L(row 500) %.0f m, need %.0f m, corridor right row 520 %.1f m, row 410 %.1f, row 395 %.1f, row 380 %.1f m, old band %.1f" % [R, tp.sight.chord_at(500), tp.sight.need_at(503),
			tp.corridor_width(520, 1), tp.corridor_width(410, 1), tp.corridor_width(395, 1), tp.corridor_width(380, 1), 300.0 * 300.0 / 8.0 / (R - 5.625) - 2.5])
	quit(0)
