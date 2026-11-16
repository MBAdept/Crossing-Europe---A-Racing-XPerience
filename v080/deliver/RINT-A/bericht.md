# Bericht RINT-A – erste Hälfte der Zusammenführung des Schubs M1 (v0.8.0)

Arbeitsbaum `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1`, Zweig
`worktree-wf_c23ec0b9-e7b-1`, Sicherung `origin wip/v080-rint-a` (nach jedem Commit gepusht, nie erzwungen).
Basis: `v0.8.0` = 2b41e16 (vorgespult). Kein Vorgänger (keine STAND.md, kein Zweig `wip/v080-rint-a`).

„gemessen“ = auf dieser VM (llvmpipe unter Xvfb bzw. headless, 4 geteilte Kerne, während der Läufe Last 1–13 durch
andere Aufträge); „abgeleitet“ = gefolgert, nicht gemessen. Über eine echte Grafikkarte, das Steam Deck oder wie
etwas klingt, sagt dieser Bericht nichts Gemessenes.

## 0. Gates auf dem Endstand fd27c16

fd27c16 ändert gegenüber 9b4be1c nur eine Prüfung (`kern_zeit`), ein Testdouble und die Doku; Render, Kaltstart
und ganze Etappe liefen auf 9b4be1c (gleicher Spielcode), Import und `check_modern_stage.gd` auf fd27c16.

Alle auf dieser VM (llvmpipe, Xvfb 1280 × 720, `nice -n 10`, eigener `XDG_DATA_HOME` unter dem Scratch-Ordner,
`--graphics=` immer ausdrücklich). Logs: `m1/RINT-A/gates/` (erster Lauf, bd30c5c), `m1/RINT-A/gates2/` (Endstand) und `m1/RINT-A/logs/`.

| Gate | Befehl | Ergebnis |
|---|---|---|
| Import | `godot --headless --path . --import` | rc 0, 0 Fehler (auf 9b4be1c und fd27c16) |
| Unit-Tests | `tools/run_tests.sh` | 2. (letzter erlaubter) Lauf auf 9b4be1c: **673 Unit-Tests, 0 fehlgeschlagen; 137 Prüfungen OK, 1 FEHLER**: `check_modern_stage` → `kern_zeit` 0,618 ms (Grenze 0,6; im 1. Lauf 0,499 ms OK). Die Prüfung soll den Renderer-Kern messen („ohne Fahrzeug-, Requisiten- und Gelände-Ebene“), maß seit der Zusammenführung aber alles, was `render()` jetzt aktualisiert – ihr Umfang ist auf den Kern zurückgeführt (Testdouble `tests/race3d/fixtures/core_renderer.gd`, Kern allein 0,194 ms – R1 hatte 0,208 ms gemessen); danach `check_modern_stage.gd` einzeln: **7 von 7 OK** (`kern_zeit` 0,251 ms, `ergebnis` gleich in beiden Modi). 1. Lauf auf bd30c5c: nur `check_vehicles` → `lampen_fest` rot (behoben, 412a756) |
| Golden | `tools/golden.sh check` | **GOLDEN arcade: 20 von 20 identisch** (225 s, einmal, auf bd30c5c; seither geändert nur `flare.gdshader`, `scripts/race3d/builders/props.gd` – beide lädt nur Modern –, vier Prüfungen, ein Testdouble und die Doku: `git diff --name-only bd30c5c HEAD`) |
| Render-Prüfungen | `tools/run_render_checks.sh all` | **13 von 13 Dateien in Ordnung**, 39 `RENDER-CHECK … OK`, 0 FEHLER (u. a. `bremslicht` 150 m +0,16, `lkw` 0 Pixel, `klassen` Fenster 1.064 px, `pause` 0 Bildpunkte, `rueckfall`, `freigabe`, `rotor`). Erster Lauf auf bd30c5c: 10 von 13 (`klassen`, `lkw`, `bremslicht` – Abschnitt 2.7/2.8) |
| Sicht | `tests/sim/modern_sight.gd -- --full` | 6 OK, 0 FEHLER: F1 0 Fälle bis 270 m in 99.424.500 Stichproben (128 Etappenrichtungen), Außenspuren 0 bis 260 m, F2 ≤ 0,593 / 0,596 / 0,555, F3 0 von 5923, F7 0 von 2.011.532 Querschnittsseiten, Modell 0 abweichend (139 s) |
| Weg | `tests/sim/modern_path_check.gd -- --full` | 2 OK, 0 FEHLER: kleinster Abstand 267,6 m (≥ 250 m), Schleifen frühestens nach 2064 m Weg (≥ 2000 m) (56 s) |
| Modelle | `python3 tools/blender/validate_models.py --report` | `CHECK models OK` (28 Modelle, LOD- und Schattenbudgets) |
| ERGEBNIS | `tests/race/run_stage.gd -- --stage=kiel_hamburg --from=kiel --graphics=arcade\|modern --seed=11 --timescale=40` | 28 Schlüssel, verschieden nur `gfx` (Seed 11, 8 Uhr: 95 km, 1 Tankstopp, 41,92 l, `time_s` 360,95 in beiden) |
| Ganze Etappe | `run_stage.gd` unter Xvfb, `--graphics=modern --gfx-preset=medium --vehicle=limousine --hour=12 --timescale=4` | rc 0, `aborted` false, 95 km, 1 Tankstopp, 0 Kollisionen, 1526 s Wanduhr (auf 9b4be1c; ebenso auf bd30c5c, 1183 s); im Log **keine** Warnung oder Fehlermeldung je Bild – die einzige Zeile ist die V-Sync-Warnung des Treibers vor dem Start; ERGEBNIS in beiden Läufen gleich |
| Kaltstart | `tests/race3d/render/warmup_cold.gd -- --graphics=modern` mit leerem Nutzer- und Mesa-Cache | **0 Varianten während der Fahrt** (389 im Cache vor dem Start; Kiel – Hamburg km 2, „Mittel“, 12 Uhr, 39 Bilder in 30 s, Median 766 ms, längstes 1.078 ms, Grenze 2.299 ms). Erster Lauf auf bd30c5c: FEHLER – 2 Varianten nach 3,0 s (Abschnitt 2.8) |

