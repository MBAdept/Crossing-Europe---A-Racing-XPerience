import re,sys
p='tests/unit/race3d/test_bridge.gd'
s=open(p,encoding='utf-8').read()
old='''	assert_eq(cables, 4 * 2 * Bridge.CABLES_PER_SIDE, "sieben Seile nach vorn und hinten je Pylon")
'''
new='''	# Arcade's number as a literal (RoadRenderer._pylon: "for i in 7", one line forwards and one backwards each) – the
	# builder's own constant would follow any change of it (QA-R5 QR5-05)
	assert_eq(cables, 4 * 2 * 7, "sieben Seile nach vorn und hinten je Pylon wie Arcade (56)")
'''
assert old in s; s=s.replace(old,new)
old='''	if m != null:
		assert_near(float(m.get_shader_parameter("emit_energy")), 0.0, 1.0e-6, "ohne Nachtatlas (M2ZS1)")
		assert_near(float(m.get_shader_parameter("night_albedo")), Bridge.PYLON_NIGHT_ALBEDO, 1.0e-6, "night_albedo 0,45 (M2ZS1)")
'''
new='''	if m != null:
		# set on the copy (null = not set: the shader's default would light the pylon at night) – asserted before the value,
		# so a missing parameter fails here and not as a script error (QA-R5 QR5-05)
		var emit: Variant = m.get_shader_parameter("emit_energy")
		var night: Variant = m.get_shader_parameter("night_albedo")
		assert_true(emit != null, "emit_energy auf der Kopie gesetzt")
		assert_true(night != null, "night_albedo auf der Kopie gesetzt")
		if emit != null:
			assert_near(float(emit), 0.0, 1.0e-6, "ohne Nachtatlas (M2ZS1)")
		if night != null:
			assert_near(float(night), 0.45, 1.0e-6, "night_albedo 0,45 (M2ZS1)")
'''
assert old in s; s=s.replace(old,new)
old='''func test_every_bridge_type_builds() -> void:'''
new='''func test_bridge_lamps_like_arcades_events() -> void:
	# every "bridge_lamp" event of Arcade's track (Track._build_bridge: stone bridges and causeways) is built – as the
	# model with its light entries, or the stand-in post with one lamp (QA-R5 QR5-05)
	for case: Array in [["kassel_wuerzburg", "kassel", "Ludwigsbrücke"], ["mailand_venedig", "mailand", "Ponte della Libertà"]]:
		var t := _track(str(case[0]), str(case[1]))
		var br := _bridge(t, str(case[2]))
		if br.is_empty():
			fail("%s fehlt" % case[2])
			continue
		var built := _build(t, br)
		var seg_lo := INF
		var seg_hi := -INF
		var lamps := 0
		var entries := 0
		for e: Array in built:
			var ctx: ChunkContext = e[0]
			seg_lo = minf(seg_lo, float(ctx.seg_a))
			seg_hi = maxf(seg_hi, float(ctx.seg_a + ctx.row_count() - 1))
			lamps += int(((e[1] as Dictionary).get("counts", {}) as Dictionary).get("lamps", 0))
			entries += ((e[1] as Dictionary).get("lamps", []) as Array).size()
		var arcade := 0
		for k in range(int(seg_lo), int(seg_hi)):
			for ev: Dictionary in t.events_for_segment(k):
				if ev.has("bridge") and str(ev.get("proc", "")) == "bridge_lamp":
					arcade += 1
		assert_true(arcade >= 4, "%s: Arcade hat Brückenlampen (%d)" % [case[2], arcade])
		assert_eq(lamps, arcade, "%s: so viele Brückenlampen wie Arcade" % case[2])
		assert_true(entries >= lamps, "%s: jede Lampe leuchtet (%d Lichteinträge)" % [case[2], entries])


func test_every_bridge_type_builds() -> void:'''
assert old in s; s=s.replace(old,new)
open(p,'w',encoding='utf-8').write(s)
print("ok")
