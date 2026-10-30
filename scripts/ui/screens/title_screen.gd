class_name TitleScreen
extends UiScreen
## Title / main menu: logo, menu (Rennen starten, Rennen fortsetzen, Einzelne Etappe, Bestenlisten,
## Optionen, Beenden) with a description line for the focused entry, the player's car on the highway.

var _desc: Label
var _buttons: Array[Button] = []
var confirm_box: ConfirmBox          ## open "overwrite the saved race?" question (null if none)


func build() -> void:
	bg_dim = 0.0
	hints = [[["ud"], tr("Wählen")], [["Enter", "pad:A"], tr("Bestätigen")]]
	var l1 := GradientText.new("CROSSING", UiTheme.font(UiTheme.F.LOGO), 80)
	UiKit.place(self, l1, Rect2(84, 30, 760, 100))
	var l2 := GradientText.new("EUROPE", UiTheme.font(UiTheme.F.LOGO), 80)
	UiKit.place(self, l2, Rect2(84, 114, 760, 100))
	var tag_font := FontVariation.new()
	tag_font.base_font = UiTheme.font(UiTheme.F.TITLE)
	tag_font.spacing_glyph = 5
	var tag := Label.new()
	tag.text = "A RACING XPERIENCE"
	tag.add_theme_font_override("font", tag_font)
	tag.add_theme_font_size_override("font_size", 27)
	tag.add_theme_color_override("font_color", UiTheme.ACCENT_2)
	tag.add_theme_color_override("font_shadow_color", Color(UiTheme.ACCENT, 0.6))
	tag.add_theme_constant_override("shadow_offset_x", 2)
	tag.add_theme_constant_override("shadow_offset_y", 2)
	UiKit.place(self, tag, Rect2(92, 208, 600, 40))

	var box := UiKit.vbox(8)
	UiKit.place(self, box, Rect2(92, 266, 410, 352))
	var has_save := UiData.has_saved_race()
	var items := [
		[tr("Rennen starten"), tr("Etappenrennen quer durch Europa – Rennen, Fahrzeug und Startzeit wählen."), _new_race, true],
		[tr("Rennen fortsetzen"), _save_text(), GameFlow.continue_race, has_save],
		[tr("Einzelne Etappe"), tr("Eine Etappe frei wählen: Richtung, Uhrzeit und Wetter."), GameFlow.single_stage, true],
		[tr("Bestenlisten"), tr("Top 10 aller Etappen und Rennen."), func() -> void: GameFlow.go("leaderboards"), true],
		[tr("Optionen"), tr("Lautstärke, Vollbild, Spielername und Steuerung."), func() -> void: GameFlow.go("options"), true],
		[tr("Beenden"), tr("Zurück auf den Boden der Tatsachen."), GameFlow.quit_game, true],
	]
	for it in items:
		var b := UiKit.button(str(it[0]), 25)
		b.custom_minimum_size = Vector2(390, 44)
		b.disabled = not bool(it[3])
		if b.disabled:
			b.focus_mode = Control.FOCUS_NONE
		var cb: Callable = it[2]
		b.pressed.connect(cb)
		var d := str(it[1])
		b.focus_entered.connect(func() -> void: _desc.text = d)
		box.add_child(b)
		_buttons.append(b)
	_desc = UiKit.label("", UiTheme.F.BODY_MEDIUM, 21, UiTheme.TEXT_DIM)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiKit.place(self, _desc, Rect2(96, 630, 620, 40))
	default_focus = _buttons[1] if has_save else _buttons[0]
	var ver := UiKit.label("v" + str(ProjectSettings.get_setting("application/config/version", "0.1")), UiTheme.F.MONO, 16, UiTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	UiKit.place(self, ver, Rect2(1016, 684, 200, 24))
	var car := TextureRect.new()
	var db: Node = get_node_or_null("/root/SpriteDB")
	if db != null and db.call("has_set", "player/sportwagen"):
		var at := AtlasTexture.new()
		at.atlas = db.call("texture", "player/sportwagen")
		at.region = db.call("region", "player/sportwagen", "c", "base")
		if at.atlas != null:
			car.texture = at
			car.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			car.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			car.mouse_filter = Control.MOUSE_FILTER_IGNORE
			UiKit.place(self, car, Rect2(1280 * 0.7 - 130, 540, 260, 170))


## "Rennen starten": there is only one save slot – with a saved race in progress ask first, because
## confirming the start time of a new race replaces it.
func _new_race() -> void:
	if not UiData.has_saved_race():
		GameFlow.new_race()
		return
	confirm_box = ConfirmBox.new(tr("Gespeichertes Rennen überschreiben?"),
		tr("Gespeichert: %s\nEin neues Rennen ersetzt diesen Spielstand, sobald du seine Startzeit bestätigst.") % _save_text(),
		tr("Neues Rennen"), tr("Abbrechen"))
	confirm_box.confirmed.connect(GameFlow.new_race)
	add_child(confirm_box)


func _save_text() -> String:
	var d := UiData.load_race()
	if d.is_empty():
		return tr("Kein gespeichertes Rennen.")
	var rs := RaceState.from_dict(d, UiData.race(str(d.get("race_id", ""))))
	if rs.is_finished():
		# kept until the race result's name entry is done (GameFlow.finish_race)
		return tr("%s – im Ziel nach %s, Eintrag in die Bestenliste offen") % [rs.race_name, UiFormat.time(rs.total_time_s)]
	return tr("%s – Etappe %d ab %s, bisher %s") % [rs.race_name, rs.next_stage_number(), UiData.city_name(rs.current_city), UiFormat.time(rs.total_time_s)]


func on_cancel() -> void:
	pass
