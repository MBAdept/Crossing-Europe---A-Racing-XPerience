class_name StageScreen
extends UiScreen
## Stage screen before every stage: record marquee (Laufschrift: name, time, average of the stage
## record over all vehicles – the record holder, like the HUD and the result screen), map with the
## route and the current stage highlighted, weather, start time, stage facts, race standing, the
## stage description and the top 10 (name, time + weather/daytime icons, avg, vehicle; vehicle
## filter of the leaderboard browser). Tutorial stages (StagePlan.tutorial, Kiel – Hamburg) get a
## "So geht's" box: controls, refuelling and radar tolerance (numbers from the configuration).
## Fuel strip under the map (v0.7.0): the tank the stage starts with – in a race the tank of the last stage
## (RaceState.fuel_l), else the stage's own filling – with gauge, the first station and what the tank is good for on
## the way there (FuelSystem.start_check with the chosen car: even at full speed / at most X km/h / the tow service
## before the start).
## "Start" launches the race scene.

var _filter := "all"
var marquee: Marquee
var description_label: Label        ## stage description (null if the stage has none)
var tutorial_box: Control           ## "So geht's" panel (null unless plan.tutorial)
var fuel_strip: Control             ## the tank at the start and the way to the first station (null without a plan)


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
	# v0.7.0: the fuel strip takes the bottom of the map's room (above the tutorial box on the tutorial stage)
	var strip_h := 54.0 if plan != null else 0.0
	var map_h := (204.0 if tutorial else 372.0) - (strip_h + 8.0 if plan != null else 0.0)
	UiKit.place(self, map, Rect2(40, 146, 640, map_h))
	map.fit_to(focus)
	if plan != null:
		fuel_strip = _fuel_strip(plan, race)
		UiKit.place(self, fuel_strip, Rect2(40, 146 + map_h + 8.0, 640, strip_h))
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
	# Pause (Esc / Start) is left out: the race shows it under the start lights, and the row must fit the panel
	var keys := KeyHints.new([[["left", "right", "pad:LS"], tr("Lenken")], [["up", "pad:RT"], tr("Gas")], [["down", "pad:LT"], tr("Bremse")]])
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


## Fuel strip (v0.7.0): the tank of the chosen car at the start – carried over in a race (RaceState.fuel_l >= 0),
## else the stage's own filling (FuelSystem.start_fill_fraction) – and FuelSystem.start_check for the way to the
## first station, exactly what the race session decides at the start.
func _fuel_strip(plan: StagePlan, race: RaceState) -> Control:
	var vehicle_id := race.vehicle if race != null else str(GameFlow.single.get("vehicle", ConfigLoader.lookup(cfg(), "vehicles.default", "limousine")))
	var spec := VehicleModel.resolve_spec(cfg(), vehicle_id)
	var strip := _FuelStrip.new()
	strip.tank = float(spec.get("tank_l", ConfigLoader.lookup(cfg(), "vehicles.base_tank_l", 50.0)))
	var carried := race != null and race.fuel_l >= 0.0
	strip.litres = clampf(race.fuel_l, 0.0, strip.tank) if carried else strip.tank * FuelSystem.start_fill_fraction(cfg(), plan)
	strip.origin = UiFormat.fuel_origin(carried, strip.litres, strip.tank)
	strip.reserve = float(ConfigLoader.lookup(cfg(), "fuel.reserve_warning_l", 8.0))
	var check := FuelSystem.start_check(cfg(), spec, plan, strip.litres)
	strip.state = str(check["state"])
	strip.station = UiFormat.first_station_text(float(check["first_km"]))
	var verdict := UiFormat.fuel_verdict(check, cfg())
	strip.verdict = verdict[0]
	strip.verdict_kind = verdict[1]
	return strip


class _FuelStrip extends Control:
	var litres := 0.0
	var tank := 50.0
	var reserve := 8.0
	var origin := ""
	var station := ""
	var verdict := ""
	var verdict_kind := "good"
	var state := "ok"

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var col: Color = {"good": UiTheme.GOOD, "warn": UiTheme.WARN, "bad": UiTheme.BAD}.get(verdict_kind, UiTheme.TEXT)
		UiIcons.panel(self, r, UiTheme.PANEL, Color(col, 0.55) if verdict_kind != "good" else Color(UiTheme.ACCENT_2, 0.35), 10.0)
		var fh := UiTheme.font(UiTheme.F.BODY_BOLD)
		var fm := UiTheme.font(UiTheme.F.MONO)
		var fb := UiTheme.font(UiTheme.F.BODY_MEDIUM)
		var low := litres < reserve
		UiIcons.pump(self, Vector2(26, size.y * 0.5), 26.0, UiTheme.BAD if low else UiTheme.TEXT)
		draw_string(fh, Vector2(50, 22), tr("TANK"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.TEXT_MUTED)
		draw_string(fm, Vector2(96, 23), "%d / %d L" % [SessionRules.shown_litres(litres), roundi(tank)], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
		draw_string(fb, Vector2(50, 23), origin, HORIZONTAL_ALIGNMENT_RIGHT, 246, 15, UiTheme.TEXT_DIM)
		# gauge like the HUD's: segments, green / yellow below 30 % / red below the reserve, reserve mark
		var segs := 24
		var gx := 50.0
		var gw := 246.0
		var sw := gw / segs
		var frac := clampf(litres / maxf(tank, 1.0), 0.0, 1.0)
		var lit := int(ceilf(frac * segs - 0.001))
		var fill := UiTheme.BAD if low else (UiTheme.GOOD if frac > 0.3 else UiTheme.WARN)
		for i in segs:
			draw_rect(Rect2(gx + i * sw + 1, 32, sw - 2, 11), fill if i < lit else Color(1, 1, 1, 0.1))
		var rx := gx + gw * clampf(reserve / maxf(tank, 1.0), 0.0, 1.0)
		draw_line(Vector2(rx, 29), Vector2(rx, 46), Color(UiTheme.BAD, 0.9), 2.0)
		draw_string(fh, Vector2(318, 23), station, HORIZONTAL_ALIGNMENT_LEFT, size.x - 330, 17, UiTheme.TEXT)
		draw_string(fh, Vector2(318, 45), verdict, HORIZONTAL_ALIGNMENT_LEFT, size.x - 330, 17, col)


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
				draw_string(fb, r.position + Vector2(14, 82), sub, HORIZONTAL_ALIGNMENT_LEFT, tw - 20, 18, UiTheme.TEXT_DIM)
