import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
pairs = [
# doc
('''## Nothing here depends on a quality level except the shadow (levels.shadow_casters >= 1: "structures") – what''',
 '''##  * FIX1 (QA QB-03: the Köhlbrand bridge read as a dam): on bridge segments (water, outside tunnels) Arcade's railing
##    at the outer deck edge (RoadRenderer._bridge_structures: the shoulder edge + Track.BRIDGE_DECK_EXTRA_M outside
##    the City Limits) in the bridge's colour – a steel railing with a concrete kerb, posts every second segment; a
##    stone parapet for "stone_arch", a low wall for "causeway", an iron railing for "canal". Until the bridge
##    builder of M2 (R5) builds decks, girders and pylons.
## Nothing here depends on a quality level except the shadow (levels.shadow_casters >= 1: "structures") – what'''),
# constants
('''const ROUGH_REFLECTOR := Vector2(0.2, 0.0)
''', '''const ROUGH_REFLECTOR := Vector2(0.2, 0.0)
const ROUGH_RAILING := Vector2(0.5, 0.3)
const ROUGH_STONE := Vector2(0.9, 0.0)
const CONCRETE := Color("b9b5aa")             ## RoadRenderer.CONCRETE
const BRIDGE_EXTRA_M := 0.4                   ## Track.BRIDGE_DECK_EXTRA_M
'''),
# collect: bridge colours
('''func collect(ctx: ChunkContext) -> Variant:
	if not _configured:
		configure(ctx.cfg)
	return null''', '''func collect(ctx: ChunkContext) -> Variant:
	if not _configured:
		configure(ctx.cfg)
	# the colour of every bridge in the chunk (Track.bridges is main-thread data; Arcade: RoadRenderer._bridge_color)
	var colours := {}
	if ctx.track != null:
		for seg: Dictionary in ctx.segs:
			if not bool(seg["water"]):
				continue
			var bi := int(seg["bridge_i"])
			if colours.has(bi):
				continue
			var c := ""
			if bi >= 0 and bi < ctx.track.bridges.size():
				c = str(ctx.track.bridges[bi].get("color", ""))
			colours[bi] = Color(c) if c != "" else RoadRenderer.RAIL.get(str(seg["bridge"]), RoadRenderer.RAIL["river"])
	return {"bridge_colours": colours}'''),
# build signature uses input
('''func build(ctx: ChunkContext, _input: Variant) -> Dictionary:
	var buf := Buf.new()''', '''func build(ctx: ChunkContext, input: Variant) -> Dictionary:
	var buf := Buf.new()
	var bridge_colours: Dictionary = (input as Dictionary).get("bridge_colours", {}) if input is Dictionary else {}
	var railing_segments := 0'''),
# railing per segment: inside the per-segment loop, before the guardrail side loop
('''		var seg_index := int(sa["index"])
		for side: int in [-1, 1]:
			if not has_rail(sa, sb, side):
				continue''', '''		var seg_index := int(sa["index"])
		if bool(sa["water"]) and not bool(sa["tunnel"]):
			railing_segments += 1
			var rc: Color = bridge_colours.get(int(sa["bridge_i"]), RoadRenderer.RAIL["river"])
			for side: int in [-1, 1]:
				_railing(buf, ctx, i, z0, z1, side, str(sa["bridge"]), rc, bool(sa["city"]), seg_index)
		for side: int in [-1, 1]:
			if not has_rail(sa, sb, side):
				continue'''),
# result counts
('''	return {"arrays": arrays, "vertices": buf.v.size(), "triangles": buf.idx.size() / 3, "rail_left": rail_segments[0],
		"rail_right": rail_segments[1], "posts": posts, "delineators": delineators, "reflectors": reflectors}''',
 '''	return {"arrays": arrays, "vertices": buf.v.size(), "triangles": buf.idx.size() / 3, "rail_left": rail_segments[0],
		"rail_right": rail_segments[1], "posts": posts, "delineators": delineators, "reflectors": reflectors,
		"railing_segments": railing_segments}'''),
('''		"rail_right": int(part.get("rail_right", 0)), "posts": int(part.get("posts", 0)), "delineators": int(part.get("delineators", 0)),
		"reflectors": (part.get("reflectors", []) as Array).size()}''', '''		"rail_right": int(part.get("rail_right", 0)), "posts": int(part.get("posts", 0)), "delineators": int(part.get("delineators", 0)),
		"reflectors": (part.get("reflectors", []) as Array).size(), "railing_segments": int(part.get("railing_segments", 0))}'''),
]
for old, new in pairs:
    assert s.count(old) == 1, old[:80]
    s = s.replace(old, new)
anchor = '''## One delineator post at road position (z, x): white, a black band near the top, the reflector on the face that'''
assert s.count(anchor) == 1
helper = open(sys.argv[2], encoding='utf-8').read()
s = s.replace(anchor, helper + anchor)
open(p, 'w', encoding='utf-8').write(s)
print('ok')
