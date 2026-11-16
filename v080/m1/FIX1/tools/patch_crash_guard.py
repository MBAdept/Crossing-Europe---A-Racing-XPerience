import sys
wt = sys.argv[1]
p = wt + '/scripts/core/settings.gd'
s = open(p, encoding='utf-8').read()
pairs = [
('''## Crash guard: removes the marker – Modern has drawn for a while (race session), the stage fell back to Arcade or
## left in an orderly way, or the player answered the question on the title. lift = also forget the marker of the
## last run (Modern may be used again in this run); false leaves effective_graphics() as it is.
func disarm_crash_guard(lift: bool = true) -> void:
	if FileAccess.file_exists(marker_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(marker_path))
	if lift:
		crash_guard = false''',
 '''## Crash guard: removes the marker – Modern has drawn for a while (race session), the stage fell back to Arcade or
## left in an orderly way, or the player answered the question on the title. lift = also forget the marker of the
## last run (Modern may be used again in this run) and the strikes before it (crash_strikes()); false leaves
## effective_graphics() and the strikes as they are.
func disarm_crash_guard(lift: bool = true) -> void:
	if FileAccess.file_exists(marker_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(marker_path))
	if lift:
		crash_guard = false
		var sp := strikes_path()
		if FileAccess.file_exists(sp):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))


## FIX1 (QA QS-04): how many starts in a row found the marker of an unfinished Modern run, this one included – without
## a Modern stage that ran properly in between. A SIGTERM (Steam's "Exit game", a log-out) while a Modern stage loads
## ends the game without any cleanup and leaves the marker like a crash does; the title therefore stores "Arcade" only
## at the second strike in a row and lets the first one keep the choice (this start runs in Arcade all the same).
func crash_strikes() -> int:
	var n := 0
	var sp := strikes_path()
	if FileAccess.file_exists(sp):
		n = maxi(0, FileAccess.get_file_as_string(sp).strip_edges().to_int())
	return n + (1 if crash_guard else 0)


## The player stays in Arcade for this start after a strike (crash_strikes()): remember it for the next marker.
func note_crash_strike() -> void:
	var f := FileAccess.open(strikes_path(), FileAccess.WRITE)
	if f != null:
		f.store_line(str(crash_strikes()))
		f.close()


## File of the strike count, next to the marker.
func strikes_path() -> String:
	return marker_path.get_basename() + ".strikes"'''),
]
for old, new in pairs:
    assert s.count(old) == 1, old[:80]
    s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)

p = wt + '/scripts/ui/screens/title_screen.gd'
s = open(p, encoding='utf-8').read()
pairs = [
('''## v0.8.0, crash guard of the mode "Modern" (docs/grafik-modi.md): when the last start in Modern did not end properly
## (Settings.crash_guard – this start runs in Arcade, reason "crash_guard"), the title asks once: „Bei Arcade
## bleiben“ (focused, also B) or „Modern noch einmal versuchen“. Debug (sample screens): --sample-crash-guard.''',
 '''## v0.8.0, crash guard of the mode "Modern" (docs/grafik-modi.md): when the last start in Modern did not end properly
## (Settings.crash_guard – this start runs in Arcade, reason "crash_guard"), the title asks once: „Bei Arcade
## bleiben“ (focused, also B) or „Modern noch einmal versuchen“. „Bei Arcade bleiben“ stores Arcade only when it
## happened twice in a row (Settings.crash_strikes(); FIX1, QA QS-04: quitting through Steam while a Modern stage loads
## leaves the same marker); the first time this start stays Arcade and the next one tries Modern again.
## Debug (sample screens): --sample-crash-guard.'''),
('''	confirm_box = ConfirmBox.new(tr("Der Modus „Modern“ wurde beim letzten Start nicht richtig beendet."),
		tr("Vielleicht ist das Spiel dabei abgestürzt oder hängen geblieben. Dieser Start läuft deshalb im Modus „Arcade“."),
		tr("Modern noch einmal versuchen"), tr("Bei Arcade bleiben"))''',
 '''	var body := tr("Vielleicht ist das Spiel dabei abgestürzt oder hängen geblieben. Dieser Start läuft deshalb im Modus „Arcade“, der nächste versucht „Modern“ wieder.")
	if int(Settings.crash_strikes()) >= 2:
		body = tr("Das ist schon zum zweiten Mal passiert. „Bei Arcade bleiben“ stellt die Grafik auf „Arcade“ um – „Modern“ lässt sich in den Optionen wieder wählen.")
	confirm_box = ConfirmBox.new(tr("Der Modus „Modern“ wurde beim letzten Start nicht richtig beendet."), body,
		tr("Modern noch einmal versuchen"), tr("Bei Arcade bleiben"))'''),
('''func _on_crash_guard_answer(try_modern: bool) -> void:
	if not GameFlow.sample_mode:
		if not try_modern:
			Settings.graphics_mode = Gfx.ARCADE   # stored from now on; "Klang: Wie Grafik" follows
		Settings.disarm_crash_guard()             # the marker goes; with "Modern" the next stage runs in Modern
		Settings.save_if_changed()''',
 '''func _on_crash_guard_answer(try_modern: bool) -> void:
	if not GameFlow.sample_mode:
		if try_modern:
			Settings.disarm_crash_guard()          # the marker goes; the next stage runs in Modern
		elif int(Settings.crash_strikes()) >= 2:
			Settings.graphics_mode = Gfx.ARCADE    # the second time in a row: stored from now on ("Klang: Wie Grafik" follows)
			Settings.disarm_crash_guard()
		else:
			Settings.note_crash_strike()           # the first time: this start stays Arcade, the next one tries Modern
			Settings.disarm_crash_guard(false)
		Settings.save_if_changed()'''),
]
for old, new in pairs:
    assert s.count(old) == 1, old[:80]
    s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)
print('ok')
