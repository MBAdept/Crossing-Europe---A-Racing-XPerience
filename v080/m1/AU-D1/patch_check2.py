import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
rep = [
('''	var go_frame := -1
	var wall := Time.get_ticks_msec()
	# 1. countdown and the first half second after "LOS!" in real time
	while Time.get_ticks_msec() - wall < 15000:
		await process_frame
		_drain(pre, x_pre)
		_drain(post, x_post)
		_drain(ui, x_ui)
		if go_frame < 0 and _sc != null and bool(_sc.get("running")):''',
'''	var go_frame := -1
	var wall := Time.get_ticks_msec()
	var burst := 0              # the largest number of frames the driver mixed between two frames of the game
	var frame_real_max := 0.0   # the longest frame of the countdown (real time)
	var frame_times := PackedFloat32Array()
	# 1. countdown and the first half second after "LOS!" in real time
	while Time.get_ticks_msec() - wall < 15000:
		await process_frame
		_drain(pre, x_pre)
		burst = maxi(burst, _drain(post, x_post))
		_drain(ui, x_ui)
		if bool(_sc.get("_stage_start_sent")) if _sc != null else false:
			frame_real_max = maxf(frame_real_max, _frame_delta)
			frame_times.append(_frame_delta)
		if go_frame < 0 and _sc != null and bool(_sc.get("running")):'''),
('''	# 2. full throttle at time scale 8: the ducking (after the fader against before it)
	_set_time_scale(8.0)''',
'''	# 2. full throttle, sped up as far as a frame stays well under 0.35 s of game time (from the frames of the
	# countdown: 0.15 s of game time per frame, 1 to 8): the ducking (after the fader against before it)
	var sorted_times := frame_times.duplicate()
	sorted_times.sort()
	var median_frame := sorted_times[sorted_times.size() / 2] if not sorted_times.is_empty() else 0.02
	var ts := clampf(floorf(0.15 / maxf(median_frame, 0.001)), 1.0, 8.0)
	_set_time_scale(ts)'''),
('''	var ok := music_started and go_ui >= 0 and on_ui.size() >= 4 and absf(land_ms) <= LAND_TOL_MS and float(fs["err"]) < 3.0 and duck_db <= -3.0''',
'''	# the downbeat against the "LOS!" tone in the output: one driver burst (two sounds started in different frames
	# reach the output up to a burst apart) plus half the longest frame (the director starts in the frame nearest to
	# its moment) plus 10 ms
	var land_tol := 1000.0 * (burst / MIX_RATE + 0.5 * frame_real_max) + 10.0
	var ok := music_started and go_ui >= 0 and on_ui.size() >= 4 and absf(land_ms) <= land_tol and float(fs["err"]) < 3.0 and duck_db <= -3.0'''),
('''"(Spielzeit-Abstand im Director %s s); Vollgas (%.0f km/h, Gas %.2f): Musik nach dem Fader %.1f dB gegenüber dem Countdown (Mischung %.1f dB), " +
		"ohne Sitzung wieder %.1f dB; längstes Bild %.3f s Spielzeit") % [''',
'''"– erlaubt %.0f ms (Treiber mischt in Schüben bis %d Frames, längstes Bild des Countdowns %.0f ms); Spielzeit-Abstand im Director %s s; " +
		"Vollgas bei Zeitraffer %d (%.0f km/h, Gas %.2f): Musik nach dem Fader %.1f dB gegenüber dem Countdown (Mischung %.1f dB), " +
		"ohne Sitzung wieder %.1f dB; längstes Bild %.3f s Spielzeit") % ['''),
('''		str(go_offset), speed, throttle, duck_db, mix_duck, back_db, frame_game_max])''',
'''		land_tol, burst, frame_real_max * 1000.0, str(go_offset), int(ts), speed, throttle, duck_db, mix_duck, back_db, frame_game_max])'''),
]
for a, b in rep:
    assert s.count(a) == 1, a[:80]
    s = s.replace(a, b)
s = s.replace('''## Tolerance of the downbeat against the "LOS!" tone in the captured audio. The Dummy driver of a headless run mixes in
## bursts of about 93 ms, so two sounds started in different frames reach the output up to one burst apart; a real
## driver mixes in 512-frame steps (11.6 ms) – there the director's frame (16.7 ms at 60 fps) dominates (inferred).
const LAND_TOL_MS := 120.0
''', '')
open(p, "w", encoding="utf-8").write(s)
print("ok")
