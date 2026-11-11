class_name BenchmarkScreen
extends UiScreen
## "LEISTUNGSTEST" (v0.8.0, options page GRAFIK): start page and result page of the built-in benchmark of the mode
## "Modern". The test itself is ModernBenchmark (scripts/race3d/benchmark.gd), started through
## GameFlow.start_benchmark() – it drives the race scene, so this screen is gone while it runs and comes back with
## the result in `params.result`.
##   start page   what the test does (the scenes of graphics.benchmark.scenes, seconds each), with which settings,
##                where the result file goes; "Leistungstest starten" / "Zurück"
##   result page  per scene: average and 1 %-low pictures per second, frame time (95 % / 99 %), GDScript time of
##                the renderer, draw calls, triangles; the machine (adapter, preset, resolution); the verdict and
##                the suggested preset – "Vorschlag übernehmen" applies it (or switches to Arcade when Modern is
##                too slow or does not start), "Noch einmal", "Zurück"; the path of leistungstest.json to send in.
## Nothing of this screen names a class of scripts/race3d: an Arcade start that opens the options loads no 3D code.
## Debug (sample screens): --screen=benchmark [--bench-sample=ok|slow|arcade|fallback|stub|abort] for screenshots.

const RESULT_FILE := "user://leistungstest.json"

var result: Dictionary = {}
var start_button: Button
var apply_button: Button
var back_button: Button
var _verdict: Label


func build() -> void:
	result = params.get("result", {})
	if GameFlow.sample_mode and CliArgs.has("bench-sample"):
		result = sample_result(CliArgs.get_string("bench-sample", "ok"))
	if result.is_empty() or (bool(result.get("aborted", false)) and (result.get("scenes", []) as Array).is_empty()):
		_build_start(bool(result.get("aborted", false)))
	else:
		_build_result()


# --- start page -------------------------------------------------------------------------------------------

func _build_start(was_aborted: bool) -> void:
	add_header(tr("Leistungstest"), tr("Wie schnell läuft der Modus „Modern“ auf diesem Rechner?"))
	hints = [[["lr"], tr("Wählen")], [["Enter", "pad:A"], tr("Bestätigen")], [["Esc", "pad:B"], tr("Zurück")]]
	var c := cfg()
	var b: Variant = ConfigLoader.lookup(c, "graphics.benchmark", {})
	var bc: Dictionary = b if b is Dictionary else {}
	var seconds := float(bc.get("seconds", 20.0))
	var names: Array[String] = []
	var raw: Variant = bc.get("scenes", [])
	if raw is Array:
		for s: Variant in raw:
			if s is Dictionary and str((s as Dictionary).get("stage", "")) != "":
				names.append(str((s as Dictionary).get("name", (s as Dictionary).get("id", ""))))
	var box := add_panel(Rect2(64, 104, 1152, 470), UiTheme.ACCENT_2, 12)
	if was_aborted:
		box.add_child(UiKit.label(tr("Der Leistungstest wurde abgebrochen – es gibt kein Ergebnis."), UiTheme.F.HEADING, 22, UiTheme.WARN))
	var what := tr("Der Test fährt %d kurze Szenen im Modus „Modern“ – je %s Sekunden mit dem Autopiloten – und misst, wie viele Bilder pro Sekunde dieser Rechner dabei zeichnet. Er dauert etwa %s.") % [
		names.size(), UiFormat.number(seconds, 0), duration_text(names.size(), seconds)]
	box.add_child(_text(what, 22, UiTheme.TEXT))
	for i in names.size():
		box.add_child(UiKit.label("%d   %s" % [i + 1, names[i]], UiTheme.F.HEADING, 22, UiTheme.GOLD))
	box.add_child(_text(tr("Gemessen wird mit den Einstellungen der Seite „Grafik“: %s") % quality_line(Settings.quality()), 20, UiTheme.TEXT_DIM))
	box.add_child(_text(tr("Für die Messung ist die Bildsynchronisation (V-Sync) aus. Bitte nichts drücken und das Fenster im Vordergrund lassen; B oder Esc bricht ab. Am Ende schlägt der Test eine Voreinstellung vor."), 20, UiTheme.TEXT_DIM))
	box.add_child(_text(tr("Das Ergebnis wird gespeichert als: %s") % result_path(), 18, UiTheme.TEXT_MUTED))
	start_button = UiKit.button(tr("Leistungstest starten"), 26, HORIZONTAL_ALIGNMENT_CENTER)
	start_button.pressed.connect(_start)
	UiKit.place(self, start_button, Rect2(64, 596, 564, 54))
	back_button = UiKit.button(tr("Zurück"), 26, HORIZONTAL_ALIGNMENT_CENTER)
	back_button.pressed.connect(on_cancel)
	UiKit.place(self, back_button, Rect2(652, 596, 564, 54))
	_link_row([start_button, back_button])
	default_focus = start_button


