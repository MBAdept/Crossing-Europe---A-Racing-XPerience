extends SceneTree
## QA-RINT-SYSTEM: quit and restart in every screen. Two modes (after --):
##   --qp-mode=run   starts the real game (main scene; the game's own arguments such as --screen=<name> or
##                   --stage=… --graphics=modern are read by GameFlow.boot()), waits --qp-after=<s> wall seconds
##                   (--qp-pause-at=<s>: presses "pause" then), prints the state and closes the window the way the
##                   window manager does (NOTIFICATION_WM_CLOSE_REQUEST to every node, then the tree quits:
##                   auto_accept_quit).
##   --qp-mode=check prints what a fresh start decides: Settings.effective_graphics(), crash_guard, crash_strikes(),
##                   needs_graphics_choice() – and quits.
var _mode := "run"
var _after := 3.0
var _pause_at := -1.0
var _t0 := 0
var _paused_sent := false
var _closing := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("--qp-mode="):
			_mode = s.substr(10)
		elif s.begins_with("--qp-after="):
			_after = float(s.substr(11))
		elif s.begins_with("--qp-pause-at="):
			_pause_at = float(s.substr(14))
	_t0 = Time.get_ticks_msec()
	if _mode == "check":
		_check.call_deferred()
		return
	change_scene_to_file(str(ProjectSettings.get_setting("application/run/main_scene")))


func _check() -> void:
	var st := root.get_node("Settings")
	print("QP-CHECK ", JSON.stringify({"effective": st.call("effective_graphics"), "crash_guard": st.get("crash_guard"),
		"strikes": st.call("crash_strikes"), "needs_choice": st.call("needs_graphics_choice"),
		"graphics_mode": st.get("graphics_mode"), "marker": FileAccess.file_exists(str(st.get("marker_path")))}))
	quit(0)


func _process(_dt: float) -> bool:
	if _mode != "run" or _closing:
		return false
	var t := float(Time.get_ticks_msec() - _t0) / 1000.0
	if _pause_at >= 0.0 and t >= _pause_at and not _paused_sent:
		_paused_sent = true
		var ev := InputEventAction.new()
		ev.action = "pause"
		ev.pressed = true
		Input.parse_input_event(ev)
		var up := InputEventAction.new()
		up.action = "pause"
		up.pressed = false
		Input.parse_input_event.call_deferred(up)
	if t >= _after:
		_closing = true
		var gf := root.get_node_or_null(^"GameFlow")
		var st := root.get_node("Settings")
		var info := {"t": t, "paused": paused, "marker_before_close": FileAccess.file_exists(str(st.get("marker_path")))}
		if gf != null:
			info["screen"] = gf.call("current_screen_name")
			info["stage_running"] = gf.call("stage_running")
		var cur := current_scene
		info["scene"] = str(cur.scene_file_path) if cur != null else ""
		print("QP-RUN ", JSON.stringify(info))
		root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		quit(0)
	return false
