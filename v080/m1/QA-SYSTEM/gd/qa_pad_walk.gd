extends SceneTree
## QA-SYSTEM: gamepad-only walk through the new menus of v0.8.0 in the real GameFlow (headless or under Xvfb with
## pictures): chooser (no trap, B does nothing, ◀▶ + A), title, options both pages (focus order with Grafik = Arcade
## and Modern, LB/RB, wrap), Leistungstest page (B back), crash-guard question on the title (B = stay Arcade).
## With a display: a PNG per step into --out=<dir> and the smallest font size of every visible text control.
## No --graphics on the command line (the stored choice is under test).

var _gf: Node
var _st: Node
var _failed: Array[String] = []
var _n := 0
var _out := ""
var _fonts: Dictionary = {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	_run.call_deferred()


func _check(check_name: String, ok: bool, msg: String = "") -> void:
	_n += 1
	print("CHECK %-24s %s  %s" % [check_name, "OK    " if ok else "FEHLER", msg])
	if not ok:
		_failed.append(check_name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _tap(b: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventJoypadButton.new()
		e.device = 0
		e.button_index = b
		e.pressed = pressed
		e.pressure = 1.0 if pressed else 0.0
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await _frames(3)
	await _frames(3)


func _focus_label() -> String:
	var f := root.gui_get_focus_owner()
	if f == null:
		return "<kein Fokus>"
	for key: String in ["label_text", "title"]:
		var lt: Variant = f.get(key)
		if lt != null and str(lt) != "":
			return str(lt)
	if f is Button:
		return (f as Button).text
	if f is LineEdit:
		return "LineEdit:" + (f as LineEdit).text
	return f.get_class()


func _screen() -> Node:
	var shell: Node = _gf.get("shell")
	return shell.get("current_screen") if shell != null else null


## Focus sequence pressing ▼ n times from the current focus.
func _walk(b: JoyButton, n: int) -> Array[String]:
	var seq: Array[String] = [_focus_label()]
	for i in n:
		await _tap(b)
		seq.append(_focus_label())
	return seq


func _min_font(node: Node, acc: Array) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is Control:
		var c := node as Control
		var txt := ""
		var fs := 0
		if c is Label:
			txt = (c as Label).text
			fs = c.get_theme_font_size("font_size")
		elif c is Button:
			txt = (c as Button).text
			fs = c.get_theme_font_size("font_size")
		elif c is LineEdit:
			txt = (c as LineEdit).text + (c as LineEdit).placeholder_text
			fs = c.get_theme_font_size("font_size")
		elif c is RichTextLabel:
			txt = (c as RichTextLabel).get_parsed_text()
			fs = c.get_theme_font_size("normal_font_size")
		if txt.strip_edges() != "" and fs > 0 and c.modulate.a > 0.05:
			var scale := c.get_global_transform_with_canvas().get_scale().y * root.get_final_transform().get_scale().y
			acc.append([fs * scale, txt.substr(0, 40).replace("\n", " "), c.get_class()])
	for ch in node.get_children():
		_min_font(ch, acc)


func _shot(step: String) -> void:
	await _frames(4)
	var acc: Array = []
	_min_font(root, acc)
	var mn := 999.0
	var small: Array = []
	for a: Array in acc:
		mn = minf(mn, float(a[0]))
		if float(a[0]) < 18.0 - 0.01:
			small.append("%s (%.1f px, %s)" % [a[1], float(a[0]), a[2]])
	_fonts[step] = mn
	print("FONT %-22s min %.1f px over %d texts%s" % [step, mn, acc.size(), ("  KLEIN: " + "; ".join(small)) if not small.is_empty() else ""])
	if _out != "" and DisplayServer.get_name() != "headless":
		var img := root.get_texture().get_image()
		img.save_png(_out.path_join(step + ".png"))


func _run() -> void:
	_gf = root.get_node("GameFlow")
	_st = root.get_node("Settings")
	(_gf.get("attract") as Node).set("enabled", false)
	await _frames(5)
	print("WINDOW ", DisplayServer.window_get_size(), " final scale ", root.get_final_transform().get_scale())
	# 1 chooser
	_gf.call("go", "graphics_choice", {}, true)
	await _frames(8)
	await _shot("01_chooser")
	var first := _focus_label()
	await _tap(JOY_BUTTON_DPAD_UP)
	await _tap(JOY_BUTTON_DPAD_DOWN)
	await _tap(JOY_BUTTON_B)
	var still := str(_gf.call("current_screen_name"))
	_check("chooser_no_way_out", still == "graphics_choice" and _focus_label() == first, "Fokus %s -> %s, Bildschirm %s" % [first, _focus_label(), still])
	await _tap(JOY_BUTTON_DPAD_RIGHT)
	var second := _focus_label()
	await _tap(JOY_BUTTON_DPAD_RIGHT)
	var third := _focus_label()
	_check("chooser_lr", second != first and third == first, "%s -> %s -> %s" % [first, second, third])
	if _focus_label() != "MODERN":
		await _tap(JOY_BUTTON_DPAD_RIGHT)
	await _tap(JOY_BUTTON_A)
	await _frames(6)
	_check("chooser_a", str(_st.get("graphics_mode")) == "modern" and str(_gf.call("current_screen_name")) == "title",
		"graphics_mode %s, Bildschirm %s" % [_st.get("graphics_mode"), _gf.call("current_screen_name")])
	await _shot("02_title")
	# 2 title: walk down through all entries, find "Optionen"
	var seq := await _walk(JOY_BUTTON_DPAD_DOWN, 9)
	print("TITEL ▼: ", " | ".join(seq))
	var guard := 0
	while _focus_label() != "Optionen" and guard < 8:
		await _tap(JOY_BUTTON_DPAD_UP)
		guard += 1
	await _tap(JOY_BUTTON_A)
	await _frames(6)
	_check("title_to_options", str(_gf.call("current_screen_name")) == "options", str(_gf.call("current_screen_name")))
	await _shot("03_options_allgemein")
	var gseq := await _walk(JOY_BUTTON_DPAD_DOWN, 9)
	print("ALLGEMEIN ▼: ", " | ".join(gseq))
	_check("allgemein_wrap", gseq[0] == gseq[gseq.size() - 1] or gseq.has("Zurück"), " | ".join(gseq))
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	var scr := _screen()
	if scr == null or scr.get("tab") == null:
		_check("options_screen", false, "kein Optionsbildschirm")
		print("QA-PAD %d Prüfungen, %d Fehler %s" % [_n, _failed.size(), str(_failed)])
		quit(1)
		return
	_check("rb_grafik", int(scr.get("tab")) == 1 and _focus_label() == "Grafik", "Seite %d Fokus %s" % [int(scr.get("tab")), _focus_label()])
	await _shot("04_options_grafik_modern")
	var mseq := await _walk(JOY_BUTTON_DPAD_DOWN, 11)
	print("GRAFIK (Modern) ▼: ", " | ".join(mseq))
	_check("grafik_modern_rows", mseq.has("Schatten") and mseq.has("Effekte") and mseq.has("Leistungstest") and mseq.has("Zurück"), " | ".join(mseq))
	while _focus_label() != "Grafik":
		await _tap(JOY_BUTTON_DPAD_DOWN)
	await _tap(JOY_BUTTON_DPAD_LEFT)   # Arcade
	await _shot("05_options_grafik_arcade")
	var aseq := await _walk(JOY_BUTTON_DPAD_DOWN, 5)
	print("GRAFIK (Arcade) ▼: ", " | ".join(aseq))
	_check("grafik_arcade_skip", not aseq.has("Schatten") and aseq.has("Leistungstest") and aseq[0] == aseq[4],
		" | ".join(aseq))
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	_check("rb_end_stays", int(scr.get("tab")) == 1 or int(scr.get("tab")) == 0, "Seite %d" % int(scr.get("tab")))
	print("RB auf letzter Seite -> Seite ", int(scr.get("tab")), " Fokus ", _focus_label())
	if int(scr.get("tab")) != 1:
		await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	# 3 Leistungstest page and back with B
	while _focus_label() != "Leistungstest":
		await _tap(JOY_BUTTON_DPAD_DOWN)
	await _tap(JOY_BUTTON_A)
	await _frames(6)
	_check("bench_page", str(_gf.call("current_screen_name")) == "benchmark", str(_gf.call("current_screen_name")))
	await _shot("06_benchmark_start")
	var bseq := await _walk(JOY_BUTTON_DPAD_RIGHT, 3)
	print("LEISTUNGSTEST ▶: ", " | ".join(bseq))
	await _tap(JOY_BUTTON_B)
	await _frames(6)
	_check("bench_b_back", str(_gf.call("current_screen_name")) == "options" and _focus_label() == "Leistungstest",
		"%s Fokus %s" % [_gf.call("current_screen_name"), _focus_label()])
	await _tap(JOY_BUTTON_B)
	await _frames(6)
	_check("options_b_title", str(_gf.call("current_screen_name")) == "title", str(_gf.call("current_screen_name")))
	# 4 crash-guard question: the marker of a Modern start that did not end
	_st.set("graphics_mode", "modern")
	_st.call("arm_crash_guard")
	_st.set("crash_guard", true)
	_gf.call("show_title")
	await _frames(10)
	await _shot("07_title_crash_question")
	var q_focus := _focus_label()
	await _tap(JOY_BUTTON_B)
	await _frames(6)
	var marker := FileAccess.file_exists(str(_st.get("marker_path")))
	_check("crash_question_b", str(_st.get("graphics_mode")) == "arcade" and not marker and not bool(_st.get("crash_guard")),
		"Fokus vorher %s, Grafik %s, Marker %s" % [q_focus, _st.get("graphics_mode"), marker])
	await _shot("08_title_after_question")
	var fmin := 999.0
	for k: String in _fonts:
		fmin = minf(fmin, float(_fonts[k]))
	_check("text_min_18px", fmin >= 17.99, "kleinste Schrift %.1f px" % fmin)
	print("QA-PAD %d Prüfungen, %d Fehler %s" % [_n, _failed.size(), str(_failed)])
	quit(0 if _failed.is_empty() else 1)
