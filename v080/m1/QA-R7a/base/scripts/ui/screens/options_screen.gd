class_name OptionsScreen
extends UiScreen
## Options in two pages (v0.8.0), switched with LB / RB (keyboard: Bild ↑ / Bild ↓, mouse: a click on the tab):
##   ALLGEMEIN  master / effects / music volume, "Klang" (sound profile: Wie Grafik | Arcade | Modern), "Musik im
##              Rennen" (only with the Modern sound – dimmed and skipped by the focus otherwise), gamepad vibration,
##              player name; on the right the controls overview.
##   GRAFIK     "Grafik" (Arcade | Modern), "Vollbild", then the quality of the mode "Modern": "Voreinstellung"
##              (Steam Deck | Niedrig | Mittel | Hoch | Eigene), Schatten, Details, Auflösung, Kantenglättung,
##              Effekte – dimmed and skipped by the focus while Grafik = Arcade; changing one value makes the preset
##              "Eigene" –, "Leistungstest", "Zurück"; on the right a picture of the same road in the chosen mode,
##              what the focused row does, the graphics adapter and what is recommended for it.
## Changes apply immediately (graphics: in the menus at once, in a race from the next start of a stage); settings
## are saved when leaving the screen. A value is only stored once the player has chosen it (Settings).
## Player name with a gamepad: A on the name field opens the on-screen keyboard (NameEntryBox); a
## keyboard (or the Steam keyboard, STEAM + X) types into the field directly – also when the focus reached
## it with the arrow keys / D-pad (the LineEdit is then not in edit mode; the first key starts it).
## build() works without a scene tree (unit tests build the screen and call its handlers).
## Debug: --options-tab=grafik opens the second page (screenshots); params {"tab": 0|1, "focus": "bench"}.

const TABS: Array[String] = ["ALLGEMEIN", "GRAFIK"]
const TAB_GENERAL := 0
const TAB_GRAPHICS := 1
const PREVIEW := "res://assets/ui/gfx_preview_%s.webp"
const ROW_H := 42.0                  ## rows of ALLGEMEIN
const GFX_ROW_H := 40.0              ## rows of GRAFIK (two more of them)

var tab := 0
var _name: LineEdit
var vibration: OptionRow             ## "Vibration An/Aus" (Settings.vibration)
var keyboard: NameEntryBox          ## open on-screen keyboard (null if none)
var sound_row: OptionRow             ## "Klang" Wie Grafik / Arcade / Modern (Settings.sound_profile)
var race_music_row: OptionRow        ## "Musik im Rennen" (Settings.race_music; Modern sound only)
var gfx_mode: OptionRow              ## "Grafik" Arcade / Modern (Settings.graphics_mode)
var fullscreen_row: OptionRow
var gfx_preset: OptionRow            ## "Voreinstellung"
var quality_rows: Dictionary = {}    ## key of Gfx.QUALITY_KEYS -> OptionRow
var bench_button: Button             ## "Leistungstest"
var _base_hints: Array = []
var _pages: Array[Control] = []
var _tab_buttons: Array[Button] = []
var _page_rows: Array = [[], []]     ## per page: its rows and buttons top to bottom
var _general_help: Label
var _preview: TextureRect
var _preview_name: Label
var _help: Label
var _status: Label


func build() -> void:
	add_header(tr("Optionen"))
	_base_hints = [[["ud"], tr("Wählen")], [["lr"], tr("Ändern")], [["pgup", "pgdn", "pad:LB", "pad:RB"], tr("Seite")],
		[["Esc", "pad:B"], tr("Zurück")]]
	hints = _base_hints
	# tab strip right of the title
	for i in TABS.size():
		var b := Button.new()
		b.text = tr(TABS[i])
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(show_tab.bind(i))
		UiKit.place(self, b, Rect2(700.0 + i * 248.0, 26, 236, 44))
		_tab_buttons.append(b)
	for i in TABS.size():
		var page := Control.new()
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(page)
		_pages.append(page)
	_build_general(_pages[TAB_GENERAL])
	_build_graphics(_pages[TAB_GRAPHICS])
	var start := int(params.get("tab", TAB_GRAPHICS if CliArgs.get_string("options-tab", "") == "grafik" else TAB_GENERAL))
	show_tab(start, false)
	default_focus = first_row(tab)
	if tab == TAB_GRAPHICS and str(params.get("focus", "")) == "bench":
		default_focus = bench_button   # back from the Leistungstest
		_on_gfx_focus(bench_button)


