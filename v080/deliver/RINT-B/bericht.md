# RINT-B – zweite Hälfte der Zusammenführung von M1 (Bericht)

Arbeitskopie `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-1`, Zweig
`worktree-wf_ae4df3ba-14f-1`, Sicherung `origin/wip/v080-rint-b`. Basis: RINT-As Kopf `fd27c16` (fast-forward; kein
Vorgänger-Stand vorhanden). „gemessen“ = auf der Build-VM (llvmpipe unter Xvfb bzw. headless, 4 geteilte Kerne; zeitweise
lief daneben ein fremder Render-Prozess `kritik_render.gd` mit 150–230 % CPU); „abgeleitet“ = gerechnet, nicht messbar
(echte Grafikkarte, Steam Deck, Gehör). Ausführlich in `docs/renderer-modern.md` §13.

## 1. Zusammenführung

| Schritt | Commit | Ergebnis |
|---|---|---|
| R3E (fbfd1b5) `--no-ff` | dfc99b6 | Konflikt nur in `docs/renderer-modern.md` (RINT-A hatte neu nummeriert): RINT-As Nummern bleiben, R3Es Abschnitt „Ersatzbilder“ ist §11.8 im Fahrzeug-Abschnitt von R3. `vehicles.gd` ohne Konflikt – RINT-As `vehicle_shadow` und R3Es Ersatzbilder sind beide drin |
| AS1R (c478902) `--no-ff` | 94ce4a2 | ohne Konflikt; `manifest.json` mit `--manifest-only` neu erzeugt = automatisch gemergt (28 Modelle, 182 Sets, 40 mit Modell); Prüfer OK |
| AU-D1 (03eaeff) `--no-ff` | b473e90 | ohne Konflikt; Import danach sauber |

**Modell-Cache nach AS1R** (`ce3d/lod.py` gehört zu jedem Schlüssel): `export_models.py --check-keys` OK. Die sechs
Fahrzeuge mit dem zusammengeführten Code neu exportiert (21 s) und gebacken: **byte-gleich** mit AS1Rs eingecheckten
Dateien; ein zweiter Bake wieder byte-gleich. Requisiten nicht neu exportiert (unverändert).

## 2. Notizen der Leitung 1–10

1. **Doku-Konflikt** – gelöst wie in Abschnitt 1; §11.8 (Ersatzbilder) im Fahrzeug-Abschnitt, Verweise 11.1/11.7
   angepasst.
2. **run_tests auf dem letzten Kopf** – siehe Gates (Abschnitt 6).
3. **Robuste Zeitprüfungen** – `tests/race3d/fixtures/perf_clock.gd`: Referenz-Arbeitslast im selben Prozess, neben
   jeder Probe gemessen, auf das normale Tempo der VM umgerechnet (`REF_NOMINAL_US` 600 µs; die Thread-CPU-Zeit taugt
   nicht: `schedstat` springt in Scheduler-Ticks, 0 µs für 2 ms Arbeit – gemessen). Benutzt von `check_vehicles` →
   `leistung` (≤ 40 µs je Auto) und `check_modern_stage` → `kern_zeit` (≤ 0,6 ms); neu `renderer_zeit`: **ganzer
   Renderer ≤ 1,5 ms GDScript je Bild** (alle Builder und Ebenen, Verkehr der Sitzung), Tabelle in
   `docs/renderer-modern.md` §13.6. Gemessen: 32,6–34,6 µs je Auto, Kern 0,23 ms, ganzer Renderer 0,80 ms (13 Autos).
4. **Horizont** – Silhouetten auf Arcades Zeile (Kuppenregel `base_y = max(clip, hy − 120)` in `backdrop.gd`), Fernboden
   in Landfarbe mit Arcades Bodennebel statt Tiefennebel (F4: nie mehr Nebel als Arcade), Gelände mit demselben Nebel
   (`FOG` im Compatibility-Renderer), Rand des Fernbodens bis zur Silhouettenzeile, mit dem Mittel des fernen Bodens.
   Gemessen an S1: Unterkante der Silhouetten Zeile 320 = Arcade (vorher 323), Zeilen 321–330 Land 108–114/148–155/
   66–69 statt Nebel 197/219/237; T4 kein „See“ mehr; T1 Land bis an die Hügel (A/B-Bögen). `check_terrain_cover` in
   den Render-Prüfungen.
