# R7d – „Freie Strecke“ (Vertrag A-27)

Zweig `wip/v080-r7d`, Basis `720eaf4` (RINT-M3). Arbeitsbaum `.claude/worktrees/wf_a71eeb2e-3b7-1`.
Arbeitsordner `scratchpad/v080/m1/R7D` (Skripte `sh/`, Logs `logs/`, Bilder `shots/`, Tore `gates/`).

Ziel: Auf der offenen Autobahn erkennt man Modern auf den ersten Blick und findet es deutlich schöner als Arcade – bei
Tag, Dämmerung, Nacht, Regen und Schnee –, ohne dass etwas, worauf der Spieler reagiert, schlechter zu sehen ist.

## 1. Kurzfassung

**Ergebnis:** Auf der offenen Autobahn ist Modern jetzt bei Tag, Morgen, Dämmerung und Regen auf den ersten Blick
zu erkennen und deutlich schöner als Arcade; nachts und im Schnee erkennt man es weiterhin – dort trägt R7d aber
wenig bei (9). Nichts, worauf der Spieler reagiert, ist schlechter zu sehen; alle Tore sind auf dem Endstand
`6092197` grün.

- **Himmel**: Haufenwolken mit Licht, Schatten und Silberrand, in der Dämmerung angestrahlt, bei Regen und Schnee eine
  strukturierte Decke; ein Wolkenfeld für Himmel und Boden – **Wolkenschatten** ziehen über Felder und Bäume, nie
  über Fahrzeuge, die Fahrbahn höchstens auf 0,86 ×.
- **Felder**: Fruchtfolgen mit Saatreihen, Fahrgassen, Mähstreifen, Vorgewenden und Hecken bis zum Horizont; im Schnee
  schauen Hecken, Furchen und Stoppeln heraus; Rastanlagen sind Rasen.
- **Fahrbahn**: Betonabschnitte dort, wo der Klang Beton spielt, Asphaltalter, und **lesbarere Markierungen** – der
  Kontrast nass und in der Ferne lag vorher bei 0,14–0,61 × Arcade, jetzt in allen 18 Fällen bei 0,92–1,30 ×.
- **Gefundene Fehler**: ein alter Fehler der Feldsuche ließ die Felder als Rasterzellen mit Randfarbe erscheinen –
  behoben, Felder erst jetzt so, wie R7d sie gebaut hat (K-6); die Tankstelle wurde nachts dunkler als erlaubt – mit
  Rasen behoben (K-2).
- **Tore** (`6092197`): 851 Tests grün, 32 Bildprüfdateien grün, Arcade-Goldens 20/20 und 17/17, Verdeckung
  unverändert (144 von 147 gleich, Rest nur Pixelfarbe), Sicht 6/0 und Pfad 2/0, Rennergebnis Arcade = Modern.
- **Leistung**: Zeichenaufrufe, Primitive, Skriptzeit gleich; Pixelarbeit +17–24 % in der Software-Grafik, davon der
  Himmel etwa die Hälfte; +5–6 MB. Deck abgeleitet unter 1 ms – auf dem Deck messen (ZS2).

## 2. Was gebaut ist

### 2.1 Himmel mit Haufenwolken
- Neuer Himmelsshader `assets/shaders/modern/sky2d.gdshader` hinter der Leinwand des Hintergrunds: Arcades Verlauf,
  Glühen, Sterne, Mond und Sonne an Arcades Stellen (Arcades Formeln).
- Neue Wolkenschicht `clouds2d.gdshader` in halber Auflösung in einem eigenen Viewport: Haufen auf flacher Basis
  (1.600 m), Kuppeln bis 450 m darüber, ein Blickstrahl durch die Schicht in Proben auf festen Höhen (keine Streifen
  zwischen den Zeilen), Treffer mit Regula falsi, weicher Rand, Licht nach Höhe im Haufen und Neigung zur Sonne,
  Silberrand vor der Sonne, Dunst zum Horizont, ferne Haufen gehen in ein Band über. Regen und Schnee: geschlossene,
  strukturierte Decke. Nachts mondbeschienene Wolken vor den Sternen, etwas heller als der Nachthimmel.
