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
| `scripts/race3d/sight_corridor.gd` | `SightCorridor` | Sichtkorridor der Kurven aus der wirklichen Geometrie: Hülle aller Sichtlinien bis zum F2-Bedarf (Nachtrag A-17, 5.3) |
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

### 3.8 Vorlauf vor der Startlinie (FIX-ZS1, Befund QA1-B1)

Beim stehenden Start jeder Etappe steht das Auto bei z = 0 (Mitte), sein Heck bei −2,4 m und die Kamera
`render.camera_distance_m` = 9 m dahinter, also bei z = −9 m. Bis Zwischenstand 1 kannte der Pfad nur z ≥ 0 und
klemmte alles davor auf Grenze 0: die Kamera stand 9 m zu weit vorn, das Spielerauto fehlte im Countdown und erschien
nach „LOS!“ zu groß und zu tief, bis es 9 m gefahren war.

Solange der Pfad am Streckenanfang beginnt (`first == 0`, `has_lead_in()`), geht er vor Grenze 0 **gerade entlang
ihrer Tangente** weiter, auf ihrer Höhe und mit ihrer Richtung: `point(k < 0)`, `centre_at()`, `world()`,
`frame_at()` und `rows_local()` antworten dort. Arcade zeichnet die Straße hinter der Startlinie mit Kurve und Höhe von
Segment 0, und jede Etappe beginnt gerade und eben (`Track._calm`: keine Kurve vor 40 m, keine Steigung vor 30 m) –
beides ist also dieselbe Straße. `z_min()` ist die tiefste Straßenposition, die der Pfad richtig setzt: −∞ mit Vorlauf,
sonst die erste gehaltene Grenze (darunter wird wie bisher geklemmt). Für z ≥ 0 ändert sich nichts (Unit-Test:
bitgleich mit der Interpolation der Grenzen), ebenso nicht nach `trim()` oder bei einem Start mitten in der Etappe.

Der Streamer baut dort **Stück −1** (Reihen −32 … 0, 96 m, Abschnitt 4.1), die Fahrzeugebene zeigt Autos, deren Heck
vor z = 0 liegt (Abschnitt 11.1). Belege (gemessen, Kiel – Hamburg ab km 0, Mittel): Auto im Bild an Arcades Stelle,
Kanten ≤ 2 px von Arcades Lackfläche (192 × 192 px), Straßenmitte 0–60 m voraus ≤ 1,2 px neben Arcades Projektion
(`tests/race3d/render/check_start_km0.gd`).

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

**Stück −1, der Vorlauf** (FIX-ZS1, Abschnitt 3.8): Solange der Pfad am Streckenanfang beginnt, ist das niedrigste
Stück −1 (Reihen −32 … 0) statt 0. Es gilt dieselbe Laderegel – gewünscht, solange es höchstens `keep_behind_m` hinter
der Kamera liegt, also bis die Kamera 150 m gefahren ist. Seine Reihen liegen auf dem geraden Vorlauf des Pfads und
tragen die Daten von Segment 0 mit eigenem Index und eigener Straßenposition, aber **ohne Requisiten und Schilder**
(`ChunkContext.lead_in_snapshot()`): Straße, Markierung, Bankett, Leitplanken und Gelände entstehen wie in jedem Stück,
nichts der Etappe steht doppelt (kein zweites Starttor). Das Gelände wiederholt den Querschnitt der Reihe 0. Die
Kamera sieht davon nur die letzten Meter vor der Startlinie (der Boden am unteren Bildrand liegt bei 3,4 m Augenhöhe
6,1 m vor ihr, abgeleitet); das volle Stück hält die Prüfungen „32 Segmente je Stück“ und die Zeichenregeln ohne
Sonderfall. Gewünscht ist es, solange die Kamera höchstens 150 m hinter der Startlinie liegt (Auto bis z ≈ 159 m, km 1,6
der Etappe bei Zeitmaßstab 10); ein Start weiter hinten in der Etappe lädt es nie.

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
| `in_sight_envelope(z, x, reach, half_len)`, `bend_intrusion(…)` | liegt ein Teil des Fußabdrucks in der genauen Hülle der Sichtlinien (A-17) / wie tief (m, quer zur Straße; negativ = draußen) – FIX-R7a, 5.3 |

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

`corridor_width(k, seite)` (Meter jenseits des Banketts) ist seit R7a (Nachtrag A-17) die **Hülle der wirklichen
Sichtlinien** (`SightCorridor`): von einer Kamera in jeder Spur zu einem Fahrzeug in jeder Spur, bis
L = min(`corridor_chord_m` = 300 m, F2-Bedarf / 0,6 + 9 m Kamera) Weg voraus. Der F2-Bedarf ist der Anhalteweg bei der
schnellsten fahrbaren Geschwindigkeit am Wagen, genau wie `fairness.speed_profile()` ihn rechnet (7.2), der größte von
trocken, Regen und Schnee – der Korridor hängt also nicht vom Wetter des Rennens ab. Wo eine Sichtlinie die Straße
verlässt, ist der Korridor diese Hülle, mindestens aber der schlichte Streifen + 0,55 m (`BEND_FLOOR_M`: so zählt
`ChunkContext.in_bend_corridor()` ihn als Kurvenkorridor); sonst der schlichte Streifen `corridor_min_m` (8 m ab
Fahrbahnrand). Engste Kurve des Netzes: 83,6 m. Die Hülle selbst, ohne diese Mindestbreite, liefert
`envelope_width(k, seite)` (0, wo keine Sichtlinie die Straße verlässt; `rows()["envelope"]`) – sie prüfen der
Stadtzaun, der Fußabdruck der Requisiten (unten) und die Grenzpfeiler (FIX-R7a).

- **Verfahren** (`scripts/race3d/sight_corridor.gd`): eine Kamera auf jeder Reihe, auf der äußersten Spurmitte links
  und rechts (die Sichtlinien der Spuren dazwischen liegen in deren konvexer Hülle; rechts gilt die Mitte der Tankspur,
  sobald sie öffnet – `Track.fuel_lane_x()`); Ziele sind die äußersten Spurmitten jeder Reihe bis L und das genaue Ende.
  Vom fernen Ende zur Kamera zurück ist die Sichtlinie mit dem größten Peilwinkel nach rechts (links) die äußerste,
  die den Querschnitt der eben erreichten Reihe noch kreuzt; ihr Schnittpunkt ist dort der Rand. Dreht die Straße bis
  L weniger als 1,2 rad, genügt je Seite ein Kamera- und ein Zielpunkt; sonst zählen beide äußersten Linien auf beiden
  Seiten (jenseits einer Vierteldrehung kehrt sich die Reihenfolge der Schnittpunkte um – in Kehren dadurch bis 2,4 m
  vorsichtiger als nötig). Nie über die Mittelachse zu einem anderen Teil der Straße hinaus (`clearance()`, beim
  Lesen angewandt); Ziele, die gegen die Kamera mehr als 2,6 rad gedreht sind, zählen nicht. Gegen eine vollständige
  Referenz (jede Kamerareihe, jede Spurmitte, jede Zielreihe, jeder Schnittpunkt jeder Sichtlinie mit jedem
  Querschnitt) **ohne Fehlbetrag** (Unit-Test `test_sight_corridor.gd`: langer und kurzer Bogen, Gerade vor der Kurve,
  S-Kurve, Kehre, drei Spuren mit Tankspur; gröbere Kameraschritte verfehlen Knicke der Hülle um bis zu 1 m und wurden
  verworfen).
- **Was das heißt**: das Band läuft an Anfang und Ende einer Kurve aus; in der Kurvenmitte ist es schmal, wo das
  Tempo klein ist (Bergkurven T3/T4: L = 118–119 m, Pfeilhöhe 11–13 m statt 83 m), am Kurvenanfang breit, solange die
  Anfahrt schnell ist – die Sichtlinien der schnellen Anfahrt schneiden in die Kurve (Autobahnbogen R = 200 m: Mitte
  10 m, die ersten 100 m bis 43 m, das alte Band überall 55 m). Eine kurze Kurve bekommt nicht die Pfeilhöhe ihres
  eigenen Bogens, sondern den Abstand der Sichtlinien von den Geraden davor und danach über ihre Ecke (60-m-Bogen
  R = 150 m nach langer Geraden, L = 300 m: Scheitel 22,5 m jenseits des Banketts; der Bogen allein −1,4 m, das alte
  Band 74 m). Eine Gerade vor der Kurve ist frei, soweit
  keine Sichtlinie in die Kurve über sie läuft (mehr als eine Sehne L vor der Kurve immer).
- **Rechnung**: faul und schrittweise, wenn Reihen gelesen werden (`ensure()`), jede Kamera einmal je Etappe; dazu
  rechnet der Streamer voraus (`TerrainProfile.warm()`), bis zwei Stücke über `landmark_path_m` hinaus (die fernen
  Wahrzeichen lesen das Gelände ihrer Reihe so weit voraus) – in Bildern, die nichts sammeln und in denen die
  Festschreibe-Schleife nichts zu tun hat (`_commit_pending()` entscheidet vor der Schleife: kein Bau fertig, kein
  Stück halb festgeschrieben – so auch, wenn Stücke in Schritten über mehrere Bilder festgeschrieben werden), höchstens
  0,25 ms je Bild; beim Laden diese ganze Strecke auf einmal, und solange der Korridor hinter dem liegt, was das nächste
  Sammeln braucht, bis 2 ms je Bild – ein gesammeltes Stück findet seine Reihen fertig vor. `warm()` arbeitet in
  Schritten und hört vor dem Schritt auf, der die Frist überschritte: ein Block Geometrie (etwa 0,25 ms je 32 Kameras)
  und ein Block F2-Bedarf (etwa 0,16 ms) sind je ein eigener Schritt und nur der erste eines Aufrufs, ein Fächer
  (0,03–0,06 ms) nur, solange sein laufendes Mittel noch passt (FIX-R7a, gemessen mit 0,25 ms Frist: Mittel 0,21 statt
  0,31 ms, p99 0,29–0,39 statt 0,50–0,67 ms). `perf_stats()` zeigt unter `streamer.corridor` die Zeit des Vorrechnens
  (`warm_ms_avg`, `_max`, `warm_calls`) und was trotzdem im Hauptthread nachgerechnet wird (`sync_ms_max`, `_sum`,
  `sync_calls`); `reset_stats()` setzt beides zurück, die Werte nach dem Laden zeigen also die Fahrt (bei Zeitraffer 40
  – 1,3 s Fahrt je Bild – ist Nachrechnen unvermeidlich, bei Zeitraffer 4 nach dem Laden kein Aufruf, gemessen). Ein Start mitten in der Etappe kennt die Kameras vor dem ersten Pfadpunkt (150–246 m hinter der
  Kamera) nicht: an den 13 Bildstellen sind die Reihen ab der Kamera an 11 Stellen gleich, an zweien weichen 4 bzw. 8
  Reihenseiten direkt an der Kamera um höchstens 0,56 m ab (gemessen).

Im Korridor liegt der Boden nie über der Fahrbahn: Relief bekommt ein Ring nur, wenn schon sein **innerer Nachbar**
außerhalb des Korridors liegt – damit ist auch die gerade Linie zwischen zwei Ringen im Korridor nie über null.
`ChunkContext.in_bend_corridor()` sagt dem Requisiten-Builder, wo nichts über 0,5 m stehen darf (Bodendecker füllen
den Korridor); der Stadt-Builder lässt Zaun-, Hecken- und Mauerstücke weg, sobald ihre Mitte oder eines ihrer Enden in
der **genauen** Hülle liegt (`in_sight_envelope()`, Rand 0,3 m für Abdeckung und Pfeiler – FIX-R7a, Befund QR7a-05:
die Mindestbreite am Kurvenende ließ Stücke weg, die in keiner Sichtlinie stehen); der Grenz-Builder prüft seine
Pfeiler gegen dieselbe genaue Hülle (`pillar_in_sight()`).
Gemessen im ganzen Netz (128 Etappenrichtungen, gleiche Strecken, Sonde des Pakets R7a): von 203.367 Requisiten im
Band ließ das alte Band 37.368 im Kurvenkorridor weg (18,4 %), die Hülle 14.342 (7,1 %) – 23.026 kommen zurück
(16.947 Bäume, 2.947 Pflanzen, 952 Felsen, 1.944 Häuser, davon 1.878 in Städten), keines fällt neu weg. Stadtzäune:
Arcade zeichnet 79.662 Stücke, das alte Band ließ 64,3 % stehen, die Hülle 75,3 %, die genaue Hülle 75,9 % (60.473,
FIX-R7a, echte Bauten). Grenzdächer: von 48 hängen 3 an Masten (vorher 4; Belgrad – Sofia km 340 steht wieder auf vier
Pfeilern).

**Fußabdruck (FIX-R7a, Befund QR7a-01 von QA-R7a):** `in_bend_corridor(z, x)` prüft nur den Fuß, und der
Requisiten-Builder gibt nur ihn (bei `align: edge` den Anker = Vorderkante plus Ausdehnung). Mit der schmaleren
wirklichen Hülle stehen zurückgekehrte Requisiten genau an ihrem Rand – Fuß draußen, Krone oder Fassade drin: gemessen
an echten Bauten (128 Richtungen) 5.630 Requisiten über 0,5 m (3.604 Bäume bis 12 m tief, 1.563 Stadthäuser bis 19 m;
Basis 974) – das strenge Lesen von A-17 hält so nicht. Der Kern bietet dafür:
- `ChunkContext.in_sight_envelope(z, x, reach, half_len)` – liegt ein Teil des Fußabdrucks in der genauen Hülle;
  `reach` = wie weit das Objekt vom Fuß zur Straße reicht (Kronenradius, Anker bis Vorderkante), `half_len` = halbe
  Länge längs der Straße (abgetastet je halbe Reihe; zwischen zwei Reihen zählt die größere Hülle der beiden);
- `ChunkContext.bend_intrusion(…)` – wie tief der Abdruck quer zur Straße hineinreicht (negativ: draußen): um so viel
  hinausgeschoben steht er draußen;
- der Schnappschuss hält die Hülle 8 Reihen über beide Enden des Stücks hinaus (`ENV_MARGIN`), ein Abdruck am Ende
  eines Stücks reicht in die Reihen des Nachbarn.

Der Aufruf gehört dem Besitzer von `builders/props.gd` (R7c); FIX-R7a übergibt ihn als Änderung (Bericht FIX-R7a,
`notes_for_next`): `drop_reason()` prüft den Abdruck gegen die genaue Hülle, und vorher schiebt `push_out()` eine
Requisite, deren Fuß draußen steht und deren Abdruck hineinreicht, um die Tiefe + 0,3 m hinaus (höchstens 12 m; tiefer
oder dann jenseits des Bands: weggelassen). Gemessen an echten Bauten (128 Richtungen, Kopie mit der Änderung): 218.103
Requisiten gezeichnet; gegen die Basis 23.943 zurück und 8 neu weg (Stadthäuser, die tiefer als 12 m hineinragen),
gegen R7a 1.711 zurück (Bäume, Pflanzen, Felsen: die genaue Hülle statt der Mindestbreite) und 211 weg; mit höchstens
6 m wären es 191 bzw. 794 (548 Stadthäuser) – u. a. das Eckhaus an C1. Kein Teil einer Requisite über 0,5 m mehr in der
Hülle. Verdeckungssonde: C1 bei 270 m in zwei von drei Spuren wieder sichtbar (6/16/18 px; R7a 6/0/0), T3/T4 wie R7a.
Netzprüfung `tests/race3d/props_footprint.gd` (`--full`: alle 128 Richtungen): 0 Requisiten über 0,5 m mit dem
Abdruck in der Hülle mit der Änderung, 5.728 ohne.