5. **Nacht** – *Ursache der Dunkel-Quetschung*: der fest eingeschaltete Nachbearbeitungspfad schickt das Bild ein
   zweites Mal durch die Näherungen der Engine (sRGB-Polynom, Anzeige ohne linearen Fuß); geschriebene 8/255 kamen als
   1/255 heraus, 16 als 11 (gemessen, `probe/post_probe.gd`). *Abhilfe*: 1D-LUT im Environment, ab 8/255 genau. *Boden
   zu hell*: Bodengesetz (Fahrbahn, Gelände, Fernboden schreiben den Umgebungsdurchgang selbst: ebener Boden = Albedo ×
   Arcades Umgebung, bei jeder Albedo): N1 Schneeboden +50 %/+37 % → +1,7 %/−8,5 %; S4 22 Uhr Gras +34 % → −16 %
   (gemessen). *Laternen*: Arcades warmer Schein (2,4 m, ≥ 3 px) in `flares`. Abgestimmt an S1 22 Uhr, S4 22 Uhr, N1.
6. **Ersatzbilder ohne Sonnenschatten und ohne zweiten Fleck; Kasten-Ersatzbilder werfen wie Modelle** – umgesetzt,
   `check_vehicles` → `schatten` prüft alle Presets; Bild bei „Hoch“: der gelbe Sportwagen an S1 trägt nur seinen
   eingebackenen Schatten (`look/hoch/S1.jpg`).
7. **F7 streng** – unverändert.
8. **Bögen nur in `prepare()`; Texturspeicher** – Arcade 221,1 MB, Modern 166,8 MB (davon 17 Bögen 51,5 MB), gemessen
   Kiel–Hamburg. Unter der Grenze Arcade + 60 MB (A-6) – keine weitere Einschränkung nötig (Bögen ohnehin nur für Sets
   ohne Modell).
9. **Doku** – §11.1/§11.7 auf die Ersatzbilder (Sprite vor gemaltem Kasten), §11.8 Schattensatz; ARCHITECTURE.md §15:
   `leave_modern(always)`, `quality_lowered`, `gfx_lowered`; `docs/modelle.md` Kanal 15; neuer §13 in
   `docs/renderer-modern.md`.
10. **Ladezeit Kiel–Hamburg Modern** – 5,2–5,6 s ab km 0 bis „live“ (Arcade 0,85 s), gemessen wie `prepare_s` des
    Leistungstests; die ganze Zeit hinter dem Ladebild. Der Balken lief vorher einmal rückwärts (0,1 → 0,05) und stand
    während des Ladens der Startansicht bei 0,05; jetzt 0,05 → 0,1 → 0,65 → 0,83 … 1,0. Offen: das Laden der
    Startansicht ist ein Bild von 1,6–1,9 s (der Balken steht so lange).

## 3. Fahrzeuge, Showroom, Klang, Leistungstest

- **Lampen**: unbeleuchtet 0,28 (`lamp_off`), Rücklicht Kanal 2 bei 0,5 (`tail_level`); **Bremse 3,9 × Rücklicht**
  um 22 Uhr (gemessen, `probe/brake_probe.gd`, schwarze Limousine 18 m voraus).
- **Lack** (Knie über 0,7, Steigung 0,45, 8 % Entsättigung; nachts Himmelsspiegel 35 %, Fülllicht 30 %), gemessen
  gegen die Cycles-Sprites in der Spielkamera (Farbton / Helligkeit): Limousine mittags −3,4° / +6,7 %, 19:30 −9,6° /
  +3,3 %; Kompakt mittags −1,3° / −7,8 % (am Anschlag 2 % statt 29 % bei Arcade), 19:30 +5,9° / **−16,2 %** (Sonne
  voraus, Heck im Schatten – außerhalb der 10 %); nachts Limousine +31,8 % (vorher +53 %), Kompakt −10,5 %.