- Ein Wolkenfeld (`scripts/race3d/cloud_field.gd`) für Himmel **und** Boden: Kuppeln, Beulen, Gruppen; Bedeckung
  0,12 bei Tag (+0,05 im Glühen), 1 bei Regen und Schnee; das Feld steht in der Welt (schwimmender Ursprung) und
  driftet mit 7 m/s im Wind.
- Kosten: `sky_steps` je Effektstufe 12 / 16 / 24 (Deck und „Mittel“ 16). Gemessen auf llvmpipe, nur die Shader:
  Himmel ohne Wolken 6,3 ms; Wolken in voller Auflösung 122 ms, in halber Auflösung 39 ms (16 Proben) bzw. 49 ms
  (24) – die halbe Auflösung spart zwei Drittel. Im Tunnel wird die Wolkenschicht nicht gezeichnet.

### 2.2 Wolkenschatten
- `inc/cloud_shadow.gdshaderinc`: derselbe Feldwert, entlang des Sonnenstrahls bis zur Wolkenbasis; nimmt höchstens
  0,22 des Lichts (Anzeigefaktor), auf der Fahrbahn höchstens 0,12 – Farbe und Markierung gleich, ihr Kontrast
  bleibt. Gelände, ferner Boden, Fahrbahn, Requisiten (`baked`, `leaves`: direkter Sonnenanteil je Objekt) und die
  Baum-Vertretungen. Nie Fahrzeuge, Schilder, Lampen. Nachts, unter geschlossener Decke und im Tunnel aus.

### 2.3 Felder, Bankett, Gras
- Felder (Voronoi, rund 230 × 135 m) mit Frucht: Wiese, junges Getreide, dunkle Reihenkultur, Acker oder Stoppel,
  die Akzentfrucht der Landschaft; Saatreihen, Fahrgassen, Mähstreifen, Vorgewende, Hecken (Knicks) an rund 38 % der
  Grenzen. Die Feldfarben bleiben bis in die Ferne stehen (vorher war jenseits von ~200 m alles ein Mittelgrün).
- Gras: trockenere und frischere Büschel, blühende Flecken im Bankett und im Graben.
- **Schnee**: aus der Schneedecke schauen die Hecken, die Kämme gepflügter Äcker (Schnee liegt in den Furchen),
  Stoppeln und die Stängel einer Reihenkultur; Wiese, Getreide, Bankett und Rasen bleiben weiß (K-7).
- **Fehler im Bestand behoben**: die Felder waren Rasterzellen, und der Grenzton lag über ganzen Feldern (K-6).

### 2.4 Fahrbahn
- **Betonabschnitte** genau dort, wo der Klang Beton spielt (`RoadBuilder.is_concrete()` = `AudioFeed`-Entscheidung,
  Test): Platten 5 m × eine Spur, Fugen quer und längs, polierte Radspuren, nie heller als Asphalt.
- **Asphaltalter** in Abschnitten von 240 m mit Nähten (erneuert dunkler, alt gröber, nie heller).
- **Lesbare Markierungen**: ferne Linien ¼ Pixel je Seite breiter (wie Arcades ganze Pixel), der Himmelsspiegel auf
  nasser Fahrbahn erst ab 110–220 m, nasse Farbe nicht mehr 7 % dunkler.

### 2.5 Bäume
- Jede Pflanze in eigenem, stabilem Ton (±6 % Helligkeit, ±3 % Farbe), nahes Modell und Vertretung gleich.

### 2.6 Rastanlagen (aus der eigenen Prüfung, siehe 5)
- Rechts neben jeder Tankspur liegt bis 110 m jenseits des Banketts gemähter Rasen mit breiten Mähstreifen statt
  Feldern (60 m vor bis 60 m nach der Spur, über weitere 80 m ausgeblendet; ab 170 m wieder Felder). Eine Rastanlage
  ist Rasen, Parkplatz und Gebüsch, kein Maisfeld hinter den Zapfsäulen. `builders/terrain.gd` `lawn_at()`,
  CUSTOM1.a; Test `test_service_areas_are_lawn`.

