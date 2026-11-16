## 5. Robustheit

### 5.1 Rückfall auf Arcade (Vertrag D34, §4.4.2)

Echter Start über `GameFlow --stage=kiel_hamburg --autopilot` unter Xvfb, Bilder bei 2 s und 6 s (`bin/fallback.sh`,
Ordner `fallback/`, gemessen):

| Fall | Ergebnis |
|---|---|
| `--gfx-debug=fail` | Arcade-Bild, HUD-Meldung wörtlich wie im Vertrag („Der Modus „Modern“ lässt sich mit dieser Grafik nicht starten. Das Spiel läuft im Modus „Arcade“ weiter.“), Log `selftest:debug`, kein Absturz-Marker übrig – `fallback/fail_00.png` |
| `manifest.json` fehlt | dasselbe mit Grund `manifest`, kein Marker – `fallback/nomanifest_00.png` |
| `manifest.json` abgeschnitten (kaputtes JSON) | ein `ERROR: Parse JSON failed` im Log (so gewollt: „ein kaputtes ist ein Fehler im Log“), dann Rückfall `manifest`, kein Marker |
| Ergebnisbildschirm nach Rückfall (Beispieldaten) | Hinweiszeile „Diese Etappe lief im Modus „Arcade“: „Modern“ ließ sich auf diesem Rechner nicht starten.“ – sitzt knapp unter dem Rahmen der linken Tafel (`fallback/result_note_00.png`) |
| Leistungstest mit `--gfx-debug=fail` | endet sofort, schreibt `leistungstest.json` mit `"fallback": "selftest:debug"`, ohne Szenen, Vorschlag Arcade, Exit-Code 1 (so dokumentiert) |

Danach Manifest byte-gleich zurückgelegt, Arbeitsbaum sauber.

### 5.2 Erster Start, Beenden und Neustart

Echtes Spiel unter Xvfb, Tastatur über `xdotool` (`bin/quit_restart.sh`, `bin/quit_title.sh`, Bilder in `quit/`,
gemessen):

- **Auswahl genau einmal**: Start **ohne jedes Argument** in einem leeren Benutzerordner → „GRAFIK WÄHLEN“
  (`q1a_chooser.png`); Prozess beendet ohne Wahl → beim nächsten Start wieder die Auswahl (richtig: nichts gewählt);
  ▶ + Enter → Titel, `graphics_mode: "modern"` sofort gespeichert; Neustart ohne Argument → **direkt der Titel**
  (`q1_bc.png`).
- **Beenden über das Spiel** (Titel → „Beenden“ → Frage → „Beenden“), je zweimal mit gespeichertem Modus Modern
  (Modern-Klang, Titel-Remaster läuft) und Arcade: **4 von 4 mit Exit-Code 0, keine „leaked“-, „still in use“- oder
  Fehlerzeile** (`quit/qt_*.log`, Bild der Frage `qt_modern_pair.png`).
- **Fenster schließen**: ein `WM_DELETE_WINDOW` per `XSendEvent` ohne Fenstermanager nimmt Godot hier nicht an –
  **v0.7.0 genauso** (`bin/xclose_debug.sh`); dieser Weg (X-Knopf, Alt+F4) ließ sich hier nicht nachstellen. Die
  Fälle liefen deshalb als harter Abbruch (`kill -9`) – das ist die Probe für den Absturz-Wächter:
  - Abbruch während eine Modern-Etappe lädt (Last 13 auf 4 Kernen: auch nach 30 s noch das Ladebild mit Balken
    ≈ 65 %, `q3_driving.png`) → Marker bleibt → Neustart ohne Argument zeigt die Absturz-Frage, der Start läuft in
    Arcade (`q3_loading_pair.png`). Richtig.
  - Optionen mit ungespeicherter Änderung und Abbruch → Änderung verloren (bei einem Abbruch erwartet; beim Schließen
    speichert `Settings` über `NOTIFICATION_WM_CLOSE_REQUEST`, Code gelesen).
  - Fahrzeugwahl mit erzwungenem 3D-Showroom, laufender Leistungstest: Abbruch hinterlässt keinen Marker und keine
    `leistungstest.json` („Ein Abbruch schreibt nichts“).