**Eingebaut in RINT-M3 (A-24, das ganze Objekt):** Der Abdruck ist nicht mehr die halbe Bibliotheksbreite, sondern das
Modell selbst: `Props.footprint()` nimmt die AABB der Vereinigung aller Varianten eines Sets (`PropLibrary` „aabb“
aus dem Manifest), skaliert, gespiegelt und mit dem Gierwinkel gedreht, mit dem `_place()` das Modell stellt
(`place_yaw()`: Bäume, Pflanzen, Felsen zufällig, `face_road` ±20°); an der Kante ausgerichtete Häuser reichen quer
mindestens bis Arcades Vorderkante (max(Ausdehnung, AABB-Seite)), längs zählt die AABB. `push_out()` und
`drop_reason()` rechnen mit demselben Abdruck, angehängte Requisiten (`attach`) ebenso. `props/city_french_sud` reicht
mit den Obergeschossen (2,6–7,6 m hoch) 2,08 m über seine Ausdehnung `extent_m.left` hinaus – die Ausrichtung an
Arcades Kante bleibt (die Ausdehnung ist Arcades Kante), der Abdruck nimmt die AABB. Die Netzprüfung heißt jetzt
`tests/race3d/check_props_footprint.gd` (Gate von `run_tests.sh`, sechs Richtungen; `--full` 128) und rechnet das
Modell unabhängig aus dem Manifest (Gierwinkel als neuntes Element der Listeneinträge), über `list` und
`attach_list`. Gemessen: `--full` 0 von 218.090 gemessenen Requisiten (218.105 gezeichnet); Mutationen (sechs
Richtungen): nur der Fuß 474, das Breitenmodell von FIX-R7a 391 Requisiten in der Hülle.

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
| `corridor_chord_m`, `corridor_min_m` | 300, 8 | Sichtkorridor: längste Sichtlinie L (darunter der F2-Bedarf) und schlichter Streifen ab Fahrbahnrand – nicht ohne die Projektleitung ändern |

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
| F7 der Korridor ist die Hülle der Sichtlinien (A-17) | `modern_sight_f7`: unabhängige Referenz `Fairness.sight_envelope()` (jede 7. Kamerareihe, jede Spurmitte, Bedarf aus `speed_profile()`, doppelte Genauigkeit): jede ihrer Sichtlinien jenseits des Banketts liegt im Korridor, und er zählt dort als Kurvenkorridor | 0 nicht abgedeckt, 0 nicht gezählt |
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
- **Sichtkorridor und Vegetation**: seit R7a aus der wirklichen Geometrie (A-17, 5.3); in Städten bleibt L meist 300 m
  (die schnellste fahrbare Geschwindigkeit kennt keine Tempolimits), Häuser in Stadtkurven kommen daher nur zum Teil
  zurück.
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
**Aufwärm-Ebene** (R4): die Aufwärm-Knoten liegen auf der Render-Ebene 20 (`ModernRenderer.WARMUP_LAYER`, ein
Boden-Knoten behält `GROUND_LAYERS`); die echten Spots und Punktlichter der Lichtebene lassen sie aus
(`lights.gd` `LIGHT_MASK`), nur die Aufwärm-Lichter erreichen sie. Vorher beleuchtete das Abblendlicht nachts die
Aufwärm-Knoten in allen vier Phasen: die Variante „ohne positionelles Licht“ eines Materials, das die Startansicht
nicht zeigt, fehlte – N1 (Hamburg – Hannover km 71, 22 Uhr) übersetzte das Schild-Programm beim ersten fernen
Schild während der Fahrt (`warmup_kalt`: 3 Varianten nach 6–8 s, ermittelt über Godots Shader-Cache: das Programm
von `sign.gdshader`). Danach 0 (443 statt 386 Varianten vor dem Start).

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
- **Welche Autos gezeichnet werden** (`in_range()`): Front höchstens 14 m hinter der Kamera, Heck höchstens Sicht +
  30 m voraus, das ganze Auto zwischen `RoadPath3D.z_min()` und der letzten integrierten Grenze. Am Start einer Etappe
  ist `z_min()` −∞ (Vorlauf, Abschnitt 3.8): das Spielerauto mit dem Heck bei −2,4 m steht im Countdown im Bild
  (FIX-ZS1; vorher blendete die Grenze z ≥ 0 es aus, Befund QA1-B1).
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
**Blinkende Lampen** (M2ZS1): Eine feste Lampe mit `"blink"` = (Takt s, an s, Phase s) leuchtet nur nachts (Lichter
der Palette über 0,2) und nur, solange `fposmod(view.time + Phase, Takt) < an` (`blink_lit()`, reine Funktion, nach
`view.time` – im Pausenbild steht sie still). So blinkt die rote Flugbefeuerung auf den Pylonen der
Schrägseilbrücken wie Arcades prozeduraler Pylon (`RoadRenderer._pylon`: 1,6 s Takt, 0,8 s an, die zwei Seiten um
0,4 s versetzt, also im Wechsel), mit Arcades rotem Schein um die Lampe als zweitem Lichtpunkt (Radius max(3 px,
1,2 m), Stärke 0,8 × Lichter). Den Takt gibt `builders/props.gd` (`PYLON_BLINK`) den Lampenankern des Pylonmodells ab
25 m Höhe, nur für Einträge mit `proc` = `pylon`.

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
  Die Flugbefeuerung des Brückenpylons (Modell seit AS4R, Anker auf 88,3 m) blinkt wie in Arcade (M2ZS1, 11.2).
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
  Häuser einer Landschaftsregel bleiben im Korridor weggelassen (strenge Lesart, A-17: nichts über 0,5 m in der Hülle
  der Sichtlinien); der Korridor selbst ist seit R7a die Hülle der wirklichen Sichtlinien (5.3).
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

Seit R6 (Welle 3) sind Tankstelle, Grenze, Stadtmobiliar, Start-/Zieltor und Blitzer ausgebaut – Einzelheiten,
Sichtlinien-Entscheid der Stützen, abgespannte Dächer und Prüfungen in
[renderer-modern-bauten.md](renderer-modern-bauten.md); die Montage RINT-M2 (§17) hängt Dächer ohne Stütze an einen Mast.

### 14.5 Start- und Zieltor (`builders/gantry.gd`)

Aus den Schild-Ereignissen mit Seite 0 (`start` 14 m nach der Startlinie, `finish` am Ziel), wie `SignPainter._gantry`:
zwei Pfosten 0,45 m außerhalb der Bankette, 7 m hoch; Banner von 5,4 bis 7 m – Ziel rot mit Schachbrettstreifen und dem
Text des Ereignisses („ZIEL“), Start dunkel mit hellem Streifen, „START“ und drei Countdown-Lampen (rot, eine mehr je
Sekunde, alle grün beim Start; Schein über die Ebene `flares`, Farbe und Stärke je Bild aus `view.countdown`).
Ausbau mit Fachwerkträger und Flutlichtern (R6/FIX-R6): [renderer-modern-bauten.md](renderer-modern-bauten.md).

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
- Wahrzeichen, die Arcade prozedural zeichnet und für die es weder Sprite noch Modell gibt (Belgrad, Hannover, Leipzig,
  Dortmund, Calais, Madrid), vertritt das Ersatz-Set ihres Etappenplan-Eintrags (FIX-WASSER-R; Einzelheiten:
  [renderer-modern-gelaende.md](renderer-modern-gelaende.md) Abschnitt 4.1). Eine getönte ferne Vertretung ist ein
  MultiMesh mit einer Instanz, damit die Tönung schon vor dem Stück gilt.

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
- `layers/far_ground.gd` (FIX-WASSER): Der Fernboden liegt auch mindestens 0,3 m unter der tiefsten Wasserfläche des
  geladenen Fensters – vorher lag er 4 m unter der tiefsten Straße und deckte Wasser zu, das tiefer liegt (Köhlbrandbrücke:
  Elbe 9 m unter der Fahrbahn, Wiese statt Fluss, Fähren auf der Wiese). Einzelheiten und die Liste der betroffenen
  Brücken: [renderer-modern-gelaende.md](renderer-modern-gelaende.md) Abschnitt 3. Die Render-Prüfung
  `terrain_cover` bewacht das an der Köhlbrandbrücke (Position K1, km 78,1: Fernboden-Anteil unter dem Horizont
  höchstens 2 %; gemessen 0,38 %, mit dem alten `far_ground.gd` 31,96 %).
- Pylone der Schrägseilbrücken: im Testbuild ZS1 Vertretungen des Arcade-Sprites, nachts ohne die Lichtebene des
  Sprites und ohne Scheinwerferlicht, betongrau wie Arcades prozeduraler Pylon (FIX-WASSER-R; vorher fast weiß). Seit
  AS4R (in der M2-Linie seit M2INT) ist der Pylon ein **Modell** (`props/bridge_pylon`, Seile bis zur Deckkante, eine
  Stufe); die dunkle Vertretung bleibt der Rückfall, wenn das Modell fehlt. Der Nachtatlas des Modells ist der
  angestrahlte Pylon des Sprites, den Arcade nie zeigt, und der Mond beleuchtet die hellen Betonflächen des Modells,
  während Arcades prozeduraler Pylon nachts Beton × Umgebungslicht ist (`RoadRenderer._oc`) – beim Zusammenführen mit
  ZS1 (M2ZS1) leuchteten die Pylone der Köhlbrandbrücke um 22 Uhr wieder hellgrau (gemessen im Bereich von
  FIX-WASSER-R, 500–780 × 150–350, km 78,1, mittlere Leuchtdichte: Arcade 60,1, ZS1 58,4, Modell 84,4, ohne Nachtatlas
  79,5). Jetzt bekommen Pylone mit `prefer_proc` eine Kopie des Modellmaterials ohne Nachtatlas (`emit_energy` 0) und
  mit `night_albedo` 0,45 (`PYLON_NIGHT_ALBEDO`; neuer Parameter von `baked.gdshader`, Vorgabe 1 = jedes andere
  Material unverändert; `_dark_model_override()`, Gruppe `md|…`) – derselbe Shader, keine neue Variante; bei Tag
  dasselbe Bild. Gemessen über die ganze Brücke (22 Uhr, ab km 77,6 mit 80 km/h und Verkehr, derselbe Bereich,
  Arcade / ZS1 / M2ZS1): km 77,7 76,5 / 79,7 / 70,7; km 78,1 60,1 / 58,4 / 55,9; km 78,8 48,1 / 49,8 / 43,0; km 78,9
  47,7 / – / 42,6; km 79,7 51,6 / 52,1 / 51,7 (mit 0,5 dort 53,7: die Laternen beleuchten die Seile neben dem Deck).
  Steam-Deck-Stufe (1280 × 800, Arcade mit Balken: Bereich 40 Zeilen tiefer) km 77,7 / 78,1 / 78,8: Arcade 76,5 /
  60,1 / 48,1, ZS1 78,4 / 61,0 / 50,9, M2ZS1 69,2 / 57,7 / 43,5. Die rote Flugbefeuerung ist ein Lampenanker des
  Modells und blinkt wie in Arcade (11.2).
Offen für R5: Deck, Träger, Pylonhöhe und Seilfächer je Brücke (`height_m`, `cables`; das Modell hat Arcades
Sprite-Höhe 88,8 m), Uferwände.

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

### 14.10 Nacharbeit nach der Prüfung der ersten M2-Montage (Bauabschnitt FIX-M2)

Grundlage: die Befunde von QA-M2-BILD (B-…) und QA-M2-SYSTEM (M2S-…) auf `6e48405`; Messungen auf dieser Maschine
(Software-OpenGL unter Last), Bildpaare mit `probe/qa_vehicles.gd` der Prüfung (dieselbe Ansicht, dieselben Testautos).

- **Abblendlicht ohne Glanz** (B-05; seit RINT-M2 im Material statt am Licht, §17.1): die zwei Spots des Abblendlichts
  (`layers/lights.gd`, `SPOT_SPECULAR` 0) gaben keinen Glanzanteil mehr. Die Lampen sitzen neben dem Auge – auf jeder flachen, glänzenden Fläche, die zur Kamera
  schaut, fiel der Halbvektor auf die Normale, und der scharfe Klarlack-Lappen machte Lkw-Hecktüren, Stoßfänger und
  Kennzeichen zum weißen Kasten. Roter Lkw bei 60 m, 22 Uhr, mittlere Leuchtdichte des Hecks 152 → 47 (Arcade 42),
  bei 20 m 109 → 61 (Arcade 56); Limousine silber bei 60 m ohne weißen Block. Arcade beleuchtet ein Auto im Kegel nur
  diffus. Rückstrahler (Kanal 15) und Schilder behalten ihr eigenes Kegelgesetz.
- **Schein von Bremslicht und Blaulicht der Modelle** (B-03, B-04): Arcades Leuchtgesetz liegt über einem Sprite, dessen
  Lichtebene den ganzen Leuchtenblock (und den Lichtbalken der Polizei als breiten blauen Fleck) malt; ein Modell
  leuchtet nur mit seinen Lampenflächen (8-cm-Lichtbalken, schmales Bremsband des Sportwagens). Der Schein selbst war
  richtig (Rot +38 in der Mitte, gemessen mit abgeschalteten Lichtpunkten). Darum `VehiclePose3D.model_glow_gain()`:
  Bremsanteil × 2,2 (`MODEL_BRAKE_GAIN`, ein Rücklicht allein bleibt bei Arcades Stärke), Blaulicht × 2,4
  (`MODEL_BEACON_GAIN`); Sprite- und Kasten-Vertretungen behalten Arcades Gesetz. Polizei bei 60 m blaue Pixel Tag
  28 → 153 (ZS1 114, Arcade 182), Nacht 49 → 103; bei 20 m Tag 411 → 1 004 (= ZS1). Das schmale Bremsband des
  Sportwagens bleibt ein Modellthema (größere Lampen, mittleres Bremslicht): bei 60 m am Tag 11 rote Pixel gegen
  Arcades 34.
- **Lack des Spielerautos** (B-06): im Rennen wird der Lack des Spielerautos bei Tag um 35 % zu seiner eigenen
  Leuchtdichte hin entsättigt, nachts nicht (`ModernMaterials.VEHICLE_PLAYER_DESAT` × (1 − Nacht der Palette),
  `player_paint()`; die Fahrzeug-Ebene setzt den Lack neu, wenn sich die Nacht um mehr als 0,02 ändert). Gemessen mit
  R4s Lichtgesetz zusammen (Lackpixel farbgefiltert, „Mittel“): Limousine 12 Uhr 0,73 → 0,63 (Arcade 0,58), Sportwagen
  19:30 0,40 → 0,39 (Arcade 0,34), Kompakt 22 Uhr Schnee 0,76 unverändert (Arcade 0,72). Der Showroom zeigt den Lack des
  Modells.
- **Rückfallhinweis** (M2S-07): bei `gfx_fallback` „manifest“ oder „script:…“ nennt der Hinweis fehlende oder
  beschädigte Spieldateien, sonst die Grafik (`RaceSession.fallback_from_files()`).
- **Prüfungen**: `check_vehicle_lights` → `blaulicht` (Polizei bei 60 m, Tag ≥ 200 / Nacht ≥ 600 deutlich blauere
  Pixel; mit Arcades Gesetz allein 102 / 303) und `abblendlicht` (roter Lkw bei 20 und 60 m: höchstens 5 % des Hecks
  über Leuchtdichte 200, Mittel ≤ 0,35; vorher 13 % / 45 %); `check_seam` → `rueckfall_dateien`; `check_vehicles` →
  `leistung` schaltet ein Auto dreimal zwischen zwei Stufen und verlangt dieselben Knoten (Stufenspeicher, M2S-03);
  `check_vehicle_standin` lädt ein Test-Manifest ohne Modell für `player/kombi`, `traffic/sports_red`,
  `traffic/van_white` und `traffic/bus_blue` (vier Sätze, `TEST_SETS`) – ein Fall ohne Vergleich ist ein FEHLER (M2S-02); `test_far_ground_lies_below_the_water_of_a_bridge`
  legt das Wasser so tief, dass nur der Wasserterm entscheidet (M2S-05); der Unit-Läufer zählt einen Test, der an
  einem Skriptfehler abbricht, als fehlgeschlagen (M2S-04).
- **Waldprüfung** (M2S-01): `check_instance_budget_wald.gd` fährt 20 s statt 100 s (der Wald steht ab dem ersten
  Bild; die Fahrzeuge allein prüft `check_instance_budget.gd` über 100 s), meldet Laden und Fahrt getrennt und darf
  1 800 s laufen (Kopfzeile `## render-check-timeout:`; seit RINT-M2 mit eingespeistem Verkehr unter Last, §17.4); `tools/run_render_checks.sh` meldet ein Zeitlimit als
  `ZEITLIMIT` (kein Ergebnis) statt als verletzte Regel.

### 14.11 Bekannte Lücken im ersten Testbuild (Stand ZS1; die heutige Liste steht in §17.9)

- **Kein Wetter in der Luft** (R4, M2): kein Regen, kein Schneefall, keine Gischt; nasse Fahrbahn und Schneeränder gibt es.
  *Seit R4 behoben (§15).*
- Tunnel und Brücken nur als Mindestbauten (14.3, 14.7); keine Grenzstationen (Dach, Kabinen) – Arcade zeigt sie.
  *Seit R5 und R6 behoben (§16, renderer-modern-bauten.md).*
- Keine Sonnenscheibe am Tag; kein überstrahltes Draußen an der Tunnelausfahrt. *Seit R4 behoben (§15.6, §15.8).*
- Spielerautos: Limousine mit steiler Heckscheibe statt Arcades Fließheck, Kompakt mit schwarzem Dach (Modellnacharbeit).
- Kurveninnenseiten in Bergetappen kahler als Arcade (Sichtkorridor F7: Bäume werden durch Bodendecker ersetzt –
  Entscheidung der Leitung nach A-3). *Seit R7a nur noch, wo die Sichtlinien laufen (A-17, 5.3).*