func _start() -> void:
	if GameFlow.sample_mode:
		return
	Settings.save_if_changed()   # the test reads the quality settings of the options
	GameFlow.start_benchmark()


# --- result page ------------------------------------------------------------------------------------------

func _build_result() -> void:
	var scenes: Array = result.get("scenes", [])
	add_header(tr("Leistungstest"), tr("Ergebnis"), UiFormat.date_de(str(result.get("date", "")).left(10)))
	hints = [[["lr"], tr("Wählen")], [["Enter", "pad:A"], tr("Bestätigen")], [["Esc", "pad:B"], tr("Zurück")]]
	var box := add_panel(Rect2(64, 104, 1152, 470), UiTheme.ACCENT_2, 8)
	var table := _Table.new()
	table.scenes = scenes
	table.custom_minimum_size = Vector2(1116, 38.0 + 36.0 * maxi(scenes.size(), 1))
	box.add_child(table)
	box.add_child(HSeparator.new())
	box.add_child(_text(machine_line(result), 19, UiTheme.TEXT_DIM))
	var v := verdict_text(result)
	_verdict = _text(str(v[0]), 24, v[1], UiTheme.F.HEADING)
	box.add_child(_verdict)
	if str(v[2]) != "":
		box.add_child(_text(str(v[2]), 20, UiTheme.TEXT))
	if bool(result.get("written", true)) and not bool(result.get("aborted", false)):
		box.add_child(_text(tr("Gespeichert als: %s") % result_path(), 18, UiTheme.TEXT_MUTED))
	var buttons: Array = []
	var offer := offer_of(result, Settings.stored_quality(), OptionsScreen.shown_mode())
	if not offer.is_empty():
		apply_button = UiKit.button(str(offer["label"]), 24, HORIZONTAL_ALIGNMENT_CENTER)
		apply_button.pressed.connect(_apply.bind(offer))
		buttons.append(apply_button)
	var again := UiKit.button(tr("Noch einmal"), 24, HORIZONTAL_ALIGNMENT_CENTER)
	again.pressed.connect(_start)
	buttons.append(again)
	back_button = UiKit.button(tr("Zurück"), 24, HORIZONTAL_ALIGNMENT_CENTER)
	back_button.pressed.connect(on_cancel)
	buttons.append(back_button)
	var w := (1152.0 - 24.0 * (buttons.size() - 1)) / buttons.size()
	for i in buttons.size():
		UiKit.place(self, buttons[i], Rect2(64.0 + i * (w + 24.0), 596, w, 54))
	_link_row(buttons)
	default_focus = back_button


## What the button "… übernehmen" would change, or {} when there is nothing to offer: {"label", "preset"} or
## {"label", "mode": "arcade"}. `stored` = the player's quality (Settings.stored_quality()), `mode` = his mode.
static func offer_of(res: Dictionary, stored: Dictionary, mode: String) -> Dictionary:
	if bool(res.get("aborted", false)) or bool(res.get("renderer_stub", false)):
		return {}
	if str(res.get("suggested_mode", Gfx.MODERN)) == Gfx.ARCADE:
		if mode == Gfx.ARCADE:
			return {}
		return {"label": UiFormat.t("Zu Arcade wechseln"), "mode": Gfx.ARCADE}
	var preset := str(res.get("suggested_preset", ""))
	if (res.get("scenes", []) as Array).is_empty() or not Gfx.DEFAULT_PRESETS.has(preset) or preset == str(stored.get("preset", "")):
		return {}
	return {"label": UiFormat.t("„%s“ übernehmen") % OptionsScreen.preset_name(preset), "preset": preset}


