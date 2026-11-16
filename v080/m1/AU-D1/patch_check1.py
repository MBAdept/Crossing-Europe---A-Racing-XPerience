import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
a = s.index("## Frame of the strongest rise of the low band")
b = s.index("func _launch(stage: String, start_km: float) -> void:")
new_fn = '''const ENV_W := 220      ## 5-ms windows of the envelopes


## 5-ms RMS envelope (dB) of x from frame a on, n windows.
func _env(x: PackedVector2Array, a: int, n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for j in n:
		out.append(_rms_db(x, a + j * ENV_W, ENV_W))
	return out


## Frame of the capture at which frame 0 of the file played: the file's envelope (count-in) slid over the capture's,
## best mean absolute difference in dB after removing the level difference (player volume, EQ). Search from lo to hi
## (frames of the capture) on the 5-ms grid, then in 10-frame steps around the best window.
func _file_start(x: PackedVector2Array, file_env: PackedFloat32Array, lo: int, hi: int) -> Dictionary:
	var best := -1
	var best_err := INF

	var score := func(start: int) -> float:
		var e := _env(x, start, file_env.size())
		var diff := 0.0
		var cnt := 0
		for j in file_env.size():
			if file_env[j] > -60.0:
				diff += e[j] - file_env[j]
				cnt += 1
		if cnt == 0:
			return INF
		var off := diff / cnt
		var err := 0.0
		for j in file_env.size():
			if file_env[j] > -60.0:
				err += absf(e[j] - file_env[j] - off)
		return err / cnt

	for start in range(maxi(lo, 0), maxi(hi, 0), ENV_W):
		var err: float = score.call(start)
		if err < best_err:
			best_err = err
			best = start
	if best < 0:
		return {"frame": -1, "err": INF}
	var fine := best
	for start in range(best - ENV_W, best + ENV_W, 10):
		var err: float = score.call(start)
		if err < best_err:
			best_err = err
			fine = start
	return {"frame": fine, "err": best_err}


## First frame near `near` where the capture rises above `level` (a sharp onset: the "LOS!" tone).
func _onset_near(x: PackedVector2Array, near: int, level: float = 0.01) -> int:
	for i in range(maxi(near - 2 * ENV_W, 0), mini(near + 2 * ENV_W, x.size())):
		if absf(x[i].x) > level or absf(x[i].y) > level:
			return i
	return near


'''
s = s[:a] + new_fn + s[b:]
old = '''	var on_ui := _onsets(x_ui, -45.0)
	var go_ui := on_ui[on_ui.size() - 1] if not on_ui.is_empty() else -1
	var downbeat := _low_rise(x_post, maxi(go_ui - int(0.3 * MIX_RATE), 0), go_ui + int(0.3 * MIX_RATE)) if go_ui >= 0 else -1
	var land_ms := (downbeat - go_ui) / MIX_RATE * 1000.0'''
new = '''	var on_ui := _onsets(x_ui, -45.0)
	var go_ui := _onset_near(x_ui, on_ui[on_ui.size() - 1]) if not on_ui.is_empty() else -1
	# where the race file started in the capture (its count-in matched), its first downbeat one bar later
	var main: AudioStreamOggVorbis = load(MUSIC_DIR + "linke_spur.ogg")
	var bar_f := int(round(4.0 * 60.0 / main.bpm * MIX_RATE))
	var file_env := _env(_mix(main.instantiate_playback(), bar_f), 0, bar_f / ENV_W - 4)
	var fs := _file_start(x_pre, file_env, go_ui - pre_lag - int(4.0 * MIX_RATE), go_ui - pre_lag) if go_ui >= 0 else {"frame": -1, "err": INF}
	var downbeat := int(fs["frame"]) + pre_lag + bar_f
	var land_ms := (downbeat - go_ui) / MIX_RATE * 1000.0'''
assert s.count(old) == 1
s = s.replace(old, new)
old2 = '''	var st: Dictionary = (m.get("music") as Object).call("debug_state")
	var go_offset: Variant = st.get("go_offset_s")'''
