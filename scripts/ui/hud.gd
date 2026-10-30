class_name Hud
extends Control
## In-race HUD, drawn in one _draw() pass (cheap, crisp at 1280×720). Owner: UI module.
## Public API = contract (ARCHITECTURE.md §9): setup_stage(plan, cfg), update_state(state) every frame,
## show_message(text, kind, duration), flash(color, duration).
##
## Layout (keeps the road centre free):
##   top-left    clock + day/night icon, weather, country (flag colours), stage name
##   top-centre  stage time, record + pace delta, penalties; below: progress bar with markers
##               (fuel stations, radars, tunnels, borders, City Limits, finish)
##   top-right   speed-limit sign ("frei" = end-of-restrictions sign), radar warning, City Limits
##               town sign, police chase panel (blinking, escape meter)
##   bottom-left fuel gauge (litres, reserve warning), range at current speed, next station
##   bottom-right analog speedometer (arc, vmax mark, limit mark) + digital km/h
##   centre      message queue, countdown 3-2-1-LOS!, refuel / tow overlays, finish banner
##   full screen radar flash, collision flash
## Debug: CLI --hud-demo=refuel,police,radar,radarzone,tow,countdown,reserve,finish,city,night overlays
## demo values onto the live state (screenshots of rare situations).

const SPEEDO_A0 := 135.0
const SPEEDO_A1 := 405.0
const GO_TIME := 1.1
const DEMO := {
	"refuel": {"refuel": {"active": true, "progress01": 0.46, "liters": 23.4, "time_left_s": 6.3}, "speed_kmh": 0.0, "fuel_l": 31.0},
	"police": {"police_state": "chase", "police_gap_m": 140.0, "escape01": 0.62, "speed_kmh": 226.0},
	"radar": {"radar_warning": {"distance_km": 4.2, "limit": 120, "in_zone": false}, "speed_limit": 120},
	"radarzone": {"radar_warning": {"distance_km": 0.0, "limit": 120, "in_zone": true}, "speed_limit": 120},
	"tow": {"tow": {"active": true}, "fuel_l": 0.0, "speed_kmh": 0.0, "range_km": 0.0},
	"countdown": {"countdown": 2},
	"reserve": {"fuel_l": 5.5, "range_km": 21.0, "next_station_km": 24.0},
	"finish": {"finished": true},
	"city": {"city_limits": true, "speed_limit": 50},
	"understeer": {"understeer": 0.8},
}

var state: Dictionary = {}
var plan: StagePlan
var cfg: Dictionary = {}

var _messages: Array[Dictionary] = []
var _flash := Color(0, 0, 0, 0)
var _flash_t := 0.0
var _flash_len := 0.0
var _t := 0.0
var _last_countdown := -1
var _count_pop := 0.0
var _go_t := 0.0
var _reserve_l := 8.0
var _speedo_max := 300.0
var _escape_kmh := 220.0
var _max_messages := 3
var _show_fps := false
var _country_colors: Dictionary = {}
var _country_names: Dictionary = {}
var _demo: Dictionary = {}
var _finish_text := ""
var _f_mono: Font
var _f_body: Font
var _f_bold: Font
var _f_head: Font
var _f_title: Font
var _f_logo: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_f_mono = UiTheme.font(UiTheme.F.MONO)
	_f_body = UiTheme.font(UiTheme.F.BODY)
	_f_bold = UiTheme.font(UiTheme.F.BODY_BOLD)
	_f_head = UiTheme.font(UiTheme.F.HEADING)
	_f_title = UiTheme.font(UiTheme.F.TITLE)
	_f_logo = UiTheme.font(UiTheme.F.LOGO)
	if CliArgs.has("hud-demo"):
		for key in CliArgs.get_string("hud-demo", "").split(",", false):
			_demo.merge(DEMO.get(key, {}), true)
		show_message(tr("Radarkontrolle in 10 km – Limit 120 km/h"), "warn", 30.0)
		show_message(tr("Tankstelle in 15 km"), "info", 30.0)


## Called once when the stage is built.
func setup_stage(stage_plan: StagePlan, config: Dictionary) -> void:
	plan = stage_plan
	cfg = config
	_reserve_l = float(ConfigLoader.lookup(cfg, "fuel.reserve_warning_l", 8.0))
	_speedo_max = float(ConfigLoader.lookup(cfg, "hud.speedo_max_kmh", 300.0))
	_escape_kmh = float(ConfigLoader.lookup(cfg, "police.escape_speed_kmh", 220.0))
	_max_messages = int(ConfigLoader.lookup(cfg, "hud.messages_max", 3))
	_show_fps = bool(ConfigLoader.lookup(cfg, "hud.show_fps", false))
	var gd: Node = get_node_or_null("/root/GameData")
	if gd != null:
		var countries: Dictionary = gd.get("countries")
		for code in countries:
			_country_colors[code] = countries[code].get("colors", [])
			_country_names[code] = str(countries[code].get("name", code))