**perf_stats der ganzen Etappe** (Kiel – Hamburg, Modern „Mittel“, 12 Uhr, llvmpipe unter Xvfb, Zeitraffer 4 –
gemessen auf einer geteilten VM, Werte einer Software-Grafik, keine Aussage über eine echte Karte):

| Größe | 9b4be1c (Last 8,3) | bd30c5c (Last 5,3) |
|---|---|---|
| `render_ms_avg` / `render_ms_max` (GDScript-Zeit von `render()`) | 2,01 ms / 29,9 ms | 1,73 ms / 12,5 ms |
| `chunk_commit_ms_max` (Streamer, ganze Fahrt) / Einhängen in der Vorbereitung | 1,75 ms / 10,6 ms | 1,53 ms / 9,67 ms |
| `chunk_build_ms_avg` / `_max` (Arbeiter-Thread, 95 Stücke) | 5,57 ms / 25,4 ms | 4,75 ms / 18,6 ms |
| `draw_calls` / `primitives` (letztes Bild, im Ziel; Schatten) | 95 / 74.412 (0 / 2.526) | 95 / 74.412 (0 / 2.526) |
| Bildzeit Median / p95 (llvmpipe, 1280 × 720) | 659 ms / 909 ms (2.398 Bilder) | 395 ms / 502 ms |
| Vorbereitung / Aufwärmen (Aufwärm-Knoten) | 13,7 s / 12,6 s (48) | 8,5 s / 7,2 s (17) |
| erste Bilder nach dem Ladebild: Median / längstes | 405 / 633 ms (73 Bilder) | 935 / 1.252 ms (34 Bilder) |
| `vehicle_us_avg` / `_max`, `flare_us_avg` / `_max` | 796 µs / 16,8 ms, 113 µs / 13,5 ms | 723 µs / 5,2 ms, 87 µs / 1,4 ms |
| `tex_mem_mb`, `fallback_sets`, `signs_missing`, `quality_lowered`, `watchdog` | 123 MB, 35, 0, „“, „“ | dieselben |

Der Kaltstart mit leerem Cache (`warmup_cold.gd`) auf 9b4be1c: `render()` im Mittel 2,54 ms, Einhängen höchstens
1,51 ms, 138 Zeichenaufrufe, 100.953 Dreiecke in der Startansicht. Die Maxima schwanken mit der Last der Maschine
(andere Aufträge liefen mit); das längere Aufwärmen ist der Preis von 2.8 (Übersetzungen, die sonst unterwegs kämen).

## 1. Zusammenführung

| Schritt | Commit | Ergebnis |
|---|---|---|
| R1 (21bca09) `--no-ff` | 286e64d | ohne Konflikt |
| R2 (b947e73) `--no-ff` | 7c1a82f | ohne Konflikt |
| R3 (4d02ada) `--no-ff` | f1a2ea2 | Konflikte `contact_shadow.gdshader` (+ .uid, add/add) und `docs/renderer-modern.md` (R1 und R3 je ein §10) |
| AS1b (adff0b3) `--no-ff` | 720fa3a | ohne Konflikt |
| UI1 (3b89a33, enthält AS1 und AU-B) `--no-ff` | 4547818 | ohne Konflikt |

- **contact_shadow**: R2s Datei (Schattenfleck der Requisiten, `PropLibrary.CONTACT_SHADER`) bleibt
  `contact_shadow.gdshader` mit ihrer uid; R3s Fahrzeug-Schattenfleck heißt `vehicle_shadow.gdshader`, Klasse
  `vehicle_shadow` in `layers/vehicles.gd` (die einzige Zeile, die ich in einer Datei von R3E geändert habe), uid neu
  aus dem Import (a27d3ed). Keine Aufwärm- oder Prüfliste nannte die Klasse; `perf().contact_shadows` bleibt der
  Zählername der Fahrzeug-Ebene.
