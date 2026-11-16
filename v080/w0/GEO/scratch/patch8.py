root = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-4/'
p = root + 'tests/unit/race3d/test_chunk_streamer.gd'
s = open(p).read()
a = '''	# a jump beyond the integrated path (the track window moved on): the streamer starts again there
	cam_z = 25300.0
	t.update_window(cam_z, 960.0)
	st.update(cam_z, 900.0)
	assert_eq(int(st.stats()["restarts"]), 2, "Sprung um 3 km über das Pfadende hinaus: Neuaufbau")
	var lo := 1 << 30
	for c: Dictionary in st.snapshot()["chunks"]:
		lo = mini(lo, int(c["index"]))
		assert_eq(str(c["state"]), "committed", "nach dem Neuaufbau ist alles eingehängt")
	assert_true(float(lo + 1) * CHUNK_M >= cam_z - 192.0 - CHUNK_M and st.chunk_count() >= 5, "Stücke rund um die neue Position (%d ab Stück %d)" % [st.chunk_count(), lo])
	# the camera behind everything the track still holds: no endless restart, the oldest road is streamed
	st.update(20000.0, 900.0)
	st.update(20010.0, 900.0)
	assert_eq(int(st.stats()["restarts"]), 2, "Kamera hinter dem Streckenfenster: kein Neuaufbau in jedem Bild")
	assert_true(st.chunk_count() >= 5, "die älteste vorhandene Straße bleibt geladen")
'''
b = '''	# a jump beyond the integrated path (it reaches about 3.4 km ahead; the track window moved on): a new start there
	assert_true(float(p.last()) * 3.0 < 25950.0, "der Pfad reicht nicht bis zum Sprungziel (%.0f m)" % (float(p.last()) * 3.0))
	cam_z = 25950.0
	t.update_window(cam_z, 960.0)
	st.update(cam_z, 900.0)
	assert_eq(int(st.stats()["restarts"]), 2, "Sprung über das Pfadende hinaus: Neuaufbau")
	var lo := 1 << 30
	for c: Dictionary in st.snapshot()["chunks"]:
		lo = mini(lo, int(c["index"]))
		assert_eq(str(c["state"]), "committed", "nach dem Neuaufbau ist alles eingehängt")
	assert_true(float(lo + 1) * CHUNK_M >= cam_z - 192.0 - CHUNK_M and st.chunk_count() >= 3, "Stücke rund um die neue Position (%d ab Stück %d)" % [st.chunk_count(), lo])
	# the camera behind everything the track still holds: no endless restart, the oldest road is streamed
	st.update(20000.0, 900.0)
	st.update(20010.0, 900.0)
	assert_eq(int(st.stats()["restarts"]), 2, "Kamera hinter dem Streckenfenster: kein Neuaufbau in jedem Bild")
	assert_true(st.chunk_count() >= 3, "die älteste vorhandene Straße bleibt geladen")
'''
assert a in s
s = s.replace(a, b)
a = '''	assert_true(max_path <= int((150.0 + 2.0 * p.clear_reach_m + 1596.0 + 900.0) / 3.0) + 400, "der Pfad wird hinten gekürzt (%d Grenzen)" % max_path)'''
b = '''	assert_true(max_path <= int((150.0 + 2.0 * p.clear_reach_m + 1596.0) / 3.0) + 400, "der Pfad wird hinten gekürzt (%d Grenzen)" % max_path)
	assert_true(float(p.last()) * 3.0 - cam_z <= 1500.0 + 96.0 + p.clear_reach_m + 45.0, "und reicht höchstens %.0f m vor die Kamera" % (float(p.last()) * 3.0 - cam_z))'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)
print('patched')
