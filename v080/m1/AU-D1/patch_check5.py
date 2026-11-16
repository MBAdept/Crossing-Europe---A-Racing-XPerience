import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
rep = [
# defer the heavy matching to the end of the scenario
('''	# where the race file started in the capture (its count-in matched), its first downbeat one bar later
	var main: AudioStreamOggVorbis = load(MUSIC_DIR + "linke_spur.ogg")
	var bar_f := int(round(4.0 * 60.0 / main.bpm * MIX_RATE))
	var file_env := _env(_mix(main.instantiate_playback(), bar_f), 0, bar_f / ENV_W - 4)
	var fs := _file_start(x_pre, file_env, go_ui - pre_lag - int(4.0 * MIX_RATE), go_ui - pre_lag) if go_ui >= 0 else {"frame": -1, "err": INF}
	var downbeat := int(fs["frame"]) + pre_lag + bar_f
	var land_ms := (downbeat - go_ui) / MIX_RATE * 1000.0
	var music_started''',
'''	var music_started'''),
('''	var back_db := _gain_db(x_pre, x_post, x_post.size() - int(0.3 * MIX_RATE), int(0.25 * MIX_RATE), pre_lag) - idle_db''',
'''	var back_db := _gain_db(x_pre, x_post, x_post.size() - int(0.3 * MIX_RATE), int(0.25 * MIX_RATE), pre_lag) - idle_db
	# where the race file started in the capture (its count-in matched), its first downbeat one bar later – computed
	# now, after the drive (it takes a moment and must not stretch a frame of the race)
	var main: AudioStreamOggVorbis = load(MUSIC_DIR + "linke_spur.ogg")
	var bar_f := int(round(4.0 * 60.0 / main.bpm * MIX_RATE))
	var file_env := _env(_mix(main.instantiate_playback(), bar_f), 0, bar_f / ENV_W - 4)
	var fs := _file_start(x_pre, file_env, go_ui - pre_lag - int(4.0 * MIX_RATE), go_ui - pre_lag) if go_ui >= 0 else {"frame": -1, "err": INF}
	var downbeat := int(fs["frame"]) + pre_lag + bar_f
	var land_ms := (downbeat - go_ui) / MIX_RATE * 1000.0'''),
# faster coarse search: the capture's envelope once on the 5-ms grid
('''	for start in range(maxi(lo, 0), maxi(hi, 0), ENV_W):
		var err: float = score.call(start)
		if err < best_err:
			best_err = err
			best = start''',
'''	lo = maxi(lo, 0)
	hi = maxi(hi, lo)
	var cap := _env(x, lo, (hi - lo) / ENV_W + file_env.size())
	for c in range(0, (hi - lo) / ENV_W):
		var diff := 0.0
		var cnt := 0
		for j in file_env.size():
			if file_env[j] > -60.0:
				diff += cap[c + j] - file_env[j]
				cnt += 1
		if cnt == 0:
			continue
		var off := diff / cnt
		var err := 0.0
		for j in file_env.size():
			if file_env[j] > -60.0:
				err += absf(cap[c + j] - file_env[j] - off)
		err /= cnt
		if err < best_err:
			best_err = err
			best = lo + c * ENV_W'''),
]
for a, b in rep:
    assert s.count(a) == 1, a[:70]
    s = s.replace(a, b)
open(p, "w", encoding="utf-8").write(s)
print("ok")