- **docs/renderer-modern.md**: R1s Abschnitt bleibt §10, R3s wird §11 (Unterabschnitte umnummeriert).
- **Manifest**: `export_models.py --manifest-only` erzeugt genau das gemergte `manifest.json` (28 Modelle, 182 Sets).
- **Import**: der erste `godot --headless --import` hing (Hauptthread drehte 15 min, Arbeiter schliefen, drei
  Texturen als 0-Byte-Reste); abgebrochen, Reste gelöscht, zweiter Lauf 8 s. Der Import auf dem Endstand ist sauber.
- `tests/check_scripts.gd` nach dem Zusammenführen: 287 Skripte, 0 fehlerhaft.

## 2. Was die Zusammenführung erst zusammen brauchte (Punkte des Auftrags)

### 2.1 Kern: Bandspitzen (R2-Bericht §9.1)

Die drei Zeilen aus R2s Versuch (`m1/R2/bin/exp_kernel.sh`) sind in `TerrainProfile._compute()`: die Innenseite wird
auch nach der stärksten Krümmung ihrer Seite im Korridorfenster (`_kappa()`) gekürzt. `check_terrain_plan` ist
streng (`STRICT = true`): 40 Kamerapositionen in 13 Etappenrichtungen, 601 Stücke, 37.488 Streifen –
0 Überlappungen verschiedener Straßenteile, **0 Paare von Bandspitzen** (vorher 71 Paare bis 1,83 m), höchstens
896 Dreiecke je Stück (gemessen). `modern_sight.gd -- --full` danach grün (Zahlen in den Gates).

### 2.2 Licht: Gelände, Fernboden, Lampen, Abblendlicht

- Gelände und Fernboden liegen auf Render-Ebene 2 wie die Fahrbahn (die echten Spots/Punktlichter lassen den Boden
  aus); `terrain.gdshader` und `far_ground.gdshader` binden `inc/pools.gdshaderinc` und `inc/headlight.gdshaderinc`
  ein (Arcades Rückstrahlfaktoren: Gras 0,45, Kies 0,6, Pflaster 0,8, Wasser 0,45); der Fernboden meldet sein
  Material mit `add_pool_material()` an. Gemessen (headless, Kiel – Hamburg km 80, 22 Uhr): Fahrbahn, Gelände und
  Fernboden tragen `pool_count` 16 und dieselbe `pool_ambient`.
- `--gfx-debug=cover`: war schon in `environment_rig.gd` (Nebel aus) und `layers/backdrop.gd` (magenta Leinwand)
  eingebaut (R1); `check_terrain_cover` läuft in den Render-Prüfungen.
- Lampen der Requisiten (`PropLibrary.lamp_pools()`): nach unten (Laterne, Tankdach) Kegel 9 m, eine Gruppe teilt sich
  Arcades Tankstellenlicht (je min(0,55; 1,6/n) – Tankdach 8 × 0,2); Wandlampen (Bauernhaus, Scheune, Zollhäuschen)
  5 m / 0,4, der Kegel liegt höchstens 1,5 m vor der Wand (`lights.gd pool_centre()`, vorher hätte die waagrechte
  Achse den Kegel bis zu ~30 m vor die Wand gelegt); Flugbefeuerung des Windrads (ab 25 m Höhe) ohne Kegel – sie hätte
  einen roten Kegel 300 m neben das Windrad gelegt und das Punktlicht-Pool belegt. Alle gehen über `add_lamps()` an
  `lights` und `flares` (A-7). Gemessen an S4 22 Uhr: 47 feste Lampen in beiden Ebenen, 16 Kegel, 4 Punktlichter,
  34 Lichtpunkte gezeichnet.
- `ce_headlight_pos/_dir/ce_headlight` setzt die Ebene `lights` (R1) in jedem Bild mit Abblendlicht; `sign.gdshader`
  nimmt damit die echten Scheinwerfer (`ce_headlight.y > 0`), der Kamera-Ersatz greift nur noch, wenn niemand sie
  setzt. Lack und Glas bekommen das Abblendlicht von den zwei echten Spots (Ebene 1).

### 2.3 Spiegelungen: eine Quelle

Siehe docs/renderer-modern.md §12.2 und `spiegelung_eine_quelle.png`. Gemessen (Ausschnitt des Spielerautos, S1,
„Hoch“, Mittelwerte RGB): Mittag – beide Quellen 86/102/136, nur Sky der Umgebung 75/92/126, nur analytisch
83/96/122, **neu 83,5/96,4/124,2**; 19:24 Uhr – beide 86/70/83, nur Sky 73,5/64/80, **neu 83/68/79**. Der Pfad ohne
analytischen Himmel (Showroom, Kontaktbogen) ist pixelgleich zu vorher (mittlere Abweichung 0,000).