### 2.7 Bewusst nicht gemacht
- **Relief**: Das Gelände hat schon sanftes Relief außerhalb des Sichtkorridors (A-17); jede Änderung hätte die
  Verdeckungsprüfung berührt, die unverändert bleiben muss.
- **Luftperspektive**: wäre zusätzlicher Dunst – mehr Nebel als Arcade (F4).
- **Spiegel-Himmel** der Lacke bleibt der Palettenverlauf (12–17 % Bedeckung bei Tag; die Regenpalette ist schon grau).

## 3. Neue Bildprüfung „Freie Strecke“

`tests/race3d/render/check_freie_strecke.gd` (Teil der Bildprüfungen, rund 9 Minuten), drei Prüfungen:

- **markierung** – Weber-Kontrast der Randlinie gegen den Asphalt daneben, Modern gegen Arcade, bei 20 / 60 / 120 m,
  an km 2 und km 45 (Beton), Tag und Nacht, trocken und nass. Grenze 0,9 × Arcade. Gemessen (alle 18 Fälle):

  | Fall | 20 m | 60 m | 120 m |
  |---|---|---|---|
  | km 2 trocken 12 Uhr | 1,13× | 0,93× | 1,16× |
  | km 2 trocken 22 Uhr | 0,99× | 0,94× | 1,03× |
  | km 2 Regen 12 Uhr | 1,11× | 0,94× | 1,01× |
  | km 2 Regen 22 Uhr | 1,09× | 1,24× | 0,94× |
  | km 45 (Beton) trocken 12 Uhr | 0,94× | 1,00× | 1,09× |
  | km 45 (Beton) Regen 22 Uhr | 0,92× | 1,30× | 0,98× |

  **Befund am Bestand:** In `720eaf4` lag der Kontrast nass und in der Ferne bei nur 0,14–0,61 × Arcade (der
  Himmelsspiegel überdeckte die Linien schon ab wenigen Metern, ferne Linien waren dünner als Arcades ganze Pixel).
  Das ist mit R7d behoben (2.4), nicht nur nicht verschlechtert.
- **schatten** – Wolke überall gegen nirgends (`debug_shadow_cover` 1 / 0) bei S1 12 Uhr: Fahrbahn 0,864 × (Grenze ≥
  0,85), Linienkontrast 20 m 1,009 ×, 60 m 1,010 × (≥ 0,95), Gras 0,766 × (der Schatten ist sichtbar, ≤ 0,93);
  **Auto 0 von 22.779 Pixeln anders** (Maske ohne Sonnenschatten, um 2 px geschrumpft); bei Regen 0 Pixel anders.
- **fern** – F4: Nebelanteil des Bodens je Bildzeile (Nebelfarbe weiß gegen schwarz, Zeilen über die Kamera
  bestimmt, 80. Perzentil, Anzeigeformel) gegen Arcades 0,7 × t. Tag, Dämmerung, Regen, Schnee: Modern zeigt am Boden
  **keinen** Nebel (0,00 gegen das Gesetz 0,54–0,57); Regen 22 Uhr im Mittel 0,22 gegen 0,58. Größter Überschuss
  überall +0,000. Modern ist nirgends nebliger als Arcade.

- **Fahrbahnhelligkeit** (Auftrag: im Band von Arcade ± 6 %; gemessen in den A/B-Bildern, nur unbunte Fahrbahnpixel
  ohne Farbe): S1 Asphalt 0,347–0,384 gegen Arcade 0,355–0,388 (−1 … −3 %), B1 Beton 0,333–0,345 gegen 0,347–0,352
  (−2 … −4 %), S3 0,341–0,350 gegen 0,347–0,351. Der Beton wirkt im Bild heller (neutraler Ton, Fugen), ist es aber
  nicht.