- Die Leistung auf echter Hardware ist nur über den Leistungstest messbar.

## 15. Licht, Nacht, Wetter (Bauabschnitt R4)

R4 übernimmt in Welle 3 den Renderer-Kern (Bauplan §5, Spalte W3) und baut Licht, Nacht und Wetter aus. Zahlen
„gemessen“ stammen von der Build-VM (llvmpipe unter Xvfb bzw. headless); alles über echte Grafikkarten und das Steam
Deck ist abgeleitet.

### 15.1 Zonen: `EnvironmentRig.set_zone(kind, amount)`

Die Schnittstelle, über die Bauwerke dem Umgebungs-Rig sagen, wie weit die Kamera in ihnen steckt (Bauplan §6 R5:
„Environment changes are requested from R4 … through `EnvironmentRig.set_zone(kind, amount)`“). Aufruf immer über die
Fassade und `has_method`, nie über einen Klassennamen:

```gdscript
var env: Node = renderer.get("env")          # null, solange environment_rig.gd fehlt
if env != null and env.has_method("set_zone"):
	env.call("set_zone", "tunnel", amount)   # amount 0 (draußen) … 1 (drinnen)
```

| Art | Wirkung |
|---|---|
| `"tunnel"` | Licht zum Tunnellicht (`Palette.TUNNEL_AMBIENT`, Sonnenenergie 0 – das eine Schattenlicht bleibt, D5), Nebel nach Arcades Tunnelgesetz (`Palette.TUNNEL_FOG` ab 12 m über `render.tunnel.darkness_m`), Globals `ce_tunnel` = amount, `ce_wet`, `ce_snow` und Wind gegen 0; der Hintergrund zeigt keinen Himmel, solange die Ausfahrt außer Sicht ist; zur Ausfahrt hin wirkt das Draußen überstrahlt (Belichtungsrampe, 15.6) |
| `"bridge"` | 0 … 1 über offenem Wasser: der Wind (`ce_wind`) bläst um bis zu 50 % stärker |
| jede andere | wird behalten und im Schnappschuss gezeigt (`environment.zones`), ändert nichts |

- Der Wert gilt bis zum nächsten Aufruf derselben Art und wird auf 0 … 1 begrenzt; `zone(kind, fallback)` liest ihn.
- **Solange in einer Etappe niemand `set_zone("tunnel", …)` ruft**, nimmt das Rig den Tunnel wie bisher selbst aus der
  Tunnelliste des Etappenplans (`tunnel_blend()`, eine Funktion der Kameraposition) – das Licht der Mindestbau-Röhre
  bleibt also unverändert, bis der Tunnel-Builder die Zone setzt. Ab dem ersten Aufruf gilt nur noch der gesetzte Wert.
- Das Rig liest den Wert in seinem nächsten `update()`, das in jedem Bild **vor** den `update()` der Builder läuft:
  eine Zone, die ein Builder in seinem `update()` setzt, wirkt ein Bild später (bei 60 Bildern je Sekunde 17 ms).
- Kosten: ein Wörterbuch-Eintrag je Aufruf. Prüfung: `tests/unit/race3d/test_environment_rig.gd` → `test_set_zone`.

### 15.2 Wetter in der Luft (`layers/weather.gd`)

Regen und Schneefall sind **zustandslose GPU-Teilchen**: eine MultiMesh aus Vierecken, ein Zeichenaufruf; der Ort
jedes Tropfens ist eine reine Funktion seiner Instanznummer, der Kamera und der Spielzeit `ce_time`
(`assets/shaders/modern/particles_rain.gdshader`, `particles_snow.gdshader`). Nichts wird simuliert oder gespeichert:
das Bild ist im Sync-Modus und mit `--shot-fast` bestimmt (Regel 10), steht im Pausenbild still und springt nicht, wenn
der schwimmende Ursprung verlegt wird; es gibt keinen Prozess-Shader zu übersetzen. (Der Bauplan nennt
`GPUParticles3D`; ein solcher Knoten hält Zustand je Bild auf der Grafikkarte – mit `--shot-fast` stünde er still, zwei
Läufe gäben verschiedene Bilder, beim Ursprungsversatz spränge er. Als Vertragsfrage gemeldet.)

- **Raum**: ein Kasten im Kameraraum wie Arcades (`RoadRenderer._draw_weather`: Tropfen 3 … 45 m voraus, ±14 m, bis
  9 m hoch, 8,5 m/s Fall, 0,6 m/s Drift; Flocken 2 … 38 m, 1,2 m/s, ±0,7 m/s Schaukeln). Er dreht mit der
  Straßenrichtung an der Kamera und wandert mit ihrem Weg (`odo` = `camera_z` modulo Tiefe): die Tropfen ziehen vorbei
  wie in Arcade. An den Kastenflächen blenden die Teilchen weich aus statt aufzutauchen.
- **Menge je „Effekte“**: die Teilchenzahl der Stufe (300 / 1.500 / 4.000) in einem Kasten je Stufe (`RAIN_BOX`,
  `SNOW_BOX`) – schon „Aus“ hat mindestens Arcades Dichte (Unit-Test `test_weather`), auch die Steam-Deck-Stufe zeigt
  Niederschlag.
- **Aussehen**: Regen als Striche der Bewegung in 18 ms (der Fallanteil 2,5-fach wie in Arcade), Schnee als runde
  Flocken von 4,5 cm (1,2 … 5,5 px), bei schneller Fahrt zu Strichen gezogen. Helligkeit nach Arcades Gesetz
  (Farbe × min(1, Umgebungslicht + 0,35)) plus dem Abblendlicht dort, wo das Teilchen im Kegel hängt – nachts
  glitzern Regen und Schnee vor dem Auto.
- **Tunnel**: ausgeblendet über die Portalrampe (`1 − tunnel01`), drinnen unsichtbar. Kein Schatten.
- **Wächter** (FIX-R4, Befund B5 von QA-R4): stuft der Langsamkeits-Wächter im Countdown die Voreinstellung herab,
  folgt die Ebene sofort (`quality_lowered(levels)`): Teilchenzahl und Kasten der niedrigeren Stufe (die ersten n
  Instanzen der gebauten MultiMesh – der Shader setzt jede Instanz nur nach ihrer Nummer, es braucht keinen neuen
  Puffer) und die Gischt der niedrigeren Stufe. Vorher behielt der Niederschlag 4.000 Teilchen im großen Kasten –
  genau die Füllkosten, die R4 auf llvmpipe gemessen hat. `lights.gd` hatte den Haken schon (Punktlicht-Pool).

### 15.3 Gischt

Hinter jedem Auto auf nasser Fahrbahn ab 40 km/h (voll bei 160 km/h, Arcades Gesetz) – auch hinter Lkw, Bussen und dem
eigenen Auto (Arcade: nur hinter Pkw). Die Fahrzeug-Ebene gibt je Bild die Quellen weiter (`set_spray_sources`: Heck,
Richtung, Breite, Ausblendung, Tempo, Rücklicht); die Wetter-Ebene setzt daraus weiche Wolken
(`assets/shaders/modern/spray.gdshader`: Kamera-zugewandte Vierecke, treibendes Rauschen nach `ce_time`, weiche Kante,
wo die Wolke Straße oder Auto trifft – Tiefentextur). Bei „Effekte: Einfach/Voll“ je eine Fahne hinter jedem
Hinterrad und ein nachziehender Schleier, bei „Aus“ (Gischt laut Tabelle aus) eine Wolke je Auto an der Stelle von
Arcades Ellipse – so zeigt keine Stufe weniger als Arcade. Licht auf dem Prozessor: Umgebung, das Abblendlicht am Ort
der Wolke (`lights.beam_at()`), nachts das Rot der eigenen Rückleuchten.

### 15.4 Nasse Fahrbahn

- `road.gdshader`: um ein Drittel dunkler und glatter (wie bisher), dazu spiegelt der Wasserfilm den Himmel mit dem
  Fresnel-Gesetz von Wasser unter dem Winkel, unter dem die Kamera die Straße sieht (`wet_mirror` 0,42; neue Globals
  `ce_sky_top`, `ce_sky_horizon`, vom Rig) – nah am Auto wenig, zum Horizont viel; nie weniger als Arcades Glanz
  (28 % der Nebelfarbe am Ende der Sicht). Markierung spiegelt etwas weniger.
- **Abblendlicht und Lichtkegel nur auf dem diffusen Anteil** (FIX-R4, Befund B2 von QA-R4): der gespiegelte Himmel
  gehört zum Grundwert der Fahrbahn (er zeigt sich unter dem Bodengesetz als Farbe des Himmels), ist aber keine matte
  Fläche. `road.gdshader` führt darum neben `base` den Anteil `lit`, den die Lampen beleuchten (Asphalt × (1 − Spiegel),
  Markierung × (1 − 0,07 nass) × (1 − 0,35 Spiegel)); `EMISSION` = Bodengesetz(`base`) + Kegel × `lit`. Vorher
  beleuchteten Abblendlicht und Laternenkegel den gespiegelten Himmel wie hellen Asphalt: im Kegel war die nasse
  Fahrbahn 1,77 × so hell wie Arcade (Median 108 gegen 61 von 255, N2 22 Uhr Regen, „Hoch“) und die Markierung hatte
  weniger als den halben Kontrast – ein cremefarbener Fleck vor dem Auto. Jetzt (gemessen, dasselbe Bild): 54 gegen 61,
  wie bei Arcade wird die nasse Straße im Scheinwerfer dunkler als die trockene; die ferne Spiegelung des Himmels bleibt.
- **Spiegelungen der Lampen** (`flare.gdshader`, Variante `CE_STREAK`, Klasse `flare_streak`): je Rück- und
  Bremsleuchte ein Streifen auf der Straße vom Boden unter der Lampe zur Kamera (3–18 m, mit der Entfernung länger),
  hell an der Lampe, zur Kamera hin auslaufend, mit leichtem Flimmern des Films; **tiefengetestet** (das eigene Auto
  und alles davor verdeckt es) und mit denselben fünf Tiefenproben an der Lampe wie ihr Lichtpunkt – eine Lampe hinter
  einer Kuppe oder einem Lkw hat auch keine Spiegelung. Laternen und Tankstellenlampen spiegeln nachts ebenso; ihr
  langer Streifen wird Punkt für Punkt mit dem Fresnel-Gesetz von Wasser unter dem Blickwinkel der Kamera gewichtet
  (`flare.gdshader`, negative halbe Breite der Instanz, 1 ab `fresnel_ref_m` 15 m vor der Kamera): das nahe Ende
  liegt steil unter der Kamera und spiegelt wenig – die ersten Bilder (C1 im Regen, 21:30) zeigten dort einen
  gesättigten orangen Fleck um das Spielerauto. Zur Kamera hin reicht der Schleier höchstens halb so weit wie der
  Weg vom Spiegelpunkt zur Kamera (bei einer hohen Laterne liegt der Spiegelpunkt nahe der Kamera; das Gesetz der
  tiefen Rückleuchten, 1,3 × Weg vom Lampenfuß, zog den Streifen sonst in voller Stärke bis unter die Kamera). Die
  kurzen Streifen der Fahrzeuglampen bleiben ohne Fresnel-Gewicht und ändern sich durch die Grenze nicht.
- **Der Streifen liegt auf der Straße** (FIX-R4, Befund B1 von QA-R4): er war ein waagrechtes Viereck in der Höhe
  des Bodens unter der Lampe. Stieg die Straße zum Auto hin an, hing es zwischen Auto und Kamera in der Luft und stand
  über fernen Autos als rote, flimmernde Säule (N2 22 Uhr Regen bei 4 s: etwa 65 Bildpunkte hoch über einem Auto 300 m
  voraus; in R4s Clip bis an den oberen Bildrand). Jetzt ist er ein Band aus 12 Abschnitten (`flares.gd`
  `streak_mesh()`), und die Instanz trägt in ihrer sonst ungenutzten Basis das Höhenprofil der Straße vom Lampenfuß bis
  zum Fuß der Kamera: die Höhen bei 1/6 … 6/6 des Weges relativ zum Fuß (`flares.gd` `road_profile()`, `put_profile()`;
  Spalten 0 und 1, Spalte 2 x = 1 heißt „Profil da“). Der Shader legt jeden Punkt des Bandes auf die Catmull-Rom-Kurve
  durch die sieben Punkte, mit 3 cm + 0,6 mm je Meter Abstand zur Kamera darüber (das Profil zwischen den Stützstellen
  ist eine Kurve, der Tiefenpuffer in der Ferne grob). Die Augenhöhe für den Spiegelpunkt ist die Höhe der Kamera
  über ihrem eigenen Fuß (auf einer gleichmäßigen Steigung gilt dann das Gesetz der ebenen Straße in deren Ebene).
  Die Fahrzeug-Ebene rechnet ein Profil je Auto (vom Heck `car.z` zur `camera_z`, alle Rückleuchten des Autos teilen
  es), die Laternen eines je Lampe von der Straßenstelle, an der ihre Höhe gemessen wird (`_drop_of()` merkt sich sie).
  Hinter einer Kuppe verdeckt die Straße den Streifen wie bisher (Tiefentest).

### 15.5 Schnee am Boden und auf den Dingen

- **Schneewälle** (`builders/terrain.gd`, `_snow_banks`): auf einer Schnee-Etappe liegt der geräumte Schnee als
  niedriger Wall an der Außenkante der Bankette – Teil des Geländenetzes, gleiches Material, also nach dem Bodengesetz
  so hell wie der Schneeboden; der Fuß auf dem Bankett ist schmutzig grau (die Pflugkante zeichnet den Wall gegen das
  Weiß). Höhe 0,3 m mit langsamer Schwankung, **höchstens 0,45 m** (`BANK_MAX_M`) – wie die Bodendecker der
  Kurvenkorridore (A-3, 0,5 m) kann er nie ein Auto vor dem Auge in 3,4 m verdecken; das Geländeprofil der
  Fairness-Prüfungen bleibt unberührt. Nicht auf Brücken, in Tunneln, in den City Limits und neben einer Tankspur; wo er
  endet, läuft er über drei Segmente aus. Etwa 380 Dreiecke je Stück.
- **Schnee auf den Dingen**: nach oben weisende Flächen tragen Schnee – Dächer und Simse (`baked`), die Kronen der
  Bäume (`leaves`), Leitplankenholme, Masten, Laternen (`vpbr` statischer Modelle: `ModernMaterials.static_code()` setzt
  dort `snow_cover` 1, Fahrzeuge behalten 0). Nachts um 30 % dunkler (`snow_night`), damit Dächer und Kronen nicht über
  dem Schneeboden leuchten. Fernbilder und Ersatzbilder tönen wie Arcade 15 % zu `#bfccd6`.

### 15.6 Belichtungsrampe an der Tunnelausfahrt

