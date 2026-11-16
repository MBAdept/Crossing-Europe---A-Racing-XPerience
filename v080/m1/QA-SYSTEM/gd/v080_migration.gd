extends SceneTree
## QA-SYSTEM: runs in the v0.8.0 tree on a COPY of a user folder written by the real v0.7.0 game.
## Checks that settings (v2 -> v3), leaderboards and the savegame survive without loss, that the chooser is due for
## this existing player, that a new leaderboard entry carries "gfx", and that a choice is stored once.
## Prints "CHECK <name> OK|FEHLER" lines, exit code 1 on a failure.

var _failed: Array[String] = []
var _n := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(check_name: String, ok: bool, msg: String = "") -> void:
	_n += 1
	print("CHECK %-22s %s  %s" % [check_name, "OK    " if ok else "FEHLER", msg])
	if not ok:
		_failed.append(check_name)


func _read_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


func _run() -> void:
	var st: Node = root.get_node("Settings")
	var gfx: GDScript = load("res://scripts/core/gfx.gd")
	var before: Variant = _read_json("user://settings.json")
	var lb_before: Variant = _read_json("user://leaderboards.json")
	var sg_before: Variant = _read_json("user://savegame.json")
	print("V070 settings ", JSON.stringify(before))
	# M1 values of v0.7.0 read without loss
	var exp := {"master_volume": 0.55, "sfx_volume": 0.35, "music_volume": 0.25, "fullscreen": false, "vibration": false,
		"player_name": "Jörg Ü", "leaderboard_filter": "kompakt", "language": "de"}
	var bad: Array[String] = []
	for k: String in exp:
		if st.get(k) != exp[k]:
			bad.append("%s=%s (erwartet %s)" % [k, str(st.get(k)), str(exp[k])])
	_check("m1_v070_values", bad.is_empty(), ", ".join(bad))
	_check("m1_fullscreen_choice", bool(st.get("fullscreen_chosen")), "fullscreen_chosen=%s" % str(st.get("fullscreen_chosen")))
	# M2 new keys not chosen
	var gm := str(st.get("graphics_mode"))
	_check("m2_new_defaults", gm == "" and str(st.get("sound_profile")) == "auto" and bool(st.get("race_music"))
		and str(st.get("gfx_preset")) == "" and (st.get("gfx_custom") as Dictionary).is_empty(),
		"graphics_mode='%s' sound_profile=%s race_music=%s" % [gm, str(st.get("sound_profile")), str(st.get("race_music"))])
	var res: Dictionary = gfx.call("resolve_mode", gm, "", "", false)
	_check("m2_mode_without_cli", str(res.get("mode")) == "arcade", JSON.stringify(res))
	_check("m2_sound_without_cli", str(gfx.call("resolve_sound", str(st.get("sound_profile")), gm, "", "")) == "arcade")
	# M3 chooser due for this existing player when started without arguments on a display
	_check("m3_chooser_due", bool(gfx.call("chooser_due", gm, 0, false, "")), "")
	var gcs: GDScript = load("res://scripts/ui/screens/graphics_choice_screen.gd")
	_check("m3_existing_player", bool(gcs.call("existing_player")), "")
	_check("m3_no_unsaved", not bool(st.call("has_unsaved_changes")), "to_dict=%s" % JSON.stringify(st.call("to_dict")))
	# M4 save -> v3 without loss
	var ok: bool = st.call("save_settings")
	var after: Variant = _read_json("user://settings.json")
	print("V080 settings ", JSON.stringify(after))
	var lost: Array[String] = []
	for k: String in (before as Dictionary):
		if k == "settings_version":
			continue
		if not (after as Dictionary).has(k) or (after as Dictionary)[k] != (before as Dictionary)[k]:
			lost.append(k)
	_check("m4_saved_v3", ok and int((after as Dictionary).get("settings_version", 0)) == 3, "")
	_check("m4_nothing_lost", lost.is_empty(), "verloren/geändert: %s" % ", ".join(lost))
	var added: Array[String] = []
	for k: String in (after as Dictionary):
		if not (before as Dictionary).has(k):
			added.append(k)
	_check("m4_no_unchosen_keys", added.is_empty(), "neu: %s" % ", ".join(added))
	# M5 fresh read of the v3 file keeps "Vollbild: Aus" chosen (FULLSCREEN_CHOICE_SINCE trap)
	var ss: GDScript = load("res://scripts/core/settings.gd")
	_check("m5_fullscreen_v3", bool(ss.call("fullscreen_stored_as_choice", after)), "")
	# M6 the player chooses Modern in the chooser: stored once, sound follows, chooser no longer due
	st.set("graphics_mode", "modern")
	st.call("save_settings")
	var chosen: Variant = _read_json("user://settings.json")
	_check("m6_mode_stored", str((chosen as Dictionary).get("graphics_mode", "")) == "modern"
		and not (chosen as Dictionary).has("sound_profile"), JSON.stringify(chosen))
	_check("m6_sound_follows", str(gfx.call("resolve_sound", str(st.get("sound_profile")), "modern", "", "")) == "modern")
	_check("m6_chooser_not_due", not bool(gfx.call("chooser_due", str((chosen as Dictionary).get("graphics_mode", "")), 0, false, "")))
	# M7 a key of a later version survives load + save
	var fut := (chosen as Dictionary).duplicate(true)
	fut["future_key"] = {"a": 1, "b": [1, 2]}
	var f := FileAccess.open("user://settings.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(fut))
	f.close()
	st.call("load_settings")
	st.call("save_settings")
	var fut2: Variant = _read_json("user://settings.json")
	_check("m7_unknown_key_kept", JSON.stringify((fut2 as Dictionary).get("future_key", null)) == JSON.stringify(JSON.parse_string(JSON.stringify(fut["future_key"])))
		and str((fut2 as Dictionary).get("graphics_mode", "")) == "modern", JSON.stringify(fut2))
	# M8 leaderboards: v0.7.0 entries unchanged; a new entry carries gfx
	var lb: Node = root.get_node("Leaderboards")
	var boards_before: Dictionary = (lb_before as Dictionary).get("boards", {})
	var mism: Array[String] = []
	for key: String in boards_before:
		var mine: Array = []
		for e: Dictionary in (boards_before[key] as Array):
			if str(e.get("name", "")) == "Jörg Ü":
				mine.append(e)
		var now: Array = lb.call("entries", key) if lb.has_method("entries") else lb.get("store").call("entries", key)
		for e: Dictionary in mine:
			var found := false
			for n: Dictionary in now:
				if n == e:
					found = true
			if not found:
				mism.append(key)
	_check("m8_lb_v070_entries", mism.is_empty(), "fehlen/geändert: %s" % ", ".join(mism))
	var rs: GDScript = load("res://scripts/ui/screens/result_screen.gd")
	var res_modern := {"time_s": 290.0, "avg_speed_kmh": 118.0, "vehicle": "sportwagen", "weather": "normal",
		"start_hour": 12.0, "gfx": "modern"}
	var entry: Dictionary = rs.call("leaderboard_entry", res_modern, "day")
	entry["name"] = "QA Modern"
	var res_fb := {"time_s": 295.0, "avg_speed_kmh": 117.0, "vehicle": "kombi", "weather": "normal",
		"start_hour": 12.0, "gfx": "arcade", "gfx_fallback": "selftest:shader"}
	var entry2: Dictionary = rs.call("leaderboard_entry", res_fb, "day")
	entry2["name"] = "QA Fallback"
	lb.call("submit", "stage:kiel_hamburg:fwd", entry, "")
	lb.call("submit", "stage:kiel_hamburg:fwd", entry2, "")
	var lb_after: Variant = _read_json("user://leaderboards.json")
	var board: Array = ((lb_after as Dictionary).get("boards", {}) as Dictionary).get("stage:kiel_hamburg:fwd", [])
	var g1 := ""
	var g2 := ""
	var fb2 := ""
	var old_ok := false
	for e: Dictionary in board:
		if str(e.get("name", "")) == "QA Modern":
			g1 = str(e.get("gfx", ""))
		if str(e.get("name", "")) == "QA Fallback":
			g2 = str(e.get("gfx", ""))
			fb2 = str(e.get("gfx_fallback", ""))
		if str(e.get("name", "")) == "Jörg Ü":
			old_ok = not e.has("gfx")
	_check("m8_lb_new_gfx", g1 == "modern" and g2 == "arcade" and fb2 == "selftest:shader", "gfx=%s/%s fallback=%s" % [g1, g2, fb2])
	_check("m8_lb_old_untouched", old_ok, "")
	var race_board: Array = ((lb_after as Dictionary).get("boards", {}) as Dictionary).get("race:kiel_nuernberg", [])
	var race_old := false
	for e: Dictionary in race_board:
		if str(e.get("name", "")) == "Jörg Ü" and (e.get("route", []) as Array).size() == 3:
			race_old = true
	_check("m8_lb_race_board", race_old, "")
	# M9 savegame of v0.7.0 continues
	var sg: Node = root.get_node("SaveGame")
	_check("m9_has_race", bool(sg.call("has_race")), "")
	var state: Dictionary = sg.call("load_race")
	var raw: Dictionary = (sg_before as Dictionary).get("race", {})
	var diff: Array[String] = []
	for k: String in raw:
		if not state.has(k) or (str(state[k]) != str(raw[k]) and not ((state[k] is int or state[k] is float) and (raw[k] is int or raw[k] is float) and float(state[k]) == float(raw[k]))):
			diff.append(k)
	_check("m9_state_equal", diff.is_empty(), "abweichend: %s" % ", ".join(diff))
	var rsg: GDScript = load("res://scripts/ui/race_state.gd")
	var race: Object = rsg.call("from_dict", state)
	var summary := str(race.call("gfx_summary")) if race.has_method("gfx_summary") else "?"
	_check("m9_gfx_summary_legacy", summary == "arcade", "gfx_summary=%s legs=%d" % [summary, (state.get("legs", []) as Array).size()])
	print("ERGEBNIS-QA %d Prüfungen, %d Fehler %s" % [_n, _failed.size(), str(_failed)])
	quit(0 if _failed.is_empty() else 1)