## Called every frame with the HUD state dictionary (ARCHITECTURE.md §9 "HUD-Zustand").
func update_state(s: Dictionary) -> void:
	state = s
	if not _demo.is_empty():
		state = s.duplicate()
		state.merge(_demo, true)
	var cd := int(state.get("countdown", -1))
	if cd != _last_countdown:
		if cd > 0:
			_count_pop = 1.0
			_play("beep")
		elif cd <= 0 and _last_countdown > 0:
			_go_t = GO_TIME
		_last_countdown = cd
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("hud_hints"):
		am.call("hud_hints", state)
	queue_redraw()


## Temporary centred message. kind: "info" | "warn" | "alert".
func show_message(text: String, kind: String = "info", duration: float = 3.0) -> void:
	if text == tr("LOS!") or text == "LOS!":
		_go_t = GO_TIME
		return
	if text.begins_with(tr("ZIEL!")) or text.begins_with("ZIEL!"):
		_finish_text = text
		return
	for m in _messages:
		if str(m["text"]) == text:
			m["t"] = duration
			m["len"] = duration
			m["kind"] = kind
			return
	_messages.append({"text": text, "kind": kind, "t": duration, "len": maxf(duration, 0.01), "age": 0.0})
	while _messages.size() > _max_messages:
		_messages.pop_front()


## Full-screen colour flash (collision, radar).
func flash(color: Color, duration: float) -> void:
	_flash = color
	_flash_t = duration
	_flash_len = maxf(duration, 0.01)


func _process(delta: float) -> void:
	_t += delta
	for m in _messages:
		m["t"] = float(m["t"]) - delta
		m["age"] = float(m["age"]) + delta
	_messages = _messages.filter(func(m: Dictionary) -> bool: return float(m["t"]) > 0.0)
	_flash_t = maxf(0.0, _flash_t - delta)
	_count_pop = maxf(0.0, _count_pop - delta * 2.2)
	_go_t = maxf(0.0, _go_t - delta)
	if not _messages.is_empty() or _flash_t > 0.0 or _go_t > 0.0:
		queue_redraw()


func _play(sound: String) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("play", sound)


# --- state helpers ---------------------------------------------------------------------------

func _f(key: String, def: float = 0.0) -> float:
	var v: Variant = state.get(key, def)
	return float(v) if (v is float or v is int) else def


func _s(key: String, def: String = "") -> String:
	return str(state.get(key, def))


func _b(key: String) -> bool:
	return bool(state.get(key, false))


func _d(key: String) -> Dictionary:
	var v: Variant = state.get(key, {})
	return v if v is Dictionary else {}


func _blink(hz: float) -> bool:
	return fmod(_t * hz, 1.0) < 0.5


# --- drawing primitives ----------------------------------------------------------------------

func _text(pos: Vector2, text: String, font: Font, fs: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, shadow: bool = true) -> void:
	if shadow:
		draw_string(font, pos + Vector2(1, 2), text, align, width, fs, Color(0, 0, 0, 0.55 * col.a))
	draw_string(font, pos, text, align, width, fs, col)


func _text_w(text: String, font: Font, fs: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


func _hud_panel(r: Rect2, border: Color = Color(UiTheme.ACCENT_2, 0.32), bg: Color = UiTheme.PANEL_HUD, cut: float = 10.0) -> void:
	UiIcons.panel(self, r, bg, border, cut, 1.5)


func _bar(r: Rect2, frac: float, col: Color, bg: Color = Color(1, 1, 1, 0.1)) -> void:
	draw_rect(r, bg)
	if frac > 0.0:
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), col)


# --- main draw -------------------------------------------------------------------------------

func _draw() -> void:
	if state.is_empty():
		return
	var vs := size if size.x > 2.0 else get_viewport_rect().size
	var w := vs.x
	var h := vs.y
	_draw_clock_panel()
	_draw_time_panel(w)
	_draw_progress(w)
	var right_y := _draw_limit_and_radar(w)
	right_y = _draw_city_sign(w, right_y)
	_draw_police(w, right_y)
	_draw_fuel(h)
	_draw_speedo(w, h)
	var overlay_bottom := 0.0
	if not _d("tow").is_empty():
		overlay_bottom = _draw_tow(w, h)
	elif not _d("refuel").is_empty():
		overlay_bottom = _draw_refuel(w)
	if _b("finished"):
		overlay_bottom = maxf(overlay_bottom, _draw_finish(w))
	_draw_messages(w, maxf(overlay_bottom + 14.0, 172.0))
	_draw_countdown(w)
	if _show_fps:
		_text(Vector2(18, h - 132), "%d FPS" % Engine.get_frames_per_second(), _f_mono, 16, UiTheme.TEXT_DIM)
	var fl := _f("radar_flash01")
	if fl > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, clampf(fl, 0.0, 1.0) * 0.85))
	if _flash_t > 0.0:
		var a := _flash.a * _flash_t / _flash_len
		draw_rect(Rect2(0, 0, w, h), Color(_flash, a))
	if _b("collision"):
		_draw_vignette(w, h, Color(UiTheme.BAD, 0.28 if _blink(6.0) else 0.12))