Arcade lässt das Draußen überstrahlt wirken, solange die Kamera im Tunnel ist (Umgebungslicht × 1,7 + 0,25, Nebel 55 %
zu Weiß). Modern: ein Viereck über dem Ausfahrtsportal (`environment_rig.gd`, `_update_exit`), tiefengetestet – die
Röhre verdeckt es außerhalb der Öffnung –, überbelichtet alles, was durch die Öffnung zu sehen ist: Stärke 0,6
solange die Ausfahrt fern ist, 0,45 direkt am Portal (die Augen sind noch auf die Röhre eingestellt – wie bei Arcade
bleibt das Draußen hell, solange die Kamera drinnen ist; `exit_glare()`); danach ist das ganze Bild 60 m lang
überstrahlt (0,4 am Portal, in rund 1,5 s bei 140 km/h abklingend; `exit_after()`, Canvas-Ebene 1) – **und höchstens
`EXIT_AFTER_S` (2 s) lang** (FIX-R4, Befund B6 von QA-R4: ein Auto, das im Stau, nach einem Unfall oder bei einer
Polizeikontrolle kurz hinter der Ausfahrt stand, blieb sonst dauernd überbelichtet). `exit_after_timed(d, dt)`: es
klingt mit dem ab, was weiter fortgeschritten ist – Weg (`d` / 60 m) oder Zeit seit dem Portal (`dt` / 2 s, nach
`view.time`, also bestimmt mit `--gfx-sync`); über 108 km/h entscheidet der Weg (der Look von R4 bleibt), darunter
die Zeit. Die Zeit, zu der die Kamera das Portal passierte, schätzt das Rig aus dem Weg hinter der Ausfahrt und dem
Tempo – eine Etappe, die hinter einer Ausfahrt beginnt, zeigt kein Nachglühen. Die ersten
Bilder mit 12 % am Portal und 22 % danach zeigten eine fast normale Ausfahrt – schwächer als Arcade.
**Belichtungsgesetz** (beide Stellen, `GLARE_LAW`): das Viereck und die Canvas-Ebene lesen, was hinter ihnen liegt
(Bildschirmtextur – eine Kopie des Bildes, nur solange sie zu sehen sind), und zeigen es nach Arcades Gesetz für das
Draußen: Anzeigewert × (1 + 0,7 s) + 0,25 s (`EXIT_GAIN`, `EXIT_LIFT`; s = Stärke / 0,6, also bei fernem Portal
genau Arcades × 1,7 + 0,25), die hellsten Teile brennen zu `EXIT_GLARE_COLOR` aus. Die erste Fassung mischte zu Weiß –
das las sich milchig, ein blasser Schleier über graugrünem Gras, wo Arcade helles, sattes Grün zeigt. Gemessen
(Teststrecke km 52,8, 12 Uhr, „Hoch“, Kamera am Portal, Bereich über den Autos): Leuchtdichte Arcade 0,600, Modern
vorher 0,638, jetzt 0,717; mittlere Sättigung Arcade 0,43, Modern vorher 0,20, jetzt 0,26 (Moderns Tagesgras ist
grundsätzlich weniger grell als Arcades Palette). Ist das
Spielerauto schon draußen, die Kamera aber noch drin, steht das Viereck 1,5 m vor seiner Front (`EXIT_CAR_GAP_M`):
das Draußen dahinter ist überstrahlt, das Auto nicht verschleiert – wie Arcades Sprite (das Portal rahmt das Viereck
von innen weiter ein). Nur bei Tag (Leuchtdichte des Umgebungslichts 0,35 … 0,75), nur mit einem Tunnel-Builder
(seine Röhre muss das Viereck verdecken), eine Funktion der Kameraposition und der Spielzeit `view.time` – keine
Wanduhr. Das Viereck wird als **erstes** aller durchsichtigen Dinge gezeichnet (`render_priority` −128, FIX-R4, Befund
B8): es ersetzt, was hinter ihm liegt, durch die überstrahlte Kopie des undurchsichtigen Bildes; nach der Tiefe sortiert
konnte es nach einem Brems- oder Blinklicht jenseits des Portals gezeichnet werden und es löschen (F6). Lichtpunkte,
Regen und Glas kommen jetzt danach. Das Viereck steht in den
Aufwärm-Knoten des Rigs; die Canvas-Ebene wird beim Aufwärmen zwölf Aktualisierungen lang mit Stärke 0 (Identität)
gezeichnet, damit ihr Programm hinter dem Ladebild übersetzt wird.

### 15.7 Nacht

- **Mond von oben** (Nachtgesetz für senkrechte Flächen, Entscheidung 8 der Leitung): das Mondlicht fällt aus
  mindestens 55° (`MOON_MIN_ELEV_DEG`). Ein tiefer Mond beleuchtete Wände, die ihm zugewandt sind, viel stärker als
  ebenen Boden (um 22 Uhr 1,7-fach) – das Lichtgesetz ist für ebenen Boden gemacht; M2ZS1 maß den hellen Pylon der
  Köhlbrandbrücke 40 % über Arcade. Ab 55° bekommt eine senkrechte Fläche höchstens 0,7 × das Mondlicht des Bodens: jede
  helle Wand, jedes Brückenteil, jede Karosserie bleibt beim Anteil des Bodens. Der Mond am Himmel bleibt, wo die
  Palette ihn zeichnet. `night_albedo` von `baked.gdshader` bleibt die Stellschraube je Material (Pylon 0,45 –
  nachgemessen mit dem Mondgesetz an der Köhlbrandbrücke km 78,1, 22 Uhr, „Hoch“, Bereich x 500–780, y 150–350:
  Arcade 59,7, Modern 55,4 von 255, also weiter höchstens so hell wie Arcade; das Mondgesetz allein hätte den Wert
  nicht gebraucht, die Laternen an den Seilen bei km 79,7 schon).
- **Nacht-Füll-Licht des Spielerautos** (Kunstkritik KRITIK-2 A2: „die Karosserie bleibt nachts fast schwarz“):
  das Füll-Licht (`fill` 0,7 des Umgebungslichts, nur das Spielerauto) bleibt nachts bei 0,6 seines Tagesanteils
  (`fill_night`, vorher 0,3) und zeigt sich zusätzlich als gleichmäßiger Schimmer auf dem Klarlack
  (`fill_sheen` 0,25 × `ce_night`) – so hält Arcades Sprite mit seinem
  Studioglanz auch einen dunklen Lack lesbar. Ein stärkeres diffuses Füll-Licht allein hebt den dunklen Metallic-Lack
  der Limousine am wenigsten (bei 2,0: Limousine 0,51 ×, Kompakt schon 1,13 × Arcade), der neutrale Schimmer am
  meisten. Gemessen mit `check_night spielerauto` (75. Perzentil der Leuchtdichte der Karosserie gegen Arcades Bild,
  22 Uhr): vorher Kompakt 0,80 ×, Gran Turismo 0,55 ×, Limousine 0,35 ×; mit dem neutralen Schimmer Kompakt 1,06 ×,
  Gran Turismo 0,92 ×, Limousine 0,94 ×. Der neutrale Schimmer machte die Lacke aber blasser als Arcades Sprites (der
  bernsteinfarbene Kompakt cremefarben, der blaugraue GT neutral grau; mittlere Sättigung der Karosserie 0,74 × /
  0,70 × / 0,91 × des Sprites). Darum trägt der Schimmer jetzt zu 80 % die Farbe des Lacks im Licht der Umgebung
  (`fill_sheen_tint` 0,8, Arcades Gesetz Sprite × Umgebungsfarbe, bei gleicher Leuchtdichte): Sättigung **0,95 × /
  0,73 × / 0,91 ×**, Helligkeit 1,04 × / 0,93 × / 0,86 × (`check_night spielerauto` prüft jetzt beides: Helligkeit
  0,6 … 1,1 ×, Sättigung ≥ 0,7 × – der silberne GT verdankt seine Sättigung bei Arcade nur dem blauen Nachtton).
  Bei Tag ändert sich nichts (alles wirkt mit `ce_night`).
  **FIX-R4** (Befunde B3/B7 von QA-R4): der Schimmer nimmt den Ton aus dem um 35 % zur eigenen Leuchtdichte
  gewaschenen Lack (`sheen_wash` 0,35 – das Studiolicht der Sprites wäscht den Lack, FIX-M2 B-06 hat es bei Tag
  gemessen); mit dem vollen Ton des Modells las sich die dunkelblaue Limousine um 21 Uhr königsblau (QA-R4: Sättigung
  1,38 × ihres Sprites). Und nachts nimmt der Himmel, den Lack, Metall und Glas spiegeln, 80 % des Tons des
  Umgebungslichts bei seiner eigenen Leuchtdichte an (`layers/vehicles.gd` `ENV_NIGHT_TINT`, `night_tint()` – Arcades
  Gesetz Sprite × Umgebungsfarbe; der Regen verdeckt den Nachthimmel mit grauen Wolken). Gemessen mit
  `check_night spielerauto` (jetzt mit der Limousine auf der Teststrecke um 21 Uhr und einer Obergrenze der Sättigung
  1,25 ×): Kompakt 1,05 × / Sättigung 1,23 ×, Gran Turismo 0,92 × / 0,77 × (vorher 0,73 ×), Limousine S1 0,88 × /
  0,95 ×, Limousine DEV 21 Uhr 0,87 × / 1,00 ×. **Offen**: der silberne Gran Turismo liest sich nachts im Regen weiter
  hellgrau-neutral statt blaugrau – auch mit dem vollen Himmelston (1,0) nur 0,78 ×; der neutrale Anteil kommt also
  nicht aus dem gespiegelten Himmel (Lack `#b2b7bd`, Metall 0,9 – vermutlich das direkte Mondlicht auf dem Metall,
  `light()`), Sache von FIX-M2 B-06 / R7.
- **Blaulicht**: ein Polizeiauto mit Blaulicht (Ansicht `beacon` „a“/„b“) bis 160 m vor der Kamera bekommt nachts
  einen Punktlicht aus dem Pool (es hat Vorrang vor der fernsten Lampe, der Deckel bleibt 8) und einen blauen
  Lichtkegel auf dem Boden, beide im Takt der Phase (1,0 / 0,6). Bei Tag nichts.
- **Deckel**: höchstens 8 Punktlichter und 2 Spots, keines mit Schatten, genau ein gerichtetes Licht – geprüft auf drei
  Nachtetappen (`tests/race3d/check_light_cap.gd`).

### 15.8 Tag: Sonnenscheibe

`EnvironmentRig.sky_palette()` gibt die Palette unverändert an den Hintergrund: die Sonnenscheibe steht, wo Arcade sie
zeichnet – mittags vorn und hoch –, auch wenn das Licht der hohen Sonne von hinten links kommt (sonst läge alles, was
die Verfolgerkamera sieht, im Gegenlicht). Das ist Arcades eigene Abmachung: sein Panorama zeigt die Sonne vorn, seine
Sprites sind von hinten links beleuchtet. Bei tiefer Sonne (Morgen, Abend) wird nicht geschwenkt: dort stimmen Scheibe,
Horizontglühen, Licht und Schatten genau überein.

### 15.9 Prüfungen

| Prüfung | Inhalt |
|---|---|
| `tests/unit/race3d/test_environment_rig.gd` → `test_set_zone`, `test_night_moon_and_floor`, `test_where_the_sun_stands` | Zonen (Tunnel, Brücke, fremde Art, Grenzen), Mond ≥ 55° zu jeder Nachtstunde, Sonnenscheibe an Arcades Stelle |
| `tests/unit/race3d/test_light_pool.gd` | Lichtdeckel je „Effekte“ (2 / 4 / 8 Punktlichter, ≤ 2 Spots, keine Schatten, der Boden ausgelassen), Gesetz der Lichtkegel, Mitte eines Kegels, Abblendlicht am Boden und in der Luft (`beam_at`), Blaulicht (`beacon_of`) |
| `tests/unit/race3d/test_weather.gd` | Wetterarten und Stufen, jede „Effekte“-Stufe mindestens mit Arcades Teilchendichte, Gischtwolken (eine bei „Aus“, drei sonst, Lkw größer, schneller weiter hinten), Länge der Lampenspiegelung; FIX-R4: Höhenprofil der Spiegelung auf einer Steigung und seine Lage in der Instanz, Band mit Abschnitten (`test_streak_follows_the_road_profile`), Schneewall im gebauten Netz ≤ 0,45 m (`test_snow_bank_mesh_height`), Niederschlag folgt dem Wächter (`test_weather_follows_the_watchdog`) |
| `tests/race3d/check_light_cap.gd` (kopflos, im Haken von `tools/run_tests.sh`) | `deckel`: N1, Kiel – Hamburg ab km 76 um 22:30 und C1 um 21:30 im Regen, „Hoch“: in jeder Probe ≤ 8 sichtbare Punktlichter, ≤ 2 Spots, keines mit Schatten, genau ein gerichtetes Licht mit Schatten, der Schnappschuss stimmt; Lampen-Pool und Abblendlicht benutzt |
| `tests/race3d/render/check_weather.gd` | `teilchen` (Regen und Schnee je Stufe „Niedrig“ / „Steam Deck“ / „Hoch“: Bildpunkte, mehr je Stufe, zweimal dasselbe Bild), `gischt`, `nass` (Spiegelung der Rückleuchten nachts, Fresnel bei Tag), `tunnel`, `schneewall` (FIX-R4: auch der höchste Wallpunkt im gebauten Netz, `bank_max_m` aus `TerrainBuilder.debug()`) |
| `tests/race3d/render/check_weather_tabelle.gd`, `check_weather_tabelle_schnee.gd` | `tabelle` (Wetter klar/Regen bzw. Schnee × Stunde 6:36/12/19:12/22 Uhr, S1 „Mittel“: mittlere Leuchtdichte des Bodens 0,8 … 1,35 × Arcade, Kontrast ≥ 0,5 × Arcade, kein schwarzes Bild) – eigene Dateien: alle 24 Etappenstarts brauchten bei Last 20 933 s, mehr als die 900 s je Datei von `tools/run_render_checks.sh`. Gemessen (R4): Helligkeit 0,90 … 1,01 ×, Kontrast 0,74 … 1,17 × |
| `tests/race3d/render/check_night.gd` | `fahrbahn` (N1: mittlere Leuchtdichte der Fahrbahn 0 … +15 % gegen Arcade, „Mittel“ und „Steam Deck“), `spielerauto` (Kompakt/N1 Schnee, Gran Turismo/Regen, Limousine/klar, 22 Uhr: Karosserie 0,6 … 1,1 × Arcades Bild), `verdeckung` (nasse Nacht: Auto hinter Kuppe und hinter Sattelzug ändert 0 Pixel, auch keine Spiegelung), `blaulicht` (Polizei 34 m voraus: nachts ≥ 400 blauere Pixel und ein Punktlicht, bei Tag keines) |
| `tests/race3d/render/check_night_nass.gd` (FIX-R4, eigene Datei von `check_night.gd`) | `nass_kegel` (N2 22 Uhr Regen, „Mittel“: Median der eigenen Spur im Abblendlicht 16–34 m vor der Kamera 0,7 … 1,15 × Arcade, Weber-Kontrast der Markierung dort ≥ 0,8 × Arcade – Befund B2), `spiegelung` (nasse Nacht, bremsendes Auto auf der Steigung vor der Kuppe T2, ≥ 3 m über dem Kamerafuß: kein Bildpunkt der Spiegelungen über seinem Dach, ihre Spiegelung liegt darunter auf der Straße – Befund B1) |
| `tests/unit/race3d/test_environment_rig.gd` → `test_exit_ramp` (FIX-R4) | Nachglühen stetig (kein Sprung bei 60 m, < 0,02 bei 59,5 m) und höchstens `EXIT_AFTER_S` lang; über 108 km/h entscheidet der Weg |

## 16. Tunnel, Brücken, Wasser und Ufer (Bauabschnitt R5)

R5 ersetzt die Mindestbauten von FIX1 (14.3, 14.7) durch die echten Bauten; Einzelheiten:
[renderer-modern-tunnel-bruecken.md](renderer-modern-tunnel-bruecken.md). Neu: `builders/bridge.gd` (Wasser, Ufer,
Tragwerk, Pylone mit Seilen und Flugbefeuerung, Fachwerkportale, Brückenlampen – `builders/props.gd` lässt diese Teile
liegen, sobald der Builder existiert), `assets/shaders/modern/water.gdshader` (Materialklasse `water`), der Ausbau von
`builders/tunnel.gd` und `tunnel.gdshader` (Gehwege, Nischen, Notausgänge, Lüfter, Portalrahmen, Ausfahrt) und in
`layers/far_ground.gd` Fernwasser, Fernland und Fernufer je Brücke; die Scheibe bleibt bei der Regel von 14.7.

### 16.1 Zone „Tunnel“ für die Umgebung (`set_zone`)

Der Tunnel-Builder ist die Quelle der Tunnelzone; das Umgebungs-Rig (R4) entscheidet, was es daraus macht. Aufrufe:
- **Jedes Bild** in `tunnel.gd` `update(view, dt)` (nach `environment.update`, in der Reihenfolge der Builder-Haken):
  `amount = TunnelBuilder.zone_amount(track, camera_z + 1)` – dasselbe Gesetz wie `EnvironmentRig.tunnel_blend()`
  (0 ab 12 m vor einem Portal, 1 ab 14 m drin, Glättung `smoothstep`, eine Funktion des Orts).
- **`renderer.env.set_zone("tunnel", amount)`** nur, wenn `renderer.env` die Methode hat (`has_method("set_zone")`,
  duck-typed) und nur, wenn sich `amount` um mehr als 0,0001 geändert hat (erster Aufruf immer). Ohne `set_zone` bleibt
  das Rig bei seinem eigenen Weg (`tunnel01` aus `tunnel_blend`), es ändert sich nichts.
- **`tunnel_state`** (Eigenschaft des Builders, über `renderer.builder("tunnel")`): `amount`, `inside` (Kamera in einem
  Tunnel), `exit_m` (Weg bis zur Ausfahrt, INF draußen), `portal_m` (Weg bis zum nächsten Portal voraus),
  `exit_in_sight` (Ausfahrt innerhalb der Sicht) – für eine Belichtungsrampe an der Ausfahrt, ohne eigene Rechnung;
  `exit_z` (FIX-R5) = Straßen-z, an dem die Röhre wirklich endet (Segmentgrenze nach `end_km`, wie Arcades
  Tunnelsegmente; INF draußen) – der Rahmen der Ausfahrt steht von `exit_z` − 0,35 m bis `exit_z`; eine Belichtungsfläche
  an der Öffnung gehört dorthin, nicht an `end_km` (das bis zu ein Segment früher liegt);
  `light` (FIX-R5) = das Licht der Röhre in diesem Bild, wie es `tunnel.gdshader` bekommt: `ambient_in`, `ambient_out`
  (Anzeigefaktoren der Tunnelumgebung für eine Kamera drinnen / draußen, Arcades × (0,5 + 0,5 × Lichter)), `fog`
  (`Palette.TUNNEL_FOG`), `darkness_m`, `peek_m`, `cam_tunnel_z` (Portal-z des Tunnels der Kamera, −1e9 draußen),
  `lights` – damit die Fahrbahn in der Röhre (R4) von außen Arcades warmes Tunnellicht zeigen kann (Befund QR5-02).