func _apply(offer: Dictionary) -> void:
	if offer.has("mode"):
		Settings.graphics_mode = str(offer["mode"])
		_verdict.text = tr("Übernommen: Grafik „Arcade“.")
	else:
		Settings.choose_preset(str(offer["preset"]))
		_verdict.text = tr("Übernommen: Voreinstellung „%s“.") % OptionsScreen.preset_name(str(offer["preset"]))
	_verdict.add_theme_color_override("font_color", UiTheme.GOOD)
	if not GameFlow.sample_mode:
		Settings.save_if_changed()
	apply_button.disabled = true
	apply_button.focus_mode = Control.FOCUS_NONE
	var rest: Array = []
	for c in get_children():
		if c is Button and c != apply_button and (c as Button).focus_mode != Control.FOCUS_NONE:
			rest.append(c)
	_link_row(rest)
	back_button.grab_focus()


## Headline, colour and explanation of a result: [text, colour, second line].
static func verdict_text(res: Dictionary) -> Array:
	if str(res.get("fallback", "")) != "":
		return [UiFormat.t("Der Modus „Modern“ lässt sich mit dieser Grafik nicht starten."), UiTheme.BAD,
			UiFormat.t("Das Spiel läuft im Modus „Arcade“ weiter. (Grund: %s)") % str(res["fallback"])]
	if bool(res.get("aborted", false)):
		return [UiFormat.t("Abgebrochen – das Ergebnis ist unvollständig."), UiTheme.WARN, ""]
	if str(res.get("error", "")) != "" or (res.get("scenes", []) as Array).is_empty():
		return [UiFormat.t("Der Leistungstest konnte nicht laufen (%s).") % str(res.get("error", "?")), UiTheme.BAD, ""]
	if bool(res.get("renderer_stub", false)):
		return [UiFormat.t("Diese Vorabversion zeichnet im Modus „Modern“ erst ein Gerüst."), UiTheme.WARN,
			UiFormat.t("Die Zahlen sagen noch nichts über die fertige Grafik – der Test selbst hat funktioniert.")]
	var preset := OptionsScreen.preset_name(str(res.get("preset", "")))
	var sug := OptionsScreen.preset_name(str(res.get("suggested_preset", "")))
	var target := UiFormat.number(1000.0 / maxf(float(res.get("target_ms", 16.667)), 0.001), 0)
	match str(res.get("verdict", "")):
		"too_slow":
			return [UiFormat.t("Zu langsam: „Modern“ erreicht hier auch mit „%s“ keine flüssige Fahrt.") % preset, UiTheme.BAD,
				UiFormat.t("Vorschlag: der Modus „Arcade“ – er läuft auf jedem Rechner.")]
		"slow":
			if sug != preset:
				return [UiFormat.t("Etwas zu langsam für „%s“ – Vorschlag: „%s“.") % [preset, sug], UiTheme.WARN,
					UiFormat.t("Ziel sind %s Bilder pro Sekunde in jeder Szene.") % target]
			return [UiFormat.t("Etwas langsam, aber spielbar – eine niedrigere Voreinstellung gibt es nicht."), UiTheme.WARN,
				UiFormat.t("Ziel sind %s Bilder pro Sekunde in jeder Szene.") % target]
	if sug != preset and str(res.get("suggested_preset", "")) != "":
		return [UiFormat.t("Flüssig, mit Reserve – Vorschlag: „%s“.") % sug, UiTheme.GOOD,
			UiFormat.t("Jede Szene läuft deutlich schneller als %s Bilder pro Sekunde.") % target]
	return [UiFormat.t("Flüssig: „%s“ passt zu diesem Rechner.") % preset, UiTheme.GOOD, ""]


## "Grafikkarte: … · OpenGL … · Voreinstellung Mittel · 1280 × 800 · V-Sync aus"
static func machine_line(res: Dictionary) -> String:
	var adapter := str(res.get("adapter", ""))
	if adapter.length() > 52:
		adapter = adapter.substr(0, 51) + "…"
	var parts: Array[String] = [UiFormat.t("Grafikkarte: %s") % (adapter if adapter != "" else UiFormat.t("unbekannt"))]
	var q: Variant = res.get("quality", {})
	if q is Dictionary and not (q as Dictionary).is_empty():
		var qq: Dictionary = (q as Dictionary).duplicate()
		qq["preset"] = str(res.get("preset", ""))
		parts.append(quality_line(qq))
	var size: Variant = res.get("resolution", [])
	if size is Array and (size as Array).size() >= 2 and int(size[0]) > 0:
		parts.append("%d × %d" % [int(size[0]), int(size[1])])
	if res.has("vsync"):
		parts.append(UiFormat.t("V-Sync an (begrenzt die Bildrate)") if bool(res["vsync"]) else UiFormat.t("V-Sync aus"))
	return "  ·  ".join(parts)