## 4. Bilder

A/B-Bögen auf dem Endstand `6092197` (Arcade links, Modern rechts, „Hoch“, Bild nach 3 s) in `shots/ab/hoch/`, Deck in
`shots/ab/deck/`; dazu je Ort Modern vor R7d (`720eaf4`) neben Modern R7d in `shots/basis_kopf/`. Urteil je Bild – ist
Modern auf den ersten Blick zu erkennen, und wo ist es noch Arcades Bild?

| Bild | Auf den ersten Blick Modern? | Noch Arcades Bild |
|---|---|---|
| S1 8 Uhr | **ja** – Haufenwolken, Felder in eigenen Farben (gelbes Getreide), Wolkenschatten | – |
| S1 12 Uhr | **ja** – Wolken, Mähstreifen im Feld neben der Straße, Felder bis zum Horizont | – |
| S1 19:30 | **ja, deutlich schöner** – rosa angestrahlte Kuppen, satte Abendfelder | – |
| S1 22 Uhr | ja – an Auto, Licht, Bäumen (wie vor R7d) | Himmel und Boden im Aufbau (K-8) |
| S1 Regen | **ja** – strukturierte Wolkendecke, nasse Fahrbahn mit Spiegelung, Gischt | – |
| S1 Regen 22 Uhr | ja – Spiegelungen der Rücklichter auf der nassen Fahrbahn | Himmel und Boden (K-3, K-8) |
| S1 Schnee | ja – Bäume, verschneite Leitplanken | die Schneefelder: fast so gleichmäßig weiß wie Arcade (hier eine Wiese, K-7) |
| S3 8 / 12 Uhr | **ja** – Wolken, Mähstreifen, Fruchtfarben, gelbes Band in der Ferne | – |
| S3 19:30 | **ja, deutlich schöner** | – |
| S3 22 Uhr | ja – wie S1 22 Uhr | Himmel und Boden (K-8) |
| S3 Regen | **ja** – Wolkendecke, nasse Fahrbahn | – |
| S3 Regen 22 Uhr | ja – Spiegelungen auf der nassen Fahrbahn | Himmel und Boden |
| S3 Schnee | ja – Bäume, Leitplanken, zarte Struktur rechts | die Schneefelder im Ganzen (K-7) |
| B1 (km 45, Beton) | **ja** – Betonplatten mit Fugen, Wolken, Felder | – |
| S0 (Start) | ja – Starttor, Wolken, Felder | – |
| S4 (Hamburg, 50 km/h) | ja – Häuser (R6), Himmel mit Wolken (R7d) | – |
| T2 (Kassel–Würzburg) | **ja** – Beton, Saatreihen, Wolken, Fichten | – |
| S1 Deck | ja – gleiches Bild bei `sky_steps` 16 | – |

Clips auf dem Endstand (20 s, Arcade und Modern nebeneinander, „Hoch“, Autopilot ab 140 km/h) in `clips/`:
`freie_strecke_tag.mp4` (Kiel–Hamburg ab km 22, 12 Uhr, in einen Betonabschnitt) und `freie_strecke_daemmerung.mp4` (ab
km 40, 19:30 – die Felder zeigen im Abendlicht ihre eigenen Töne, von dunkel über ocker bis golden). Beide auf
Flimmern geprüft (K-4).

## 5. Eigene Kritik und Nacharbeit