## Shows page `i`; with `focus` the focus goes to its first row (LB / RB, a click on the tab).
func show_tab(i: int, focus: bool = true) -> void:
	tab = clampi(i, 0, TABS.size() - 1)
	params["tab"] = tab   # GameFlow keeps the params: coming back (from the Leistungstest) shows this page again
	for k in _pages.size():
		_pages[k].visible = k == tab
		var on := k == tab
		_tab_buttons[k].add_theme_color_override("font_color", UiTheme.GOLD if on else UiTheme.TEXT_DIM)
		_tab_buttons[k].add_theme_color_override("font_hover_color", UiTheme.GOLD if on else UiTheme.TEXT)
		var box := UiTheme.button_box(Color(0.12, 0.16, 0.4, 0.85) if on else Color(0.05, 0.07, 0.2, 0.5),
			UiTheme.ACCENT if on else Color(1, 1, 1, 0.14), 0, 2)
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			_tab_buttons[k].add_theme_stylebox_override(state, box)
	if focus and is_inside_tree():
		UiKit.sound_modern("ui/ui_tab", "ui_move")
		var first := first_row(tab)
		if first != null:
			first.grab_focus()


## First focusable row of a page.
func first_row(page: int) -> Control:
	for c: Control in _page_rows[page]:
		if c.focus_mode != Control.FOCUS_NONE:
			return c
	return null


## LB / RB (Bild ↑ / Bild ↓) switch the page – before the GUI sees the event; not while the on-screen keyboard is open.
func _input(event: InputEvent) -> void:
	if keyboard != null and is_instance_valid(keyboard):
		return
	var d := 0
	if event.is_action_pressed("ui_page_down"):
		d = 1
	elif event.is_action_pressed("ui_page_up"):
		d = -1
	if d == 0:
		return
	get_viewport().set_input_as_handled()
	var target := UiKit.page_index(tab, d, TABS.size())
	if target != tab:
		show_tab(target)


# --- page ALLGEMEIN ---------------------------------------------------------------------------------------