- **Rückstrahler** (Kanal 15 `retro`): Konturband und Dreiecke des Lkw im Kegel des eigenen Abblendlichts
  (`ce_headlight_*`), Lkw neu exportiert/gebacken; Schilder strahlen schon das echte Abblendlicht zurück.
- **lod1 → lod2**: Dither-Überblendung über 0,5 s (`xfade`). Gemessen (ruhige Szene, Auto zieht langsam durch die
  Grenze bei 94,5 m, Preset der Maschine): vorher **5,4 %** der Autopixel in einem Bild, jetzt 0 % im Wechselbild und
  ≤ 3,5 % je Bild verteilt; Kosten ein Zeichenaufruf je blendendem Auto. Prüfung `check_vehicles` → `ueberblendung`.
- **Showroom**: A/B mit derselben Kamera (`models_contact_sheet.sh … --only="player/*" --showroom`, jetzt mit dem Look
  des Showrooms) – Echtzeit heller, gesättigter, aber flacher als die Sprites → `showroom` bleibt `false` (Manifest
  unverändert). Bild `showroom_ab.png`.
- **Klang**: `GameFlow.quit_game()` stellt den Klang ab, wartet 0,3 s, dann `quit()`; Render-Prüfung
  `check_quit_sound.gd` (je Profil drei Starts). Motor v3, Rennmusik zum Einzählen, Ducking, Arcade unverändert,
  Ende ohne Lecks: AU-D1-Prüfungen in `run_tests` (`check_music`, `check_engine3`, `check_modern_audio`).
- **Leistungstest**: siehe Gates.

## 4. Neu gefunden: Instanz-Uniforms sprengten Godots globalen Shader-Puffer

Bei den Messungen fiel „Too many instances using shader instance variables“ auf (15 Meldungen in 900 Bildern mit
Verkehr am Stand b473e90, gemessen). Godot (Compatibility) gibt jeder Instanz mit `instance uniform` 16 Plätze eines
Puffers, der nur so groß ist wie der Uniform-Block der GPU (64 KB = 4096 Plätze – llvmpipe und die meisten
Desktop-Treiber): ≈ 250 Instanzen in der ganzen Szene; darüber zeichnet Godot eine Instanz mit den Werten einer
anderen. Die Fahrzeug-Pools behielten ihre gebauten Stufen, die Zahl wuchs mit dem Verkehr ohne Ende. Abhilfe:
`INSTANCE_BUDGET` 128 in `layers/vehicles.gd` (gepoolte Autos zuerst freigeben, dann nicht gezeigte Stufen); Prüfungen
`check_vehicles` → `instanzen`, Render-Prüfung `check_instance_budget.gd` (Logger fängt die Ablehnung), und
`run_render_checks.sh` lässt jede Render-Prüfung mit dieser Meldung scheitern. Gemessen: ganze Szene höchstens 196
(100 s Verkehr) bzw. 229 Instanzen, keine Ablehnung; am alten Stand nach 100 s schon 220 und wachsend.

## 5. LOOK PASS

A/B-Bögen (`tools/ab_shot.sh` über `m1/RINT-B/tools/ab.sh`, gleiche Simulation, links Arcade, rechts Modern) am letzten
Stand des Renderers: `look/hoch/` mit `--gfx-preset=high` an S1–S5, T1, T4, C1 (19:30), N1, N2 und die Fahrzeuge an S1
(`S1K` Kombi, `S1S` Sportwagen, `S1G` Gran Turismo); `look/maschine/` mit dem Preset der Maschine (llvmpipe →
„software“ → „Niedrig“) an denselben zehn Stellen. Clip `kiel_hamburg_start_ab.mp4`: die ersten 20 s von Kiel–Hamburg ab
dem Einzählen, beide Modi aus derselben Simulation (Movie Maker, 30 Bilder/s, Modern „Hoch“ mit `--no-watchdog`: der
Wächter hätte das Preset auf llvmpipe gesenkt), Ton von Modern.

