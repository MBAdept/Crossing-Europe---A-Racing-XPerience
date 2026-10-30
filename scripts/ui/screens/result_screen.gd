class_name ResultScreen
extends UiScreen
## Stage result: time, average, penalties, record comparison and statistics; in a race also the
## standing and the start of the next stage. Top-10 time -> name entry (remembered in Settings) ->
## leaderboard with the new entry highlighted.

var result: Dictionary = {}
var _right: VBoxContainer
var _next: Button
var _board := ""
var _entry: Dictionary = {}


func build() -> void:
	result = params.get("result", {})
	var race: RaceState = GameFlow.race if GameFlow.mode == "race" else null
	_board = str(result.get("board_key", ""))
	add_header(tr("Etappe beendet"), str(result.get("stage_name", "")), race.race_name if race != null else "")
	hints = [[["Enter", "pad:A"], tr("Bestätigen")]]
	var c := cfg()
	var time_s := float(result.get("time_s", 0.0))
	var left := add_panel(Rect2(40, 104, 584, 508), UiTheme.ACCENT, 6)
	left.add_child(UiKit.label(tr("ZEIT"), UiTheme.F.BODY_BOLD, 18, UiTheme.TEXT_MUTED))
	var big := UiKit.label(UiFormat.time(time_s), UiTheme.F.MONO, 74, Color.WHITE)
	big.add_theme_color_override("font_shadow_color", Color(UiTheme.ACCENT, 0.55))
	big.add_theme_constant_override("shadow_offset_x", 3)
	big.add_theme_constant_override("shadow_offset_y", 3)
	left.add_child(big)
	var line := tr("Ø %s") % UiFormat.kmh(float(result.get("avg_speed_kmh", 0.0)))
	var pen := float(result.get("penalty_s", 0.0))
	if pen > 0.0:
		line += "   ·   " + tr("inkl. %s Strafe") % UiFormat.time(pen)
	left.add_child(UiKit.label(line, UiTheme.F.HEADING, 24, UiTheme.ACCENT_2))
	# record comparison (before submitting)
	var rec := UiData.record(_board)
	var cmp := UiKit.label("", UiTheme.F.BODY_BOLD, 22, UiTheme.GOLD)
	if rec.is_empty() or time_s < float(rec.get("time_s", INF)):
		cmp.text = tr("NEUER ETAPPENREKORD!")
	else:
		var d := time_s - float(rec.get("time_s", 0.0))
		cmp.text = tr("Rekord %s (%s)  %s") % [UiFormat.time(float(rec.get("time_s", 0.0))), str(rec.get("name", "")), UiFormat.delta(d)]
		cmp.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	left.add_child(cmp)
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 10)
	left.add_child(sep)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 34)
	grid.add_theme_constant_override("v_separation", 4)
	left.add_child(grid)
	var stats := [
		[tr("Kollisionen"), str(int(result.get("collisions", 0)))],
		[tr("Tankstopps"), tr("%d (%s)") % [int(result.get("refuels", 0)), UiFormat.liters(float(result.get("liters_refueled", 0.0)))]],
		[tr("Geblitzt"), str(int(result.get("radar_flashes", 0)))],
		[tr("Polizei entkommen"), str(int(result.get("police_escapes", 0)))],
		[tr("Polizeikontrollen"), str(int(result.get("police_stops", 0)))],
		[tr("Abschleppdienst"), str(int(result.get("tow_events", 0)))],
	]
	for st in stats:
		var row := UiKit.stat_line(str(st[0]), str(st[1]), UiTheme.TEXT, 20)
		row.custom_minimum_size = Vector2(250, 0)
		grid.add_child(row)
	var cond := _Conditions.new()
	cond.weather = str(result.get("weather", "normal"))
	cond.hour = float(result.get("start_hour", 8.0))
	cond.daytime = str(result.get("daytime", WorldClock.daytime_category(cond.hour, c)))
	cond.vehicle = UiFormat.vehicle_name(str(result.get("vehicle", "")), c)
	cond.custom_minimum_size = Vector2(540, 40)
	left.add_child(cond)
	if race != null:
		var s2 := HSeparator.new()
		left.add_child(s2)
		left.add_child(UiKit.stat_line(tr("Rennzeit nach Etappe %d") % race.stage_count(), UiFormat.time(race.total_time_s), UiTheme.GOLD, 22))
		if not race.is_finished():
			left.add_child(UiKit.stat_line(next_start_caption(c), tr("%s Uhr") % Units.format_clock(race.world_minutes), UiTheme.TEXT, 20))
	# right: name entry or leaderboard
	_right = add_panel(Rect2(644, 104, 596, 508), UiTheme.GOLD, 10)
	_next = UiKit.button(tr("Weiter") if race == null or not race.is_finished() else tr("Zum Rennergebnis"), 28, HORIZONTAL_ALIGNMENT_CENTER)
	_next.pressed.connect(GameFlow.result_continue)
	UiKit.place(self, _next, Rect2(644, 622, 596, 50))
	var vehicle := str(result.get("vehicle", ""))
	var rank := UiData.would_rank(_board, time_s, "")
	var rank_v := UiData.would_rank(_board, time_s, vehicle) if vehicle != "" else 0
	if _board != "" and not bool(result.get("aborted", false)) and (rank > 0 or rank_v > 0):
		_entry = {"time_s": time_s, "avg_kmh": float(result.get("avg_speed_kmh", 0.0)), "vehicle": vehicle,
			"weather": str(result.get("weather", "normal")), "start_hour": float(result.get("start_hour", 8.0)),
			"daytime": cond.daytime, "date": Time.get_date_string_from_system()}
		var head := UiFormat.placement_headline(false, rank, rank_v, UiFormat.vehicle_name(vehicle, c))
		_right.add_child(UiKit.label(head, UiTheme.F.TITLE, 34, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		_right.add_child(UiKit.label(tr("Trag dich in die Bestenliste ein:"), UiTheme.F.BODY_MEDIUM, 21, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
		var ne := NameEntry.new(str(Settings.player_name))
		ne.alignment = BoxContainer.ALIGNMENT_CENTER
		ne.submitted.connect(_on_name)
		_right.add_child(ne)
		_next.visible = false
		default_focus = ne.line
		hints = NameEntry.key_hints()
	else:
		_show_board("", 0)
		default_focus = _next


## "Nächster Start (12 h Pause)" – the pause is time.stage_pause_hours (what RaceState really adds).
static func next_start_caption(config: Dictionary) -> String:
	var pause_h := float(ConfigLoader.lookup(config, "time.stage_pause_hours", 12.0))
	return UiFormat.t("Nächster Start (%s h Pause)") % UiFormat.number(pause_h)


func _on_name(player_name: String) -> void:
	GameFlow.remember_player_name(player_name)
	_entry["name"] = player_name
	UiKit.sound("finish")
	UiData.submit(_board, _entry)
	GameFlow.stage_result_done()   # entry stored -> the save no longer needs the pending result
	var filter := UiData.board_filter_for(_board, _entry)
	for ch in _right.get_children():
		ch.queue_free()
	_show_board(filter, -1)
	_next.visible = true
	_focus_later(_next)
	set_hints([[["Enter", "pad:A"], tr("Weiter")]])


func _find(list: Array) -> int:
	return UiData.entry_index(list, _entry)


func _show_board(filter: String, highlight: int) -> void:
	var head := UiKit.hbox(8)
	var t := UiKit.label(tr("TOP 10"), UiTheme.F.TITLE, 30, UiTheme.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UiKit.label(UiFormat.vehicle_name(filter, cfg()), UiTheme.F.BODY_BOLD, 19, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT))
	_right.add_child(head)
	var table := LeaderboardTable.new()
	table.custom_minimum_size = Vector2(556, 420)
	var list := UiData.top(_board, filter, 10)
	var hl := highlight
	if hl < 0:
		hl = _find(list) + 1
	table.set_entries(list, hl)
	_right.add_child(table)


func on_cancel() -> void:
	pass


class _Conditions extends Control:
	var weather := "normal"
	var hour := 8.0
	var daytime := "day"
	var vehicle := ""

	func _draw() -> void:
		var f := UiTheme.font(UiTheme.F.BODY_BOLD)
		var cy := size.y * 0.5
		UiIcons.weather(self, weather, Vector2(16, cy), 28.0)
		draw_string(f, Vector2(36, cy + 7), UiFormat.weather_name(weather), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiTheme.TEXT)
		UiIcons.daytime(self, daytime, Vector2(150, cy), 28.0)
		draw_string(f, Vector2(170, cy + 7), tr("Start %s Uhr") % UiFormat.clock_hour(hour), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiTheme.TEXT)
		draw_string(f, Vector2(340, cy + 7), vehicle, HORIZONTAL_ALIGNMENT_LEFT, size.x - 340, 20, UiTheme.TEXT_DIM)