func _build_general(page: Control) -> void:
	var left := _page_panel(page, Rect2(48, 104, 640, 560), UiTheme.ACCENT, 6)
	left.add_child(UiKit.label(tr("TON"), UiTheme.F.HEADING, 22, UiTheme.ACCENT_2))
	var master := _volume_row(tr("Gesamtlautstärke"), float(Settings.master_volume))
	master.value_changed.connect(func(i: int) -> void: _set_volume("master_volume", i))
	left.add_child(master)
	var sfx := _volume_row(tr("Effekte"), float(Settings.sfx_volume))
	sfx.value_changed.connect(func(i: int) -> void: _set_volume("sfx_volume", i))
	left.add_child(sfx)
	var music := _volume_row(tr("Musik"), float(Settings.music_volume))
	music.value_changed.connect(func(i: int) -> void: _set_volume("music_volume", i))
	left.add_child(music)
	sound_row = OptionRow.new(tr("Klang"), [tr("Wie Grafik"), tr("Arcade"), tr("Modern")],
		maxi(Gfx.SOUND_PROFILES.find(str(Settings.sound_profile)), 0))
	sound_row.value_changed.connect(_on_sound_profile)
	left.add_child(sound_row)
	race_music_row = OptionRow.new(tr("Musik im Rennen"), [tr("Aus"), tr("An")], 1 if Settings.race_music else 0)
	race_music_row.value_changed.connect(func(i: int) -> void:
		Settings.race_music = i == 1   # saved from now on (Settings.race_music_chosen)
		AudioManager.set_race_music(i == 1))
	left.add_child(race_music_row)
	vibration = OptionRow.new(tr("Vibration"), [tr("Aus"), tr("An")], 1 if Settings.vibration else 0)
	vibration.value_changed.connect(func(i: int) -> void:
		Settings.vibration = i == 1
		if i == 1 and not GameFlow.sample_mode:
			Haptics.test_pulse())   # a short pulse: this is what it feels like
	left.add_child(vibration)
	left.add_child(UiKit.label(tr("SPIELERNAME"), UiTheme.F.HEADING, 22, UiTheme.ACCENT_2))
	_name = LineEdit.new()
	_name.text = str(Settings.player_name)
	_name.max_length = NameEntry.MAX_LEN
	_name.placeholder_text = tr("Name für die Bestenlisten")
	_name.custom_minimum_size = Vector2(0, 50)
	_name.text_changed.connect(func(t: String) -> void: Settings.player_name = t.strip_edges())
	_name.gui_input.connect(_on_name_input)
	_name.focus_entered.connect(func() -> void: set_hints(_name_hints()))
	_name.focus_exited.connect(func() -> void:
		if keyboard == null:
			set_hints(_base_hints))
	left.add_child(_name)
	var back := UiKit.button(tr("Zurück"), 24, HORIZONTAL_ALIGNMENT_CENTER)
	back.pressed.connect(on_cancel)
	left.add_child(back)
	_general_help = UiKit.label("", UiTheme.F.BODY_MEDIUM, 18, UiTheme.TEXT_DIM)
	_general_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_general_help.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_general_help.custom_minimum_size = Vector2(0, 44)
	left.add_child(_general_help)
	var rows: Array = [master, sfx, music, sound_row, race_music_row, vibration, _name, back]
	for r: Control in rows:
		if r is OptionRow:
			r.custom_minimum_size.y = ROW_H
		r.focus_entered.connect(_on_general_focus.bind(r))
	_page_rows[TAB_GENERAL] = rows
	_refresh_general()
	var right := _page_panel(page, Rect2(708, 104, 516, 560), UiTheme.ACCENT_2, 6)
	right.add_child(UiKit.label(tr("STEUERUNG"), UiTheme.F.HEADING, 22, UiTheme.ACCENT_2))
	var ctl := _Controls.new()
	ctl.custom_minimum_size = Vector2(480, 470)
	right.add_child(ctl)


func _on_sound_profile(i: int) -> void:
	Settings.sound_profile = Gfx.SOUND_PROFILES[clampi(i, 0, Gfx.SOUND_PROFILES.size() - 1)]
	_refresh_general()
	_on_general_focus(sound_row)


## "Musik im Rennen" belongs to the Modern sound: dimmed and skipped by the focus with the Arcade sound.
func _refresh_general() -> void:
	set_row_enabled(race_music_row, Settings.sound() == Gfx.MODERN)
	_chain(TAB_GENERAL)


func _on_general_focus(row: Control) -> void:
	if _general_help == null:
		return
	var text := ""
	if row == sound_row:
		var now := tr("Modern") if Settings.sound() == Gfx.MODERN else tr("Arcade")
		text = tr("Motor, Fahrgeräusche und Musik: der bisherige Klang (Arcade) oder der neue (Modern). „Wie Grafik“ folgt dem gewählten Grafikmodus – zurzeit %s.") % now
	elif row == race_music_row:
		text = tr("Musik während der Fahrt – nur mit dem Klang „Modern“. Der Klang „Arcade“ hat im Rennen keine Musik.")
	_general_help.text = text


# --- page GRAFIK ------------------------------------------------------------------------------------------