- `snapshot()` → `"tunnel": {"zone", "zone_calls", "inside"}` im `debug_snapshot()` des Renderers.

### 16.2 Portal im Licht

Auch das **Tunnelportal** (Rahmen, Stirnwand, Flügelmauern, Hügel) liegt auf Ebene 2 (FIX-R5, `tunnel.gd`
`PORTAL_LAYERS`): kein Spot des Abblendlichts und kein Lampen-Omni erreicht es, wie Arcade sein Portal nie mit den
Scheinwerfern beleuchtet – ohne Abblendkante strahlte der 30°-Kegel nachts die Stirnwand aus 60–70 m bis oben an. Es
bleibt im Licht von Sonne, Mond und Umgebung und wirft seinen Schatten.

### 16.3 Wasser im Licht

Das Wasser ist Boden (Ebene 2, kein Schatten): Lichtkegel analytisch (`inc/pools.gdshaderinc`, das Material meldet
sich über `renderer.add_pool_material()` an), Scheinwerfer (`inc/headlight.gdshaderinc`), Arcades Bodenfarbgesetz
(`inc/ground_law.gdshaderinc`), Arcades Nebel für Boden. Der Himmel, den es spiegelt, kommt jedes Bild aus der
Palette (`sky_top` für den Zenit, `sky_bottom` für den Horizont), das Glitzern aus Sonne (1, solange `lights` < 0,3)
bzw. Mond (0,25), × (1 − Bewölkung).

## 17. Montage RINT-M2 (FIX-M2, R4, R5, R6, AS5aR1)

Die zweite Montage des Schubs M2 führt FIX-M2 (§14.10) mit den Bauabschnitten R4 (§15), R5 (§16), R6
(renderer-modern-bauten.md) und der Nacharbeit AS5aR1 der Stadtgebäude (docs/modelle.md) zusammen und setzt die
Entscheidungen der Leitung aus Vertrag §11.3 (A-18 bis A-22) um. Was sich dabei am Renderer änderte:

### 17.1 Abblendlicht: Glanz bleibt, Fahrzeuge dämpfen ihn im Material (A-20)

`layers/lights.gd` `SPOT_SPECULAR` ist wieder 0,5 (wie die Lampen-Omnis). Die Glanzkeulen eines Punkt- oder
Spotlichts, das von neben dem Auge kommt, nehmen `vpbr` und `glass` selbst heraus: `eye_lamp_spec` (Renn-Look der
Fahrzeuge 0, Studio und Kontaktbogen 1) über den Winkel zwischen Licht- und Blickrichtung (`eye_lamp_cos` 0,85 … 0,95:
volle Keulen unter x, keine über y; das Abblendlicht liegt ab etwa 18 m vor der Kamera innerhalb y, eine Laterne über
der Straße weit außerhalb). Gemessen, roter Lkw im Abblendlicht, 22 Uhr (Sonde, mittlere Leuchtdichte Arcade / neu):
20 m 57,0 / 63,0 (+10 %), 60 m 44,1 / 44,1; Mutation `eye_lamp_spec` 1 → 60 m 171,5 (48 % weiß).
Die Fahrbahn nahm dieses Licht nie (Ebene 2): die nasse Fahrbahn N2 22 Uhr ist mit `SPOT_SPECULAR` 0 und 0,5
pixelgleich – ihr Glanz kommt aus `inc/headlight.gdshaderinc` und `road.gdshader` (§15.4).

### 17.2 Bremsschein nach Tageslicht und Abstand (A-20)

`VehiclePose3D.model_glow_gain(role, a, lights, dist_m)`: der Zuschlag `MODEL_BRAKE_GAIN` 2,2 der Modell-Bremsleuchten
gilt bei Tag; nachts fällt er mit den Lichtern der Palette auf einen Anteil, der vom Abstand des Autos zur Kamera
abhängt (`brake_night_share`: 0,6 bis 22 m, 0,15 ab 60 m, dazwischen `smoothstep`). Ein Anteil für alle Abstände ging
nicht (0,35: Sportwagen 60 m +22 %, Limousine 20 m −32 %; 0,15: −1 % / −46 %). Das Blaulicht behält seinen Zuschlag
(nachts ohnehin etwa halb so viel Blau wie Arcade). Sonde 22 Uhr, rote Pixel Arcade / neu: Sportwagen 60 m 95 / 94,
Limousine 20 m 539 / 476, Sportwagen 20 m 567 / 454. Prüfung `check_vehicle_lights` „bremsschein“ (17.10).

### 17.3 Tönung der Platzierung auch für Modelle (A-19)

`builders/props.gd` legt jeder Instanz die Tönung der Platzierung bei (`tint` × `fallback_tint`, sonst Weiß);
`baked`, `vpbr` (statisch), `leaves` und `billboard` multiplizieren die Albedo damit wie Arcade das Sprite, Lampen
behalten ihre Farbe. Keine Instanz-Uniform. **Jedes MultiMesh der Requisiten trägt Farbe UND Custom-Daten**
(`INSTANCE_FLOATS` = 20: Transformation, Farbe, Custom): ein Modell Weiß als Farbe (`MODEL_COLOR`) und die Tönung als
Custom-Daten (r, g, b, 1), eine Vertretung die Tönung als Farbe und `NO_CUSTOM` (a = 0). Grund, mit Sonden gemessen
(Godot 4.7.2, Compatibility, llvmpipe): `INSTANCE_CUSTOM` liest bei Farbe ohne Custom-Daten (0, 1, 0, 1) und bei
Custom-Daten ohne Farbe, über `MultiMesh.buffer` gesetzt, Müll auf den echten Modellnetzen (über
`set_instance_custom_data()` richtig, aber je Instanz zu teuer) – der erste Stand dieser Montage zeigte leuchtend grüne
Fensterrahmen, Garagentore, Bäume und Windräder. Ohne Instanzdaten liest es (0, 0, 0, 0), ein `MeshInstance3D` 0:
a < 0,5 lässt die Albedo, wie sie ist (Fahrzeuge, `builders/city.gd`). Wer neue MultiMeshes mit diesen Shadern baut,
gibt ihnen beides oder keins.

### 17.4 Instanzbudget unter Last (A-19)

`check_instance_budget.gd` kann Verkehr einspeisen (`_inject_n()`, Testautos über
`tests/race3d/fixtures/vehicle_probe_renderer.gd`, Abstände wandern 20–540 m, jedes Auto durchläuft jede Stufe); dann
muss die Fahrzeug-Ebene 90 % ihres `INSTANCE_BUDGET` erreichen („nicht belastet“ sonst FEHLER). 48 gezeigte Autos
brauchen mehr Stufen, als das Budget fasst – die Ebene gibt nur Pool-Autos und verborgene Stufen frei –, darum gelten
mit eingespeistem Verkehr die Grenze der ganzen Szene (230) und die Ablehnung der Engine, und die Szene wird alle 10
Bilder gezählt. `instanzen_wald`: Dortmund – Frankfurt ab km 40, „Hoch“, 48 Autos, 20 s Sicht (Kopfzeit 2400 s);
neu `instanzen_stadt`: Würzburg – Nürnberg ab km 106 in die Stadt; `instanzen`: Kiel – Hamburg (100 s, ohne
Einspeisung). Gemessen bei „Hoch“ (ganze Szene höchstens / Fahrzeug-Ebene höchstens): Kiel – Hamburg 141 / 128, Wald
216 / 208, Stadt 171 / 176 – alle unter 230, keine Ablehnung. Der Wald mit 48 Autos liegt 14 Instanzen unter der
Grenze: mehr gleichzeitig gezeigte Autos als dort verträgt die Szene nicht.

### 17.5 Tankstellendach ohne Stütze, Entscheid auf einem Arbeitsfaden (A-18)

An den drei Dächern, deren Stützen alle wegfielen (prag_leipzig km 148,08, sibiu_timisoara km 148,98, prag_nuernberg
km 233,13), stand eine Notstütze auf der Insel, die Arcade nicht hat. Jetzt hängt das Dach an einem Mast
(`station.gd`, Arten „mast“ / „mast_l“): zuerst rechts jenseits der Tafeln (Balken unter der Dachkante, Zugstangen über
dem Dach), sonst links jenseits des Seitenstreifens mit Zugstangen 7–9 m über den Spuren; an allen drei Dächern links.
`scan_f1` über das ganze Netz: Paare an Tankstellen-Endstützen 38 → 3, keines ≥ 6 px.
`ChunkStreamer.stats()` → `collect_by` misst die Hauptfadenzeit von `collect()` je Baustein. Gemessen (DEV, „Steam
Deck“, llvmpipe unter Last): Tankstelle bis 3,4 ms in einem Bild, über dem Budget von 2 ms. Der Entscheid der Stützen
läuft darum als `StationBuilder.CanopyJob`:
- Der Hauptfaden sammelt nur, was er aus der Strecke liest, in zwei Hälften (`canopy_job_begin()`: Schilder, Tafeln,
  Krümmungen; `canopy_job_rest()`: Spuren an jeder Kamerastelle, Fahrbahnkanten), für die Dächer bis `WARM_AHEAD_M`
  (1200 m) voraus. Die Dächer einer Station teilen Schilder, Krümmungen und Kamerastellen über den Cache des Bausteins
  („_signs“, „_curve“, „_lanes“). Mit kalten Caches kostete das erste Dach einer Station zwei Hälften zu je 1,1–1,5 ms
  (2,4 ms in einem `collect()`); darum erzeugt `warm_step()` vor der ersten Hälfte die Strecke so weit, wie
  `signs_behind()` sie braucht (`WARM_GEN_SEGS` = 6 Segmente je Stück, Fortschritt im Cache „_gen“), und füllt die Caches
  der Schilder und Kamerastellen – Stück für Stück, bis der Aufruf `WARM_BUDGET_MS` (1,0 ms) gebraucht hat, mindestens
  ein Stück je Aufruf. Eine Hälfte beginnt nur innerhalb dieser Zeit. Die Werte sind dieselben, die die Hälften selbst
  rechnen (Unit-Test `test_station_warm_step_prepares_what_the_halves_read`). Weil die Strecke nur noch in Stücken
  erzeugt wird, darf der Vorlauf 1200 m sein; so bleiben genug Aufrufe, bis das Stück eines Dachs gebraucht wird.
- Die Sichtlinien rechnet ein Arbeitsfaden (`run()`), auf einem eigenen Pfad ab dem ersten Segment, das er braucht –
  deckungsgleich mit dem des Streamers, also unabhängig vom Startort (`startdep`: 1909 Dächer, 0 abweichende Entscheide;
  vorher 43).
- Die Korridor-Merker der Stellen (TerrainProfile) liest `CanopyJob.finish()` auf dem Hauptfaden erst, wenn die Stützen
  des Dachs gebraucht werden (beim Stück des Dachs gibt es diese Zeilen ohnehin).
- Verworfen (gemessen): 2000 m Vorlauf ohne `warm_step()` – das Sammeln ließ die Strecke 1,4 km auf einmal erzeugen
  (18 ms in einem Bild); Korridor-Merker beim Sammeln – das Geländeprofil rechnete seine Zeilen 600 m voraus (bis
  17 ms); `warm_step()` mit 600 m Vorlauf und 0,7 ms je Aufruf – ein Dach war beim Stück noch nicht fertig (8,7 ms).
- Entscheide unverändert: `scan_f1` netzweit zeilengleich (3486 Stützen), Sonde `jobpath` (Streaming-Reihenfolge mit
  Arbeitsfaden und Cache gegen inline) 1909 Dächer, 0 verschieden. `collect()` der Tankstelle auf der Testetappe:
  vorher bis 3,4 ms (inline) bzw. 8,0 ms (erster Arbeitsfaden-Stand), 2,4 ms mit kalten Caches, mit `warm_step()` und
  600 m Vorlauf 2,08 ms, mit 1200 m **höchstens 1,36 ms, Mittel 0,11 ms**; alle neun Dächer beim Stück fertig (der
  Rest dort 0,02–0,18 ms), keines inline (§17.10). Ein Lauf auf einer VM neben einem zweiten Paket: Höchstwerte
  streuen dort stark (Requisiten in vier Läufen 0,12–4,19 ms ohne Änderung), Mittel sind belastbar.

### 17.6 Lichtebenen (A-18)

- `layers/lights.gd` liest die Stärke statischer Lampen jedes Bild aus dem Eintrag des Bausteins (`entry_energy`).
- `layers/flares.gd`: Lampen mit Stärke 0 kosten keine Instanz; optionale Schlüssel `"halo"` (Nahanteil statt
  `STATIC_HALO`) und `"glow": false` (kein Laternenschein). Das Straßenprofil der Spiegelung einer Laterne wird je Lampe
  gehalten, solange die Kamera sich weniger als 3 m bewegt (`PROFILE_KEEP_M`); `snapshot()` meldet
  `lamp_streak_profiles`, `lamp_streak_profile_max_m`, `lamp_streak_profiles_computed`.
- `builders/radar.gd`: der Blitz nutzt `halo` 1 statt des Ausgleichs in `FLASH_GAIN` (gleiches Bild) und wirft nachts
  einen Lichtkegel von 9 m auf die Fahrbahn.

### 17.7 Tunnel und Brücken (A-18)

- Die Blendfläche der Ausfahrt steht am wahren Röhrenende (`tunnel_state.exit_z` − 0,05 m, sonst die Segmentgrenze
  nach `end_km`); `check_tunnel_bridge` „U1_ausfahrt“ prüft die Überstrahlung gegen Arcade (mindestens 0,6 × Arcades
  Leuchtdichte 0,89 draußen) und dass der Rahmen nicht mitglüht.
- Die Fahrbahn in der Röhre zeigt von außen Arcades Tunnellicht: `builders/road.gd` liest `tunnel_state.light` jedes
  Bild und setzt `tunnel_out`, `tunnel_ambient`, `tunnel_fog`, `tunnel_darkness_m` in `road.gdshader`.
- Steinbrücken haben Arcades Balustrade (`roadside.gd` `stone_arch`): fünf Docken je Segment (0,14 m) zwischen Sockel
  und Handlauf, ein Pfeiler alle vier Segmente.
- Hausboote und Schiffe schwimmen auf dem Wasser des Brückenbausteins (+0,15 m, `BRIDGE_WATER_LIFT`).

### 17.8 Lack der Spielerautos (Leitungsnotiz 10)

Gemessen gegen Arcade (`check_night` „spielerauto“, Sättigung neu / Arcade): Limousine S1 0,95×, Testetappe 1,00×,
Kompakt N1 (Schnee, 22 Uhr) 1,23×, Gran Turismo N2 (Regen) 0,77× (Leuchtdichte 0,92×). Die Abweichungen gehen in
beide Richtungen und hängen am Lack des Modells (Asset): keine Konstante des Renderers bringt beide in ±15 %; offen
für die Modellnacharbeit.

### 17.9 Bekannte Lücken (Stand RINT-M2)

- Lack: Kompakt nachts satter, Gran Turismo im Regen blasser als Arcade (17.8).
- Lack in der Abenddämmerung (19:30): die Limousine wirkt grau-lila statt Blau – Heck und Dach im A/B-Bild Farbton
  271–276° statt Arcades 242°, Sättigung 0,27–0,28 / 0,29, Helligkeit 0,30 / 0,37 (Hamburg Mitte, Kiel Stadtrand;
  am Tag 217° / 222°). Vermutlich spiegelt der Abendhimmel zu stark im Lack (gefolgert).
- Abblendlicht: keine Hell-Dunkel-Grenze wie Arcades Kegel (Lichtkegel weich).
- Grenzstation Amsterdam – Lüttich km 210,175: eine Endstütze verdeckt die Tafel „town_ahead“ zu 22 % (keine
  Spieltafel nach A-18, gemeldet).
- `collect()` je Baustein auf „Deck“ nur in einzelnen Läufen auf der belasteten VM gemessen (Tankstelle 1,36 ms,
  Höchstwerte anderer Bausteine streuen bis 4,19 ms) – auf dem Gerät nicht gemessen.
- Geländewasser unter Brücken (FIX-R5 8.6) und Mondlichtstreifen am Portalhügel (NACH-R5 N-01) offen.
- Kurveninnenseiten in Bergetappen: Sichtkorridor nach A-17 mit R7a (5.3); was in Stadtkurven fehlt, bleibt (L = 300 m).
- Lackflackern des weißen Autos (Testbuild 1): pausiert (A-21).

