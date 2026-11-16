P = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3/tests/unit/audio_modern/check_modern_audio.gd"
s = open(P, encoding="utf-8").read()
a = s.index("func _scenario_race(_g: String) -> void:")
b = s.index("func _scenario_arcade_after(golden_file: String) -> void:")
NEW = '''func _scenario_race(_g: String) -> void:
	# time scale 8: quick, and a frame still spans well under ModernAudio.ALIVE_S of game time (at 20 the session
	# would count as gone between two frames – for the Arcade sound as well)
	var ts := 8.0
	Engine.time_scale = ts
	Engine.physics_ticks_per_second = int(60.0 * ts)
	Engine.max_physics_steps_per_frame = 32
	# Modern: 22 s from km 49 through the Testtunnel (km 50–54), in the rain
	_am.call("set_profile", "modern")
	_am.call("set_music_context", "race", {"stage": "dev_testetappe"})
	_launch(49.0, 5)
	var mod: Dictionary = await _drive(22.0)
	var st: Dictionary = _modern().call("debug_state")
	var events: Dictionary = st["events"]
	var feed: Dictionary = st["feed"]
	var music: Dictionary = st["slots"]["music"]
	await _end_stage()
	var modern_diff := _arcade_diff()   # the Arcade buses after a race with Modern: exactly as in v0.7.0
	var hooks := int(events.get("stage_start", 0)) >= 1 and int(events.get("go", 0)) >= 1 and bool(feed["valid"]) \\
		and int(events.get("tunnel_in", 0)) == 1 and int(events.get("tunnel_out", 0)) == 1 \\
		and int(mod["tunnel_frames"]) > 0 and float(mod["max_rpm"]) > 1500.0 and int(mod["alive_frames"]) > int(mod["frames"]) * 0.9 \\
		and ((int(mod["max_voices"]) >= 1) == _live) and int((st["plays"] as Dictionary).get("go", 0)) == 1
	var music_ok := str(music["context"]) == "race" and ((str(music["key"]) == "music/platzhalter_takt") == _live)
	var text := "Teststadt – Testdorp ab km 49 im Regen, 22 s mit dem Profil Modern bis km %.2f: Motor bis %.0f/min, Sitzung in %d von %d Bildern da, Tunnelhall in %d Bildern, Feed gültig (Zone %s, Ereignisse %s), bis zu %d Verkehrsstimmen, Musik %s („%s“)" % [
		float(mod["km"]), float(mod["max_rpm"]), int(mod["alive_frames"]), int(mod["frames"]), int(mod["tunnel_frames"]), str(feed["zone"]),
		JSON.stringify(events), int(mod["max_voices"]), str(music["context"]), str(music["key"])]
	var ok := hooks and music_ok and (st["asset_errors"] as Array).is_empty() and modern_diff.is_empty()
	text += "; Arcade-Busse dabei unverändert" if modern_diff.is_empty() else "; ARCADE-BUSSE GEÄNDERT: " + "; ".join(modern_diff.slice(0, 3))
	if not _live:
		# the last 1.5 km to the finish with Modern
		_launch(128.5, 6)
		var fin: Dictionary = await _drive(0.0, true)
		var st_fin: Dictionary = _modern().call("debug_state")
		await _end_stage()
		var finish_ok := bool(fin["finished"]) and int((st_fin["plays"] as Dictionary).get("finish", 0)) == 1 \\
			and (_inject or int((st_fin["events"] as Dictionary).get("stage_finish", 0)) == 1)
		# the same 22 s with the Arcade profile: the simulation does not depend on the sound profile (Rule 3)
		_am.call("set_profile", "arcade")
		_launch(49.0, 5)
		var arc: Dictionary = await _drive(22.0)
		await _end_stage()
		var ha: Array = arc["hashes"]
		var hm: Array = mod["hashes"]
		var first_diff := -1
		for i in mini(ha.size(), hm.size()):
			if ha[i] != hm[i]:
				first_diff = i
				break
		var same := ha.size() == hm.size() and ha.size() >= 21 and first_diff < 0 \\
			and JSON.stringify(arc["result"]) == JSON.stringify(mod["result"]) and float(arc["km"]) == float(mod["km"])
		ok = ok and finish_ok and same
		text += "; Zieleinlauf ab km 128,5: im Ziel %s, Zielklang %d ×; dieselben 22 s mit dem Profil Arcade bis km %.2f: Simulation in %d / %d Sekunden gleich%s, Ergebnis gleich %s" % [
			str(fin["finished"]), int((st_fin["plays"] as Dictionary).get("finish", 0)), float(arc["km"]), hm.size(), ha.size(),
			"" if first_diff < 0 else " – ERSTE ABWEICHUNG in Sekunde %d" % first_diff,
			str(JSON.stringify(arc["result"]) == JSON.stringify(mod["result"]))]
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	Engine.max_physics_steps_per_frame = 8
	_am.call("set_profile", "arcade")
	_check("race", ok, text + (" (Hooks von dieser Prüfung gesendet: %d Zustände)" % int(mod["injected_states"]) if _inject else " (Hooks von der Rennsitzung)"))


'''
s = s[:a] + NEW + s[b:]
# _drive: count frames and the frames in which the session counted as there
old = '''			max_rpm = maxf(max_rpm, float((_am.call("engine_state") as Dictionary).get("rpm", 0.0)))
'''
new = '''			max_rpm = maxf(max_rpm, float((_am.call("engine_state") as Dictionary).get("rpm", 0.0)))
			if bool(_sc.get("running")):
				total_frames += 1
				var mo := _modern()
				if mo != null and bool((mo.get("frame") as Object).get("alive")):
					alive_frames += 1
'''
assert old in s
s = s.replace(old, new)
old = '''	var states := 0
	var wall := Time.get_ticks_msec()
'''
new = '''	var states := 0
	var total_frames := 0
	var alive_frames := 0
	var wall := Time.get_ticks_msec()
'''
assert old in s
s = s.replace(old, new)
old = '''		"injected_states": states, "km": float(_sc.get("pos_km")), "time": float(_sc.get("stage_time")),'''
new = '''		"injected_states": states, "frames": total_frames, "alive_frames": alive_frames,
		"km": float(_sc.get("pos_km")), "time": float(_sc.get("stage_time")),'''
assert old in s
s = s.replace(old, new)
old = '''##   race           a stretch of the test stage (tunnel) with the Modern profile and with the Arcade profile: no
##                  errors, the same simulation at every second (Rule 3), the session's calls arrive (engine,
##                  traffic, tunnel reverb, feed, events); the last kilometres to the finish with Modern'''
new = '''##   race           22 s of the test stage through its tunnel with the Modern profile: the session's calls arrive
##                  (engine, traffic, tunnel reverb, feed, events, race music); without --live also the finish with
##                  Modern and the same 22 s with the Arcade profile – the same simulation at every second (Rule 3)'''
assert old in s
s = s.replace(old, new)
open(P, "w", encoding="utf-8").write(s)
print("ok")