**Besser als vorher / gleichauf mit Arcade** (an den Bildern): Horizont an S1, T1, T4 (Land bis an die Silhouetten,
Silhouetten auf Arcades Zeile, kein See an T4), Boden mittags und nachts in Arcades Helligkeit (Gras, Asphalt, Schnee),
Laternen mit warmem Schein (C1), Lack der Spielerautos mittags innerhalb 10 %, Ersatzbilder ohne zweiten Schatten,
Tiefe und Felder des Geländes (S3, T1), Lampen bei Tag nicht mehr „an“.

**Ehrlich: was schlechter ist als Arcade** (gesehen bzw. gemessen):
1. **Start- und Zieltor** fehlen in Modern (Clip: Arcades Brücke „START“ in Kiel; S5: „ZIEL“ in Hamburg) – nur die
   Linie auf der Fahrbahn ist da.
2. S2 – die **Tankstelle** wirkt kleiner: das große rot-weiße Dach über der Fahrspur und die gelbe Kante der Tankspur
   fehlen; Arcades Station liest sich viel stärker.
3. S4 (Hamburg, Brücke) – **keine Brückengeländer**, das Wasser dunkel blaugrün statt Arcades hellgrau, eine grüne
   Böschung zum Wasser.
4. N2 / N1 – **kein Regen und kein Schnee in der Luft** (Modern hat keine Wetter-Ebene, M2), die nasse Fahrbahn spiegelt
   nichts.
5. T4 – Arcades **Felsbrocken** am Straßenrand fehlt (keine Requisite in Modern).
6. Nacht – das **Spielerauto ist heller** als sein Sprite (Limousine +32 %, Mondglanz auf dem Kofferraum), Arcades großer
   roter Schein der Rückleuchten über dem Stoßfänger ist in Modern kleiner; das **Abblendlicht auf der Fahrbahn**
   ist 9–38 % heller als in Arcade (S1 22 Uhr, gemessen).
7. Dämmerung mit der Sonne voraus – der **Kompakt 16 % dunkler** als sein Sprite (Heck im eigenen Schatten).
8. Showroom – das Echtzeitbild ist **flacher als die Cycles-Sprites** (deshalb bleibt `showroom` aus).
9. Laden – Modern braucht **5,2–5,6 s** statt 0,85 s, davon ein Bild von 1,6–1,9 s, in dem der Balken steht.
10. Preset „Niedrig“ (Maschine) – weniger Bäume und Büsche als Arcade (N1), die 3D-Auflösung ist sichtbar gröber am
    Spielerauto.
11. Himmel – Modern zeichnet **keine Sonnenscheibe** (Vorschaubild der Optionen: Arcade hat sie); am Start fehlt im
    Clip außerdem Arcades blaues Schild „Tankstelle 15 km“ rechts.
Kombi, Sportwagen und Gran Turismo sind in Modern noch Arcades Bilder (kein Modell, M2) – an S1 von Arcade nicht zu
unterscheiden.

## 6. Gates am letzten Kopf (9b6adbc)

Alle Läufe mit eigenem absoluten `XDG_DATA_HOME` (unter `m1/RINT-B/xdg_*`), `nice -n 10`, ein schwerer Lauf zur Zeit.

