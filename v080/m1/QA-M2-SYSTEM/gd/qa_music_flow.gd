extends SceneTree
## QA-M2-SYSTEM: music of the Modern sound through the REAL GameFlow (race selection -> stage screen -> stage with the
## autopilot -> result -> next stage …), headless with ModernAudio.force_live (the players really play). Logs every
## change of the MusicDirector state (context, piece of the active player, race phase, rotation index, ending variant,
## stingers) and which players are playing which stream, with the game flow screen, plus the one-shots of the UI.
## Based on tests/race/run_race.gd (same flow calls).
##   godot --headless --path <tree> -s <this> -- --graphics=arcade --sound=modern --race=kiel_nuernberg --autopilot \
##       --no-countdown? (no: the countdown is needed for the count-in) --timescale=8 --max-legs=4 [--race-music=0]

var _gf: Node
var _am: Node
var _ui_data: GDScript
var _state := "start"
var _wall0 := 0
var _max_wall := 3000.0
var _legs_done := 0
var _max_legs := 4
var _last_result: Variant = null
var _last := ""
var _last_screen := ""
var _boot_done := false


func _initialize() -> void:
	var args := CliArgs.all()
	var ts := clampf(float(args.get("timescale", 8.0)), 1.0, 40.0)
	Engine.time_scale = ts
	Engine.physics_ticks_per_second = maxi(60, int(round(60.0 * ts)))
	Engine.max_physics_steps_per_frame = 64
	_max_legs = int(args.get("max-legs", 4))
	_max_wall = float(args.get("max-seconds", 3000.0))
	_ui_data = load("res://scripts/ui/ui_data.gd")
	_wall0 = Time.get_ticks_msec()


func _t() -> String:
	return "%7.1f" % ((Time.get_ticks_msec() - _wall0) / 1000.0)


func _process(_delta: float) -> bool:
	if (Time.get_ticks_msec() - _wall0) / 1000.0 > _max_wall:
		print("FEHLER: Zeitlimit überschritten im Zustand ", _state)
		quit(1)
		return true
	if _gf == null:
		_gf = root.get_node_or_null("/root/GameFlow")
		_am = root.get_node_or_null("/root/AudioManager")
		return false
	if not _boot_done:
		_boot_done = true
		ModernAudio.force_live = true
		var prof := str(_am.call("profile"))
		print(_t(), " PROFIL beim Start: ", prof)
		# rebuild the Modern profile with live players (headless), as tools/audio/modern/capture_mix.gd does
		_am.call("set_profile", "arcade")
		_am.call("set_profile", "modern")
		var rm := float(CliArgs.all().get("race-music", 1.0)) > 0.5
		root.get_node("Settings").set("race_music", rm)
		_am.call("set_race_music", rm)
		print(_t(), " PROFIL jetzt: ", str(_am.call("profile")), " Musik im Rennen ", rm)
		return false
	_poll()
	var args := CliArgs.all()
	match _state:
		"start":
			_gf.call("new_race")
			_gf.call("select_race", str(args.get("race", "kiel_nuernberg")))
			_gf.call("select_vehicle", str(args.get("vehicle", "limousine")))
			_gf.call("select_start_time", float(args.get("hour", 8.0)))
			print(_t(), " RENNEN ", _gf.get("race").get("race_id"))
			_state = "flow"
		"flow":
			_flow_step()
		"racing":
			var r: Variant = _gf.get("last_result")
			if r != null and not is_same(r, _last_result) and _gf.call("current_screen_name") == "result":
				_last_result = r
				_legs_done += 1
				print(_t(), " ETAPPE %d fertig: %s" % [_legs_done, str((r as Dictionary).get("stage_name", ""))])
				_state = "flow"
				if _legs_done >= _max_legs:
					_state = "linger"
					_linger_until = Time.get_ticks_msec() + 15000
		"linger":
			if Time.get_ticks_msec() > _linger_until:
				print(_t(), " ENDE nach %d Etappen" % _legs_done)
				_am.call("set_music", false)
				_am.call("stop_all")
				_state = "quit"
				_linger_until = Time.get_ticks_msec() + 3000
		"quit":
			if Time.get_ticks_msec() > _linger_until:
				_am.call("set_profile", "arcade")
				quit(0)
	return false


var _linger_until := 0


func _flow_step() -> void:
	var scr := str(_gf.call("current_screen_name"))
	var race: Object = _gf.get("race")
	match scr:
		"route_choice":
			var opts: Array = _ui_data.call("next_options", race.get("race_id"), race.get("current_city"), race.get("waypoint_index"), race.call("visited"))
			_gf.call("choose_leg", opts[0])
		"stage_screen":
			# stay on the stage screen a moment (its music context), then start
			if _stage_wait < 0:
				_stage_wait = Time.get_ticks_msec() + 4000
			elif Time.get_ticks_msec() > _stage_wait:
				_stage_wait = -1
				_gf.call("start_pending_stage")
				_state = "racing"
		"ferry":
			_gf.call("ferry_done")
		"race_result":
			print(_t(), " RENNERGEBNIS")
			_gf.call("finish_race")
			_state = "linger"
			_linger_until = Time.get_ticks_msec() + 10000
		"result":
			if _result_wait < 0:
				_result_wait = Time.get_ticks_msec() + 6000
			elif Time.get_ticks_msec() > _result_wait:
				_result_wait = -1
				_gf.call("result_continue")
		_:
			pass


var _stage_wait := -1
var _result_wait := -1


func _poll() -> void:
	var scr := str(_gf.call("current_screen_name")) if _gf != null else ""
	var m: Variant = _am.get("_modern")
	var line := "screen=%s " % scr
	if m != null:
		var mu: Variant = m.get("music")
		if mu != null:
			var keys: Array = mu.get("_key")
			var players: Array = mu.get("_players")
			var playing: Array = []
			for i in players.size():
				var p: AudioStreamPlayer = players[i]
				if p != null and is_instance_valid(p) and p.playing:
					playing.append(str(keys[i]) if p.volume_db > -40.0 else str(keys[i]) + "(leise)")
			var sp: Variant = mu.get("_sting_player")
			var sting := ""
			if sp != null and is_instance_valid(sp) and (sp as AudioStreamPlayer).playing:
				sting = (sp as AudioStreamPlayer).stream.resource_path.get_file() if (sp as AudioStreamPlayer).stream != null else "?"
			line += "ctx=%s phase=%s idx=%d ending=%s stingers=%s playing=%s sting=%s" % [str(mu.get("context")),
				str(mu.get("race_phase")), int(mu.get("race_index")), str(mu.get("ending_variant")),
				str(mu.get("stingers_played")), str(playing), sting]
		var plays: Dictionary = m.get("plays")
		var ui := []
		for k: Variant in plays:
			if str(k).begins_with("ui") or str(k) in ["beep", "go", "finish"]:
				ui.append("%s:%d" % [str(k), int(plays[k])])
		ui.sort()
		line += " ui=%s" % str(ui)
	else:
		line += "kein ModernAudio"
	if line != _last:
		print(_t(), " MUSIK ", line)
		_last = line