| Nr. | Befund | Entscheidung |
|---|---|---|
| K-1 | Dämmerung: Wolkenunterseiten dunkel | Im Bild S3D und im Clip angesehen: Kuppen rosa angestrahlt, Unterseiten mauve – stimmig, **kein Fix**. |
| K-2 | **Tankstelle nachts 0,84 × Arcade** (`check_structures_licht` „tankstelle“, Grenze 0,85; vor R7d 0,211 = 0,86 ×) | Ursache gemessen (Bild alt gegen neu): hinter der Tankstelle lag jetzt eine dunkle Reihenkultur bis zum Horizont (die Feldfarben bleiben seit R7d bis in die Ferne stehen). **Behoben** mit dem Rasen der Rastanlagen (2.6): wieder 0,211 (0,86 ×). Die Grenze ist unverändert. |
| K-3 | Nacht bei Regen und Schnee: das ganze Bild 1,19 × bzw. 1,22 × Arcade (vor R7d 0,95 × / 1,00 ×; `check_modern_render` „helligkeit“, Band 0,67–1,5) | Die geschlossene Wolkendecke ist nachts etwas heller grau als Arcades fast schwarzer Himmel. Im Bild S1RN: der Himmel bleibt dunkel, Bäume stehen besser dagegen, Rück- und Scheinwerfer leuchten unverändert. Der Boden bleibt 0,89 × / 1,00 ×. **Behalten**, zur Beurteilung in QA-mid. |
| K-4 | Tag-Clip und Dämmerungs-Clip: Flimmern – besonders nach K-6, seit Saatreihen, Fahrgassen und Mähstreifen wirklich gezeichnet werden | Je Clip vier aufeinanderfolgende Bilder, Horizont und Mittelfeld dreifach vergrößert: die Muster wandern gleichmäßig mit dem Feld, die Fahrgassen im Stoppelfeld bleiben feine stetige Linien, nichts funkelt. Mittlere Bildänderung je Bild in den nahen Feldern Modern 3,7 gegen Arcade 1,7 (Tag) bzw. 12,0 gegen 8,6 (Dämmerung, 194 km/h) – mehr Struktur, die vorbeizieht; in der Dämmerung gleich wie vor K-6 (12,1). |
| K-5 | Eigener Code noch einmal gelesen (Himmel, Wolkenfeld, Beton, Baumtöne) | Kein Fehler gefunden. Die Feldposition der Wolken wächst über ein langes Rennen (Verschiebung des Ursprungs + Drift); bei 500 km Strecke ist ein Gleitkomma-Schritt noch 0,06 m – unkritisch. |
| K-6 | **Felder: ein alter Fehler machte den Großteil der Feldarbeit unsichtbar** (gefunden über K-7: ein ganzes Feld blieb im Schnee grün) | `ce_ground_fields()` (vor R7d entstanden) suchte die nächsten Feldmittelpunkte in Quadratmetern, startete aber mit 64 (= 8 m) – kein Mittelpunkt lag je so nah. Jeder Pixel behielt seine Rasterzelle als beide Felder: Rasterfelder statt Voronoi-Feldern, jeder Pixel galt als Feldrand (Vorgewende- oder Heckenton über ganzen Feldern – das dunkle „Wolkenschattenfeld“ in T2 war in Wahrheit ein Heckenfeld), Saatreihen, Fahrgassen und Mähstreifen erschienen nie. Fehlersuche mit einer Falschfarben-Ausgabe (Heckenanteil rot: das ganze Mittelfeld rot). **Behoben** (`6092197`): Start 10¹². Jetzt sieht man Mähstreifen und Reihen in eigener Richtung, unregelmäßige Feldgrenzen, Hecken. Alle Tore, Bilder, Clips und die Leistung danach **neu** auf `6092197`. |
| K-7 | Schnee: alt gegen neu kaum ein Unterschied – eine gleichmäßig weiße Fläche wie in Arcade | **Nachgebessert** (`6092197`): aus dem Schnee schauen die Hecken, die Kämme gepflügter Äcker, Stoppeln und die Stängel einer Reihenkultur (2.3). Wiesen, Getreide, Bankett und Rasen bleiben weiß; in der Ferne gleichmäßig. Die Wirkung ist ruhig – je nach Feld vor der Kamera deutlich (S3S) oder kaum (S1S: eine Wiese). |
| K-8 | Nacht: alt gegen neu kaum ein Unterschied | Nachts sieht man fast nur Lichter, Fahrbahn und Silhouetten – die soll R7d nicht anfassen. Modern erkennt man nachts an Bäumen, Licht und Auto wie schon vor R7d; R7d fügt Wolken vor dem Sternenhimmel hinzu. **Offener Punkt für QA-mid.** |

