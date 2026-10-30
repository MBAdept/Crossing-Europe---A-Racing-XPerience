class_name OptionsScreen
extends UiScreen
## Options: master / effects / music volume, fullscreen, player name and the controls overview.
## Changes apply immediately; settings are saved when leaving the screen.

var _name: LineEdit


func build() -> void:
	add_header(tr("Optionen"))
	hints = [[["ud"], tr("Wählen")], [["lr"], tr("Ändern")], [["Esc", "pad:B"], tr("Zurück")]]
	var left := add_panel(Rect2(48, 104, 640, 560), UiTheme.ACCENT, 8)
	left.add_child(UiKit.label(tr("TON UND BILD"), UiTheme.F.HEADING, 22, UiTheme.ACCENT_2))
	var master := _volume_row(tr("Gesamtlautstärke"), float(Settings.master_volume))
	master.value_changed.connect(func(i: int) -> void: _set_volume("master_volume", i))
	left.add_child(master)
	var sfx := _volume_row(tr("Effekte"), float(Settings.sfx_volume))
	sfx.value_changed.connect(func(i: int) -> void: _set_volume("sfx_volume", i))
	left.add_child(sfx)
	var music := _volume_row(tr("Musik"), float(Settings.music_volume))
	music.value_changed.connect(func(i: int) -> void: _set_volume("music_volume", i))
	left.add_child(music)
	var full := OptionRow.new(tr("Vollbild"), [tr("Aus"), tr("An")], 1 if Settings.fullscreen else 0)
	full.value_changed.connect(func(i: int) -> void:
		Settings.fullscreen = i == 1
		if not GameFlow.sample_mode:
			Settings.apply())
	left.add_child(full)
	left.add_child(UiKit.label(tr("SPIELERNAME"), UiTheme.F.HEADING, 22, UiTheme.ACCENT_2))
	_name = LineEdit.new()
	_name.text = str(Settings.player_name)
	_name.max_length = NameEntry.MAX_LEN
	_name.placeholder_text = tr("Name für die Bestenlisten")
	_name.custom_minimum_size = Vector2(0, 54)
	_name.text_changed.connect(func(t: String) -> void: Settings.player_name = t.strip_edges())
	left.add_child(_name)
	var back := UiKit.button(tr("Zurück"), 24, HORIZONTAL_ALIGNMENT_CENTER)
	back.pressed.connect(on_cancel)
	left.add_child(back)
	UiKit.chain_focus([master, sfx, music, full, _name, back])
	default_focus = master
	var right := add_panel(Rect2(708, 104, 516, 560), UiTheme.ACCENT_2, 6)
	right.add_child(UiKit.label(tr("STEUERUNG"), UiTheme.F.HEADING, 22, UiTheme.ACCENT_2))
	var ctl := _Controls.new()
	ctl.custom_minimum_size = Vector2(480, 470)
	right.add_child(ctl)


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
			[tr("Menü: bestätigen"), tr("Enter, Leertaste"), "A"],
			[tr("Menü: zurück"), "Esc", "B"],
		]
		var fb := UiTheme.font(UiTheme.F.BODY_BOLD)
		var f := UiTheme.font(UiTheme.F.BODY_MEDIUM)
		draw_string(fb, Vector2(0, 20), tr("AKTION"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.TEXT_MUTED)
		draw_string(fb, Vector2(140, 20), tr("TASTATUR"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.TEXT_MUTED)
		draw_string(fb, Vector2(300, 20), tr("GAMEPAD"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.TEXT_MUTED)
		draw_line(Vector2(0, 28), Vector2(size.x, 28), Color(UiTheme.ACCENT_2, 0.35), 1.0)
		var y := 60.0
		for r in rows:
			draw_string(fb, Vector2(0, y), str(r[0]), HORIZONTAL_ALIGNMENT_LEFT, 136, 20, UiTheme.TEXT)
			draw_string(f, Vector2(140, y), str(r[1]), HORIZONTAL_ALIGNMENT_LEFT, 150, 19, UiTheme.GOLD)
			draw_string(f, Vector2(300, y), str(r[2]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 300, 19, UiTheme.TEXT_DIM)
			y += 44.0
		var note := tr("Tankspur: unter 60 km/h rollen – getankt wird automatisch. Gas geben bricht ab.")
		draw_multiline_string(f, Vector2(0, y + 10), note, HORIZONTAL_ALIGNMENT_LEFT, size.x, 18, -1, UiTheme.TEXT_DIM)