### 17.10 Prüfungen


Neu oder geändert in dieser Montage (gemessen am Stand `b673df5`, Preset „Hoch“, llvmpipe):

| Prüfung | Datei | Was | Gemessen | Gegenprobe |
|---|---|---|---|---|
| `bremsschein` | `render/check_vehicle_lights.gd` | Rot, das die Bremse eines Modells hinzufügt: Sportwagen 60 m 12 Uhr ≥ 29, 22 Uhr ≤ 57; Limousine 20 m 22 Uhr ≤ 500 | 33,1 / 28,3 / 436,1 | Verstärkung 1,0: Tag 25,0 → FEHLER; volle Tagesverstärkung nachts 68,9 → FEHLER |
| `instanzen`, `instanzen_wald`, `instanzen_stadt` | `render/check_instance_budget*.gd` | ganze Szene ≤ `SCENE_LIMIT` (230) Instanzen mit Instanz-Uniforms, keine Ablehnung der Engine; Wald und Stadt mit 48 eingespeisten Autos (Fahrzeug-Ebene ≥ 90 % ihres Budgets, sonst „nicht belastet“) | 141 / 216 / 171 | Wald ohne `VPBR_STATIC`: 306, 144 Ablehnungen → FEHLER |
| `laternen` | `render/check_night.gd` (Lauf: `check_night_nass.gd`) | Spiegelstreifen von vier Laternen an einer Steigung (Kassel – Würzburg km 61,6): Profilhöhe ≥ 0,3 m, Profile zwischengespeichert | Profil bis 15,84 m, 4 von 160 gerechnet | flaches Profil → FEHLER |
| `tunnel_bridge_U1_ausfahrt` | `render/check_tunnel_bridge.gd` | Ausfahrt mindestens 0,6 × Arcades Leuchtdichte (0,89), Rahmen höchstens 0,8 | 0,584 = 0,66 ×, Rahmen 0,501 | – |
| `props_spiegel` | `render/check_props_render.gd` | erwartet das Einfamilienhaus (seit AS5a ein Modell) in der Modellgruppe statt als Ersatzbild | Abweichung vom Spiegelbild 0,09 | – |
| `test_model_instances_carry_the_placement_tint` | `unit/race3d/test_props.gd` | Pufferlayout 20 Werte je Instanz, jedes MultiMesh mit Farbe und Custom-Daten, Shadercode der Tönung | – | – |
| `test_station_canopy_without_column_hangs_from_a_mast` | `unit/race3d/test_structures.gd` | Dach ohne Stütze (Prag – Leipzig km 148,08) hängt an genau einem Mast außerhalb des Sichtkorridors, der keine Tafel verdeckt | – | – |
| `test_station_warm_step_prepares_what_the_halves_read` | `unit/race3d/test_structures.gd` | `warm_step()` in Stücken (eines je Aufruf), danach derselbe Entscheid wie mit kalten Caches auf einer zweiten Strecke | – | – |
| `test_static_lamp_energy_is_read_every_frame` | `unit/race3d/test_light_pool.gd` | Stärke statischer Lampen je Bild aus dem Eintrag | – | – |
| Bremsschein nah/fern/Tag | `unit/race3d/test_vehicles.gd` | `model_glow_gain()` nach Tageslicht und Abstand, stetig | – | – |

Zusätzlich gemessen, nicht als Prüfung im Baum: die Hauptfadenzeit von `collect()` je Baustein
(`ChunkStreamer.stats()["collect_by"]`: Mittel, Höchstwert, Aufrufe; §17.5) und die Sonde, die den Stützen-Entscheid
auf dem Arbeitsfaden über das ganze Netz gegen den inline-Entscheid stellt (1909 Dächer, 0 verschieden).

## 18. Nacharbeit FIX-RINT (nach QA-RINT-BILD und QA-RINT-SYSTEM)

### 18.1 Tunnelausfahrt bei Tag (Befund F-01)

Nach einer Ausfahrt bei Tag war das ganze Bild gut eine Sekunde lang ausgewaschen (Schnee: 65–68 % reines Weiß gegen
Arcades 0,3 %, Leitlinien kaum zu sehen – Regel 9), davor zeigte Modern drei Bilder lang eine sandbraune Landschaft
ohne Schnee. Drei Ursachen, drei Änderungen:

- **Wetter bleibt beim Wetter.** `ce_snow` und `ce_wet` folgten der Tunnelrampe der Kamera (× (1 − tunnel01)): solange
  die Kamera in der Röhre war, verlor die ganze Welt ihren Schnee. Jetzt tragen beide immer den Wert der Palette; in
  der Röhre nimmt sie niemand an (die Fahrbahn kennzeichnet ihre Tunnelsegmente, Flag 64; die Röhre hat kein Wetter,
  Fahrzeuge keinen Schnee).
- **Licht des Himmels ab dem Portal.** Die Tunnelrampe (`EnvironmentRig.tunnel_blend()`, gleiches Gesetz in
  `builders/tunnel.gd` `zone_amount()`) lief an der Ausfahrt bis 12 m hinter das Portal: die ersten 26 m Landschaft
  standen im warmen Tunnellicht. Jetzt fällt sie von 14 m vor der Ausfahrt auf 0 an der Ausfahrt – wie Arcades Palette,
  die bei Kamera + 1 m umschaltet. Blendviereck und Nachglühen entscheiden ebenfalls bei Kamera + 1 m (mit der Kamera
  selbst stand das Viereck in dem Bild, in dem Arcade schon normal zeigt, noch vor dem Auto: 59 % Weiß).
- **Nachglühen ohne Ausbrennen.** Die Canvas-Ebene nach der Ausfahrt hat ein eigenes Gesetz:
  1 − (1 − c)^(1 + 0,9 × Stärke) (`AFTER_SHADER`, `after_law()`). Schwarz bleibt Schwarz, Weiß bleibt Weiß, es ist
  monoton (Fahrbahn und Markierung behalten ihre Reihenfolge und mindestens 80 % ihres Abstands) und hebt die
  Mitteltöne; reines Weiß wird nur, was schon fast weiß war (über ≈ 0,83 am Portal). Bei Schnee entfällt es
  (`EXIT_AFTER_SNOW`): das verschneite Draußen ist schon das hellste Bild des Spiels. Das Viereck in der Öffnung behält
  Arcades Gesetz (× 1,7 + 0,25) – das ist Arcades Draußen, solange die Kamera drin ist.

Prüfung `tunnel_bridge_ausfahrt_schnee` / `_trocken` (`render/check_tunnel_bridge.gd`): Arcade und Modern derselben
Simulationsschritte, ab dem Schritt, in dem die Kamera die Ausfahrt passiert, 2 s lang jedes sechste Bild; im Bildband
25–80 % höchstens Arcades Anteil reiner Weißpixel + 5 Punkte, im Bodenband 50–80 % (Leuchtdichte ≥ 0,6, Sättigung
< 0,1) mindestens 0,5 × Arcades Schnee. Gemessen (Valík 8 Uhr Schnee 80 km/h; Gotthard 12 Uhr 100 km/h): Weiß höchstens
+0,1 / +1,0 Punkte, Schnee mindestens 0,99 × Arcade. Gegenprobe auf den Bildern des alten Stands: die braunen Bilder
0,00 Schnee gegen Arcades 0,59, das Ausbrennen 0,66 Weiß – beides wäre rot.

### 18.2 Einhängen unter Zeitbudget (Befund B-01)

§4.10 erlaubt 3 ms Einhängen je Bild; ganze Stücke brauchten in jeder Messung seit der Basis 3,8–9,0 ms. Im
Fahrbetrieb hängt `ChunkStreamer` ein Stück jetzt Baustein für Baustein ein (`COMMIT_BUDGET_MS` 2 ms je Bild, einer
mindestens, der nächste nur, wenn seine bisherige mittlere Zeit noch passt). Der Knoten des Stücks kommt erst in den
Baum, wenn alle Bausteine eingehängt sind – wie vorher während eines ganzen Einhängens; `chunk_node()` antwortet erst
dann. Laden und `--gfx-sync` (`flush()`) hängen ganze Stücke ein wie bisher. Die Lichtebenen warten auf einen
Lampen-Elternknoten, der noch nicht im Baum ist, und vergessen einen, der ihn verlassen hat oder freigegeben wurde (ein
halb eingehängtes Stück, das verworfen wird). `stats()` meldet `commit_steps` und `commit_by` (Zeit je Baustein);
`commit_ms_max` ist jetzt die Einhängezeit eines Bildes. Der Leistungstest schreibt je Szene `chunk_commit_ms_max`,
`collect_ms_max_by` und `commit_ms_max_by` – das Budget wird auf dem Gerät gemessen, nicht auf der geteilten VM.
Gemessen (Kiel – Hamburg ganz, „Steam Deck“, Xvfb, Zeitraffer 16, Last 7–11): Einhängen höchstens 3,24 ms je Bild
(QA vorher auf demselben Lauf 8,96 ms), 95 Stücke in 100 Schritten, längster einzelner Baustein `road` 2,37 ms;
Regel 3 hält (Prüfsumme der 347 Sekunden gleich v0.7.0). `stats()["update_ms_max"]` nennt die längste Zeit jedes Teils
von `update()` (Pfad, Abfall, Freigeben, Auswahl, Sammeln, Einhängen). Damit gefunden (zweiter Lauf): die Stöße des
Streamers (8–144 ms auf dieser VM, `perf_stats()["spikes"]`) lagen im **Freigeben** der Stücke hinter der Kamera
(`free` bis 141,7 ms), nicht im Einhängen. Ein solches Stück verlässt jetzt sofort den Baum (seine Lampen werden
vergessen, nichts davon wird gezeichnet) und wird Kind für Kind freigegeben, höchstens `FREE_BUDGET_MS` (1 ms) je
Bild, frühestens `TRASH_DELAY` (4) Aufrufe nachdem es den Baum verlassen hat (dritter Lauf ohne Wartezeit: ein
einzelnes Kind brauchte noch 134 ms – gefolgert: der Treiber wartet beim Löschen auf ein Bild, das das Netz noch
zeichnet); `clear()` gibt alles sofort frei. Vierter Lauf: `trash` höchstens 57 ms, aber auch der reine
GDScript-Teil `path` 49,6 ms – auf der geteilten VM (Last 12) ist ein einzelner Stoß dieser Größe nicht mehr vom
Rauschen zu trennen. Ob die Stöße auf dem Gerät weg sind, zeigt erst `spikes` des Leistungstests auf dem Deck.

**Schritte innerhalb eines Bausteins (RINT-M3, A-28).** Die kleinste Einheit des Einhängens ist jetzt ein Schritt eines
Bausteins: `ChunkBuilder.commit_steps(part)` und `commit_step(ctx, part, parent, k)` (Vorgabe: ein Schritt, der
`commit()` ruft). `road`, `roadside` und `terrain` teilen ihr Netz in `build()` (Arbeitsfaden) mit
`ChunkBuilder.split_arrays()` in Stücke gleicher Dreieckszahl, sobald es mehr als `PIECE_VERTICES` (2.000) Ecken hat
(höchstens `PIECES_MAX` 4), und hängen je Schritt ein Stück ein („Road“, „Road_2“ …, alle mit demselben Material,
dieselben Dreiecke in derselben Reihenfolge – dasselbe Bild); die Reflektoren hängen am ersten Stück. `roadside`
hängt seine Stücke dagegen als weitere **Flächen desselben Knotens** „Roadside“ ein: die Leitplanke zeichnet mit dem
gemeinsamen `vpbr`-Material, dessen Instanz-Uniforms je Geometrie-Instanz 16 Plätze des globalen Shader-Puffers
belegen – ein Knoten je Stück trieb die Waldprüfung `instanzen_wald` auf 236 > 230 Instanzen (A-19); ein Knoten je
Stück Strecke wie vor den Schritten (`test_road_builder`). Der Streamer
merkt sich Baustein und Schritt (`commit_i`, `commit_k`), schätzt einen Schritt mit der mittleren Schrittzeit des
Bausteins, `commit_by` zählt Schritte. Gemessen (Sonde `commit_cost.gd`, Xvfb, Kiel – Hamburg, Last 2): ein Einhängen von
`roadside` (≈ 2.850 Ecken) kostet im Median 0,21 ms, in zwei Stücken 0,10 ms je Schritt; `road` (≤ 900 Ecken) 0,02 ms
und `terrain` (≤ 600 Ecken) 0,07 ms bleiben ganz. Die Höchstwerte von 4–6 ms, die NACH-RINT unter Last 9–10 maß, sind
damit nicht die Arbeit der Bausteine selbst (gefolgert: Verdrängung des Fadens auf der geteilten VM). Das Vorwärmen des
Sichtkorridors zählt als eigener Teil `warm` von `update_ms_max` (vorher in „commit“, NACH-R7a NR7a-03). Ein Stück, das
beim Einhängen verworfen wird, gibt über `ModernRenderer.release_chunk()` frei, was seine Bausteine bei den Ebenen
gemeldet haben (`release_under()` von `lights` und `flares`, NACH-RINT N-01); die Glanzpunkte überspringen
freigegebene Knoten.

### 18.3 Weitere Änderungen

- **Tankstelle nachts (F-05):** `builders/station.gd` legt Arcades Lichtschicht des Tankstellen-Sprites nach: ein
  warmes Lichtvolumen unter dem Vordach des Shops (vier Leuchtscheine, `SHOP_VOLUME_*`) und die drei Schaufenster
  (`SHOP_WINDOW_*`) – Flare-Ebene, nur nachts, `"halo": 1` (keine beleuchtete Geometrie dahinter: volle Stärke auch nah
  an der Kamera). Gemessen (Kiel – Hamburg km 14,3 → Tankstelle, 21 Uhr, „Hoch“, Bildzone x 780–1280, y 250–460):
  Arcade 96,4, vorher 74,7 (0,77 ×), jetzt 91,6 (0,95 ×). Die Prüfung `tankstelle` misst um 21 Uhr zusätzlich die
  Tankstelle als Ganzes (Dächer, Vorplatz, Shop; mindestens 0,85 × Arcade).
- **Spielerautos nachts (F-06):** `ModernMaterials.VEHICLE_PLAYER_NIGHT` – je Set ein eigener Nachtanteil
  (Entsättigung, Helligkeit des Lacks, Anteil der Füllung und damit des Klarlack-Glanzes); nur der rote Sportwagen hat
  einen Eintrag (0,5 / 0,7 / 0,2): nachts im Regen vorher 1,19 × Arcades Leuchtdichte bei 1,83 × Sättigung, jetzt
  1,01 × / 1,21 ×. Die Prüfung `spielerauto` umfasst jetzt alle fünf Autos; rote Lacke misst sie in der oberen
  Hälfte des Autos ohne Farbtonregel (die Farbtonregel hielt roten Lack für Lampenschein).
- **`collect()` der Tankstelle (B-03):** `canopy_job_rest()` hält die Frist von `WARM_BUDGET_MS` ein und macht im
  nächsten `collect()` weiter.
- **Stöße (F-08):** `perf_stats()["spikes"]` – die zwölf längsten Teile eines Bildes über 8 ms mit Etappen-km; der
  Leistungstest schreibt sie mit.
- **Langsamkeitswächter (B-04):** Ein Bild über 1 s im Countdown bleibt eine Pause, drei davon urteilen sofort
  „langsam“ (auf der niedrigsten Stufe „zu langsam“) – vorher bekam der langsamste Rechner kein Urteil.
- **Zensus (B-05):** `check_instance_budget` zählt die Szene zusätzlich in jedem Bild, in dem die Fahrzeug-Ebene ihren
  bisher höchsten Wert erreicht, und meldet die obere Schranke Ebene + übrige.
- **Tönungswächter (B-02):** `test_props` verlangt für `baked`, `leaves` und `billboard` die Multiplikation mit der
  Tönung im Code ohne Kommentare.

## 19. Wahrzeichen und Skyline (Bauabschnitt R7b)

Seit R7b gehören die Wahrzeichen einem eigenen Builder: `scripts/race3d/builders/landmarks.gd` mit dem Shader
`assets/shaders/modern/landmark.gdshader`. Der Hintergrund (`layers/backdrop.gd`) zeichnet zusätzlich die Skyline der
Zielstadt wie Arcade. Vorlage ist in beiden Fällen Arcades eingefrorener Code (`RoadRenderer.landmark_fade`,
`_draw_far_landmarks`, `_draw_landmark`, `_skyline_silhouettes`, `_draw_skyline_landmark`, `_draw_landmark_proc`).

### 19.1 Wo ein Wahrzeichen steht

