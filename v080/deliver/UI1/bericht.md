# UI1 – Optionen, Auswahl, Showroom, Ladebild, Leistungstest (Bericht)

Paket UI1 von v0.8.0 (Push M1, Vertrag §6 Welle 2 „UI1“, D31–D36, §4.1, §4.2, §4.8, A-2, A-5, A-8).
Zweig `worktree-wf_9693abb2-cee-2` (Sicherung `origin/wip/v080-ui1`), Arbeitsbaum
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9693abb2-cee-2`.
Dieser Lauf ist der Nachfolger eines Vorgängers, der durch das Nutzungslimit angehalten wurde; dessen zwei Commits
(49a8ff7, d46a06b – der zweite vom Lead aus den unfertigen Dateien) sind geprüft und die Grundlage. AS1 (53bcc1b)
und AU-B (8414002) sind wie verlangt früh gemergt.

Alle Zahlen „gemessen“ = auf dieser VM (llvmpipe unter Xvfb oder headless, 4 geteilte Kerne). Alles über einen
Steam Deck, eine echte Grafikkarte, ANGLE/Windows oder wie etwas klingt, ist „abgeleitet“ – nicht messbar hier.

## Was fertig ist

| Teil | Dateien | Stand |
|---|---|---|
| Gfx: Wächter gegen max(Bildzeit, 1/60 s) (A-2), Bedingung der Auswahl (D32), Statistik und Vorschlag des Leistungstests | `scripts/core/gfx.gd` | fertig, Unit-Tests |
| Settings: `stored_quality`, `choose_preset`, `set_quality_value` (ein `quality_changed` je Änderung), `needs_graphics_choice` | `scripts/core/settings.gd` | fertig, Hin und Zurück jeder Option getestet |
| Optionen in zwei Seiten ALLGEMEIN / GRAFIK, LB/RB, Klang, Musik im Rennen, Qualität, Vorschau, Status | `scripts/ui/screens/options_screen.gd` | fertig, 10/10 mit echten Pad-Ereignissen |
| Auswahl „GRAFIK WÄHLEN“ (einmal, D32), ein A übernimmt, Empfehlung, Warnungen | `scripts/ui/screens/graphics_choice_screen.gd`, `game_flow.gd` | fertig |
| Klangprofil: `set_profile` beim Start und bei Änderung (nie in einer Etappe), `set_music_context`, `set_race_music` | `scripts/ui/game_flow.gd`, `options_screen.gd` | fertig; im laufenden Spiel umgeschaltet (Log der Optionsprüfung: „ModernAudio: Profil „Modern“ gestartet“) – gehört hat es hier niemand |
| Absturz-Frage auf dem Titel | `scripts/ui/screens/title_screen.gd` | fertig |
| `gfx` / `gfx_fallback` in Bestenlisten-Einträgen, Hinweis nach Rückfall, Modus je Etappe im Rennstand | `result_screen.gd`, `race_result_screen.gd`, `race_state.gd` | fertig |
| `LoadingOverlay.set_progress(p)` | `scripts/ui/widgets/loading_overlay.gd` | fertig (die Sitzung ruft es schon) |
| Attract-Demos im wirksamen Modus, 30 s ab `stage_live` | `scripts/ui/attract_mode.gd`, `widgets/attract_overlay.gd` | fertig, geprüft mit langsam vorbereitendem Renderer |
| 3D-Showroom (Showroom3D in CarShowcase) | `scripts/ui/widgets/showroom_3d.gd`, `car_showcase.gd` | fertig; heute für kein Auto aktiv (Manifest), erzwingbar |
| Leistungstest: Läufer `ModernBenchmark`, Seiten, Leiste, `--bench`, `--bench-out` | `scripts/race3d/benchmark.gd`, `screens/benchmark_screen.gd`, `widgets/bench_overlay.gd`, `game_flow.gd` | fertig, läuft mit dem Gerüst-Renderer und fällt sauber zurück |
| Vorschaubilder der beiden Modi | `tools/gfx_previews.sh`, `tools/gfx_previews.gd`, `assets/ui/gfx_preview_*.webp` | Werkzeug fertig; **Modern-Bild zeigt das Gerüst – neu erzeugen** |
| Doku | `docs/grafik-modi.md` (neu), `docs/ui.md` | fertig |

## Prüfungen und Ergebnisse

| Prüfung | Ergebnis |
|---|---|
| `tests/race/check_options_tabs.gd -- --graphics=arcade` (echte Pad-Ereignisse) | **10 von 10** (gemessen) |
| `tests/race/check_menu_pad.gd -- --graphics=arcade` | **9 von 9**, unverändert |
| `tests/unit/ui/test_steam_deck.gd`, `test_menu_input.gd` | grün, unverändert |
| `tests/unit/core/test_gfx_ui.gd` (neu, 12 Tests) | grün: Auswahl-Matrix 120 Fälle (6 fällig), Wächter bei 120/144 Hz, Statistik, Vorschlag, Angebote, Voreinstellung/Einzelwerte, Hin und Zurück 96 Kombinationen, `gfx` der Einträge |
| `tests/unit/ui/test_showroom.gd` (neu, 5 Tests) | grün: Fixture-Manifest, erzwungene Limousine, physische Pixel, Bildausschnitt, keine 3D-Klasse in CarShowcase |
| `tests/race3d/check_benchmark.gd` (neu, Haken) | **8 von 8** |
| `tests/race3d/check_showroom.gd` (neu, Haken) | **7 von 7** |
| `tests/race3d/check_attract_modern.gd` (neu, Haken) | **4 von 4**: Vorbereitung 1,18 s, Demo ab `stage_live` 2,10 s bei demo_s 2 (gemessen) |
| `tests/race/check_attract.gd` | **13/13 mit `--graphics=arcade`**, **13/13 mit `--graphics=modern`** |
| `tests/race/check_attract_scenes.gd -- --graphics=modern` | **7 von 7** (ohne Änderung) |
| `tests/race3d/render/check_showroom_render.gd` (neu, Xvfb, `tools/run_render_checks.sh modern showroom`) | **6 von 6**: SubViewport 660 × 400 beim Streckfaktor 1,0 und 990 × 600 bei 1,5 (gemessen), Bild um das Auto durchsichtig, nichts angeschnitten, Drehteller dreht |
| `tools/run_tests.sh` (ganz), Lauf 1 auf 326ac1d | **bestanden, 669 s** (gemessen): 612 Unit-Tests, 0 fehlgeschlagen; Integrationsszenarien, Attract, Gamepad, Attract-Szenen, Polizeiflucht, alle Haken-Prüfungen OK |
| `tools/run_tests.sh` (ganz), Lauf 2 auf dem Endstand | **bestanden, 616 s** (gemessen, auf 940f44b = Endstand des Codes; danach nur noch eine Doku-Änderung): 612 Unit-Tests, 0 fehlgeschlagen |
| `tools/golden.sh check` (Endstand 940f44b) | **GOLDEN arcade: 20 von 20 identisch** (200 s, gemessen) |

Leistungstest mit dem Gerüst-Renderer (gemessen, nur als Funktionsnachweis – die Zahlen sagen nichts über die
fertige Grafik oder eine echte Grafikkarte): headless 3 Szenen à 0,4 s komplett, Datei und `--bench-out`
gleich; unter Xvfb (llvmpipe, 1280 × 720, Mittel) Autobahn 4 s: Ø 22,4 Bilder/s, 1 % niedrig 4,8, Bildzeit p95
75 ms / p99 207 ms, Skript 0,028 ms, Vorbereitung 0,6 s, Urteil „slow“ → Vorschlag „Niedrig“. Der Gerüst-Renderer
meldet keine Draw Calls (0) – die Spalte füllt sich mit dem echten Renderer (`perf_stats()` von R1).

## Bilder (Lieferordner)

`/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/UI1/screens/` – jeder neue Bildschirm in 1280 × 720 und
1280 × 800 (`_720.png`, `_800.png`):
01 Optionen ALLGEMEIN, 02 GRAFIK in Arcade (Qualität gedimmt), 03 GRAFIK in Modern, 04/05 Auswahl (Modern bzw.
Arcade empfohlen), 06–09 Leistungstest (Start, Ergebnis, langsam, Rückfall), 10 Titel mit Absturz-Frage, 11/12
Showroom Limousine/Kompakt (erzwungen), 13 Fahrzeugwahl in Modern mit Sprite (Sportwagen ohne Modell).
14 Etappenergebnis mit dem Hinweis nach einem Rückfall (nur 720, `--sample-gfx-fallback`).
Dazu `showroom_ab_limousine.png` (Sprite gegen 3D-Showroom an derselben Stelle), `showroom_1080_ausschnitt.png`
(Schärfe in physischen Pixeln, 1920 × 1080, Endstand), `leistungstest_lauf_800.png` (Leiste während des
Tests in 16:10, Gerüst-Renderer), `vorschau_paar.png` (die beiden Vorschaubilder: Arcade fertig, Modern = Gerüst).

## Ehrliches Urteil

- **Gut**: Die Optionen sind mit dem Gamepad vollständig bedienbar, die Seiten passen in 1280 × 720 und 1280 × 800,
  alle Texte ≥ 18 px. Die Auswahl ist klar (eine Karte vorgewählt, ein A). Der Leistungstest läuft durch, schreibt
  die Datei im Format von §4.8 und fällt sauber zurück. Der Showroom mit dem echten `show`-Modell der Limousine
  sieht im Menü gut aus (glänzender Lack, Felgen, Scheinwerfer an, Schatten auf dem Drehteller, Kantenlichter in
  Magenta/Cyan) und ist bei 1080p gestochen scharf; Größe und Lage entsprechen jetzt dem Sprite, die Lackfarben
  (Blau der Limousine, Goldgelb des Kompakt) denen der Cycles-Sprites (AgX statt Filmic).
- **Noch nicht gut**: Das Modern-Vorschaubild (Optionen und Auswahlkarte) zeigt heute das Gerüst des Renderers –
  Himmel und graue Ebene. Für den Testbuild des Nutzers **muss** es nach dem Zusammenführen des Renderers mit
  `tools/gfx_previews.sh` neu erzeugt werden, sonst wirbt die Karte „Modern“ mit einer grauen Fläche. Der Lack im
  Showroom ist flach (der Lack-Shader mit Klarlack kommt von R3); die Schattenseite des Autos ist recht dunkel und
  der Cyan-Rand des Drehtellers wirkt unter AgX blasser als die 2D-Plattform. Das Licht trägt den Eindruck, ersetzt
  aber keinen Lack-Shader. Die Leiste des Leistungstests und der Ablauf sind nur mit dem Gerüst-Renderer gesehen.
- **Fehlt**: Der Showroom ist für kein Auto eingeschaltet, weil das Manifest kein Set mit `showroom: true` hat (AS1
  entscheidet per A/B). Die Angebote des Wächters auf dem Ergebnisbildschirm („Qualität senken“ / „Zu Arcade
  wechseln“) sind laut Vertrag UI2. Wie der Leistungstest auf einem Steam Deck aussieht und was er dort misst, ist
  abgeleitet – erst die Datei des Nutzers zeigt es.

## Abweichungen vom Vertrag und vom Auftrag

- **Eintrag eines Rennens**: `gfx` = `"arcade"`, `"modern"` oder **`"mixed"`** (D15 nennt nur die beiden Modi; ein
  Rennen, dessen Etappen in verschiedenen Modi liefen, hat keinen der beiden). Stände von vor v0.8.0 zählen als Arcade.
- **„gfx … onto the result screens“** (Auftrag) gegen D15 („nie angezeigt“): Der Modus wird nicht angezeigt; nur nach
  einem Rückfall steht eine Zeile unter dem Etappenergebnis. Die Rangliste bleibt unverändert.
- **Zusätzliche Schalter**: `--bench-seconds` (Tests), `--showroom-force[=ids]`, `--showroom-still`,
  `--sample-crash-guard`, `--sample-gfx-fallback`, `--options-tab=grafik`, `--recommend`, `--existing-player`,
  `--bench-sample` (nur Beispielbildschirme bzw. Tests).
- **Neue Prüfdateien** außerhalb der Liste des Auftrags: `tests/unit/core/test_gfx_ui.gd` (statt Änderungen an der
  Testdatei von KERN), `tests/race3d/check_{benchmark,showroom,attract_modern}.gd`,
  `tests/race3d/render/check_showroom_render.gd`; erweitert: `tests/race/check_attract.gd` (wie verlangt).
- **Showroom-Tonemapper AgX** (eigene Welt, nicht das Rennen – D6 gilt für Modern-Rennszenen): Mit Filmic und Linear
  kippte das Gelb des Kompakt ins Zitronengelbe.
- **Leistungstest-Ergebnis**: Das Feld `written` steht nicht in der Datei (Status des Laufs); `refresh_hz` ist −1,
  wenn die Anzeige keine Bildwiederholrate meldet (Xvfb: NaN).

## Für den Lead / die nächsten Pakete

1. **Vorschaubilder neu erzeugen**, sobald der echte Renderer im Baum ist: `XDG_DATA_HOME=/abs tools/gfx_previews.sh`
   (schreibt `assets/ui/gfx_preview_{arcade,modern}.webp`, ≈ 1 min unter Xvfb). Heute zeigt das Modern-Bild das Gerüst.
2. **`tools/run_tests.sh` einhängen** (Besitz: Integration): `tests/race/check_options_tabs.gd -- --graphics=arcade`
   (≈ 2 s) in die Liste der Ganzspiel-Prüfungen; `check_attract.gd` und `check_attract_scenes.gd` zusätzlich mit
   `-- --graphics=modern` (≈ 30 s + 25 s). Die neuen `tests/race3d/check_*.gd` nimmt der Haken schon mit
   (+≈ 12 s, gemessen), die Render-Prüfung `run_render_checks.sh modern`.
3. **Showroom einschalten**: Sobald AS1R `showroom: true` für `showroom/limousine` und `showroom/kompakt` setzt, zeigt
   die Fahrzeugwahl in Modern das 3D-Modell – ohne Codeänderung. Der Lack-Shader von R3 macht den Lack weniger flach;
   danach Licht und Belichtung des Showrooms (`showroom_3d.gd`, `_build_world`) noch einmal ansehen.
4. **Leistungstest auf echter Hardware**: Steam Deck und Windows (`Optionen → Grafik → Leistungstest`, Datei
   `leistungstest.json`); mit dem echten Renderer füllen sich Draw Calls/Dreiecke aus `perf_stats()` – der Läufer
   erwartet dort `render_ms_avg`/`frames` (Skriptzeit des Fensters), `draw_calls(_shadow)`, `primitives(_shadow)`.
5. **UI2**: Angebote des Wächters auf dem Ergebnisbildschirm („Qualität senken“ / „Zu Arcade wechseln“) und die
   HUD-Meldung „Grafikqualität gesenkt: %s“ fehlen laut Plan noch.
6. **QA1**: Die zweite Bildgleichheitsliste (Menüs, 1280 × 800) wird die geänderten Bildschirme enthalten (Optionen in
   zwei Seiten, Beschreibung des Titeleintrags „Optionen“ nennt jetzt Klang und Grafik).
7. `scripts/race3d/benchmark.gd` gehört nach §6 eigentlich QA1; A-8 hat ihn für diesen Schub UI1 gegeben – QA1 kann
   ihn übernehmen.
