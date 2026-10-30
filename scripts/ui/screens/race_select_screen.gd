class_name RaceSelectScreen
extends UiScreen
## Race selection: list of races, map preview of all possible routes of the focused race, length
## range, stage count, mandatory stations, description and race record.

var _map: MapView
var _title: Label
var _desc: Label
var _facts: VBoxContainer
var _record: Label


func build() -> void:
	add_header(tr("Rennen wählen"), tr("Etappenrennen quer durch Europa"))
	hints = [[["ud"], tr("Rennen")], [["Enter", "pad:A"], tr("Auswählen")], [["Esc", "pad:B"], tr("Zurück")]]
	var ids := UiData.visible_race_ids()
	var lst: Array = UiKit.scroll_list(8)
	var sc: ScrollContainer = lst[0]
	var box: VBoxContainer = lst[1]
	UiKit.place(self, sc, Rect2(56, 104, 400, 560))
	var first: Button = null
	for id in ids:
		var b := UiKit.button(UiData.race_name(id), 24)
		b.custom_minimum_size = Vector2(380, 50)
		b.clip_text = true
		b.pressed.connect(func() -> void: GameFlow.select_race(id))
		b.focus_entered.connect(func() -> void: _show_race(id))
		box.add_child(b)
		if first == null:
			first = b
	_map = MapView.new()
	_map.set_network(UiData.cities(), UiData.stages(), UiData.ferries(), UiData.map_data())
	UiKit.place(self, _map, Rect2(476, 104, 748, 262))
	# info panel sized for the longest content (title, 4 description lines, 2 fact lines, record) – the
	# description wraps at a fixed width and is cut with "…", so the panel never grows over the footer
	var info := add_panel(Rect2(476, 374, 748, 290), UiTheme.ACCENT, 4)
	_title = UiKit.label("", UiTheme.F.HEADING, 28, Color.WHITE)
	info.add_child(_title)
	_desc = UiKit.label("", UiTheme.F.BODY_MEDIUM, 19, UiTheme.TEXT_DIM)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(708, 108)   # four lines
	_desc.max_lines_visible = 4
	_desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_desc.add_theme_constant_override("line_spacing", -5)
	info.add_child(_desc)
	_facts = UiKit.vbox(2)
	info.add_child(_facts)
	_record = _line_label("", UiTheme.F.BODY_BOLD, UiTheme.GOLD)
	info.add_child(_record)
	if first == null:
		_title.text = tr("Keine Rennen verfügbar")
		var back := UiKit.button(tr("Zurück"), 24)
		back.pressed.connect(GameFlow.back)
		box.add_child(back)
		first = back
	default_focus = first
	if not ids.is_empty():
		_show_race(ids[0])


## "Rekord" = the overall race record (the record holder); with a vehicle filter of the leaderboard
## browser the best time of that vehicle is added and named, never passed off as the record.
static func record_text(race_id: String, filter: String) -> String:
	var key := UiData.race_board_key(race_id)
	var rec := UiData.record(key)
	if rec.is_empty():
		return UiFormat.t("Noch kein Rekord für dieses Rennen")
	var s := UiFormat.t("Rekord: %s – %s (Ø %s)") % [str(rec.get("name", "")), UiFormat.time(float(rec.get("time_s", -1.0))), UiFormat.kmh(float(rec.get("avg_kmh", 0.0)))]
	if filter != "" and filter != "all":
		var best := UiData.record(key, filter)
		var vname := UiFormat.vehicle_name(filter, UiData.cfg())
		if best.is_empty():
			s += "  ·  " + UiFormat.t("%s: noch keine Zeit") % vname
		elif best != rec:
			s += "  ·  " + UiFormat.t("%s: %s – %s") % [vname, str(best.get("name", "")), UiFormat.time(float(best.get("time_s", -1.0)))]
	return s


## One-line label of the info panel: clipped with "…" so a long line (17 Pflichtstationen of the
## Königsrennen) can never widen the panel beyond the screen.
func _line_label(text: String, kind: int, col: Color) -> Label:
	var l := UiKit.label(text, kind, 20, col)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _show_race(race_id: String) -> void:
	var r := UiData.race(race_id)
	_title.text = UiData.race_name(race_id)
	_desc.text = str(r.get("description", ""))
	for c in _facts.get_children():
		c.queue_free()
	var start := str(r.get("start", ""))
	var finish := str(r.get("finish", ""))
	var wps: Array = r.get("waypoints", [])
	var routes := UiData.race_routes(race_id)
	var st := UiData.race_summary(race_id)
	var line1 := tr("Start %s  ·  Ziel %s") % [UiData.city_name(start), UiData.city_name(finish)]
	if not wps.is_empty():
		var names: Array[String] = []
		for w in wps:
			names.append(UiData.city_name(str(w)))
		line1 += "  ·  " + tr("Pflichtstationen: %s") % ", ".join(names)
	_facts.add_child(_line_label(line1, UiTheme.F.BODY_BOLD, UiTheme.TEXT))
	var line2 := tr("Strecke wird noch geplant")
	if int(st.get("count", 0)) > 0:
		var km_txt := UiFormat.km(float(st["min_km"]))
		if absf(float(st["max_km"]) - float(st["min_km"])) > 1.0:
			km_txt = "%s – %s" % [UiFormat.decimal(float(st["min_km"]), 0), UiFormat.km(float(st["max_km"]))]
		var stg := str(st["min_stages"])
		if int(st["max_stages"]) != int(st["min_stages"]):
			stg = "%d – %d" % [int(st["min_stages"]), int(st["max_stages"])]
		line2 = tr("%s  ·  %s Etappen  ·  %d mögliche Routen") % [km_txt, stg, int(st["count"])]
		if bool(st.get("ferry", false)):
			line2 += "  ·  " + tr("mit Fähre")
	_facts.add_child(_line_label(line2, UiTheme.F.BODY_MEDIUM, UiTheme.ACCENT_2))
	_record.text = record_text(race_id, str(Settings.leaderboard_filter))
	# map: union of all route legs, start/finish labels
	var hl: Array[Dictionary] = []
	var seen := {}
	var focus: Array[String] = [start, finish]
	for route in routes:
		for leg in route:
			var key := "%s>%s" % [leg.get("from", ""), leg.get("to", "")]
			if seen.has(key):
				continue
			seen[key] = true
			hl.append({"from": str(leg.get("from", "")), "to": str(leg.get("to", "")), "style": "ferry" if str(leg.get("kind", "")) == "ferry" else "option_selected"})
			focus.append(str(leg.get("to", "")))
	for w in wps:
		focus.append(str(w))
	_map.highlight = hl
	_map.route.clear()
	_map.current_city = start
	_map.label_ids.clear()
	_map.label_ids.append_array([start, finish])
	_map.fit_to(focus)