### 2.4 Rotoren

`vpbr.gdshader` `vertex()`: Lackcode 0,875, Nabe = `UV2.y` × 128 m, Winkel = −`ce_time` × 1,35 rad/s + Phase aus
`MODEL_MATRIX`-Ursprung (x · 0,37 + z · 0,23) – genau AS1bs Vorgabe, nur das Vorzeichen so, dass sich der Rotor von
der Straße (+Z) aus im Uhrzeigersinn dreht. Render-Prüfung `rotor` (in `check_props_render.gd`): Windrad bei
`ce_time` 0 / 0,4 / 0,8 s – Rotor 2.837 / 2.779 Bildpunkte geändert, Turm 0 / 0 (jeder zweite Bildpunkt, gemessen);
Bild `rotor_drei_bilder.png`. Mit der Pause steht er (Prüfung `pause`).

### 2.5 Requisiten

- **Varianten**: eine je Stück und Set (`chunk_variant()`, stabiler Hash aus Stücknummer und Set) statt je Requisite.
- **Bodendecker**: `graphics.modern.props.bend_cover = ["props/cover_bush", "props/cover_grass"]`; weggelassene
  Pflanzen im Kurvenkorridor werden ein (Busch) bzw. drei (Baum) Stücke ≤ 0,5 m, nie näher als 0,8 m an der
  Fahrbahnkante, nicht in den City Limits (an C1 lagen sonst Grasbüschel auf dem Pflaster – gesehen, behoben).
  Vorher/nachher `bodendecker_T2_T4_vorher_nachher.jpg`: T4 2.115, T2 365 Bildpunkte geändert (gemessen) – an T4
  Strauchpolster und Grasbüschel auf der kahlen Innenseite, an T2 kaum sichtbar.
- **Helle Rauten am Horizont von S1**: gemessen mit Ausblenden einzelner Knoten – ohne die Fernbild-Knoten
  verschwinden 555 Bildpunkte in den Zeilen 300–319 (die Rauten), ohne die Kontaktschatten 418 andere (Zeilen
  318–401, der echte Fleck unter nahen Bäumen). Ursache: Fernbilder jenseits des Nebelendes sind reine Nebelfarbe vor
  den dunstigen Silhouetten des Hintergrunds. `billboard.gdshader` und `leaves.gdshader` blenden zwischen 0,85 und
  1,0 der Sichtweite mit geordnetem Dither aus; Bild `rauten_horizont_S1_vorher_nachher.png`.

### 2.6 Sitzung: ganze Etappe, Pause, Rückfall, Freigabe, Prozessende

- `tests/race3d/render/check_session_modern.gd` (neu, in `run_render_checks.sh`): `pause` – 30 Bilder in der Pause
  0 Bildpunkte verschieden, danach 132.660 (gemessen); `rueckfall` – `--gfx-debug=fail` mit echtem Selbsttest:
  `road_renderer.gd`, `gfx` arcade, `gfx_fallback` `selftest:debug`, 16:9 mit Balken; `freigabe` – nach der
  Modern-Etappe 55 Netze und geteilte Materialien, nach der Arcade-Etappe 0 Netze, 0 Texturen, keine geteilten
  Materialien.
- `RaceRenderers.leave_modern(always)` ist die eine Freigabe-Stelle (A-4); GameFlow ruft sie beim Wechsel aus den
  Menüs und beim Beenden (vorher hatten GameFlow und RaceRenderers je eine eigene Freigabe).
- Prozessende: `AudioManager` stoppt beim Beenden Motor, Schleifen und Einzelgeräusche und wartet 60 ms, bis der
  Audio-Server die Wiedergaben verworfen hat. Gemessen mit `--verbose` (Rennszene mit Bildaufnahme, die den Prozess
  beendet): vorher 2 von 3, 2 von 4, 2 von 5 Arcade-Läufen mit „3–9 ObjectDB instances leaked at exit“
  (`AudioStreamPlaybackWAV`, `AudioStreamWAV`, `AudioStreamGeneratorPlayback`); mit nur der Wartezeit noch 2 von 5;
  mit Stopp + Wartezeit **0 von 6 (Arcade), 0 von 3 (Modern)**.
- Ganze Etappe: siehe Gates (Fahrt unter Xvfb).

### 2.7 Prüfungen in den Läufern

- `tools/run_tests.sh`: `check_options_tabs.gd -- --graphics=arcade`, `check_attract.gd -- --graphics=modern`,
  `check_attract_scenes.gd -- --graphics=modern` (UI1); die neuen `tests/race3d/check_*.gd` nimmt der Haken mit.
- `tools/run_render_checks.sh` findet alle `tests/race3d/render/check_*.gd` über den Dateinamen (11 Dateien:
  facade, light_base, models, occlusion, props_render, road_parity, seam, session_modern, showroom, terrain_cover,
  vehicle_lights) – keine Änderung am Skript nötig.