new2 = '''	var st: Dictionary = (m.get("music") as Object).call("debug_state")
	var go_offset: Variant = st.get("go_offset_s")
	# the capture before the fader may have started one mix step later than the other two: index x_pre with this
	var pre_lag := x_post.size() - x_pre.size()'''
assert s.count(old2) == 1
s = s.replace(old2, new2)
s = s.replace("var idle_db := _gain_db(x_pre, x_post, maxi(go_ui - int(1.2 * MIX_RATE), 0), int(0.8 * MIX_RATE))",
              "var idle_db := _gain_db(x_pre, x_post, maxi(go_ui - int(1.2 * MIX_RATE), 0), int(0.8 * MIX_RATE), pre_lag)")
s = s.replace("duck_db = _gain_db(x_pre, x_post, x_post.size() - int(0.3 * MIX_RATE), int(0.25 * MIX_RATE)) - idle_db",
              "duck_db = _gain_db(x_pre, x_post, x_post.size() - int(0.3 * MIX_RATE), int(0.25 * MIX_RATE), pre_lag) - idle_db")
s = s.replace("var back_db := _gain_db(x_pre, x_post, x_post.size() - int(0.3 * MIX_RATE), int(0.25 * MIX_RATE)) - idle_db",
              "var back_db := _gain_db(x_pre, x_post, x_post.size() - int(0.3 * MIX_RATE), int(0.25 * MIX_RATE), pre_lag) - idle_db")
old3 = '''func _gain_db(x_pre: PackedVector2Array, x_post: PackedVector2Array, a: int, n: int) -> float:
	return _rms_db(x_post, a, n) - _rms_db(x_pre, a, n)'''
new3 = '''func _gain_db(x_pre: PackedVector2Array, x_post: PackedVector2Array, a: int, n: int, pre_lag: int) -> float:
	return _rms_db(x_post, a, n) - _rms_db(x_pre, a - pre_lag, n)'''
assert s.count(old3) == 1
s = s.replace(old3, new3)
# tolerance and message
old4 = "and absf(land_ms) <= 25.0 and duck_db <= -3.0"
assert s.count(old4) == 1
s = s.replace(old4, "and absf(land_ms) <= LAND_TOL_MS and float(fs[\"err\"]) < 3.0 and duck_db <= -3.0")
old5 = '''const STEP := 512
const MIX_RATE := 44100.0'''
new5 = '''const STEP := 512
const MIX_RATE := 44100.0
## Tolerance of the downbeat against the "LOS!" tone in the captured audio. The Dummy driver of a headless run mixes in
## bursts of about 93 ms, so two sounds started in different frames reach the output up to one burst apart; a real
## driver mixes in 512-frame steps (11.6 ms) – there the director's frame (16.7 ms at 60 fps) dominates (inferred).
const LAND_TOL_MS := 120.0'''
assert s.count(old5) == 1
s = s.replace(old5, new5)
s = s.replace('''"Kiel – Hamburg ab km 2 mit Countdown: Rennstück %s (%s); %d Einsätze auf MUI, der Schlag nach dem Einzähler kommt %.1f ms %s „LOS!“ " +''',
              '''"Kiel – Hamburg ab km 2 mit Countdown: Rennstück %s (%s); %d Einsätze auf MUI, der Schlag nach dem Einzähler kommt %.1f ms %s „LOS!“ (Abgleich des Einzählers %.2f dB) " +''')
s = s.replace('''		str(st.get("key", "")), str(st.get("race_phase", "")), on_ui.size(), absf(land_ms), "nach" if land_ms >= 0.0 else "vor",''',
              '''		str(st.get("key", "")), str(st.get("race_phase", "")), on_ui.size(), absf(land_ms), "nach" if land_ms >= 0.0 else "vor", float(fs["err"]),''')
open(p, "w", encoding="utf-8").write(s)
print("ok")
