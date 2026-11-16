import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
rep = [
('''	var go_frame := -1
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
			frame_times.append(_frame_delta)''',
'''	var go_frame := -1
	var wall := Time.get_ticks_msec()
	var burst := 0              # the most frames the driver mixed between two short frames of the game: its burst
	var frame_times := PackedFloat32Array()
	# 1. countdown and the first half second after "LOS!" in real time
	while Time.get_ticks_msec() - wall < 15000:
		await process_frame
		_drain(pre, x_pre)
		var got := _drain(post, x_post)
		_drain(ui, x_ui)
		if _frame_delta < 0.05:
			burst = maxi(burst, got)
		if bool(_sc.get("_stage_start_sent")) if _sc != null else false:
			frame_times.append(_frame_delta)'''),
('''	var sorted_times := frame_times.duplicate()
	sorted_times.sort()
	var median_frame := sorted_times[sorted_times.size() / 2] if not sorted_times.is_empty() else 0.02
	var ts := clampf(floorf(0.15 / maxf(median_frame, 0.001)), 1.0, 8.0)
	_set_time_scale(ts)''',
'''	var sorted_times := frame_times.duplicate()
	sorted_times.sort()
	var median_frame := sorted_times[sorted_times.size() / 2] if not sorted_times.is_empty() else 0.02
	var p90_frame := sorted_times[int(sorted_times.size() * 0.9)] if not sorted_times.is_empty() else 0.02
	var ts := clampf(floorf(0.1 / maxf(p90_frame, 0.001)), 1.0, 4.0)
	_set_time_scale(ts)'''),
('''	duck_db = _gain_db(x_pre, x_post, x_post.size() - int(0.3 * MIX_RATE), int(0.25 * MIX_RATE), pre_lag) - idle_db''',
'''	# the fader's effect in 50-ms windows over the last second of full throttle: median and deepest
	var gains := PackedFloat32Array()
	for a in range(x_post.size() - int(1.0 * MIX_RATE), x_post.size() - 2205, 2205):
		gains.append(_gain_db(x_pre, x_post, a, 2205, pre_lag) - idle_db)
	gains.sort()
	duck_db = gains[gains.size() / 2] if not gains.is_empty() else 0.0
	var duck_deepest := gains[0] if not gains.is_empty() else 0.0'''),
('''	var land_tol := 1000.0 * (burst / MIX_RATE + 0.5 * frame_real_max) + 10.0''',
'''	var land_tol := 1000.0 * (burst / MIX_RATE + 0.5 * median_frame) + 10.0'''),
('''"– erlaubt %.0f ms (Treiber mischt in Schüben bis %d Frames, längstes Bild des Countdowns %.0f ms); Spielzeit-Abstand im Director %s s; " +
		"Vollgas bei Zeitraffer %d (%.0f km/h, Gas %.2f): Musik nach dem Fader %.1f dB gegenüber dem Countdown (Mischung %.1f dB), " +''',
'''"– erlaubt %.0f ms (Treiber mischt in Schüben von %d Frames, Bilder im Countdown im Median %.0f ms); Spielzeit-Abstand im Director %s s; " +
		"Vollgas bei Zeitraffer %d (%.0f km/h, Gas %.2f): Musik nach dem Fader %.1f dB gegenüber dem Countdown (Median über 1 s, tiefstes 50-ms-Fenster %.1f dB; Mischung %.1f dB), " +'''),
('''		land_tol, burst, frame_real_max * 1000.0, str(go_offset), int(ts), speed, throttle, duck_db, mix_duck, back_db, frame_game_max])''',
'''		land_tol, burst, median_frame * 1000.0, str(go_offset), int(ts), speed, throttle, duck_db, duck_deepest, mix_duck, back_db, frame_game_max])'''),
]
for a, b in rep:
    assert s.count(a) == 1, a[:70]
    s = s.replace(a, b)
open(p, "w", encoding="utf-8").write(s)
print("ok")