| Gate | Befehl | Ergebnis |
|---|---|---|
| Import | `godot --headless --path . --import` | Exit 0, keine Zeile `ERROR`/`WARNING`, Baum unverändert |
| Tests (1) | `tools/run_tests.sh` (Stand 3d84e0b) | Exit 0 in 854 s: `692 Tests, 0 fehlgeschlagen`, alle `CHECK … OK` (u. a. `instanzen`, `ueberblendung`, `renderer_zeit` 0,726 ms, `kern_zeit` 0,247 ms, `leistung` 33,9 µs) |
| Tests (2) | `tools/run_tests.sh` (9b6adbc, letzter Kopf) | Exit 0 in 880 s: `692 Tests, 0 fehlgeschlagen`, `==> Tests bestanden`, 156 Zeilen `CHECK(S) … OK`, keine `FEHLER` |
| Golden | `tools/golden.sh check` | `GOLDEN arcade: 20 von 20 identisch (151 s)` |
| Render | `tools/run_render_checks.sh all` | `==> 16 von 16 Render-Prüfdateien in Ordnung` (Arcade: Glow 16 OK, Sprite-Flip; Modern: facade, instance_budget (neu), light_base, models, occlusion, props, quit_sound (neu), road_parity, seam, session_modern, showroom, terrain_cover, vehicle_lights, vehicle_standin) |
| modern_sight / path_check `--full` | – | nicht nötig: Kern (Streamer, Pfad) und Platzierung unverändert; geändert sind Shader, Ebenen, der Ladebalken |
| Modelle | `python3 tools/blender/validate_models.py --report` | `CHECK models OK` (28 Modelle, 182 Sets; Netze 4,47 MB, Texturen 15,94 MB) |
| Export-Determinismus | `export_models.py --only=traffic/truck --force`, ebenso `traffic/sedan`, danach `bake_models.gd` | glb gleich (sha1 31ef148a…, 89308252…), Neubacken lässt den Baum unverändert |
| Sprite-Geometrie | `check_sprite_geometry.py --jobs 2` | `187 Sprite-Sets … 187 identisch (davon 1 mit anderer Flächenreihenfolge)`, `CHECK sprite_geometry OK` |
| ERGEBNIS Arcade = Modern | `tests/race/run_stage.gd --timescale=40` je Modus | kiel_hamburg, dev_testetappe (21 Uhr, Regen), saragossa_pau (Schnee): 28 Schlüssel, einziger Unterschied das Feld `gfx` (arcade/modern) – Fahrzeit, Tempo, Sprit, Strafen gleich |
| Modern-Autopilot Kiel–Hamburg unter Xvfb | `run_stage.gd --graphics=modern --timescale=4` (Xvfb, opengl3) | im Ziel, ERGEBNIS gleich dem headless-Lauf; 260 s Wand; perf_stats: Preset low, 96 Zeichenaufrufe, 85 820 Primitive, Bild median 86 ms (llvmpipe), render() 1,76 ms, Textur 154,6 MB, Fahrzeug-Instanzen 119 (Spitze 128 = Budget, 11 freigegeben), keine Ablehnung des Puffers |
| Texturspeicher | `probe/texmem_probe.gd` | Arcade 221,1 MB, Modern 166,8 MB (Grenze Arcade + 60 MB) |
| Linux-Build | `tools/build_linux.sh` | Exit 0; 440,6 MB, Archiv geschätzt 146,7 MB – „in Ordnung“ (Grenzen 300/330/350) |
| Windows-Build | `tools/build_windows.sh` | Exit 0; Zip gemessen 156,5 MB – „in Ordnung“ |
| Windows unter Wine | `wine64 CrossingEurope.exe -- --graphics=modern --bench=autobahn --bench-seconds=5` (eigenes Präfix, `dinput8=d`, ALSA-Null, `TMPDIR` leer, `wineserver -w`) | Modern-Etappe gefahren: kein `fallback`, 8,7 Bilder/s, 44 Bilder, Laden 5,41 s; Linux-Build ebenso: 10,3 Bilder/s |
| Leistungstest | `-- --graphics=modern --bench=all --bench-out=…` | `leistungstest.json` (user:// und `--bench-out`) mit perf_stats: Autobahn 11,0 / Stadt Nacht Regen 2,4 / Berg Tunnel 7,0 Bilder/s, script_ms 1,6–2,0, Laden 5,8–8,9 s; Urteil „zu langsam“, Vorschlag Arcade (llvmpipe) |

Hinweis: `script_ms` des Leistungstests (1,6–2,0 ms) ist Wanduhr unter Xvfb, die CPU teilt sich mit dem Software-
Rasterer; das Budget 1,5 ms (`renderer_zeit`) gilt headless auf das normale Tempo der VM umgerechnet (0,73–0,80 ms).

## 7. Dateien (eigene Änderungen seit b473e90)

Shader: `assets/shaders/modern/{far_ground,road,terrain,vpbr}.gdshader`, `inc/ground.gdshaderinc`,
`inc/ground_law.gdshaderinc` (neu). Skripte: `scripts/race3d/{environment_rig,modern_materials,modern_renderer}.gd`,
`scripts/race3d/layers/{backdrop,far_ground,flares,vehicles}.gd`, `scripts/ui/game_flow.gd`,
`scripts/ui/widgets/showroom_3d.gd`. Modelle: `assets/models/traffic/truck/*` (Kanal 15), `assets/models/manifest.json`;
`tools/blender/ce3d/{roles,truck3d}.py`, `tools/blender/validate_models.py`. Prüfungen:
`tests/race3d/check_{vehicles,modern_stage}.gd`, `tests/race3d/fixtures/perf_clock.gd` (neu),
`tests/race3d/render/check_{quit_sound,instance_budget}.gd` (neu), `tools/run_render_checks.sh`,
`tools/models/contact_sheet.gd`. Bild: `assets/ui/gfx_preview_modern.webp` (vorher ein Platzhalter von 1 KB). Doku:
`docs/renderer-modern.md` (§11.1/11.7/11.8, neuer §13), `docs/modelle.md`, `ARCHITECTURE.md` §15. Keine eingefrorene
Arcade-Datei geändert (geprüft: `git diff fd27c16..HEAD` über die Liste von Regel 1 ist leer).

## 8. Commits (Zweig `worktree-wf_ae4df3ba-14f-1`, gesichert auf `wip/v080-rint-b`)

dfc99b6 R3E, 94ce4a2 AS1R, b473e90 AU-D1 (Zusammenführungen) · f198858 Nachbearbeitung exakt, Bodengesetz, Horizont,
Laternenschein, Lack, Zeitprüfungen · 9eac32f Überblendung, Rückstrahler, Nachtlack, Showroom-Look · a8abb01
Instanzbudget · 3d84e0b Ladebalken, Showroom-A/B · 8f58b2d Doku §13 · 9b6adbc Vorschaubild Modern.

## 9. Für die Nächsten

- Start- und Zieltor, Tankstellendach, Brückengeländer, Felsbrocken und Sonnenscheibe fehlen in Modern (Abschnitt 5).
- Das erste Laden der Startansicht ist ein Bild von 1,6–1,9 s (`ChunkStreamer.update` lädt beim ersten Aufruf alles):
  hinter dem Ladebild über mehrere Bilder verteilen, mit Fortschritt je Stück.
- `INSTANCE_BUDGET` 128 setzt voraus, dass der Rest der Szene unter ~120 Instanzen mit `instance uniform` bleibt (gemessen
  34–72, Aufwärmen bis 135): neue Shader mit Instanz-Uniforms (Requisiten, M2) müssen in dieses Budget passen –
  `check_instance_budget.gd` schlägt sonst an.
- Lack nachts (Limousine +32 %) und in der Dämmerung mit der Sonne voraus (Kompakt −16 %), Abblendlicht auf der
  Fahrbahn 9–38 % heller als Arcade: Kandidaten für den nächsten Look-Durchgang.
- Showroom: erst bei einem Echtzeitbild, das mit dem Sprite mithält, `showroom: true` setzen (Kontaktbogen mit
  `--showroom` zeigt jetzt den echten Look).

## 10. Lieferung

`/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/RINT-B/`:
`bericht.md` (dieser Bericht), `kiel_hamburg_start_ab.mp4` (20 s A/B), `look/hoch/*.jpg` (13 Bögen),
`look/maschine/*.jpg` (10 Bögen), `showroom_ab.png` (Showroom, dieselbe Kamera), `leistungstest.json` (Leistungstest
auf der Build-VM).
