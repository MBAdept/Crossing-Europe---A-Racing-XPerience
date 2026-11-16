import sys

ROOT = sys.argv[1].rstrip("/") + "/"
P = ROOT + "scripts/race3d/builders/station.gd"
t = open(P, encoding="utf-8").read()


def sub(old, new, c=1):
    global t
    assert t.count(old) == c, (old[:80], t.count(old))
    t = t.replace(old, new)


sub("""	var sb := signs_behind(tr, r0, r1)
	job.signs = sb["signs"]""", """	var sb := signs_behind(tr, r0, r1, shared)
	job.signs = sb["signs"]""")
sub("""## of every board on either side up to LOS_FAR beyond it, outside tunnels (end_column_hides())}. Generates the track far
## enough ahead that the curve and crest warnings Track inserts later are in place.
static func signs_behind(tr: Track, r0: float, r1: float) -> Dictionary:
	tr.get_segment(tr.segment_index_at(r1 + LOS_FAR + tr.generation_lead_m()) + 2)
	var signs: Array = []
	var boards: Array = []
	for i in range(tr.segment_index_at(r0), tr.segment_index_at(r1 + LOS_FAR) + 1):
		var s := tr.get_segment(i)
		for sp: Variant in s.sprites:
			var it: Dictionary = sp
			if str(it.get("kind", "")) != "sign" or int(it.get("side", 1)) == 0:
				continue
			var zs := float(it.get("z", s.z))
			var hw := SignPainter.board_half_width(str(it.get("sign", ""))) * float(it.get("scale", 1.0))
			if int(it.get("side", 1)) > 0 and zs <= r1 + SIGN_SCAN_M:
				signs.append([zs, float(it.get("x", 0.0)) + hw - tr.road_edges_at(zs).y])
			if not s.tunnel:
				boards.append([zs, float(it.get("x", 0.0)), hw])
	return {"signs": signs, "boards": boards}""", """## of every board on either side up to LOS_FAR beyond it, outside tunnels (end_column_hides())}. Generates the track far
## enough ahead that the curve and crest warnings Track inserts later are in place. shared: the builder's cache – the
## signs of a segment (final once the track is generated that far) are kept there for the next canopy (RINT-M2).
static func signs_behind(tr: Track, r0: float, r1: float, shared: Variant = null) -> Dictionary:
	tr.get_segment(tr.segment_index_at(r1 + LOS_FAR + tr.generation_lead_m()) + 2)
	var signs: Array = []
	var boards: Array = []
	var ia := tr.segment_index_at(r0)
	var sc: Dictionary = _shared_part(shared, "_signs", ia)
	for i in range(ia, tr.segment_index_at(r1 + LOS_FAR) + 1):
		var got: Variant = sc.get(i)
		if got == null:
			# [z, x, half width, right side, paved edge there, in a tunnel] of the signs of segment i
			var list: Array = []
			var s := tr.get_segment(i)
			for sp: Variant in s.sprites:
				var it: Dictionary = sp
				if str(it.get("kind", "")) != "sign" or int(it.get("side", 1)) == 0:
					continue
				var zs := float(it.get("z", s.z))
				var hw := SignPainter.board_half_width(str(it.get("sign", ""))) * float(it.get("scale", 1.0))
				var right := int(it.get("side", 1)) > 0
				list.append([zs, float(it.get("x", 0.0)), hw, right, tr.road_edges_at(zs).y if right else 0.0, s.tunnel])
			got = list
			sc[i] = list
		for e: Array in got:
			var zs := float(e[0])
			if bool(e[3]) and zs <= r1 + SIGN_SCAN_M:
				signs.append([zs, float(e[1]) + float(e[2]) - float(e[4])])
			if not bool(e[5]):
				boards.append([zs, float(e[1]), float(e[2])])
	return {"signs": signs, "boards": boards}""")
sub("""## next canopy (cache "_lanes", "_curve"), so a station of six canopies is gathered in about four calls. RINT-M2,""",
    """## next canopy (cache "_lanes", "_curve", "_signs"), so a station of six canopies is gathered in a few calls. RINT-M2,""")
open(P, "w", encoding="utf-8").write(t)
print("ok")
