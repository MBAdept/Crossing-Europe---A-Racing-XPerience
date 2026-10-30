class_name Hud
extends Control
## In-race HUD (speedometer, clock, stage time, fuel, range, next station, radar warning, police,
## messages, refuel prompt, countdown). Owner: UI module. Public API = contract (ARCHITECTURE.md §HUD).
## STUB: plain text display – the UI module replaces it.

var state: Dictionary = {}
var plan: StagePlan
var _messages: Array[Dictionary] = []
var _flash := Color(0, 0, 0, 0)
var _flash_t := 0.0
var _flash_len := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Called once when the stage is built.
func setup_stage(stage_plan: StagePlan, _config: Dictionary) -> void:
	plan = stage_plan


## Called every frame with the HUD state dictionary (ARCHITECTURE.md §HUD-Zustand).
func update_state(s: Dictionary) -> void:
	state = s
	queue_redraw()


## Temporary centred message. kind: "info" | "warn" | "alert".
func show_message(text: String, kind: String = "info", duration: float = 3.0) -> void:
	_messages.append({"text": text, "kind": kind, "t": duration})
	if _messages.size() > 3:
		_messages.pop_front()


## Full-screen colour flash (collision, radar).
func flash(color: Color, duration: float) -> void:
	_flash = color
	_flash_t = duration
	_flash_len = duration


func _process(delta: float) -> void:
	for m in _messages:
		m["t"] = float(m["t"]) - delta
	_messages = _messages.filter(func(m: Dictionary) -> bool: return float(m["t"]) > 0.0)
	_flash_t = maxf(0.0, _flash_t - delta)


func _draw() -> void:
	if state.is_empty():
		return
	var f := ThemeDB.fallback_font
	var w := get_viewport_rect().size.x
	var h := get_viewport_rect().size.y
	draw_string(f, Vector2(w - 260, h - 30), "%3d km/h" % int(state.get("speed_kmh", 0.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Color.WHITE)
	draw_string(f, Vector2(w * 0.5 - 70, 44), Units.format_race_time(float(state.get("stage_time_s", 0.0))), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)
	draw_string(f, Vector2(24, 40), "%s   %s" % [state.get("clock_text", ""), state.get("stage_name", "")], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_string(f, Vector2(24, 70), "km %.1f / %.0f" % [float(state.get("stage_km", 0.0)), float(state.get("stage_length_km", 0.0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	draw_string(f, Vector2(24, h - 60), "Tank %.0f / %.0f L   Reichweite %.0f km   Tankstelle %s" % [float(state.get("fuel_l", 0.0)), float(state.get("tank_l", 0.0)), float(state.get("range_km", 0.0)), ("%.0f km" % float(state.get("next_station_km", -1.0))) if float(state.get("next_station_km", -1.0)) >= 0.0 else "–"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	var y := h * 0.32
	for m in _messages:
		var col := Color.WHITE if m["kind"] == "info" else (Color(1, 0.85, 0.2) if m["kind"] == "warn" else Color(1, 0.3, 0.25))
		var tw := f.get_string_size(str(m["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_string(f, Vector2((w - tw) * 0.5, y), str(m["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, col)
		y += 40
	if int(state.get("countdown", -1)) > 0:
		draw_string(f, Vector2(w * 0.5 - 20, h * 0.45), str(state["countdown"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 96, Color.WHITE)
	if not state.get("refuel", {}).is_empty():
		draw_string(f, Vector2(w * 0.5 - 120, h * 0.6), "Volltanken?", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color.WHITE)
		draw_string(f, Vector2(w * 0.5 - 120, h * 0.6 + 34), "Gas = Weiterfahren", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	var fl := float(state.get("radar_flash01", 0.0))
	if fl > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, fl * 0.8))
	if _flash_t > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(_flash, _flash.a * _flash_t / maxf(_flash_len, 0.01)))