- **`SIGTERM` während eine Modern-Etappe lädt** (so beenden Steam „Spiel beenden“ und das Abmelden unter Linux –
  abgeleitet): Godot beendet sich mit **143** ohne Aufräumen, der Marker bleibt, und der nächste Start meldet
  „Der Modus „Modern“ wurde beim letzten Start nicht richtig beendet … Vielleicht ist das Spiel dabei abgestürzt“ und
  läuft in Arcade; die vorausgewählte Antwort „Bei Arcade bleiben“ **speichert Arcade dauerhaft**
  (`q3_sigterm_restart.png`). Siehe Befund QS-04.

### 5.3 20 Minuten Modern

`bin/soak.sh`: `tests/race/run_race.gd` durch den echten `GameFlow` (Rennen Kiel–Nürnberg, Autopilot), Xvfb,
**Modern-Bild + Modern-Klang** (Motor-Thread, Rennmusik), Voreinstellung Mittel (mit Schatten), Zeitraffer 1,
1 233 s Wanduhr (gemessen):

- **Log: keine einzige Fehler-, Skript- oder „Too many instances“-Zeile**; einzige Warnung die übliche „Could not set
  V-Sync mode“ des Software-Treibers. Ende durch mein Zeitlimit (`FEHLER: Zeitlimit überschritten im Zustand racing`).
- Bei Last 10–14 auf 4 Kernen lief die Simulation langsamer als die Uhr (Physik höchstens 8 Schritte je Bild): Kiel–Hamburg
  war nach 20 min noch nicht im Ziel – Etappenwechsel und Ergebnisbildschirm kamen in diesem Lauf also **nicht** vor
  (die liefen kopflos im Meisterschaftslauf, Abschnitt 2, viermal fehlerfrei).
- Speicher des Prozesses (RSS, alle 20 s): 1 526 MB → 1 586 MB in 16 min (+4 %, Kurve mit Auf und Ab: 1 573 → 1 552 →
  1 587), 23 Threads und 8 Dateideskriptoren konstant – kein Hinweis auf ein Leck, für eine Aussage über Stunden zu kurz
  (`soak/rss_godot.tsv`).

### 5.4 Leistungstest `--bench=all`

`bin/bench.sh` (Xvfb, Voreinstellung dieses Rechners „Niedrig“, gemessen; Ordner `bench/`): läuft durch (146 s, Exit 0),
schreibt `user://leistungstest.json` und `--bench-out` **identisch**, Format nach Vertrag §4.8 vollständig (alle
Pflichtschlüssel, Version 1, je Szene id/avg/1 %-low/p95/p99/Skript/Aufrufe/Dreiecke, `suggested_preset`; dazu die
Zusatzfelder), Prüfskript `bin/bench_check.py`: **FORMAT OK**. Urteil auf llvmpipe: „too_slow“ → Vorschlag Arcade
(richtig für Software-Grafik). Zahlen (gemessen bei Last 13 auf 4 Kernen, für eine echte Grafikkarte bedeutungslos):

| Szene | Ø fps | 1 % niedrig | p95 / p99 ms | `render()` ms | Aufrufe | Dreiecke | Vorbereitung |
|---|---|---|---|---|---|---|---|
| Autobahn bei Tag | 4,1 | 1,2 | 312 / 801 | 2,10 | 129 | 89 258 | 42,1 s (kalter Shader-Cache) |
| Stadt bei Nacht im Regen | 0,9 | 0,6 | 1 555 / 1 555 | 7,10 | 67 | 26 900 | 18,6 s |
| Bergstrecke mit Tunnel | 2,5 | 1,5 | 610 / 689 | 2,39 | 56 | 19 989 | 14,5 s |

Hinweis für den Testbuild (abgeleitet): In M1 fehlen in Modern Wetter, Stadtgebäude und Tunnelbauwerke noch (M2) –
die Szenen „Stadt bei Nacht im Regen“ und „Bergstrecke mit Tunnel“ messen deshalb weniger, als sie später kosten; die
Zahlen, die der Nutzer vom Steam Deck zurückschickt, sind für diese Szenen zu günstig. Die Datei trägt
`"game_version": "0.7.0"` (Befund QS-05).

### 5.5 Render-Prüfungen der Systemlinse (`tools/run_render_checks.sh`, Xvfb)

`bin/render_subset.sh`, gemessen – **alle grün**:

