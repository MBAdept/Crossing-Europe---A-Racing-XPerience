import sys
p = sys.argv[1] + '/tests/unit/race3d/test_structures.gd'
s = open(p).read()


def rep(old, new):
    global s
    assert old in s, old[:80]
    s = s.replace(old, new)


rep('''	var got := {"covers": 0, "fronts": 0, "pillars": 0, "pools": 0}
	var want := 0
	var letters: Array = []
	var low := 0
	var pillar_at: Array = []
	var roof_end := 0.0''', '''	var got := {"covers": 0, "fronts": 0, "pillars": 0, "pools": 0, "masts": 0}
	var want := 0
	var letters: Array = []
	var low := 0
	var in_corridor: Array = []
	var corridor_mismatch := 0
	var pillar_at: Array = []
	var roof_end := 0.0''')

rep('''		for p: Array in part.get("pillar_at", []):
			if str(p[2]) != "front":
				assert_false(ctx.in_bend_corridor(float(p[0]), float(p[1])), "Pfeiler %s nicht in der Sichtschneise einer Kurve (F7)" % str(p))
		# the roof keeps Arcade's height over the road and its shoulders: nothing lower than its soffit (6 m) there but
		# the luminaires of the light bars (Arcade hangs them at 5.95 m, here 0.1 m below the soffit)
		for v: Vector3 in (part["arrays"] as Array)[Mesh.ARRAY_VERTEX]:
			var rc := _road_coords(ctx, v)
			var ed := t.road_edges_at(rc.x)
			if rc.y > ed.x - t.shoulder_w + 0.01 and rc.y < ed.y + t.shoulder_w - 0.01 and rc.z > 0.05 \\
					and rc.z < ARCADE_ROOF_H - BorderB.BAR_DROP - 0.02:      # (a rigid luminaire on a sloping road: ±1–2 cm)
				low += 1''', '''		var fronts_here: Array = []
		for p: Array in part.get("pillar_at", []):
			if str(p[2]) != "front":
				assert_false(ctx.in_bend_corridor(float(p[0]), float(p[1])), "Pfeiler %s nicht in der Sichtschneise einer Kurve (F7)" % str(p))
			else:
				fronts_here.append(p)
			# the main-thread corridor test of the builder = the chunk's
			for dx: float in [-0.3, 0.0, 0.3, 1.5, 4.0]:
				var px := float(p[1]) + dx * signf(float(p[1]))
				if BorderB.bend_corridor_at(t, ctx.terrain, float(p[0]), px) != ctx.in_bend_corridor(float(p[0]), px):
					corridor_mismatch += 1
		# the roof keeps Arcade's height over the road and its shoulders: nothing lower than its soffit (6 m) there but
		# the luminaires of the light bars (Arcade hangs them at 5.95 m, here 0.1 m below the soffit); in a bend's sight
		# corridor nothing below the soffit but Arcade's front pillars (F7: masts, stays and beams stay above the slab)
		for v: Vector3 in (part["arrays"] as Array)[Mesh.ARRAY_VERTEX]:
			var rc := _road_coords(ctx, v)
			var ed := t.road_edges_at(rc.x)
			if rc.y > ed.x - t.shoulder_w + 0.01 and rc.y < ed.y + t.shoulder_w - 0.01 and rc.z > 0.05 \\
					and rc.z < ARCADE_ROOF_H - BorderB.BAR_DROP - 0.02:      # (a rigid luminaire on a sloping road: ±1–2 cm)
				low += 1
			if rc.z < ARCADE_ROOF_H - 0.05 and ctx.in_bend_corridor(rc.x, rc.y):
				var arcade_pillar := false
				for p: Array in fronts_here:
					if absf(rc.x - float(p[0])) <= BorderB.PLINTH_HALF + 0.05 and absf(rc.y - float(p[1])) <= BorderB.PLINTH_HALF + 0.05:
						arcade_pillar = true
				if not arcade_pillar:
					in_corridor.append(Vector3(snappedf(rc.x, 0.1), snappedf(rc.y, 0.1), snappedf(rc.z, 0.1)))''')

