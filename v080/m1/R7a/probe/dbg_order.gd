extends SceneTree
const SynTrack := preload("res://tests/race3d/synthetic_track.gd")

func _mk(curves: PackedFloat32Array) -> SightCorridor:
	var t: Track = SynTrack.new()
	t.fill(ConfigLoader.load_merged(), curves, PackedFloat32Array(), {"lanes": 2.0, "road": "landstrasse"})
	var p := RoadPath3D.new()
	p.setup(t, 0, 120.0)
	var tp := TerrainProfile.new()
	tp.setup(p, t, {}, {})
	return tp.sight

func _initialize() -> void:
	var curves := SynTrack.join([SynTrack.straight(100), SynTrack.arc(90, 160.0), SynTrack.straight(60), SynTrack.arc(70, -110.0), SynTrack.straight(200)])
	var sa := _mk(curves)
	var sb := _mk(curves)
	var fwd := {}
	for j in range(0, 480):
		fwd[j] = sa.width(j, -1)
	var n := 0
	for j in range(479, -1, -1):
		var v := sb.width(j, -1)
		if absf(v - float(fwd[j])) > 1e-6 and n < 12:
			n += 1
			print("row %d fwd %.3f back %.3f  chord a %.1f b %.1f" % [j, fwd[j], v, sa.chord_at(j), sb.chord_at(j)])
	quit(0)
