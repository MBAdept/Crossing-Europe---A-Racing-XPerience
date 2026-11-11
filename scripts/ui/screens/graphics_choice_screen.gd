class_name GraphicsChoiceScreen
extends UiScreen
## "GRAFIK WÄHLEN" – shown once, before the title, at the first start of v0.8.0 (contract D32: no graphics mode
## stored yet, the game started without any command line argument and with a display; new and existing players
## alike – nobody is switched silently). Two cards, "Arcade" and "Modern", each with a picture of the same road in
## that mode (assets/ui/gfx_preview_*.webp, tools/gfx_previews.sh). ◀▶ choose, one A / Enter confirms; there is no
## way around it (B does nothing). The card recommended for this computer has the focus and the badge "EMPFOHLEN FÜR
## DIESEN RECHNER" (Gfx.recommended_mode of the adapter tier: Modern for deck / ok, Arcade for software / weak, and
## Arcade when Modern did not survive its last start – Settings.crash_guard).
## The choice sets Settings.graphics_mode and leaves the sound profile at "Wie Grafik": picture and sound switch
## together, both can be changed any time in the options. It is saved at once.
## Debug (sample screens only): --recommend=arcade|modern, --existing-player=0|1 for screenshots of every case.

const CARD_W := 560.0
const CARD_H := 472.0
const CARD_Y := 98.0

var cards: Array[Button] = []
var recommended := Gfx.ARCADE


