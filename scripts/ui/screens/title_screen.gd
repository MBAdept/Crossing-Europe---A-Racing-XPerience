class_name TitleScreen
extends UiScreen
## Title / main menu over the photo backdrop (TitleBackdrop: the player's artwork, a red sports car on the autobahn
## at sunset heading for the Frankfurt skyline). The left two thirds of the picture stay free – sun, skyline and
## the red car are the hero; the logo stands over the sky at the top right with a soft shadow, the menu (Rennen
## starten, Rennen fortsetzen, Einzelne Etappe, Bestenlisten, Optionen, Beenden) and the description of the
## focused entry sit on a frosted-glass card (GlassPanel) over the right side of the road, where the picture
## matters least. After a minute without input the attract mode shows a demo (AttractMode, GameFlow).

const LOGO_RIGHT := 1236.0
const CARD := Rect2(846, 244, 390, 414)
const CARD_PAD := Vector2(26, 20)

var _desc: Label
var _buttons: Array[Button] = []
var confirm_box: ConfirmBox          ## open "overwrite the saved race?" question (null if none)


func build() -> void:
	bg_dim = 0.0
	backdrop = "title"
	hints = [[["ud"], tr("Wählen")], [["Enter", "pad:A"], tr("Bestätigen")]]
	_build_logo()
	var card := GlassPanel.new()
	UiKit.place(self, card, CARD)
	# card content top to bottom: buttons, a thin line, the description of the focused entry
	var content := UiKit.vbox(10)
	UiKit.place(self, content, Rect2(CARD.position + CARD_PAD, CARD.size - CARD_PAD * 2.0))
	var box := UiKit.vbox(6)
	content.add_child(box)
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
		var b := UiKit.button(str(it[0]), 24)
		b.custom_minimum_size = Vector2(CARD.size.x - CARD_PAD.x * 2.0, 44)
		_glass_style(b)
		b.disabled = not bool(it[3])
		if b.disabled:
			b.focus_mode = Control.FOCUS_NONE
		var cb: Callable = it[2]
		b.pressed.connect(cb)
		var d := str(it[1])
		b.focus_entered.connect(func() -> void: _desc.text = d)
		box.add_child(b)
		_buttons.append(b)
	var line := TextureRect.new()
	line.texture = UiTheme.gradient_tex(Color(UiTheme.ACCENT_2, 0.55), Color(UiTheme.ACCENT_2, 0.0))
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.custom_minimum_size = Vector2(0, 2)
	content.add_child(line)
	_desc = UiKit.label("", UiTheme.F.BODY_MEDIUM, 19, UiTheme.TEXT_DIM)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_desc.custom_minimum_size = Vector2(0, 48)
	content.add_child(_desc)
	default_focus = _buttons[1] if has_save else _buttons[0]
	var ver := UiKit.label("v" + str(ProjectSettings.get_setting("application/config/version", "0.1")), UiTheme.F.MONO, 18, UiTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	UiKit.place(self, ver, Rect2(1036, 684, 200, 24))


## Logo over the sky at the top right: soft dark halo behind it, chrome gradient text, cyan tagline.
func _build_logo() -> void:
	var halo := TextureRect.new()
	halo.texture = TitleBackdrop.halo_texture()
	halo.stretch_mode = TextureRect.STRETCH_SCALE
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(self, halo, Rect2(LOGO_RIGHT - 600, -70, 760, 340))
	var l1 := GradientText.new("CROSSING", UiTheme.font(UiTheme.F.LOGO), 66)
	l1.align = HORIZONTAL_ALIGNMENT_RIGHT
	UiKit.place(self, l1, Rect2(LOGO_RIGHT - 520, 14, 525, 86))
	var l2 := GradientText.new("EUROPE", UiTheme.font(UiTheme.F.LOGO), 66)
	l2.align = HORIZONTAL_ALIGNMENT_RIGHT
	UiKit.place(self, l2, Rect2(LOGO_RIGHT - 520, 84, 525, 86))
	var tag_font := FontVariation.new()
	tag_font.base_font = UiTheme.font(UiTheme.F.TITLE)
	tag_font.spacing_glyph = 5
	var tag := Label.new()
	tag.text = "A RACING XPERIENCE"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.add_theme_font_override("font", tag_font)
	tag.add_theme_font_size_override("font_size", 24)
	tag.add_theme_color_override("font_color", UiTheme.ACCENT_2)
	tag.add_theme_color_override("font_shadow_color", Color(0.02, 0.0, 0.08, 0.85))
	tag.add_theme_constant_override("shadow_offset_x", 2)
	tag.add_theme_constant_override("shadow_offset_y", 2)
	tag.add_theme_constant_override("shadow_outline_size", 6)
	UiKit.place(self, tag, Rect2(LOGO_RIGHT - 560, 172, 560, 36))


## Menu buttons on the glass card: translucent at rest (the glass shows through), the theme's focus glow; a
## little tighter than the theme buttons (all states alike, so pressing does not change the height).
static func _glass_style(b: Button) -> void:
	var styles := {
		"normal": UiTheme.button_box(Color(0.05, 0.07, 0.2, 0.42), Color(1, 1, 1, 0.14), 0, 2),
		"hover": UiTheme.button_box(Color(0.12, 0.16, 0.4, 0.72), UiTheme.ACCENT_2, 0, 2),
		"pressed": UiTheme.button_box(UiTheme.ACCENT.darkened(0.25), UiTheme.ACCENT, 0, 2),
		"hover_pressed": UiTheme.button_box(UiTheme.ACCENT.darkened(0.2), UiTheme.ACCENT, 0, 2),
		"disabled": UiTheme.button_box(Color(0.04, 0.05, 0.13, 0.3), Color(1, 1, 1, 0.07), 0, 1),
	}
	for state: String in styles:
		var sb: StyleBoxFlat = styles[state]
		sb.content_margin_top = 5
		sb.content_margin_bottom = 6
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_disabled_color", Color(UiTheme.TEXT_DIM, 0.62))


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


## True while a question box is open (the attract mode waits then).
func has_modal() -> bool:
	return confirm_box != null and is_instance_valid(confirm_box) and confirm_box.is_inside_tree()


func on_cancel() -> void:
	pass