- `check_light_base` → `schatten`: vergleicht beleuchtete, unbeschattete Flächen (Bildpunkte, die in einem Bild um
  > 0,04 dunkler sind, zählen nicht; mindestens 75 % des Bodens unbeschattet). Gemessen an S1: **−0,09 %** auf
  94,1 % des Bodens; das alte Maß (ganzer Boden) läge bei −1,69 % (5,6 % des Bodens im Schatten der Werfer).
- An den Stand nach AS1b angepasst: `props_spiegel` (Buche/Fels als Vertretungen statt Birke/Strohballen, die jetzt
  Modelle sind und sich drehen), `test_props.gd` (Varianten je Stück, Wandlampen, Tankdach, Flugbefeuerung,
  Bodendecker; Zeichenaufrufe je Set, Stück und Seite).
- Im ersten Gate-Lauf rot und an die Zusammenführung angepasst (Prüfungen, kein Spielcode): `check_vehicles`
  `lampen_fest` (die Etappe meldet jetzt eigene feste Lampen an – Grundlinie statt absoluter Zahlen),
  `check_models` `klassen` (das Bauernhaus von AS1b zeigt seine Anfahrtsseite auf +Z wie alle Requisiten, A-4 – die
  Prüfung dreht es nicht mehr um 180°), `check_occlusion` `lkw` (der Lichtkegel des verdeckten Autos beleuchtet seit
  der Lichter-Ebene zu Recht die Fahrbahn neben dem Sattelzug; die Prüfung gilt den Lampen und lässt die Kegel des
  Verkehrs weg).
- Im zweiten (letzten) Gesamtlauf rot: `check_modern_stage` → `kern_zeit` 0,618 ms (Grenze 0,6 ms; im ersten Lauf
  0,499 ms). Die Prüfung beschreibt den Renderer-Kern „ohne Fahrzeug-, Requisiten- und Gelände-Ebene“, maß seit der
  Zusammenführung aber alles, was `render()` jetzt aktualisiert. Neues Testdouble `tests/race3d/fixtures/core_renderer.gd`
  (Straße, Randausstattung, Hintergrund, Lichter, Overlay – wie R1 es ausgeliefert hat): Kern 0,194 ms allein,
  0,251 ms im Lauf der ganzen Datei, `check_modern_stage.gd` einzeln 7 von 7 OK (gemessen). Die Zeit des ganzen
  Renderers steht in den `perf_stats` der Etappe (Gates).

### 2.8 Zwei Fehler, die erst die Gates zeigten

- **Bremslicht in 150 m bei „Niedrig“** (`check_vehicle_lights` → `bremslicht` rot): „Niedrig“ ist die Voreinstellung
  für Software-Grafik und zeichnet das 3D-Bild mit 75 % (R1); R3s Prüfung lief ohne R1, also immer mit 100 %.
  Gemessen am selben Bild: 75 % Rot +0,07 in 150 m, 100 % +0,57, „Hoch“ +0,55 – die Leuchte fällt zwischen die
  Bildpunkte, der Lichtpunkt hatte die volle Stärke nur genau im Mittelpunkt. `flare.gdshader` hält die volle Stärke
  bis zu einer halben Bildpunkt-Diagonale des 3D-Bilds und behält den Radius: „Niedrig“ 50 / 150 / 300 m
  +0,60 / +0,16 / +0,33, 100 % +0,74 / +0,57 / +0,20, „Hoch“ +0,73 / +0,55 / +0,47 (gemessen). Bild
  `bremslicht_150m_niedrig_vorher_nachher.png`. Ehrlich: bei 75 % bleibt eine ferne Leuchte ein rötlicher Schein,
  nicht der klare rote Punkt von 100 %.
- **Kaltstart: 2 Shader-Varianten mitten in der Fahrt** (`warmup_cold.gd`, Kiel – Hamburg km 2, „Mittel“, 12 Uhr):
  376 Varianten vor dem Start, 2 nach 3,0 s. Eingegrenzt mit Mesas Quelltext-Ablage (`MESA_SHADER_DUMP_PATH`): kein
  neuer GLSL-Quelltext nach dem Ladebild, also Treiber-Varianten bekannter Programme; dieselben 2 auch ohne Verkehr
  (`--no-traffic`) und ohne HUD (`--no-hud`). Ursache: `props.gd warmup_nodes()` zeigte nur das erste Modell jeder
  Materialklasse, als MeshInstance3D. Jetzt jede Darstellung jedes geladenen Modells wie in `commit()` (MultiMesh,
  Schattenteile als Werfer): 389 Varianten vor dem Start, **0 während der Fahrt**, 48 statt 17 Aufwärm-Knoten; das
  Aufwärmen dauerte unter llvmpipe bei Last 7 rund 10 s länger (42 s statt 30–32 s).

## 3. Bilder und ehrliches Urteil

Alle mit `tools/ab_shot.sh` (derselbe Simulationszustand, 2 s nach fliegendem Start), Modern mit `--gfx-preset=high`,
Spielerauto Limousine (N1: Kompakt) – beide haben Modelle. Dateien im Abgabeordner `ab_<Position>_hoch.jpg`.