# --- top-left: clock, weather, country -------------------------------------------------------

func _draw_clock_panel() -> void:
	var r := Rect2(16, 14, 316, 110)
	_hud_panel(r)
	var hour := _f("hour", 12.0)
	var cat := WorldClock.daytime_category(hour, cfg) if not cfg.is_empty() else "day"
	UiIcons.daytime(self, cat, Vector2(r.position.x + 30, r.position.y + 32), 36.0)
	_text(Vector2(r.position.x + 56, r.position.y + 47), _s("clock_text", "--:--"), _f_mono, 40, UiTheme.TEXT)
	var weather := _s("weather", "normal")
	var wx := r.position.x + 196.0
	UiIcons.weather(self, weather, Vector2(wx + 14, r.position.y + 31), 30.0)
	_text(Vector2(wx + 34, r.position.y + 39), UiFormat.weather_name(weather), _f_body, 20, UiTheme.TEXT_DIM)
	var code := _s("country", "")
	var colors: Array = _country_colors.get(code, [])
	UiIcons.flag(self, Rect2(r.position.x + 16, r.position.y + 60, 26, 17), colors)
	var cname := str(_country_names.get(code, code)).to_upper()
	if _b("in_tunnel"):
		cname += "  ·  " + tr("TUNNEL")
	_text(Vector2(r.position.x + 52, r.position.y + 76), cname, _f_bold, 21, UiTheme.TEXT)
	var stage_name := _s("stage_name", plan.display_name if plan != null else "")
	_text(Vector2(r.position.x + 16, r.position.y + 100), stage_name, _f_body, 17, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28)


# --- top-centre: stage time, record, pace delta ----------------------------------------------

