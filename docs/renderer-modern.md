# Modus „Modern“ – Renderer: Weltmodell, Kamera, Fairness

Technische Dokumentation des Geometrie-Kerns des echten 3D-Renderers (v0.8.0). Eigentum: `scripts/race3d/{road_path,
chase_camera, terrain_profile, chunk_context, chunk_builder, chunk_streamer, builder_registry}.gd`,
`scripts/race3d/builders/debug_road.gd`, `tests/unit/race3d/*`, `tests/race3d/{fairness, synthetic_track}.gd`,
`tests/sim/modern_*.gd`. Der Bauplan steht in [dev/v080_contract.md](dev/v080_contract.md) (§3.2, §3.3, §4.5); hier steht,
wie der Kern funktioniert, was gemessen wurde und woran man dreht. Den Aufbau des Renderers selbst – die Fassade,
über die Ebenen und Builder eingehängt werden, ihre Haken, die eingebaute Umgebung und das Bildwerkzeug – beschreibt
[Abschnitt 9](#9-aufbau-fassade-ebenen-haken); Straße, Umgebung, Gelände und Fahrzeuge ergänzen die
Renderer-Bauabschnitte dort.

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
`ModernRenderer.world_to_screen()` um höchstens 0,0005 px ab (1280 × 720 und 1280 × 800, Render-Prüfung `modern_bild`).

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
| Straße mit Geländeringen in Eckpunktfarben | `builders/debug_road.gd` | `builders/road.gd` fehlt (mit einem Builder `terrain` zeichnet sie nur noch die Straße) |
| Umgebung: ein Schattenlicht, Umgebungslicht, Tiefennebel, `ce_*`-Globals | `plain_environment.gd` | `environment_rig.gd` fehlt |
| Himmelsverlauf der Palette auf Canvas-Ebene −10 | `plain_sky.gd` | `layers/backdrop.gd` fehlt |

Keine Fahrzeuge, keine Requisiten, keine Markierungen – das Bild des Gerüsts ist ein Arbeitsstand, kein Vergleich
mit Arcade (A/B-Bild im Abgabeordner des Bauabschnitts).

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
behalten ihre Vorgaben, bis Rig und Lichter-Ebene sie setzen.

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
| gerechnet für Albedo 0,3 … 0,9 bei Tag (Unit-Test) | höchstens 7,5 % neben Arcade, bei Regen und Schnee 11 % | – |

Dunklere Albedos fallen dunkler aus, nachts helle bis zu einem Viertel heller – die Anzeigekurve des Renderers ist
bei dunklen Werten kein reiner Faktor. Nachts gibt die eingebaute Umgebung kein Mondlicht (zwei dunkle Durchgänge
fielen beide unter die Anzeigeschwelle); das entscheidet das Rig.

`plain_sky.gd` zeichnet Arcades Himmelsverlauf (dieselben Zeilen wie `RaceBackdrop.draw_sky`) über der
Horizontzeile und die Nebelfarbe darunter, bei jeder Fenstergröße auf `render.horizon_y_frac` der Höhe; im Tunnel
die Tunnelfarbe, mit `--gfx-debug=cover` Magenta (dann ist auch der Nebel aus). Sonne, Wolken und Silhouetten
bringt erst `layers/backdrop.gd`.

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
Bildpaar mit dem Gerüst (Arcade 5–6 s, Modern 6–13 s).

### 9.9 Prüfungen

| Prüfung | Inhalt |
|---|---|
| `tests/race3d/check_facade.gd` (headless, in `tools/run_tests.sh`) | `haken` (Reihenfolge aller Haken, nichts vor dem Ende jedes `prepare_pending()`, `dt` = 0 bis zum Start), `fassade`, `lampen`, `rebased`, `statistik`, `ausfall`, `umgebung`, `geruest` |
| `tests/race3d/check_seam.gd` → `vertrag` | der ausgelieferte Renderer hat jede Methode, jedes Signal und jedes Mitglied aus Bauplan §4.4.1 und A-7; vor `prepare()` antwortet alles harmlos |
| `tests/race3d/render/check_seam_render.gd` → `modern_bild`, `fenster_16_10` | Bild des Gerüsts (Himmelsverlauf, Debug-Straße an den Bildpunkten des Kameramodells, Kamera = `ChaseCamera3D`), danach der ausgelieferte Renderer mit allem, was es gibt |
| `tests/race3d/render/check_facade_render.gd` | `licht` (9.6), `pools` (9.7), `aufwaermen` (Aufwärm-Knoten zwei gezeichnete Bilder vor der Kamera, vom Ladebild verdeckt, danach frei; Selbsttest einmal je Prozess); mit `-- --save=<Ordner>` bleiben die beurteilten Bilder |
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
| `render()` in GDScript, headless, 30 s Fahrt in Echtzeit-Schritten (Kiel – Hamburg ab km 2 und ab km 60) | im Mittel 0,15–0,16 ms, höchstens 2,1–2,8 ms; Sync-Modus im Mittel 0,19 ms, höchstens 5,8 ms |
| Einhängen eines Stücks / Einsammeln / Bauen (Arbeiter-Thread) | höchstens 0,18 ms / 2,0 ms / im Mittel 3,4–4,0 ms |
| Vorbereitung headless (13 Stücke) | 74–77 ms |
| Vorbereitung unter Xvfb (llvmpipe), erste Etappe des Prozesses | 421–808 ms, davon Selbsttest 253–591 ms; jede weitere Etappe 3 Bilder |
| Zeichenaufrufe / Dreiecke des Bildes bei km 2 | 12 / 13.056 |
| `ERGEBNIS` von `run_stage.gd`, Arcade gegen Modern, Kiel – Hamburg und dev_testetappe (Nacht, Regen) | je 28 Schlüssel, nur `gfx` verschieden |

Zeiten auf einer echten Grafikkarte und auf dem Steam Deck sind hier nicht messbar.

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
