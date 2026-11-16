# QA-M2-BILD – unabhängige Prüfung der ersten M2-Zusammenführung: Bild, Fairness, Leistung

Prüfstand **`6e48405`** (`origin/wip/v080-m2int` = `origin/wip/v080-m2zs1`, M2INT + ZS1-Merge + Pylon-Nacharbeit).
Vergleich: **ZS1** = `39849f0` (erster Testbuild beim Nutzer) als eigener Baum `m1/QA-M2-BILD/zs1tree` (git archive +
Import) im selben Lauf gerendert bzw. gemessen; dazu die ZS1-Bilder aus `deliver/gate1/` (Code an den Positionen
außerhalb Start/Köhlbrandbrücke gleich ZS1, `git diff 86c0650 39849f0` betrifft nur Start-Vorlauf, Starttor-Schatten,
Fernboden über Wasser, Wahrzeichen-Ersatz und Pylon). Rolle: Prüfung ohne Commits; Worktree
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-3` (Branch `worktree-wf_438996b0-243-3`,
Fast-Forward auf `6e48405`, nichts geändert außer Probe-Skripten im Scratch-Ordner).

„gemessen" = auf dieser VM (Mesa llvmpipe unter Xvfb bzw. headless, 4 geteilte Kerne). Während der ganzen Prüfung
liefen R4, R5, R6, AS5a und QA-M2-SYSTEM parallel: **Last 12–23** – alle Zeiten sind Proxies unter Last, Vergleiche nur
innerhalb desselben Laufs oder mit ausdrücklich genannter Referenz. Alles über echte Grafikchips, das Steam Deck,
ANGLE/Direct3D und wie etwas auf einen Menschen wirkt, ist **abgeleitet**.

Werkzeuge (alle im Scratch, nichts committet): `sh/shot.sh` (eine Rennszene je Baum/Modus, wie `tools/ab_shot.sh`),
`probe/qa_vehicles.gd` (Testautos in derselben eingefrorenen Ansicht für Arcade und Modern), `probe/qa_occl.gd` +
`sh/occl_count.py` (sichtbare Pixel eines Testautos je Abstand und Spur, Arcade gegen Modern), `probe/qa_props.gd`
(welche Arcade-Requisiten Modern auslässt und warum), `probe/qa_screen.gd`, `probe/qa_drive.gd` (Sonde von M1-QA-BILD,
unverändert) und `probe/qa_drive2.gd` (dieselbe mit Etappenkette für den Speicherlauf), `sh/perfrow.py`,
`tools/models/prop_scene.sh`, `tools/ab_clip.sh`, `tests/race3d/render/warmup_cold.gd`.
## Fairness

### Geometrische Prüfungen über das ganze Netz (gemessen, 15:09–15:12 UTC)

`godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full --verbose` (144 s) und
`… modern_path_check.gd -- --full` (58 s) auf `6e48405`, Logs `fair/modern_sight_full_m2.log`, `fair/modern_path_full_m2.log`:

| Prüfung | Vertrag | Ergebnis |
|---|---|---|
| F1 Mitte | 0 Fälle bis 270 m | **0** in 99 424 500 Stichproben, 128 Richtungen (erster Fall bei 280 m) |
| F1 Außenspuren (A-3) | 0 bis 260 m | **0** in 326 680 500 Stichproben (erster bei 270 m) |
| F2 | Anhalteweg ≤ 0,6 × Sichtweite | **0,593** trocken / **0,596** Regen / **0,555** Schnee |
| F3 Kuppen | 0 später und im Anhalteweg | **0 von 5 923** Fahrzeugzielen, 0 Schilder |
| F7 Gelände im Korridor | 0 | **0 von 2 011 532** Querschnittsseiten |
| Kameramodell | 0 Abweichungen | 0 (größte 0,0002 px) |
| Pfad | ≥ 250 m, Schleifen ≥ 2 000 m | 267,6 m (Bukarest–Sibiu km 57,8), Schleifen frühestens nach 2 064 m |

Alle Zahlen gleich denen von M2ZS1. **Grenze dieser Prüfungen:** sie rechnen mit Kamera, Fahrbahn und Gelände – Bäume,
Felsen und Gebäude kommen darin nicht vor. Deshalb zusätzlich im Bild:

### Verdeckung durch Modelle an Kurven (neu, gemessen)

`probe/qa_occl.gd`: eingefrorene Etappe ohne Verkehr, ein rotes Testauto (`traffic/hatch_red`) nacheinander 25 … 270 m
vor der Kamera in drei Spuren (eigene, links daneben, rechts daneben), jedes Bild gegen dasselbe Bild ohne Auto;
sichtbar = Pixel, die sich um mehr als 24/255 ändern. Dieselbe Ansicht und dieselben Autos in Arcade und in Modern
„Hoch" (Dichte 1,3 – die meisten Bäume). 4 Stellen × 10 Abstände × 3 Spuren = 120 Fälle (`sh/occl_count.py`):

| Stelle | Modern / Arcade (sichtbare Pixel) | Befund |
|---|---|---|
| T4 Saragossa–Pau km 198,8 (R ≈ 136 m) | 0,89–1,07 bis 55 m; **55–220 m nur Modern** | Arcade verdeckt das Auto ab 55 m hinter dem Fels-Sprite; Modern zeigt es bis 220 m (Fels und Fichten der Innenseite fehlen – Korridorregel) |
| T3 Saragossa–Pau km 172,8 | 0,99–2,6 | nirgends kleiner |
| T1 Kassel–Würzburg km 46,5 | 0,69–1,01 (25–170 m), 0,88–2,1 (220/270 m) | Auto in beiden ganz sichtbar (Ausschnitt `occl/T1_d100_zoom.jpg`); der kleinere Wert kommt vom eingebackenen Schatten und weichen Rand des Arcade-Sprites |
| W1 Dortmund–Frankfurt km 121,4 (Wald) | 0,70–1,09 | nirgends verdeckt |

**Ergebnis:** In keinem der 120 Fälle zeigt Modern ein Auto später oder deutlich kleiner als Arcade (kleinstes
Verhältnis 0,69 ohne Verdeckung). Die höheren und tieferen 3D-Bäume verdecken an diesen Kurven nichts – aber nur, weil
die Korridorregel sie auf der Kurveninnenseite gar nicht erst aufstellt (nächster Abschnitt). Bilder:
`occl/T4_d100_sheet.jpg`, `occl/T3_d130_sheet.jpg`, `occl/T1_d100_zoom.jpg`.

### Was die Korridorregel kostet (gemessen)

`probe/qa_props.gd` vergleicht die Requisiten, die Arcade zeichnet (`TrackSegment.sprites`), mit der Liste, die der
Props-Bauer von Modern wirklich aufstellt (`debug_snapshot()`), in den 150 m vor der Kamera (Liste je Stelle in
`fair/props_*.txt`). Ausgelassen wird fast nur aus einem Grund: `corridor` (F7, `builders/props.gd drop_reason()`):

| Stelle | ausgelassen / Arcade | was |
|---|---|---|
| Start km 0 | die große Eiche links (Segment 9, x −17,1 m, 9 m hinter dem Bankett) | in ZS1 genauso – das erste Bild jeder Kiel–Hamburg-Fahrt |
| T4 km 199,7 | **9 von 12** | alle Fichten der Innenseite bis 30 m hinter dem Bankett, ein Fels; Korridorbreite hier ≈ 80 m (Sehne 300 m, R 136 m), Band 102 m |
| T3 km 173,5 | 4 von 8 | Kiefern, Felsen |
| T1 km 47,5 | 5 von 13 | Fichten der Innenseite bis 25 m hinter dem Bankett |
| S4 km 80,4 (Hamburg) | 3 von 12 | zwei Birken, ein Busch |
| C1 km 221,8 (Frankfurt) | 4 von 16 | drei Straßenbäume (Ereignis-Einträge) **und ein Stadthaus** `city_german_gruenderzeit` (x +6,9 m) |

Der Vertrag (D14 F7) verlangt: „no decorative **vegetation** inside that corridor on the inside of bends". Der Bauer
lässt laut Code und `docs/renderer-modern-gelaende.md` „schmückende Requisiten einer Landschaftsregel **und** jede
Vegetation" weg – also auch Häuser der Stadtregel, Felsen, Strohballen. Die Korridorbreite ist die Pfeilhöhe einer
300-m-Sehne (d²/8R) – an T4 rund 80 m (abzüglich Bankett). Was F2 an dieser Kurve verlangt (abgeleitet aus `fairness.gd`: Anhalteweg =
1 s Reaktion + Vollbremsung; bei etwa 85 km/h trocken ≈ 58 m, sichtbar ab 58/0,6 ≈ 97 m, mit 9 m Kamera ≈ 106 m
Sehne): Pfeilhöhe ≈ 10 m plus Kronenradius. Die meisten der 9 Fichten (15–36 m hinter dem Bankett) stünden dann.
Bildbeleg: T4 `occl/T4_d100_sheet.jpg` (Modern-Innenseite eine kahle Wiese, Arcade Fels und Fichten), W1/T1
`occl/W1_none_sheet.jpg`, `occl/T1_none_sheet.jpg`, C1 und Start in den A/B-Bögen.
## Bild – A/B gegen Arcade und gegen ZS1

Gleicher Simulationszustand (Argumente wie `tools/ab_sheet.sh`, Aufnahme bei 3 s; Start bei 1 s im Countdown und 1,5 s
nach „LOS!“). Arcade läuft mit `--shot-fast` (bitgleich), Modern rendert jedes Bild. ZS1 ist am Start und an S4 im
eigenen ZS1-Baum gerendert; an den übrigen Stellen ist das ZS1-Bild der „Hoch“-Bogen von gate1 (gleicher Code dort).
Prüfung der Wiederverwendung: mein S1 „Hoch“ (`6e48405`) gegen M2INTs S1 „Hoch“ (`c317625`): mittlere Abweichung
1,4/255 (JPEG), 0,05 % der Pixel > 24/255 – dasselbe Bild; M2INTs Bögen für S2, S3, S5, T4, N2 gelten damit für den
Prüfstand. Jedes Bild angesehen, Ausschnitte vergrößert. Dreierbögen in `deliver/QA-M2-BILD/bilder/`.

| Stelle | M2 gegen ZS1 | M2 gegen Arcade (ehrlich) |
|---|---|---|
| **S0 Start km 0**, Mittel, Countdown 1 s und 1,5 s nach LOS | **gleich** – Auto an Arcades Stelle in beiden Bildern, Starttor mit Lampen, Schild „Tankstelle 15 km“; Bäume von AS3R | gleichwertig, nicht besser: **die große Eiche links fehlt** (Korridorregel, Segment 9, x −17 m – schon ZS1) |
| S1 km 3, Hoch | Bäume AS3R, Verkehr als Modelle | gleichwertig bis leicht besser (Leitplanken mit Pfosten, Schatten, Asphalt, Rückfenster mit Innenraum); keine Sonnenscheibe (gewollt: Mittagssonne hinter der linken Schulter, `environment_rig.gd`) |
| S4 km 80,6 Hamburg, Hoch | 0,46 % der Pixel anders (Verkehr, Bäume) – gleich | gleichwertig: Gehweg mit Pflaster, Laternen; links fehlt die Birke vor dem Backsteinhaus (Korridor); in der Ferne über den Häusern **ein dunkler, punktierter Fleck und ein türkis gepunkteter** – die ferne Wahrzeichen-Vertretung, mit Ordered Dither ausgeblendet (`billboard.gdshader`, Zeilen 121–127); in Arcade glatt verblassend. Schon in gate1/ZS1 |
| N1 Hamburg–Hannover km 71, 22 Uhr, Schnee, Hoch | gleich (Kiefer rechts neu) | **schlechter**: kein Schneefall in der Luft (R4); Kompakt deutlich heller und gelber als Arcades Sprite (Messung Abschnitt Fahrzeuge); Rest gleichwertig |
| C1 Frankfurt km 221, 19:30, Hoch | Sportwagen jetzt Modell (ZS1: Sprite) | **schlechter**: der große Straßenbaum rechts fehlt (Korridor, Ereignis-Eintrag); Sportwagen satter und orangeroter als das Sprite, flacher Lack; Gebäude (noch Stadt-Sprites) gleich |
| T1 Kassel–Würzburg km 46,5, Hoch | Kombi jetzt Modell (ZS1: Sprite) | gleichwertig bis schlechter: Fichten links (Innenseite) fehlen, die große Kurventafel am rechten Rand ist aus dem Bild (Kurvenkamera, nah – nach A-15 erlaubt); Gelände mit Tiefe besser; Kombi heller/türkiser als das dunkelgrüne Sprite |
| T4 Saragossa–Pau km 198,8 (M2INT-Bogen) | Fichten von AS3R | **schlechter**: Innenseite kahl (Fels und 9 von 12 Requisiten fehlen), nahe Fichte am rechten Rand fehlt |
| T3 Saragossa–Pau km 172,8, 11 Uhr, Hoch | gleich | gleichwertig bis schlechter: Felsen und Kiefern der Innenseite (links) fehlen (Korridor, 4 von 8), keine Sonnenscheibe; Kurventafeln, Gelände, Hang besser |
| T2 Kassel–Würzburg km 61,9 Kuppe, 15 Uhr, Hoch | gleich | **schlechter**: die ganze linke Seite kahl (Laubbäume und Fichten von Arcade fehlen, 8 von 18 Requisiten, Korridor); rechte Seite gleichwertig |
| U1 Gotthard km 187, Hoch | gleich, Sportwagen jetzt Modell | gleichwertig: Tunnelröhre, Lampen; das rote Verkehrsauto als Modell besser, aber ohne Rücklicht-Schein (Arcade glüht) |
| DEV km 48, 21 Uhr, Hoch | gleich | gleichwertig: Tunnelportal, Laubbaum; Fichte links fehlt (schon ZS1), Rücklichter des Spielerautos schwächer als Arcades Schein |
| N2 Dortmund–Frankfurt km 121, Regen (M2INT-Bogen) | GT jetzt Modell | **schlechter**: kein Regen in der Luft (R4); GT weiß und flach |
| S2, S3, S5 (M2INT-Bögen) | Bäume, Verkehr | gleichwertig |
### Köhlbrandbrücke: Wasser und Pylone (eigene Bilder, „Hoch“, 22 Uhr und 12 Uhr)

Kiel–Hamburg ab km 77,6 mit 80 km/h, Aufnahmen bei 2 s (km 78,1) und 4 s (km 78,8), Arcade / ZS1-Baum / M2 im selben
Lauf gerendert (`shots/KBN`, `shots/KBT`):

| | km 78,1 | km 78,8 |
|---|---|---|
| Pylonbereich nachts (x 500–780, y 150–350, mittlere Leuchtdichte) Arcade / ZS1 / M2 | 60,1 / 58,4 / **55,9** | 48,1 / 49,8 / **43,0** |

M2 ist an beiden Stellen dunkler als Arcade und ZS1 (dieselben Zahlen wie bei M2ZS1 – nachgemessen, nicht übernommen).
Nachts: Elbphilharmonie und Michel beleuchtet an Arcades Stelle (in ZS1 fehlten sie), Seile dunkle Linien statt der
hellen Sprite-Bänder von ZS1, Elbe und Fähren unter der Brücke wie in ZS1 – **besser als ZS1, gleichwertig mit Arcade**.
Bei Tag: Elbe beidseits bis zum Horizont, Fähren auf dem Wasser, der Pylon als Körper mit Seilfächer bis zur Deckkante;
nah an der Fahrbahn wirken die weißen Seile breit (25–40 px am Bildrand) – ein Käfig über der Straße, den Arcade so nicht
zeigt; Geschmackssache, kein Fehler. **Nicht schlechter als ZS1.**
## Fahrzeuge (gemessen, `probe/qa_vehicles.gd`)

Eingefrorene Etappe Kiel–Hamburg km 2, Mittel, ohne Verkehr; die Sonde schaltet die Render-Aufrufe der Sitzung ab und
gibt dem Renderer dieselbe Ansicht mit eingesetzten Testautos – dasselbe Skript, dieselbe Ansicht, dieselben Autos in
Arcade, im ZS1-Baum und in M2. Je Reihe drei Autos nebeneinander in 20, 60 und 150 m: linke Spur blinkt links, eigene
Spur bremst, rechte Spur nur Rücklicht (Reihen: Kleinwagen rot / Limousine silber / SUV weiß; Transporter weiß / Lkw
rot / Bus blau; Polizei DE / Sportwagen gelb / Kombi dunkelblau), 12 Uhr und 22 Uhr. Zählung `sh/lightcount.py`
(rot r>170, g<110, b<110; blau b>160, b−r>50, b−g>20) in einem engen Fenster um das Auto, Ausschnitte `sh/zoom.py`.

| | Arcade | ZS1 | M2 | Urteil |
|---|---|---|---|---|
| Sitz auf der Fahrbahn, Räder, Schatten (20/60/150 m, Tag) | – | gut | gut | in Ordnung, Transporter/SUV/Bus neue Modelle sauber |
| Reihen Kleinwagen…Bus: Lichtzählung Tag/Nacht | – | = | = | M2 gleich ZS1 |
| **Sportwagen (neues Modell) bremst, rote Pixel Tag 20 / 60 m** | 216 / 32 | 245 / 31 | **119 / 9** | Bremslicht ist ein dünner Streifen – bei 60 m 30 % des ZS1-Signals (`fahrzeuge_sportwagen_bremse_60m.jpg`) |
| Sportwagen bremst, Nacht 20 m | 375 | 449 | 180 | ebenso |
| **Polizei DE (neues Modell), Blaulicht Tag 20 / 60 / 150 m (blaue Pixel)** | 1601 / 182 / 17 | 1004 / 114 / 11 | **411 / 28 / 7** | schmaler blauer Balken ohne Schein (`fahrzeuge_polizei_60m_tag.jpg`) |
| Blaulicht Nacht 20 / 60 / 150 m | 5883 / 690 / 110 | 2903 / 371 / 47 | **1958 / 208 / 28** | ⅓ von Arcade, 60 % von ZS1 |
| Lkw rot, eigene Spur, Abblendlicht 22 Uhr, Hecktüren mittlere Leuchtdichte 20 / 60 m | 50 / 42 | 119 / 199 | 119 / 199 | M2 = ZS1: die rote Plane leuchtet im Abblendlicht als **weißer Kasten** (223 Pixel > 200 bei 20 m) – keine Verschlechterung, aber schlechter als Arcade |
| Limousine silber 60 m nachts, Pixel > 200 | 29 | 150 | 150 | Kennzeichen und Stoßfänger als weißer Block, = ZS1 |
| Bremslicht allgemein, Tag 20 m (Kleinwagen / Limousine) | 319 / 209 | 123 / 95 | 123 / 95 | Modern ≈ 45 % von Arcade, schon ZS1 |
| Blinker | glüht | glüht | glüht (Polizei jetzt auch) | in Ordnung |

Bei 150 m sind Rück-, Brems- und Blinklichter in allen drei Bildern ähnlich klein. Gegen ZS1 schlechter sind nur die
zwei Fahrzeuge, die in ZS1 noch Sprite-Vertretungen waren und jetzt Modelle sind (Sportwagen, Polizei).
## Leistung (llvmpipe, Last 17–23 – nur Proxies)

### Methode

`probe/qa_drive.gd` – dieselbe Sonde, mit der M1-QA-BILD den Stand von gate1 (= ZS1 ohne die Behebungen, Code der
Strecke gleich) gemessen hat, unverändert: Kiel–Hamburg ab km 0, Autopilot (Tankstopp km 13,9), 12 Uhr, Limousine,
Seed 11, `--timescale=2` (8 Physikschritte je Bild, 0,133 s Spielzeit je Bild, 2 476 Bilder für die ganze Etappe), Xvfb
1280 × 720, `nice -n 10`, gemeinsamer warmer Mesa-Shader-Cache, eigenes leeres `XDG_DATA_HOME` je Fahrt. Je Bild
Wanduhr, GDScript-Zeit von `render()`, ob ein Stück eingehängt wurde; alle 5 s Speicher, Zähler, `perf_stats()`.
Referenz: die Fahrten von M1-QA-BILD (Last 4–14). Weil die Last diesmal höher war, ist das Arcade-Bild der Maßstab:
Arcade brauchte dieselbe Fahrt im Median 204 ms je Bild statt 148 ms (× 1,38).

### Ganze Etappe Kiel–Hamburg (gemessen)

| | Niedrig M2 | Niedrig Ref. | Mittel M2 | Mittel Ref. | Arcade jetzt / Ref. |
|---|---|---|---|---|---|
| Laden bis zum ersten Rennbild | 59,1 s | 15,1 s | 47,5 s | 32,1 s | 0,8 / 0,7 s |
| davon Vorbereitung / Aufwärmen | 58,0 / 54,8 s | 14,0 / 12,1 s | 42,6 / 38,3 s | 29,8 / 27,4 s | – |
| `render()` GDScript Mittel / p50 / p95 / p99 | 2,41 / 1,73 / 6,44 / 13,1 ms | 2,10 / 1,60 / 4,40 / 8,9 | 4,04 / 1,81 / 7,96 / 16,8 ms | 1,92 / 1,59 / 3,66 / 6,8 | (Arcade `_draw` ≈ 9 ms, M1) |
| `render()` längstes Bild | 36,8 ms | 166 ms | **1 154 ms** | 92,6 ms | – |
| Bilder mit Stück-Einhängen p50 / p95 / max | 2,7 / 6,7 / 10,6 ms | 2,6 / 5,9 / 13,3 | 2,9 / 10,9 / 157 ms | 2,6 / 6,5 / 21,9 | – |
| `chunk_commit_ms_max` (Budget 3 ms) | 7,5 ms | 9,5 | 13,0 ms | 20,4 | – |
| Sammeln (`collect`) eines Stücks Mittel / max | – | – | 8,9 / 598 ms | 1,6 / 3,6 | – |
| Bauen eines Stücks (Worker) Mittel / max | – | – | 8,0 / 42,9 ms | 4,8 / 23,0 | – |
| Zeichenaufrufe sichtbar Median / max | 120 / 158 | 118 / 145 | 145 / 181 | 135 / 162 | – |
| Dreiecke Median / max | 116 k / 157 k | 92 k / 127 k | 132 k / 179 k | 98 k / 147 k | – |
| Texturspeicher max | 100 MB | 155 MB | 120 MB | 174 MB | 207 / 207 MB |
| Prozess-RSS max | 1 046 MB | 937 MB | 1 066 MB | 981 MB | 577 / 578 MB |
| Bildzeit p50 (llvmpipe, nur Software) | 250 ms | 223 ms | 1 385 ms | 670 ms | 204 / 148 ms |

## Nicht abgeschlossen (Prüfung auf Anweisung beendet)

- Leistung: die ZS1-Vergleichsfahrt Mittel km 40–90 (sie soll klären, ob die Hänger von bis zu 1,15 s eine Folge der
  Last sind), M2 „Hoch“ km 0–35, die 22-Minuten-Speicherfahrt (Lecks) und der Warmlauf mit kaltem Cache sind **nicht
  gemessen**; die ZS1-Fahrt wurde bei etwa 12 % abgebrochen. Zum Speicher gibt es deshalb keine Aussage.
- Bild: Spielerautos nachts, der LOD-Test 37/43 m (#76), Deck S1, die Vegetationsstufen (`prop_scene`), S1 um 6:30 und
  20:30 sowie die Clips sind nicht gelaufen (Skripte liegen bereit: `sh/chunkC.sh`, `sh/chunkF.sh`).
- `tools/golden.sh check` wurde nicht ausgeführt.
- Die Befunde B-01…B-10 stehen im Ergebnis des Pakets; alle Rohzahlen in `m1/QA-M2-BILD/notes.md`.
