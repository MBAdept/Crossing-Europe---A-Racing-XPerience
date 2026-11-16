
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
  zeigt sich die Leinwand nie.
- **Gelände mit demselben Nebel** (`terrain.gdshader` schreibt `FOG`: im Compatibility-Renderer ersetzt `FOG` den
  Tiefennebel der Engine und wird in linearem Licht gemischt, gemessen mit `probe/fog_probe.gd`): Talboden jenseits der
  Sicht zeigt sich als dunstiges Land, nicht mehr als „See“ (T4); Band und Fernboden passen ohne Naht zusammen.
Gemessen an S1: Zeilen 321–330 Land 108–114/148–155/66–69 statt Nebel 197/219/237. Fahrbahn, Fahrzeuge, Schilder und
Requisiten behalten den Tiefennebel bzw. die Ausblendung F5 – nur Boden neben und hinter der Straße nimmt Arcades
Bodennebel.

### 13.4 Fahrzeuge im echten Rig

- **Unbeleuchtete Lampen** der Fahrzeuge (Kanäle 0–11) bei 0,28 ihrer Leuchtfarbe (`lamp_off`; 0,5 wirkte bei Tag
  eingeschaltet, Kunstkritik B1); Lampen der Requisiten (12, 13) bleiben bei 0,5 (`lamp_off_props`).
- **Rücklicht in Kanal 2** (eine Leuchte für Rück- und Bremslicht) bei 0,5 der Leuchte (`tail_level`, vorher 0,35);
  Bremse 2,2 × Lampenenergie.
- **Lack**: weiches Knie auf dem hellsten Kanal einer Lackfarbe (über 0,7 mit Steigung 0,35 – der Farbton bleibt, die
  Farbe wird skaliert), 8 % Entsättigung, `paint_base` 1,0 statt pauschal 0,9. Gemessen gegen die Cycles-Sprites in
  der Spielkamera (`m1/RINT-B/tools/paintcmp.py`: Farbton, Sättigung, Helligkeit der Lackpixel):
  Kompakt mittags −1,4° / −5,1 % (vorher an T4 +6,9 % mit 62 % Pixeln am Anschlag, jetzt 7 %), Limousine mittags
  −3,0° / −1,3 % (vorher −10,1 %).
- **Rückstrahler**: neuer Lampenkanal 15 `retro` (Vertrag: „reserviert“): Konturband und Dreiecksrückstrahler des Lkw
  leuchten im Kegel des eigenen Abblendlichts (dasselbe Gesetz wie `inc/headlight.gdshaderinc`, `retro_energy` 2,0),
  nicht mehr mit der Nacht überall. Die Schilder strahlen schon die echten Scheinwerfer zurück (11.4).
- Diese Werte setzt `layers/vehicles.gd` (`LOOK`) auf die geteilten Materialien; die Vorgaben der Shader bleiben
  neutral (Kontaktbogen, `check_models`). Der Showroom setzt seinen eigenen Look (`Showroom3D.studio_look()`), sonst
  übernahm er die Parameter des letzten Rennens (den analytischen Himmel der Rennpalette, nachts einen dunklen).

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

| Budget (GDScript je Bild, headless, normales Tempo der VM) | Grenze | Prüfung |
|---|---|---|
| Fahrzeug-Ebene je Auto (23 Autos) | 40 µs | `check_vehicles` → `leistung` |
| Renderer-Kern (Straße, Randausstattung, Hintergrund, Lichter, Overlay) | 0,6 ms | `check_modern_stage` → `kern_zeit` |
| **ganzer Renderer** (alle Builder und Ebenen, Verkehr der Sitzung) | **1,5 ms** | `check_modern_stage` → `renderer_zeit` (neu) |
| Einhängen eines Stücks | 3 ms | `kern_zeit` |

### 13.7 Beenden ohne Lecks

`GameFlow.quit_game()` stellt zuerst den Klang ab (Musikkontext „off“, Musik aus, `stop_all()` – beide Profile), wartet
0,3 s (Zeitgeber, der auch pausiert und unabhängig vom Zeitraffer läuft) und ruft dann `quit()`: der Audio-Server gibt
gestoppte Wiedergaben erst in einem späteren Mischschritt frei, ein sofortiges `quit()` meldete sie als „ObjectDB
instances leaked at exit“ (AU-D1). Render-Prüfung `check_quit_sound.gd`: je Klangprofil drei Spielstarts in eigenen
Prozessen, Beenden über `quit_game()`, keine Zeile mit „leaked“, „still in use“ oder einem Fehler.