func _build_graphics(page: Control) -> void:
	var left := _page_panel(page, Rect2(48, 104, 640, 560), UiTheme.ACCENT, 4)
	left.add_child(UiKit.label(tr("GRAFIK"), UiTheme.F.HEADING, 22, UiTheme.ACCENT_2))
	gfx_mode = OptionRow.new(tr("Grafik"), [tr("Arcade"), tr("Modern")], 1 if shown_mode() == Gfx.MODERN else 0)
	gfx_mode.value_changed.connect(_on_mode)
	left.add_child(gfx_mode)
	fullscreen_row = OptionRow.new(tr("Vollbild"), [tr("Aus"), tr("An")], 1 if Settings.fullscreen else 0)
	fullscreen_row.value_changed.connect(func(i: int) -> void:
		Settings.fullscreen = i == 1   # saved from now on (Settings.fullscreen_chosen)
		if not GameFlow.sample_mode:
			Settings.apply())
	left.add_child(fullscreen_row)
	left.add_child(UiKit.label(tr("QUALITÄT IM MODUS MODERN"), UiTheme.F.HEADING, 22, UiTheme.ACCENT_2))
	var q := Settings.stored_quality()
	gfx_preset = OptionRow.new(tr("Voreinstellung"), preset_names(), maxi(Gfx.PRESET_ORDER.find(str(q["preset"])), 0))
	gfx_preset.value_changed.connect(_on_preset)
	left.add_child(gfx_preset)
	var rows: Array = [gfx_mode, fullscreen_row, gfx_preset]
	var defs := quality_defs()
	for key: String in Gfx.QUALITY_KEYS:
		var d: Array = defs[key]
		var row := OptionRow.new(str(d[0]), d[1], _quality_index(key, q))
		row.wrap = false
		row.value_changed.connect(_on_quality.bind(key))
		left.add_child(row)
		quality_rows[key] = row
		rows.append(row)
	bench_button = UiKit.button(tr("Leistungstest"), 24, HORIZONTAL_ALIGNMENT_CENTER)
	bench_button.pressed.connect(_open_benchmark)
	left.add_child(bench_button)
	rows.append(bench_button)
	var back := UiKit.button(tr("Zurück"), 24, HORIZONTAL_ALIGNMENT_CENTER)
	back.pressed.connect(on_cancel)
	left.add_child(back)
	rows.append(back)
	for r: Control in rows:
		r.custom_minimum_size.y = GFX_ROW_H
		r.focus_entered.connect(_on_gfx_focus.bind(r))
	_page_rows[TAB_GRAPHICS] = rows
	# right: the same road in the chosen mode, what the focused row does, adapter and recommendation
	var right := _page_panel(page, Rect2(708, 104, 516, 560), UiTheme.ACCENT_2, 6)
	_preview_name = UiKit.label("", UiTheme.F.HEADING, 22, UiTheme.ACCENT_2)
	right.add_child(_preview_name)
	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_preview.custom_minimum_size = Vector2(480, 244)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_preview)
	_help = UiKit.label("", UiTheme.F.BODY_MEDIUM, 19, UiTheme.TEXT)
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.custom_minimum_size = Vector2(480, 122)
	_help.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	right.add_child(_help)
	_status = UiKit.label("", UiTheme.F.BODY_MEDIUM, 18, UiTheme.TEXT_DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(480, 0)
	right.add_child(_status)
	_refresh_graphics()
	_on_gfx_focus(gfx_mode)


## Names of the presets in the order of Gfx.PRESET_ORDER.
static func preset_names() -> Array:
	return [UiFormat.t("Steam Deck"), UiFormat.t("Niedrig"), UiFormat.t("Mittel"), UiFormat.t("Hoch"), UiFormat.t("Eigene")]


## Display name of a preset id ("deck" -> "Steam Deck").
static func preset_name(id: String) -> String:
	var i := Gfx.PRESET_ORDER.find(id)
	return str(preset_names()[i]) if i >= 0 else id


## Label and value names of the five quality rows: key -> [label, [values]].
static func quality_defs() -> Dictionary:
	var scales: Array = []
	for v in Gfx.SCALE_STEPS:
		scales.append("%d %%" % v)
	return {
		"shadows": [UiFormat.t("Schatten"), [UiFormat.t("Aus"), UiFormat.t("Niedrig"), UiFormat.t("Mittel"), UiFormat.t("Hoch")]],
		"details": [UiFormat.t("Details"), [UiFormat.t("Niedrig"), UiFormat.t("Mittel"), UiFormat.t("Hoch")]],
		"scale": [UiFormat.t("Auflösung"), scales],
		"aa": [UiFormat.t("Kantenglättung"), [UiFormat.t("Aus"), "MSAA 2×", "MSAA 4×"]],
		"effects": [UiFormat.t("Effekte"), [UiFormat.t("Aus"), UiFormat.t("Einfach"), UiFormat.t("Voll")]],
	}


## The mode the row "Grafik" shows: the player's choice, else what the game does without one (effective mode).
static func shown_mode() -> String:
	if Gfx.MODES.has(str(Settings.graphics_mode)):
		return str(Settings.graphics_mode)
	return str(Settings.effective_graphics()["mode"])


func _quality_index(key: String, q: Dictionary) -> int:
	return maxi(Gfx.SCALE_STEPS.find(int(q[key])), 0) if key == "scale" else int(q[key])


func _on_mode(i: int) -> void:
	Settings.graphics_mode = Gfx.MODES[clampi(i, 0, 1)]   # stored from now on; the sound follows while "Klang" is "Wie Grafik"
	_refresh_graphics()
	_refresh_general()
	_on_gfx_focus(gfx_mode)


func _on_preset(i: int) -> void:
	Settings.choose_preset(Gfx.PRESET_ORDER[clampi(i, 0, Gfx.PRESET_ORDER.size() - 1)])
	_refresh_graphics()


func _on_quality(i: int, key: String) -> void:
	Settings.set_quality_value(key, Gfx.SCALE_STEPS[clampi(i, 0, Gfx.SCALE_STEPS.size() - 1)] if key == "scale" else i)
	_refresh_graphics()


## The rows follow the settings: preset and quality rows show the stored values and are dimmed (not focusable)
## while Grafik = Arcade; the right panel shows the picture and the notes of the mode.
func _refresh_graphics() -> void:
	var modern := shown_mode() == Gfx.MODERN
	var q := Settings.stored_quality()
	gfx_mode.set_values(gfx_mode.values.duplicate(), 1 if modern else 0)
	gfx_preset.set_values(gfx_preset.values.duplicate(), maxi(Gfx.PRESET_ORDER.find(str(q["preset"])), 0))
	set_row_enabled(gfx_preset, modern)
	for key: String in quality_rows:
		var row: OptionRow = quality_rows[key]
		row.set_values(row.values.duplicate(), _quality_index(key, q))
		set_row_enabled(row, modern)
	_chain(TAB_GRAPHICS)
	_preview_name.text = tr("VORSCHAU: MODERN") if modern else tr("VORSCHAU: ARCADE")
	var path := PREVIEW % (Gfx.MODERN if modern else Gfx.ARCADE)
	_preview.texture = load(path) if ResourceLoader.exists(path) else null
	_status.text = status_text()


## Graphics adapter, what is recommended for it, and when changes apply (right panel of GRAFIK).
static func status_text() -> String:
	var tier := str(Settings.adapter_tier())
	var adapter := RenderingServer.get_video_adapter_name()
	if adapter == "":
		adapter = UiFormat.t("unbekannt")
	if adapter.length() > 46:
		adapter = adapter.substr(0, 45) + "…"
	var lines: Array[String] = [UiFormat.t("Grafikkarte: %s") % adapter]
	if Gfx.recommended_mode(tier) == Gfx.MODERN:
		lines.append(UiFormat.t("Empfohlen: Modern, Voreinstellung „%s“") % preset_name(Gfx.recommended_preset(tier)))
	elif tier == "software":
		lines.append(UiFormat.t("Empfohlen: Arcade (Software-Grafik ohne Grafikkarte)"))
	else:
		lines.append(UiFormat.t("Empfohlen: Arcade (ältere oder kleine Grafikkarte)"))
	var eff: Dictionary = Settings.effective_graphics()
	var mode_name := UiFormat.t("Modern") if str(eff["mode"]) == Gfx.MODERN else UiFormat.t("Arcade")
	match str(eff["reason"]):
		"cli":
			lines.append(UiFormat.t("Dieser Start erzwingt den Modus %s (Kommandozeile).") % mode_name)
		"config":
			lines.append(UiFormat.t("Die Konfiguration erzwingt den Modus %s.") % mode_name)
		"crash_guard":
			lines.append(UiFormat.t("Dieser Start läuft in Arcade: Modern wurde zuletzt nicht richtig beendet."))
	lines.append(UiFormat.t("Änderungen gelten in den Menüs sofort, im Rennen ab dem nächsten Start."))
	return "\n".join(lines)


func _on_gfx_focus(row: Control) -> void:
	if _help == null:
		return
	var text := tr("Zurück zum Hauptmenü. Die Einstellungen werden gespeichert.")
	if row == gfx_mode:
		text = tr("Arcade: das Spiel wie bisher – Pseudo-3D mit Sprites, läuft auf jedem Rechner.\nModern: echtes 3D mit feineren Modellen, Sonnenlicht, Schatten und Scheinwerfern. Strecken, Verkehr, Regeln und Bestenlisten sind in beiden Modi gleich.")
	elif row == fullscreen_row:
		text = tr("Vollbild ohne Fensterrahmen. Auf dem Steam Deck im Spielmodus immer an.")
	elif row == gfx_preset:
		text = tr("Stellt Schatten, Details, Auflösung, Kantenglättung und Effekte gemeinsam ein. „Steam Deck“ ist auf 1280×800 und den eingebauten Grafikchip abgestimmt. Wer einen Wert einzeln ändert, bekommt „Eigene“.")
	elif row == quality_rows.get("shadows"):
		text = tr("Schatten der Sonne. Kostet am meisten Leistung – bei Rucklern zuerst senken. Bei „Aus“ bekommen Fahrzeuge einen einfachen Schattenfleck.")
	elif row == quality_rows.get("details"):
		text = tr("Dichte und Sichtweite von Bäumen, Gebäuden und Kleinteilen. Fahrzeuge, Schilder und alles, worauf du reagieren musst, sind auf jeder Stufe gleich weit zu sehen.")
	elif row == quality_rows.get("scale"):
		text = tr("Auflösung des 3D-Bilds. Unter 100 % wird es weicher und schneller, darüber schärfer und langsamer. Anzeigen und Schrift bleiben immer scharf.")
	elif row == quality_rows.get("aa"):
		text = tr("Glättet Treppenstufen an Kanten (MSAA). 2× ist ein guter Kompromiss, 4× für starke Grafikkarten.")
	elif row == quality_rows.get("effects"):
		text = tr("Leuchten um Lichter, Gischt, Regen- und Schneetreiben, Spiegelungen auf nasser Fahrbahn. Lichter und Blinker der Fahrzeuge sind auf jeder Stufe zu sehen.")
	elif row == bench_button:
		text = tr("Fährt drei kurze Szenen im Modus Modern mit den Einstellungen oben, misst die Bilder pro Sekunde und schlägt eine Voreinstellung vor. Dauert etwa eine Minute.")
	_help.text = text


## "Leistungstest": the settings are saved first (the test reads them); the way back shows this page again.
func _open_benchmark() -> void:
	params["tab"] = TAB_GRAPHICS
	params["focus"] = "bench"
	if not GameFlow.sample_mode:
		Settings.player_name = _name.text.strip_edges()
		Settings.save_if_changed()
	GameFlow.go("benchmark")


# --- helpers ----------------------------------------------------------------------------------------------

func _page_panel(page: Control, rect: Rect2, accent: Color, sep: int) -> VBoxContainer:
	var p := UiKit.panel(UiTheme.PANEL, accent)
	UiKit.place(page, p, rect)
	var box := UiKit.vbox(sep)
	p.add_child(box)
	return box


## A row that does not apply right now is dimmed, takes no focus and no clicks.
static func set_row_enabled(row: Control, on: bool) -> void:
	row.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
	row.modulate.a = 1.0 if on else 0.38
	row.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE


## Links the focusable rows of a page top to bottom (wrapping) – dimmed rows are skipped. (A row is only ever
## dimmed while another one has the focus: "Klang" for "Musik im Rennen", "Grafik" for the quality rows.)
func _chain(page: int) -> void:
	var list: Array = []
	for c: Control in _page_rows[page]:
		if c.focus_mode != Control.FOCUS_NONE:
			list.append(c)
	if list.size() > 0:
		UiKit.chain_focus(list)


## Footer while the name field has the focus: gamepad A opens the on-screen keyboard.
func _name_hints() -> Array:
	return [[["ud"], tr("Wählen")], [["pad:A"], tr("Bildschirmtastatur")], [["Esc", "pad:B"], tr("Zurück")]]


## Gamepad A on the name field: on-screen keyboard (the keyboard's Enter is left to the LineEdit). A typed key
## starts editing when the field is not in edit mode yet (focus by navigation).
func _on_name_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.is_action_pressed("ui_accept"):
		_name.accept_event()
		open_keyboard()
	elif event is InputEventKey:
		NameEntry.begin_typing(_name, event as InputEventKey)


func open_keyboard() -> void:
	if keyboard != null and is_instance_valid(keyboard):
		return
	keyboard = NameEntryBox.new(tr("Spielername"), _name.text)
	keyboard.submitted.connect(_on_keyboard_name)
	keyboard.cancelled.connect(_close_keyboard)
	keyboard.hints_changed.connect(set_hints)
	add_child(keyboard)
	set_hints(keyboard.entry.current_hints())


func _on_keyboard_name(player_name: String) -> void:
	_name.text = player_name   # setting the text does not emit text_changed
	Settings.player_name = player_name
	_close_keyboard()


func _close_keyboard() -> void:
	keyboard = null
	set_hints(_name_hints())
	if is_inside_tree():
		_focus_later(_name)


func _volume_row(label: String, v: float) -> OptionRow:
	var vals: Array[String] = []
	for i in 11:
		vals.append(str(i))
	var r := OptionRow.new(label, vals, roundi(clampf(v, 0.0, 1.0) * 10.0))
	r.bar_mode = true
	r.wrap = false
	return r


func _set_volume(key: String, i: int) -> void:
	Settings.set(key, i / 10.0)
	AudioManager.apply_volumes()


## Fuel-lane note under the controls; the trigger speed comes from fuel.lane_trigger_speed_kmh.
static func lane_note(config: Dictionary) -> String:
	var lane_kmh := float(ConfigLoader.lookup(config, "fuel.lane_trigger_speed_kmh", 60.0))
	return UiFormat.t("Tankspur: unter %s km/h rollen – getankt wird automatisch. Gas geben bricht ab.") % UiFormat.number(lane_kmh, 0)


func on_cancel() -> void:
	Settings.player_name = _name.text.strip_edges()
	if not GameFlow.sample_mode:
		Settings.save_settings()
	GameFlow.back()


class _Controls extends Control:
	func _draw() -> void:
		var rows := [
			[tr("Lenken"), tr("Pfeil links/rechts, A D"), tr("Linker Stick, Steuerkreuz")],
			[tr("Gas"), tr("Pfeil hoch, W"), tr("Rechter Trigger, A")],
			[tr("Bremse"), tr("Pfeil runter, S"), tr("Linker Trigger, X")],
			[tr("Pause"), "Esc, P", tr("Start")],
			[tr("Menü: wählen"), tr("Pfeiltasten"), tr("Steuerkreuz, Stick")],
			[tr("Menü: Seite"), tr("Bild auf/ab"), "LB, RB"],
			[tr("Menü: bestätigen"), tr("Enter, Leertaste"), "A"],
			[tr("Menü: zurück"), "Esc", "B"],
		]
		var fb := UiTheme.font(UiTheme.F.BODY_BOLD)
		var f := UiTheme.font(UiTheme.F.BODY_MEDIUM)
		draw_string(fb, Vector2(0, 20), tr("AKTION"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiTheme.TEXT_MUTED)
		draw_string(fb, Vector2(140, 20), tr("TASTATUR"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiTheme.TEXT_MUTED)
		draw_string(fb, Vector2(300, 20), tr("GAMEPAD"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiTheme.TEXT_MUTED)
		draw_line(Vector2(0, 28), Vector2(size.x, 28), Color(UiTheme.ACCENT_2, 0.35), 1.0)
		var y := 60.0
		for r in rows:
			draw_string(fb, Vector2(0, y), str(r[0]), HORIZONTAL_ALIGNMENT_LEFT, 136, 20, UiTheme.TEXT)
			draw_string(f, Vector2(140, y), str(r[1]), HORIZONTAL_ALIGNMENT_LEFT, 150, 19, UiTheme.GOLD)
			draw_string(f, Vector2(300, y), str(r[2]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 300, 19, UiTheme.TEXT_DIM)
			y += 44.0
		var note := OptionsScreen.lane_note(ConfigLoader.load_merged())
		draw_multiline_string(f, Vector2(0, y + 10), note, HORIZONTAL_ALIGNMENT_LEFT, size.x, 18, -1, UiTheme.TEXT_DIM)