## 6. Tore

Alle Tore auf dem **Endstand `6092197`** (nach K-2 und K-6/K-7 vollständig neu erhoben; frühere Läufe auf `7489ef8` und
`e8c6f07` stehen in `alt_e8c6f07/`).

| Tor | Ergebnis |
|---|---|
| Import, `tests/check_scripts.gd` | 342 Skripte, 0 fehlerhaft |
| `tools/run_tests.sh` | **851 Tests, 0 fehlgeschlagen**, 157 CHECK OK, 0 CHECK FEHLER (`gates/run_tests_3.log`) |
| `tools/run_render_checks.sh` (Arcade und Modern, alle Dateien) | **32 Dateien OK, 0 rot** (`gates/render_checks_3.log`) – darunter die neue Prüfung „Freie Strecke“ (3) und die Tankstelle nachts 0,211 gegen 0,246 = 0,86 × (K-2) |
| `tools/golden.sh check` | **Arcade 20 von 20, Arcade-Oberfläche 17 von 17 identisch** |
| Verdeckungssonde A-17 (FIX-M2 `qa_occl.gd`, rotes Testauto in drei Spuren bei 25–270 m; T1–T4, C1, S0, S4; Kopf gegen Basis `720eaf4`) | **147 Stellen, 144 gleich** (±5 % / ±3 px); T1 85 m linke Spur 47 statt 51 Pixel, T3 85 m Mitte 76 statt 72, S4 120 m links 39 statt 33. In T1 dieselbe Ausdehnung des Autos (x 578–591, y 408–418), nichts davor – vier Randpixel sind nur anders gefärbt (Lack spiegelt den neuen Himmel, daneben neuer Asphalt): `shots/occl_T1_85m_links_basis_kopf.png`. Keine Verdeckung durch R7d. |
| `tools/golden.sh modern-check` (nicht neu erzeugt, A-18) | **0 von 6 identisch – erwartet**, alle sechs geänderten Bilder in 7; OpenGL ES gegen OpenGL bei `modern_s3_hoch` OK (höchstens 2/255, PSNR 73,2 dB) |
| `tests/sim/modern_sight.gd -- --full` / `modern_path_check.gd -- --full` | **6 OK, 0 FEHLER** / **2 OK, 0 FEHLER** (F7: keine Verletzung) |
| ERGEBNIS Arcade gegen Modern (`run_stage`, Kiel–Hamburg 12 Uhr, Testetappe 21 Uhr Regen, Saragossa–Pau 10 Uhr Schnee) | **je 28 Schlüssel identisch** (außer `gfx`) |
| Leistung (Kiel–Hamburg, Autopilot, Deck / Mittel / Hoch, Kopf und Basis abwechselnd, je drei Läufe) | siehe 8 |

## 7. Geänderte Goldens (`tests/golden/modern_slice.*`, nicht neu erzeugt)

Alle sechs Bilder sind anders, und alle aus denselben Gründen: der neue Himmel (Haufenwolken statt Arcades Wolkenbilder,
nachts Sterne und Mond mit Wolken davor), die Felder bis zum Horizont, die Fahrbahn (Asphaltalter, Markierungen),
die Wolkenschatten und die wieder echten Felder mit Mähstreifen und Reihen (K-6). Bogen der neuen Bilder: `shots/goldens_modern_r7d.jpg` (aus `gates/modern_keep/`).

