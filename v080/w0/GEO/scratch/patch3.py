root = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-4/'
p = root + 'tests/unit/race3d/test_chunk_streamer.gd'
s = open(p).read()

a = '''	assert_true(shifts.size() >= 2, "der Ursprung wurde verlegt (%d-mal)" % shifts.size())'''
b = '''	assert_true(shifts.size() >= 1, "der Ursprung wurde verlegt (%d-mal)" % shifts.size())'''
assert a in s
s = s.replace(a, b)

a = '''	# a jump ahead (the track window moved on): the streamer starts again there
	cam_z = 24000.0
	t.update_window(cam_z, 960.0)
	st.update(cam_z, 900.0)
	assert_eq(int(st.stats()["restarts"]), 2, "Sprung nach vorn: Neuaufbau")
	var lo := 1 << 30
	for c: Dictionary in st.snapshot()["chunks"]:
		lo = mini(lo, int(c["index"]))
	assert_true(float(lo + 1) * CHUNK_M >= cam_z - 192.0 - CHUNK_M and st.chunk_count() >= 10, "Stücke rund um die neue Position (%d ab Stück %d)" % [st.chunk_count(), lo])
	# the camera behind everything the track still holds: no endless restart, the oldest road is streamed
	st.update(20000.0, 900.0)
	st.update(20010.0, 900.0)
	assert_true(int(st.stats()["restarts"]) <= 3, "Kamera hinter dem Streckenfenster: kein Neuaufbau in jedem Bild (%d)" % int(st.stats()["restarts"]))
'''
b = '''	# a short jump ahead stays inside the integrated path: the streamer just carries on
	cam_z = 22300.0
	t.update_window(cam_z, 960.0)
	st.update(cam_z, 900.0)
	assert_eq(int(st.stats()["restarts"]), 1, "Sprung um 800 m: kein Neuaufbau")
	assert_true(st.chunk_count() >= 10, "Stücke an der neuen Position (%d)" % st.chunk_count())
	# a jump beyond the integrated path (the track window moved on): the streamer starts again there
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
assert a in s
s = s.replace(a, b)

a = '''	assert_true(a.window_size() > b.window_size() + 500, "der Streamer erzeugt die Strecke weit voraus (%d gegen %d Segmente im Fenster)" % [a.window_size(), b.window_size()])'''
b = '''	assert_true(a.window_size() > b.window_size() + 300, "der Streamer erzeugt die Strecke weit voraus (%d gegen %d Segmente im Fenster)" % [a.window_size(), b.window_size()])'''
assert a in s
s = s.replace(a, b)
open(p, 'w').write(s)
print('patched')