func build() -> void:
	var existing := existing_player()
	var tier := str(Settings.adapter_tier())
	recommended = recommended_for(tier, bool(Settings.crash_guard))
	if GameFlow.sample_mode:
		if CliArgs.has("recommend") and Gfx.MODES.has(CliArgs.get_string("recommend", "")):
			recommended = CliArgs.get_string("recommend", recommended)
			if recommended == Gfx.MODERN:
				tier = "ok"   # the warning of this machine's tier would contradict the forced recommendation
		if CliArgs.has("existing-player"):
			existing = CliArgs.get_string("existing-player", "1") != "0"
	add_header(tr("Grafik wählen"), tr("Neu in v0.8.0: der Modus „Modern“") if existing else tr("Wie soll Crossing Europe aussehen?"))
	hints = [[["lr"], tr("Wählen")], [["Enter", "pad:A"], tr("Übernehmen")]]
	var texts := card_texts()
	for i in Gfx.MODES.size():
		var id := Gfx.MODES[i]
		var card := _Card.new()
		card.title = str(texts[id][0])
		card.body = str(texts[id][1])
		card.recommended = id == recommended
		var path := OptionsScreen.PREVIEW % id
		card.picture = load(path) if ResourceLoader.exists(path) else null
		card.pressed.connect(choose.bind(id))
		UiKit.place(self, card, Rect2(64.0 + i * (CARD_W + 32.0), CARD_Y, CARD_W, CARD_H))
		cards.append(card)
	# ◀▶ move between the two cards and nowhere else (▲▼ stay): no focus trap, no way out
	for i in cards.size():
		var c := cards[i]
		var other := cards[1 - i]
		c.focus_neighbor_left = c.get_path_to(other)
		c.focus_neighbor_right = c.get_path_to(other)
		c.focus_neighbor_top = c.get_path_to(c)
		c.focus_neighbor_bottom = c.get_path_to(c)
		c.focus_next = c.get_path_to(other)
		c.focus_previous = c.get_path_to(other)
	var note := UiKit.label(tr("Strecken, Verkehr, Regeln, Spielstand und Bestenlisten sind in beiden Modi gleich. Umschalten jederzeit in den Optionen, Seite „Grafik“."),
		UiTheme.F.BODY_MEDIUM, 20, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.place(self, note, Rect2(64, 580, 1152, 28))
	var warn_text := warning_text(tier, bool(Settings.crash_guard))
	if warn_text != "":
		var warn := UiKit.label(warn_text, UiTheme.F.BODY_BOLD, 20, UiTheme.WARN, HORIZONTAL_ALIGNMENT_CENTER)
		UiKit.place(self, warn, Rect2(64, 610, 1152, 28))
	default_focus = cards[Gfx.MODES.find(recommended)]


## The mode whose card is preselected: what fits the graphics adapter – but Arcade when Modern did not survive its
## last start (the crash-guard marker is there).
static func recommended_for(tier: String, crash_guard: bool) -> String:
	return Gfx.ARCADE if crash_guard else Gfx.recommended_mode(tier)


## Title and description of the two cards: mode id -> [title, text].
static func card_texts() -> Dictionary:
	return {
		Gfx.ARCADE: [UiFormat.t("ARCADE"), UiFormat.t("Das Spiel wie bisher: Pseudo-3D mit Sprites im Stil der Arcade-Racer der 80er, mit dem bisherigen Klang.\nLäuft auf jedem Rechner.")],
		Gfx.MODERN: [UiFormat.t("MODERN"), UiFormat.t("Echtes 3D: feinere Modelle, Sonnenlicht und Schatten, Scheinwerfer bei Nacht, neuer Klang und Musik im Rennen.\nBraucht eine Grafikkarte oder einen neueren Grafikchip.")],
	}


## Line under the cards for computers on which Modern is a risk ("" = none).
static func warning_text(tier: String, crash_guard: bool) -> String:
	if crash_guard:
		return UiFormat.t("Der Modus „Modern“ wurde beim letzten Start nicht richtig beendet.")
	if tier == "software":
		return UiFormat.t("Dieser Rechner zeichnet ohne Grafikkarte (Software-Grafik) – „Modern“ läuft hier voraussichtlich sehr langsam.")
	if tier == "weak":
		return UiFormat.t("Die Grafikkarte dieses Rechners ist älter oder klein – „Modern“ läuft hier voraussichtlich langsam.")
	return ""


## True when the player has played before v0.8.0 asked: a settings file, a saved race or leaderboards exist.
static func existing_player() -> bool:
	return FileAccess.file_exists(str(Settings.file_path)) or FileAccess.file_exists("user://savegame.json") \
		or FileAccess.file_exists("user://leaderboards.json")


## A card was confirmed: the mode is stored (the sound follows it – "Klang" stays "Wie Grafik"), a crash-guard
## marker of the last run is settled by this explicit choice, and the title follows.
func choose(id: String) -> void:
	if not Gfx.MODES.has(id):
		return
	Settings.graphics_mode = id
	if bool(Settings.crash_guard):
		Settings.disarm_crash_guard()
	if not GameFlow.sample_mode:
		Settings.save_settings()
	GameFlow.show_title()


func on_cancel() -> void:
	pass   # no way around it: one of the two cards (a single A on the recommended one)


class _Card extends Button:
	const PAD := 18.0

	var title := ""
	var body := ""
	var recommended := false
	var picture: Texture2D

	func _init() -> void:
		focus_mode = Control.FOCUS_ALL
		flat = true
		for state in ["focus", "normal", "hover", "pressed", "hover_pressed"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		pressed.connect(func() -> void: UiKit.sound("ui_ok"))
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var focused := has_focus()
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.035, 0.05, 0.14, 0.92))
		if focused:
			for i in 4:
				draw_rect(r.grow(2.0 + i * 2.0), Color(UiTheme.ACCENT, 0.22 - i * 0.05), false, 2.0)
		draw_rect(r, UiTheme.ACCENT if focused else (UiTheme.ACCENT_2 if is_hovered() else UiTheme.PANEL_LINE), false, 3.0 if focused else 1.5)
		var pic := Rect2(PAD, PAD, size.x - PAD * 2.0, (size.x - PAD * 2.0) * 9.0 / 16.0)
		if picture != null:
			draw_texture_rect(picture, pic, false, Color.WHITE if focused else Color(0.72, 0.72, 0.78))
		else:
			draw_rect(pic, Color(0.1, 0.12, 0.25))
		draw_rect(pic, Color(1, 1, 1, 0.12), false, 1.0)
		var y := pic.end.y + 44.0
		draw_string(UiTheme.font(UiTheme.F.TITLE), Vector2(PAD + 2.0, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40,
			UiTheme.GOLD if focused else Color.WHITE)
		if recommended:
			var f := UiTheme.font(UiTheme.F.BODY_BOLD)
			var txt := tr("EMPFOHLEN FÜR DIESEN RECHNER")
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			var badge := Rect2(size.x - tw - PAD - 26.0, y - 30.0, tw + 24.0, 32.0)
			draw_rect(badge, Color(UiTheme.GOOD, 0.18))
			draw_rect(badge, UiTheme.GOOD, false, 1.5)
			draw_string(f, Vector2(badge.position.x + 12.0, badge.position.y + 23.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiTheme.GOOD)
		draw_multiline_string(UiTheme.font(UiTheme.F.BODY_MEDIUM), Vector2(PAD + 2.0, y + 31.0), body, HORIZONTAL_ALIGNMENT_LEFT,
			size.x - PAD * 2.0 - 4.0, 20, 4, UiTheme.TEXT)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
			queue_redraw()