| Bild | Was sich ändert |
|---|---|
| `modern_start_mittel` (km 0, Start) | Himmel und Wolken über dem Starttor, Felder links und rechts, Wolkenschatten im Gras |
| `modern_s1_nacht` (km 3,2, 22 Uhr) | Nachthimmel mit Wolken vor Sternen und Mond, Feldtöne im Dunkeln |
| `modern_s2_mittel` (km 14,8, Tankstelle) | Himmel, Felder links; rechts der neue Rasen der Rastanlage |
| `modern_s3_hoch` (km 61,2) | Himmel, Felder, Fahrbahn, Wolkenschatten |
| `modern_s4_mittel` (km 80,6, Hamburg, 50 km/h) | Himmel über der Stadt, Fahrbahn; Gelände der Vorstadt |
| `modern_s5_niedrig` (km 95, Ziel, „Niedrig“) | Himmel hinter den Häusern (die Wolkenschicht auch bei „Niedrig“ – „Effekte: Aus“ hat 12 Proben) |

Die Integration (A-18) erzeugt sie neu, wenn sie R7d übernimmt.

## 8. Leistung

Kiel–Hamburg ganz, Autopilot, Seed 7, 12 Uhr, Zeitraffer 40 (`tests/race/run_stage.gd`, wie `gates.sh perf`), Xvfb /
llvmpipe, allein auf der Maschine; Kopf `6092197` und Basis `720eaf4` abwechselnd je Voreinstellung, drei Runden, dazu
der Kopf mit `graphics.modern.sky2d` false (Arcades Himmel, keine Wolkenschatten) – **Median aus drei Läufen**
(`gates/perf3/`, `sh/perf3_cmp.py`):
#### deck (Median aus drei Läufen)

| Wert | Basis 720eaf4 | R7d 6092197 | R7d ohne neuen Himmel |
|---|---|---|---|
| render() ms Mittel | 5.26 | 5.19 | 5.12 |
| render() ms max | 30.6 | 30.7 | 25.8 |
| Bild ms Median (llvmpipe) | 798 | 936 | 852 |
| Bild ms p95 (llvmpipe) | 1139 | 1284 | 1182 |
| Haken Hintergrund ms Mittel | 0.16 | 0.23 | 0.15 |
| Haken Gelände ms Mittel | 0.20 | 0.20 | 0.20 |
| Zeichenaufrufe | 145 | 145 | 145 |
| Primitive | 189112 | 189112 | 189112 |
| Primitive Schatten | 8444 | 8444 | 8444 |
| Texturspeicher MB | 97.6 | 102.5 | 97.6 |
| Einhängen ms max | 2.34 | 2.00 | 2.19 |
| wall s | 221 | 251 | 235 |

#### medium (Median aus drei Läufen)

| Wert | Basis 720eaf4 | R7d 6092197 | R7d ohne neuen Himmel |
|---|---|---|---|
| render() ms Mittel | 5.27 | 5.20 | 5.21 |
| render() ms max | 39.8 | 26.0 | 30.1 |
| Bild ms Median (llvmpipe) | 755 | 935 | 873 |
| Bild ms p95 (llvmpipe) | 1158 | 1283 | 1248 |
| Haken Hintergrund ms Mittel | 0.16 | 0.23 | 0.16 |
| Haken Gelände ms Mittel | 0.21 | 0.20 | 0.20 |
| Zeichenaufrufe | 175 | 175 | 175 |
| Primitive | 189112 | 189112 | 189112 |
| Primitive Schatten | 81803 | 81803 | 81803 |
| Texturspeicher MB | 97.6 | 102.5 | 97.6 |
| Einhängen ms max | 2.01 | 2.06 | 2.14 |
| wall s | 217 | 253 | 236 |

#### high (Median aus drei Läufen)

| Wert | Basis 720eaf4 | R7d 6092197 |
|---|---|---|
| render() ms Mittel | 5.08 | 5.37 |
| render() ms max | 26.6 | 26.6 |
| Bild ms Median (llvmpipe) | 936 | 1120 |
| Bild ms p95 (llvmpipe) | 1410 | 1663 |
| Haken Hintergrund ms Mittel | 0.15 | 0.23 |
| Haken Gelände ms Mittel | 0.20 | 0.21 |
| Zeichenaufrufe | 225 | 225 |
| Primitive | 248752 | 248752 |
| Primitive Schatten | 170061 | 170061 |
| Texturspeicher MB | 111.6 | 117.7 |
| Einhängen ms max | 2.05 | 2.10 |
| wall s | 267 | 315 |