## "Voreinstellung Mittel (Schatten Mittel, Details Mittel, Auflösung 100 %, MSAA 2×, Effekte Einfach)"
static func quality_line(q: Dictionary) -> String:
	var defs := OptionsScreen.quality_defs()
	var s := Gfx.sanitized(q)
	var vals: Array[String] = []
	for key: String in Gfx.QUALITY_KEYS:
		var d: Array = defs[key]
		var names: Array = d[1]
		var i := maxi(Gfx.SCALE_STEPS.find(int(s[key])), 0) if key == "scale" else int(s[key])
		var value := str(names[clampi(i, 0, names.size() - 1)])
		vals.append(value if key == "aa" and i > 0 else "%s %s" % [str(d[0]), value])
	return UiFormat.t("Voreinstellung %s (%s)") % [OptionsScreen.preset_name(str(q.get("preset", "custom"))), ", ".join(vals)]


## "etwa eine Minute" / "etwa 2 Minuten" for the start page (the scenes plus loading).
static func duration_text(scene_count: int, seconds: float) -> String:
	var minutes := maxi(1, roundi((float(scene_count) * (seconds + 4.0)) / 60.0))
	return UiFormat.t("eine Minute") if minutes == 1 else UiFormat.t("%d Minuten") % minutes


## Path of the result file as the player finds it in his file manager.
static func result_path() -> String:
	return ProjectSettings.globalize_path(RESULT_FILE)


## Sample results for the debug screens (screenshots of every case).
static func sample_result(kind: String) -> Dictionary:
	var res := {"version": 1, "date": "2026-11-11 18:30:00", "adapter": "AMD Custom GPU 0405 (radeonsi, vangogh, LLVM 17.0.6)",
		"api": "4.6 (Core Profile) Mesa 24.1", "tier": "deck", "preset": "deck",
		"quality": {"shadows": 1, "details": 1, "scale": 100, "aa": 1, "effects": 1}, "resolution": [1280, 800],
		"scenes": [
			{"id": "autobahn", "name": "Autobahn bei Tag", "avg_fps": 87.4, "low1_fps": 71.2, "frame_ms_p95": 12.9, "frame_ms_p99": 14.1,
				"script_ms": 1.31, "draw_calls": 412, "primitives": 281400, "frames": 1748},
			{"id": "stadt_nacht_regen", "name": "Stadt bei Nacht im Regen", "avg_fps": 64.8, "low1_fps": 52.3, "frame_ms_p95": 17.6,
				"frame_ms_p99": 19.4, "script_ms": 1.62, "draw_calls": 633, "primitives": 432900, "frames": 1296},
			{"id": "berg_tunnel", "name": "Bergstrecke mit Tunnel", "avg_fps": 92.1, "low1_fps": 68.0, "frame_ms_p95": 12.2, "frame_ms_p99": 14.9,
				"script_ms": 1.18, "draw_calls": 356, "primitives": 240100, "frames": 1842}],
		"suggested_preset": "deck", "suggested_mode": "modern", "verdict": "ok", "target_ms": 16.667, "vsync": false,
		"renderer_stub": false, "fallback": "", "aborted": false, "error": "", "written": true}
	match kind:
		"slow":
			res["preset"] = "medium"
			res["quality"] = {"shadows": 2, "details": 1, "scale": 100, "aa": 1, "effects": 1}
			res["verdict"] = "slow"
			for s: Dictionary in res["scenes"]:
				s["avg_fps"] = snappedf(float(s["avg_fps"]) * 0.55, 0.1)
				s["low1_fps"] = snappedf(float(s["low1_fps"]) * 0.55, 0.1)
				s["frame_ms_p95"] = snappedf(float(s["frame_ms_p95"]) / 0.55, 0.1)
				s["frame_ms_p99"] = snappedf(float(s["frame_ms_p99"]) / 0.55, 0.1)
		"arcade":
			res["adapter"] = "llvmpipe (LLVM 20.1.2, 256 bits)"
			res["tier"] = "software"
			res["preset"] = "low"
			res["quality"] = {"shadows": 0, "details": 0, "scale": 75, "aa": 0, "effects": 0}
			res["suggested_preset"] = "low"
			res["suggested_mode"] = "arcade"
			res["verdict"] = "too_slow"
			for s: Dictionary in res["scenes"]:
				s["avg_fps"] = snappedf(float(s["avg_fps"]) * 0.12, 0.1)
				s["low1_fps"] = snappedf(float(s["low1_fps"]) * 0.12, 0.1)
				s["frame_ms_p95"] = snappedf(float(s["frame_ms_p95"]) / 0.12, 0.1)
				s["frame_ms_p99"] = snappedf(float(s["frame_ms_p99"]) / 0.12, 0.1)
		"fallback":
			res["scenes"] = []
			res["fallback"] = "selftest:shader"
			res["suggested_mode"] = "arcade"
			res["verdict"] = ""
		"stub":
			res["renderer_stub"] = true
			for s: Dictionary in res["scenes"]:
				s["draw_calls"] = 0
				s["primitives"] = 0
		"abort":
			res["aborted"] = true
			res["scenes"] = []
	return res