| Bild | Modern gegen Arcade |
|---|---|
| S1 km 2, Mittag | **besser**: Auto als Modell mit Klarlack und Kontaktschatten, echte Leitplanken mit Pfosten, Felder mit Getreideflächen, Eichen und Birken als Kartenbäume mit Schatten, drehende Windräder. Schwächer: zwischen Gelände und Hintergrund-Silhouetten ein heller Nebelstreifen (2–7 Zeilen), die Silhouetten 2 px tiefer als in Arcade |
| S2 Tankspur | gleichwertig bis besser bei Straße und Zapfsäulen; **schlechter**: das große Tankstellendach über der Tankspur fehlt (Stations-Builder R6), am rechten Rand steht ein grauer Pfeiler mit Platte (Teil des Tankstellenmodells) ohne Dach – wirkt unfertig |
| S3 km 60 | **besser**: große Eiche mit echtem Schatten, Felder, Windräder, Tiefe |
| S4 City Limits, Brücke | Häuser und Kran sind noch Arcade-Sprites (Vertretungen), Gehwegplatten und Bordsteine besser als Arcade; **schlechter**: Brücke, Geländer und Wasserkante fehlen (R5), das Wasser liegt als Fläche neben dem Gehweg |
| S5 Ziel | Gehwege und Schachbrett richtig; **schlechter**: Zielportal fehlt (R6), Häuser sind Vertretungen |
| T1 Bergab-Kurve | **besser**: echte Hügel, die Straße windet sich sichtbar ins Tal; Fichten sind Vertretungen (wie Arcade); Nebelstreifen am Horizont links |
| T2 Kuppe | Hang und Kuppe plastischer; **schlechter**: links (Kurveninnenseite) kahl – F7 nimmt die Bäume, die Bodendecker sind aus 3,4 m Augenhöhe kaum zu sehen |
| T4 R ≈ 136 m | Kurve und Gelände gut; **schlechter**: der große Felsen in der Kurve fehlt (F7, strenge Lesart), am Horizont ein heller Streifen wie eine Wasserfläche (Nebel des Fernbodens) |
| C1 19:30 | Abendlicht, Gehwege, Abblendlicht auf der Fahrbahn gut; Häuser Vertretungen; Laternen ohne den kräftigen Schein von Arcade |
| N1 Schnee, 22 Uhr | Abblendlicht-Kegel und Rücklichter gut; **schlechter**: kein Schneefall (Wetter-Ebene R4), der Schneeboden ist deutlich heller als in Arcade (Boden +21 … +42 %, Fahrbahn gleich 56,2 / 56,6, Himmel gleich – gemessen) |
| S4 nachts | Fenster leuchten, Fahrbahn unter den Laternen beleuchtet (16 Kegel); **schlechter**: die Leuchtenköpfe haben keinen Schein wie in Arcade, die Stadt wirkt weniger stimmungsvoll |
| S2 nachts | Laden und Zapfsäulen leuchten; das Tankdach über der Spur fehlt (R6); Gras nachts heller als Arcade |

**Gesamturteil**: Bei Tag auf freier Strecke (S1, S3, T1) ist Modern **klar besser** als Arcade – Gelände, Bäume,
Autos und Licht geben echte Tiefe. In den Städten, an Tankstelle, Brücke und Ziel ist es **noch nicht besser**,
teils schlechter, weil die Bauten der späteren Wellen fehlen (R5, R6) und die Häuser Arcade-Sprites sind. Nachts
fehlen Laternenschein und Wetter; der Boden ist nachts zu hell. Sichtbarer Kombinationsfehler, den ich nicht behoben
habe: der helle Nebelstreifen am Horizont (Abschnitt 6).

## 4. Abweichungen

1. **Varianten je Stück** statt je Requisite (§4.6.6 nennt „segment index and prop index“): sonst kostet jede Variante
   eigene Knoten und Zeichenaufrufe (Auftrag: „variants per chunk by a stable hash“).
2. **„≤ 2 Zeichenaufrufe je Set und Stück“** gilt je Seite: AS1bs Häuser haben zwei Flächen (`baked` + Scheiben in
   `vpbr`), auf beiden Straßenseiten mit dem gespiegelten Knoten (D24) also 4 je Stück (gemessen im Unit-Test).
3. **Bodendecker** nur für weggelassene **Pflanzen** und nicht in den City Limits; Felsen und Häuser einer
   Landschaftsregel bleiben im Korridor weggelassen (Leitentscheidung offen bis Zwischenstand 2).
4. **Spiegelquelle**: der analytische Himmel (R3) statt des `Sky` der Umgebung (D7) für Lack, Glas und alles in
   `vpbr`; Fahrbahn, Gelände und Requisiten behalten den `Sky` (gemessen, §12.2 der Renderer-Doku).