- **Budgets §4.10 unverändert eingehalten**: Zeichenaufrufe und Primitive (auch im Schatten) **gleich** der Basis,
  `render()` (GDScript) im Mittel gleich (5,1–5,4 ms), Einhängen eines Stücks höchstens ~2 ms wie in der Basis. Der
  Haken des Hintergrunds kostet 0,07 ms mehr (die Werte des Himmels je Bild).
- **Pixelarbeit (llvmpipe)**: die Bildzeit steigt um 17 % (Deck), 24 % („Mittel“) und 20 % („Hoch“). Ohne den neuen
  Himmel bleiben +7 % (Deck) bzw. +16 % („Mittel“): Himmel und Wolkenschicht kosten 62–84 ms der ~935 ms, Boden,
  Fahrbahn und Wolkenschatten-Abfragen den Rest. Speicher: +4,9 MB („Hoch“ +6,1 MB) – nur der Himmel (Wolkenviewport
  in halber Auflösung, Wolkenfeld 256²).
- **Steam Deck (abgeleitet, nicht gemessen)**: llvmpipe rechnet Pixel auf der CPU, die Zeiten sind nicht übertragbar;
  der Anteil ist es grob. Die Wolkenschicht sind 640 × 400 Pixel mit 16 Proben (4–8 Mio. Texturzugriffe je Bild) –
  auf der Deck-GPU größenordnungsmäßig 0,3–0,5 ms; Boden und Fahrbahn rechnen mehr je Pixel, keine Zugriffe mehr
  auf den Speicher als ein Feldmuster. Erwartung: deutlich unter 1 ms je Bild zusätzlich. **Auf dem Deck selbst
  messen** (eingebauter Leistungstest) – Punkt für ZS2.

## 9. Offene Punkte (für QA-mid und ZS2)

1. **Nacht** (K-8): R7d ändert nachts wenig; Modern erkennt man nachts an Bäumen, Licht und Auto wie vor R7d. Ob die
   Nacht mehr braucht (etwa mondbeschienenes Gelände), ohne Lichter und Fahrbahn anzufassen, gehört in QA-mid.
2. **Regen- und Schneenacht** (K-3): das ganze Bild 1,19 × / 1,22 × Arcade durch die hellere Wolkendecke – im Band,
   behalten; in QA-mid über ein ganzes Rennen ansehen.
3. **Schneefelder** (K-7): was aus dem Schnee schaut, wirkt nur dort, wo Acker, Stoppeln oder Hecken vor der Kamera
   liegen; über ganze Wiesen bleibt es weiß wie in Arcade.
4. **Leistung auf dem Steam Deck** (8): abgeleitet, nicht gemessen – mit dem eingebauten Leistungstest auf dem Deck
   messen (ZS2).
5. **Goldens** (7): `tests/golden/modern_slice.*` erzeugt die Integration neu (A-18).

## 10. Commits auf `wip/v080-r7d` (Basis `720eaf4`)

| Commit | Inhalt |
|---|---|
| `fc2ee81` | Himmel mit Haufenwolken und Wolkenschatten |
| `53c52f9` | Felder mit Frucht, Betonabschnitte, Bankett, Baumtöne |
| `5531881` | Bildprüfung „Freie Strecke“, lesbare Markierungen, Doku |
| `3e187f4` | F4-Teil der Prüfung misst den Nebel je Bildzeile |
| `7489ef8` | Die Wolkenschicht wird im Tunnel nicht gezeichnet |
| `e8c6f07` | Rasen der Rastanlagen (K-2) |
| `6092197` | Voronoi-Felder repariert (K-6), Schneestruktur (K-7) – **Endstand** |

33 Dateien, +1.922 / −93 Zeilen. Doku: `docs/renderer-modern.md` §20.

