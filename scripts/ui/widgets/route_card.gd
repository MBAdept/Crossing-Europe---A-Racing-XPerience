class_name RouteCard
extends Button
## Focusable card for one route option, drawn in code. A stage option is shown as the whole route to
## the next target (UiData.route_option / RouteInfo), because that is what the choice is about
## ("Route über Kassel" vs "über Frankfurt"): next stop, km to the target (big), "Route über …",
## the next stage, stage count, and the totals of all legs to the target – autobahn km, km without
## limit, radars, fuel stations, tunnels, traffic level, countries (flag colours).
## Without route info (only the leg is known) the card falls back to the figures of the next stage.
## Ferry options show the fixed crossing time.

var leg: Dictionary = {}
var info: Dictionary = {}          ## UiData.route_option(): {legs, continuation, totals, via, target, km}
var summary: Dictionary = {}       ## figures shown: route totals, or the next stage's summary
var dest := ""
var via := ""                      ## subtitle ("Route über …", "direkt nach …", ferry name)
var next_stage := ""               ## small line: next stage, its length, stages to the target
var km_text := ""
var target_text := ""
var is_ferry := false
var ferry: Dictionary = {}


func _init(p_leg: Dictionary = {}, p_info: Dictionary = {}) -> void:
	leg = p_leg
	info = p_info
	text = ""
	focus_mode = Control.FOCUS_ALL
	is_ferry = str(leg.get("kind", "stage")) == "ferry"
	dest = UiData.city_name(str(leg.get("to", "")))
	if is_ferry:
		ferry = UiData.ferries().get(str(leg.get("id", "")), {})
		via = str(ferry.get("name", tr("Fähre")))
	else:
		var plan := UiData.stage_plan(str(leg.get("id", "")), str(leg.get("from", "")))
		var stage_name := plan.display_name if plan != null else str(leg.get("id", ""))
		var stage_km := plan.length_km if plan != null else float(leg.get("length_km", 0.0))
		if not info.is_empty():
			summary = info.get("totals", {})
			var target := str(info.get("target", ""))
			var names: Array[String] = []
			for c in info.get("via", []):
				names.append(UiData.city_name(str(c)))
			via = UiFormat.route_via(names, UiData.city_name(target))
			km_text = UiFormat.km(float(info.get("km", summary.get("km", 0.0))))
			target_text = tr("bis %s") % UiData.city_name(target)
			var n := int(summary.get("stages", 1))
			var count := tr("1 Etappe") if n == 1 else tr("%d Etappen") % n
			if int(summary.get("ferries", 0)) > 0:
				count += " " + tr("+ Fähre")
			next_stage = tr("Nächste Etappe: %s, %s  ·  %s") % [stage_name, UiFormat.km(stage_km), count]
		else:
			summary = plan.summary() if plan != null else {"length_km": stage_km}
			via = tr("über %s") % stage_name
			km_text = UiFormat.km(float(summary.get("length_km", stage_km)))
	UiTheme.apply_card_button(self)
	pressed.connect(func() -> void: UiKit.sound("ui_ok"))


func _draw() -> void:
	var f_title := UiTheme.font(UiTheme.F.TITLE)
	var f_body := UiTheme.font(UiTheme.F.BODY_MEDIUM)
	var f_bold := UiTheme.font(UiTheme.F.BODY_BOLD)
	var mono := UiTheme.font(UiTheme.F.MONO)
	var focused := has_focus()
	var x := 26.0
	var right_w := 200.0
	draw_string(f_title, Vector2(x, 40), dest, HORIZONTAL_ALIGNMENT_LEFT, size.x - right_w - x, 30, UiTheme.GOLD if focused else Color.WHITE)
	if is_ferry:
		draw_string(f_body, Vector2(x, 66), via, HORIZONTAL_ALIGNMENT_LEFT, size.x - right_w, 19, UiTheme.TEXT_DIM)
		draw_string(mono, Vector2(0, 42), UiFormat.time(float(ferry.get("fixed_time_s", 0.0))), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 24, 30, Color.WHITE)
		draw_string(f_bold, Vector2(x, 104), tr("Feste Überfahrtszeit, +%d h Weltzeit – kein Tanken, kein Radar") % int(ferry.get("world_hours", 0)), HORIZONTAL_ALIGNMENT_LEFT, size.x - 50, 20, UiTheme.ACCENT_2)
		return
	draw_string(mono, Vector2(0, 42), km_text, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 24, 30, Color.WHITE)
	draw_string(f_body, Vector2(x, 65), via, HORIZONTAL_ALIGNMENT_LEFT, size.x - x - 150.0, 19, UiTheme.ACCENT_2 if focused else UiTheme.TEXT)
	if target_text != "":
		draw_string(f_body, Vector2(0, 65), target_text, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 24, 17, UiTheme.TEXT_DIM)
	# countries (flag colours) on the right of the small line
	var codes: Array = summary.get("countries", [])
	var n_flags := mini(codes.size(), 5)
	var fx := size.x - 24.0 - n_flags * 44.0
	var fy := 88.0
	for i in n_flags:
		var code := str(codes[i])
		UiIcons.flag(self, Rect2(fx, fy - 13, 22, 15), UiData.country_colors(code))
		draw_string(f_bold, Vector2(fx + 25, fy + 1), code, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.TEXT_DIM)
		fx += 44.0
	if next_stage != "":
		draw_string(f_body, Vector2(x, fy), next_stage, HORIZONTAL_ALIGNMENT_LEFT, size.x - x - 34.0 - n_flags * 44.0, 17, UiTheme.TEXT_DIM)
	# figures row: totals over the route to the target
	var y := size.y - 18.0
	var cx := x
	cx = _fig(cx, y, "autobahn", "%s %s" % [tr("Autobahn"), UiFormat.km(float(summary.get("autobahn_km", 0.0)))])
	cx = _fig(cx, y, "free", "%s %s" % [UiFormat.km(float(summary.get("unlimited_km", 0.0))), tr("frei")])
	cx = _fig(cx, y, "radar", str(int(summary.get("radars", 0))))
	cx = _fig(cx, y, "pump", str(int(summary.get("stations", 0))))
	cx = _fig(cx, y, "tunnel", str(int(summary.get("tunnels", 0))))
	var traffic := tr("Verkehr: %s") % UiFormat.traffic_level(float(summary.get("traffic", 1.0)))
	draw_string(f_bold, Vector2(0, y), traffic, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 24, 18, UiTheme.TEXT_DIM)


func _fig(x: float, y: float, icon: String, value: String) -> float:
	var f := UiTheme.font(UiTheme.F.BODY_BOLD)
	var ic := Vector2(x + 10, y - 7)
	match icon:
		"radar":
			UiIcons.radar(self, ic, 20.0, UiTheme.WARN)
		"pump":
			UiIcons.pump(self, ic, 20.0, UiTheme.GOOD)
		"free":
			UiIcons.speed_sign(self, ic, 9.0, 0, f)
		"tunnel":
			draw_arc(ic + Vector2(0, 6), 9.0, PI, TAU, 12, Color(0.75, 0.78, 0.85), 3.0, true)
			draw_line(ic + Vector2(-9, 6), ic + Vector2(9, 6), Color(0.75, 0.78, 0.85), 2.0)
		_:
			draw_rect(Rect2(ic.x - 9, ic.y - 8, 18, 16), Color("1f5fbf"))
			draw_rect(Rect2(ic.x - 9, ic.y - 8, 18, 16), Color.WHITE, false, 1.5)
	draw_string(f, Vector2(x + 24, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UiTheme.TEXT)
	return x + 24.0 + f.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 18.0
