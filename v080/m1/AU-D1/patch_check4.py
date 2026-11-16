import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
rep = [
('''	# 3. the session goes (the stage is left, the race piece plays on): the music comes back
	_sc.queue_free()
	_sc = null
	wall = Time.get_ticks_msec()
	while Time.get_ticks_msec() - wall < 1500:
		await process_frame
		frame_game_max = maxf(frame_game_max, _frame_delta)
		_drain(pre, x_pre)''',
'''	# 3. the session goes (the stage is left, the race piece plays on): the music comes back
	_set_time_scale(1.0)
	_sc.queue_free()
	_sc = null
	wall = Time.get_ticks_msec()
	while Time.get_ticks_msec() - wall < 1500:
		await process_frame
		_drain(pre, x_pre)'''),
('''	# the downbeat against the "LOS!" tone in the output: one driver burst (two sounds started in different frames
	# reach the output up to a burst apart) plus half the longest frame (the director starts in the frame nearest to
	# its moment) plus 10 ms
	var land_tol := 1000.0 * (burst / MIX_RATE + 0.5 * median_frame) + 10.0''',
'''	# the downbeat against the "LOS!" tone in the output. The Dummy driver of a headless run starts every sound at the
	# next of its bursts (4096 frames, 93 ms): the downbeat lies a fixed part of a burst after the music's start
	# (80182 frames = 19.58 bursts), the tone right on a burst – the two land up to one burst apart (measured
	# +53.4 ms or −39.4 ms, and one burst more when the tone's frame came early). Tolerance: one burst, half a frame
	# (the director starts in the frame nearest to its moment) and 60 ms for frames that came unevenly on a loaded
	# machine. A real driver mixes in 512-frame steps (11.6 ms) – there the director's half frame dominates
	# (inferred). The director's own clock is checked to one physics step plus half a frame (go_offset_s).
	var land_tol := 1000.0 * (burst / MIX_RATE + 0.5 * median_frame) + 60.0
	var game_tol := 1.0 / 60.0 + 0.5 * maxf(median_frame, 1.0 / 60.0) + 0.002'''),
('''	var ok := music_started and go_ui >= 0 and on_ui.size() >= 4 and absf(land_ms) <= land_tol and float(fs["err"]) < 3.0 and duck_db <= -3.0''',
'''	var game_ok := go_offset != null and absf(float(go_offset)) <= game_tol
	var ok := music_started and game_ok and go_ui >= 0 and on_ui.size() >= 4 and absf(land_ms) <= land_tol and float(fs["err"]) < 3.0 and duck_db <= -3.0'''),
]
for a, b in rep:
    assert s.count(a) == 1, a[:70]
    s = s.replace(a, b)
open(p, "w", encoding="utf-8").write(s)
print("ok")