- Quelle ist `Track.landmarks` (ein Eintrag je Wahrzeichen des Etappenplans, aus `Track._build_landmark`). Ein
  Wahrzeichen ist **kein Teil eines Stücks**: es steht als ein Knoten unter `renderer.world` auf dem Pfad, sobald es
  in Arcades Reichweite kommt, und wird freigegeben, wenn die Kamera es um `KEEP_BEHIND_M` (320 m) hinter sich
  gelassen hat. Reichweite = Arcades Wahrzeichenreichweite L = clamp(Sicht × `render.landmark_range_factor`,
  min(Sicht, 600), max(`render.landmark_far_m`, Sicht)), nachts (Palette `lights` > 0,05) mindestens
  `render.landmark_far_m` (1.900 m) – dort zeichnet Arcade noch die Beleuchtung. Der Pfad ist dafür weit genug
  integriert (`graphics.modern.landmark_path_m`, A-3: 3.438 m voraus).
- Stelle wie Arcade: Bild und Modell mit Arcades Kantenregel (`edge_anchor_x` mit den Ausdehnungen der Seite, die
  Arcade zeigt), eine prozedurale Form in der Mitte, die Arcades Zeichnung hat (x + Seite × `width_m` / 2 ×
  `scale`). Höhe: das Gelände an dieser Stelle (`TerrainProfile.height`). Ein Bild dreht sein Shader zum Bildschirm.
- **Gespiegelt wie Arcade** (FIX-R7b, Befund B-04): Arcade spiegelt das Bild eines Wahrzeichens nach
  `RoadRenderer.prop_flipped` – eine gewöhnliche Requisite, die für die rechte Seite gebaut ist (Tag `mirror_left`,
  `props/church` als Dom), steht links gespiegelt; kein `landmarks/*`-Set trägt das Tag, ein echtes Wahrzeichen (und
  jedes AS6-Modell) wird also nie gespiegelt. Modern macht dasselbe: das Modell steht unter einem Knoten mit negativer
  x-Skalierung (ein einzelnes `MeshInstance3D` zeichnet gespiegelt richtig), das Bild klappt sein Shader um den Anker
  (`mirror` = −1), und der Anker misst die Kante mit der Ausdehnung der gespiegelten Seite. Vorher stand der Turm des
  Magdeburger Doms 37,8 m näher an der Straße (44,7 px bei 600 m); jetzt steht jedes der 143 Wahrzeichen des Netzes
  an Arcades Anker (`test_landmarks` „anchor_and_mirror…“: größter Unterschied 0,15 m – Modell- gegen
  Sprite-Ausdehnung, A-4), 23 davon gespiegelt.
- **Zur Anfahrt gedreht** (FIX-R7b, Befund B-05): Arcade zeigt ein Wahrzeichen immer von vorn. Modell und Form
  stehen deshalb mit ihrer Vorderseite (+Z) zum Straßenpunkt 600 m vor dem Anker (`APPROACH_M`; höchstens 40°,
  `MAX_TURN`, gegen die Straßenrichtung am Anker), einmal beim Entstehen des Knotens. R7b drehte sie mit der Straße
  am Anker – in Kurven zeigten sie ihre Seitenwand (Belgrad ≈ 85 px neben Arcade, breiter). Die Drehung bringt keine
  Ecke des Grundrisses näher an die Straße als die Aufstellung längs der Straße (`near_shift`: sonst rückt das
  Wahrzeichen um den Unterschied nach außen).
- **Verschiebung des gezeichneten Knotens** (RINT-M3, A-25, NACH-R7b N-1): Diese Verschiebung trifft den Knoten, nicht
  den Anker – „an Arcades Anker“ oben gilt für den Anker davor. Netzweit (66 Modelle und Formen der 143 Wahrzeichen)
  ist der Knoten bis **11,89 m** von Arcades Anker verschoben (die Kirche vor Bremen auf Bremen – Amsterdam km 36,3,
  um −10,6° gedreht); auf dem Bildschirm etwa 14 px bei 600 m (gefolgert). Die Grenze des Vertrags ist 12 m
  (`MAX_NODE_SHIFT_M`); `test_landmarks` „drawn_node_stays_near_arcades_anchor_network_wide“ rechnet den Knoten mit
  derselben Funktion, mit der `_place()` zeichnet (`place_model()`, Grundriss `parts_box()` bzw. der prozeduralen
  Form), und prüft ihn gegen den Anker (Mutation „Verschiebung × 1,1“: rot).
- `builders/props.gd` lässt alle Wahrzeichen-Einträge diesem Builder, sobald es ihn gibt (seine Ente-Typ-Weiche
  `_skip_landmarks = renderer.builder("landmarks") != null`, Zeilen 88, 122, 329, 539, 741 – sie stand schon im Code;
  R7b hat `props.gd` nicht geändert).
- Gemessen (`tests/race3d/check_landmarks.gd` „position“): auf den drei Anfahrten des Netzes, die 640 m gerade
  verlaufen (Burgos; die Kirche vor Slavonski Brod aus beiden Richtungen), steht der Anker 600 m voraus 0,0 px neben
  Arcades Stelle (Bild wie Kirchenmodell; erlaubt sind 5 % der Bildbreite, 64 px). Vor FIX-R7b waren es beim
  Kirchenmodell 24,7 px auf diesen Anfahrten und netzweit bis 44,7 px (die fehlende Spiegelung, oben). Alle zehn
  Stadteinfahrten der A/B-Bögen verlaufen in den letzten 640 m in Kurven (|curve| 0,11–0,29).

### 19.2 Womit ein Wahrzeichen gezeichnet wird (Schnittstelle für AS6)

Reihenfolge (Entscheidung der Leitung, Punkt 3):
1. **Modell** – das Set hat im Manifest ein Modell (`ModelDB`, `PropLibrary` Art MODEL): das Modell. Seine Flächen
   der Klassen `baked` / `baked_cutout` zeichnet `landmark.gdshader` (CE_ATLAS, mit CE_CUTOUT), `vpbr` CE_VCOL;
   `glass` und `leaves` behalten ihr Klassenmaterial (ohne Wahrzeichen-Gesetz – AS6 sollte sie bei Wahrzeichen
   meiden). Heute zeichnen 46 der 143 Wahrzeichen des Netzes als Modell: `props/church` 38-mal (ein Dom als
   gewöhnliche Requisite), `props/building_tall` 5-mal, `landmarks/michel` 3-mal (Datenscan QA-R7b).
2. **Arcades Bild** – sonst die Zelle „c“ des Sprite-Blatts, wie Arcade sie zeichnet (CE_PICTURE): dieselbe Rechnung
   wie die Vertretungen (`billboard.gdshader`, Bild mit eingebackenem Licht × das Licht einer mittelgrauen Fläche),
   die Lichtebene des Sprites nachts darüber, ungedunstet.
3. **Prozedurale Form in 3D** – sonst die Art, die Arcade prozedural zeichnet (`proc`, kein Sprite, kein Modell):
   `domed_church`, `tv_tower`, `lighthouse`, `skyscrapers` (`proc_mesh()`, aus Arcades Maßen der
   `_lm_*`-Zeichnungen: Bezugshöhen 80 / 368 / 51 / 259 m, skaliert auf `height_m` × `scale`). Ein Fernsehturm bleibt
   ein schlanker Turm, ein Leuchtturm ein Leuchtturm (offener Punkt N2: vorher ein breiter Block des Ersatz-Sets).
   Betroffen: Hannover (Neues Rathaus), Dortmund (Florianturm), Leipzig (Völkerschlachtdenkmal), Madrid (Cuatro
   Torres), Belgrad (Kirche des Heiligen Sava), Calais (Leuchtturm).
4. **Ersatz-Set** – sonst das `fallback` des Eintrags bzw. des Etappenplans (Modell oder Bild, mit `fallback_scale`
   und `fallback_tint`). Heute für keine Stadt nötig.

AS6 muss dafür nichts am Renderer ändern: sobald `assets/models/manifest.json` für `landmarks/<name>` ein Modell
führt, steht es statt des Bildes da (Ursprung = Anker des Sprites, −Z vom Fahrer weg, Klassen wie oben). Ein Modell
für einen prozeduralen Eintrag (z. B. `landmarks/florianturm`) ersetzt die 3D-Form ebenso. Nachtlicht eines
Modells: der Emissionsatlas (`baked`) bzw. die Lampenkanäle 10–14 (`vpbr`).

### 19.3 Arcades Gesetz, weiches Ausblenden

Je Wahrzeichen und Bild aus dem Abstand d seines Ankers (`fade()`, wie `RoadRenderer._draw_landmark`):
Deckung 1 − smoothstep(0,72 L, L, d), Dunst 0,85 × (d − Nebelbeginn) / (L − Nebelbeginn) zur Nebelfarbe × 1,15,
Beleuchtung = Nacht × (1 − smoothstep(0,8 F, F, d)) mit F = `render.landmark_far_m`, Anstrahlen (0,55 × Beleuchtung
in `RoadRenderer.LANDMARK_FLOOD`) für eine gewöhnliche Requisite, die als Wahrzeichen steht (`props/church` als Dom).
Die vier Werte gehen als `lm_fade` an die Materialien des Wahrzeichens – **jedes Wahrzeichen hat seine eigenen
Materialien, keine Instanz-Uniform** (A-19).

Nachts wie Arcade (FIX-R7b):
- Bild (CE_PICTURE): die Lichtebene des Sprites liegt in **Anzeigewerten** über dem Bild (wie Arcades Leinwand und
  `billboard.gdshader`), nicht linear gemischt – linear war ein halb heller Mischpixel aus dunkler Fassade und
  hellem Fenster deutlich heller (Elbphilharmonie 22 Uhr: Fassade +28 % gegen Arcade; jetzt 0,99 ×, Render-Prüfung
  „nacht_hell“).
- Anstrahlen einer gewöhnlichen Requisite: im Bild wie Arcade (Bild × Flutlichtfarbe), beim Modell (CE_ATLAS) als
  eigenes Licht – Albedo × Flutlichtfarbe × Anteil, die beleuchtete Albedo behält 1 − Anteil. R7b skalierte nur die
  beleuchtete Albedo, die nachts kaum Licht bekommt. Gemessen (Render-Prüfung „anstrahlung“, 22 Uhr): Bremer Dom
  (Modell) 1,32 × heller als ohne Anstrahlen und 0,97 × Arcade, Fourvière in Lyon (Bild) 1,71 × und 1,05 × Arcade.

Weich statt gerastert (Befund B-09): ab 0,70 L zeichnet ein Wahrzeichen mit der durchscheinenden Variante seines
Materials (CE_BLEND, `blend_mix`), näher mit der deckenden (Schatten, Tiefe – nahe Wahrzeichen werfen Schatten).
Jenseits von L bleiben nachts nur seine leuchtenden Pixel. Die durchscheinenden Varianten der beleuchteten Klassen
schreiben Tiefe (`depth_draw_always`): bei voller Deckung ist die Kuppelkirche in beiden Varianten pixelgleich
(gemessen, Sonne mit Schatten, 0 von 921.600 Pixeln verschieden; mit `depth_draw_opaque` waren es 481 – die
Flächen eines Netzes überdeckten sich in Zeichenreihenfolge). Prüfungen: `check_landmarks.gd` „weich“ (Material),
`render/check_landmarks_render.gd` „wahrzeichen_weich“ (Differenzbild ohne Rastermuster).

### 19.4 Die prozeduralen Formen

`ShapeKit` baut Dreiecke im Format CE_VCOL (Farbe, Rauheit/Metall in UV, Lampenkanal in UV2) und Leuchtpunkte (CE_GLOW).
- Kuppelkirche: Baukörper 64 × 44 × 30 m mit Gesims und flachem Walmdach, zwei Reihen Rundbogenfenster auf allen
  Seiten, Portal, zwei Seitenkuppeln auf Tambouren, Haupttambour mit zwölf Fenstern, Hauptkuppel, Laterne, Spitze,
  Kreuz (außer `cross: false`). Farben `wall` / `dome` des Katalogs. Nachts angestrahlt (Kanal 14; das Licht geht wie
  Arcades Überzug ungedunstet durch den Dunst), Fenster warm (Kanal 12), warmer Schein um die Hauptkuppel wie Arcades
  `_lm_glow` (16 m, 0,4).
- Fernsehturm: Schaft in drei Kegelstümpfen, Kugel mit Fensterring (nachts warm), oberer Schaft, Antenne mit
  rot-weißen Bändern, rote Flugwarnlichter bei 252 m (fest) und 300 / 368 m (1,5 s blinkend) – wie Arcade.
- Leuchtturm: weißer Turm mit Fenstern, Wärterhaus mit Dach, schwarze Galerie, Laternenraum (nachts hell), Kuppel; das
  Feuer blitzt viermal je Umdrehung (15 s), dazu Arcades vier kreisende Lichtstrahlen (240 m, flache Bänder, die sich
  um ihre Achse zur Kamera drehen; CE_GLOW Art 3).
- Hochhausgruppe: fünf Türme mit Glasfassade (Geschossbänder alle 4 m, Pfosten alle 3 m im Shader, nachts 35 % der
  Fenster hell wie Arcade), Mast oder Pyramide, blinkendes Flugwarnlicht je Turm (auf der Spitze; auf einem flachen
  Dach an dessen Vorderkante, sonst verdeckt die Brüstung das Licht in Arcades Größe von unten – FIX-R7b).
Dreiecke (gemessen): Kuppelkirche 1.626–1.636, Fernsehturm 1.012, Leuchtturm 246, Hochhausgruppe 124 (die Fassade
zeichnet der Shader) – je eine Fläche plus eine für die Leuchtpunkte; gebaut in 0,3–3,8 ms beim ersten Gebrauch
(zwischengespeichert je Art, Höhe und Farben – nicht nach dem Maßstab, den trägt der Knoten; FIX-R7b, B-07).

**Hauptachse am Anker** (FIX-R7b, Befund B-05): Arcade zeichnet ein prozedurales Wahrzeichen flach in der Ebene seines
Ankers, die Kuppel am Anker. Die Formen stehen deshalb mit ihrer Hauptachse – Hauptkuppel, Turm, höchstes Hochhaus –
auf dem Anker (`PROC_AXIS_Z`: 22 / 16 / 7 / 18 m × Maßstab nach vorn gerückt), der Körper reicht vor und hinter ihn.
Vorher stand die Vorderseite am Anker und die Kuppel 25 m dahinter: tiefer und kleiner als in Arcade, in Leipzig hinter
einem Baum verborgen.

**Leuchtpunkte wie Arcades `_lm_glow`** (FIX-R7b, Befund B-02): eine weiche Scheibe der Farbe (Deckung 0,8 a, zum Rand
linear auf 0) unter einem Kern von 0,35 des Radius in der um die Hälfte aufgehellten Farbe (Deckung 1,2 a); Radius
max(Mindestpixel, Meter) mit Arcades Maßen – Flugwarnlicht des Fernsehturms 6 m / 2,5 px / a 0,85, der Hochhäuser
3 m / 2,5 px / 0,85, Schein um die Kuppel 16 m / 4 px / 0,4, Leuchtfeuer 3,5 m (beim Blitz bis 25,5 m) / 2,5 px /
0,5 … 1. Der Pixelmaßstab im Vertex-Schritt nimmt den **Betrag** von `PROJECTION_MATRIX[1][1]`: im Compatibility-
Renderer ist er negativ (die Szene wird kopfüber in ihren Puffer gezeichnet). R7b rechnete mit dem Vorzeichen – jeder
Leuchtpunkt bekam die Sicherheitsgrenze (3 % seiner Tiefe) statt seiner Größe; das Flugwarnlicht des Florianturms war
17 × 19 px gegen Arcades 4 × 4 px (gemessen: jetzt 15 gegen Arcades 10 rote Pixel bei 22 Uhr).

### 19.5 Skyline im Hintergrund (`layers/backdrop.gd`)

Wie Arcade: nur in den City Limits (Bodenpunkt der Kamera), je Eintrag von `cities.json` „skyline“ eine Silhouette auf
der Grundlinie des Panoramas in `render.skyline_distance_m` (1.800 m) Größe; beim ersten Sehen am Panorama verankert
(`azimuth_deg`, sonst die wahre Richtung des Wahrzeichens auf der Straße von der Kamera aus – in 3D die Richtung
seines Ankers auf dem Pfad –, sonst Arcades feste Winkel `SKY_OFFSETS`), danach dreht sie mit dem Panorama. Steht
dasselbe Wahrzeichen auf der Straße, blendet die Silhouette aus, solange es in Reichweite ist (smoothstep(L, 1,15 L,
d)) – dann übernimmt das 3D-Wahrzeichen, nie doppelt. Gezeichnet wird eine Sprite-Silhouette als Zelle „c“ des
Blatts (× Umgebungslicht zum Nebel × 1,15 nach dem Dunst, getönt, nachts die Lichtebene), eine prozedurale mit
Arcades eigener 2D-Zeichnung: eine `RoadRenderer`-Instanz, die nie in den Baum kommt, zeichnet über ihren `GeoBatch` in
die Leinwand des Hintergrunds. Die Blätter werden in `prepare()` aufgelöst (hinter der Ladeabdeckung). Verankert wird
erst, wenn die Etappe vorbereitet ist (vorher steht die Kamera noch nicht im Startbild). Snapshot:
`backdrop.skyline` (Set, Winkel, Deckung, x). Prüfung `check_landmarks.gd` „skyline“.