5. **Rotor im Uhrzeigersinn** (Vorzeichen des Winkels negativ) statt AS1bs `+ce_time` – sonst von der Straße aus gegen
   den Uhrzeigersinn, anders als echte Anlagen.
6. **Ende der Sicht**: Fernbilder und Laub blenden zwischen 0,85 und 1,0 der Sichtweite aus (vorher reine Nebelfarbe
   vor den Silhouetten). Arcade blendet seine Sprites ähnlich aus; F4 betrifft das nicht (kein stärkerer Nebel).
7. **Lampen der Requisiten**: Gruppen teilen sich Arcades Tankstellenlicht, Wandlampen bekommen 5 m vor der Wand,
   Flugbefeuerung keinen Kegel – A-7 nennt nur `range`/`energy` je Lampe, keine Regel dafür.
8. **`scripts/audio/audio_manager.gd`** geändert (Stopp und 60 ms beim Beenden, AU-B-Hinweis), obwohl die Datei in
   diesem Schub keinem Paket gehört – der Auftrag verlangt saubere Prozessenden; nur `_exit_tree()`.
9. **`tools/run_render_checks.sh` nicht geändert**: es findet alle `tests/race3d/render/check_*.gd` selbst; neu ist
   `check_session_modern.gd` (Pause, Rückfall, Freigabe), `check_props_render.gd` hat die Prüfung `rotor` dazu.
10. **Dateien anderer Pakete für Fehler der Zusammenführung**: `flare.gdshader` (R3: volle Stärke bis zu einer halben
    Bildpunkt-Diagonale, 2.8), `props.gd warmup_nodes()` (R2: je Modell statt je Klasse, 2.8) und die Prüfungen
    `check_vehicles` `lampen_fest`, `check_models` `klassen`, `check_occlusion` `lkw`, `check_modern_stage`
    `kern_zeit` (2.7) – keine Datei aus der R3E-Liste außer der einen Zeile `vehicle_shadow`.
11. **`tools/run_tests.sh` zweimal, beide Male mit einer roten Prüfung** (1.: `lampen_fest`, 2.: `kern_zeit`, beide
    Prüfungen der Zusammenführung angepasst); ein dritter Gesamtlauf war nicht erlaubt – `check_modern_stage.gd`
    lief danach einzeln grün.

## 5. Probleme im Bauplan

1. **§4.6.6 vs. Zeichenaufruf-Budget**: Varianten je Requisite und ≤ 2 Aufrufe je Set und Stück widersprechen sich;
   mit zwei Flächen und beiden Seiten (D24) sind es 4. Vorschlag: Budget „je Set, Stück und Seite“, Varianten je
   Stück (so umgesetzt).
2. **D7 (Sky als Spiegelquelle für Lack und Glas)**: im Rennen spiegelten Sky und R3s analytischer Himmel doppelt
   (+3 … +11 Stufen am Auto); der Sky fehlt bei „Effekte: Aus“. Umgesetzt: analytisch für `vpbr`/`glass`, Sky für den
   Rest – der Bauplan sollte das so festhalten.
3. **Horizont**: Fernboden-Kragen und Leinwand unter der Horizontzeile sind laut D16/R1/R2 reine Nebelfarbe; Arcade
   zeigt bei klarem Wetter Gras bis zur Horizontzeile (gemessen an S1: Arcade Zeilen 321 ff. 91/149/61, Modern Zeilen
   324–329 197/219/237). Das ergibt einen hellen Streifen unter den Silhouetten (an T4 wie eine Wasserfläche) – mehr
   „Nebel“ als Arcade an derselben Bildstelle (Geist von F4). Braucht eine Bildentscheidung (Fernboden bei klarer
   Sicht nicht bis zur reinen Nebelfarbe).
4. **A-4 / §4.11 „leaving Modern“** hatte zwei Eigentümer im Code (GameFlow und RaceRenderers); jetzt eine Stelle
   (`RaceRenderers.leave_modern(always)`).
5. **§4.9.4 Bildzeit-Regel** bleibt lastabhängig (R1); gezählt habe ich zusätzlich die übersetzten Varianten.
6. **Prozessende-Lecks** stammen auch aus Arcade (gefroren: `EngineAudio`); behoben in `AudioManager`, nicht in der
   gefrorenen Datei.
7. **3D-Auflösung und Fahrzeuglichter**: „Niedrig“ zeichnet mit 75 % (Voreinstellung für Software-Grafik), der
   Bauplan verlangt zugleich, dass keine Stufe Fahrzeuglichter abdunkelt. Er sollte sagen, dass Lichtpunkte gegen die
   3D-Auflösung abgesichert sein müssen, und die Render-Prüfungen der Pakete liefen bisher mit der Voreinstellung der
   Maschine (llvmpipe → „Niedrig“) – R3 ohne R1 also mit 100 %. Vorschlag: Lichter-Prüfungen bei „Niedrig“ und „Hoch“.