rep('''	assert_eq(low, 0, "über Fahrbahn und Banketten nichts unter 6 m (Arcades Dach)")''',
    '''	assert_eq(low, 0, "über Fahrbahn und Banketten nichts unter 6 m (Arcades Dach)")
	assert_eq(in_corridor.slice(0, 6), [], "in der Sichtschneise der Kurve unter dem Dach nur Arcades vordere Pfeiler (F7)")
	assert_eq(corridor_mismatch, 0, "bend_corridor_at() = ChunkContext.in_bend_corridor()")''')

rep('''	assert_true(kinds.has("Lfront_out") and kinds.has("Lend"), "links ein äußerer Pfeiler vorn und einer am Ende (%s)" % str(kinds))''',
    '''	assert_true(kinds.has("Lfront_out") and kinds.has("Lend"), "links ein äußerer Pfeiler vorn und einer am Ende (%s)" % str(kinds))
	# B-01 of QA-R6: the right side has no pillar (sign under the roof, bend corridor) – it hangs from the two left
	# pillars, which rise to masts with stays over the slab
	var masts := {-1: 0, 1: 0}
	for p: Array in pillar_at:
		if p.size() > 3 and bool(p[3]):
			masts[1 if float(p[1]) > 0.0 else -1] += 1
	assert_eq(masts, {-1: 2, 1: 0}, "das Dach hängt rechts an zwei Masten links (%s)" % str(masts))
	assert_eq(got["masts"], 2, "zwei Masten")''')

rep('''# --- city ----------------------------------------------------------------------------------------------------------
''', '''func test_border_support_plan() -> void:
	var r0 := 6498.0
	var r1 := 6519.0
	var o := BorderB.PILLAR_OUT
	var plan := BorderB.pillar_plan(r0, r1, [[6500.0, 1, 1.4]])
	var far := 1.4 + BorderB.OUT_GAP + BorderB.PILLAR_W * 0.5
	# outside any corridor: every pillar stands, no mast
	var none := BorderB.support_plan(plan, [false, false, false, false])
	assert_eq(none["free"], 0, "beidseitig getragen")
	assert_eq((none["pillars"] as Array).size(), 4, "vier Pfeiler")
	# the right side in a bend corridor: Arcade's front pillar would stand, but it moved out (sign under the roof) and
	# leaves with the end one – the right side hangs from masts on the left pillars
	var hung := BorderB.support_plan(plan, [false, false, true, true])
	assert_eq(hung["free"], 1, "rechts frei")
	assert_eq(hung["pillars"], [[r0 + 0.5, -1, "front", o, true], [r1 - 0.5, -1, "end", o, true]], "links zwei Masten (%s)" % str(hung))
	# Arcade's own front pillar stands even inside the corridor (Arcade draws it there): no mast
	var arcade := BorderB.support_plan(BorderB.pillar_plan(r0, r1, []), [false, false, true, true])
	assert_eq(arcade["free"], 0, "Arcades vorderer Pfeiler trägt")
	assert_true((arcade["pillars"] as Array).has([r0 + 0.5, 1, "front", o, false]), "rechts Arcades vorderer Pfeiler (%s)" % str(arcade))
	# both sides without any (never in the network): the moved-out front pillars stand after all
	var both := BorderB.support_plan(BorderB.pillar_plan(r0, r1, [[6500.0, 1, 1.4], [6501.0, -1, 1.4]]), [true, true, true, true])
	assert_eq(both["free"], 0, "kein Mast ohne getragene Seite")
	assert_eq((both["pillars"] as Array).size(), 2, "die beiden äußeren vorderen Pfeiler (%s)" % str(both))
	assert_true((both["pillars"] as Array).has([r0 + 0.5, 1, "front_out", far, false]), "rechts vorn außen")


# --- city ----------------------------------------------------------------------------------------------------------
''')
open(p, 'w').write(s)
print('ok')