# --- helpers ----------------------------------------------------------------------------------------------

func _text(text: String, fs: int, col: Color, kind: int = UiTheme.F.BODY_MEDIUM) -> Label:
	var l := UiKit.label(text, kind, fs, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(1100, 0)
	return l


## ◀▶ between the buttons of the bottom row (wrapping), ▲▼ stay.
func _link_row(buttons: Array) -> void:
	var n := buttons.size()
	for i in n:
		var b: Control = buttons[i]
		b.focus_neighbor_left = b.get_path_to(buttons[(i - 1 + n) % n])
		b.focus_neighbor_right = b.get_path_to(buttons[(i + 1) % n])
		b.focus_neighbor_top = b.get_path_to(b)
		b.focus_neighbor_bottom = b.get_path_to(b)
		b.focus_next = b.get_path_to(buttons[(i + 1) % n])
		b.focus_previous = b.get_path_to(buttons[(i - 1 + n) % n])


## One row per scene: name, average and 1 %-low pictures per second, frame time 95 % / 99 %, script time, draw calls,
## triangles. Fixed columns for 1116 px.
class _Table extends Control:
	const COLS: Array[float] = [0.0, 340.0, 460.0, 580.0, 790.0, 900.0, 1000.0]
	const WIDTHS: Array[float] = [330.0, 110.0, 110.0, 200.0, 100.0, 90.0, 116.0]

	var scenes: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var fb := UiTheme.font(UiTheme.F.BODY_BOLD)
		var f := UiTheme.font(UiTheme.F.BODY_MEDIUM)
		var fm := UiTheme.font(UiTheme.F.MONO)
		var heads := [tr("SZENE"), tr("Ø BILDER/S"), tr("1 % NIEDRIG"), tr("BILDZEIT 95 / 99 %"), tr("SKRIPT"), tr("AUFRUFE"), tr("DREIECKE")]
		for i in heads.size():
			draw_string(fb, Vector2(COLS[i], 20), str(heads[i]), HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT,
				WIDTHS[i], 18, UiTheme.TEXT_MUTED)
		draw_line(Vector2(0, 30), Vector2(size.x, 30), Color(UiTheme.ACCENT_2, 0.35), 1.0)
		var y := 38.0
		if scenes.is_empty():
			draw_string(f, Vector2(0, y + 24), tr("keine Szene gemessen"), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, UiTheme.TEXT_DIM)
			return
		for i in scenes.size():
			var s: Dictionary = scenes[i]
			if i % 2 == 0:
				draw_rect(Rect2(0, y, size.x, 34), Color(1, 1, 1, 0.035))
			var base := y + 25.0
			var nm := str(s.get("name", ""))
			draw_string(f, Vector2(8, base), nm if nm != "" else str(s.get("id", "")), HORIZONTAL_ALIGNMENT_LEFT, WIDTHS[0] - 8.0, 21, UiTheme.TEXT)
			var vals := [
				UiFormat.decimal(float(s.get("avg_fps", 0.0)), 1), UiFormat.decimal(float(s.get("low1_fps", 0.0)), 1),
				"%s / %s ms" % [UiFormat.decimal(float(s.get("frame_ms_p95", 0.0)), 1), UiFormat.decimal(float(s.get("frame_ms_p99", 0.0)), 1)],
				"%s ms" % UiFormat.decimal(float(s.get("script_ms", 0.0)), 2), UiFormat.grouped(int(s.get("draw_calls", 0))),
				UiFormat.grouped(int(s.get("primitives", 0))),
			]
			for k in vals.size():
				draw_string(fm, Vector2(COLS[k + 1], base), str(vals[k]), HORIZONTAL_ALIGNMENT_RIGHT, WIDTHS[k + 1], 20,
					UiTheme.GOLD if k == 0 else UiTheme.TEXT)
			y += 36.0