### 19.6 Dateien und Prüfungen

| Datei | Was |
|---|---|
| `scripts/race3d/builders/landmarks.gd` | der Builder (Plan je Wahrzeichen, Gesetz, Materialien, Formen, Aufwärmen auf den echten Netzen) |
| `assets/shaders/modern/landmark.gdshader` | CE_PICTURE, CE_ATLAS (+ CE_CUTOUT), CE_VCOL, CE_GLOW, je mit CE_BLEND |
| `scripts/race3d/layers/backdrop.gd` | Skyline (§19.5) |
| `tests/unit/race3d/test_landmarks.gd` | Gesetz = `RoadRenderer.landmark_fade` an 20 Abständen und drei Sichtweiten, Reichweite, jedes Wahrzeichen der 55 Städte hat eine Darstellung (die sechs prozeduralen als 3D-Form), Anker wie Arcade, Anker und Spiegelung aller 143 Wahrzeichen des Netzes gegen Arcades `_prep_prop` / `prop_flipped` (FIX-R7b), Ausrichtung zur Anfahrt ohne Ecke näher an der Straße (FIX-R7b), Formen (Höhe, Hauptachse am Anker, schlank, Flächen nach außen gewunden, Leuchtpunkte), keine Instanz-Uniform, Varianten, Tönung ferner und naher Wahrzeichen (offener Punkt N1) |
| `tests/race3d/check_landmarks.gd` | „reichweite“, „nacht“, „position“, „prozedural“, „weich“, „skyline“ in der echten Rennszene (headless) |
| `tests/race3d/render/check_landmarks_render.gd` | „wahrzeichen_stelle“ (Pixel des Wahrzeichens in Arcades Bild desselben Zustands gesucht: Versatz ≤ 5 % der Bildbreite), „wahrzeichen_weich“, „wahrzeichen_nacht“, „nacht_hell“ (FIX-R7b: Fassade der Elbphilharmonie 22 Uhr 0,8–1,1 × Arcade), „flugfeuer“ (Dortmund 22 Uhr: rote Flugwarnlichter sichtbar, höchstens 3 × Arcades rote Pixel desselben Zustands und höchstens 3 % des Bildes – die Leuchtpunkte rechnen ihre Größe mit der Bildhöhe aus einer Uniform, `VIEWPORT_SIZE` liest im Vertex-Schritt 0), „anstrahlung“ (FIX-R7b: Bremer Dom als Modell und Fourvière in Lyon als Bild, 22 Uhr – sichtbar angestrahlt, 0,8–1,25 × Arcade). Arcades Wahrzeichen-Pixel: dasselbe angehaltene Bild noch einmal mit leer vorbereiteten Wahrzeichen (`_c`, der Zwischenspeicher von `_prep_prop`) – an Arcade wird nichts geändert |
| `tests/race3d/check_minimal_structures.gd` | „wahrzeichen“ verweist auf die Prüfungen oben, sobald es den Builder gibt |

Offen: Modelle der Wahrzeichen (AS6); Wahrzeichen-Modelle mit Glas- oder Laubflächen blenden diese Flächen nicht
weich aus.

## 20. Freie Strecke: Himmel, Wolken, Felder, Fahrbahn (Bauabschnitt R7d)

Ziel (Vertrag A-27): Auf der offenen Autobahn erkennt man Modern auf den ersten Blick und findet es deutlich schöner
als Arcade – bei Tag, Dämmerung, Nacht, Regen und Schnee –, ohne dass etwas, worauf der Spieler reagiert, schlechter
zu sehen ist. Fahrzeuge, Lichter, Schilder, der Sichtkorridor und die Fairness-Schwellen bleiben unberührt.

### 20.1 Der Himmel (`assets/shaders/modern/sky2d.gdshader`, `clouds2d.gdshader`)

- Der Hintergrund (`layers/backdrop.gd`) zeichnet den Himmel nicht mehr mit `RaceBackdrop.draw_sky`, sondern mit einem
  eigenen Shader auf einem Rechteck hinter der Leinwand (`SkyNode`). An Arcades Stellen: Verlauf der Palette
  (`sky_top` → `sky_mid` bei 0,52 der Horizontzeile → `sky_bottom`), Morgen- und Abendglühen um den Sonnenazimut,
  Sterne (funkeln), Mond mit Sichel, Sonne mit Hof, die dunklere Oberkante unter geschlossener Decke. Die Formeln für
  Sonne und Mond sind Arcades (`sun_pos.x × 1,1`, `moon_pos.x × 1,1 + 0,4`, `RaceBackdrop.wrap_angle`).
- Statt Arcades 16 Wolkenbildern und den Ellipsen bei Bedeckung: eine **Wolkenschicht** in halber Auflösung in einem
  eigenen `SubViewport` (`cloud_vp`, `CLOUD_SCALE` 2), die der Himmelsshader vormultipliert über alles legt – Wolken
  verdecken Sterne, Mond und, wo sie dicht sind, die Sonne. Gemessen (llvmpipe, nur die Shader, 1376 × 816):
  Himmel ohne Wolken 6,3 ms über einem leeren Bild, Wolken in voller Auflösung 122 ms, in halber 39 ms (16 Proben)
  bzw. 49 ms (24 Proben) – die halbe Auflösung spart zwei Drittel, die Wolken sind weich. In einem Tunnel (die Leinwand
  deckt den ganzen Himmel) wird die Wolkenschicht nicht gezeichnet (`UPDATE_DISABLED`).
- **Haufenwolken**: Eine Schicht mit flacher Basis in `CloudField.HEIGHT_M` (1.600 m); jeder Haufen ist eine Kuppel bis
  `THICK_M` (450 m) darüber, deren Höhe dem Überschuss des Feldes über der Schwelle folgt (Wurzel: runde Kuppen,
  steile Flanken; in dünnen Gruppen flacher). Der Blickstrahl wird von der Basis aufwärts in `sky_steps` Proben auf
  **festen Höhen** verfolgt – in jeder Bildzeile dieselben, darum keine Streifen zwischen den Zeilen; die erste Probe
  unter einer Kuppel ist der Treffer, die Oberfläche liegt zwischen ihr und der Probe davor (drei Schritte Regula
  falsi). Licht: die Höhe im Haufen (Basis grau, Kuppen hell) und die Neigung zur Lichtquelle (`to_sun`: die
  zugewandte Seite hell, die abgewandte grau). Ein Strahl, der knapp vorbeigeht, gibt einen weichen Rand. Ein dünner
  Rand vor der Sonne leuchtet; ferne Haufen werden zum Horizont hin dunstig und gehen jenseits `far_m` (34 km) in ein
  Band der erwarteten Bedeckung über. Nachts sind die Wolken dunkle Silhouetten in den Palettenfarben.
- Regen und Schnee (Palette `overcast` 1): Bedeckung 1, eine geschlossene graue Decke, deren Unterseite dort heller
  ist, wo sie dünn ist.
- `sky_steps` je Effektstufe (`graphics.levels.effects`): 12 / 16 / 24 (Aus / Einfach / Voll) – Steam Deck und
  „Mittel“ 16. Der Langsamkeits-Wächter nimmt die Proben der niedrigeren Stufe mit (`quality_lowered`).
- `graphics.modern.sky2d` = false zeichnet wieder Arcades Himmel (und schaltet die Wolkenschatten ab).

### 20.2 Ein Wolkenfeld für Himmel und Boden (`scripts/race3d/cloud_field.gd`)

- `CloudField` erzeugt einmal je Prozess eine kachelnde Rauschtextur (FastNoiseLite, feste Samen, 256², Mipmaps):
  r = Kuppeln (1 − Abstand zum Zellpunkt, eine Wolke je Zelle, `TILE_M` 18 km je Kachel – ein Haufen etwa alle
  2,3 km), g = Beulen auf den Kuppeln (`DETAIL.x` 2,3), b = Gruppen von Haufen und klare Flecken (`DETAIL.y` 0,37).
  n = W · (r, g, b) mit W = (0,55; 0,18; 0,27).
- Bedeckung `cover_for(palette)`: 0,12 an einem klaren Tag (+0,05 in Morgen- und Abendglühen), 1 unter Regen und
  Schnee; `threshold(cover)` ist ein Quantil von n über eine Kachel, damit die Bedeckung der Anteil ist, was immer die
  Textur hergibt. `n_max()` ist das höchste n (die Kuppelhöhe ist auf den Überschuss bis dorthin bezogen).
- Das Feld steht in der Welt still: `field_pos()` = ursprungsbezogene Position − Summe der Verschiebungen des
  schwimmenden Ursprungs (`rebased()`) + die Drift mit dem Wind (7 m/s, Richtung von `EnvironmentRig.wind()`, über
  die Sichtzeit – keine Wanduhr, Regel 10).
- Die Shader tragen Kopien der Konstanten (`clouds2d.gdshader`, `inc/cloud_shadow.gdshaderinc`);
  `tests/unit/race3d/test_cloud_field.gd` prüft, dass sie übereinstimmen.

### 20.3 Wolkenschatten (`inc/cloud_shadow.gdshaderinc`)

- Der Strahl eines Bodenpunkts zur Sonne trifft die Schicht in `HEIGHT_M`; die Dichte des Feldes dort (mit einem
  breiteren Rand als die Wolke am Himmel) nimmt höchstens `CloudField.SHADOW` (0,22) des Lichts weg – als
  Anzeigefaktor auf Grund- und Sonnendurchgang (ALBEDO und EMISSION). Stärke 0 nachts, unter geschlossener Decke
  (diffuses Licht), im Tunnel und mit `sky2d` = false.
- Wer ihn bekommt: das Gelände, der ferne Boden, die Fahrbahn (höchstens `CLOUD_ROAD_MAX` 0,12, Farbe und Markierung
  gleich – der Kontrast der Linien bleibt), die Requisiten aus `baked` und `leaves` (der direkte Sonnenanteil, ein
  Wert je Objekt im Vertex-Schritt) und die Baum-Vertretungen (`billboard.gdshader` `cloud_shadow` = 1, nur bei den
  Impostoren). **Nie** Fahrzeuge, Schilder, Lampen, Lichthöfe.
- Ein Schatten ist so groß wie ein Haufen (rund 1 km): Meist liegt das ganze sichtbare Land im Licht oder im
  Schatten, und beim Fahren wandert die Grenze über die Felder.
- Der Spiegel-Himmel (`EnvironmentRig._update_sky`) bleibt der Verlauf der Palette: An einem klaren Tag sind 12–17 %
  des Feldes Wolke, unter geschlossener Decke ist die Palette ohnehin grau.

### 20.4 Felder, Bankett, Gras (`inc/ground.gdshaderinc`, `terrain.gdshader`)

- Felder (Voronoi, jetzt rund 230 × 135 m) tragen eine **Frucht**: ein Anteil `amount` die Akzentfrucht der Landschaft,
  der Rest Wiese (46 %), junges Getreide (22 %), dunkle Reihenkultur (17 %) und offener Boden (15 %: Acker oder
  Stoppel). Darin Saatreihen entlang einer Feldseite, Fahrgassen im Getreide (zwei Spuren alle 21 m), auf der Hälfte
  der Wiesen breite Mähstreifen; am Rand ein Grasstreifen (Vorgewende) und an rund 38 % der Grenzen eine Hecke
  (Knick). Gepflasterter Boden (nature 0) behält seine zwei Töne mit Fugen.
- Die Farben der Felder bleiben stehen, bis ein Feld nur noch ein, zwei Pixel misst (Fußabdruck 35–110 m, Entfernung
  1.500–2.300 m; vorher 9–30 m und 800–1.400 m – jenseits von etwa 200 m zeigten alle Felder ihr Mittel). Feine
  Muster (Reihen, Fahrgassen, Hecken) gehen wie bisher nach dem Fußabdruck eines Pixels in ihr Mittel über.
- Gras nah an der Straße: trockenere und frischere Büschel über einige Meter, im Bankett und im Graben blühende Flecken
  (ein Hauch Gelb, Weiß oder Lila über Meter, keine Punkte – sie würden beim Vorbeifahren nur flimmern).
- Relief und Luftperspektive bleiben, wie sie sind: Das Gelände hat schon sanftes Relief außerhalb des Sichtkorridors
  (A-17); jede Änderung würde die Verdeckungsprüfung berühren. Mehr Dunst wäre mehr Nebel als Arcade (F4).

### 20.5 Fahrbahn (`road.gdshader`, `builders/road.gd`)

- **Betonabschnitte**: Die Autobahnabschnitte, die der Klang als Beton spielt (`AudioFeed._concrete_section`: Anteil je
  Land, kalibrierte Schwellen aus `audio.modern.feed`), tragen das Flag 2048 (`F_CONCRETE`; nie in der Stadt, im Tunnel
  oder auf einem Brückendeck). Der Shader zeichnet dort Platten von 5 m Länge (die Fugen des Klangs) und einer Spur
  Breite, jede in ihrem Ton, mit dunklen Fugen quer und längs, etwas Abplatzung; die Radspuren sind heller poliert.
  Der Beton ist höchstens 2–3 % heller als Arcades Asphalt (`col_concrete`), damit die Markierungen ihren Kontrast
  behalten. `RoadBuilder.is_concrete()` entscheidet wie `AudioFeed` (Test „concrete_sections_follow_the_audio“).
- **Asphaltalter**: In Abschnitten von 240 m ist der Belag erneuert (dunkler, feiner), älter (etwas dunkler, gröber)
  oder unverändert, manchmal nur auf der rechten Spur, mit einer dünnen Naht, wo zwei Alter aneinanderstoßen – nie
  heller als der Grundton, damit die Markierungen ihren Kontrast behalten. z_period (1.440 m) ist ein Vielfaches von
  5 m und 240 m.
- **Lesbare Markierungen** (Vertrag A-27: Kontrast der Randlinien mindestens 0,9 × Arcade bei 20, 60 und 120 m,
  trocken und nass, Tag und Nacht – `check_freie_strecke.gd` „markierung“). Gemessen vor R7d (720eaf4): trocken bei
  120 m 0,70–0,82 × (Arcades Streifen liegen auf ganzen Pixeln und wirken etwa einen halben Pixel breiter), nass 0,14–
  0,61 × (der Spiegel des Himmels hellte den Asphalt bis an das Auto auf). Seit R7d:
  - jede Linie ist um einen viertel Pixel je Seite breiter (`pw` = 0,25 × Fußabdruck – in der Nähe nichts, in der
    Ferne so kräftig wie Arcades Linie);
  - der Spiegel des Himmels auf nassem Asphalt wächst erst zwischen `mirror_from` = 110 und 220 m herein (Arcades
    eigener Glanz zum Ende der Sicht bleibt); nah am Auto zeigen der dunklere Asphalt, die Gischt und die
    Spiegelungen der Lampen den Regen. „Zum Horizont hin spiegelt die Fahrbahn“ (`check_weather.gd` „nass“, 150–
    260 m) bleibt;
  - nasse Farbe ist nicht mehr um 7 % dunkler.
  Gemessen danach: alle 18 Fälle 0,92–1,30 × Arcade.

### 20.6 Bäume

- Jede Pflanze (Modell mit `veg`) bekommt einen eigenen, stabilen Ton (`Props.veg_variation`: ±6 % heller oder
  dunkler, ±3 % gelber oder blauer) als Faktor auf die Platzierungstönung – das nahe Modell und seine Vertretung
  lesen dieselben Instanzdaten. Gedreht waren sie schon (`place_yaw`).

### 20.7 Prüfungen

- `tests/unit/race3d/test_cloud_field.gd`: Textur, Bedeckung und Schwelle (der Anteil über der Schwelle ist die
  Bedeckung), Feldposition über Verschiebungen des Ursprungs, Schattenstärke, Konstanten der Shader.
- `tests/race3d/render/check_freie_strecke.gd`: Markierungskontrast Modern/Arcade bei 20, 60 und 120 m (Asphalt Tag,
  Nacht, nass Tag, nass Nacht; Beton Tag und nass Nacht) mindestens 0,9; Wolkenschatten (überall gegen nirgends): das
  eigene Auto unverändert, Asphalt mindestens 0,85 so hell, Linienkontrast mindestens 0,95, Gras dunkler, bei Regen
  keine Änderung; F4: der Nebelanteil im fernen Boden, gemessen mit weißer gegen schwarze Nebelfarbe, höchstens
  Arcades 0,7.
