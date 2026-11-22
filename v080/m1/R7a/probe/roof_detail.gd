extends SceneTree
## R7a probe: the pillars of the hanging border roofs – where they stand against the corridor (old / new).
const Fair := preload("res://tests/race3d/fairness.gd")
const BorderB := preload("res://scripts/race3d/builders/border.gd")
const ROOFS := [["belgrad_sofia", "belgrad", 340.0], ["belgrad_sofia", "sofia", 55.0], ["wien_prag", "prag", 270.0], ["bialystok_kaunas", "kaunas", 90.0]]


func _old(tp: TerrainProfile, track: Track, k: int, side: int) -> float:
	var kap := tp._kappa(k)
	var s := track.get_segment(k)
	var half := s.lanes * track.lane_w * 0.5
	var paved := half if side < 0 else half + s.fuel_lane * track.lane_w
	var k_c := kap.x if side < 0 else kap.y
	var corr := tp.corridor_min_m
	if k_c > 1.0e-7:
		corr = maxf(corr, tp.corridor_chord_m * tp.corridor_chord_m * 0.125 * k_c / maxf(0.05, 1.0 - k_c * paved))
	return maxf(0.0, corr - track.shoulder_w)


func _initialize() -> void:
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var tc: Dictionary = ConfigLoader.lookup(cfg, "graphics.modern.terrain", {})
	for r: Array in ROOFS:
		for dir: Dictionary in Fair.directions(net, [r[0]]):
			if str(dir["from"]) != str(r[1]):
				continue
			var geo := Fair.build_geo(cfg, net, dir, net["scenery"])
			var track: Track = geo["track"]
			var path: RoadPath3D = geo["path"]
			path.set_clear_reach(1842.0)
			var tp := TerrainProfile.new()
			tp.setup(path, track, tc, net["scenery"])
			for zn: Dictionary in track.zones:
				if str(zn.get("kind", "")) != "border" or absf(track.z_to_km(float(zn["z0"])) - float(r[2])) > 1.0:
					continue
				var r0 := floorf(float(zn["z0"]) / track.seg_len) * track.seg_len
				var r1 := ceilf(float(zn["z1"]) / track.seg_len) * track.seg_len
				var signs: Array = []
				for i in range(track.segment_index_at(r0), track.segment_index_at(r1 + BorderB.SIGN_SCAN_M) + 1):
					var s := track.get_segment(i)
					for sp: Variant in s.sprites:
						var it: Dictionary = sp
						if str(it.get("kind", "")) == "sign" and int(it.get("side", 1)) != 0:
							var zs := float(it.get("z", s.z))
							var side := int(it.get("side", 1))
							var ed := BorderB.edges_at(track, zs)
							var edge := ed.y if side > 0 else -ed.x
							var hw := SignPainter.board_half_width(str(it.get("sign", ""))) * float(it.get("scale", 1.0))
							signs.append([zs, side, absf(float(it.get("x", 0.0))) + hw - edge])
				var plan := BorderB.pillar_plan(r0, r1, signs)
				print("ROOF %s km %.2f  rows %d..%d  L at the roof %.0f m" % [dir["name"], track.z_to_km(r0), int(r0 / 3.0), int(r1 / 3.0), tp.sight.chord_at(int(r0 / 3.0) - 3)])
				for p: Array in plan:
					var k := int(floor(float(p[0]) / track.seg_len))
					var sd := int(p[1])
					print("   pillar %-9s side %+d z %.1f  %.2f m beyond the shoulder | corridor there: new %.2f (sight lines %.2f), old %.2f  -> in new %s, in old %s" % [
						str(p[2]), sd, float(p[0]), float(p[3]), tp.corridor_width(k, sd), tp.sight.width(k, sd), _old(tp, track, k, sd),
						str(tp.corridor_width(k, sd) > 6.0 and float(p[3]) <= tp.corridor_width(k, sd)), str(_old(tp, track, k, sd) > 6.0 and float(p[3]) <= _old(tp, track, k, sd))])
			geo["path"] = null
	quit(0)
