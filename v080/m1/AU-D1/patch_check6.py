import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
rep = [
('''	var burst := 0              # the most frames the driver mixed between two short frames of the game: its burst
	var frame_times := PackedFloat32Array()''',
'''	var burst := 0              # the most frames the driver mixed between two short frames of the game: its burst
	var frame_times := PackedFloat32Array()
	var countin_frame_max := 0.0   # the longest frame between the music's start and "LOS!" (real time)
	var director: Object = m.get("music")'''),
('''		if bool(_sc.get("_stage_start_sent")) if _sc != null else false:
			frame_times.append(_frame_delta)''',
'''		if bool(_sc.get("_stage_start_sent")) if _sc != null else false:
			frame_times.append(_frame_delta)
			if go_frame < 0 and str(director.get("race_phase")) == "playing":
				countin_frame_max = maxf(countin_frame_max, _frame_delta)'''),
('''	var land_tol := 1000.0 * (burst / MIX_RATE + 0.5 * median_frame) + 80.0
	var game_tol := 1.0 / 60.0 + 0.5 * maxf(median_frame, 1.0 / 60.0) + 0.002''',
'''	# Both bounds grow with the longest frame of the count-in: a frame that runs several physics steps at once (the
	# physics catching up on a loaded machine) moves the start by up to that frame; with steady frames they are tight.
	var step := 1.0 / 60.0
	var game_tol := maxf(countin_frame_max, step) + step + 0.002
	var land_tol := 1000.0 * (burst / MIX_RATE + maxf(countin_frame_max, step)) + 40.0'''),
('''"– erlaubt %.0f ms (Treiber mischt in Schüben von %d Frames, Bilder im Countdown im Median %.0f ms); Spielzeit-Abstand im Director %s s; " +''',
'''"– erlaubt %.0f ms (Treiber mischt in Schüben von %d Frames, Bilder im Countdown im Median %.0f ms, im Einzähler bis %.0f ms); Spielzeit-Abstand im Director %s s (erlaubt %.0f ms); " +'''),
('''		land_tol, burst, median_frame * 1000.0, str(go_offset), int(ts),''',
'''		land_tol, burst, median_frame * 1000.0, countin_frame_max * 1000.0, str(go_offset), game_tol * 1000.0, int(ts),'''),
]
for a, b in rep:
    assert s.count(a) == 1, a[:70]
    s = s.replace(a, b)
s = s.replace('''	# the downbeat against the "LOS!" tone in the output. The Dummy driver of a headless run starts every sound at the
	# next of its bursts (4096 frames, 93 ms): the downbeat lies a fixed part of a burst after the music's start
	# (80182 frames = 19.58 bursts), the tone right on a burst – the two land up to one burst apart (measured
	# +53.4 ms or −39.4 ms, and one burst more when the tone's frame came early). Tolerance: one burst, half a frame
	# (the director starts in the frame nearest to its moment) and 80 ms for frames that came unevenly on a loaded
	# machine. A real driver mixes in 512-frame steps (11.6 ms) – there the director's half frame dominates
	# (inferred). The director's own clock is checked to one physics step plus half a frame (go_offset_s).
''', '''	# the downbeat against the "LOS!" tone in the output. The Dummy driver of a headless run starts every sound at the
	# next of its bursts (4096 frames, 93 ms): the downbeat lies a fixed part of a burst after the music's start
	# (80182 frames = 19.58 bursts), the tone right on a burst – the two land up to one burst apart (measured
	# +53.4 ms, one burst more when the tone's frame came early). A real driver mixes in 512-frame steps (11.6 ms) –
	# there the director's frame dominates (inferred). The director's own clock is checked to one frame plus one
	# physics step (go_offset_s).
''')
open(p, "w", encoding="utf-8").write(s)
print("ok")
