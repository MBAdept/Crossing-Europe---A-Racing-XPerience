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
- Diese Werte setzt `layers/vehicles.gd` (`LOOK`) auf die geteilten Materialien; die Vorgaben der Shader bleiben
  neutral (Kontaktbogen, `check_models`). Der Showroom setzt seinen eigenen Look (`Showroom3D.studio_look()`), sonst
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
