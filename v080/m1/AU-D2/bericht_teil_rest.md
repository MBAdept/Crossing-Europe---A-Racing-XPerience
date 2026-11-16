## 6. Abweichungen vom Vertrag und vom Auftrag

- **Tempi**: geplant waren 112 / 144 / 96 bpm (Nachtfahrt, Rückenwind, Zwischenspiel), geliefert 105 / 150 / 100 bpm –
  nur diese Tempi geben eine exakte Schleife (Entscheidung 6, Falle 14.13.12).
- **Stinger „Etappenziel“, „Rekord“, „Meisterschaft“** sind keine Einzelklänge über der laufenden Musik, sondern
  der Ziel-Schlag (Einzelklang) plus drei Schluss-Varianten im `AudioStreamInteractive` (Entscheidung 3); ohne
  laufendes Stück sind die Varianten selbst die Einzelklänge. „Erwischt“ und „Tank leer“ sind Einzelklänge über dem
  um 9 dB abgesenkten Stück, wie verlangt.
- **Der Jingle „finish“ entfällt im Profil Modern** (der Director beansprucht `stage_finish`, Entscheidung 2).
- **Ergebnisbildschirm**: spielt das Zwischenspiel statt des Titel-Remasters, und erst nachdem der Schluss
  ausgeklungen ist (bis zu 10 s; Entscheidung 4, 7).
- **UI-Klänge `ui_tab`, `ui_toggle`, `ui_error`** sind gebaut, aber nicht verdrahtet: Die UI ruft heute nur
  `ui_move`, `ui_ok`, `ui_back`; die Dateien unter `scripts/ui/` gehören in diesem Schub UI1 (Vertrag A-8).
- **Fünf Testdateien von AU-A/AU-D1 angepasst**, deren Erwartungen das alte Verhalten festschrieben:
  `test_modern_audio.gd` (nach dem Ziel klingt der Schluss erst aus; `ui_move` kommt jetzt aus der Modern-Datei –
  den Rückfall auf den Arcade-Klang prüft der Test an `flash`, solange es dafür keine Modern-Datei gibt),
  `test_modern_assets.gd` (der Ordner `ui` hat mehr als den Platzhalter), `check_modern_audio.gd` (Zielklang: der
  Jingle oder – beansprucht – der Schluss), `test_music_director.gd` und `check_music.gd` (neue Stücke, Rotation,
  Varianten, Stinger, Zwischenspiel, Arcade).
- **`linke_spur.py` und `title_remaster.py` geändert** (gemeinsame Mischung, Zusatzclips): Hauptdatei und Schluss von
  „Linke Spur“ und das Titel-Remaster sind bitgleich geblieben (gemessen).

## 7. Vertragspunkte (contract issues)

1. D30 und der Auftrag verlangen Stinger als Einzelklänge „ducking the running music“ auch für Ziel, Rekord und
   Meisterschaft – im Ziel spielt aber das Rennstück schon seinen taktgenauen Schluss (AU-D1, D30); zwei Musiken
   übereinander passen weder zeitlich noch harmonisch. Gelöst mit Varianten des Schlusses (Entscheidung 3).
2. Der Vertrag (§6 Welle 6) gibt AU-D2 `assets/audio/modern/sfx/**`, der Auftrag verbietet es (gehört AU-C1). Die
   Stinger liegen deshalb im Ordner `music/` (Ogg, Rolle `race_ziel`/`race_ending`/`race_stinger`).
3. Die UI-Namen `ui_tab`, `ui_toggle`, `ui_error` brauchen Aufrufe in `scripts/ui/**` (UI1/UI2) und – für einen
   Arcade-Ersatz – Einträge in `SfxBank.ROUTES` / `AudioManager.ONESHOT_DB` (AU-E); beides außerhalb von AU-D2.
4. `audio_qc.py --determinism` läuft immer alle Generatoren eines Ordners (gemessen: 50 min für `music,ui`, davon
   39 min zweimal rendern); ein Filter je Generator fehlt (Werkzeug von AU-A).
5. Die QC-Grenze „Musik −14 ± 1 LUFS“ passt nicht auf Schlüsse und Stinger (sie tragen den Pegel ihres Stücks); sie
   haben eigene Grenzen im Manifest (`qc.lufs`), wie schon der Schluss von AU-D1.

## 8. Für die nächsten Pakete

- **UI2**: `UiKit.sound("ui/ui_tab")` beim Reiterwechsel der Optionen (LB/RB), `"ui/ui_toggle"` beim Ändern eines
  Werts (`option_row.gd`), `"ui/ui_error"` wo eine Eingabe nicht geht; für Arcade weiter `ui_move`/`ui_back`.
- **AU-E**: Stinger und Ziel-Schlag im Rennen mit der ganzen Kette messen (`capture_mix.gd`), die Absenkung
  (`sting_duck_db`, `sting_release_s`) gegebenenfalls in `audio.modern.music` setzen; eine ganze Etappe bis ins Ziel
  je Profil aufnehmen (Ziel-Schlag, Schluss-Variante, Ausklingen in den Ergebnisbildschirm).
- **Nutzerurteil**: Bass und Pegel ändert man in `tools/audio/music/mischung.json`, dann
  `python3 tools/audio/music/render_all.py` und `godot --headless --import` (etwa 25 Minuten). Bei diesem Lauf in
  `linke_spur.py` auch `race_lib.phrase_end()` auf die weiche Lead-Stimme anwenden (das Knacken, Doku 14.14) – die
  Bitgleichheit mit den Hörproben von AU-D1 zählt nach dem Urteil nicht mehr.
- **Stücke 4–5** (nur wenn alles andere fertig ist): eine neue Partitur-Datei nach dem Muster von `nachtfahrt.py`;
  Tempo nach `race_lib.check_tempo()`.
