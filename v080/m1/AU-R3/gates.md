| Gate | Ergebnis | Beleg |
|---|---|---|
| neue Tests auf dem Stand vor dem Fix | **rot** wie verlangt (2 Damm-Tests) | `pruefung_test_vor_fix.txt` |
| Feed-Tests beim Arbeiten (`tools/run_tests.sh test_audio_feed`) | grün, 21 von 21 | – |
| `tools/run_tests.sh` (einmal, am Ende) | **grün**: „656 Tests, 0 fehlgeschlagen“, 83 CHECK-Zeilen OK, 0 FEHLER, „Tests bestanden (602 s)“ – darin `test_arcade_identity` (eingefrorene Klänge, Motor-Mischer byte-gleich zu v0.7.0) | `pruefung_run_tests.txt` |
| `check_arcade_lean` | **OK**: „0 von 35 Skripten des Modern-Klangs, des Modern-Renderers und der Modell-Datenbank geladen“ | `pruefung_run_tests.txt` |
| `tools/golden.sh check` (einmal) | **grün**: „GOLDEN arcade: 20 von 20 identisch (177 s)“ | `pruefung_golden.txt` |
| eingefrorene Arcade-Dateien = v0.7.0 | **0 geänderte Zeilen** (`git diff v0.7.0..HEAD` über alle Pfade von Regel 1) | – |
| keine Klangdatei geändert | `git diff --stat 3600eb7..HEAD`: 4 Dateien – `audio_feed.gd` (+116/−9), `test_audio_feed.gd` (+148), `docs/audio-modern.md` (+92/−17), `config/game_config.json` (1 Zeile: Beschreibung von `cobble_share`); **0 Dateien unter `assets/` und `tools/audio/`** – darum kein `audio_qc` | – |
| Kiel – Hamburg unverändert | deterministisch 0 von 9 500 Schritten verschieden; Triggerlog gleich | `pruefung_kiel_hamburg_venedig.txt` |

Die volle Testreihe lief auf `85e138a` mit der Wortkorrektur der Doku von `b6339ad` (nur `docs/`); der Golden-Lauf auf
`b6339ad`. Die Maschine war von anderen Paketen belastet (A/B-Clip des Renderers, Bilder von AS4R); alle eigenen
schweren Läufe einzeln mit `nice -n 19`.
