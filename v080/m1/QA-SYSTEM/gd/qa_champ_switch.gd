extends SceneTree
## QA-SYSTEM: switching "Grafik" and "Klang" in the middle of a championship through the real GameFlow (headless,
## autopilot). No --graphics on the command line (it would override the stored choice) – the run passes --sound-free
## arguments only. Steps:
##  leg 1 in Arcade (chosen) -> result: gfx arcade, sound arcade
##  back to the title, options GRAFIK: Grafik = Modern (options handler), leave (saved) -> sound follows at once
##  continue race -> leg 2: renderer Modern, sound Modern during the stage, result gfx modern
##  during leg 3: Grafik -> Arcade and Klang -> Arcade (as the options would) -> nothing changes inside the stage;
##  after the stage the sound is Arcade; leg 4 is drawn in Arcade; RaceState.gfx_summary() == "mixed"
## Prints CHECK lines; exit 1 on a failure.

var _gf: Node
var _st: Node
var _am: Node
var _state := "start"
var _wall0 := 0
var _failed: Array[String] = []
var _n := 0
var _legs := 0
var _last_result: Variant = null
var _mid_done := false
var _samples: Dictionary = {}
var _frames_in_stage := 0


func _initialize() -> void:
	Engine.time_scale = 40.0
	Engine.physics_ticks_per_second = 2400
	Engine.max_physics_steps_per_frame = 80
	_wall0 = Time.get_ticks_msec()


func _check(check_name: String, ok: bool, msg: String = "") -> void:
	_n += 1
	print("CHECK %-26s %s  %s" % [check_name, "OK    " if ok else "FEHLER", msg])
	if not ok:
		_failed.append(check_name)


func _session() -> Node:
	var c: Variant = _gf.get("current")
	if c is Node and is_instance_valid(c) and (c as Node).has_method("is_live"):
		return c
	return null


func _process(_delta: float) -> bool:
	if (Time.get_ticks_msec() - _wall0) / 1000.0 > 1500.0:
		print("FEHLER: Zeitlimit im Zustand ", _state)
		_finish()
		return true
	if _gf == null:
		_gf = root.get_node_or_null("/root/GameFlow")
		_st = root.get_node_or_null("/root/Settings")
		_am = root.get_node_or_null("/root/AudioManager")
		return false
	match _state:
		"start":
			_st.set("file_path", "user://qa_champ_settings.json")
			_st.set("graphics_mode", "arcade")
			_st.call("save_settings")
			_gf.call("show_title")
			_check("start_profile_arcade", str(_am.call("profile")) == "arcade", str(_am.call("profile")))
			_gf.call("new_race")
			_gf.call("select_race", "kiel_nuernberg")
			_gf.call("select_vehicle", "kompakt")
			_gf.call("select_start_time", 9.0)
			_state = "flow"
		"flow":
			_flow_step()
		"racing":
			var s := _session()
			if s != null:
				_frames_in_stage += 1
				if _frames_in_stage == 200:
					_samples[_legs + 1] = {"gfx": str(s.get("gfx")), "sound": str(_am.call("profile"))}
					if _legs + 1 == 3 and not _mid_done:
						# the player cannot reach the options in a stage – simulate the signals anyway (robustness)
						_mid_done = true
						_st.set("graphics_mode", "arcade")
						_st.set("sound_profile", "arcade")
						_samples["mid3"] = {"gfx_after_switch": str(s.get("gfx")), "sound_after_switch": str(_am.call("profile"))}
			var r: Variant = _gf.get("last_result")
			if r != null and not is_same(r, _last_result) and _gf.call("current_screen_name") == "result":
				_last_result = r
				_legs += 1
				_frames_in_stage = 0
				_on_leg(r)
	return false


func _flow_step() -> void:
	var scr := str(_gf.call("current_screen_name"))
	match scr:
		"route_choice":
			var race: Object = _gf.get("race")
			var ui_data: GDScript = load("res://scripts/ui/ui_data.gd")
			var opts: Array = ui_data.call("next_options", race.get("race_id"), race.get("current_city"), race.get("waypoint_index"), race.call("visited"))
			_gf.call("choose_leg", opts[0])
		"stage_screen":
			_gf.call("start_pending_stage")
			_state = "racing"
		"ferry":
			_gf.call("ferry_done")
		"result":
			_gf.call("result_continue")
		"race_result":
			_finish()


func _on_leg(r: Dictionary) -> void:
	var g := str(r.get("gfx", "?"))
	print("ETAPPE %d %s gfx=%s fallback=%s Ton=%s mitten=%s" % [_legs, str(r.get("stage_name")), g, str(r.get("gfx_fallback", "")),
		str(_am.call("profile")), JSON.stringify(_samples.get(_legs, {}))])
	match _legs:
		1:
			_check("leg1_arcade", g == "arcade" and str(_samples.get(1, {}).get("sound", "")) == "arcade", g)
			# the player leaves the race to the title (the race is saved) and switches to Modern in the options
			_gf.call("result_continue")   # result done -> next stage screen (saved)
			_gf.call("leave_race_to_title")
			_gf.call("go", "options", {"tab": 1})
			var shell: Node = _gf.get("shell")
			var scr: Node = shell.get("current_screen")
			scr.call("_on_mode", 1)   # "Grafik" -> Modern, exactly what ◀▶ on the row does
			_check("switch_sound_follows_menu", str(_am.call("profile")) == "modern", "Ton im Menü: %s" % str(_am.call("profile")))
			scr.call("on_cancel")     # B: saved, back
			var f := FileAccess.open("user://qa_champ_settings.json", FileAccess.READ)
			var saved: Dictionary = JSON.parse_string(f.get_as_text())
			_check("switch_saved", str(saved.get("graphics_mode", "")) == "modern", JSON.stringify(saved))
			_gf.call("continue_race")
			_state = "flow"
		2:
			_check("leg2_modern", g == "modern" and str(_samples.get(2, {}).get("gfx", "")) == "modern"
				and str(_samples.get(2, {}).get("sound", "")) == "modern", "%s %s" % [g, JSON.stringify(_samples.get(2, {}))])
			_state = "flow"
		3:
			var mid: Dictionary = _samples.get("mid3", {})
			_check("leg3_no_swap_in_stage", g == "modern" and str(mid.get("gfx_after_switch", "")) == "modern"
				and str(mid.get("sound_after_switch", "")) == "modern", "%s %s" % [g, JSON.stringify(mid)])
			_check("leg3_sound_after_stage", str(_am.call("profile")) == "arcade", "Ton auf dem Ergebnis: %s" % str(_am.call("profile")))
			_state = "flow"
		4:
			_check("leg4_arcade", g == "arcade" and str(_samples.get(4, {}).get("sound", "")) == "arcade", "%s %s" % [g, JSON.stringify(_samples.get(4, {}))])
			var race: Object = _gf.get("race")
			_check("race_gfx_mixed", str(race.call("gfx_summary")) == "mixed", str(race.call("gfx_summary")))
			_finish()
		_:
			_state = "flow"


func _finish() -> void:
	print("QA-CHAMP %d Prüfungen, %d Fehler %s" % [_n, _failed.size(), str(_failed)])
	quit(0 if _failed.is_empty() and _n >= 7 else 1)
