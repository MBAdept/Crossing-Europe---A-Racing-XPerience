class_name StageScreen
extends UiScreen
## Stage screen before every stage: record marquee (Laufschrift: name, time, average), map with the
## route and the current stage highlighted, weather, start time, stage facts, race standing and the
## top 10 (name, time, avg, vehicle, weather + daytime icons). "Start" launches the race scene.

var _filter := "all"


func build() -> void:
	var leg: Dictionary = GameFlow.pending_leg
	var race: RaceState = GameFlow.race if GameFlow.mode == "race" else null
	var stage_id := str(leg.get("id", ""))
	var from := str(leg.get("from", ""))
	var plan := UiData.stage_plan(stage_id, from)
	var stage_name := plan.display_name if plan != null else stage_id
	var title := tr("Etappe %d") % race.next_stage_number() if race != null else tr("Einzelne Etappe")
	add_header(title, stage_name, race.race_name if race != null else "")
	hints = [[["Enter", "pad:A"], tr("Start")], [["Esc", "pad:B"], tr("Zurück") if race == null else tr("Hauptmenü")]]
	var board := plan.board_key if plan != null else UiData.stage_board_key(stage_id, from)
	_filter = str(Settings.leaderboard_filter)
	var rec := UiData.record(board, _filter)
	var mq := Marquee.new(UiFormat.marquee_text(rec, stage_name, cfg()))
	UiKit.place(self, mq, Rect2(0, 90, 1280, 42))
	# map
	var map := MapView.new()
	map.set_network(UiData.cities(), UiData.stages(), UiData.ferries(), UiData.map_data())
	var focus: Array[String] = [from, str(leg.get("to", ""))]
	if race != null:
		map.route = race.route.duplicate()
		map.route_done = race.route.size() - 1
		for c in race.route:
			focus.append(c)
		focus.append(race.next_target())
		map.label_ids.append(race.next_target())
	map.current_city = from
	map.highlight = [{"from": from, "to": str(leg.get("to", "")), "style": "current"}]
	UiKit.place(self, map, Rect2(40, 146, 640, 372))
	map.fit_to(focus)
	# info tiles
	var start_min: float = race.world_minutes if race != null else float(GameFlow.single.get("hour", 8.0)) * 60.0
	var hour := Units.hour_of_day(start_min)
	var tiles := _InfoTiles.new()
	tiles.weather = GameFlow.pending_weather
	tiles.hour = hour
	tiles.daytime = WorldClock.daytime_category(hour, cfg())
	tiles.length_km = plan.length_km if plan != null else float(leg.get("length_km", 0.0))
	tiles.summary = plan.summary() if plan != null else {}
	tiles.race_total = race.total_time_s if race != null else -1.0
	tiles.race_stages = race.stage_count() if race != null else 0
	UiKit.place(self, tiles, Rect2(40, 528, 640, 92))
	# top 10
	var right := add_panel(Rect2(700, 146, 540, 474), UiTheme.GOLD, 4)
	var head := UiKit.hbox(8)
	right.add_child(head)
	var t := UiKit.label(tr("TOP 10"), UiTheme.F.TITLE, 28, UiTheme.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UiKit.label(UiFormat.vehicle_name(_filter, cfg()), UiTheme.F.BODY_BOLD, 19, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT))
	var table := LeaderboardTable.new()
	table.custom_minimum_size = Vector2(500, 400)
	table.set_entries(UiData.top(board, _filter, 10))
	right.add_child(table)
	# buttons
	var start := UiKit.button(tr("Start"), 30, HORIZONTAL_ALIGNMENT_CENTER)
	start.add_theme_color_override("font_color", UiTheme.GOLD)
	start.pressed.connect(GameFlow.start_pending_stage)
	UiKit.place(self, start, Rect2(700, 628, 300, 48))
	var back := UiKit.button(tr("Hauptmenü") if race != null else tr("Zurück"), 22, HORIZONTAL_ALIGNMENT_CENTER)
	back.pressed.connect(on_cancel)
	UiKit.place(self, back, Rect2(1016, 628, 224, 48))
	default_focus = start


func on_cancel() -> void:
	if GameFlow.mode == "race":
		GameFlow.leave_race_to_title()
	else:
		GameFlow.back()


class _InfoTiles extends Control:
	var weather := "normal"
	var hour := 8.0
	var daytime := "day"
	var length_km := 0.0
	var summary: Dictionary = {}
	var race_total := -1.0
	var race_stages := 0

	func _draw() -> void:
		var n := 4
		var gap := 10.0
		var tw := (size.x - gap * (n - 1)) / n
		var fh := UiTheme.font(UiTheme.F.BODY_BOLD)
		var fm := UiTheme.font(UiTheme.F.MONO)
		var fb := UiTheme.font(UiTheme.F.BODY_MEDIUM)
		for i in n:
			var r := Rect2(i * (tw + gap), 0, tw, size.y)
			UiIcons.panel(self, r, UiTheme.PANEL, Color(UiTheme.ACCENT_2, 0.35), 10.0)
			var ic := r.position + Vector2(30, 34)
			match i:
				0:
					UiIcons.weather(self, weather, ic, 38.0)
					draw_string(fh, r.position + Vector2(56, 30), tr("WETTER"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.TEXT_MUTED)
					draw_string(fh, r.position + Vector2(56, 56), UiFormat.weather_name(weather), HORIZONTAL_ALIGNMENT_LEFT, tw - 60, 24, UiTheme.weather_color(weather))
				1:
					UiIcons.daytime(self, daytime, ic, 38.0)
					draw_string(fh, r.position + Vector2(56, 30), tr("START"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.TEXT_MUTED)
					draw_string(fm, r.position + Vector2(56, 58), UiFormat.clock_hour(hour), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
				2:
					draw_string(fh, r.position + Vector2(14, 30), tr("LÄNGE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.TEXT_MUTED)
					draw_string(fm, r.position + Vector2(14, 58), UiFormat.km(length_km), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
				3:
					draw_string(fh, r.position + Vector2(14, 30), tr("RENNZEIT BISHER") if race_total >= 0.0 else tr("MODUS"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.TEXT_MUTED)
					if race_total >= 0.0:
						draw_string(fm, r.position + Vector2(14, 58), UiFormat.time(race_total) if race_stages > 0 else "--:--.--", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiTheme.GOLD)
					else:
						draw_string(fh, r.position + Vector2(14, 56), tr("Zeitfahren"), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiTheme.GOLD)
			var sub := ""
			match i:
				1:
					sub = UiFormat.daytime_name(daytime)
				2:
					if not summary.is_empty():
						sub = tr("%d Radar · %d Tankst.") % [int(summary.get("radars", 0)), int(summary.get("stations", 0))]
				3:
					if race_total >= 0.0:
						sub = tr("nach %d Etappen") % race_stages if race_stages != 1 else tr("nach 1 Etappe")
			if sub != "":
				draw_string(fb, r.position + Vector2(14 if i >= 2 else 56, 80), sub, HORIZONTAL_ALIGNMENT_LEFT, tw - 20, 16, UiTheme.TEXT_DIM)
