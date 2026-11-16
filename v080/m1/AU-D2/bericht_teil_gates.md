## 10. Gates (je einmal, am Ende, auf Commit 2f4f260)

| Gate | Ergebnis |
|---|---|
| `tools/run_tests.sh` (alles, `XDG_DATA_HOME` unter scratch, `nice -n 19`) | **grün**: 627 Tests, 0 fehlgeschlagen, alle Integrationsprüfungen OK („Tests bestanden“, 641 s) – darin `check_music.gd` (interactive, race, arcade, quit_menu, quit_race) |
| `tools/golden.sh check` | **„GOLDEN arcade: 20 von 20 identisch“** (204 s) |
| `audio_qc.py --folders music,ui --determinism` | **grün**: 31 Klänge geprüft, 0 Fehler; jeder Generator zweimal byte-gleich (Platzhalter, Titel-Remaster, Linke Spur, Nachtfahrt, Rückenwind, Zwischenspiel, UI-Klänge); Musik 18,54 MB von 25 MB, Klänge 0,75 MB von 23 MB (50 min) |
| `check_music.py` (Noten, alle Stücke und Zusatzclips) | OK |
| Arcade spielt nichts Neues | `check_music.gd` arcade: kein ModernAudio, kein Modern-Bus, keine Datei aus `music/` oder `ui/` geladen – nach Menü, UI-Klängen, Rennkontext, Ereignissen mit `busted`/`out_of_fuel`/`stage_finish` und Zwischenspiel-Kontext; Menümusik die Titelmelodie von v0.7.0 |

Zwischendurch (vor den Gates): `run_tests.sh audio_modern` fand einen Fehler – `test_modern_audio.gd` erwartete für
`ui_move` noch den Arcade-Klang; behoben (Abschnitt 6), danach 14 von 14 und im Gesamtlauf grün.