8. **Aufwärmen „je Shader-Variante ein Knoten“** (§9 Haken, D10) reicht nicht: Treiber übersetzen auch je
   Texturformat und Vertex-Aufbau. Vorschlag: „jede Darstellung jedes geladenen Modells, so wie sie gezeichnet wird“.

## 6. Für RINT-B und die nächsten

1. **Horizontstreifen** (Problem 3): Entscheidung und kleine Shader-Änderung im Fernboden (Nebel deckeln bei klarer
   Sicht) oder Silhouetten tiefer; danach `check_terrain_cover` und A/B S1, T1, T4.
2. **Laternen nachts**: Kegel und Lichtpunkte sind da, aber der Schein am Leuchtenkopf ist schwach (Halo-Anteil 0,35
   nah); Arcade wirkt in S4 nachts stimmungsvoller – `layers/flares.gd` (`STATIC_HALO`) oder Glow abstimmen (R4).
3. **Nachtboden zu hell**: N1 Schneeboden +21 … +42 % gegen Arcade (Fahrbahn gleich), S2 nachts Gras heller – R1s
   Lichtgesetz für den Nachtboden, Nachtabgleich in R4.
4. **R3E/AS1R zusammenführen**: in `layers/vehicles.gd` habe ich nur `material("vehicle_shadow")` geändert; `vpbr`
   und `glass` tragen jetzt den Ein-Quellen-Pfad (env_energy > 0) – AS1R stimmt Glas mit `mirror` ab, das im Rennen
   nur noch die analytische Spiegelung skaliert.
5. **Vorschaubilder** der Grafikwahl (`tools/gfx_previews.sh`, UI1) erst nach R3E/AS1R neu erzeugen.
6. **Tankstelle**: `props/fuel_station` und `fuel_pump` zeichnet heute der Requisiten-Builder; das Dach über der
   Tankspur fehlt bis R6 – an S2 steht ein Pfeiler mit Platte am Rand (Teil des Modells), wirkt unfertig.
7. **F7 an T2/T4**: Bodendecker sind aus 3,4 m kaum zu sehen; Felsen/Häuser im Korridor entscheidet die Leitung mit den
   Bergbildern.
8. **`docs/renderer-modern.md` §12** beschreibt alles aus dieser Zusammenführung; ARCHITECTURE.md §15 (DOC, Welle 8):
   `RaceRenderers.leave_modern(always)`, `quality_lowered`, `gfx_lowered`.
9. **Ferne Heckleuchten bei 75 %** (R3E): mit dem Lichtpunkt sichtbar (+0,16 Rot in 150 m), aber nur ein rötlicher
   Schein, kein klarer roter Punkt wie bei 100 %; ein Leuchtenkern von einem Bildpunkt (wie beim Blinker) wäre der
   nächste Schritt. Das Aufwärmen je Modell kostet unter llvmpipe rund 10 s mehr Vorbereitung – auf dem Deck messen.

## 7. Geänderte Dateien (seit 2b41e16 ohne die Merges)

Beim Auflösen der Konflikte (Merge-Commit von R3): `assets/shaders/modern/vehicle_shadow.gdshader` (R3s Datei unter
neuem Namen), `scripts/race3d/layers/vehicles.gd` (eine Zeile: Klasse `vehicle_shadow`), `docs/renderer-modern.md`
(§10 R1, §11 R3).

Danach (10 Commits, a27d3ed … fd27c16):

| Bereich | Dateien |
|---|---|
| Shader | `assets/shaders/modern/{terrain, far_ground, vpbr, glass, billboard, leaves, flare}.gdshader`, `vehicle_shadow.gdshader.uid` |
| Renderer | `scripts/race3d/terrain_profile.gd` (3 Kernzeilen), `builders/terrain.gd`, `builders/props.gd`, `layers/far_ground.gd`, `layers/lights.gd`, `prop_library.gd` |
| Sitzung, Audio | `scripts/race/race_renderers.gd` (`leave_modern`), `scripts/ui/game_flow.gd`, `scripts/audio/audio_manager.gd` (`_exit_tree`) |
| Konfiguration | `config/game_config.json` (`graphics.modern.props`, Doku-Text) |
| Prüfungen | `tests/race3d/check_terrain_plan.gd` (STRICT), `tests/race3d/check_vehicles.gd`, `tests/race3d/check_modern_stage.gd` (`kern_zeit`), neu `tests/race3d/fixtures/core_renderer.gd` (+ .uid), `tests/race3d/render/{check_light_base, check_models, check_occlusion, check_props_render}.gd`, neu `tests/race3d/render/check_session_modern.gd` (+ .uid), `tests/unit/race3d/test_props.gd`, `tools/run_tests.sh` |
| Doku | `docs/renderer-modern.md` §1 und §12, `docs/renderer-modern-gelaende.md`, `docs/modelle.md` |

Nicht angefasst: die gefrorenen Arcade-Dateien, `assets/models/player/**`, `assets/models/traffic/**`; aus der
R3E-Liste nur die eine Zeile in `layers/vehicles.gd`.
