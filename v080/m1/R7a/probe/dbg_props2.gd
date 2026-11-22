extends SceneTree
const SynTrack := preload("res://tests/race3d/synthetic_track.gd")

func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var t: Track = SynTrack.new()
	t.fill(cfg, SynTrack.join([SynTrack.straight(400), SynTrack.arc(300, 200.0), SynTrack.straight(500)]))
	var p := RoadPath3D.new()
	p.setup(t, 0, 120.0)
	var tp := TerrainProfile.new()
	tp.setup(p, t, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), {})
	var line := ""
	for k in range(376, 448, 2):
		line += "%d:%.1f/%.1f " % [k, tp.corridor_width(k, 1), tp.corridor_width(k, -1)]
	print("CORR ", line)
	quit(0)
