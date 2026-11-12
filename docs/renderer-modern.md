# Modus „Modern“ – Renderer: Weltmodell, Kamera, Fairness

Technische Dokumentation des Geometrie-Kerns des echten 3D-Renderers (v0.8.0). Eigentum: `scripts/race3d/{road_path,
chase_camera, terrain_profile, chunk_context, chunk_builder, chunk_streamer, builder_registry}.gd`,
`scripts/race3d/builders/debug_road.gd`, `tests/unit/race3d/*`, `tests/race3d/{fairness, synthetic_track}.gd`,
`tests/sim/modern_*.gd`. Der Bauplan steht in [dev/v080_contract.md](dev/v080_contract.md) (§3.2, §3.3, §4.5); hier steht,
wie der Kern funktioniert, was gemessen wurde und woran man dreht. Den Aufbau des Renderers selbst – die Fassade,
über die Ebenen und Builder eingehängt werden, ihre Haken, die eingebaute Umgebung und das Bildwerkzeug – beschreibt
[Abschnitt 9](#9-aufbau-fassade-ebenen-haken); den Renderer-Kern mit Straße, Umgebung, Licht, Qualität und Aufwärmen
[Abschnitt 10](#10-renderer-kern-straße-umgebung-licht-qualität); Gelände und Fahrzeuge ergänzen die
Renderer-Bauabschnitte.

Zahlen mit „gemessen“ stammen von dieser Entwicklungsmaschine (headless bzw. Mesa llvmpipe unter Xvfb, 4 geteilte
Kerne); „abgeleitet“ heißt gerechnet, nicht gemessen. Zeiten auf einer echten Grafikkarte sind hier nicht messbar.

## 1. Dateien und Klassen

| Datei | Klasse | Aufgabe |
|---|---|---|
| `scripts/race3d/road_path.gd` | `RoadPath3D` | echter Weltpfad der Strecke: Mittellinie aus den Kurvenwerten integriert, schwimmender Ursprung, Talsohle, freie Breite (Mittelachse) |
| `scripts/race3d/chase_camera.gd` | `ChaseCamera3D` | Verfolgerkamera = Arcades Projektion plus Blick in die Kurve; reine Mathematik, kein Knoten |
| `scripts/race3d/terrain_profile.gd` | `TerrainProfile` | Gelände als Band neben der Straße: Ringabstände, Höhen, Sichtkorridor – reine Zahlen |
| `scripts/race3d/chunk_context.gd` | `ChunkContext` | Schnappschuss eines Straßenstücks (33 Reihen) für die Builder, mit `local()`, `frame()`, `ground()` |
| `scripts/race3d/chunk_builder.gd` | `ChunkBuilder` | Basisklasse aller Builder: `collect` → `build` (Arbeiter-Thread) → `commit` |
| `scripts/race3d/chunk_streamer.gd` | `ChunkStreamer` | lädt und entlädt Stücke nach Wegstrecke, besitzt ihre Knoten und Transformationen |
| `scripts/race3d/builder_registry.gd` | `BuilderRegistry` | feste Liste aller Builder und Ebenen; fehlende Dateien werden übersprungen |
| `scripts/race3d/builders/debug_road.gd` | – | einfache Straße mit Geländeringen in Eckpunktfarben: Vertretung für `builders/road.gd`, Beispiel der Builder-Regeln |
| `tests/race3d/fairness.gd` | – | Fairness- und Weltprüfungen als reine Funktionen (Pfad, Sichtkegel, Kuppen, Sichtkorridor) |
| `tests/race3d/synthetic_track.gd` | – | künstliche `Track` mit vorgegebenen Kurven und Höhen für Tests |
| `tests/sim/modern_sight.gd` | – | Fairness-Prüfung F1–F3, F7 (läuft in `tools/run_tests.sh` über den Haken für `tests/sim/modern_*.gd`) |
| `tests/sim/modern_path_check.gd` | – | Weltprüfung: Abstand des Pfads zu sich selbst (läuft ebenso in `tools/run_tests.sh`) |
| `tests/unit/race3d/test_*.gd` | – | Unit-Tests: Pfad, Kamera, Geländeprofil, Stücke, die Prüfungen selbst |
| `scripts/race3d/modern_renderer.gd` | `ModernRenderer` | das Gerüst des Renderers: Naht zur Sitzung, Fassade für Ebenen und Builder, Vorbereitung über mehrere Bilder (Abschnitt 9) |
| `scripts/race3d/plain_environment.gd`, `plain_sky.gd` | – | eingebaute Umgebung und eingebauter Himmel, solange `environment_rig.gd` bzw. `layers/backdrop.gd` fehlen (9.6) |
| `assets/shaders/modern/inc/pools.gdshaderinc` | – | Lichtkegel der Fahrbahn- und Geländematerialien (9.7) |
| `tools/ab_shot.sh` | – | derselbe Simulationszustand in Arcade und Modern nebeneinander (9.8) |
| `tests/race3d/check_facade.gd`, `tests/race3d/render/check_facade_render.gd`, `tests/race3d/fixtures/facade_*.gd` | – | Prüfungen der Fassade mit Prüf-Ebene, Prüf-Builder und Prüf-Renderer (9.9) |
| `scripts/race3d/builders/road.gd`, `assets/shaders/modern/road.gdshader` | – | die Fahrbahn mit aller Markierung im Shader (10.2) |
| `scripts/race3d/builders/roadside.gd` | – | Leitplanken mit Pfosten und Rückstrahlern, Leitpfosten (10.3) |
| `scripts/race3d/environment_rig.gd` | – | Sonne bzw. Mond mit Schatten, Umgebungslicht, Nebel, Himmel als Spiegelquelle, `ce_*`-Globals (10.4) |
| `scripts/race3d/layers/backdrop.gd`, `lights.gd`, `overlay.gd` | – | Hintergrund auf Canvas-Ebene −10, Abblendlicht und Lichtkegel, Verfolgungslichter (10.5–10.7) |
| `scripts/race3d/quality.gd`, `perf_probe.gd`, `prewarm.gd` | – | Qualitätszustände des Viewports, Bildzeit-Sonde und Wächter, Aufwärmen der Shader (10.8) |
| `scripts/race3d/builders/terrain.gd`, `props.gd`, `layers/far_ground.gd`, `prop_library.gd`, `ground_look.gd` | – | Gelände, Requisiten, Fernboden – eigene Dokumentation: [renderer-modern-gelaende.md](renderer-modern-gelaende.md) |
| `scripts/race3d/layers/vehicles.gd`, `flares.gd`, `builders/signs.gd`, `vehicle_pose3d.gd`, `sign_atlas.gd` | – | Fahrzeuge, Lichtpunkte, Schilder (Abschnitt 11) |
| `scripts/race3d/builders/tunnel.gd`, `station.gd`, `gantry.gd`, `assets/shaders/modern/tunnel.gdshader`, `inc/fog_law.gdshaderinc` | – | Mindestbauten bis M2 (Tunnelröhre, Tankstelle, Start-/Zieltor) und Arcades Nebelgesetz für alles in der Landschaft (Abschnitt 14) |

Nichts davon wirkt auf die Simulation zurück: der Kern liest `Track`, `RoadProjection` und die Konfiguration, mehr nicht.

## 2. Koordinaten

- **Straßenkoordinaten** (wie überall im Spiel): `z` entlang der Straße in sichtbaren Metern, `x` seitlich
  (+ rechts), `h` über der Fahrbahn.
- **Welt** = Godot: +X rechts, +Y oben, Richtung 0 blickt entlang **−Z**; eine positive Kurve dreht nach rechts.
  `fwd(a) = (sin a, 0, −cos a)`, `right(a) = (cos a, 0, sin a)`. Richtung 0 ist die Richtung des ersten integrierten
  Segments.
- **Höhen**: die Segmenthöhen der `Track`, wie sie sind (`render.hill_height_scale` steckt schon darin).
- **Stück-lokal**: relativ zur Straßenmitte der ersten Reihe eines Stücks (`ChunkContext.rows_o[0] = 0`).
- **Grenze k** = Anfang von Segment k (`z = k · 3 m`). Ein Stück hat die Reihen `seg_a … seg_b` (33 Grenzen); die
  letzte Reihe ist die erste des nächsten Stücks.

## 3. Weltmodell: der echte Pfad (`RoadPath3D`)

### 3.1 Integration

Arcade schert die Straße nur seitlich (`x += dx; dx += curve · seg² / R1`). Modern legt sie wirklich in die Welt: je
Segment dreht sich die Richtung um `curve / road.curve_radius_at_1_m · 3 m`, die Grenze wandert 3 m in die mittlere
Richtung des Segments (Mittelpunktsregel).

| Messung (gemessen) | Wert |
|---|---|
| Kreisbogen R = 134 m über 900 m gegen die geschlossene Form | höchstens 5,59 mm (verlangt ≤ 1 cm) |
| Kreisbogen R = 400 m über 900 m | höchstens 1,68 mm |
| Segmentmitte (`centre_at`) gegen den Bogen | Pfeilhöhe 3² / 8R = 8,4 mm bei R = 134 m (abgeleitet), im Test ≤ 16 mm mit Randfehler |

`centre_at(z)`, `world(z, x, h)` und `frame_at(z, x, h)` interpolieren innerhalb eines Segments linear zwischen den
beiden Grenzen – genau die gerade Kante, die ein aus den Reihen gebautes Netz hat. `world()` und
`ChunkContext.local()` rechnen dieselbe bilineare Formel; ein mit `world()` gesetztes Fahrzeug steht also auf der
Fahrbahn, die ein Builder mit `local()` gebaut hat (Test: ≤ 1 mm).

### 3.2 Die Welt stimmt nur lokal

Der echte Pfad kreuzt sich bei 8 Etappenrichtungen selbst (2,5–6,6 km Weg auseinander, siehe 3.7). Deshalb:

- Geladen wird **streng nach Wegstrecke**; jedes Stück Welt gehört seinem Stück und verschwindet mit ihm.
- **Keine Welt-Caches, kein Weltraster.** Alles, was „in der Nähe“ sucht, sucht entlang des Pfads.
- Die drei **Builder-Regeln** (sie halten auch den Rückfall auf die gescherte Abbildung möglich, Bauplan §8):
  1. Jede Position kommt aus `ChunkContext.local()` / `frame()` / `ground()` (im Hauptthread auch aus `RoadPath3D`).
  2. Nie annehmen, die Transformation eines Stückknotens sei fest; keine Weltpositionen merken.
  3. Starre Instanzen (Requisiten, Schilder, Bauwerke) stehen über `ChunkContext.frame()`.

### 3.3 Schwimmender Ursprung

Positionen liegen intern in doppelter Genauigkeit relativ zur ersten Grenze; nach außen gehen nur Werte relativ zum
schwimmenden Ursprung (32-Bit-Vektoren). `rebase(index)` verlegt ihn und liefert die Verschiebung, die damit auf
alle Positionen wirkt (`neu = alt + Verschiebung`; Höhen ändern sich nicht). Der `ChunkStreamer` verlegt, sobald die
Kamera mehr als `rebase_m` (2 km) vom Ursprung entfernt ist, setzt seine Stückknoten um und meldet es mit dem Signal
`rebased(shift)` – alles, was der Renderer sonst in Weltkoordinaten hält, muss dieselbe Verschiebung bekommen
(Kamera, Fahrzeuge und Lichter werden ohnehin jedes Bild aus dem Pfad gerechnet).

| Messung (gemessen, künstliche 42-km-Strecke, bis 22 km vom Start) | Wert |
|---|---|
| größter Positionsfehler mit Ursprung alle 2 km | 0,13 mm (verlangt ≤ 1 mm) |
| Sprung beim Verlegen (`neu` gegen `alt + Verschiebung`) | 0,14 mm |
| größter Positionsfehler ohne Verlegen | 1,06 mm |
| größte Koordinate eines echten Pfads ab seinem Start (Belgrad – Budapest ab Budapest; `modern_path_check.gd -- --full`) | 37,8 km → 3,9 mm Raster der 32-Bit-Zahlen ohne Verlegen (abgeleitet) |

### 3.4 Talsohle (`floor_y`)

`floor_y(k)` = tiefste Fahrbahn innerhalb von ±`floor_window_m` (900 m) Weg, minus `floor_drop_m` (4,5 m). Sie liegt
nie über der Fahrbahn und kann deshalb nichts verdecken. Das Geländeband endet außen auf ihr (Abschnitt 5).
`floor_rows(a, b)` liefert dieselben Werte für eine Reihenfolge in einem Durchgang (gleitendes Minimum).

### 3.5 Freie Breite (`clearance`)

`clearance(k, seite)` = Abstand von der Straßenmitte, bis zu dem der Querschnitt der Reihe k auf einer Seite reichen
darf, bevor sein Boden näher an einem **anderen** Teil der Straße liegt: die Mittelachse gegen jede Grenze innerhalb
von ±`clear_reach_m` Weg. Auf der Innenseite einer Kurve ist das ihr Radius (die Querschnitte treffen sich im
Mittelpunkt); neben einem zweiten Straßenast der halbe Abstand zu ihm; auf freier Strecke `clear_max_m`.
Ausgewertet wird jede 8. Reihe (24 m) gegen jede 8. Grenze, dazwischen linear; die Werte werden gemerkt.

`clear_reach_m` setzt der Streamer auf die größte Wegstrecke zwischen zwei Stücken, die gleichzeitig geladen sein
können: `load_path_m + keep_behind_m + 2 Stücke` = 1.842 m. Der Wert ist eine reine Funktion der Straße um die Reihe
herum: zwei Stücke, die sich eine Reihe teilen, bekommen dieselbe Zahl (Test).

### 3.6 Die Strecke wird vorauserzeugt

`ensure(index)` liest die Segmente aus der `Track` und zwingt damit deren Erzeugung voraus. Der Streamer hält den
Pfad in jedem Bild `load_path_m + 1 Stück + clear_reach_m` = **3.438 m vor der Kamera** (der Bauplan nennt 1.900 m;
für die beidseitig gleiche Mittelachse braucht es mehr – ein Stück muss jeden Straßenteil kennen, der später
gleichzeitig mit ihm geladen sein kann). Er wächst je Bild um höchstens ein Segment, nicht stoßweise.

Das ist unschädlich, weil der Generator sequenziell arbeitet und sein Fenster nur hinter der Kamera gekürzt wird.
Gemessen:

| Prüfung (gemessen) | Ergebnis |
|---|---|
| `run_stage.gd` mit dem echten `ChunkStreamer` neben der Arcade-Sitzung, dev_testetappe (Nacht, Regen) | `ERGEBNIS` identisch; Streckenfenster bis 1.201 Segmente, Pfad bis 3.406 m voraus |
| dasselbe, Saragossa – Pau (Schnee) | identisch; bis 1.207 Segmente, 3.425 m voraus |
| dasselbe, Kiel – Hamburg | identisch; bis 1.060 Segmente, 2.984 m voraus |
| Erzeugung jedes Bild 4.500 m voraus erzwungen, dev_testetappe | identisch |
| Unit-Test: Strecke über den Streamer gegen schrittweise Erzeugung wie in Arcade (Kassel – Würzburg, 7 km) | Kurve, Höhe, Spuren und Requisiten jedes verglichenen Segments gleich |

Schilder werden nachträglich in schon erzeugte Segmente eingefügt (Kurven- und Kuppenwarnung, bis
`Track.generation_lead_m()` = 600 m zurück). Ein Stück wird deshalb erst eingesammelt, wenn die Strecke so weit hinter
seinem Ende erzeugt ist; sein Schnappschuss enthält die Schilder (Test).

### 3.7 Prüfung `tests/sim/modern_path_check.gd`

Der Pfad darf sich innerhalb dessen, was zugleich geladen ist, nicht nahe kommen – sonst lägen Gelände und
Requisiten zweier Straßenteile ineinander.

| Prüfung | Regel | Ergebnis (gemessen, 128 Etappenrichtungen, 3.017 km sichtbare Straße, Punkte alle 12 m) |
|---|---|---|
| `modern_path_clearance` | zwei Punkte 360 … 1.900 m Weg auseinander liegen ≥ 250 m Luftlinie auseinander | kleinster Abstand **267,6 m** (Bukarest – Sibiu ab Sibiu, km 57,8, nach 360 m Weg); unter 300 m: 2.232 m Straße = 0,074 %, 7 Etappenrichtungen; unter 250 m: keine |
| `modern_path_loops` | eine Annäherung unter 250 m jenseits davon erst ab 2.000 m Weg | früheste nach 2.064 m (Bukarest – Sibiu ab Sibiu) |

Schleifen (1.100 … 8.000 m Weg auseinander, Punkte alle 24 m): 9 Etappenrichtungen unter 300 m, 8 kreuzen sich
(3,9 m Erfurt – Kassel ab Erfurt nach 2.688 m Weg, 4,1 m Sibiu – Timișoara ab Sibiu nach 6.336 m, 4,7 m und 4,8 m
San Sebastián – Burgos, 8,7 m Bordeaux – San Sebastián, 9,2 m und 10,4 m Saragossa – Pau, 11,0 m Bukarest – Sibiu ab
Sibiu nach 2.544 m). Die Zahlen sind dieselben wie in der Entwurfsstudie.

Der 360-m-Anfang ist die Sehne über eine einzelne enge Kurve: 267,6 m ist die Sehne über 360 m Bogen der engsten
Kurve (R ≈ 134 m), kein zweiter Straßenast. Eine künftige Etappe, die eine Prüfung verfehlt, bekommt einen anderen Seed.

Im normalen Lauf (24–25 s gemessen) werden die 74 Etappenrichtungen nicht erzeugt, deren Kurven dafür zu weit sind
(Kurvigkeit ≤ 1: R ≥ 400 m): Nach dem Bogensatz von Schwarz ist ein Bogen mit Krümmung ≤ 1/R zwischen zwei Punkten
im Abstand d entweder höchstens so lang wie der kurze oder mindestens so lang wie der lange Kreisbogen vom Radius R
durch sie – für d = 250 m und R = 400 m also ≤ 254 m oder ≥ 2.259 m, nie 360 … 2.000 m. `--full` rechnet alle 128 und
bestätigt die Schranke (53–56 s gemessen).

## 4. Stücke

### 4.1 Laderegel (`ChunkStreamer`)

Ein Stück = `chunk_segments` (32) Segmente = 96 m. Es ist **gewünscht**, wenn seine nahe Kante höchstens
`load_path_m` (1.500 m) Weg voraus liegt **und** höchstens Sichtweite + 96 m Luftlinie entfernt ist; das Stück unter
der Kamera und die dahinter immer. **Frei** wird es, sobald seine ferne Kante mehr als `keep_behind_m` (150 m) hinter
der Kamera liegt. Gehalten werden höchstens `max_chunks` (16, `graphics.modern.max_chunks` in
`config/game_config.json`).

Die Laderegel allein will in engen Bergstrecken mehr (gemessen bei 900 m Sicht, Kamera alle 96 m, 31.488 Positionen):
an 38 Positionen 17 und an 171 Positionen 18 Stücke – zusammen 209 Positionen (0,66 %) in zwölf Etappenrichtungen.
Dann warten die **nach Luftlinie fernsten**. Das nächste ausgelassene Stück liegt an 135 dieser Positionen 800 m und
weiter entfernt (im dichten Nebel am Ende der Sichtweite), an 45 bei 700–800 m, an 18 bei 600–700 m, an 8 bei
500–600 m und an 3 unter 500 m (das nächste: 456 m, Saragossa – Pau ab Pau km 42,2). An diesen 29 Positionen kann eine
Lücke in der Ferne zu sehen sein, bis die Kamera ein Stück weiter ist. Mit `graphics.modern.max_chunks = 18` wird
nirgends im Netz etwas ausgelassen – zu entscheiden mit dem Zeichenbudget.

Bei 900 m Sicht sind auf gerader Strecke 13–14 Stücke geladen, im Tunnel (360 m) deutlich weniger.

### 4.2 Ablauf je Stück

1. **collect** (Hauptthread): `ChunkContext.capture()` – Schnappschuss von Segmenten, Reihen, Gelände – und
   `ChunkBuilder.collect(ctx)` jedes Builders für das, was er darüber hinaus braucht.
2. **build** (`WorkerThreadPool`, im Sync-Modus Hauptthread): `ChunkBuilder.build(ctx, input)` – nur Arrays und
   einfache Daten; keine Knoten, keine Ressourcen, keine Autoloads, keine `Track`, kein `ctx.path` / `ctx.terrain`.
3. **commit** (Hauptthread): `ChunkBuilder.commit(ctx, part, parent)` hängt Netze und Knoten unter den Stückknoten;
   erst danach kommt der Stückknoten in den Baum.

Je Bild gibt es höchstens einen Hauptthread-Auftrag: ein Bild, das ein Stück einsammelt, hängt keines ein; sonst
höchstens `commits_per_frame` (1). Das erste `update()` nach dem Start oder einem Kamerasprung lädt alles Gewünschte
sofort (hinter dem Ladebild). Mit `sync = true` (`--gfx-sync`, Tests) baut und hängt jedes `update()` alles sofort im
Hauptthread ein – das Ergebnis hängt dann nur von der Kameraposition ab.

Kamerasprünge: liegt die Kamera noch im integrierten Pfad, läuft der Streamer weiter; liegt sie dahinter, baut er
neu auf. Liegt sie hinter allem, was die `Track` noch hält (rückwärts gibt es nichts), bleibt die älteste Straße
geladen. `snapshot()` liefert einfache Daten für `debug_snapshot()` (Stücke mit `index`, `seg_a`, `seg_b`, `state`,
`pos`, `parts`), `stats()` die Zeiten für `perf_stats()`, `flush()` baut und hängt alles Offene sofort ein.

| Messung (gemessen, headless, Debug-Straße mit Geländeringen = 2.176 Eckpunkte je Stück, echte Landschaftsdaten) | Wert |
|---|---|
| Einsammeln je Stück (Hauptthread) | im Mittel 0,85–1,26 ms, höchstens 2,0 ms |
| davon `TerrainProfile.rows()` | 0,77 ms |
| `clearance` einer Stützreihe (beide Seiten, ±1.842 m Weg) | 19 µs |
| Bauen der Debug-Straße je Stück | im Mittel 1,6–2,5 ms im Hauptthread, 2,2–3,3 ms auf einem Arbeiter-Thread |
| Einhängen der Debug-Straße | im Mittel 0,06–0,10 ms, höchstens 0,25 ms |
| `update()` je Bild (Threads, 120–250 km/h) | im Mittel 0,01–0,07 ms, p95 0,03–0,19 ms, p99 0,07–1,2 ms, höchstens 1,0–4,0 ms |
| `update()` je Bild (Sync-Modus) | im Mittel 0,02–0,08 ms, höchstens 3,5–8,2 ms (Einsammeln, Bauen und Einhängen in einem Bild) |
| erstes `update()` (12 Stücke, dazu 3,4 km Strecke erzeugen; Kiel – Hamburg km 2) | 77–114 ms |

### 4.3 `ChunkContext`

Schnappschuss im Hauptthread, danach unveränderlich: `segs` (jedes Feld jedes `TrackSegment`, `sprites` tief kopiert),
`rows_o` / `rows_r` / `rows_f` / `rows_heading` (Straßenmitte, Rechts- und Vorausvektor, Richtung je Reihe),
`rows_edge` (Fahrbahnränder), `floor_y` (Talsohle, stück-lokal), `rings`, `ring_x`, `ring_h`, `corridor` (Gelände),
dazu `seg_len`, `lane_w`, `shoulder_w`, `length_z`, `cfg`, `scenery_db`, `levels`, `sync`.
`path`, `terrain` und `track` sind **nur im Hauptthread** erlaubt (`collect`, `commit`).

| Funktion | liefert |
|---|---|
| `local(z, x, h)` | Straßenkoordinaten → stück-lokal (bilinear zwischen zwei Reihen) |
| `frame(z, x, h, yaw_rad)` | starrer Rahmen: +X rechts, +Y oben, −Z = Straßenrichtung bei z; `yaw_rad` dreht wie eine Straßenrichtung nach rechts; nur Gieren |
| `ground(z, x)` | Höhe des Bodens relativ zur Fahrbahn bei z – der Wert für `h`: 0 auf Fahrbahn und Bankett, daneben das Geländeband |
| `heading(z)`, `row_of(z)` | Straßenrichtung, Reihe als Kommazahl |
| `shoulder_edge(reihe, seite)`, `ring_offset(…)`, `ring_height(…)`, `ribbon_width(z, seite)` | Bankettkante ab Mitte, Ringe, Breite des Bands |
| `in_corridor(z, x)` | liegt im Sichtkorridor (kein Boden über der Fahrbahn) |
| `in_bend_corridor(z, x)` | liegt im Sichtkorridor einer Kurveninnenseite – dort steht keine schmückende Vegetation |

Eine Requisite auf dem Boden: `ctx.frame(z, x, ctx.ground(z, x))`.

### 4.4 Einen Builder schreiben

Datei `scripts/race3d/builders/<name>.gd` mit einem der Namen aus 4.5, `extends ChunkBuilder`, `id()` = Dateiname.
Ein Builder hält keinen Zustand je Stück in sich – `build()` läuft für mehrere Stücke gleichzeitig. Die Debug-Straße
(`builders/debug_road.gd`) ist das Muster: Eckpunkte nur aus `ctx.local()`, im `commit()` ein `ArrayMesh`, in
`debug()` Zähler und Prüfsumme.

### 4.5 `BuilderRegistry`

Feste Reihenfolge; eine Datei, die es (noch) nicht gibt, wird übersprungen – ein Bauabschnitt legt nur seine Datei
ab und ändert die Liste nie.

| Builder (`scripts/race3d/builders/`) | Inhalt |
|---|---|
| `road` | Asphalt, Bankette, Bordsteine, Gehwege, Tankspur; alle Markierungen im Straßen-Shader |
| `roadside` | Leitplanken, Pfosten, Reflektoren, Leitpfosten |
| `terrain` | Geländeringe, Kante zur Talsohle |
| `props` | Landschafts-Requisiten als MultiMesh (und Sprite-Vertretungen) |
| `signs` | Schilder auf Pfosten und an Tunnelwänden |
| `tunnel` | Röhre, Gehwege, Lampen, Nischen, Portal, Hügel |
| `bridge` | Fahrbahnplatte, Ufer, Geländer, Träger, Pylone, Lampen, Wasserfläche |
| `station` | Inseln der Tankspur, Dächer, Zapfsäulen, Shop, Preismast |
| `border` | Dach, Blende, Häuschen |
| `city` | Straßenlaternen, Zäune/Hecken/Mauern, Zebrastreifen-Daten |
| `gantry` | Startbrücke mit Countdown-Lampen, Zielbrücke |
| `radar` | Radarsäulen und Blitz |
| `landmarks` | Wahrzeichen am Pfad bis `landmark_path_m` |

Ebenen (`scripts/race3d/layers/`, jede mit `setup(renderer)`, `update(view, dt)`, `snapshot()`): `backdrop`,
`far_ground`, `lights`, `vehicles`, `flares`, `weather`, `overlay`, `post`.

`create_all()` liefert alle vorhandenen Builder; solange `builders/road.gd` fehlt, steht die Debug-Straße an ihrer
Stelle. `create(name)`, `create_layer(name)`, `existing_builders()`, `existing_layers()` für alles Weitere.

### 4.6 Einbau in den Renderer

Genau das tut `ModernRenderer.prepare()` (Abschnitt 9.2) – wer einen Builder oder eine Ebene schreibt, baut den Kern
nicht selbst auf, sondern bekommt ihn über die Fassade. Das Muster, etwa für Tests ohne Renderer:

```gdscript
var path := RoadPath3D.new()
path.setup(track, 0, float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0)))
var terrain := TerrainProfile.new()
terrain.setup(path, track, ConfigLoader.lookup(cfg, "graphics.modern.terrain", {}), scenery_db)
var streamer := ChunkStreamer.new()
add_child(streamer)
streamer.setup(path, terrain, track, cfg, levels, sync)   # cfg: die ganze Spielkonfiguration; levels: Detailstufen
for b: ChunkBuilder in BuilderRegistry.create_all():
	streamer.register(b)
streamer.rebased.connect(_on_rebased)                     # Verschiebung für alles, was Weltpositionen hält
# je Bild
streamer.update(float(view["camera_z"]), visibility_m)
```

- `cfg` ist die **ganze** Spielkonfiguration (`ConfigLoader.load_merged()`); die Builder bekommen sie als
  `ChunkContext.cfg` und lesen daraus auch `road.*` und `render.*`. Der Streamer liest `graphics.modern`.
- `levels` sind die aufgelösten Detailstufen; der Kern liest daraus nur `terrain_outer_m` (äußerer Ring).
- `visibility_m` ist die Sichtweite der Ansicht – im Tunnel und bei Nebel lädt der Streamer entsprechend weniger.
- Der Streamer ist ein `Node3D`; seine Kinder sind die Stückknoten. Er gehört unter die Welt des Renderers, nicht
  unter einen Knoten, der sich bewegt.
- Fahrzeuge, Lichter und alles andere Bewegliche stehen jedes Bild neu über `path.world()` / `path.frame_at()`; sie
  brauchen `rebased` nicht.

## 5. Gelände (`TerrainProfile`)

Das Gelände ist ein Regelflächen-Band: je Reihe und Seite eine Kette von Ringen – Abstände jenseits der äußeren
Bankettkante (`ring_offsets`) und Höhen relativ zur Fahrbahn dieser Reihe (`ring_heights`). `height(k, seite, m)` ist
die gerade Linie zwischen den Ringen, also genau das, was ein aus den Ringen gebautes Netz zeigt.

### 5.1 Ringe und Kürzung

Abstände: `rings_m` = 0 / 5 / 15 / 40 / 100 / 220 / 480 m; der letzte ist der äußere Ring (auf „Details: Hoch“
1.000 m über `levels.terrain_outer_m`). Das Band wird gekürzt, wo es seinen eigenen Boden verließe:

- auf der Kurveninnenseite bei `inside_bend_factor` (0,8) × Radius ab Straßenmitte,
- überall an der Mittelachse zu einem anderen Straßenteil: `clearance − clear_margin_m` (6 m).

Ein gekürztes Band behält die inneren Ringe, wo sie passen, und verteilt die übrigen: Ring i liegt höchstens bei
`Breite · (i / letzter)^cap_power` (1,6). So bleibt dem letzten Ring immer Platz zum Abfallen (er beginnt bei
höchstens 75 % der Breite), und Bankett und Graben (5 m, 15 m) bleiben auch in engen Kurven, wo sie sind.

Gemessen im ganzen Netz (2.011.532 Querschnittsseiten): gekürzt an 149.924 Seiten (7,5 %), schmalstes Band 101,3 m.
Freie Breite bis zur Mittelachse (251.540 Seiten, alle 24 m): ≥ 120 m an 100 %, ≥ 160 m an 99,89 %, ≥ 240 m an
99,59 %, ≥ 320 m an 98,87 %, ≥ 480 m an 94,87 %; kleinste 134,5 m (Saragossa – Pau).

Zwei Bänder verschiedener Straßenteile enden je 6 m vor der Mittelachse – dazwischen bleibt ein Spalt von etwa 12 m,
im Kurvenmittelpunkt ein Loch von 0,2 × Radius. Beide liegen auf Höhe der Talsohle; schließen muss sie der
Fernboden.

### 5.2 Höhen

- **Bankett und Graben** (`profile`): 0 m an der Bankettkante, −0,35 m bei 5 m, −0,6 m bei 15 m, −1,1 m bei 40 m,
  −2,6 m bei 100 m, −4,0 m bei 220 m. Das Profil selbst liegt nie über der Fahrbahn.
- **Relief** (`relief_m`, 3 m bei Hügelstufe 2): glattes Rauschen entlang der Straße (Wellenlänge
  `relief_wavelength_m` 260 m, ein Strom je Seite und Ring), eingeblendet zwischen `relief_from_m` (30 m) und
  `relief_full_m` (100 m), skaliert mit der Hügelstufe des Abschnitts (`hill_factors` 0,4 / 0,7 / 1,0 / 1,5).
  Kein Relief in City Limits, in Tunneln und 60 m davor und dahinter, auf Brücken, am Start und hinter dem Ziel;
  Übergänge über `relief_ramp_m` (120 m). Eine Landschaft kann es mit dem Schlüssel `relief` in `scenery.json`
  skalieren (heute nirgends gesetzt).
- **Talsohle**: der letzte Ring liegt auf `floor_y` (Abschnitt 3.4).
- **Brücken**: alle Ringe liegen auf dem Wasser (`TrackSegment.water_level`).

Gemessen im ganzen Netz: höchstes Gelände 1,89 m über der Fahrbahn; an 56.339 von 2.011.532 Seiten (2,8 %) liegt
irgendwo Gelände über Fahrbahnniveau. Das Relief ist also mild; `relief_m` ist die Stellschraube.

### 5.3 Sichtkorridor (Fairness-Regel F7)

`corridor_width(k, seite)` (Meter jenseits des Banketts): auf der Kurveninnenseite die Pfeilhöhe einer Sehne von
`corridor_chord_m` (300 m), gemessen ab dem Fahrbahnrand mit dessen Radius – `300² / (8 · (R − halbe Fahrbahn))` –
für die stärkste Krümmung zu dieser Seite innerhalb einer halben Sehne Weg davor und dahinter; sonst
`corridor_min_m` (8 m) ab Fahrbahnrand. Engste Kurve des Netzes: 83,6 m.

Im Korridor liegt der Boden nie über der Fahrbahn: Relief bekommt ein Ring nur, wenn schon sein **innerer Nachbar**
außerhalb des Korridors liegt – damit ist auch die gerade Linie zwischen zwei Ringen im Korridor nie über null.
`ChunkContext.in_bend_corridor()` sagt dem Requisiten-Builder, wo keine schmückende Vegetation stehen darf. Gemessen
in den zwölf härtesten Etappenrichtungen: 5.230 von 18.518 Landschafts-Requisiten (28,2 %) stehen in einem
Kurvenkorridor, davon 4.033 von 13.628 Bäumen und Büschen (29,6 %).

### 5.4 Konfiguration `graphics.modern.terrain`

Alle Schlüssel sind optional; die Standardwerte stehen im Code.

| Schlüssel | Standard | Bedeutung |
|---|---|---|
| `rings_m` | 0, 5, 15, 40, 100, 220, 480 | Ringabstände jenseits des Banketts |
| `inside_bend_factor` | 0,8 | Bandbreite auf der Kurveninnenseite als Anteil des Radius |
| `floor_window_m`, `floor_drop_m` | 900, 4,5 | Talsohle |
| `clear_margin_m` | 6 | Abstand des Bandendes von der Mittelachse |
| `min_width_m` | 3 | kleinste Bandbreite |
| `cap_power` | 1,6 | Verteilung der Ringe in einem gekürzten Band |
| `profile` | siehe 5.2 | Bankett und Graben als Liste `[m, Höhe]` |
| `relief_m`, `relief_wavelength_m`, `relief_from_m`, `relief_full_m`, `relief_ramp_m`, `hill_factors` | 3; 260; 30; 100; 120; 0,4 / 0,7 / 1,0 / 1,5 | Relief |
| `corridor_chord_m`, `corridor_min_m` | 300, 8 | Sichtkorridor – nicht ohne die Projektleitung ändern |

Weitere Schlüssel in `graphics.modern`: `max_chunks` (16; steht seit der Korrektur nach der Abnahme von
Bauabschnitt 0 ausdrücklich in `config/game_config.json` – vorher galt nur die Vorgabe im Code, und die offene
Entscheidung „16 oder 18“ aus 4.1 hatte keinen Ort, an dem man sie treffen konnte), `rebase_m` (2.000, Vorgabe im
Code).

## 6. Kamera (`ChaseCamera3D`)

### 6.1 Arcades Projektion, exakt

Die Kamera ist eine `Camera3D` mit `PROJECTION_FRUSTUM` und `keep_aspect = KEEP_HEIGHT`:

```
size   = near · H / focal            focal = RoadProjection.focal = 711 logische Pixel
offset = (0, −(0,5 − horizon_frac) · size) = (0, −0,05 · size)
near   = 1 m, far = 2.600 m          keine Neigung, kein Rollen
```

`H` ist die Höhe des **logischen** Viewports (`get_visible_rect().size`), mit dem Streckmodus `expand` des Modus
„Modern“ also 720 bei 16:9, 800 bei 16:10. Die Brennweite bleibt bei jedem Seitenverhältnis 711 px, der Horizont
auf 45 % der Bildhöhe: ein breiteres oder höheres Fenster zeigt nur mehr.

Position = `(camera_z, camera_x, camera_y)` der Ansicht auf dem echten Pfad; `camera_x` seitlich entlang der
Straßenquerrichtung bei `camera_z`. Kamerawackeln = Verschiebung des Frustums um `shake` logische Pixel (+x rechts,
+y unten) wie Arcades Zeichentransformation – keine Drehung.

| Messung (gemessen) | Wert |
|---|---|
| `project()` gegen `RoadProjection` auf gerader Strecke über Hügel, 10 … 600 m, 1280×720 / 1280×800 / 1680×720 | höchstens 0,0001 px (verlangt ≤ 0,5 px) |
| `project()` gegen das Frustum der Engine (`Projection.create_frustum_aspect`) | ≤ 0,01 px (Test) |
| `Camera3D.unproject_position()` gegen `project()` im laufenden Spiel (Xvfb, OpenGL, `expand`), dieselben drei Größen | höchstens 0,0015 px |

### 6.2 Blick in die Kurve

Gierwinkel = `look_gain` (0,6) × Peilung der Mittellinie `look_m` (100 m) voraus, höchstens `yaw_max_deg` (14°) –
eine Funktion des Ortes allein: derselbe Ort zeigt immer dasselbe Bild. Gemessen im ganzen Netz: größter Winkel
12,7°. Ohne ihn (Tangentenkamera) verlässt die Straße in engen Kurven das Bild früher als in Arcade (Abschnitt 7.4).

In Kurven ist das echte 3D-Bild nicht pixelgleich mit Arcades geschertem. Mit der Tangentenkamera (`look_gain` 0)
weichen Fahrbahnpunkte (Mitte und ± 5,6 m) so weit von Arcade ab (gemessen):

| Stelle | bis 100 m | bis 150 m | bis 200 m | bis 300 m |
|---|---|---|---|---|
| Kassel – Würzburg km 46,2 (Kurvenwert 0,16) | 4,6 px | 4,7 px | 6,5 px | 10,7 px |
| Kassel – Würzburg km 46,5 (0,29, R ≈ 414 m) | 7,4 px | 7,4 px | 7,4 px | 9,4 px |
| Saragossa – Pau km 198,3 (0,72) | 22,8 px | 54,7 px | 122,6 px | – |
| Saragossa – Pau km 198,8 (0,88, R ≈ 136 m) | 25,7 px | 61,1 px | 135,5 px | – |
| Kreisbogen ab der Kamera, R 400 m / R 136 m (Test) | – / ≤ 27 px | ≤ 8 px / – | | |

Die Unterschiede sind Geometrie, nicht Kamera: Arcade schert, Modern dreht. Der Blick in die Kurve schwenkt das
ganze Bild zusätzlich um einen festen Betrag (an diesen vier Stellen 54 / 60 / 176 / 184 px, gemessen) – ein
Bildvergleich mit Arcade in Kurven braucht deshalb `look_gain` 0 oder rechnet den Schwenk heraus.

### 6.3 Einbau in den Renderer

```gdscript
var cam_model := ChaseCamera3D.new()
cam_model.setup(proj, ConfigLoader.lookup(cfg, "graphics.modern.camera", {}))    # proj: RoadProjection der Sitzung
# je Bild
camera.global_transform = cam_model.transform(view, path)
var fr := cam_model.frustum(get_viewport().get_visible_rect().size, view.get("shake", Vector2.ZERO))
camera.set_frustum(fr.size, fr.offset, fr.near, fr.far)                           # keep_aspect = KEEP_HEIGHT
```

`ChaseCamera3D.project(transform, frustum, viewport_size, punkt)` liefert (Pixel x, Pixel y, Tiefe) und ist die
Rechnung hinter `world_to_screen()`; `on_screen()` prüft Bildrand und Tiefe. Der Renderer setzt seine `Camera3D`
jedes Bild so (Abschnitt 9.2); gemessen im laufenden Spiel weicht `Camera3D.unproject_position()` von
`ModernRenderer.world_to_screen()` um höchstens 0,0005 px ab (1280 × 720, Render-Prüfung `modern_bild`; 0,0001 px bei
1280 × 800, `fenster_16_10`).

## 7. Fairness

Wörtlich „überall mindestens so früh sichtbar wie in Arcade“ geht in echtem 3D nicht: durch den Hügel, um den sich
eine Straße windet, kann man nicht sehen. Verbindlich sind die Regeln F1–F7 des Bauplans (D14). F1–F3 und F7 prüft
`tests/sim/modern_sight.gd` mit der ausgelieferten Kamera und dem ausgelieferten Gelände auf den echten Strecken;
F4–F6 (Nebel, Ausblenden, Lichtgrößen) sind Render-Prüfungen des Renderers.

### 7.1 Regeln und Prüfungen

| Regel | Prüfung | Grenze |
|---|---|---|
| F1 Was Arcade bis 270 m im Bild hat, liegt im Sichtkegel von Modern | `modern_sight_f1`: Kamera in Fahrbahnmitte, Ziele auf der Mitte und ± eine Spur, 15 … 270 m voraus | 0 Fälle |
| | `modern_sight_f1_lanes`: Kamera in den Außenspuren (± 3,75 m), Ziele in jeder Spur und am Fahrbahnrand (± 9,4 m), 30 … 260 m | 0 Fälle |
| F2 Jenseits davon: Anhalteweg bei der schnellsten fahrbaren Geschwindigkeit ≤ 0,6 × Entfernung des Ziels, das Arcade zeigt und Modern noch nicht | `modern_sight_f2`: jede Stichprobe beider Abtastungen; trocken, Regen, Schnee | ≤ 0,60 |
| F3 Kuppen: kein Fahrzeug (0,75 m) und kein Schild (2,8 m) wird später gesehen als in Arcade **und** dann innerhalb des Anhaltewegs | `modern_sight_f3`: Ziele alle 300 m, wo die Straße davor nicht flach ist | 0 Fälle |
| F7 Gelände im Sichtkorridor nie über der Fahrbahn | `modern_sight_f7`: jede Reihe, beide Seiten | 0 Verstöße |
| – | `modern_sight_model`: die schnelle Rechenschleife gegen `ChaseCamera3D.transform()` / `project()` und `RoadProjection.project()` | 0 Abweichungen |
| – | `modern_sight_model`, Augpunkt: F3 rechnet mit einem eigenen Auge (Kamerahöhe aus `RoadProjection` über der Fahrbahn am Wagen). Für jede nachgerechnete Stichprobe wird die Bildhöhe des Ziels aus `ChaseCamera3D.transform()` / `project()` mit der dieses Auges verglichen (`horizon_y − focal · (Zielhöhe − Augenhöhe) / Tiefe`) | 0 Stichproben über 0,5 px |

### 7.2 Die Modelle

- **Arcade**: die Reihenrechnung des Renderers (`RoadRenderer._project`: `x += dx; dx += curve · seg² / R1`) und
  `RoadProjection`; ein Unit-Test hält das Modell gegen den echten Renderer fest (≤ 0,01 m, ≤ 0,05 px). Sicht über
  Kuppen wie `tests/sim/sight_check.gd`: Sichtlinie über das Höhenprofil, Tiefe = Weg auf der Straße.
- **Modern**: `ChaseCamera3D` auf dem `RoadPath3D`; über Kuppen eine gerade Sichtlinie durch die Welt, Stützpunkte
  alle 6 m, Boden = Fahrbahn und Geländeband des nächstgelegenen Querschnitts (`TerrainProfile.rows()`), jenseits
  des Bands nichts. Kamera 9 m hinter dem Wagen, Auge 3,4 m über der Fahrbahn am Wagen, 5 cm Toleranz.
- **Schnellste fahrbare Geschwindigkeit**: beste Querhaftung (8 m/s²) und höchste Endgeschwindigkeit (270 km/h)
  aller Autos zugleich, Kurven 5 % über ihrer Grenze, Bremshüllkurve rückwärts; Wetter über die Haftungs- und
  Tempofaktoren der Konfiguration. **Anhalteweg** = 1 s Reaktion + Vollbremsung bis zum Stand (219,6 m bei 270 km/h
  trocken). Ein Ziel gilt bis 0,839 × Sichtweite als gesehen (trocken 755 m, Regen 491 m, Schnee 378 m bei Tag).

### 7.3 Ergebnisse

Ganzes Netz (`--full`, gemessen: 128 Etappenrichtungen, 1.005.766 Segmente, 132 s):

| Prüfung | Ergebnis |
|---|---|
| F1 | **0 Fälle bis 270 m**, erster Fall bei 280 m; 99.424.500 Stichproben (davon 86.641.350 auf dem Raster der Entwurfsstudie 150 … 750 m) |
| F1 Außenspuren | 0 Fälle bis 260 m, erster Fall bei 270 m; 326.680.500 Stichproben |
| F2 | Anhalteweg / Entfernung höchstens **0,593 trocken, 0,596 Regen, 0,555 Schnee** |
| F3 | **0 von 5.923** Zielen, Fahrzeug wie Schild |
| F7 | 0 von 2.011.532 Querschnittsseiten |
| Modell | 394.011 Stichproben nachgerechnet, 0 abweichend, keine senkrecht außerhalb des Bilds; Augpunkt: keine über 0,5 px, größte Abweichung 0,0002 px |

Ungünstigste F2-Fälle: trocken Saragossa – Pau km 170,6 (Anhalteweg 219 m bei 270 km/h, Ziel 370 m voraus), Regen
Bukarest – Sibiu ab Bukarest km 187,3 (244 m bei 260 km/h, 410 m), Schnee Saragossa – Pau km 170,5 (211 m bei
198 km/h, 380 m). Mit der Kamera nur in Fahrbahnmitte (Abtastung der Entwurfsstudie) sind es 0,591 / 0,594 / 0,553.

F3 im Einzelnen (ausgeliefertes Gelände): Fahrzeuge werden in Arcade ab p10 180 m / p50 510 m gesehen, in Modern ab
186 m / 528 m; Modern später um mehr als 6 m bei 15 Zielen (mehr als 30 m: 8), früher bei 772; näher als der
Anhalteweg gesehen: Arcade 816, Modern 793. Schilder: Arcade 246 m / 612 m, Modern 252 m / 642 m; später 17 (8),
früher 866; näher als der Anhalteweg 345 gegen 317. Modern sieht über das abfallende Gelände meist weiter als Arcade
über das Höhenprofil.

Vergleich mit der Entwurfsstudie (`--study-terrain`: deren Boden – Fahrbahnhöhe bis 100 m neben der Mitte, innen bis
0,8 R – statt des ausgelieferten Geländes): 5.923 Ziele, Arcade p10 180 m / p50 510 m (Studie: gleich), durch Kuppen
begrenzt 4.211 (gleich), näher als der Anhalteweg Arcade 816 (gleich), Modern 814 (gleich); Modern später um mehr
als 6 m: 71 (Studie 76), mehr als 30 m: 22 (22), früher 52 (41); 0 Verstöße. Die kleinen Unterschiede kommen von der
zwischen den Grenzen interpolierten Bodenhöhe.

### 7.4 Was die Zahlen nicht sagen

- **F1 gilt für Fahrzeuge in jeder Spur, nicht für jeden Bildpunkt.** Ziele am Fahrbahnrand (± 9,4 m) direkt neben
  dem Wagen – 15 m vor der Kamera, also 6 m vor dem Wagen, bis 13 m seitlich – zeigt Arcade noch am Bildrand, Modern
  in Kurven nicht mehr (120.852 von 199 Mio. Stichproben). Ab 30 m gibt es bis 260 m keinen Fall.
  Ebenso die Tankspur (+ 7,5 m; gerechnet, als gäbe es sie überall): ein Ziel dort mit der Kamera in einer Spur 866
  Fälle bei 15 m, Ziele in den Spuren mit der Kamera auf der Tankspur 1.031 Fälle bei 15 m – jeweils bis drei Spuren
  quer, 6 m vor dem Wagen; von 30 bis 260 m kein Fall, bei 270 m einer bzw. zwei (je 99 Mio. Stichproben).
- **270 m ist knapp.** Mit der Kamera in einer Außenspur liegt der erste Fall bei 270 m (1 von 298 Mio. Stichproben
  für Ziele in den Spuren), mit der Kamera in der Mitte bei 280 m. F2 hält in beiden Fällen.
- **Der Blick in die Kurve trägt F1.** Mit der Tangentenkamera (`look_gain` 0) gäbe es in den vier härtesten
  Etappenrichtungen schon für ein Ziel eine Spur neben der Mitte 1.332 Fälle bis 270 m, die ersten bei 200 m.
- **Die Grenze des Generators.** Eine künstliche Strecke, deren Kurven alle den Höchstwert 0,9 der Kurvigkeit 3
  erreichen, hat den ersten Fall bei 270 m (das Netz: höchstens 0,892, erster Fall 280 m). Eine künftige Etappe,
  die F1 verfehlt, bekommt einen anderen Seed.
- **Verdeckung durch Bauten und Bäume** prüfen diese Rechnungen nicht – nur Sichtkegel (F1/F2) und Gelände (F3/F7).
  Tunnelwände verdecken in Kurven in beiden Modi gleich weit (abgeleitet, nicht gemessen: die Sichtlinie an der
  Innenwand vorbei reicht in der gescherten wie in der echten Röhre etwa √(8 · R · halbe Röhrenbreite), bei
  R = 134 m und 6 m also rund 80 m).
- F3 rechnet trocken bei Tag, wie die Entwurfsstudie.

### 7.5 Prüfungen bedienen

```
godot --headless --path . -s res://tests/sim/modern_sight.gd [-- --full] [--stage=<id>[,<id>…]] [--verbose] [--study-terrain]
godot --headless --path . -s res://tests/sim/modern_path_check.gd [-- --full] [--stage=<id>[,<id>…]] [--verbose]
```

| Lauf | Umfang | Zeit (gemessen) |
|---|---|---|
| `modern_sight.gd` | die zwölf härtesten Etappenrichtungen (`Fairness.HARDEST`): 103.583 Segmente, 44 Mio. Stichproben, 874 Kuppenziele | 18 s |
| `modern_sight.gd -- --full` | ganzes Netz | 132 s |
| `modern_path_check.gd` | ganzes Netz, 74 Etappenrichtungen über die Krümmungsschranke | 24–25 s |
| `modern_path_check.gd -- --full` | ganzes Netz gerechnet, dazu freie Breite, Stückzahl und größte Koordinate | 53–56 s |

Die Auswahl enthält die ungünstigsten Fälle des ganzen Netzes: ihr Lauf liefert dieselben F2-Werte (0,593 / 0,596 /
0,555). Jede Prüfung druckt `CHECK <name> OK|FEHLER …` und endet mit Fehlercode 1, wenn eine fehlschlägt.

### 7.6 Regeln für Änderungen

- Die Prüfungen sind Sperren. **Nie eine Grenze lockern ohne die Projektleitung.**
- Wer `graphics.modern.camera` oder `graphics.modern.terrain` ändert oder am Kern dreht, lässt `modern_sight.gd`
  laufen, an den Meilensteinen mit `--full`.
- Neue Etappen oder ein geänderter Streckengenerator: `modern_path_check.gd -- --full` und `modern_sight.gd -- --full`.
- Relief, Vegetation und Bauten gehören nicht in den Sichtkorridor (5.3); „Details“ dünnt nie etwas aus, worauf der
  Spieler reagieren muss.

## 8. Offene Punkte für die nächsten Bauabschnitte

- **Tunnel**: `TerrainProfile` liefert auch für Tunnelreihen ein Profil (ohne Relief); die Debug-Straße zeichnet dort
  kein Gelände. Portal und Hügel muss der Tunnel-Builder schließen – von außen endet das Band sonst am Portal.
- **Spalt an der Mittelachse und Loch im Kurvenmittelpunkt** (5.1) schließt der Fernboden.
- **Sichtkorridor und Vegetation**: die Regel nimmt in Bergstrecken knapp 30 % der Bäume weg (5.3). Wirkt das kahl,
  ließe sich der Korridor aus der wirklichen Sehne statt aus der stärksten Krümmung rechnen – eine Änderung im
  Kern mit neuem Lauf von `modern_sight.gd`, zu entscheiden von der Projektleitung.
- **Stückzahl**: wird `load_path_m` oder `max_chunks` geändert, ändert sich `clear_reach_m` und damit, wie weit die
  Strecke vorauserzeugt wird (3.6).
- **Bilder**: Draufsichten und Kamerabilder der Debug-Straße an den Referenzpositionen liegen im Abgabeordner des
  Bauabschnitts (nicht im Repository).
- **Kurvenkamera ohne Reserve**: Die ausgelieferte Kamera (Blick 0,60 × Peilung 100 m voraus) besteht F1 genau –
  der erste Fall liegt bei 280 m, die Grenze bei 270 m; weniger Blick in die Kurve fällt durch (6.2). Wer die
  Kamera ändert, lässt `modern_sight.gd --full` laufen; die Entscheidung über mehr Reserve liegt bei der
  Projektleitung (Frage 9 des Bauplans, Abnahme von Bauabschnitt 1).
- **3D-Puffer bleiben nach der ersten Modern-Etappe**: Die Engine behält die Renderpuffer des 3D-Bilds für den
  Rest des Prozesses, auch in späteren Arcade-Etappen (gemessen in der Abnahme von Bauabschnitt 0 unter Xvfb bei
  1280 × 720: + 7.722.314 Bytes Texturspeicher nach der ersten Modern-Etappe, über drei weitere Wechsel
  unverändert; eine nackte `Camera3D` mit `Environment` belegt 7.372.800 Bytes = 1280 × 720 × 8 und gibt sie nach
  dem Freigeben der Knoten nicht zurück, auch `disable_3d` nicht; nach den Korrekturen nachgemessen: dieselbe
  Arcade-Etappe 314,4 MB allein und 321,8 MB nach einer Modern-Etappe). Der Betrag wächst mit Fenstergröße und
  3D-Auflösung (gefolgert, nicht gemessen). Für den Renderer (R1) heißt das: den Betrag in das Texturbudget beider
  Modi einrechnen und in der Leckprüfung als Grundlast führen – er ist kein Leck, zählt aber gegen „jeder Modus
  lädt nur seine eigenen Assets“ (Bauplan §4.11).

## 9. Aufbau: Fassade, Ebenen, Haken

`scripts/race3d/modern_renderer.gd` (`ModernRenderer`, ein `Node3D`) ist das **Gerüst** des Renderers. Es zeichnet
selbst nichts: die Straße ist ein Builder, Fahrzeuge, Lichter, Wetter … sind Ebenen. Das Gerüst findet beide über
ihren festen Dateinamen (Abschnitt 4.5), baut den Kern auf, ruft ihre **Haken** in fester Reihenfolge und bietet
ihnen eine **Fassade** – die einzige Stelle, über die Bauabschnitte miteinander reden (immer mit `has_method` /
`renderer.layer(id)`, nie über einen Klassennamen eines anderen Bauabschnitts). Verbindlich ist Nachtrag A-7 des
Bauplans; hier steht, wie es gebaut ist.

### 9.1 Was es heute gibt

| Teil | Datei | solange … |
|---|---|---|
| Straße mit Geländeringen in Eckpunktfarben, unbeleuchtet | `builders/debug_road.gd` | `builders/road.gd` fehlt (mit einem Builder `terrain` zeichnet sie nur noch die Straße) |
| Umgebung: ein Schattenlicht, Umgebungslicht, Tiefennebel, `ce_*`-Globals | `plain_environment.gd` | `environment_rig.gd` fehlt |
| Himmelsverlauf der Palette auf Canvas-Ebene −10 | `plain_sky.gd` | `layers/backdrop.gd` fehlt |

Keine Fahrzeuge, keine Requisiten, keine Markierungen – das Bild des Gerüsts ist ein Arbeitsstand, kein Vergleich
mit Arcade (A/B-Bild im Abgabeordner des Bauabschnitts).

Seit dem Renderer-Kern (Abschnitt 10) gibt es `builders/road.gd`, `environment_rig.gd` und `layers/backdrop.gd`: der
ausgelieferte Renderer nimmt diese; die eingebauten Teile bleiben Rückfall und Prüfgrundlage (der Prüf-Renderer
`bare` lädt nur sie). Die Debug-Straße zeichnet dann nur noch ihr Geländeband – so lange, bis `builders/terrain.gd`
da ist; das Band trägt die beiden Grasfarben der Landschaft in Arcades Rhythmus von vier Segmenten.

Die Debug-Straße ist **unbeleuchtet**: sie zeigt weder das Licht der Umgebung noch Schatten – ein Kasten über der
bloßen Fahrbahn ändert darunter keinen einzigen Bildpunkt, derselbe Kasten wirft auf eine beleuchtete Platte einen
Schatten (gemessen: Render-Prüfungen `strasse` und `licht`). Ein Fahrzeug wirft auf ihr also keinen Schatten. Damit
Nacht, Regen und Tunnel trotzdem danach aussehen, färbt ihr Haken `update()` sie jedes Bild mit
`palette.ambient` (im Tunnel mit `Palette.TUNNEL_AMBIENT`) – Arcades Farbgesetz für Fahrbahn und Boden. Licht und
Schatten der eingebauten Umgebung sieht man auf beleuchteten Flächen: auf den Prüfplatten der Render-Prüfungen
`licht` und `nacht`, später auf Straße, Gelände und Modellen der Bauabschnitte.

### 9.2 Ablauf

Die Sitzung ruft `setup(track, proj, cfg, scenery_db)` → `apply_quality(levels)` → `prepare(ctx)` und danach jedes
Bild `render(view)` – auch während der Vorbereitung, dann mit der eingefrorenen Startansicht hinter dem Ladebild.

`prepare(ctx)` baut in dieser Reihenfolge: `RoadPath3D` (noch nicht integriert), `TerrainProfile`, `ChaseCamera3D`,
die `Camera3D` (Frustum aus `ChaseCamera3D` für die **logische** Bildgröße, `KEEP_HEIGHT`), den Knoten `world`,
`materials = ModernMaterials.shared()`, die Umgebung (`environment_rig.gd` oder die eingebaute), den `ChunkStreamer`
unter `world` mit `services = {"renderer", "materials"}` und den Buildern aus `BuilderRegistry.create_all()`, dann
jede Ebene, deren Datei es gibt, in der Reihenfolge `backdrop, far_ground, lights, vehicles, flares, weather,
overlay, post` – jede als Kind des Renderers mit dem Namen ihrer Datei. Erst wenn alles besteht, laufen drei
Durchgänge, jeder in der Reihenfolge Umgebung → Builder → Ebenen: `setup(renderer)`, `apply_quality(levels)`,
`prepare(ctx)`.

Danach läuft die Vorbereitung über Bilder (`debug_snapshot().stage`):

| Stufe | was geschieht | endet, wenn |
|---|---|---|
| `selftest` | Render-Selbsttest (`GfxSelfTest`), **einmal je Prozess** | das Urteil da ist (headless: sofort) |
| `hooks` | nichts wird aktualisiert, kein Stück gebaut | jedes `prepare_pending()` 0 ist |
| `chunks` | mit der ersten Ansicht integriert der Streamer den Pfad und lädt die Stücke der Startansicht sofort (Sync-Modus: `flush()`); ab jetzt läuft `update()` | kein Stück und keine Vorbereitung mehr offen ist |
| `warmup` | die Knoten aus `warmup_nodes()` stehen 14 m vor der Kamera auf der Fahrbahn, `WARMUP_FRAMES` = 2 gezeichnete Bilder lang, hinter dem Ladebild; dann gibt der Renderer sie frei | die Bilder gezeichnet sind (headless, `--no-prewarm`, `graphics.modern.prewarm = false`: sofort, ohne Knoten bzw. ohne Bilder) |
| `done` | `is_prepared()` ist wahr | – |

Jedes `render(view)` ab der Stufe `chunks`: Umgebung `update(view, dt)` → `streamer.update(camera_z, visibility_m)`
→ Kamera (Transformation und Frustum aus `ChaseCamera3D`) → `update(view, dt)` der Builder, die eines haben, in
Registrierfolge → `update(view, dt)` der Ebenen in Listenfolge. **Bis `is_prepared()` ist `dt` = 0**: die Startansicht
steht, der Zustand beim Start hängt nicht davon ab, wie viele Bilder die Vorbereitung brauchte (Selbsttest nur in der
ersten Etappe, Aufwärmbilder nur mit echtem Renderer).

`healthy()` wird falsch – die Sitzung fährt die Etappe dann in Arcade – mit `fail_reason()` =

- `selftest:<grund>` (Selbsttest; `--gfx-debug=fail` ergibt `selftest:debug`),
- dem, was ein Haken während der Vorbereitung in `fail_reason()` meldet (`manifest`, `shader`, …),
- `script:<datei>`, wenn eine Ebenen-, Builder- oder Rig-Datei da ist, aber keinen Knoten bzw. Builder ergibt,
- `timeout` nach `graphics.modern.prepare_timeout_s` (Vorgabe im Code: 120 s; nie im Sync-Modus – Regel 10). Es
  zählen nur gezeichnete Bilder, jedes mit höchstens 0,25 s: ein minimiertes Fenster zeichnet nichts (Selbsttest
  und Aufwärmen warten darauf), und ein Rechner, der schlief, ist kein hängender Renderer.

### 9.3 Fassade

Alles Hauptthread, für Ebenen, Builder (in `setup`, `collect`, `commit`, `update`) und Tests; nur lesen.

| Mitglied | Inhalt |
|---|---|
| `track`, `proj`, `cfg`, `scenery_db` | was die Sitzung in `setup()` übergab (`cfg` = ganze Spielkonfiguration) |
| `levels`, `sync`, `prep` | Qualitätsstufen (`Gfx.levels`), Sync-Modus (`--gfx-sync`), der Kontext von `prepare()` (`sets`, `plan`, `vehicle`, `weather`, `hour`, `sync`) |
| `path`, `terrain`, `streamer`, `chase`, `camera` | der Kern; `path` ist erst ab dem ersten `update()` integriert |
| `materials` | `ModernMaterials.shared()` |
| `env` | der Knoten von `environment_rig.gd`; `null`, solange die Datei fehlt |
| `world` | Elternknoten für 3D-Knoten der Ebenen: Einheitstransformation, Koordinaten relativ zum schwimmenden Ursprung |
| `view`, `visibility_m` | Ansicht und Sichtweite des laufenden `render()` |
| `debug_flags` | `--gfx-debug=<liste>` |
| `signal rebased(shift)` | der Ursprung wurde verlegt: `shift` auf jede gemerkte Weltposition addieren |
| `layer(id)` | die Ebene oder `null` |
| `builder(id)` | der registrierte Builder mit dieser `id()` oder `null` |
| `road_to_world(z, x, h)` | Straßenkoordinaten → Weltposition (`path.world()`); `Vector3.ZERO`, bevor der Pfad integriert ist |
| `world_to_screen(z, x, h)` | (Pixel x, Pixel y, Tiefe in m) in logischen Pixeln des letzten Bildes – `ChaseCamera3D.project()` |
| `add_lamps(parent, lamps)` | feste Lampen eines Stückteils: geht an `layer("lights")` und `layer("flares")`, wenn es sie gibt und sie `add_static(parent, lamps)` haben; Einträge `{pos, dir, role, color, size, range, energy}` wie in A-7 |
| `add_pool_material(mat)`, `pool_materials()` | Materialien, deren Shader die Lichtkegel einbindet (9.7) |

`ChunkContext.services` (= `ChunkStreamer.services`) reicht `{"renderer", "materials"}` an `collect()` und `commit()`
jedes Builders – **nie** in `build()` (Arbeiter-Thread). In Tests ohne Renderer ist es `{}`; ein Builder muss ohne
auskommen (Materialien über `ModernMaterials.shared()`, keine Lampen).

### 9.4 Haken

Alle sind freiwillig und werden per `has_method` gefunden – bei der Umgebung, bei Buildern und bei Ebenen.

| Haken | wann | Hinweis |
|---|---|---|
| `setup(renderer)` | in `prepare()`, nachdem alles besteht | der Pfad ist noch nicht integriert: keine Positionen |
| `apply_quality(levels)` | danach, einmal je Etappe | Qualitätsstufen ändern sich während der Etappe nie |
| `prepare(ctx)` | danach | Laden anstoßen (`ModelDB.request`, Schilder vorzeichnen …); darf Bilder dauern |
| `prepare_pending() -> int` | jedes Bild der Vorbereitung | > 0: die Etappe wartet |
| `fail_reason() -> String` | jedes Bild der Vorbereitung | nicht leer: Rückfall auf Arcade mit diesem Grund |
| `warmup_nodes() -> Array` | einmal, wenn die Startansicht steht | je Shader-Variante ein frischer `Node3D` ohne Elternknoten; der Renderer zeigt und löscht ihn |
| `update(view, dt)` | jedes Bild ab dem Start der Welt | Umgebung vor Streamer und Kamera, Builder und Ebenen danach; `dt` = 0 während der Vorbereitung |
| `rebased(shift)` | wenn der Ursprung verlegt wird | erst die Haken (Umgebung, Builder, Ebenen), dann das Signal |
| `perf() -> Dictionary` | bei `perf_stats()` | flache Schlüssel aus Bauplan §4.4.5; Zahlen werden addiert |
| `snapshot() -> Dictionary` | bei `debug_snapshot()` | Listen werden angehängt, Wörterbücher zusammengeführt, Zahlen addiert |
| `add_static(parent, lamps)` | nur `lights` und `flares` | Ziel von `add_lamps()` |

Bauplan A-7 nennt `update` und `rebased` nur für Ebenen; das Gerüst ruft beide auch an Buildern, die sie haben
(nützlich für Dinge, die ein Builder für die ganze Etappe hält, etwa ein Material mit dem Countdown der Startbrücke).
Ein Builder hält weiterhin keinen Zustand je Stück, und sein `update()` läuft im Hauptthread, **während** `build()`
auf einem Arbeiter-Thread laufen kann: es fasst nur an, was `build()` nie liest (Materialien, Knoten).

### 9.5 Beispiel

Eine Ebene – Datei `scripts/race3d/layers/overlay.gd`, ein `Node`; der Dateiname ist ihre Kennung:

```gdscript
extends Node3D

var _renderer: Node               # untyped: packages talk to each other through the facade only
var _marker: MeshInstance3D
var _material: StandardMaterial3D
var _pending := 0


func setup(renderer: Node) -> void:
	# every layer and builder exists by now; the path is not integrated yet (no positions before update())
	_renderer = renderer
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.9, 0.2, 0.1)
	_marker = MeshInstance3D.new()
	_marker.mesh = BoxMesh.new()
	_marker.material_override = _material
	(renderer.get("world") as Node3D).add_child(_marker)   # origin-relative world, identity transform


func apply_quality(levels: Dictionary) -> void:
	var casts := int(levels.get("shadow_casters", 0)) > 0
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func prepare(_ctx: Dictionary) -> void:
	_pending = 1      # e.g. ModelDB.request(...) – the stage does not start while prepare_pending() > 0


func prepare_pending() -> int:
	_pending = 0      # here: ready at the first poll
	return _pending


func warmup_nodes() -> Array:
	# a fresh node per shader variant: the renderer shows it for two frames behind the loading cover and frees it
	var probe := MeshInstance3D.new()
	probe.mesh = BoxMesh.new()
	probe.material_override = _material
	return [probe]


func update(view: Dictionary, _dt: float) -> void:
	# every frame, after the streamer and the camera; _dt is 0 while the stage is prepared
	var player: Dictionary = view["player"]
	_marker.position = _renderer.call("road_to_world", float(player["z"]) + 30.0, float(player["x"]), 0.5)


func perf() -> Dictionary:
	return {"instances": 1}


func snapshot() -> Dictionary:
	return {"props": {"overlay_marker": 1}}


func _exit_tree() -> void:
	if is_instance_valid(_marker):
		_marker.queue_free()      # it hangs under renderer.world, not under this layer
```

Der Kasten wird jedes Bild über `road_to_world()` gesetzt und braucht deshalb kein `rebased()`. Wer eine
Weltposition über Bilder hinweg behält, addiert in `rebased(shift)` die Verschiebung.

Ein Builder – Datei `scripts/race3d/builders/roadside.gd`, `id()` = Dateiname:

```gdscript
extends ChunkBuilder

const POST_EVERY := 8             # rows (segments of 3 m)

var _mesh: BoxMesh
var _material: StandardMaterial3D


func id() -> String:
	return "roadside"


func setup(_renderer: Node) -> void:
	# main thread, once per stage: resources that every chunk shares
	_mesh = BoxMesh.new()
	_mesh.size = Vector3(0.12, 1.0, 0.12)
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.85, 0.85, 0.82)


func build(ctx: ChunkContext, _input: Variant) -> Dictionary:
	# WORKER THREAD: only the snapshot arrays of ctx – no nodes, no resources, no ctx.services / path / terrain
	var frames: Array[Transform3D] = []
	for i in range(0, ctx.row_count() - 1, POST_EVERY):
		var z := float(ctx.seg_a + i) * ctx.seg_len
		var x := ctx.rows_edge[i].y + ctx.shoulder_w - 0.3
		frames.append(ctx.frame(z, x, ctx.ground(z, x) + 0.5))      # rigid frame, chunk-local
	return {"frames": frames}


func commit(ctx: ChunkContext, part: Dictionary, parent: Node3D) -> void:
	# main thread: nodes under the chunk node; the streamer owns and moves that node
	var frames: Array = part["frames"]
	if frames.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mesh
	mm.instance_count = frames.size()
	var lamps: Array = []
	for i in frames.size():
		var tr: Transform3D = frames[i]
		mm.set_instance_transform(i, tr)
		if i % 4 == 0:
			lamps.append({"pos": tr.origin + Vector3(0.0, 0.6, 0.0), "dir": Vector3.DOWN, "role": "street",
				"color": Color(1.0, 0.9, 0.7), "size": 0.3, "range": 8.0, "energy": 1.0})
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = _material
	parent.add_child(node)
	var renderer: Variant = ctx.services.get("renderer")           # {} in a test without a renderer
	if renderer != null:
		(renderer as Object).call("add_lamps", node, lamps)        # positions are local to `node`


func debug(part: Dictionary) -> Dictionary:
	return {"posts": (part["frames"] as Array).size()}
```

Beide Beispiele sind im echten Renderer gelaufen (Kiel – Hamburg km 2, headless: Ebene `overlay`, Builder
`debug_road` und `roadside`, 4 Pfosten je Stück, 14 angemeldete Lampen, ein Aufwärm-Knoten).

### 9.6 Eingebaute Umgebung und eingebauter Himmel

`plain_environment.gd` hat dieselben Haken wie das spätere Rig (`setup`, `apply_quality`, `update`, `snapshot`) und
hält, was die Engine-Befunde des Bauplans verlangen: Hintergrund `BG_CANVAS` hinter Canvas-Ebene −10 (D7), linearer
Tonemapper und fest eingeschaltete Nachbearbeitung (D6), genau **ein** `DirectionalLight3D`, immer mit
`shadow_enabled` (D5) – nachts und im Tunnel geht seine Energie auf 0, versteckt wird es nie. Tiefennebel von
`graphics.modern.fog.begin_frac` bis `end_frac` der Sichtweite in der Nebelfarbe der Palette. Gesetzt werden die
Globals `ce_time`, `ce_night`, `ce_wet`, `ce_snow`, `ce_fog_color`, `ce_fog_range`, `ce_sun_dir`, `ce_sun_color`,
`ce_ambient` (beide über `ModernMaterials.light_value()`) und `ce_tunnel`; `ce_wind`, `ce_headlight*` und `ce_far_y`
behalten ihre Vorgaben, bis Rig und Lichter-Ebene sie setzen. Das ist der Stand des Codes: kein Bild und keine
Prüfung dieses Bauabschnitts liest die Globals (das Gerüst zeichnet nichts, das sie benutzt) – ob ihre Werte zu
den Modell-Shadern passen, zeigt sich erst mit Fahrzeugen und Requisiten.

**Lichtgesetz** (`light_state()`, rein und unit-getestet): Arcade zeigt jede Fläche als Albedo × `palette.ambient`.
Hier zeigt eine **ebene** Fläche dasselbe: der Wert der Palette wird in einen gerichteten Anteil (bei Tag die
Hälfte, bei Regen und Schnee 35 %, nachts nichts) und den Rest als Umgebungslicht geteilt. Weil der Renderer den
Umgebungs- und den Lichtdurchgang einzeln in Anzeigewerte wandelt und addiert (docs/modelle.md §4), wird in
Anzeigewerten geteilt und für eine Bezugs-Albedo (0,38) in lineares Licht umgerechnet. Richtung: wo `RaceBackdrop`
die Sonne zeichnet, gegen die Straßenrichtung am Wagen gehalten (sie schwenkt nicht mit den Kurven); Höhe 12 … 62°,
bei bedecktem Himmel weiches Licht von oben (75°).

| Messung (Render-Prüfung `licht`, Kiel – Hamburg km 2, 12 Uhr, klar; gemessen) | Bild | erwartet |
|---|---|---|
| ebene Platte, Albedo 0,38, im Licht | 99 / 99 / 99 | 97 / 97 / 97 (Arcade: Albedo × `palette.ambient`) |
| dieselbe Platte im Schatten eines Kastens | 47 / 48 / 51 | 48 / 49 / 52 (nur der Umgebungsanteil) |
| 23 Uhr (Render-Prüfung `nacht`): ebene Platte, Albedo 0,38 | 17 / 22 / 34 | 21 / 25 / 36 (Arcade) |
| 23 Uhr: Debug-Straße (unbeleuchtet, mit `palette.ambient` gefärbt) | 6 / 13 / 27 | 16 / 21 / 32 (Arcade) |

Gemessen sind genau diese Punkte: eine Albedo (0,38), mittags und um 23 Uhr, klares Wetter. Alles Weitere ist
**gerechnet** (`light_state()` mit den Näherungen des Renderers für einen Durchgang, ungünstigster Farbkanal einer
ebenen Fläche gegen Arcades Farbe):

| gerechnet für die Stunden … | Albedo 0,2 | 0,3 | 0,45 | 0,6 | 0,9 |
|---|---|---|---|---|---|
| 8:30, 12, 13, 15, 17:30 Uhr, klar | −13 % | −3,6 % | +1,9 % | +4,4 % | +6,9 % |
| dieselben Stunden, Regen | −19 % | −5,3 % | +2,9 % | +6,7 % | +10,6 % |
| 7, 19 und 19:30 Uhr, klar | −26 … −31 % | −10 … −17 % | −2 … +1 % | +5 … +6 % | +10 … +12 % |
| 19:30 Uhr, Regen | −36 % | −12,5 % | +7,1 % | +16,5 % | +26 % |
| 21 und 23 Uhr, klar | −45 % | −12,8 % | +7,3 % | +16,9 % | +26,7 % |
| 21 und 23 Uhr, Regen | −59 % | −16,9 % | +9,6 % | +22,4 % | +35,3 % |

(Zwischen diesen Stunden ist nichts gerechnet. Schnee ist mitgerechnet, hier aber nicht aufgeführt: am Tag und
nachts liegt er zwischen klar und Regen, in der Dämmerung nicht durchweg.)

Das Gesetz trifft Arcades Farbe also nur für mittlere Albedos am hellen Tag (der Unit-Test hält 8:30, 12, 15 und
17:30 Uhr fest: höchstens 7,5 %, bei Regen und Schnee 11 %, für Albedo 0,3 … 0,9). In der Dämmerung und nachts
liegen dunkle Flächen weit darunter und helle bis zu einem Drittel darüber. Das gemessene Nachtbild ist noch
dunkler als diese Rechnung (Platte 17 / 22 / 34 statt 21 / 25 / 36, Debug-Straße bis zu zehn Stufen unter Arcade):
die Rechnung kennt nur einen Durchgang; was der Renderer danach mit dunklen Werten tut, ist in docs/modelle.md §4
gemessen und hier nicht getrennt untersucht. Die Nacht des Gerüsts ist dunkler als die von Arcade. Nachts gibt
die eingebaute Umgebung auch kein Mondlicht (Energie 0); beides entscheidet das Rig.

`plain_sky.gd` zeichnet Arcades Himmelsverlauf (dieselben Zeilen wie `RaceBackdrop.draw_sky`) über der
Horizontzeile und die Nebelfarbe darunter, bei jeder Fenstergröße auf `render.horizon_y_frac` der Höhe (geprüft bei
1280 × 720 und 1280 × 800). Sonne, Wolken und Silhouetten bringt erst `layers/backdrop.gd`.

Im **Tunnel** (Kamera im Tunnel) zeigt die Canvas-Ebene eine Farbe, die Tunnelfarbe; das Licht bleibt mit Energie 0,
der Nebel nimmt die Tunnelfarbe, die Debug-Straße das Tunnellicht. Geprüft headless an den Zustandswerten
(`check_facade.gd` → `umgebung`, Bern – Mailand km 186) und in einem Bild angesehen: dunkle Fläche, warm gefärbte
Fahrbahn mit Banketten, sonst nichts – Röhre, Wände und Lampen gibt es erst mit dem Tunnel-Builder. Mit
`--gfx-debug=cover` soll die Canvas-Ebene magenta und der Nebel aus sein; das steht im Code und ist in diesem
Bauabschnitt **nicht** gelaufen.

### 9.7 Lichtkegel (`assets/shaders/modern/inc/pools.gdshaderinc`)

Lampen und Scheinwerfer des Verkehrs beleuchten den Boden nicht als echte Lichter, sondern als Summe im Shader des
Bodens (D8): `uniform vec4 pool_pos_r[22]` (Mitte relativ zum schwimmenden Ursprung, Radius in m; Radius ≤ 0 wird
übersprungen), `uniform vec4 pool_col[22]` (**linearer** Lichtwert der Mitte – `ModernMaterials.light_value()` –,
`a` = Art: 0 Lampe, 1 Scheinwerfer) und `uniform int pool_count`. `vec3 ce_pools(vec3 world_pos)` liefert das
summierte lineare Licht; Gesetz eines Kegels wie Arcades Lampenkegel: `e = 1 − d²/r²`, Licht = Farbe × `e²` – voll in
der Mitte, Wert und Steigung 0 am Radius.

Im Compatibility-Renderer schreibt `fragment()` `ALBEDO` und `EMISSION` sRGB-kodiert; lineares Licht lässt sich
deshalb nicht einfach aufmultiplizieren. `ce_pools_emission(albedo, world_pos)` ist der `EMISSION`-Wert, mit dem
eine Fläche dieser Albedo die Kegel **zusätzlich** zu ihrem übrigen Licht zeigt (der Grunddurchgang zeigt dann
Albedo × (Umgebungslicht + Kegel)); ein Shader mit eigener Emission addiert linear und kodiert die Summe mit
`ce_pools_encode()`:

```glsl
#include "res://assets/shaders/modern/inc/pools.gdshaderinc"
varying vec3 v_world;
void vertex()   { v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() { ALBEDO = base; EMISSION = ce_pools_emission(ALBEDO, v_world); }
```

Das Material meldet sein Builder mit `renderer.add_pool_material(mat)` an; die Ebene `lights` setzt die drei
Uniforms einmal je Bild auf jedem Material aus `renderer.pool_materials()` (die Positionen wandern mit dem
Ursprung). Ohne diese Ebene bleibt `pool_count` 0.

| Messung (Render-Prüfung `pools`, weiße unbeleuchtete Platte bzw. beleuchtete Platte mit Albedo 0,38; gemessen) | Bild | erwartet |
|---|---|---|
| Mitte eines Kegels mit Lichtwert 0,8 / 0,5 / 0,2 | 230 / 187 / 123 | 231 / 188 / 124 |
| halber Radius (56 % des Lichts) | 178 / 145 / 94 | 179 / 145 / 94 |
| außerhalb des Radius; Eintrag mit Radius −1; Eintrag hinter `pool_count` | 0 / 0 / 0 | 0 |
| zwei Kegel an einer Stelle | 169 / 169 / 210 | 170 / 170 / 211 (Summe) |
| beleuchtete Platte: im Kegel gegenüber außerhalb | + 36 / 30 / 23 | + 36 / 30 / 23 |

### 9.8 A/B-Bilder (`tools/ab_shot.sh`)

```
tools/ab_shot.sh <präfix> [S1|S2|S3|S4|S5] [Argumente der Rennszene …]
tools/ab_shot.sh out/s1 S1
tools/ab_shot.sh out/s3_nacht S3 --hour=22 --weather=rain --shot-times=2,5
GFX_ARGS="--gfx-preset=high" SCREEN=1280x800 tools/ab_shot.sh out/s4_hoch S4
```

Zwei Läufe der Rennszene unter Xvfb mit denselben Argumenten und demselben Seed – `--graphics=arcade` (mit
`--shot-fast`) und `--graphics=modern` (ohne: was der `RenderingServer` beim Zeichnen weiterzählt, stünde sonst
still) –, beide mit `--gfx-sync` bei festen 60 Bildern je Sekunde, jeder mit eigenem leerem `XDG_DATA_HOME`, mit
einem gemeinsamen Mesa-Shader-Cache. Die Sitzung hält die Aufnahmeuhr an, solange Modern die Etappe vorbereitet:
gleiche Aufnahmezeit = gleicher Simulationszustand (Render-Prüfung `gleiche_zeit`). Je Aufnahmezeit entstehen
`<präfix>_arcade_NN.png`, `<präfix>_modern_NN.png` und das beschriftete `<präfix>_ab_NN.jpg`. `S1`–`S5` sind die
Referenzpositionen des Schnitts auf Kiel – Hamburg (km 2, Tankspur ab km 13,6, km 60, km 80 in den City Limits,
km 94 vor dem Ziel; fliegender Start, Vorgabe 2 s nach dem Start). `GFX_ARGS` gilt nur für den Modern-Lauf,
`SCREEN` setzt Bildschirm und Fenster, ein eigener `MESA_SHADER_CACHE_DIR` hält den Cache über viele Aufrufe warm.
Fehlercode 1, wenn ein Lauf scheitert, ein Bild fehlt oder Modern auf Arcade zurückfällt. Gemessen: 21–23 s je
Bildpaar mit dem Gerüst (Arcade 5–6 s, Modern 6–13 s). Vier Aufrufe derselben Position (S3) lieferten viermal
byte-gleiche Arcade- und viermal byte-gleiche Modern-Bilder.

Zu beachten: Die Kilometer der Etappe sind gerafft – bei 146 km/h legt der Wagen in den 2 s bis zur Aufnahme etwa
0,7 km zurück. `S5` (Start bei km 94) zeigt deshalb das Ziel unmittelbar voraus (km 94,7); eine spätere
Aufnahmezeit läge dort hinter dem Ziel.

### 9.9 Prüfungen

| Prüfung | Inhalt |
|---|---|
| `tests/race3d/check_facade.gd` (headless, in `tools/run_tests.sh`) | `haken` (Reihenfolge aller Haken, nichts vor dem Ende jedes `prepare_pending()`, `dt` = 0 bis zum Start), `fassade`, `lampen`, `rebased`, `statistik`, `ausfall`, `umgebung`, `geruest` |
| `tests/race3d/check_seam.gd` → `vertrag` | der ausgelieferte Renderer hat jede Methode, jedes Signal und jedes Mitglied aus Bauplan §4.4.1 und A-7; vor `prepare()` antwortet alles harmlos |
| `tests/race3d/render/check_seam_render.gd` → `modern_bild`, `fenster_16_10` | Bild des Gerüsts (Himmelsverlauf, Debug-Straße an den Bildpunkten des Kameramodells, Kamera = `ChaseCamera3D`), danach der ausgelieferte Renderer mit allem, was es gibt |
| `tests/race3d/render/check_facade_render.gd` | `licht` und `nacht` (9.6), `strasse` (die Debug-Straße nimmt keinen Schatten an, 9.1), `pools` (9.7), `aufwaermen` (Aufwärm-Knoten zwei gezeichnete Bilder vor der Kamera, vom Ladebild verdeckt, danach frei; Selbsttest einmal je Prozess); mit `-- --save=<Ordner>` bleiben die beurteilten Bilder |
| `tests/unit/race3d/test_chunk_services.gd`, `test_renderer_skeleton.gd` | `services`; Zusammenführen der Haken-Daten, Lichtgesetz |

Die Prüfungen der Fassade laufen mit dem **Gerüst allein**: der Prüf-Renderer
(`tests/race3d/fixtures/facade_probe_renderer.gd`, `bare = true`) ist der echte Renderer, lädt aber keine Ebenen-,
Builder- oder Rig-Datei aus `scripts/race3d/` – nur die Debug-Straße, die eingebaute Umgebung und Prüf-Ebenen
(`facade_layer.gd`) bzw. den Prüf-Builder (`facade_builder.gd`). So bleiben sie grün und bedeuten dasselbe, wenn die
Bauabschnitte ihre Dateien ablegen. Nur `geruest`, `vertrag` und der zweite Teil von `modern_bild` /
`fenster_16_10` nehmen den ausgelieferten Renderer mit allem, was es gibt, und prüfen, was für jeden Inhalt gilt.

### 9.10 Messwerte des Gerüsts

| Messung (gemessen; Debug-Straße, eingebaute Umgebung, keine Ebene) | Wert |
|---|---|
| `render()` in GDScript, headless, 30 s Fahrt in Echtzeit-Schritten (Kiel – Hamburg ab km 2 und ab km 60; je ein Lauf, zwei Messrunden) | im Mittel 0,15–0,17 ms, höchstens 2,1–2,8 ms; Sync-Modus im Mittel 0,19 ms, höchstens 5,8 ms |
| Einhängen eines Stücks / Einsammeln / Bauen (Arbeiter-Thread) | höchstens 0,18 ms / 2,0 ms während der Fahrt (beim Laden bis 3,5 ms) / im Mittel 3,3–4,0 ms |
| Vorbereitung headless (12–13 Stücke) | 74–89 ms |
| Vorbereitung unter Xvfb (llvmpipe), erste Etappe des Prozesses | 405–808 ms, davon Selbsttest 202–591 ms; jede weitere Etappe 3 Bilder |
| Zeichenaufrufe / Dreiecke des Bildes bei km 2 | 12 / 13.056 |
| `ERGEBNIS` von `tests/race/run_stage.gd`, Arcade gegen Modern, Kiel – Hamburg (12 Uhr) und dev_testetappe (21 Uhr, Regen) | je 28 Schlüssel, nur `gfx` verschieden |

Die Zeiten stammen aus zwei Messrunden mit je einem Lauf, auf zwei aufeinanderfolgenden Ständen (vor und nach dem
Haken `update()` der Debug-Straße): `render()` im Mittel 0,156 → 0,173 ms ab km 2 und 0,149 → 0,150 ms ab km 60,
Vorbereitung 74–77 → 79–89 ms. Wie stark die Zeiten auf dieser Maschine (vier Kerne, geteilt mit anderen Aufträgen)
von Lauf zu Lauf streuen, ist nicht gemessen; der Unterschied zwischen den Runden ist deshalb nicht dem Haken
zuzuschreiben. Zeiten auf einer echten Grafikkarte und auf dem Steam Deck sind hier nicht messbar.

### 9.11 Übergabe an die Renderer-Bauabschnitte

- Ein Bauabschnitt legt **seine Datei** ab (`builders/<name>.gd`, `layers/<name>.gd`, `environment_rig.gd`) – das
  Gerüst findet sie; `modern_renderer.gd` ändert danach nur noch sein Eigentümer (R1).
- Mit `environment_rig.gd` entfällt die eingebaute Umgebung, mit `layers/backdrop.gd` der eingebaute Himmel, mit
  `builders/road.gd` die Debug-Straße; das Rig muss dann die `ce_*`-Globals setzen und das eine Schattenlicht halten.
- Noch nicht im Gerüst: projektweite Renderzustände je Qualitätsstufe (MSAA, 3D-Auflösung, Schattenatlas –
  `quality.gd`), der Countdown-Wächter und das Signal `quality_lowered` (es ist deklariert, wird aber nie gesendet),
  Aufwärmen über die Knoten der Haken hinaus (`prewarm.gd`), das Freigeben der Materialien beim Verlassen des Modus
  (`ModelDB.release_all()` + `ModernMaterials.drop_shared()` – Sache des Moduswechsels).
- `graphics.modern.prepare_timeout_s` steht nicht in `config/game_config.json` (Vorgabe im Code 120 s).

Alle diese Punkte hat der Renderer-Kern erledigt (Abschnitt 10: `quality.gd`, `perf_probe.gd`, `prewarm.gd`,
`RaceRenderers.leave_modern()`, `prepare_timeout_s` = 120 s in der Konfiguration).

## 10. Renderer-Kern: Straße, Umgebung, Licht, Qualität

Der Bauabschnitt R1 füllt das Gerüst mit dem, was jedes Bild braucht: die Fahrbahn mit aller Markierung, die
Leitplanken, das Umgebungs-Rig (Licht, Schatten, Nebel, Spiegelhimmel, Globals), den Hintergrund, die Lichter, die
Verfolgungslichter, die Qualitätszustände, den Wächter und das Aufwärmen. Alles hängt sich über die festen
Dateinamen und die Haken aus Abschnitt 9 ein; keine Datei eines anderen Bauabschnitts wird benannt.

### 10.1 Was wo liegt

| Datei | Inhalt |
|---|---|
| `builders/road.gd` + `assets/shaders/modern/road.gdshader` | Fahrbahn: ein Mesh je Stück, eine Fläche, ein geteiltes Material, Render-Ebene 2 (Boden) |
| `builders/roadside.gd` | Leitplanken (W-Profil), Pfosten, Rückstrahler, Leitpfosten – ein Mesh je Stück in der Materialklasse `vpbr` |
| `environment_rig.gd` | `Environment`, das eine `DirectionalLight3D` (Sonne / Mond), Spiegelhimmel, `ce_*`-Globals |
| `layers/backdrop.gd` | `RaceBackdrop` auf Canvas-Ebene −10 bei jedem Seitenverhältnis |
| `layers/lights.gd` + `assets/shaders/modern/reflector.gdshader` | zwei Scheinwerfer-Spots, Punktlicht-Pool, Lichtkegel am Boden, Reflexe der Rückstrahler |
| `assets/shaders/modern/inc/headlight.gdshaderinc` | Arcades Abblendlicht-Kegel auf dem Boden (für Fahrbahn und Gelände) |
| `assets/shaders/modern/inc/pools.gdshaderinc` | Lichtkegel von Lampen und Verkehr, jetzt mit Richtung (`pool_dir`) und `pool_ambient` |
| `layers/overlay.gd` + `assets/shaders/modern/overlay.gdshader` | Lichter einer Polizeiverfolgung an den unteren Bildecken (Canvas-Ebene 2) |
| `quality.gd`, `perf_probe.gd`, `prewarm.gd` | Viewport-Zustände je Stufe, Bildzeiten und Wächter, Aufwärmen in vier Lichtsituationen |

### 10.2 Fahrbahn (`builders/road.gd`, `road.gdshader`)

**Querschnitt** wie bei Arcade (`RoadRenderer._draw_ground`): Asphalt von −Spuren × 3,75 m / 2 bis zum rechten Rand
der Fahrstreifen plus Tankspur, daneben auf Fahrbahnhöhe 2,5 m (Standstreifen rechts, befestigter Streifen und
Gras des Mittelstreifens links, Schotterbankett der Landstraße, Notgehweg im Tunnel, auf Brücken 0,4 m mehr bis zum
Geländer). In den City Limits endet das Band am Asphalt; Bordsteine (0,25 m) und Gehwege liegen 0,14 m höher. Die
Außenkante ist genau `ChunkContext.shoulder_edge()`, dort beginnt das Gelände. Zwei Dreiecke je Segment, in den
City Limits vierzehn. Bruchteile von Spuren (Spurwechsel-Übergänge) kommen aus `Track` wie in Arcade.

**Markierung ganz im Shader**, Maße und Rhythmus von `RoadRenderer._draw_markings` auf den Zentimeter: Randlinien
(links 0,15–0,45 m innen, rechts bis zur Kante, 0,3 m), Leitlinien 0,15 m mit Strichen 6/12 m (Autobahn,
Landstraße) bzw. 3/6 m (Stadt) in Arcades Phase, die breite Trennlinie (1,6 × 0,3 m) und die Randlinie der Tankspur,
die Schraffur des sich öffnenden Keils, das Schachbrett an Start und Ziel, Zebrastreifen alle 330 m in den City
Limits. Jedes Fragment weiß aus UV (Meter von der Mitte, Meter entlang der Straße modulo 1.440 m) und den
Kantenwerten der Reihe (CUSTOM0), was es ist; nichts liegt als Streifen über dem Asphalt.

**Kantenglättung analytisch**: der Fußabdruck eines Bildpunkts in Straßenmetern kommt aus `dFdx`/`dFdy`; eine Linie
deckt den Teil des Fußabdrucks, der auf ihr liegt (Kastenfilter). Eine Linie, die dünner als ein Bildpunkt ist,
verblasst mit ihrer Deckung statt zu flimmern; ferne Striche verschmelzen zu ihrem Tastverhältnis.

**Feindetail** (jede Stufe verschwindet, bevor sie kleiner als ein Bildpunkt wird): Körnung, Längsstreifen und
Chargen des Asphalts, polierte und etwas dunklere Fahrspuren, Öl in der Spurmitte, vergossene Fugen neben den
Spurgrenzen, Flicken jüngeren Asphalts mit Teerrand, Reifenspuren in den Fahrspuren (häufiger in Kurven, in der
Stadt und an der Tankspur), abgenutzte Farbe, Schmutz zum Bankett hin, Gehwegplatten, Bordsteine von einem Meter.
Alles ist eine Funktion der Straßenkoordinaten (kein `TIME`): derselbe Ort sieht immer gleich aus (Regel 10).
„Details: Niedrig“ dämpft nur dieses Feindetail (0,7); Markierung und Kanten hängen von keiner Stufe ab (Regel 9).

**Wetter**: nasser Asphalt wird um ein Drittel dunkler, glatter und spiegelt zum Horizont hin den hellen Himmel
(Nebelfarbe, wie Arcades 28 % am Ende der Sicht); Schnee liegt an den Rändern der Fahrstreifen mit ausgefranster
Kante; im Tunnel weder Nässe noch Schnee.

**Licht**: das Mesh liegt auf Render-Ebene 2 (`GROUND_LAYERS`). Es nimmt das Umgebungslicht und die eine Sonne mit
ihrem Schatten; die echten Spots und Punktlichter der Lichter-Ebene lassen es aus. Abblendlicht und Lichtkegel
kommen analytisch dazu (`inc/headlight.gdshaderinc`, `inc/pools.gdshaderinc`): Arcade addiert Licht in
Anzeigewerten (Albedo × (Umgebung + Licht)), der Shader rechnet denselben Zuwachs über `pool_ambient` in lineares
Licht um. Rückstrahlung mit Arcades Faktoren: Asphalt 0,9, Farbe 1,6, Schachbrett 1,2, Gras 0,45–0,8. Ein späterer
Gelände-Shader hängt sich mit denselben zwei Includes an und legt sein Mesh ebenfalls auf Ebene 2.

### 10.3 Leitplanken und Leitpfosten (`builders/roadside.gd`)

Wo etwas steht, ist Arcades Regel (`_draw_structures`): Leitplanke links an jedem Segment mit `guardrail` außerhalb
von Tunneln, rechts ebenso, außer neben einer Tankspur oder einem Grenzübergang. Der Holm ist ein echtes W-Profil
(0,48–0,80 m hoch) aus gefaltetem Blech mit Rückseite, die Vorderkante auf der Außenkante des Banketts; wo eine
Planke im Stück beginnt oder endet, taucht sie über ein Segment in den Boden. Pfosten alle 6 m hinter dem Holm, am
ersten Pfosten nach jedem Vielfachen von 50 m ein Rückstrahler im Tal des Profils (rechts gelb, links weiß). Ohne
Leitplanke stehen Leitpfosten alle 50 m (weiß, 1,05 m, schwarzes Band mit Rückstrahler). Die Fahrbahn zeigt unter
dem Holm und an jedem Pfosten einen weichen Kontaktschatten. Nur der Schattenwurf hängt von der Qualität ab
(`shadow_casters` ≥ 1); was den Fahrbahnrand zeigt, wird nie ausgedünnt (Regel 9). Die Rückstrahler meldet der
Builder der Lichter-Ebene (`add_reflectors`), die sie im Abblendlicht aufleuchten lässt.

### 10.4 Umgebung (`environment_rig.gd`)

Das Rig ersetzt die eingebaute Umgebung (9.6) und wird als `renderer.env` angeboten (`env.get("state")`,
`env.get("sun")`, `env.call("sky_palette", pal)`).

- **Ein Schattenlicht** (D5): genau eine `DirectionalLight3D`, immer mit `shadow_enabled`; Sonne bei Tag, Mond in
  der Nacht; im Tunnel Energie 0, nie versteckt. Schattenmodus, Kaskaden, Reichweite und Filter aus den Stufen
  (orthogonal / 2 / 4 Kaskaden, 80 / 120 / 200 m).
- **Hintergrund** `BG_CANVAS` hinter Canvas-Ebene −10, linearer Tonemapper, Nachbearbeitung fest an (D6, D7).
- **Lichtgesetz** (`light_state()`, rein, unit-getestet): eine **ebene** Fläche der Bezugs-Albedo zeigt Arcades
  Farbe (Albedo × `palette.ambient`). Davon ist ein Anteil gerichtet – die Hälfte unter klarem Tageshimmel, ein
  Achtel bei Regen und Schnee, ein Fünftel als Mondlicht – der Rest ist Umgebungslicht. Schatten zeigen den
  Umgebungsanteil allein, Flächen zur Sonne sind heller als der Boden: das Bild bekommt Tiefe. Die Sonne ist warm
  getönt, das Umgebungslicht deshalb kühler: blaue Schatten. Weil der Renderer Umgebungs- und Lichtdurchgang einzeln
  in Anzeigewerte wandelt und die feste Nachbearbeitung beide Näherungen noch einmal anwendet, wird in Anzeigewerten
  geteilt und mit den Kurven des Renderers zurückgerechnet (`post_inverse`).
- **Nachtboden** (A-4): zur Nacht hin sinkt die Bezugs-Albedo von 0,38 auf 0,29, das hebt das Umgebungslicht über
  die Schwelle, an der die Kurven dunkle Werte verschlucken; das Mondlicht kommt größtenteils zusätzlich.
- **Sonnenstand**: Arcades Panorama hält die Sonne den ganzen Tag vor dem Wagen – im echten 3D lägen Heck, Schilder
  und alles, worauf die Kamera blickt, mittags im Gegenlicht-Schatten. Die tiefe Sonne (Morgen, Abend) steht, wo
  Arcade sie zeichnet; mit der Höhe schwenkt sie bis 2 rad nach links hinter den Wagen. Höhe 13–46°, bei Regen und
  Schnee 68°. Die Richtung hält sich gegen die Straßenrichtung am Wagen (sie schwenkt nicht mit jeder Kurve). Der
  Hintergrund zeichnet die Sonnenscheibe an derselben Stelle (`sky_palette()`): Licht, Schatten und Scheibe passen
  immer zusammen.
- **Tunnel**: das Tunnellicht blendet 12 m vor dem Portal bis 14 m hinein über (`tunnel_blend()` – eine Funktion
  des Orts); Tunnelnebel ab 12 m nach Arcades Gesetz (Exponent 0,8 über die Dunkelstrecke).
- **Nebel** (F4): linear von 0,45 × bis 1,0 × Sichtweite in der Nebelfarbe der Palette – nie mehr als Arcade.
- **Spiegelhimmel** (D7): ein kleiner `ProceduralSkyMaterial`-Himmel im Palettenverlauf, ohne Sonnenscheibe, nie
  `TIME`, nur Quelle von Spiegelungen (Lack, Glas, nasse Fahrbahn); neu höchstens alle `sky_update_s` (2 s) und nur,
  wenn sich eine Farbe um mehr als 1,5/255 bewegt hat. Glow ab „Effekte: Einfach“, SSAO bei „Voll“.
- **Globals**: `ce_time`, `ce_night`, `ce_wet`, `ce_snow`, `ce_wind`, `ce_fog_color`, `ce_fog_range`, `ce_sun_dir`,
  `ce_sun_color`, `ce_ambient` (lineare Lichtwerte im Sinne von `ModernMaterials.light_value()`), `ce_tunnel` – jedes
  nur, wenn es sich ändert. `ce_headlight*` setzt die Lichter-Ebene, `ce_far_y` der Fernboden.
- `--gfx-debug=cover` schaltet den Nebel ab, `nolight` legt alles Licht in den Umgebungsanteil.

### 10.5 Hintergrund (`layers/backdrop.gd`)

`RaceBackdrop` (Himmelsverlauf, Sonne, Mond, Sterne, Wolken, alle Silhouetten mit den Stadt-Überschreibungen) auf
Canvas-Ebene −10. Er bekommt eine eigene `RoadProjection` in der **logischen** Bildgröße (1280 × 720, 1280 × 800,
1680 × 720 …) plus 48 px Rand links und rechts für das Wackeln, mit der Brennweite der Kamera: Himmel und
Silhouetten drehen genau so weit wie die Welt. Die Silhouetten stehen auf der wahren Horizontzeile
(`render.horizon_y_frac`), darunter ist die Leinwand nebelfarben. Gedreht wird nach `bg_offset` plus dem echten
Blickwinkel der Kamera gegen die Straßenrichtung am Wagen. Im Tunnel blendet die Leinwand ins Dunkel, solange kein
Tunnel-Builder eine Röhre zeichnet. Neu gezeichnet wird nur, wenn sich das Bild um etwa einen Viertel-Bildpunkt
ändern würde (Richtung, Wolkenzug, Sterne, Palette, Größe).

### 10.6 Lichter (`layers/lights.gd`)

Echte Lichter, alle ohne Schatten, höchstens 2 Spots + 8 Punktlichter (D8):
- **Abblendlicht**: zwei `SpotLight3D` an der Wagenfront (30°, Reichweite `render.headlight_range_m`), Stärke
  `render.headlight_intensity` × min(1, 1,4 × `palette.lights`), im Tunnel mindestens 0,35 – Arcades Gesetz. Sie
  beleuchten, was auf dem Boden steht (Fahrzeuge, Leitplanken, Schilder, Requisiten); den Boden selbst lassen sie
  aus (Ebene 2), dort zeichnet der Shader Arcades langen Kegel.
- **Punktlicht-Pool** (2 / 4 / 8 nach „Effekte“): wandert zu den nächsten festen Lampen, die Builder über
  `renderer.add_lamps()` melden; die fernste blendet aus, bevor die nächste übernimmt.
- **Lichtkegel am Boden** (analytisch, 22 Einträge): die nächsten Lampen (höchstens 16, 0,55 × `lights` in der
  Mitte) und die Scheinwerferkegel des Verkehrs (Arcades Regel: die ersten sechs Wagen bis 140 m vor der Kamera,
  Kegel von 34 m, 0,5 × `lights`), einmal je Bild an jedes Material aus `renderer.pool_materials()`.
- **Reflexe**: Rückstrahler im Abblendlicht leuchten als kleine additive Scheiben auf (höchstens 24, Stärke aus dem
  Kegel am Ort, nur wenn sie zum Wagen blicken).
Tagsüber kostet die Ebene ein paar Vergleiche je Bild. Nichts liest die Wanduhr.

### 10.7 Verfolgungslichter (`layers/overlay.gd`)

Canvas-Ebene 2 (über dem 3D-Bild und dem späteren Bild-Nachlauf, unter dem HUD): ein bildfüllendes `ColorRect` mit
`overlay.gdshader` zeichnet Arcades blaues und rotes Leuchten an den unteren Ecken (Radien 330 und 260 Zeilen von 720,
Stärke 0,32 bzw. 0,22 × `chase01`, Seitenwechsel 2,5-mal je Sekunde nach `view.time`), bei jedem Seitenverhältnis an
den Ecken des logischen Bildes. Ohne Verfolgung ist es versteckt. Den Radarblitz zeichnet in beiden Modi das HUD.

### 10.8 Qualität, Wächter, Aufwärmen

**`quality.gd`** setzt beim Vorbereiten, was Viewport und RenderingServer betrifft – MSAA (aus / 2× / 4×),
3D-Auflösung (bilinear, das HUD bleibt scharf), Größe des Schattenatlas (1024 / 2048 / 4096), Filter (hart / weich
niedrig / weich mittel) – und stellt beim Verlassen der Etappe wieder her, was vorher galt (Render-Prüfung
`arcade_gleich`: Arcade danach pixelgleich). Alles andere an einer Stufe gehört dem, der es zeichnet (Haken
`apply_quality`). Nichts, worauf der Spieler reagieren muss, hängt an einer Stufe (Regel 9).

**Wächter** (`perf_probe.gd`, D34 c): während des Countdowns werden die Bildzeiten gesammelt (die ersten 0,4 s
nicht), nach mindestens 20 Bildern und 1 s einmal beurteilt – `Gfx.watchdog_verdict` gegen die Bildzeit der
Anzeige, mindestens 1/60 s (ein 144-Hz-Bildschirm macht 60 Bilder je Sekunde nicht „langsam“), oder eine
Bildrate unter `countdown_min_fps`. „Langsam“ senkt die Voreinstellung für diese Etappe einmal um eine Stufe
(Hoch → Mittel → Niedrig, Steam Deck und Eigene → Niedrig): Viewport-Zustände, Schattenwerfer und -reichweite,
Glow, SSAO, Dichten und LOD-Abstände folgen sofort; Schattenmodus, Kaskaden-Überblendung und Filter bleiben, weil sie
Shader-Varianten wählen (D10). Die Sitzung bekommt `quality_lowered(preset)`: Meldung im HUD („Das Bild läuft zu
langsam – die Grafikqualität ist für diese Etappe auf „…“ gesenkt.“) und das Ergebnisfeld `gfx_lowered`.
Gespeichert wird nichts. Aus mit `--gfx-sync`, `--no-watchdog`, headless und ohne Countdown.
Die Sonde liefert außerdem `frame_ms_median` / `frame_ms_p95` (letzte 240 Bilder) und `start_frame_ms_max` /
`start_frame_ms_median` (die ersten 30 s nach dem Ladebild – für die Aufwärm-Prüfung).

**Aufwärmen** (`prewarm.gd`, D10): Hinter dem Ladebild steht die Startansicht mit allen Stücken und den
Aufwärm-Knoten der Haken; sie wird in vier Lichtsituationen gezeichnet – ohne positionelles Licht, mit Spot, mit
Punktlicht, mit beiden –, je zwei gezeichnete Bilder (`WARMUP_FRAMES` = 8), mit eigenen Lichtern an der Kamera, die
wie alle echten Lichter den Boden auslassen. Die Engine übersetzt für jede dieser Situationen eigene Programme;
Abblendlicht und Lampen kommen sonst erst in der Dämmerung oder unter der ersten Laterne – mitten in der Fahrt.

### 10.9 Moduswechsel

`RaceRenderers.leave_modern()`: wird nach einem Modern-Renderer ein Arcade-Renderer erzeugt (Moduswechsel oder
Rückfall), gibt `ModelDB.release_all()` alles frei und `ModernMaterials.drop_shared()` die geteilten Materialien
mit ihren Texturen (A-4, §4.11). Zwischen zwei Modern-Etappen bleibt beides (die nächste Etappe würde dasselbe
wieder laden und übersetzen). Aufgerufen über die Skriptpfade: die Datei lädt jeder Arcade-Start, sie darf keine
Klasse des Modern-Renderers benennen.

### 10.10 Prüfungen

| Prüfung | Inhalt |
|---|---|
| `tests/unit/race3d/test_road_builder.gd` | Querschnitt der Autobahn, Periode und Schachbrett, Leitlinien bei Bruchteil-Spuren, Bordsteine und Zebrastreifen, Tunnel, Brücke und Bodenfarbe, Tankspur der Schnitt-Etappe, Einhängen und Leitplanken |
| `tests/unit/race3d/test_environment_rig.gd` | Kurven und ihre Umkehrungen, ebene Fläche = Arcades Farbe, Anteil und Schattenfarbe, Sonnenstand, Nacht, Mond und Boden, Tunnel-Rampe, Wind |
| `tests/unit/race3d/test_quality.gd` | Viewport-Zustände gesetzt und zurückgegeben, Wächter-Stufe ohne neue Shader-Variante, Zielbildzeit, Wächter des Countdowns, Bildzeit-Statistik, Aufwärm-Phasen |
| `tests/race3d/check_modern_stage.gd` (headless) | `inhalt`, `nacht`, `tunnel`, `waechter`, `wechsel`, `kern_zeit`, `ergebnis` (Kiel – Hamburg mit dem Autopiloten: `ERGEBNIS` in Arcade und Modern gleich) |
| `tests/race3d/render/check_road_parity.gd` | `gerade` (S1: Linienmitte ≤ 1 px neben Arcade), `kurve_400` (≤ 8 px bis 150 m), `kurve_136` (≤ 27 px bis 100 m, beide mit `look_gain` 0, A-3), `fenster` (1280 × 800 und 1680 × 720 gefüllt) |
| `tests/race3d/render/check_light_base.gd` | `tageslicht` (S1: Asphalt, Gras, Himmel ≤ 10 % neben Arcade), `schatten` („Aus“ gegen „Mittel“ ± 2 %) |
| `tests/race3d/render/warmup_cold.gd` | Aufwärm-Prüfung mit kaltem Shader-Cache (einmal je Meilenstein, nicht im Lauf der Render-Prüfungen – Aufruf im Kopf der Datei) |

`check_road_parity` misst jede Linie quer zu ihrer Richtung im Bild (bilinear entlang der Normalen der projizierten
Tangente) und vergleicht mit Arcades eigenem Reihenmodell (`RoadRenderer._project`, eingefroren und unverändert
benutzt). Randlinien zählen, solange sie mindestens 1,5 px breit sind – daneben liegen helle Seitenstreifen –,
Leitlinien ab 0,6 px. `check_light_base` vergleicht Mediane über Probenpunkte, die in **beiden** Bildern das
Material zeigen (Sprites, Wolken, Linien bleiben außen vor). Beide laufen ohne Verkehr und ohne HUD.

### 10.11 Messwerte

| Messung (gemessen auf dieser Maschine) | Wert |
|---|---|
| `render()` in GDScript, headless, 1.500 Bilder einer Fahrt mit 150 km/h ab Kiel – Hamburg km 2, nur Straße, Leitplanken, Rig, Hintergrund, Lichter, Overlay | 0,117 ms im Mittel (höchstens 1,75 ms); mit dem Zeichnen des Hintergrunds (0,494 ms je Neuzeichnen, bei Tag in 19 % der Bilder) 0,208 ms (`check_modern_stage` „kern_zeit“, bestes von höchstens drei Läufen) |
| Einhängen eines Stücks (Straße + Leitplanken), headless | höchstens 0,41 ms |
| Linienlage gegen Arcade (`check_road_parity`) | Gerade 0,23 px; R 400 m 7,11 px bis 150 m; R 136 m 13,27 px bis 100 m; gegen das eigene Kameramodell höchstens 0,32 px |
| Tageslicht bei S1 gegen Arcade (`check_light_base`) | Asphalt −6,7 %, Gras +1,5 % (Geländevertretung), Himmel −4,8 %; „Schatten: Aus“ gegen „Mittel“ −0,32 % (1,25 % des Bodens im Schatten der Leitplanken) |
| Aufwärmen mit kaltem Cache (`warmup_cold.gd`, „Mittel“, 30 s) | 0 Shader-Varianten während der Fahrt um 12 Uhr und um 19:06 Uhr; längstes Bild 497 ms bei Median 179 ms bzw. 362 ms bei 189 ms (Last der Maschine 7–19) |
| `ERGEBNIS` Kiel – Hamburg, Autopilot, Arcade gegen Modern | 28 Schlüssel, nur `gfx` verschieden |
| `modern_sight.gd --full` / `modern_path_check.gd --full` mit `max_chunks` = 18 | F1 0 Fälle bis 270 m (99,4 Mio. Stichproben), F2 höchstens 0,596, F3 0 von 5.923, F7 0; Abstand 267,6 m, 0 Kamerapositionen über 18 Stücken |
| Unter OpenGL (llvmpipe, Xvfb, „Mittel“, Kiel – Hamburg km 2, 12 Uhr, kalter Cache, Last der Maschine 12,5) | `render()` im Mittel 1,14 ms Wanduhr (bei dreifach überbuchten Kernen), Einhängen eines Stücks höchstens 2,83 ms, Bauen im Mittel 7,0 ms (Arbeiter-Thread), 37 Zeichenaufrufe, 24.200 Dreiecke; den Schattendurchgang meldet der Compatibility-Renderer mit 0 Zeichenaufrufen (die Schatten sind da: `check_light_base`) |
| Aufwärm-Prüfung, alle Läufe mit kaltem Cache nach der HUD-Korrektur | 0 Varianten während der Fahrt in allen drei Läufen; das Bildzeit-Kriterium (≤ 3 × Median) bestanden zweimal (Last 7), einmal nicht (Last 12,5: ein Bild von 1.167 ms bei Median 353 ms, ohne Übersetzung – Ausreißer der Maschine) |

Was die Zahlen nicht sagen: Zeiten einer echten Grafikkarte und des Steam Deck sind hier nicht messbar; die
Aufwärm-Zeiten unter llvmpipe schwanken mit der Last der Maschine stärker als jede Übersetzung (deshalb zählt die
Prüfung die Cache-Dateien). Die Tageslicht-Probe „Gras“ misst, solange `builders/terrain.gd` fehlt, die
unbeleuchtete Geländevertretung – mit dem echten Gelände misst sie dessen Shader.

### 10.12 Offene Punkte

- **Gelände an das Licht anschließen**: der Gelände-Shader legt sein Mesh wie die Fahrbahn auf Render-Ebene 2 und
  bindet `inc/pools.gdshaderinc` und `inc/headlight.gdshaderinc` ein (`ce_pools_display_light` mit
  `pool_ambient`, Rückstrahlung von Gras 0,45–0,6) und meldet das Material mit `add_pool_material()` an. Sonst
  beleuchten die echten Spots das Gelände nur als kurzen hellen Fleck, und Lampen- und Verkehrskegel fehlen dort.
- **„Schatten: Aus“ gegen „Mittel“**: die Prüfung vergleicht, wie im Bauplan, die mittlere Helligkeit des ganzen
  Bodens. Mit Bäumen und Fahrzeugen liegt mehr Fläche im Schatten, das Mittel sinkt dann zu Recht um mehr als 2 %;
  gemeint ist (D5), dass beleuchtete Flächen gleich hell bleiben – die Prüfung ist dann auf unbeschattete Bereiche
  umzustellen (Entscheidung der Zusammenführung).
- **Mittagssonne**: sie steht hinter dem Wagen; am Himmel fehlt mittags Arcades Sonnenscheibe (Himmel −4,8 % in der
  Probe). Ob eine Scheibe „vorn“ trotzdem gezeichnet werden soll, ist eine Bildentscheidung.
- **Feindetail**: Teernähte quer über die Fahrstreifen, kräftigere Körnung im Nahbereich, Asphalt etwas heller (die
  Probe liegt bei −6,7 %) – kleine Shader-Änderungen, danach `check_road_parity` und `check_light_base` erneut.
- **HUD hinter dem Ladebild**: die Sitzung setzt `hud.state` vor dem Start direkt; wer das HUD umbaut, hält es ohne
  `update_state()` zeichenbar.

## 11. Fahrzeuge, Lichtpunkte und Schilder (Bauabschnitt R3)

Alles hier sind Dateien, die das Gerüst über ihren festen Namen findet (Abschnitt 9): zwei Ebenen, ein Builder und
die Materialien der Fahrzeuge. Sie reden mit dem Rest nur über die Fassade (A-7) und `has_method`.

| Datei | Aufgabe |
|---|---|
| `scripts/race3d/layers/vehicles.gd` | jedes Auto der Ansicht (Verkehr, Polizei, Spieler) als 3D-Modell: Pose, Detailstufen, Lampen, Schatten |
| `scripts/race3d/layers/flares.gd` | Lichtpunkte aller Lampen (Fahrzeuge und feste Lampen der Builder), Verdeckung über den Tiefenpuffer |
| `scripts/race3d/vehicle_pose3d.gd` (`VehiclePose3D`) | reine Mathematik: Ausblendgesetz, Pose, Detailstufe, Lampenstufen, Leuchtgrößen |
| `scripts/race3d/model_factory.gd` | Modelle aus dem Manifest (mit Gelenk: `build(…, articulated)`), Kasten für Sets ohne Modell |
| `scripts/race3d/sign_atlas.gd` (`SignAtlas`), `sign_canvas.gd` | alle Schilder der Etappe einmal vorgezeichnet, ein Atlas |
| `scripts/race3d/builders/signs.gd` | Schilder als Tafeln mit Pfosten im Querschnitt der Straße |
| `assets/shaders/modern/{vpbr,glass,flare,vehicle_shadow,sign}.gdshader` | Lack, Glas, Lichtpunkte, Kontaktschatten der Fahrzeuge, Schilder |

### 11.1 Fahrzeug-Ebene

- **Daten statt Code.** Ein Set löst sich über `ModelDB` in ein Modell auf (beliebig viele Stufen, Gelenke aus
  `groups`) oder in seinen Platzhalter `{"fallback": "box"}`. Für einen Platzhalter zeichnet die Ebene **Arcades
  eigenes Bild** dieses Fahrzeugs (Ersatzbild, Abschnitt 11.8: Sprite-Sets als Bild, Kasten-Sets wie Busse und Lkw als
  Kasten mit Arcades Flächen); nur wenn auch das Blatt fehlt, zeichnet `ModelFactory.build_box()` als letzten Ausweg
  einen gemalten Kasten in Größe und Lack des Sets mit dunklen Scheiben, Rädern und Lampen auf den Lampenkanälen
  (Rück-/Bremslicht, Blinker, Scheinwerfer, Kennzeichen, bei Polizei Blaulicht A/B). Ein neues Modell im Manifest
  erscheint ohne Codeänderung; ein fehlendes Modell ist nie ein fehlendes Auto. `prepare()` lädt die Modelle aller
  Fahrzeug-Sets der Etappe (`ModelDB.request(…, self)`) und die Blätter der Sets ohne Modell; fehlt danach eine Datei
  eines Modells, meldet die Ebene `fail_reason() = "manifest"`.
- **Pose aus zwei Punkten der Straße** – Heck und Front des Kollisionsquaders (`path.world(z, x, 0)` und
  `path.world(z + Länge, x, 0)`): Gier- und Nickwinkel folgen der Straße, der Ursprung liegt in der Mitte am Boden.
  Eigene Richtung beim Spurwechsel aus der Quergeschwindigkeit (`VehiclePose.own_heading`), kritisch gedämpft wie
  Arcades Sprites (`render.vehicle_yaw_smooth_s`). Spielerauto zusätzlich: Lenken × 3°, Untersteuern × 6° (Nase in
  die Kurve), Wanken ≤ 2,5° um 0,38 m Höhe (nur die Karosserie, die Räder bleiben am Boden) – die Werte von
  `render.player_*`; Blinken über `view.player.visible`. Die Grundfläche liegt höchstens 0,3 m neben dem
  Kollisionsquader (20 Posen bis R = 120 m, Unit-Test).
- **Sattelzug:** die Einheiten der Gruppen (`tractor`, `trailer`) werden einzeln gestellt: die Zugmaschine vom
  Straßenpunkt unter ihrem Drehpunkt bis zur Front, der Auflieger vom Heck bis zum Boden unter dem Königszapfen, den
  er mit der Zugmaschine teilt. Die fernen Stufen (ein Netz) sind starr.
- **Räder** drehen sich mit der gefahrenen Strecke (`z / Radius`; linke Räder sind das gedrehte rechte Rad: anderes
  Vorzeichen), Vorderräder lenken mit der Kurve (und beim Spieler mit dem Lenkeinschlag).
- **Detailstufen** nach Wegstrecke: die Grenzen des Manifests skaliert mit `vehicle_lod0_m / 40` bzw.
  `vehicle_lod1_m / 120` der Qualitätsstufe, 5 % Hysterese gegen Flackern; die Knoten jeder Stufe werden beim ersten
  Gebrauch gebaut und je Set wiederverwendet (Pool).
- **Lampen** über `lamp_a` / `lamp_b`: Rücklicht und Scheinwerfer mit `tail` der Ansicht (Lichter der Palette) und
  immer im Tunnel, Bremse, Blinker im Takt von Arcade (`blink_t`, 0,72 s), Blaulicht A/B. **Sonnenmaske** `sun` = 0
  für Autos im Tunnel. **Ausblendung** nach Wegstrecke mit Arcades Gesetz (F5, Dither). Uniforms werden nur bei
  Änderung gesetzt.
- **Schatten:** mit Fahrzeug-Schattenwerfern (`shadow_casters ≥ 1`) wirft die grobe Hülle des Modells; in jeder
  Stufe liegt zusätzlich ein weicher Kontaktschatten unter jedem Auto (ein MultiMesh für alle,
  `vehicle_shadow.gdshader`; Klasse `vehicle_shadow` – `contact_shadow.gdshader` ist der Schattenfleck der Requisiten,
  docs/renderer-modern-gelaende.md §4.7) – ohne Werfer ist er der einzige Schatten und kräftiger. Ein Ersatzbild
  (Arcades Sprite) wirft weder Sonnen- noch Kontaktschatten: sein Schatten ist ins Bild eingebacken (Abschnitt 13.5);
  Kasten-Ersatzbilder (Busse, Lkw) werfen wie Modelle.
- `snapshot()` → `vehicles [{id, set, model, lod, z, x, yaw_deg, lamps, fade, sun, shown, box, player, cast, caster}]`
  (`cast`: die gezeigte Stufe wirft Schatten; `caster`: ihre Schattenhülle ist sichtbar, −1 ohne Hülle);
  `perf()` → `vehicles`, `fallback_sets`, `vehicle_us_avg`, `vehicle_builds`, `contact_shadows`.

### 11.2 Lichtpunkte

Ein additiver Schein je Lampe (`flare.gdshader`, Arcades Leuchttextur: voll in der Mitte, 55 % bei einem Viertel
des Radius): Radius = Faktor × Pixel je Meter, nie kleiner als in Arcade – Rück-/Bremslicht ≥ 2 px, Blinker ≥
`INDICATOR_MIN_GLOW_PX` (+1 px nachts) mit einem Lampenkern von mindestens `INDICATOR_MIN_PX` (2,4 × 2,0 px);
Stärken wie Arcade (Rücklicht nachts 0,9, Bremse 0,35 + 0,4 × Nacht). Größen in logischen Pixeln (720 Zeilen): bei
jeder Fenstergröße so groß wie in Arcade. Ein Rück- und ein Bremslicht an derselben Stelle sind ein Schein.
**Verdeckung:** der Lichtpunkt sitzt 6 cm vor seiner Lampe; fünf Abtastungen der Tiefentextur um ihren Bildpunkt
entscheiden, wie viel davon sichtbar ist – hinter einer Kuppe, einem Lkw oder einer Wand 0 Pixel. (Die
Tiefentextur gibt es im Compatibility-Renderer nur in `fragment()`, umgekehrtes Z, NDC-z = 2d − 1.)
**Feste Lampen:** `renderer.add_lamps(parent, lamps)` (A-7) landet in `add_static()`: nachts (Rollen `lights`,
`street`, … mit den Lichtern der Palette, `on` immer) ein Schein, der dem Elternknoten folgt und verschwindet, wenn
der Knoten den Baum verlässt. Fernschein: nah ist er ein Halo (35 %), wo die Leuchte kleiner als ein Pixel wird,
trägt er die Lampe allein (100 %).

### 11.3 Lack und Glas

`vpbr.gdshader`: Lack ist Grundlack unter Klarlack – der Klarlack spiegelt die Umgebung mit Fresnel (bei
streifendem Blick auf 25 % begrenzt) und hat eine eigene scharfe Sonnenspitze; metallischer Lack funkelt nah an der
Kamera (Flakes, ab 14 m ausgeblendet); Metalle (Felgen, Chrom) und glatte Teile spiegeln ebenfalls. Die Umgebung ist
**analytisch** (Zenit, Horizont mit Landschaftsband, Boden aus den Uniforms `env_*`, im Tunnel die Röhre): sie
braucht keine `Sky` am Environment und gilt in jeder Voreinstellung. Spiegelungen gehen über `EMISSION`
(unbeschattet, vom Nebel erfasst). `glass.gdshader` bekommt dieselbe Spiegelung zum Aussehen von AS1 dazu
(markierter R3-Teil, Fresnel des Glases, `mirror`). Neu je Instanz: `fill` (zusätzliches Umgebungslicht – das
Spielerauto bekommt 0,7 × `ce_ambient`, so wie Arcade sein Spieler-Sprite aufhellt) und `gloss` (Kasten: 0,35).
**Die Vorgaben der Shader sind neutral** (`env_energy` 0, `paint_base` 1, `flake_strength` 0): Kontaktbogen und
`check_models.gd` messen das Vertexformat allein. Den Renn-Look setzt `layers/vehicles.gd` (`LOOK`) auf die
geteilten Materialien, die Umgebungsfarben aus der Palette (nur bei Änderung). Seit M2INT steht der Look an **einer**
Stelle (A-13): `ModernMaterials.VEHICLE_LOOK` (Rennen), `VEHICLE_PLAYER_FILL` und `STUDIO_LOOK` (Showroom);
Fahrzeug-Ebene, Showroom, Kontaktbogen und `prop_scene` lesen sie dort (`ModernMaterials.apply_look()` legt jede
Klassen-Materialie vor dem Einstellen an). Im Renn-Look sind die Metallic-Flocken aus (`flake_strength` 0): eine
Flockenzelle (1/260 m) ist beim Spielerauto in 9 m 0,3 px breit und flimmerte nur (Kunstkritik KRITIK-2 A4: 83
glitzernde Pixel je Bild beim Gran Turismo); der Showroom behält sie.

### 11.4 Schilder

- **Katalog** (`SignAtlas.stage_signs`): die Ereignisse der `Track` über die ganze Etappe
  (`events_for_segment`) mit Land und Straßenart ihres Segments – genau, was `Track._place_props` dem Schild gibt –
  plus die Schilder, die `Track` beim Erzeugen setzt (Kurve, Kuppe, Richtungstafel). Schlüssel = was das Aussehen
  der Art bestimmt (`key_of`).
- **Geometrie:** ein Trockenlauf von Arcades `SignPainter` bei 4 px/m sammelt die Eckpunkte seiner `GeoBatch`, ohne
  zu zeichnen: Grenzen der Tafeln (über dem Bodenpunkt) und die Pfosten (die Rechtecke bis zum Boden).
- **Atlas:** in `prepare()` zeichnet `SignPainter` alle Schilder einmal in **eine** SubViewport (64 px/m, ohne
  Pfosten); sie wird zurückgelesen, mit Mipmaps eine `ImageTexture`, die SubViewport freigegeben. Headless: ein
  Platzhalter. Während der Fahrt entsteht nichts (`SignAtlas.subviewports_created`, `textures_created`,
  `created_while_driving`).
- **Builder** `signs`: je Stück ein Netz für alle Schilder (Tafel-Quads mit Atlas-UVs, Pfosten als Kästen 5 cm
  hinter der Tafel bis in den Boden), eine Zeichnung. Tafeln in Arcades Höhe über der Straße, mit `scale`;
  Wandschilder ohne Pfosten. `sign.gdshader`: Umriss aus dem Alpha (vormultipliziert, `t.rgb / t.a`), Rückseite
  blankes Blech, Ausblendung F5 (Kamera-z als Uniform, gesetzt in `update()`), Fülllicht im Eigenschatten,
  Rückstrahlung im Scheinwerferkegel (`ce_headlight_*`; solange die niemand setzt, steht nachts die Kamera für die
  Scheinwerfer ein). Start- und Zielbrücke (`side` 0) baut der Builder `gantry`.

### 11.5 Prüfungen

| Prüfung | Inhalt |
|---|---|
| `tests/unit/race3d/test_vehicles.gd` | Grundfläche = Kollisionsquader ± 0,3 m (20 Posen, auch R = 120/136 m, Kuppe), Sattelzug, Konventionen, Spielerterme, Detailstufen, Lampen = Ansicht, Leuchtgrößen = Arcade, Räder, Kasten |
| `tests/unit/race3d/test_fade_law.gd` | Ausblendung = `RoadRenderer._item_alpha` an 80 Stellen (offen, Tunnel) |
| `tests/unit/race3d/test_sign_atlas.gd` | jede Art aus `SignPainter.HALF_WIDTH_M`: Tafel, Höhe, Pfosten; Schlüssel; Katalog einer Etappe; Netz des Builders |
| `tests/race3d/check_vehicles.gd` | `lampen` (Schnappschuss = Ansicht), `kasten`, `leistung` (µs je Auto), `schilder` (Zähler), `lampen_fest` (`add_lamps`), `schatten` (je Voreinstellung eine Etappe: Kontaktschatten unter jedem Auto, Werfer genau mit `shadow_casters ≥ 1`) |
| `tests/race3d/render/check_vehicle_lights.gd` | Blinker bei 300 m ≥ `INDICATOR_MIN_PX`, Rücklicht bei 0,839 × Sichtweite an N1, Bremslicht 50/150/300 m |
| `tests/race3d/render/check_occlusion.gd` | Auto hinter der Kuppe (T2) und hinter dem Sattelzug: 0 Pixel |

Die beiden Render-Prüfungen setzen Autos in eine stehende Szene ohne Verkehr
(`tests/race3d/fixtures/vehicle_probe_renderer.gd`) und halten die Weltuhr an (sonst wandert die Sonne um 1/255).

### 11.6 Messwerte (gemessen auf dieser Maschine: Software-OpenGL bzw. headless)

| Messung | Wert |
|---|---|
| Fahrzeug-Ebene, GDScript je Auto und Bild, 34 Autos (headless, 6 Läufe auf geteilter VM) | Median 31,3 … 36,4 µs, p90 35,2 … 47,9 µs |
| Kontaktschatten (Voreinstellungen deck, low, medium, high) | unter 15 von 15 Autos in Sicht; Werfer an, aus, an, an |
| Blinker bei 300 m, Tag / Nacht | Kern 3 × 2 / 2 × 2 px, Schein bis 4,2 / 5,4 px |
| Rücklicht bei 0,839 × Sichtweite (N1, 338 m Sicht, Auto bei 283 m) | +0,304 Leuchtdichte, +0,494 Rot |
| Auto hinter der Kuppe (346 m), Tag und Nacht; hinter dem Sattelzug, Nacht | 0 von 921.600 Pixeln |
| Schilderatlas Kiel – Hamburg | 17 Zellen, kein Schild ohne Zelle |

### 11.7 Offen

- Busse, Lieferwagen, SUV, Polizei, Sportwagen und drei der fünf Spielerautos haben noch kein Modell: sie fahren als
  Arcades Bild bzw. als Kasten mit Arcades Flächen (Abschnitt 11.8; AS2a/AS2b liefern die Modelle, sie erscheinen
  dann ohne Codeänderung). Der gemalte Kasten bleibt der letzte Ausweg, wenn auch das Blatt fehlt. Gelenkbusse brauchen
  nur `groups`.
- (Erledigt mit der Zusammenführung, Abschnitt 12:) Die Mittagssonne des Renderer-Kerns steht hinter dem Wagen, das
  Heck liegt im Licht; Abblendlicht und Verkehrskegel setzt die Ebene `lights` (`ce_headlight*`), die Schilder
  strahlen damit die echten Scheinwerfer zurück; Lack und Glas haben genau eine Spiegelquelle (12.2).

### 11.8 Ersatzbilder für Fahrzeuge ohne Modell (Bauabschnitt R3E)

Entscheidung der Leitung für Zwischenstand 1: Ein Fahrzeug-Set ohne 3D-Modell zeigt in Modern **Arcades eigenes Bild**
dieses Fahrzeugs – kein Auto ist je schlechter als in Arcade. Das gilt dauerhaft als Sicherheitsnetz: Bekommt ein Set
ein Modell (`ModelDB.has_model`), verschwindet sein Ersatzbild von selbst; im Code steht kein Set-Name. Damit ersetzt
dieser Abschnitt für alle Sets mit einem Arcade-Blatt den „Kasten in Größe und Lack“ aus 11.1 und 11.7; der gemalte
Kasten (`ModelFactory.build_box`) bleibt nur der letzte Ausweg, wenn auch das Blatt fehlt.

| Datei | Aufgabe |
|---|---|
| `scripts/race3d/vehicle_standin.gd` (`VehicleStandIn`) | Zellwahl, Faltung, Licht wie Arcade (rein, getestet); Blatt-Stapel (`SheetBatch`), Kasten aus Arcades Flächen |
| `assets/shaders/modern/vehicle_sprite.gdshader` | Bild auf Viereck, Faltung und Kastenflächen; zwei Durchgänge (deckend / weich) |
| `scripts/race3d/layers/vehicles.gd` | Weichen je Set: Modell, Ersatzbild (`sprite`, `boxtex`) oder gemalter Kasten |

**Was ein Set bekommt.** `prepare()` lädt für jedes Fahrzeug-Set der Etappe ohne Modell sein Blatt über `SpriteDB`
(`SpriteDB.texture`, einmal, hinter dem Ladebild). Sprite-Sets (Verkehr und Polizei: orthografische Zellen mit 17
Gierwinkeln; Spielerautos: perspektivische Zellen mit 21 Winkeln) werden ein Bild, Kasten-Sets (`"render": "box"`:
Busse, Lkw) ein Kasten mit Arcades Flächenbildern. Ein Set, dessen Blatt nicht vorbereitet wurde, wird während der Fahrt
nicht nachgeladen (`SpriteDB.loads` bleibt, Render-Prüfung `laden`), sondern als gemalter Kasten gezeigt – mit einer
Warnung. Kiel – Hamburg: 18 Blätter, geschätzt 69 MB Grafikspeicher (BPTC mit Mipmaps; Arcade lädt dieselben Blätter
und dazu die der Sets mit Modell).

**Zellwahl wie Arcade.** Verkehr und Polizei genau nach `RoadRenderer._vehicle_cell`: Anzeigewinkel aus der
Vertragsformel `VehiclePose.ortho_yaw` (Heck-Tiefe, Seitenversatz, Straßenrichtung als Sehne von Heck zu Front,
eigene Richtung aus der Quergeschwindigkeit), je Auto kritisch gedämpft (`render.vehicle_yaw_smooth_s`), Zellwechsel
mit Hysterese (`render.vehicle_cell_hysteresis`). Die Eingaben stammen aus der 3D-Kamera des Bildes
(`VehicleStandIn.view_inputs`): auf gerader Straße mit der Kamera auf der Achse genau Arcades Werte, und weil Straße
und Sehstrahl sich mit der Kamera gemeinsam drehen, bleibt die Gier gegen den Sehstrahl auch mit dem Blick in die
Kurve. Das Spielerauto nach `_update_player_pose` / `_draw_player` (Kurvenvorschau relativ zur Kamera, Lenken,
Spurwechsel, Untersteuern, Blickwinkel; 21 Winkel), Wanken als Drehung um den Anker wie Arcade. Unit-Test: Bild für
Bild gleich Arcades eigenem Code (über 20.000 Fälle, Spieler 900 Bilder).

**Bild im Raum.** Ein aufrechtes Viereck parallel zum Bild am Anker der Zelle (Verkehr: Heckmitte am Boden; Spieler:
Boden unter der Wagenmitte), Breite `image_width_m` – das Fahrzeug hat seine echte Breite, der Anker steht auf der
Straße. Wo Arcade die Zelle nahe der Kamera in Streifen zerlegt (`_car_warp`: ausdrückliches Heck-Pivot, gedreht ≥ 1°,
Länge / Hecktiefe ≥ `render.vehicle_warp_min_ratio`), wird sie **gefaltet**: die Spalten liegen auf dem Auto selbst –
Heckfläche quer, sichtbare Flanke längs, jeder Streifen in seiner eigenen Tiefe (vier Spalten genügen, die Grafikkarte
interpoliert jede ebene Fläche perspektivisch richtig). Unter der Bodenlinie jeder Spalte zeigt das Bild die Straße
näher zur Kamera (Arcades eingebackenen Schlagschatten): diese Zeilen liegen auf der Straße, genau dort, wo die
Ortho-Kamera sie sah (Umkehrung ihrer Abbildung), statt unter ihr zu verschwinden. Beim flachen Bild rücken die Zeilen
unter der Bodenlinie entlang ihres Sehstrahls auf die Straße (dieselben Pixel); in beiden Fällen liegt, was auf der
Straße liegt, 2 cm über ihr. Das Bild selbst steht in der Tiefe des Autos: Kuppen und Fahrzeuge davor verdecken es wie
ein Modell. Nur das Bild des Spielers wird zum Auge hin gezogen (um den Augpunkt skaliert: dieselben Pixel, geringere
Tiefe), bis seine unterste Zeile über der Straße steht – es reicht weit unter seinen Anker, das Heck ist näher als die
Wagenmitte, und zwischen ihm und der Kamera steht nichts.

**Licht wie Arcade.** Die Blätter tragen eingebackenes Licht: unbeleuchtet (`unshaded`), moduliert wie
`RoadRenderer._modulate` (`VehicleStandIn.ArcadeShade`): Umgebung der Palette bzw. des Tunnels (mit der Anpassung des
Auges, wenn die Kamera im Tunnel ist), Licht der eigenen Scheinwerfer, der Kegel des Verkehrs voraus und der festen
Lampen (Straßenlaternen in Städten, Tankdächer, Überdachungen), Arcades Nebeltönung der Zeile. Das Spielerbild heller
wie in Arcade. Die Lichtebenen des Blatts (Rücklicht, Bremse, Blaulicht A/B) liegen „über“ dem Wagen wie in Arcades
Zeichenfolge. Gerechnet wird in Anzeigewerten wie auf Arcades Leinwand; der Shader gibt das ALBEDO aus, das der
Compatibility-Renderer als genau diesen Wert zeigt (`albedo_for`, wie `billboard.gdshader` – sonst führt er ein
unbeleuchtetes ALBEDO durch sein Polynom sRGB → linear, und dunkle Werte, nachts das ganze Bild, erscheinen bis zu
25 % dunkler). Zwei Durchgänge aus derselben Quelle: deckend mit Alpha-Schnitt 0,8 (der Wagen schreibt Tiefe – Kuppen
und andere Fahrzeuge verdecken ihn, die Lichtpunkte sehen ihn in der Tiefentextur), dazu weich (`CE_SOFT`, als
`next_pass`) die Teile, die der deckende Durchgang auslässt: Schlagschatten (Alpha 0,5–0,75) und Ränder.
(`depth_prepass_alpha` taugt dafür nicht: was so gezeichnet wird, fehlt in der Tiefentextur.)

**Lichtpunkte, Schatten, Ausblendung.** Die Lichtpunkte von R3 (Mindestgrößen F6) an den Ankern, die der Kasten schon
ableitet (`ModelFactory.box_lights`) – bei einem Bild nur, was Arcade über sein Bild zeichnet: Heckleuchten, hintere
Blinker, Blaulicht. Liegt ein Lichtpunkt hinter dem Bild, rückt er entlang des Sehstrahls davor, mit angepasstem
Radiusfaktor (gleiche Größe auf dem Bildschirm). Scheinwerfer und vordere Blinker eines Bildes leuchten nicht (sein
Glas kann durchsichtig sein, es gibt keinen Körper, der sie verdeckt). Schatten (Entscheidung der Leitung, umgesetzt
in RINT-B, Abschnitt 13.5): ein Bild trägt Arcades eingebackenen Schatten und bekommt weder einen Kontaktschatten noch
einen Sonnenschatten – der verborgene Kastenwerfer und der Kontaktschatten legten einen zweiten dunklen Fleck neben
bzw. unter den eingebackenen. Kasten-Sets werfen wie Modelle (ein verborgener Werfer je Einheit, Kontaktschatten).
Ausblendung nach Wegstrecke mit Arcades Gesetz als Dither (F5), Verdeckung über den Tiefenpuffer.

**Kasten-Sets.** Je Teil ein echter Kasten in Modellkoordinaten mit Arcades Flächen (`BoxVehicle`: Heck, links, rechts,
Dach; die Front zeigt das Heckbild), Lampenbilder als zweite und dritte UV (Rücklicht, Bremse). Mehrere Teile sind
Einheiten wie die Gruppen eines Modells: der vordere Teil (Zugmaschine) dreht um die Achse 0,6 m hinter dem
Königszapfen des Teils dahinter, jeder folgende hängt an seinem Zapfen 1,65 m hinter seiner Front, 1,19 m hoch – die
Kupplung von AS1s Sattelzug, denn das Sprite-Manifest kennt keine Drehpunkte. Die Ebene stellt die Einheiten wie bei
Modellen (`_pose_groups`).

**Schnappschuss und Leistung.** `snapshot().vehicles[]`: jedes Ersatzbild meldet `lod` = „box“ (die Ersatzstufe des
Manifests), dazu `standin` („sprite“, „boxtex“ oder „painted“), `cell`, `fold`, `pull`. `perf()`: `standin_cars`,
`standin_sheets`, `standin_sheets_mb`; `standin_state()` für Prüfungen. Ein Bild ist eine Instanz im MultiMesh seines
Blatts (zwei Zeichenaufrufe je Blatt mit Autos, ein Blatt ohne Autos kostet nichts). Gemessen (headless, geteilte VM,
dieselbe Szene abwechselnd in einem Prozess, 34 Autos, davon 14 Ersatzbilder): 38,8–41,0 µs je Auto und Bild mit
Ersatzbildern gegen 32,4–36,5 µs mit gemalten Kästen, je nach Last der Maschine – ein Ersatzbild kostet 4–9 µs mehr
als ein gemalter Kasten. `check_vehicles leistung` (≤ 40 µs) hält damit knapp (38,7–39,7 µs unter Last 10).

| Prüfung | Inhalt |
|---|---|
| `tests/unit/race3d/test_vehicle_standin.gd` | Zelle = `RoadRenderer._vehicle_cell` und Spielerzelle = `_update_player_pose` (Bild für Bild), Eingaben aus der 3D-Kamera, Faltung = `VehiclePose.warp_columns`, Faltregel = `_car_warp`, Modulation = `_modulate` nach `_prepare`/`_project` (Tag, Dämmerung, Nacht, Stadt, Tunnel), welches Set welches Bild bekommt (Fixture-Blätter), Kasten und Einheiten, gezogenes Bild |
| `tests/race3d/render/check_vehicle_standin.gd` | gegen Arcades Bild desselben Augenblicks: Spielerautos (Rechteck und Pixel ≤ 3 px, Helligkeit ± 10 %), Verkehr bei 20/60/150 m, Bus, Nacht (22 Uhr: Karosserie von Spieler und hellem Auto bei 20/60 m, Helligkeit ± 10 %); Verdeckung hinter einer Kuppe (0 Pixel, Tag und Nacht, Lampen an); kein Blatt-Laden während der Fahrt |

Grenzen: Das Bild ist Arcades Bild – sein Licht ist eingebacken und folgt nicht der Sonne von Modern, und es kennt nur
die Ansichten der Zellen (± 24° bzw. ± 20°). Sehr dunkle Werte zeigt der 3D-Pfad trotz `albedo_for` einige Stufen
dunkler als Arcades Leinwand (gemessen am pixelgleichen Spielerbild: 11 → 7, 19 → 16, 28 → 26,5 von 255, ab etwa 56
gleich) – das betrifft jeden 3D-Inhalt, nicht nur Ersatzbilder; die Nachtprüfung misst deshalb an einem hellen Auto.
Arcade (eingefroren) lässt bei Bussen und Lkw selten die Heckfläche weg (Rundung in `BoxVehicle.emit`); das Ersatzbild
in Modern zeigt sie.

## 12. Zusammenführung des Schubs M1 (Bauabschnitt RINT-A)

Die Pakete R1 (Kern), R2 (Gelände, Requisiten, Fernboden), R3 (Fahrzeuge, Schilder), AS1b (Umgebungsmodelle) und
UI1 (Optionen, Showroom, Leistungstest, mit AS1 und AU-B) sind zusammengeführt. Was sie erst zusammen brauchten,
steht hier; die Dokumentation der Pakete gilt sonst unverändert.

### 12.1 Konflikt beim Zusammenführen

`assets/shaders/modern/contact_shadow.gdshader` hatten R2 (Schattenfleck der Requisiten) und R3 (Schattenfleck der
Fahrzeuge) unabhängig angelegt. R2s Datei behält den Namen; R3s Shader heißt jetzt `vehicle_shadow.gdshader`
(Materialklasse `vehicle_shadow`, eigene uid aus dem Import).

### 12.2 Eine Spiegelquelle für Lack und Glas

Gemessen am Spielerauto (Kiel – Hamburg km 2, 12 Uhr und 19:24 Uhr, „Hoch“, ohne Verkehr, Bildausschnitt des Autos):
der `Sky` des Umgebungs-Rigs (D7) und der analytische Himmel von `vpbr`/`glass` (R3, `env_energy` aus der
Fahrzeug-Ebene) spiegelten im Rennen **beide** – das Auto war mittags im Mittel 3 bis 11 Stufen heller als mit
einer Quelle (Mittelwerte des Ausschnitts: beide 86/102/136, nur Sky 75/92/126, nur analytisch 83/96/122).

Entscheidung: **der analytische Himmel ist die Quelle für Fahrzeuge und alles in `vpbr`** (Leitplanken, Laternen,
Windräder). Er trägt Horizontband und Boden, spiegelt in der Dämmerung den roten Himmel (der Sky der Umgebung
gab dort fast nichts), und er gilt in jeder Voreinstellung gleich – den Sky gibt es bei „Effekte: Aus“ nicht.
Umsetzung: solange `env_energy > 0` ist (im Rennen immer), schreiben `vpbr` und `glass` `SPECULAR = 0` und `vpbr`
zusätzlich `METALLIC = 0` mit dem Diffusanteil eines Metalls linear aus `ALBEDO` genommen (die Engine rechnet
Albedo × (1 − Metallic)); das f0 des eigenen `light()` kommt über Varyings. Ohne analytischen Himmel
(`env_energy` 0: Showroom, Kontaktbogen, neutrale Prüfungen) spiegelt die Engine wie bisher – gemessen
pixelgleich zum Stand vor der Änderung. Fahrbahn, Gelände und Requisiten behalten den `Sky` als Quelle (nasse
Fahrbahn). Vergleichsbild: Abgabeordner RINT-A, `spiegelung_eine_quelle.png`.

### 12.3 Gelände und Fernboden im Licht

Wie die Fahrbahn liegen das Geländeband und die Sektoren des Fernbodens auf Render-Ebene 2 (`GROUND_LAYERS`): die
echten Spots und Punktlichter lassen sie aus. Beide Shader binden `inc/pools.gdshaderinc` und
`inc/headlight.gdshaderinc` ein und zeigen Lampen- und Verkehrskegel und das Abblendlicht mit Arcades
Rückstrahlfaktoren (Gras 0,45, Kiesstreifen 0,6, Pflaster 0,8, Wasser 0,45); der Fernboden meldet sein Material wie
das Gelände mit `add_pool_material()` an.

### 12.4 Lampen der Requisiten

`PropLibrary.lamp_pools()` gibt jedem Lichtanker eines Modells Kegel und Stärke:
- Lampen, die nach unten schauen (Laterne, Tankstellendach), bekommen den Kegel von Arcades Laternen (9 m); eine
  Gruppe teilt sich das Licht von Arcades Tankstellenkegel: je Lampe min(0,55; 1,6 / Anzahl) – die acht Lampen
  des Tankstellendachs je 0,2.
- Wandlampen (Bauernhaus, Scheune, Zollhäuschen: Blick zur Seite) bekommen einen kleinen Kegel (5 m, 0,4) auf dem
  Boden vor der Wand – die Ebene `lights` legt ihn höchstens 1,5 m vor die Wand unter die Lampe
  (`pool_centre()`), nicht dorthin, wo die waagrechte Achse den Boden träfe.
- Lampen hoch oben (Flugbefeuerung des Windrads, ab 25 m) bekommen keinen Kegel, nur den Schein der Ebene `flares`.
Fenster leuchten über Lampenkanal 12 (Modelle) bzw. den Nachtlicht-Atlas, ohne Anker.

### 12.5 Rotoren

`vpbr.gdshader` dreht die Rotorteile (Lackcode 0,875, `UV2.y` = Nabenhöhe / 128 m; docs/modelle.md §14) in
`vertex()` um die Z-Achse des Modells durch die Nabe: Winkel = −`ce_time` × `rotor_speed` (1,35 rad/s) + Phase aus der
Lage der Instanz – von der Straße (+Z) aus im Uhrzeigersinn wie echte Anlagen; mit dem Spiel steht auch der Rotor
still (`ce_time` ist Spielzeit). Render-Prüfung `rotor` in `check_props_render.gd` (drei Zeitpunkte: der Rotor
ändert sich, der Turm nicht); Bild: `rotor_drei_bilder.png` im Abgabeordner.

### 12.6 Requisiten: Varianten, Bodendecker, Ende der Sicht

- **Varianten** (`variants` eines Sets): eine je Stück und Set nach stabilem Hash (`chunk_variant()`), nicht mehr je
  Requisite – so kostet ein Set je Stück und Seite höchstens seine Flächen an Zeichenaufrufen (Kartenbaum 2).
- **Bodendecker** (Nachtrag A-3): im Sichtkorridor einer Kurveninnenseite weggelassene Pflanzen werden durch
  `props/cover_bush` und `props/cover_grass` ersetzt (`graphics.modern.props.bend_cover`), höchstens 0,5 m hoch –
  ein Stück je Busch, drei je Baum über seinen Fuß verteilt, nie näher als 0,8 m an der Fahrbahnkante, nicht in den
  City Limits (Grasbüschel auf dem Pflaster eines Stadtzentrums, gesehen an C1). Felsen und
  Häuser einer Landschaftsregel bleiben im Korridor weggelassen (strengere Lesart von R2, bis die Projektleitung mit
  den Bergbildern von Zwischenstand 2 entscheidet). Bilder T2/T4 vorher/nachher im Abgabeordner.
- **Ende der Sicht**: die „hellen Rauten“ am Horizont von S1 waren Fernbilder ferner Bäume jenseits des Nebelendes –
  reine Nebelfarbe vor den dunstigen Silhouetten des Hintergrunds (gemessen: ohne die Fernbild-Knoten verschwinden
  sie, ohne die Kontaktschatten nicht). `billboard.gdshader` und `leaves.gdshader` blenden zwischen 0,85 und 1,0 des
  Nebelendes (`ce_fog_range.y`, die Sichtweite) mit geordnetem Dither aus, wie Arcades Sprites am Ende der Sicht.

### 12.7 Prüfungen nach der Zusammenführung

- `check_light_base` → `schatten` vergleicht jetzt **beleuchtete, unbeschattete Flächen** (D5 meint: gleich hell),
  nicht mehr das Mittel des ganzen Bodens: Bildpunkte, die in einem der beiden Bilder um mehr als 0,04 dunkler sind,
  gelten als Schatten und zählen nicht; mindestens 75 % des Bodens müssen unbeschattet sein (eine Änderung des
  Grundlichts machte den meisten Boden „verschieden“). Gemessen an S1: beleuchtete Flächen −0,09 %, ganzer Boden
  −1,69 % (5,6 % des Bodens im Schatten der Werfer).
- `check_props_render` → `props_spiegel` nimmt Buche und Fels als Vertretungen (Birke und Strohballen haben seit AS1b
  Modelle, Bäume drehen sich zufällig) und `rotor` (12.5).
- `test_props.gd`: Varianten je Stück, Wandlampen, Tankstellendach, Flugbefeuerung, Bodendecker; „höchstens zwei
  Zeichenaufrufe je Set und Stück“ gilt **je Seite** – ein Haus aus AS1b hat zwei Flächen (`baked` + Scheiben in
  `vpbr`), auf beiden Straßenseiten also 2 × 2 Aufrufe (gespiegelter Knoten, D24).
- `check_terrain_plan` ist streng: `TerrainProfile` kürzt die Innenseite einer Kurve auch nach der stärksten Krümmung
  ihrer Seite in der Nähe (drei Zeilen, R2); 0 überlappende Bandspitzen an 40 Kamerapositionen, `modern_sight --full`
  grün.
- `tools/run_tests.sh` startet zusätzlich `check_options_tabs` (Arcade) und `check_attract`, `check_attract_scenes`
  in Modern; die Render-Prüfungen der Pakete findet `tools/run_render_checks.sh` über ihren Dateinamen.
- `check_modern_stage` → `kern_zeit` misst wieder nur den Renderer-Kern (Straße, Randausstattung, Hintergrund,
  Lichter, Overlay – Testdouble `tests/race3d/fixtures/core_renderer.gd`): seit der Zusammenführung aktualisiert
  `render()` auch Gelände, Requisiten, Schilder, Fernboden, Fahrzeuge und Lichtpunkte; mit allem maß die Prüfung
  0,499 bzw. 0,618 ms je Bild (Grenze 0,6 ms für den Kern, zwei Läufe bei Last 6–9), der Kern allein 0,194 bzw. 0,251 ms
  (gemessen, headless). Die Zeit des ganzen Renderers steht in `perf_stats` (`render_ms_avg`).

### 12.8 Moduswechsel und Programmende

- `RaceRenderers.leave_modern()` ist die eine Stelle, die freigibt, was Modern geladen hat (`ModelDB.release_all()`
  + `ModernMaterials.drop_shared()`, A-4): beim Arcade-Renderer nach einem Modern-Renderer und – mit `always` – aus
  den Menüs, wenn „Grafik“ Modern verlässt (GameFlow), und beim Beenden.
- Beim Beenden stoppt `AudioManager` Motor, Schleifen und Einzelgeräusche und wartet 60 ms, damit der Audio-Server
  die gestoppten Wiedergaben verwirft: sonst meldete Godot sie (mit ihren Klängen und dem Generator des Motors) in
  2 von 3 Läufen als „ObjectDB instances leaked at exit“ (gemessen; danach 0 von 6 Läufen in Arcade, 0 von 3 in
  Modern).

### 12.9 Erst zusammen sichtbar: 3D-Auflösung und Lichtpunkte, Aufwärmen je Modell

- **Lichtpunkte bei verkleinerter 3D-Auflösung**: „Niedrig“ (die Voreinstellung für Software-Grafik) zeichnet das
  3D-Bild mit 75 % und zieht es bilinear auf (R1, `quality.gd`). Eine Heckleuchte in 150 m ist dann kleiner als ein
  Bildpunkt und fällt zwischen die Bildpunkte; ihr Lichtpunkt (R3) hatte die volle Stärke nur genau im Mittelpunkt.
  Gemessen (`check_vehicle_lights` → `bremslicht`, Tag): 150 m Rot +0,07 statt +0,57 bei 100 % – unter der Schwelle
  0,08; das widerspricht „keine Qualitätsstufe dunkelt Fahrzeuglichter ab“. `flare.gdshader` hält die volle Stärke
  jetzt bis zu einer halben Bildpunkt-Diagonale des 3D-Bilds und fällt von dort bis zum unveränderten Radius ab (der
  Schein wird nirgends schwächer oder kleiner): „Niedrig“ 150 m +0,16, 300 m +0,33; bei 100 % und „Hoch“ wie vorher
  oder heller (+0,57 / +0,55 in 150 m).
- **Aufwärmen der Requisiten je Modell**: `props.gd warmup_nodes()` gab einen Knoten je Materialklasse (das erste
  Modell der Klasse, als MeshInstance3D). Die Prüfung mit kaltem Cache (`warmup_cold.gd`, Kiel – Hamburg km 2,
  „Mittel“, 12 Uhr) zählte mit allen Inhalten **2 Varianten mitten in der Fahrt** (nach 3–6 s, auch ohne Verkehr und
  ohne HUD; Mesa bekam dabei keinen neuen GLSL-Quelltext – es waren Varianten des Treibers für ein Modell mit anderen
  Texturen oder Vertex-Daten als das erste seiner Klasse). Jetzt steht jede Darstellung jedes geladenen Modells so
  vor der Kamera, wie `commit()` sie zeichnet (MultiMesh mit einer Instanz, Schattenteile als Werfer): **0 Varianten
  während der Fahrt**, 48 statt 17 Aufwärm-Knoten, das Aufwärmen dauerte unter llvmpipe bei Last 7 rund 10 s länger
  (Übersetzungen, die sonst unterwegs gekommen wären).


## 13. Zweite Hälfte der Zusammenführung (Bauabschnitt RINT-B)

R3E (Ersatzbilder, Abschnitt 11.8), AS1R (Nacharbeit der Fahrzeugmodelle) und AU-D1 (Musik) sind zusammengeführt;
danach kamen die Entscheidungen der Leitung für den ersten Testbuild dazu. Zahlen „gemessen“ stammen von der Build-VM
(Software-OpenGL, llvmpipe, unter Xvfb), alles über echte Grafikkarten und das Steam Deck ist abgeleitet.

### 13.1 Der Nachbearbeitungspfad zeigt, was die Durchgänge schreiben

Die fest eingeschaltete Nachbearbeitung (D6) schickt das 3D-Bild – und die Leinwand des Hintergrunds, die als
`BG_CANVAS` darin liegt – ein zweites Mal durch die beiden Näherungen der Engine (sRGB → linear als Polynom, linear →
Anzeige ohne linearen Fuß). Das drückte jeden dunklen Wert: gemessen mit Flächen, die genau einen Anzeigewert schreiben
(Probe `m1/RINT-B/probe/post_probe.gd`):

| geschrieben (von 255) | 2 | 4 | 6 | 8 | 10 | 12 | 16 | 22 | 30 | 44 | ≥ 56 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| ohne Nachbearbeitung | 2 | 4 | 6 | 8 | 10 | 12 | 16 | 22 | 30 | 44 | gleich |
| mit Nachbearbeitung (bisher) | 0 | 0 | 0 | 1 | 4 | 6 | 11 | 18 | 27 | 43 | ±1 |
| mit Nachbearbeitung und LUT (jetzt) | 0 | 0 | 0 | 8 | 10 | 12 | 16 | 22 | 30 | 44 | gleich |

Das war die Ursache der „zu dunklen dunklen Werte“ (R3E: 11 → 7, 19 → 16; Debug-Straße nachts 6/13/27 statt 16/21/32) –
weder das Format noch die Genauigkeit des 3D-Puffers. Abhilfe in `environment_rig.gd`: das Environment trägt eine
**1D-Farbkorrektur-LUT** (`post_lut()`: 256 Texel Halbfloat, Texel j = `post_inverse((j + 0,5) / 256)`, Texel 0 = 0),
die die zweite Runde rückgängig macht. Ab 8/255 kommt jeder Wert genau so heraus, wie er geschrieben wurde; was die
Näherungen auf 0 gedrückt haben (unter etwa 7/255), bleibt schwarz. Eine 8-Bit-LUT lag eine Stufe daneben, eine 3D-LUT
(17³) verfälschte das Bild (gemessen). Das Lichtgesetz des Rigs rechnet seitdem ohne die Nachbearbeitung
(`POST_EXACT`, `post_in` / `post_out` sind die Identität; `post_shown` / `post_inverse` bleiben das Modell des rohen
Engine-Pfads und sind weiter getestet). Gemessen an N1: Nachthimmel jetzt gleich Arcade (51/53/57), vorher −2 %.

### 13.2 Bodengesetz: ebener Boden in Arcades Farbe, auch nachts

Arcade zeigt Boden als Albedo × `palette.ambient` (Anzeigewerte). Die Engine wandelt Umgebungs- und Sonnendurchgang
einzeln in Anzeigewerte und addiert sie; das ist am dunklen Ende nicht linear in der Albedo. Das Lichtgesetz des Rigs
trifft deshalb nur eine Bezugs-Albedo (nachts 0,29); gerechnet für N1 (Schnee, 22 Uhr) zeigte eine Albedo 0,93 (Schnee)
+28 … +66 % gegenüber Arcade, eine Albedo 0,2 −28 … −60 % – gemessen am Bild: Schneeboden +37 … +50 %, Fahrbahn nachts
bei S1 +47 … +59 %. Keine Bezugs-Albedo passt für beide Enden (`m1/RINT-B/tools/nightmodel.py`).

`assets/shaders/modern/inc/ground_law.gdshaderinc`: Fahrbahn (`road.gdshader`), Geländeband (`terrain.gdshader`) und
Fernboden schalten den Umgebungsdurchgang der Engine ab (`render_mode ambient_light_disabled`) und schreiben ihn selbst
als `EMISSION`: `ce_ground_base_lin(albedo)` ist der lineare Wert, mit dem **ebener Boden im Licht genau Albedo ×
`ce_ambient_display`** zeigt – den Anteil, den der Sonnendurchgang der Engine ebenem Boden gibt, zieht sie ab. Im
Schatten fehlt dieser Anteil, ein Hang zur Sonne bekommt mehr: die Tiefe bleibt, der ebene Boden hat Arcades Farbe
bei jeder Albedo und jeder Stunde. Neuer Global `ce_ambient_display` (Arcades Umgebungsfaktor als Anzeigewert, im
Tunnel gemischt; gesetzt vom Rig). Lichtkegel und Abblendlicht kommen wie bisher linear dazu.

| Messung (Bildflächen gegen Arcade, gleiche Simulation, „Hoch“; gemessen) | vorher | nachher |
|---|---|---|
| N1 Schneeboden links / rechts (Leuchtdichte) | +50,0 % / +36,7 % | +1,7 % / −8,5 % |
| S4 22 Uhr Gras rechts | +34,1 % | −16,3 % |
| S1 12 Uhr Asphalt / Gras / Himmel | −6,7 % / −7,6 % / −0,2 % | −6,5 % / −7,6 % / −0,2 % |

### 13.3 Horizont: Land bis an die Silhouetten

Lead-Entscheidung: unter der Horizontzeile muss das Bild wie in Arcade als fernes Land lesbar sein. Vorher lag zwischen
Gelände und Silhouetten ein heller Nebelstreifen (S1: 2–7 Zeilen in reiner Nebelfarbe 197/219/237; an T4 wie eine
Wasserfläche), und die Silhouetten standen 2–3 px tiefer als in Arcade.
- **Silhouetten auf Arcades Zeile** (`layers/backdrop.gd`, `crest_lift`): Arcade stellt die Silhouetten auf die
  höchste Zeile, die die Straße bis zur Sichtweite erreicht, wenn sie über der Horizontzeile liegt (höchstens
  120 Zeilen: `RoadRenderer._draw`, `base_y = max(clip, hy − 120)`). Der Hintergrund rechnet dieselbe Regel aus den
  Segmenthöhen (Höhen je Segment zwischengespeichert); `lift_rows` ist die Anhebung, um die die Leinwand gezeichnet
  wird. Gemessen an S1: Unterkante der Silhouetten in Zeile 320 wie in Arcade (vorher 323).
- **Fernboden in Landfarbe** (`far_ground.gdshader`, unbeleuchtet): ebener Boden nach dem Bodengesetz (Albedo ×
  `ce_ambient_display`), dann **Arcades Nebel für Dinge am Boden** (`RoadRenderer._modulate`: zur aufgehellten
  Nebelfarbe × 1,25, höchstens 0,7 × Nebelanteil) statt des Tiefennebels der Engine – nie mehr Nebel als Arcade (F4).
  Der Rand des Fernbodens steht bis zur Zeile der Silhouetten (`rim_rows` = `lift_rows`; der Shader hebt die
  Oberkante mit der Tiefe entlang der Blickachse, so ist sie auf dem Bild eine gerade Linie): unter den Silhouetten
  zeigt sich die Leinwand nie. Der Rand zeigt das Mittel des fernen Bodens (`ce_ground_field_mean`) – das Muster der
  Felder lief auf der 2,4 km fernen Wand in senkrechte Streifen.
- **Gelände mit demselben Nebel** (`terrain.gdshader` schreibt `FOG`: im Compatibility-Renderer ersetzt `FOG` den
  Tiefennebel der Engine und wird in linearem Licht gemischt, gemessen mit `probe/fog_probe.gd`): Talboden jenseits der
  Sicht zeigt sich als dunstiges Land, nicht mehr als „See“ (T4); Band und Fernboden passen ohne Naht zusammen.
Gemessen an S1: Zeilen 321–330 Land 108–114/148–155/66–69 statt Nebel 197/219/237. Fahrbahn, Fahrzeuge, Schilder und
Requisiten behalten den Tiefennebel bzw. die Ausblendung F5 – nur Boden neben und hinter der Straße nimmt Arcades
Bodennebel.

### 13.4 Fahrzeuge im echten Rig

- **Unbeleuchtete Lampen** der Fahrzeuge (Kanäle 0–11) bei 0,28 ihrer Leuchtfarbe (`lamp_off`; 0,5 wirkte bei Tag
  eingeschaltet, Kunstkritik B1); Lampen der Requisiten (12, 13) bleiben bei 0,5 (`lamp_off_props`).
- **Rücklicht in Kanal 2** (eine Leuchte für Rück- und Bremslicht) bei 0,5 der Leuchte (`tail_level`, vorher 0,35).
  Gemessen (`m1/RINT-B/probe/brake_probe.gd`: schwarze Limousine 18 m voraus, Zunahme der Leuchtdichte der Lampenpixel
  gegen das Bild ohne Auto): um 22 Uhr Bremse 3,9 × Rücklicht (4,73 gegen 1,20), mittags ist das Rücklicht kaum zu
  sehen (0,04), die Bremse deutlich (5,15).
- **Lack**: weiches Knie auf dem hellsten Kanal einer Lackfarbe (über 0,7 mit Steigung 0,45 – der Farbton bleibt, die
  Farbe wird skaliert), 8 % Entsättigung, `paint_base` 1,0 statt pauschal 0,9. Nachts spiegelt der Lack den
  Palettenhimmel nur zu 35 % (`env_night`), das Fülllicht des Spielerautos sinkt auf 30 % (`fill_night`; beide nach
  `ce_night` gemischt). Gemessen gegen die Cycles-Sprites in der Spielkamera (`m1/RINT-B/tools/paintcmp.py`, Lackpixel
  der Heckpartie, Farbton / Helligkeit):

| Spielerauto | 12 Uhr | 19:30 | 22 Uhr |
|---|---|---|---|
| Limousine (S1) | −3,4° / +6,7 % | −9,6° / +3,3 % | −2,7° / +31,8 % (vorher +53,1 %) |
| Kompakt (S1, N1 im Schnee) | −1,3° / −7,8 % (am Anschlag 2 % statt Arcade 29 %) | +5,9° / −16,2 % | +5,0° / −10,5 % |

  Mittags und in der Dämmerung innerhalb von 10 % – außer dem Kompakt um 19:30: die Sonne steht dort voraus, sein Heck
  liegt im eigenen Schatten, Arcades Sprite kennt keinen. Nachts bleibt die Limousine heller als ihr Sprite (der Mond
  legt einen Glanz auf den Kofferraum).
- **Rückstrahler**: neuer Lampenkanal 15 `retro` (Vertrag: „reserviert“): Konturband und Dreiecksrückstrahler des Lkw
  leuchten im Kegel des eigenen Abblendlichts (dasselbe Gesetz wie `inc/headlight.gdshaderinc`, `retro_energy` 2,0),
  nicht mehr mit der Nacht überall; der Lkw ist neu exportiert und gebacken. Die Schilder strahlen schon die echten
  Scheinwerfer zurück (11.4, `sign.gdshader`).
- **Überblendung der fernen Stufen**: lod1 und lod2 eines Modells (je ein zusammengeführtes Netz) wechseln nicht mehr in
  einem Bild, sondern blenden über `XFADE_S` = 0,5 s Sichtzeit mit gegenläufigem Dither ineinander (vpbr-Instanzwert
  `xfade`, Index 9: > 0 die neue Stufe behält die Pixel unter dem Ditherwert, < 0 die alte die übrigen – zusammen genau
  die Fläche einer Stufe); die alte Stufe folgt Ausblendung, Sonnenmaske und Lampen der neuen, ihre Schattenhülle ist
  aus. Kosten: ein Zeichenaufruf mehr je Auto, solange es blendet. Gemessen (`m1/RINT-B/probe/pop_probe.gd`: ruhige
  Szene ohne Verkehr, Auto fährt mit 3 cm je Bild durch die Grenze, Anteil der Autopixel, die sich gegen das Bild davor
  ändern): vorher 5,4 % in einem Bild beim Wechsel, jetzt 0 % im Wechselbild und höchstens 3,5 % je Bild verteilt.
- Diese Werte setzt `layers/vehicles.gd` (`LOOK` = `ModernMaterials.VEHICLE_LOOK`, A-13) auf die geteilten
  Materialien; die Vorgaben der Shader bleiben neutral (Kontaktbogen, `check_models`). Der Showroom setzt seinen
  eigenen Look (`Showroom3D.studio_look()` mit `ModernMaterials.STUDIO_LOOK`), sonst
  übernahm er die Parameter des letzten Rennens (den analytischen Himmel der Rennpalette, nachts einen dunklen); der
  Kontaktbogen mit `--showroom` nimmt denselben Look.

### 13.5 Laternen und Ersatzbilder

- **Laternenschein**: jede Lampe, die auf einen Lichtkegel nach unten schaut (Laternen, Tankstellendach), bekommt in der
  Ebene `flares` zusätzlich Arcades warmen Schein (`RoadRenderer._streetlight`: Radius 2,4 m, mindestens 3 px, Farbe
  (1; 0,75; 0,4), Stärke 0,5 × Lichter – im Lichtpunkt-Shader Stärke 1,0, weil er Farbe × 0,5 × Stärke addiert),
  nach ihrer Energie gegen die einer Laterne skaliert. Vorher trug nur ein kleiner Halo (35 % in der Nähe) die Lampe.
- **Ersatzbilder ohne eigenen Schatten** (Entscheidung der Leitung): ein Sprite-Ersatzbild trägt Arcades eingebackenen
  Schatten; der verborgene Kastenwerfer und der Kontaktschatten kommen weg (sie legten einen zweiten dunklen Fleck
  neben bzw. unter den eingebackenen). Kasten-Ersatzbilder (Busse, Lkw) werfen wie Modelle. Geprüft in
  `check_vehicles` → `schatten`.

### 13.6 Zeitbudgets auf einer geteilten Maschine

Wanduhr-Zeiten dieser VM sind unter Last zweigeteilt (dieselbe Fahrzeug-Ebene 36 oder 49 µs je Auto). Die
CPU-Zeit des Threads hilft nicht (`/proc/thread-self/schedstat` bewegt sich nur zu Scheduler-Ticks: 0 µs für 2 ms
Arbeit, gemessen). `tests/race3d/fixtures/perf_clock.gd` misst deshalb **gegen eine Referenz im selben Prozess**: ein
festes Stück GDScript (Vektorrechnung, Arrays, Wörterbücher – was die Ebenen tun), neben jeder Probe gemessen; das
Ergebnis wird auf das Tempo umgerechnet, mit dem diese VM die Referenz normal läuft (`REF_NOMINAL_US` = 600 µs; Mediane
592 und 610 µs normal, 921 µs im langsamen Zustand – die Referenz zeigt dieselbe Zweiteilung). Ein Budget bedeutet
damit, was Bauplan §4.10 sagt: „µs auf dieser VM bei normalem Tempo“.

| Budget (GDScript je Bild, headless, normales Tempo der VM) | Grenze | gemessen | Prüfung |
|---|---|---|---|
| Fahrzeug-Ebene je Auto (34 Autos) | 40 µs | 32,6–34,6 µs (p90 42–47) | `check_vehicles` → `leistung` |
| Renderer-Kern (Straße, Randausstattung, Hintergrund, Lichter, Overlay) | 0,6 ms | 0,23 ms | `check_modern_stage` → `kern_zeit` |
| **ganzer Renderer** (alle Builder und Ebenen, Verkehr der Sitzung) | **1,5 ms** | 0,80 ms (13 Autos) | `check_modern_stage` → `renderer_zeit` (neu) |
| Einhängen eines Stücks | 3 ms | 0,42–0,78 ms | `kern_zeit`, `renderer_zeit` |

### 13.7 Beenden ohne Lecks

`GameFlow.quit_game()` stellt zuerst den Klang ab (Musikkontext „off“, Musik aus, `stop_all()` – beide Profile), wartet
0,3 s (Zeitgeber, der auch pausiert und unabhängig vom Zeitraffer läuft) und ruft dann `quit()`: der Audio-Server gibt
gestoppte Wiedergaben erst in einem späteren Mischschritt frei, ein sofortiges `quit()` meldete sie als „ObjectDB
instances leaked at exit“ (AU-D1). Render-Prüfung `check_quit_sound.gd`: je Klangprofil drei Spielstarts in eigenen
Prozessen, Beenden über `quit_game()`, keine Zeile mit „leaked“, „still in use“ oder einem Fehler.

### 13.8 Instanzbudget: Godots globaler Shader-Puffer

Der Compatibility-Renderer legt die Instanz-Uniforms (`instance uniform` in `vpbr`, `glass`, `vehicle_sprite`) im
globalen Shader-Puffer ab, **16 Plätze je Instanz**, ob sie sichtbar ist oder nicht. Der Puffer ist so groß wie der
Uniform-Block der GPU: 64 KB = 4096 Plätze mit llvmpipe und den meisten Desktop-Treibern (die Projekteinstellung
`rendering/limits/global_shader_variables/buffer_size` kann ihn nicht darüber heben) – nach den globalen Uniforms etwa
**250 Instanzen in der ganzen Szene**. Darüber lehnt Godot ab („Too many instances using shader instance variables“)
und zeichnet die Instanz mit den Werten einer anderen (Lack, Lampen, Ausblendung).

Die Pools der Fahrzeug-Ebene (6 freie Autos je Set) behielten ihre gebauten Stufen – lod0 allein sind 6 Instanzen
(Karosserie, vier Räder, Schattenhülle). Gemessen (Kiel–Hamburg km 2, Spieler steht, Verkehr zieht vorbei): die
Instanzen der gebauten Stufen wuchsen ohne Ende (30 → 159 in 720 Bildern bei doppelter Zeit, ganze Szene 227); in
900 Bildern ohne Budget 15 bzw. 17 Ablehnungen (Stand b473e90 bzw. vor der Abhilfe). Der Rest der Szene (Requisiten in
`vpbr`, Bögen der Ersatzbilder) belegte dabei 34–72 Instanzen, das Aufwärmen hinter dem Ladebild bis 135.

Abhilfe in `layers/vehicles.gd`: **`INSTANCE_BUDGET` = 128** für die Instanzen aller gebauten Stufen (aktive und
gepoolte Autos, `perf()`: `vehicle_instances`, `vehicle_instances_peak`, `vehicle_trims`). Darüber gibt die Ebene am
Ende von `update()` zuerst gepoolte Autos frei (aus dem vollsten Pool), dann Stufen aktiver Autos, die weder gezeigt
werden noch ausblenden; eine freigegebene Stufe wird beim nächsten Bedarf neu gebaut. Gemessen mit Budget: ganze
Szene höchstens 196–229 Instanzen, keine Ablehnung.
Prüfungen: `check_vehicles` → `instanzen` (headless, 180 s Verkehr bei vierfacher Zeit: höchstens 128, Zähler =
Knoten, das Budget gibt frei), Render-Prüfung `check_instance_budget.gd` (100 s Verkehr bei sechsfacher Zeit, ein
`Logger` fängt jede Ablehnung der Engine; ganze Szene unter 230), und `tools/run_render_checks.sh` lässt jede
Render-Prüfung scheitern, deren Ausgabe eine Ablehnung enthält.

**Statische Modelle ohne Instanz-Uniforms (M2INT).** Mit den Bäumen von AS3R (jeder Baum hat einen Stamm in `vpbr`)
und den Gebäuden von AS4R trug jeder MultiMesh-Knoten eines Stücks mit einer `vpbr`-Fläche 16 Plätze – auf
Waldetappen in „Hoch“ lief die Szene über den Puffer: in den A/B-Bildern T1 (5 Ablehnungen) und T4 (2), im Clip
Dortmund – Frankfurt km 121 (55), gemessen. Requisiten setzen ihre Instanz-Uniforms nie (Lack, Lampen, Ausblendung,
`sun`, `fill`, `gloss`, Überblendung bleiben auf ihren Vorgaben). Darum zeichnen alle Modelle, die keine Fahrzeuge sind
(Manifest-`kind` weder `vehicle` noch `heavy`: Bäume, Büsche, Gebäude, Straßenmöbel, Felsen, Wahrzeichen), ihre
`vpbr`-Flächen mit **`ModernMaterials.VPBR_STATIC`**: derselbe Shader, die Instanz-Uniforms als gewöhnliche Uniforms
mit denselben Vorgaben (`static_code()` ersetzt die Deklarationen), Material unter dem Schlüssel `vpbr|static` – die
Klassenparameter von `vpbr` (Look, Lampenenergien, `coat_sun`, Himmel) erreichen es wie zuvor, beim Anlegen übernimmt
es die schon gesetzten. Das Bild bleibt gleich; im Puffer stehen nur noch Fahrzeuge (Budget 128) und die eigenen
Knoten von Leitplanken, Tankstelle, Tunnel und Toren. Prüfungen: `test_props` „static_vpbr“ und die Render-Prüfung
`check_instance_budget_wald.gd` (Kassel – Würzburg ab km 46,5, „Hoch“, Autopilot 120 km/h).

### 13.9 Speicher, Ladezeit, Showroom

- **Texturspeicher** (A-6: Modern höchstens Arcade + 60 MB), Kiel–Hamburg km 2, 15 s Fahrt mit Verkehr, Monitor der
  Engine (`m1/RINT-B/probe/texmem_probe.gd`, gemessen): Arcade 221,1 MB, Modern 166,8 MB – davon 51,5 MB für 17 Bögen
  der Ersatzbilder. Die Bögen werden nur in `prepare()` geladen und nur für Sets ohne Modell; Modern liegt 54 MB unter
  Arcade, eine weitere Einschränkung der Bögen ist nicht nötig.
- **Ladezeit** Kiel–Hamburg ab km 0 (Szene eingehängt bis `RaceSession.is_live()`, wie `prepare_s` des
  Leistungstests; `m1/RINT-B/probe/loadtime_probe.gd`, gemessen auf der Build-VM): Modern 5,2–5,6 s, Arcade 0,85 s.
  Die ganze Zeit steht das Ladebild; sein Balken (`prepare_progress()`) läuft 0,05 → 0,1 (Selbsttest) → 0,65 (Stücke)
  → 0,83 … 1,0 (Aufwärmen, 8 Schritte). Er lief vorher einmal rückwärts (0,1 → 0,05 nach dem Selbsttest) und stand
  während des Ladens der Startansicht bei 0,05; jetzt bleibt ein fertiger Selbsttest bei seinem Schritt, und vor dem
  Laden der Startansicht wird einmal mit dem Balken bei 0,65 gezeichnet. Das Laden der Startansicht selbst ist ein
  Bild von 1,6–1,9 s (alle Stücke auf einmal, `ChunkStreamer.update` beim ersten Aufruf) – offen: über mehrere Bilder
  verteilen.
- **Showroom** (`tools/models_contact_sheet.sh <png> --only="player/*" --showroom`, dieselbe Kamera wie die
  Cycles-Sprites, mit dem Look des Showrooms): Kompakt und Limousine in Echtzeit sind heller und gesättigter, aber
  flacher als ihre Sprites (weniger Form im Schatten, Kunststoffglanz, helle Scheiben). Das Echtzeitbild ist nicht
  mindestens so gut wie das Sprite – `showroom` bleibt für beide `false` (das Manifest bleibt unverändert).


## 14. Nacharbeit nach der Prüfung des Schubs M1 (Bauabschnitt FIX1)

Die unabhängige Prüfung von M1 (QA-BILD, QA-SYSTEM am Kopf 9b6adbc) fand an den markanten Stellen von Kiel – Hamburg
und in anderen Etappen Lücken, die Modern schlechter als Arcade aussehen ließen. FIX1 schließt die meisten davon mit
**Mindestbauten in Arcades Formen und Farben** – die echten Bauten bleiben Sache der Bauabschnitte von M2 (R4 Wetter,
R5 Tunnel und Brücken, R6 Tankstelle/Grenze/Stadt/Tore, R7 Wahrzeichen). Die neuen Builder tragen die Dateinamen der
Registry (`builders/tunnel.gd`, `station.gd`, `gantry.gd`); R5/R6 übernehmen und ersetzen sie. Zahlen „gemessen“ stammen
von der Build-VM (llvmpipe unter Xvfb, Voreinstellung Mittel); alles über echte Grafikkarten ist abgeleitet.

### 14.1 Arcades Nebel für alles in der Landschaft (`inc/fog_law.gdshaderinc`)

Arcade tönt jedes Sprite mit `RoadRenderer._modulate`: zur eigenen Farbe mal aufgehellter Nebelfarbe (× 1,25) um
0,7 × den Nebelanteil der Entfernung – ein dunkles Auto bleibt dunkel – und blendet es mit seiner Alpha-Ausblendung aus
(in Modern: F5 als Dither). Gelände und Fernboden haben dieses Gesetz seit RINT-B; jetzt auch `baked`, `leaves`,
`billboard`, `vpbr`, `glass` und `sign` (`FOG = ce_arcade_fog(albedo, Entfernung, ce_fog_color, ce_fog_range)` ersetzt den
Tiefennebel der Engine), der Kontaktschatten der Requisiten blendet nach demselben Gesetz aus. Wirkung (gemessen, S1
nach 6 s): ferne Bäume dunkelgrün wie in Arcade statt graublauer „Geisterbäume“, das Bauernhaus in seinen Farben. Eine
schwarze Limousine bei 0,839 × Sicht behält 16 % Kontrast ihrer Pixel gegen 22 % am Nebelbeginn (Render-Prüfung
`sichtgrenze`); mit dem Tiefennebel der Engine wären es etwa 30 % davon gewesen (abgeleitet aus dem Gesetz).

### 14.2 Kein Mondglanz auf dem Lack

`light()` von `vpbr` und `glass` behandelt das gerichtete Licht als Punkt. Bei Tag darf der Sonnenglanz sättigen; nachts ist
das Licht der Mond, eine matte Scheibe im Himmel, und Grund- und Klarlackkeule legten zwei weiße Flecken auf Dach und
Kofferraum. Die Keulen des gerichteten Lichts (Grundkeule, Klarlack, Flocken) behalten nachts 8 % (`coat_sun` / `sun_spec`,
gesetzt von der Fahrzeug-Ebene, wenn `palette.night` > 0,5 – dieselbe Regel, nach der das Rig den Mond nimmt). Wichtig:
`SPECULAR_AMOUNT` in `light()` ist die Spiegelstärke des **Lichts**, nicht das `SPECULAR` des Materials – die Grundkeule
war trotz `SPECULAR = 0` im Rennen aktiv. Gemessen DEV 21 Uhr, Wagenausschnitt: p95-Leuchtdichte 193 → 69 (Arcade 51).

### 14.3 Tunnel (`builders/tunnel.gd`, `assets/shaders/modern/tunnel.gdshader`)

Vorher lag in Tunneln offenes Gelände (der Fernboden) unter einem schwarzen Himmel. Jetzt:
- **Röhre** je Tunnelsegment ab der äußeren Bankettkante: Fliesenband bis 2,9 m (jedes zweite Segmentpaar 6 % dunkler),
  Wand bis `render.tunnel.wall_height_m`, Vouten um `haunch_m` nach innen bis `ceiling_m`, Decke; Lampenbänder auf beiden
  Vouten alle `light_every_m` (die Ebene `flares` legt Arcades Lichthof dazu: 1,6 m, Stärke 0,45), grünes Notrufschild alle
  150 m rechts.
- **Shader**: unbeleuchtet mit Arcades Tunnellicht (`Palette.tunnel().ambient`; von außen gesehen × (0,5 + 0,5 × Lichter)
  wie Arcades an Tageslicht gewöhnte Augen) und Tunnelnebel (`pow((d − 12) / darkness_m, 0,8)` zu `Palette.TUNNEL_FOG`) –
  die Röhre sieht von außen und innen gleich aus, was immer die Umgebung tut. Ecken des Vertex-Formats: `UV` = (Tiefe ab
  dem Portal, z des Portals), `UV2.x` = Art (0 Fläche, 1 Kappe, 2 Lampe, 3 Notrufschild).
- **Von außen** nur die ersten `peek_m` (45 m), dort schließt eine dunkle Kappe die Röhre (Arcade: `_tunnel_cap`); der
  Shader entscheidet nach dem Portal-z jeder Ecke gegen `cam_tunnel_z` (gesetzt in `update()`).
- **Portal**: Stirnwand aus Beton über der Öffnung, Flügelmauern, Gesims, dunkler Rahmen; darüber Arcades bewachsener
  Hügel (85 m + halbe Straßenbreite je Seite, 30 m ± gesäte Abweichung hoch, Grat bis 38 m hinter dem Portal, dahinter
  abfallend; bei kurzen Tunneln niedriger und vor der Ausfahrt zu Ende) in der abgedunkelten Grasfarbe der Landschaft, in
  `vpbr`, beleuchtet.
- **Hintergrund**: mit Röhre bleibt die Leinwand im Tunnel dunkel, bis die Ausfahrt in Sicht ist (Arcades
  `_tunnel_exit_visible`) – das Ende der geladenen Röhre zeigt nie den Himmel.
Bilder: U1 (Gotthard), DEV (Testtunnel 21 Uhr: Hügel und Portal wie Arcade), Elbtunnel (Hamburg – Hannover km 3,3, von
außen und innen) im Abgabeordner FIX1. Offen für R5: Nischen mit Türen, Gehwege, Portalrahmen, Belichtungsrampe an der
Ausfahrt (draußen wirkt die Welt durch die Ausfahrt noch nicht überstrahlt wie in Arcade), Straße und Tiefe der Röhre bei
starken Kurven von außen.

### 14.4 Tankstelle (`builders/station.gd`)

Nach den Flags `TrackSegment.fuel_zone` wie `RoadRenderer._fuel_structures`: **Insel** 0,18 m hoch von 0,35 bis 2,3 m
hinter der befestigten Kante mit gelbem Bordstein zur Tankspur; **Dach** über Insel und halber Tankspur (Unterseite
5,6 m, 0,5 m innerhalb der Kante bis 4,6 m dahinter) mit rotem und weißem Band, Stirnblende mit „TANKSTELLE“ (`Label3D` in
Arcades Schildschrift: Ersatzschrift der Engine, fett), Stützen auf der Insel, zwei Lampen je zweitem Segment
(Lampenkanal 12, Lichtkegel und Schein über `add_lamps`, Rolle `canopy`). Die Zapfsäulen (Requisiten) stehen damit auf
der Insel. Bild S2: gleichwertig zu Arcade.

### 14.5 Start- und Zieltor (`builders/gantry.gd`)

Aus den Schild-Ereignissen mit Seite 0 (`start` 14 m nach der Startlinie, `finish` am Ziel), wie `SignPainter._gantry`:
zwei Pfosten 0,45 m außerhalb der Bankette, 7 m hoch; Banner von 5,4 bis 7 m – Ziel rot mit Schachbrettstreifen und dem
Text des Ereignisses („ZIEL“), Start dunkel mit hellem Streifen, „START“ und drei Countdown-Lampen (rot, eine mehr je
Sekunde, alle grün beim Start; Schein über die Ebene `flares`, Farbe und Stärke je Bild aus `view.countdown`).

### 14.6 Wahrzeichen bis Arcades Reichweite

Arcade zeigt Wahrzeichen bis Sichtweite × `render.landmark_range_factor` (2), höchstens `landmark_far_m` (1.900 m), mit
eigenem Dunst (`RoadRenderer.landmark_fade`). In Modern standen sie nur in geladenen Stücken und wurden wie Requisiten am
Ende der Sicht ausgedithert – Elbphilharmonie und Michel fehlten an S4. Jetzt:
- `billboard.gdshader` und `baked.gdshader` kennen `landmark_law`: Ausblendung über die letzten 28 % von L, Dunst zur
  Nebelfarbe × 1,15 mit 0,85 × Anteil ab dem Nebelbeginn; `props.gd` setzt es auf eigene Kopien der Materialien seiner
  Wahrzeichen (Ersatzbild oder Modell mit einer Fläche – der Michel ist ein Modell).
- Jenseits der eingehängten Stücke stellt `props.gd` (`update()`, alle 2 m Fahrt, `rebased()`) jedes Wahrzeichen bis L als
  einzelnes Ersatzbild bzw. Modell an den Pfad – genau wie `_place()` es im Stück setzt; das Stück übernimmt nahtlos.
Gemessen an S4 nach 6 s: Elbphilharmonie (1.018 m) und Michel (1.178 m) stehen am Horizont an Arcades Stelle (Michel
etwa 15 px versetzt, Blick in die Kurve).

**Nachts (M2INT).** Arcade zeichnet die Beleuchtung eines Wahrzeichens (Lichtebene des Sprites) bei Nacht bis
`landmark_far_m`, auch wenn das Bild selbst mit der kurzen Nachtsicht längst ausgeblendet ist (`_draw_far_landmarks`:
Grenze = max(L, `landmark_far_m`) bei `lights` > 0,05; `_draw_landmark`: Lichtebene ohne Dunst, Alpha `lights` ×
Ausblendung über die letzten 20 % von `landmark_far_m`). In Modern fehlte die beleuchtete Elbphilharmonie über der
Köhlbrandbrücke um 22 Uhr ganz. Jetzt:
- `props.far_reach(view)`: Wahrzeichen jenseits der Stücke stehen nachts bis `landmark_far_m` am Pfad (sonst bis L).
- `billboard.gdshader`: wo das Bild jenseits von L weggedithert wird, bleiben die Pixel der Lichtebene – geditherte
  Deckung = Alpha der Lichtebene × `ce_night` × Ausblendung, Farbe der Lichtebene, kein Nebel. `baked.gdshader` (Michel)
  ebenso mit dem Emissionsatlas (Deckung = 3 × hellster Kanal). Innerhalb von L dunstet nur das Bild, leuchtende Pixel
  behalten ihr Licht (Dunst × (1 − Deckung)), wie Arcade die Lichtebene ungedunstet darüberlegt.
- Prüfung `check_minimal_structures.gd` „wahrzeichen“: 22 Uhr, km 77,4: Reichweite 1.900 m statt 990 m der Sicht,
  2 Wahrzeichen jenseits der Stücke (gemessen). Bild `koehl_nacht` im Bericht M2INT.

### 14.7 Brücken: Geländer und Wasser

- `builders/roadside.gd` setzt auf jedem Wassersegment Arcades Geländer an die Deckkante (Bankettkante + 0,4 m außerhalb
  der City Limits) in der Farbe der Brücke: Stahlgeländer mit Betonsockel und Pfosten je zweitem Segment, Brüstung für
  `stone_arch`, Mauer für `causeway`, Eisengeländer für `canal`.
- `builders/terrain.gd`/`terrain.gdshader`: Wasser in Arcades Farbe der Brücke (`water` der Brücke, sonst der Landschaft,
  sonst `CityData.WATER_COLOR`) und zum Horizont hin den Himmel spiegelnd wie Arcades `water_tint` (16 % nah, bis 70 %
  in 324 m; die Nebelfarbe vertritt `sky_bottom`).
Offen für R5: Deck, Träger, Pylone, Uferwände.

### 14.8 Zeit je Teil von `render()`

`perf_stats()` meldet `hooks_ms_avg` und `hooks_ms_max` je Teil (Umgebung, Streamer, Kamera, jeder Builder und jede Ebene
mit `update()`); der Leistungstest schreibt je Szene `script_ms_max` und `hooks_ms_max` – eine Spitze auf dem Steam Deck
lässt sich so einer Ebene zuordnen. Gemessen headless an Kiel – Hamburg km 2 mit allen neuen Buildern: ganzer Renderer
0,81 ms je Bild bei normalem Tempo (`renderer_zeit`, Budget 1,5 ms), Kern 0,27 ms (`kern_zeit`, 0,6 ms).

### 14.9 Prüfungen

| Prüfung | Inhalt |
|---|---|
| `tests/race3d/check_minimal_structures.gd` (Haken) | `tunnel` (jedes Tunnelsegment der geladenen Stücke mit Röhre, ein Portal mit Hügel, eine Kappe, Lampen, Röhre weiß Kamera draußen/innen, Leinwand dunkel bis zur Ausfahrt), `station` (Insel und Dach genau auf den Flag-Segmenten, Stirnblende mit Schriftzug, Lampen), `tore` (Start- und Zieltor mit Schrift), `wahrzeichen` (jenseits der Stücke bis zur Reichweite, keines doppelt), `bruecke` (Geländer auf jedem Wassersegment) |
| `tests/race3d/render/check_vehicle_lights.gd` → `sichtgrenze` | Pflichtprüfung §4.9.2 „Objekt an der Sichtgrenze < 3 % Kontrast“ und Arcades Tönung bei 0,839 × Sicht |
| `tests/unit/core/test_gfx_settings.gd` → `test_crash_guard_strikes` | Absturz-Wächter: erst der zweite Fehlstart in Folge speichert Arcade (docs/grafik-modi.md) |
| `tests/race3d/check_facade.gd`, `tests/race/check_attract.gd`, `tools/run_tests.sh` | lastfest: Projektionsgesetz statt fester Horizontzeile, Demo-Dauer ab dem Start der Etappe, Haken läuft auch nach einem Fehler davor, Liste der Fehlschläge am Ende |

### 14.10 Bekannte Lücken im Testbuild (für die Testhinweise)

- **Kein Wetter in der Luft** (R4, M2): kein Regen, kein Schneefall, keine Gischt; nasse Fahrbahn und Schneeränder gibt es.
- Tunnel und Brücken nur als Mindestbauten (14.3, 14.7); keine Grenzstationen (Dach, Kabinen) – Arcade zeigt sie.
- Keine Sonnenscheibe am Tag; kein überstrahltes Draußen an der Tunnelausfahrt.
- Spielerautos: Limousine mit steiler Heckscheibe statt Arcades Fließheck, Kompakt mit schwarzem Dach (Modellnacharbeit).
- Kurveninnenseiten in Bergetappen kahler als Arcade (Sichtkorridor F7: Bäume werden durch Bodendecker ersetzt –
  Entscheidung der Leitung nach A-3).
- Die Leistung auf echter Hardware ist nur über den Leistungstest messbar.