func _draw_time_panel(w: float) -> void:
	var r := Rect2(w * 0.5 - 170, 12, 340, 84)
	_hud_panel(r, Color(UiTheme.ACCENT, 0.4))
	var t := _f("stage_time_s")
	_text(Vector2(r.position.x, r.position.y + 50), UiFormat.time(t), _f_mono, 46, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var rec := _f("record_time_s", -1.0)
	var y2 := r.position.y + 75
	if rec > 0.0:
		var who := _s("record_name", "")
		var label := tr("REKORD %s") % UiFormat.time(rec)
		if who != "":
			label += " · " + who
		_text(Vector2(r.position.x + 14, y2), label, _f_body, 17, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 110)
		var pd := UiFormat.pace_delta(t, rec, _f("stage_km"), _f("stage_length_km", 1.0))
		if not is_nan(pd) and _f("stage_km") > 0.5:
			_text(Vector2(r.position.x, y2 + 1), UiFormat.delta_short(pd), _f_mono, 21, UiTheme.delta_color(pd), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 14)
	else:
		_text(Vector2(r.position.x, y2), tr("Noch kein Rekord – setz die Bestzeit!"), _f_body, 17, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var pen := _f("penalty_s")
	if pen > 0.0:
		var txt := tr("+%s STRAFE") % UiFormat.time(pen)
		var tw := _text_w(txt, _f_bold, 17) + 20.0
		var pr := Rect2(w * 0.5 - tw * 0.5, r.end.y + 34, tw, 22)
		UiIcons.panel(self, pr, Color(0.35, 0.18, 0.0, 0.8), UiTheme.WARN, 6.0)
		_text(Vector2(pr.position.x, pr.position.y + 17), txt, _f_bold, 17, UiTheme.WARN, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)


# --- progress bar ----------------------------------------------------------------------------

func _draw_progress(w: float) -> void:
	var length := maxf(_f("stage_length_km", plan.length_km if plan != null else 1.0), 0.001)
	var km := clampf(_f("stage_km"), 0.0, length)
	var x0 := w * 0.5 - 286.0
	var bw := 572.0
	var y := 112.0
	UiIcons.panel(self, Rect2(x0 - 14, y - 15, bw + 28, 30), UiTheme.PANEL_HUD, Color(0, 0, 0, 0), 8.0)
	var kx := func(k: float) -> float: return x0 + bw * clampf(k / length, 0.0, 1.0)
	draw_rect(Rect2(x0, y - 2, bw, 4), Color(1, 1, 1, 0.16))
	if plan != null:
		var clx: float = kx.call(plan.city_limits_km)
		draw_rect(Rect2(clx, y - 2, x0 + bw - clx, 4), Color(UiTheme.ORANGE, 0.75))
		for tun in plan.tunnels:
			var a: float = kx.call(float(tun["start_km"]))
			var b: float = kx.call(float(tun["end_km"]))
			draw_rect(Rect2(a, y - 5, maxf(b - a, 3.0), 10), Color(0.62, 0.64, 0.7, 0.85))
	var px: float = kx.call(km)
	draw_line(Vector2(x0, y), Vector2(px, y), UiTheme.ACCENT_2, 4.0)
	if plan != null:
		for b in plan.borders:
			var bx: float = kx.call(float(b["km"]))
			UiIcons.flag(self, Rect2(bx - 3, y - 12, 6, 24), _country_colors.get(str(b["to"]), []), true)
		for st: float in plan.fuel_stations_km:
			var sx: float = kx.call(st)
			var col := UiTheme.GOOD if st >= km else Color(UiTheme.GOOD, 0.35)
			draw_line(Vector2(sx, y - 9), Vector2(sx, y + 3), col, 2.0)
			draw_circle(Vector2(sx, y - 9), 3.5, col)
		for rd in plan.radars:
			var rx: float = kx.call(float(rd["km"]))
			var col2 := UiTheme.BAD if float(rd["end_km"]) >= km else Color(UiTheme.BAD, 0.35)
			draw_colored_polygon(PackedVector2Array([Vector2(rx - 5, y + 10), Vector2(rx + 5, y + 10), Vector2(rx, y + 2)]), col2)
	UiIcons.checkered(self, Rect2(x0 + bw - 2, y - 7, 10, 14), 2, 3)
	# player marker
	draw_colored_polygon(PackedVector2Array([Vector2(px - 7, y - 13), Vector2(px + 7, y - 13), Vector2(px, y - 3)]), Color.WHITE)
	draw_circle(Vector2(px, y), 4.5, UiTheme.ACCENT_2)
	var left := tr("km %s / %s") % [UiFormat.decimal(km, 1), UiFormat.decimal(length, 0)]
	var right := tr("noch %s") % UiFormat.km(maxf(0.0, length - km), 0)
	_text(Vector2(x0, y + 30), left, _f_mono, 17, UiTheme.TEXT)
	_text(Vector2(x0, y + 30), right, _f_mono, 17, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT, bw)


# --- top-right: limit sign + radar warning ---------------------------------------------------

func _draw_limit_and_radar(w: float) -> float:
	var r := 34.0
	var c := Vector2(w - 16 - r - 4, 16 + r + 2)
	var limit := int(_f("speed_limit"))
	UiIcons.speed_sign(self, c, r, limit, _f_bold)
	if limit <= 0:
		_text(Vector2(c.x - 40, c.y + r + 18), tr("frei"), _f_bold, 17, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 80)
	var rw := _d("radar_warning")
	if not rw.is_empty():
		var in_zone := bool(rw.get("in_zone", false))
		var pr := Rect2(c.x - r - 14 - 236, 16, 236, 72)
		var col := UiTheme.BAD if in_zone else UiTheme.WARN
		var bg := Color(0.3, 0.02, 0.05, 0.78) if in_zone else Color(0.28, 0.16, 0.0, 0.72)
		if in_zone and _blink(3.0):
			bg = Color(0.5, 0.04, 0.08, 0.85)
		UiIcons.panel(self, pr, bg, col, 10.0, 2.0)
		UiIcons.radar(self, pr.position + Vector2(34, 36), 40.0, col)
		var title := tr("RADARFELD") if in_zone else tr("RADAR")
		_text(pr.position + Vector2(66, 30), title, _f_head, 24, col)
		var sub := tr("Limit %d km/h") % int(rw.get("limit", 0))
		if not in_zone:
			sub = tr("in %s · Limit %d") % [UiFormat.km(float(rw.get("distance_km", 0.0)), 1), int(rw.get("limit", 0))]
		_text(pr.position + Vector2(66, 56), sub, _f_body, 19, UiTheme.TEXT)
	return 16 + r * 2 + (26.0 if limit <= 0 else 10.0)


func _draw_city_sign(w: float, y: float) -> float:
	if not _b("city_limits"):
		return y
	var town := (plan.to_name if plan != null else "").to_upper()
	var tw := maxf(_text_w(town, _f_bold, 22), _text_w(tr("CITY LIMITS"), _f_bold, 13)) + 28.0
	var r := Rect2(w - 16 - tw, y + 6, tw, 50)
	draw_rect(r, Color("f2c200"))
	draw_rect(r.grow(-3), Color(0.08, 0.08, 0.08), false, 2.0)
	_text(Vector2(r.position.x, r.position.y + 19), tr("CITY LIMITS"), _f_bold, 13, Color(0.1, 0.1, 0.1), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, false)
	_text(Vector2(r.position.x, r.position.y + 41), town, _f_bold, 22, Color(0.06, 0.06, 0.06), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, false)
	return r.end.y + 4


# --- police chase ----------------------------------------------------------------------------

func _draw_police(w: float, y: float) -> void:
	var ps := _s("police_state", "none")
	if ps == "none" or ps == "":
		return
	var r := Rect2(w - 16 - 316, y + 8, 316, 96)
	var phase := fmod(_t * 2.4, 1.0)
	var border := UiTheme.POLICE if phase < 0.5 else UiTheme.BAD
	var bg := Color(0.02, 0.06, 0.25, 0.82) if phase < 0.5 else Color(0.22, 0.02, 0.06, 0.82)
	UiIcons.panel(self, r, bg, border, 12.0, 2.5)
	UiIcons.beacon(self, r.position + Vector2(26, 30), 30.0, phase)
	UiIcons.beacon(self, Vector2(r.end.x - 26, r.position.y + 30), 30.0, phase + 0.5)
	var title := tr("POLIZEI!")
	var sub := ""
	match ps:
		"chase":
			sub = tr("Flucht ab %d km/h halten!") % int(_escape_kmh)
		"stopping":
			title = tr("ANHALTEN!")
			sub = tr("Die Polizei winkt dich raus")
		"stopped":
			title = tr("KONTROLLE")
			sub = tr("Führerschein, bitte!")
	_text(Vector2(r.position.x, r.position.y + 34), title, _f_title, 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	_text(Vector2(r.position.x, r.position.y + 56), sub, _f_body, 18, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if ps == "chase":
		var e := clampf(_f("escape01"), 0.0, 1.0)
		var br := Rect2(r.position.x + 16, r.position.y + 68, r.size.x - 120, 14)
		_bar(br, e, UiTheme.GOOD if e > 0.66 else UiTheme.ACCENT_2)
		draw_rect(br, Color(1, 1, 1, 0.35), false, 1.0)
		var gap := _f("police_gap_m")
		_text(Vector2(br.end.x + 8, br.end.y), tr("%d m hinter dir") % roundi(gap), _f_body, 16, UiTheme.TEXT_DIM)


# --- bottom-left: fuel -----------------------------------------------------------------------

func _draw_fuel(h: float) -> void:
	var r := Rect2(16, h - 16 - 118, 344, 118)
	var fuel := _f("fuel_l")
	var tank := maxf(_f("tank_l", 50.0), 1.0)
	var frac := clampf(fuel / tank, 0.0, 1.0)
	var reserve := fuel <= _reserve_l
	var border := Color(UiTheme.BAD, 0.9) if (reserve and _blink(2.0)) else Color(UiTheme.ACCENT_2, 0.32)
	_hud_panel(r, border)
	var x := r.position.x + 16
	UiIcons.pump(self, Vector2(x + 12, r.position.y + 24), 24.0, UiTheme.BAD if reserve else UiTheme.TEXT)
	_text(Vector2(x + 34, r.position.y + 32), tr("TANK"), _f_bold, 20, UiTheme.TEXT_DIM)
	if reserve:
		if _blink(2.0):
			_text(Vector2(x + 88, r.position.y + 32), tr("RESERVE"), _f_bold, 20, UiTheme.BAD)
	_text(Vector2(r.position.x, r.position.y + 33), "%d / %d L" % [ceili(fuel - 0.01), roundi(tank)], _f_mono, 26, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 16)
	# segmented gauge
	var segs := 24
	var gx := x
	var gw := r.size.x - 32
	var gy := r.position.y + 44
	var sw := gw / segs
	var lit := int(ceilf(frac * segs - 0.001))
	var fill_col := UiTheme.GOOD if frac > 0.3 else UiTheme.WARN
	if reserve:
		fill_col = UiTheme.BAD
	for i in segs:
		var col := Color(1, 1, 1, 0.1)
		if i < lit:
			col = fill_col.lerp(Color.WHITE, 0.18 * float(i) / segs)
		draw_rect(Rect2(gx + i * sw + 1, gy, sw - 2, 16), col)
	var rx := gx + gw * clampf(_reserve_l / tank, 0.0, 1.0)
	draw_line(Vector2(rx, gy - 3), Vector2(rx, gy + 19), Color(UiTheme.BAD, 0.9), 2.0)
	# range + next station
	var rng := _f("range_km")
	var nxt := _f("next_station_km", -1.0)
	var remaining := _f("remaining_km", 0.0)
	var short := (nxt >= 0.0 and rng < nxt) or (nxt < 0.0 and rng < remaining)
	_text(Vector2(x, r.position.y + 84), tr("Reichweite"), _f_body, 19, UiTheme.TEXT_DIM)
	_text(Vector2(r.position.x, r.position.y + 84), UiFormat.km(rng, 0), _f_mono, 21, UiTheme.BAD if short else UiTheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 16)
	_text(Vector2(x, r.position.y + 108), tr("Nächste Tankstelle"), _f_body, 19, UiTheme.TEXT_DIM)
	var nt := UiFormat.km(nxt, 1) if nxt >= 0.0 else tr("keine mehr")
	var ncol := UiTheme.GOOD if (nxt >= 0.0 and nxt < 5.0) else UiTheme.TEXT
	_text(Vector2(r.position.x, r.position.y + 108), nt, _f_mono, 21, ncol, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 16)


# --- bottom-right: speedometer ---------------------------------------------------------------

func _speed_angle(v: float) -> float:
	return deg_to_rad(lerpf(SPEEDO_A0, SPEEDO_A1, clampf(v / _speedo_max, 0.0, 1.0)))


func _draw_speedo(w: float, h: float) -> void:
	var c := Vector2(w - 140, h - 124)
	var rr := 104.0
	draw_circle(c, rr + 16, Color(0.015, 0.02, 0.07, 0.7))
	draw_arc(c, rr + 16, 0.0, TAU, 72, Color(UiTheme.ACCENT_2, 0.3), 1.5, true)
	draw_arc(c, rr, deg_to_rad(SPEEDO_A0), deg_to_rad(SPEEDO_A1), 72, Color(1, 1, 1, 0.1), 10.0, true)
	var speed := maxf(_f("speed_kmh"), 0.0)
	var limit := _f("speed_limit")
	if limit > 0.0:
		draw_arc(c, rr + 9, _speed_angle(limit), _speed_angle(_speedo_max), 32, Color(UiTheme.BAD, 0.45), 3.0, true)
	# filled arc with gradient
	if speed > 0.5:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var n := maxi(4, int(48.0 * speed / _speedo_max))
		for i in n + 1:
			var v := speed * i / n
			var a := _speed_angle(v)
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
			var f := v / _speedo_max
			var col := UiTheme.ACCENT_2.lerp(UiTheme.ACCENT, clampf(f * 1.4 - 0.2, 0.0, 1.0))
			if f > 0.8:
				col = col.lerp(UiTheme.GOLD, (f - 0.8) * 5.0)
			cols.append(col)
		draw_polyline_colors(pts, cols, 10.0, true)
	# ticks + numbers
	var step := 10
	var v_tick := 0
	while v_tick <= int(_speedo_max):
		var a := _speed_angle(v_tick)
		var d := Vector2(cos(a), sin(a))
		var major := v_tick % 50 == 0
		var col := Color(1, 1, 1, 0.85 if major else 0.4)
		draw_line(c + d * (rr - (19.0 if major else 13.0)), c + d * (rr - 7.0), col, 2.0 if major else 1.0, true)
		if major:
			var txt := str(v_tick)
			var p := c + d * (rr - 34.0)
			_text(Vector2(p.x - 20, p.y + 6), txt, _f_bold, 15, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 40, false)
		v_tick += step
	# vmax mark
	var vmax := _f("vmax_kmh")
	if vmax > 0.0:
		var a2 := _speed_angle(vmax)
		var d2 := Vector2(cos(a2), sin(a2))
		var n2 := Vector2(-d2.y, d2.x)
		var tip := c + d2 * (rr + 7.0)
		draw_colored_polygon(PackedVector2Array([tip, tip + d2 * 11.0 + n2 * 6.0, tip + d2 * 11.0 - n2 * 6.0]), UiTheme.ORANGE)
	# needle
	var an := _speed_angle(speed)
	var dn := Vector2(cos(an), sin(an))
	draw_line(c, c + dn * (rr - 6.0), Color(UiTheme.GOLD, 0.25), 9.0, true)
	draw_line(c - dn * 12.0, c + dn * (rr - 6.0), UiTheme.GOLD, 3.5, true)
	draw_circle(c, 9.0, Color(0.1, 0.1, 0.16))
	draw_arc(c, 9.0, 0.0, TAU, 24, UiTheme.GOLD, 2.0, true)
	# digital
	var sp := str(roundi(speed))
	_text(Vector2(c.x - 70, c.y + 62), sp, _f_mono, 50, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 140)
	_text(Vector2(c.x - 70, c.y + 84), "km/h", _f_bold, 17, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, 140)
	if _f("understeer") > 0.3:
		var txt := tr("UNTERSTEUERN")
		var tw := _text_w(txt, _f_bold, 17) + 18.0
		var ur := Rect2(c.x - tw * 0.5, c.y - rr - 52, tw, 24)
		UiIcons.panel(self, ur, Color(0.3, 0.17, 0.0, 0.8), UiTheme.WARN, 6.0)
		_text(Vector2(ur.position.x, ur.position.y + 18), txt, _f_bold, 17, UiTheme.WARN, HORIZONTAL_ALIGNMENT_CENTER, ur.size.x)


# --- centre overlays -------------------------------------------------------------------------

func _draw_messages(w: float, top: float) -> void:
	var y := top
	for m in _messages:
		var kind := str(m["kind"])
		var col := UiTheme.TEXT
		var border := Color(UiTheme.ACCENT_2, 0.7)
		var bg := Color(0.02, 0.04, 0.12, 0.72)
		if kind == "warn":
			col = UiTheme.GOLD
			border = UiTheme.WARN
			bg = Color(0.2, 0.12, 0.0, 0.74)
		elif kind == "alert":
			col = Color.WHITE
			border = UiTheme.BAD
			bg = Color(0.32, 0.03, 0.07, 0.8)
		var t_left := float(m["t"])
		var age := float(m["age"])
		var alpha := clampf(minf(age / 0.15, t_left / 0.35), 0.0, 1.0)
		var slide := (1.0 - clampf(age / 0.18, 0.0, 1.0)) * 18.0
		var text := str(m["text"])
		var fs := 28
		var tw := _text_w(text, _f_head, fs)
		if tw > w - 200.0:
			fs = 22
			tw = _text_w(text, _f_head, fs)
		var r := Rect2(w * 0.5 - tw * 0.5 - 26, y - slide, tw + 52, 44)
		UiIcons.panel(self, r, Color(bg, bg.a * alpha), Color(border, alpha), 10.0, 2.0)
		_text(Vector2(r.position.x, r.position.y + 31), text, _f_head, fs, Color(col, alpha), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		y += 52.0


func _draw_countdown(w: float) -> void:
	var cd := int(_f("countdown", -1.0))
	var c := Vector2(w * 0.5, 250)
	if cd > 0:
		var cols := {3: UiTheme.BAD, 2: UiTheme.WARN, 1: UiTheme.GOLD}
		var col: Color = cols.get(cd, Color.WHITE)
		var sc := 1.0 + 0.45 * _count_pop * _count_pop
		var fs := int(150 * sc)
		var txt := str(cd)
		var tw := _text_w(txt, _f_logo, fs)
		var asc := _f_logo.get_ascent(fs)
		draw_string_outline(_f_logo, Vector2(c.x - tw * 0.5, c.y + asc * 0.4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0, 0, 0, 0.6))
		draw_string(_f_logo, Vector2(c.x - tw * 0.5, c.y + asc * 0.4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		_draw_start_lights(c + Vector2(0, 92), 4 - cd)
	elif _go_t > 0.0:
		var k := _go_t / GO_TIME
		var fs2 := int(130 * (1.0 + 0.25 * (1.0 - k)))
		var txt2 := tr("LOS!")
		var tw2 := _text_w(txt2, _f_logo, fs2)
		var a := clampf(k * 2.5, 0.0, 1.0)
		var asc2 := _f_logo.get_ascent(fs2)
		draw_string_outline(_f_logo, Vector2(c.x - tw2 * 0.5, c.y + asc2 * 0.4), txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, 10, Color(0, 0, 0, 0.6 * a))
		draw_string(_f_logo, Vector2(c.x - tw2 * 0.5, c.y + asc2 * 0.4), txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(UiTheme.GOOD, a))
		_draw_start_lights(c + Vector2(0, 92), 4, a)


## Start light gantry: `lit` red lamps (1..3), 4 = all green.
func _draw_start_lights(c: Vector2, lit: int, alpha: float = 1.0) -> void:
	var r := Rect2(c.x - 78, c.y - 18, 156, 36)
	UiIcons.panel(self, r, Color(0.02, 0.02, 0.05, 0.85 * alpha), Color(1, 1, 1, 0.25 * alpha), 6.0)
	for i in 3:
		var p := Vector2(r.position.x + 32 + i * 46, c.y)
		var col := Color(0.2, 0.2, 0.25, alpha)
		if lit >= 4:
			col = Color(UiTheme.GOOD, alpha)
		elif i < lit:
			col = Color(UiTheme.BAD, alpha)
		if col != Color(0.2, 0.2, 0.25, alpha):
			draw_circle(p, 15.0, Color(col, 0.25 * alpha))
		draw_circle(p, 10.0, col)


func _draw_refuel(w: float) -> float:
	var rf := _d("refuel")
	var r := Rect2(w * 0.5 - 230, 150, 460, 136)
	UiIcons.panel(self, r, Color(0.02, 0.05, 0.14, 0.88), UiTheme.GOOD, 14.0, 2.5)
	UiIcons.pump(self, r.position + Vector2(44, 46), 46.0, UiTheme.GOOD)
	_text(Vector2(r.position.x + 70, r.position.y + 48), tr("Volltanken?"), _f_title, 38, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 90)
	var hint := tr("Gas = Weiterfahren")
	_text(Vector2(r.position.x + 70, r.position.y + 76), hint, _f_head, 21, UiTheme.GOLD if _blink(1.2) else UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 90)
	var br := Rect2(r.position.x + 24, r.position.y + 92, r.size.x - 48, 16)
	var p := clampf(float(rf.get("progress01", 0.0)), 0.0, 1.0)
	_bar(br, p, UiTheme.GOOD)
	draw_rect(br, Color(1, 1, 1, 0.4), false, 1.0)
	_text(Vector2(br.position.x, br.end.y + 22), tr("+%s getankt") % UiFormat.liters(float(rf.get("liters", 0.0))), _f_body, 19, UiTheme.TEXT)
	_text(Vector2(br.position.x, br.end.y + 22), tr("noch %s s") % UiFormat.decimal(float(rf.get("time_left_s", 0.0)), 1), _f_mono, 19, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT, br.size.x)
	return r.end.y


func _draw_tow(w: float, h: float) -> float:
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.45))
	var r := Rect2(w * 0.5 - 260, 168, 520, 132)
	UiIcons.panel(self, r, Color(0.06, 0.05, 0.02, 0.92), UiTheme.WARN, 14.0, 2.5)
	# hazard stripes on top
	var stripe := Rect2(r.position.x + 14, r.position.y + 10, r.size.x - 28, 14)
	draw_rect(stripe, Color(0.1, 0.1, 0.1))
	var x := stripe.position.x - fmod(_t * 40.0, 28.0)
	while x < stripe.end.x:
		var a := maxf(x, stripe.position.x)
		var b := minf(x + 14.0, stripe.end.x)
		if b > a:
			draw_rect(Rect2(a, stripe.position.y, b - a, stripe.size.y), UiTheme.WARN)
		x += 28.0
	var beacon_on := _blink(2.5)
	draw_circle(r.position + Vector2(40, 72), 14.0, Color(1.0, 0.6, 0.0, 0.95 if beacon_on else 0.3))
	draw_circle(Vector2(r.end.x - 40, r.position.y + 72), 14.0, Color(1.0, 0.6, 0.0, 0.3 if beacon_on else 0.95))
	_text(Vector2(r.position.x, r.position.y + 72), tr("ABSCHLEPPDIENST"), _f_title, 36, UiTheme.WARN, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	_text(Vector2(r.position.x, r.position.y + 104), tr("Tank leer – der Wagen wird zur nächsten Tankstelle gebracht"), _f_body, 19, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var tow_pen := float(ConfigLoader.lookup(cfg, "fuel.tow_penalty_s", 120.0))
	_text(Vector2(r.position.x, r.position.y + 124), tr("Zeitstrafe: +%s") % UiFormat.time(tow_pen), _f_bold, 18, UiTheme.BAD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	return r.end.y


func _draw_finish(w: float) -> float:
	var r := Rect2(0, 150, w, 92)
	draw_rect(r, Color(0.02, 0.02, 0.06, 0.72))
	UiIcons.checkered(self, Rect2(0, r.position.y, w, 12), int(w / 12.0), 1)
	UiIcons.checkered(self, Rect2(0, r.end.y - 12, w, 12), int(w / 12.0), 1, Color(0.08, 0.08, 0.1), Color.WHITE)
	_text(Vector2(0, r.position.y + 64), tr("ZIEL"), _f_logo, 48, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, w * 0.5 - 20)
	_text(Vector2(w * 0.5 + 20, r.position.y + 62), UiFormat.time(_f("stage_time_s")), _f_mono, 46, Color.WHITE)
	return r.end.y


func _draw_vignette(w: float, h: float, col: Color) -> void:
	var t := 26.0
	var clear := Color(col, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, t), Vector2(0, t)]), PackedColorArray([col, col, clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, h - t), Vector2(w, h - t), Vector2(w, h), Vector2(0, h)]), PackedColorArray([clear, clear, col, col]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(t, 0), Vector2(t, h), Vector2(0, h)]), PackedColorArray([col, clear, clear, col]))
	draw_polygon(PackedVector2Array([Vector2(w - t, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - t, h)]), PackedColorArray([clear, col, col, clear]))