| Datei | Ergebnis |
|---|---|
| `check_quit_sound.gd` | Beenden über `GameFlow.quit_game()` je 3 Starts mit Klang Arcade und Modern: kein „leaked at exit“ |
| `check_seam_render.gd` | Selbsttest (Kugel 0,87, Hintergrund 0,00, Shaderfläche 0,09/0,80/0,30; 1 223 ms beim ersten Mal), gleiche Simulationsschritte zur gleichen Aufnahmezeit in beiden Modi, Rückfall-Bild = Arcade-Bild bis auf die Meldung (0 px), **Arcade – Modern – Arcade im selben Prozess: 0 Pixel verschieden**, 16:10-Fenster ohne Balken in Modern / mit Balken in Arcade |
| `check_session_modern.gd` | Pause: 30 Bilder, 0 Bildpunkte verschieden; `--gfx-debug=fail` → `gfx_fallback selftest:debug`, Etappe läuft; danach Arcade: 0 Netze, 0 Texturen, Materialien freigegeben |
| `check_showroom_render.gd` | physische Pixel 660 × 400 bzw. 990 × 600 (Streckfaktor 1,5), durchsichtig, nicht angeschnitten, dreht |
| `check_instance_budget.gd` | 100 s Verkehr bei 6-facher Zeit: keine Ablehnung des globalen Shader-Puffers, Fahrzeug-Ebene ≤ 128 Instanzen |
| Arcade: `check_glow_occlusion.gd`, `check_sprite_flip.gd` | 16/16 und OK |

### 5.6 Builds und Größen (`tools/build_linux.sh`, `tools/build_windows.sh`, `tools/pck_report.py`)

Beide Exporte aus diesem Baum gebaut (gemessen, `build_linux.log`, `build_windows.log`): Linux 36 s, Windows 87 s, beide
Exit 0; Windows-Icon und Versionsressource geprüft (`FileVersion 0.7.0.0` – QS-05).

| Teil (Windows-Archiv) | Dateien | roh MB | im Archiv MB | Budget MB |
|---|---|---|---|---|
| Programm (Godot-Vorlage) | 1 | 109,30 | 37,95 | 38,0 |
| Arcade-Sprites | 375 | 305,22 | 71,07 | 71,0 (unverändert) |
| Arcade-Klang und -Musik | 31 | 15,75 | 14,72 | 14,7 (unverändert) |
| UI, Schriften, Skripte, Daten | 378 | 4,19 | 3,72 | 5,0 |
| Modern: Modelle | 98 | 4,83 | 4,64 | 40,0 |
| Modern: Texturen | 60 | 16,72 | 5,59 | 60,0 |
| Modern: Klang | 52 | 12,63 | 11,14 | 23,0 |
| Modern: Musik | 9 | 7,68 | 7,54 | 25,0 |
| **Summe** | 1 004 | 476,31 | 156,36 | 277,0 |

**Zip gemessen: 156,5 MB** (Warnung > 300, Abbruch > 330, Grenze 350) – in Ordnung. Linux-Programm 440,6 MB, Archiv
geschätzt 146,7 MB. Mit ausgeliefert werden je Klangordner ein Platzhalter (6 Dateien, zusammen < 0,3 MB) und die
`model.json`-Bruchstücke – vernachlässigbar.

### 5.7 Windows-Build unter Wine

`bin/wine.sh` (wine64, eigenes Präfix, Xvfb, `-- --stage=kiel_hamburg --autopilot --gfx-preset=medium`, gemessen):

- **Arcade** (`--graphics=arcade --sound=arcade`): startet, fährt, Bilder bei 6 s und 14 s, Exit 0 nach 29 s.
- **Modern** (`--graphics=modern --sound=modern`): startet, bereitet vor, fährt (Modern-Bild, Modern-Klang laut Log),
  Bilder bei 6 s und 14 s, Exit 0 nach 159 s; kein Rückfall, keine Fehlerzeile.
- Gleiche Aufnahmezeit, gleicher Simulationszustand in beiden Modi (km 0,3 / 59 km/h und km 2,9 / 168–170 km/h) –
  `windows_wine_arcade_oben_modern_unten.png`.
- Leistungstest-Szene „autobahn“ (8 s) unter Wine: `win_bench.json` **FORMAT OK** (5,0 fps auf llvmpipe, Vorschlag
  Arcade).
- Nicht prüfbar hier: ANGLE/Direct3D und echte Windows-Treiber (abgeleitet; Nutzertest am Gate).

