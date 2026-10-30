class_name StageScreen
extends UiScreen
## Stage screen before every stage: record marquee (Laufschrift: name, time, average of the stage
## record over all vehicles – the record holder, like the HUD and the result screen), map with the
## route and the current stage highlighted, weather, start time, stage facts, race standing, the
## stage description and the top 10 (name, time + weather/daytime icons, avg, vehicle; vehicle
## filter of the leaderboard browser). Tutorial stages (StagePlan.tutorial, Kiel – Hamburg) get a
## "So geht's" box: controls, refuelling and radar tolerance (numbers from the configuration).
## "Start" launches the race scene.

var _filter := "all"
var marquee: Marquee
var description_label: Label        ## stage description (null if the stage has none)
var tutorial_box: Control           ## "So geht's" panel (null unless plan.tutorial)


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
	# the marquee names the record holder: overall record, never the vehicle-filtered best time
	var rec := UiData.record(board)
	marquee = Marquee.new(UiFormat.marquee_text(rec, stage_name, cfg()))
	UiKit.place(self, marquee, Rect2(0, 90, 1280, 42))
	var tutorial := plan != null and plan.tutorial
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
	UiKit.place(self, map, Rect2(40, 146, 640, 204 if tutorial else 372))
	map.fit_to(focus)
	if tutorial:
		tutorial_box = _tutorial_box(plan)
		UiKit.place(self, tutorial_box, Rect2(40, 358, 640, 162))
	if plan != null and plan.description != "":
		description_label = UiKit.label(plan.description, UiTheme.F.BODY_MEDIUM, 17, UiTheme.TEXT_DIM)
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.max_lines_visible = 2
		description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		description_label.add_theme_constant_override("line_spacing", -3)
		description_label.custom_minimum_size = Vector2(636, 0)
		UiKit.place(self, description_label, Rect2(44, 626, 636, 46))
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


## "So geht's" for tutorial stages: controls (keycaps + gamepad), refuelling and radar – the numbers
## (fuel-lane speed, start filling, tolerance, trigger speed, escape speed) come from config and plan.
func _tutorial_box(plan: StagePlan) -> Control:
	var p := UiKit.panel(UiTheme.PANEL, UiTheme.ACCENT_2, 12)
	var box := UiKit.vbox(4)
	p.add_child(box)
	var row := UiKit.hbox(16)
	box.add_child(row)
	var head := UiKit.label(tr("SO GEHT'S"), UiTheme.F.HEADING, 20, UiTheme.ACCENT_2)
	head.custom_minimum_size = Vector2(0, 30)
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(head)
	# Pause (Esc / Start) is left out: the race shows it, and the row must fit the panel
	var keys := KeyHints.new([[["left", "right"], tr("Lenken")], [["up", "pad:RT"], tr("Gas")], [["down", "pad:LT"], tr("Bremse")]])
	keys.custom_minimum_size = Vector2(460, 30)
	row.add_child(keys)
	var limit := 0.0
	if not plan.radars.is_empty():
		limit = float(plan.radars[0].get("limit", 0))
	var tips := UiFormat.tutorial_tips(cfg(), limit, plan.start_fuel_fraction)
	var icons := ["pump", "radar"]
	for i in tips.size():
		var tip := UiKit.hbox(10)
		box.add_child(tip)
		var ic := _TipIcon.new()
		ic.kind = str(icons[i]) if i < icons.size() else ""
		ic.custom_minimum_size = Vector2(26, 24)
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		tip.add_child(ic)
		var l := UiKit.label(tips[i], UiTheme.F.BODY_MEDIUM, 17, UiTheme.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(574, 0)   # fixed wrap width -> correct height from the start
		l.add_theme_constant_override("line_spacing", -3)
		tip.add_child(l)
	return p


class _TipIcon extends Control:
	var kind := ""

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, 13.0)
		match kind:
			"pump":
				UiIcons.pump(self, c, 22.0, UiTheme.GOOD)
			"radar":
				UiIcons.radar(self, c, 22.0, UiTheme.WARN)


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
