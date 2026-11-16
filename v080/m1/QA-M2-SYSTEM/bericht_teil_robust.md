## 5. Robustheit

**Rückfall auf Arcade** (`bin/fallback.sh`: echtes Spiel über `GameFlow -- --stage=kiel_hamburg --graphics=modern`,
Xvfb 1280 × 720, Bilder 2 s und 8 s nach dem Start; Manifest und Netzdatei nur in der Prüfkopie verändert und danach
wiederhergestellt, `= Arbeitsbaum` geprüft):

| Fall | Ergebnis (gemessen) |
|---|---|
| `--gfx-debug=fail` | Etappe läuft in **Arcade**, Hinweis im Bild, Log `Modus Modern nicht möglich (selftest:debug)`, kein Startmarker zurückgelassen, Exit 0 |
| `assets/models/manifest.json` fehlt | Arcade, `Vorbereitung abgebrochen (manifest)`, Hinweis im Bild (`rueckfall_manifest_fehlt_2s.png`), kein Marker |
| Manifest abgeschnitten (kaputtes JSON) | `Parse JSON failed … Unterminated string` (eine Fehlerzeile der Engine), dann derselbe Rückfall `manifest` |
| eine Netzdatei des Spielerautos fehlt (`player/limousine/lod0_body.res`) | `Vorbereitung abgebrochen (manifest)`, Arcade, Hinweis (`rueckfall_modelldatei_fehlt_8s.png`) |

Der Hinweis lautet in allen Fällen wörtlich wie §4.4.2: „Der Modus „Modern“ lässt sich mit dieser Grafik nicht
starten. Das Spiel läuft im Modus „Arcade“ weiter.“ – auch wenn nicht die Grafik, sondern Spieldateien fehlen
(Vertragsfrage V-3).

**Leistungstest** (`--bench=all`, Xvfb, llvmpipe auf 4 Kernen bei Last 22, `bin/bench.sh`): Exit 0 nach 191 s;
`user://leistungstest.json` geschrieben und gleich `--bench-out`; `bin/bench_check.py`: **FORMAT OK** (alle Pflichtfelder,
drei Szenen). Gemessen: Autobahn bei Tag 3,1 fps (1 %-Tief 1,1; p95 648 ms; Skript 3,49 ms; 132 Aufrufe; 109 864
Dreiecke; Vorbereitung 65 s kalt), Stadt bei Nacht im Regen 1,5 fps (Skript 5,56 ms; 81 Aufrufe), Bergstrecke mit Tunnel
3,4 fps (Skript 3,04 ms; 69 Aufrufe); Urteil `too_slow`, Vorschlag **Arcade** – richtig für Software-Grafik. Mit
`--gfx-debug=fail`: Exit 1 (dokumentiert), Datei mit `fallback: selftest:debug`, 0 Szenen, Vorschlag Arcade.

**Fenster schließen.** `WM_DELETE_WINDOW` (per `XSendEvent`, ohne Fenstermanager, `bin/xclose.py`) nimmt Godot auf
dem nackten Xvfb nicht an (`WM_PROTOCOLS` des Fensters ohne `WM_DELETE_WINDOW`) – in v0.7.0 genauso (M1). Alle
Beenden-Fälle unten laufen darum über **SIGTERM** (wie Steams „Spiel beenden“); das Schließen über das Menü prüft
`check_quit_sound` (3 Starts, kein „leaked“, Abschnitt 6).

⟨QUIT⟩

⟨SOAK⟩

⟨BUILDS⟩
