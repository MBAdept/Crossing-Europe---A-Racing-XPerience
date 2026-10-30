class_name RouteCard
extends Button
## Focusable card for one route option (stage or ferry) with its key figures, drawn in code:
## destination, stage name, length, autobahn km, km without limit, radars, fuel stations, tunnels,
## traffic level, countries (flag colours).

var leg: Dictionary = {}
var summary: Dictionary = {}
var dest := ""
var via := ""
var is_ferry := false
var ferry: Dictionary = {}


func _init(p_leg: Dictionary = {}) -> void:
	leg = p_leg
	text = ""
	focus_mode = Control.FOCUS_ALL
	is_ferry = str(leg.get("kind", "stage")) == "ferry"
	dest = UiData.city_name(str(leg.get("to", "")))
	if is_ferry:
		ferry = UiData.ferries().get(str(leg.get("id", "")), {})
		via = str(ferry.get("name", tr("Fähre")))
	else:
		var plan := UiData.stage_plan(str(leg.get("id", "")), str(leg.get("from", "")))
		if plan != null:
			summary = plan.summary()
			via = plan.display_name
		else:
			summary = {"length_km": float(leg.get("length_km", 0.0))}
			via = str(leg.get("id", ""))
	UiTheme.apply_card_button(self)
	pressed.connect(func() -> void: UiKit.sound("ui_ok"))


func _draw() -> void:
	var f_title := UiTheme.font(UiTheme.F.TITLE)
	var f_body := UiTheme.font(UiTheme.F.BODY_MEDIUM)
	var f_bold := UiTheme.font(UiTheme.F.BODY_BOLD)
	var mono := UiTheme.font(UiTheme.F.MONO)
	var focused := has_focus()
	var x := 26.0
	draw_string(f_title, Vector2(x, 42), dest, HORIZONTAL_ALIGNMENT_LEFT, size.x - 210, 32, UiTheme.GOLD if focused else Color.WHITE)
	draw_string(f_body, Vector2(x, 68), (tr("über %s") % via) if not is_ferry else via, HORIZONTAL_ALIGNMENT_LEFT, size.x - 210, 19, UiTheme.TEXT_DIM)
	if is_ferry:
		draw_string(mono, Vector2(0, 44), UiFormat.time(float(ferry.get("fixed_time_s", 0.0))), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 24, 30, Color.WHITE)
		draw_string(f_bold, Vector2(x, 104), tr("Feste Überfahrtszeit, +%d h Weltzeit – kein Tanken, kein Radar") % int(ferry.get("world_hours", 0)), HORIZONTAL_ALIGNMENT_LEFT, size.x - 50, 20, UiTheme.ACCENT_2)
		return
	draw_string(mono, Vector2(0, 44), UiFormat.km(float(summary.get("length_km", 0.0))), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 24, 32, Color.WHITE)
	var traffic := UiFormat.traffic_level(float(summary.get("traffic", 1.0)))
	draw_string(f_body, Vector2(0, 68), tr("Verkehr: %s") % traffic, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 24, 19, UiTheme.TEXT_DIM)
	# figures row
	var y := 104.0
	var cx := x
	cx = _fig(cx, y, "autobahn", "%s %s" % [tr("Autobahn"), UiFormat.km(float(summary.get("autobahn_km", 0.0)))])
	cx = _fig(cx, y, "free", "%s %s" % [UiFormat.km(float(summary.get("unlimited_km", 0.0))), tr("frei")])
	cx = _fig(cx, y, "radar", str(int(summary.get("radars", 0))))
	cx = _fig(cx, y, "pump", str(int(summary.get("stations", 0))))
	cx = _fig(cx, y, "tunnel", str(int(summary.get("tunnels", 0))))
	var codes: Array = summary.get("countries", [])
	var fx := size.x - 24.0 - codes.size() * 44.0
	for code in codes:
		UiIcons.flag(self, Rect2(fx, y - 15, 22, 15), UiData.country_colors(str(code)))
		draw_string(f_bold, Vector2(fx + 25, y - 1), str(code), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiTheme.TEXT_DIM)
		fx += 44.0


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
