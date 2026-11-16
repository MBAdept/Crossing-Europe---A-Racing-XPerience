# R4 – Licht, Nacht, Wetter (Bericht)

Paket **R4** des Schubs M2, Welle 3 (Vertrag §6 „R4 – Licht, Nacht, Wetter“, §4.9.2, §4.10, §11 A-7/A-8 und die
Entscheidungen 1–8 der Leitung). Basis `6e48405` (= `origin/wip/v080-m2int`, M2INT + M2ZS1). Der erste Lauf begann
frisch (Vorspulen auf `6e48405`); nach einem Ausgabenlimit (12.11. 20:20) und zwei Neustarts des Containers
(13.11. 05:30, 15.11. 08:00) haben zwei Nachfolger über `STAND.md` im selben Worktree weitergemacht – nichts ging
verloren (jeder Stand war gepusht). Der letzte Nachfolger hat zwei Look-Punkte nachgezogen (1.6 Tunnelausfahrt, 1.9 Lackfarbe nachts), den
Kaltstart-Fehler an N1 behoben (1.12) und alle Tore auf dem Endstand gefahren.
Branch `worktree-wf_fd1de4ee-28b-1`, Worktree `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-1`,
jeder Commit gepusht nach `origin/wip/v080-r4`.
„gemessen“ = auf dieser VM (Mesa llvmpipe unter Xvfb bzw. headless, 4 geteilte Kerne, Last 15–21 durch die parallel
laufenden Pakete); alles über Steam Deck, echte Grafikkarten und wie etwas auf einen Menschen wirkt, ist **abgeleitet**.

## Urteil

**Wetter in der Luft ist da, die Nacht hält Arcades Helligkeit, alle Tore grün oder als Last belegt – der Lack der
Spielerautos bleibt der schwächste Punkt.** Endstand `7f0eae2` (enthält die neuen Modern-Hashes `83dbdac`), Branch
`worktree-wf_fd1de4ee-28b-1`, gepusht nach `origin/wip/v080-r4`.

- **Klar besser als Arcade**: Regen und Schneefall auf jeder „Effekte“-Stufe (300 / 1.500 / 4.000 Teilchen, jede
  Stufe mindestens Arcades Dichte), Gischt hinter jedem Auto auf nasser Fahrbahn, nasse Fahrbahn mit Himmelsspiegelung
  und Spiegelungen der Rück-, Brems- und Laternenlichter, Schneewälle und Schnee auf den Dingen, Blaulicht mit
  Lichtkegel, Sonnenscheibe, lange Schatten in Dämmerung und Abend (Bilder N1, N2, S1 bedeckt, C1 Regen).
- **Gleichwertig**: Nacht-Fahrbahn N1 +4,9 % gegen Arcade (nie dunkler), Wetter-×-Stunde-Tabelle 0,90–1,01 × bei
  Kontrast 0,74–1,17 ×, Tunnelausfahrt jetzt überbelichtet statt milchig (Arcades Gras bleibt greller).
- **Schwächer als Arcade** (ehrlich): der silberne GT nachts im Regen wirkt heller und neutraler als sein blaugraues
  Sprite (gleiche Leuchtdichte – Median 42 von 255 in beiden Hälften des Clips –, aber neutral grau statt blau), die Limousine in der Dämmerung lila statt blau; nachts sind Kompakt und
  Limousine jetzt farbig wie die Sprites (Sättigung 0,95 × / 0,91 ×), der GT knapp (0,73 ×).
- **Leistung** (llvmpipe, gemessen): ganze Etappe Kiel – Hamburg nachts im Regen ohne Fehler, `render()` 5,30 ms gegen
  5,35 ms der Basis, +4 Zeichenaufrufe, < 1 % Dreiecke; kalter Cache N1 und N2 ohne Übersetzung während der Fahrt
  (N1 erst nach der Aufwärm-Ebene, 1.12). Steam Deck und echte Grafikkarten: abgeleitet.

## 1. Was gebaut ist

### 1.1 Zonen: `EnvironmentRig.set_zone(kind, amount)` (Entscheidung 4, früh: `47566b8`)
Die Schnittstelle für R5, duck-typed über `renderer.env`: `"tunnel"` mischt Licht, Nebel und Globals zum Tunnel (das
eine Schattenlicht bleibt, D5), `"bridge"` verstärkt den Wind über Wasser (bis +50 %), fremde Arten werden behalten
und im Schnappschuss gezeigt. Solange niemand `set_zone("tunnel", …)` ruft, gilt `tunnel_blend()` aus dem
Etappenplan – der heutige Weg der Mindestbau-Röhre bleibt unverändert. Ohne Himmel im Tunnel (`ce_sky_top/horizon`
zum Tunnelnebel), Belichtungsrampe an der Ausfahrt (1.6). Dokumentiert in `docs/renderer-modern.md` §15.1, Unit-Test
`test_set_zone`.

### 1.2 Wetter in der Luft (Entscheidung 1) – `layers/weather.gd`, `particles_rain/snow.gdshader`
Regen und Schneefall als **zustandslose GPU-Teilchen**: eine MultiMesh aus Vierecken, ein Zeichenaufruf, der Ort jedes
Tropfens ist eine Funktion von Instanznummer, Kamera und `ce_time` – bestimmt (Regel 10), im Pausenbild still, kein
Sprung beim Ursprungsversatz, kein Prozess-Shader. Kasten im Kameraraum wie Arcade (Tropfen 3–45 m, Flocken
2–38 m), dreht mit der Straße. Menge nach „Effekte“ (300 / 1.500 / 4.000 Teilchen) in einem Kasten je Stufe, so dass
**jede Stufe mindestens Arcades Dichte** hat (Unit-Test) – auch „Aus“ und Steam Deck zeigen Niederschlag. Regen als
Bewegungsstriche (18 ms), Schnee als Flocken (bei Tempo gezogen), Helligkeit nach Arcades Gesetz plus Abblendlicht,
wo das Teilchen im Kegel hängt (`lights.beam_at()`; nah hell, ab 16–42 m auslaufend). Im Tunnel aus (Portalrampe).

### 1.3 Gischt (Entscheidung 1)
Hinter **jedem** Fahrzeug auf nasser Fahrbahn ab 40 km/h (voll 160 km/h, Arcades Gesetz), auch hinter Lkw/Bus und
dem eigenen Auto. `vehicles.gd` gibt je Bild die Quellen weiter (`weather.set_spray_sources`), `spray.gdshader` zeichnet
weiche Wolken (Rauschen, das mit `ce_time` treibt; weiche Kante über die Tiefentextur). „Einfach/Voll“: Fahne je
Hinterrad + Schleier; „Aus“ (Gischt laut Tabelle aus): eine Wolke an Arcades Stelle – keine Stufe zeigt weniger als
Arcade. Licht: Umgebung, Abblendlicht am Ort, nachts das Rot der Rückleuchten.

### 1.4 Nasse Fahrbahn (Entscheidung 1)
`road.gdshader`: dunkler und glatter wie bisher, dazu **Himmelsspiegelung nach Fresnel** (Wasser, F0 0,02) unter dem
Blickwinkel der Kamera (`wet_mirror` 0,42, neue Globals `ce_sky_top/ce_sky_horizon` vom Rig) – nie weniger als Arcades
Glanz. **Analytische Spiegelungen** der Rück-/Bremsleuchten (`flare.gdshader` Variante `CE_STREAK`, Klasse
`flare_streak`): Viereck vom Spiegelpunkt zur Kamera, tiefengetestet und mit denselben fünf Tiefenproben an der Lampe
wie der Lichtpunkt (hinter Kuppe/Lkw keine Spiegelung, F6-sicher). Laternen und Tankstellenlampen spiegeln nachts ebenso.

### 1.5 Schnee am Boden und auf den Dingen (Entscheidung 1)
Schneewälle an der Bankettkante (`terrain.gd`, 0,3 m, **höchstens 0,45 m** – unter A-3s 0,5 m, kann nie ein Auto
verdecken), Schnee auf nach oben weisenden Flächen (Dächer, Kronen, Holme, Masten), nachts 30 % dunkler; Fern- und
Ersatzbilder 15 % zu Arcades Schneeton.

### 1.6 Tunnelausfahrt bei Tag (Entscheidung 4) – `b9484fc`, nachgestellt `8ceb281`, `d1181fe`, `866a74c`
Belichtungsrampe: ein tiefengetestetes Viereck im Ausfahrtsportal überbelichtet das Draußen (Stärke 0,6 fern, **0,45
am Portal** – die Augen sind noch auf die Röhre eingestellt, wie bei Arcade bleibt das Draußen hell, solange die Kamera
drinnen ist), danach 60 m Nachglühen über das ganze Bild (0,4 am Portal) – eine Funktion des Ortes, keine Uhr; nur
bei Tag und nur mit einem Tunnel-Builder. **Gesetz** (`866a74c`): beide lesen das Bild hinter sich
(Bildschirmtextur) und zeigen es nach Arcades Gesetz für das Draußen – Anzeigewert × 1,7 + 0,25 bei voller Stärke,
die hellsten Teile brennen aus. Die erste Fassung mischte zu Weiß und las sich **milchig** (ein blasser Schleier über
graugrünem Gras); gemessen am Portal (Bereich über den Autos, „Hoch“): Leuchtdichte Arcade 0,600 / Modern vorher
0,638 / jetzt 0,717, Sättigung 0,43 / 0,20 / 0,26. Kosten: eine Bildkopie, nur solange Viereck oder Ebene zu sehen
sind; die Nachglüh-Ebene wird beim Aufwärmen mit Stärke 0 gezeichnet. Steht die Kamera noch in der Röhre, das Auto aber schon draußen, steht das
Viereck 1,5 m vor dessen Front: das Draußen ist überstrahlt, das Spielerauto nicht verschleiert (wie Arcades Sprite).
Die ersten Bilder (12 % / 22 %) zeigten eine fast normale Ausfahrt und ein verschleiertes Auto – beides nachgestellt.
Unit-Test `test_exit_ramp`.

### 1.7 Nacht (Entscheidungen 2 und 8)
- Nachtgesetz für senkrechte Flächen: **Mond aus mindestens 55°** – eine Wand bekommt höchstens 0,7 × das Mondlicht
  des Bodens (vorher bei tiefem Mond bis 1,7 ×).
- Fahrbahn nachts +8 % (`night_lift`), weil N1 3–4 % unter Arcade lag; gemessen jetzt **+4,9 %** (N1, „Mittel“ und
  „Steam Deck“, `check_night fahrbahn`).
- Fahrzeuglack: Halbkugel-Umgebungslicht (senkrecht 0,72, unten 0,5) und Fülllicht nur im Schatten.
- **Blaulicht**: Punktlicht aus dem Pool + blauer Bodenkegel im Takt der Phase, nur nachts, bis 160 m.
- Lichtdeckel (≤ 8 Punktlichter, ≤ 2 Spots, keine Schatten außer dem einen gerichteten Licht) entlang dreier
  Nachtetappen geprüft (`check_light_cap`).
- F6 bei N1, Kuppe und Lkw verdecken Lichtpunkt **und** Spiegelung (`check_night verdeckung`).

### 1.8 Tag (Entscheidung 3)
Sonnenscheibe an Arcades Stelle (vorn, hoch), Morgen/Abend unverändert passend; bedeckter Tag über die Palette,
Himmelsspiegelung nass aus den neuen Himmels-Globals.

### 1.9 Nacht-Füll-Licht des Spielerautos (Entscheidung 5, KRITIK-2 A2) – `c3afd5c`
Erst gemessen (`check_night spielerauto`, 75. Perzentil der Karosserie gegen Arcades Bild, 22 Uhr): Kompakt 0,80 ×,
Gran Turismo 0,55 ×, Limousine 0,35 × – „die Karosserie bleibt nachts fast schwarz“ stimmte. Eine Sonde mit sechs
Varianten zeigte: ein stärkeres diffuses Füll-Licht hebt den dunklen Metallic-Lack kaum (Limousine 0,51 × bei
`fill_night` 2,0, der Kompakt dann schon 1,13 ×). Lösung: `fill_night` 0,3 → 0,6 und ein neutraler Schimmer des
Füll-Lichts auf dem Klarlack (`fill_sheen` 0,25 × `ce_night`, neues vpbr-Uniform) – wie der Studioglanz der
Sprites. Danach **1,06 × / 0,92 × / 0,94 ×** (Schranke 0,6 … 1,1). Nur das Spielerauto, nur nachts; Verkehr,
Showroom und die gegen `VEHICLE_LOOK` gemessenen Fern-Konstanten unberührt. Im Tunnel ist `ce_night` 1 (für die
Lampen): dort machte der Schimmer die blaue Limousine grau (Bild TEXIT) – Füll-Licht und Schimmer folgen jetzt der
Nacht des Himmels, im Tunnel bleibt das Füll-Licht bei 0,3 wie vorher (`fill_tunnel`, `8ceb281`).
Danach (Nachfolger, `2577b30`) die Farbe: der neutrale Schimmer in der Farbe des Nachthimmels machte die Lacke blasser
als Arcades Sprites (Kompakt cremefarben statt bernstein, GT neutral grau statt blaugrau). Neues vpbr-Uniform
`fill_sheen_tint` (Standard 0 = unverändert, Renn-Look 0,8): der Schimmer trägt die Lackfarbe im Licht der Umgebung
(Arcades Gesetz Sprite × Umgebungsfarbe) bei gleicher Leuchtdichte. `check_night spielerauto` misst jetzt auch die
Sättigung (Median der Karosserie, Schranke ≥ 0,7 × Arcade): vorher **0,74 × / 0,70 × / 0,91 ×**, jetzt **0,95 × /
0,73 × / 0,91 ×**; Helligkeit 1,04 × / 0,93 × / 0,86 × (Schranke 0,6 … 1,1). Ein erster Versuch (Lackfarbe ohne
Umgebungsfarbe, 0,7) hob den Kompakt ebenso, nahm aber dem silbernen GT sein Nachtblau (0,56 ×) – verworfen. Der GT
bleibt knapp über der Schranke: seine Sättigung bei Arcade ist nur der blaue Nachtton des Sprites.

### 1.10 Nachtgesetz der Modelle (Entscheidung 8)
Allgemeines Gesetz statt neuer Einzelwerte: Mond ≥ 55° (1.7). Die M2ZS1-Werkzeuge bleiben (`night_albedo`,
`_dark_model_override`, `PYLON_BLINK`, `blink_lit`). Köhlbrand-Pylon nachgemessen (km 78,1, 22 Uhr, „Hoch“,
x 500–780 / y 150–350, Rec.601): **Arcade 59,7, Modern 55,4** – nicht heller als Arcade, `PYLON_NIGHT_ALBEDO`
0,45 bleibt (die Laternen an den Seilen bei km 79,7 brauchen ihn, nicht der Mond). Weitere senkrechte Flächen
(gleiche Bereiche in Arcade und Modern, mittlere Leuchtdichte): C1 19:30 Fassade links **−2,2 %**; DEV 21 Uhr
Tunnelportal −14 % / +2 % / +17 % (drei Teilflächen, im Mittel gleich); N1 hat keine Gebäude im Bild. Kein Bereich
heller als Arcade, wo Arcade dunkel ist.

### 1.11 Spiegelungen hoher Lampen (gefunden im Bild C1 21:30 Regen) – `b9574c2`, `32e23eb`, `e2e8e4e`
Ein gesättigter oranger Fleck lag um das Spielerauto. Eine Sonde (Bereich hinter dem Auto, mittlere Leuchtdichte:
alles 0,134, ohne Gischt 0,132, ohne Verkehr 0,138, **ohne Spiegelungen 0,096**) fand die Laternen-Streifen: ihr
Schleier zur Kamera folgte dem Gesetz der tiefen Rückleuchten (1,3 × Weg vom Lampenfuß zum Spiegelpunkt) – bei einer
8 m hohen Laterne liegt der Spiegelpunkt nahe der Kamera, der Streifen lief in voller Stärke bis unter sie. Jetzt:
Schleier höchstens halb so weit wie vom Spiegelpunkt zur Kamera, und jeder Punkt des Streifens nach dem
Fresnel-Gesetz von Wasser unter dem Blickwinkel gewichtet (`flare.gdshader`, `fresnel_ref_m` 15 m). Die Streifen
liegen jetzt als gelbe Bänder 15–40 m voraus in der Spur; die Rückleuchten-Spiegelungen bleiben unverändert.

### 1.12 Aufwärmen nachts (Entscheidung 7) – `7f0eae2`
Die Aufwärm-Prüfung mit kaltem Cache fiel bei N1 durch: 3 Shader-Varianten nach 6–8 s Fahrt (vier Läufe, immer
dieselben drei Mesa-Dateien). Eingegrenzt: N1 um 14 Uhr 0, um 22 Uhr ohne Schnee 3 – also die Nacht. Godots eigener
Shader-Cache (Datei mit dem Zeitstempel der Übersetzung) zeigte das Programm: `sign.gdshader` (Uniforms
`back_colour`, `retro`, `hl_range`). Ursache: nachts brennt das Abblendlicht schon beim Aufwärmen und beleuchtete die
Aufwärm-Knoten (14 m voraus) in allen vier Phasen – die Variante „ohne positionelles Licht“ entstand nur für
Materialien, die die Startansicht fern zeigt; N1 hat dort kein Schild. Abhilfe: die Aufwärm-Knoten liegen auf
Render-Ebene 20 (`ModernRenderer.WARMUP_LAYER`, Boden-Knoten behalten ihre Ebene), die echten Spots und Punktlichter
lassen sie aus (`lights.gd` `LIGHT_MASK`), nur die Aufwärm-Lichter erreichen sie. Danach N1 443 statt 386 Varianten vor
dem Start und 0 während der Fahrt; das Nachtbild der Modern-Hashes bleibt gleich (kein Objekt liegt sonst auf Ebene 20).
Unit-Test `test_warmup_layer_is_lit_by_the_warmup_lights_only`.

## 2. Prüfungen (gemessen)

| Prüfung | Ergebnis |
|---|---|
| `check_light_cap` „deckel“ (kopflos, „Hoch“; im Vollauf von `run_tests` auf `866a74c`) | **OK** – N1 188 Proben, Kiel–Hamburg ab km 76 22:30 176 Proben, C1 21:30 Regen: je höchstens 8 Punktlichter / 2 Spots (18 bzw. 21 Kegel), Lampen in 89 / 176 Proben im Pool |
| `check_night fahrbahn` | **OK** – N1 22 Uhr Schnee, Fahrbahn 12–70 m: Modern 0,2775, Arcade 0,2644 (**+4,9 %**, 652 Proben), „Mittel“ und „Steam Deck“ gleich |
| `check_night spielerauto` | **OK** (nach 1.9, Endstand) – Helligkeit 1,04 × / 0,93 × / 0,86 ×, Sättigung 0,95 × / 0,73 × / 0,91 × (Kompakt N1 Schnee / GT km 121 Regen / Limousine S1) |
| `check_night verdeckung` | **OK** – Kuppe bei 346 m: 0 Pixel (davor bei 20 m: 38 991); Sattelzug 30 m vor Auto in 50 m: 0 Pixel (ohne Lkw 8 691), Lichtpunkt und Spiegelung |
| `check_night blaulicht` | **OK** – 22 Uhr 12 804 geänderte Pixel, 7 848 blauer, Punktlicht an; 12 Uhr Punktlicht aus |
| `check_weather teilchen/gischt/nass/tunnel/schneewall` | **OK** – Endstand `866a74c`, Lauf von `tools/run_render_checks.sh all`: **teilchen** Regen 300 / 1.500 / 4.000 Teilchen („Aus“ / „Steam Deck“ / „Hoch“) → 7.343 / 20.021 / 45.417 Bildpunkte, Schnee 7.872 / 17.214 / 31.645; **gischt** S1 Regen 120 km/h: „Aus“ 1 Wolke 13.556 Bildpunkte, „Mittel“ 3 Wolken 13.974; **nass** 22 Uhr 2 Spiegelungen mit 932 roten Bildpunkten, 12 Uhr Fahrbahn fern/nah 1,59 (trocken 1,17); **tunnel** Teststrecke km 51,5 Regen: Niederschlag aus, Ausblendung 0; **schneewall** N1 2.688 Dreiecke in 7 Stücken, höchstens 0,35 m |
| `check_weather_tabelle` | **OK** – S1 „Mittel“, Boden unter dem Horizont, Modern gegen Arcade (Helligkeit, Kontrast):

  | | 6:36 | 12:00 | 19:12 | 22:00 |
  |---|---|---|---|---|
  | klar | 1,01 × / 1,07 × | 0,95 × / 1,00 × | 0,95 × / 1,06 × | 1,01 × / 1,10 × |
  | Regen | 0,95 × / 0,89 × | 0,90 × / 0,74 × | 0,94 × / 0,92 × | 0,98 × / 1,17 × |
  | Schnee | 1,00 × / 0,96 × | 0,98 × / 0,99 × | 1,00 × / 0,96 × | 0,99 × / 0,97 × |

  Schranken 0,8 … 1,35 × und Kontrast ≥ 0,5 ×; 933 s für alle 24 Starts → zwei Dateien (`fe70c27`) |
| Warm-up kalt N1, N2 | **OK auf `7f0eae2`** (`warmup_cold.gd`, leerer Mesa-Cache und Nutzerordner, „Mittel“, 30 s): N1 22 Uhr Schnee 443 Varianten vor dem Start, **0 während der Fahrt**, längstes Bild 2.994 ms bei Median 1.415 ms (Grenze 4.246 ms); N2 16 Uhr Regen 455 Varianten, 0 während der Fahrt, längstes 4.463 ms bei 1.802 ms (Grenze 5.406 ms); N2 22 Uhr Regen (Lampen, Kegel, Spiegelungen, Gischt) 459 Varianten, 0 während der Fahrt, längstes 2.545 ms bei 1.641 ms (Grenze 4.924 ms). Der erste Lauf auf `83dbdac` fiel bei N1 durch (3 Varianten nach 8,2 s) – Ursache und Abhilfe in 1.12 |

## 3. Bilder (A/B, `tools/ab_shot.sh`, Modern „Hoch“ wenn nicht anders genannt) – angesehen

Dateien in `deliver/R4/bilder/`: 01 N1 Hoch, 02 N1 Steam Deck, 03 N2 22 Uhr Hoch, 04 N2 22 Uhr Steam Deck, 05 N2 16 Uhr,
06 C1 19:30, 07 C1 21:30 Regen, 08 DEV 21 Uhr, 09 S1 6:36, 10 S1 19:12, 11 S1 bedeckt/Regen, 12/13/20 Tunnelausfahrt,
14 Köhlbrandbrücke 22 Uhr, 15 Laternen-Spiegelung vorher/nachher, 16/17 Spielerauto nachts (Stand `c3afd5c`), 18 Teilchen
„Aus“/Deck, 19 Prüfbild N1 Fahrbahn, 21 Spielerauto nachts Arcade / neutral / Endstand. 01, 03, 12, 13, 20, 21 sind vom
Endstand (`7f0eae2` bzw. `866a74c`), die übrigen vom Stand `33ded9a` (seither nur Nacht-Schimmer und Tunnelausfahrt geändert).

| Bild | Was zu sehen ist | Urteil gegen Arcade |
|---|---|---|
| `01_N1_…` (Hamburg–Hannover km 71, 22 Uhr, Schnee; Endstand) | Schneefall als Striche im Kegel hell, Schneewall an der Bankette, Kegel auf der Fahrbahn, Kompakt bernsteinfarben | **besser**: Schnee fällt sichtbar in der Luft und liegt am Rand, Flocken bei Tempo strichförmig wie bei Arcade; das Auto hat jetzt die Farbe des Sprites |
| `KBN_*` (Köhlbrandbrücke km 78,1, 22 Uhr) | Seilfächer, Pylon, Laternen auf dem Deck, Elbphilharmonie | gleichwertig bis besser; Pylon −7 % gegen Arcade |
| `C1_*` (Frankfurt, 19:30) | 3D-Fassaden mit Fenstern, Gehweg, Laternenkegel | gleichwertig, mehr Tiefe; Fassade −2,2 % |
| `DEV_*` (Testetappe km 48, 21 Uhr) | Portal mit Lampen, Hügel, Kegel, Limousine mit Nacht-Füll-Licht | gleichwertig bis besser |
| `S1DAWN_*` / `S1DUSK_*` (6:36 / 19:12) | Sonnenscheibe am Horizont links/rechts wie Arcade, lange Schatten quer über die Fahrbahn | besser (Schatten, Licht); **schwächer**: der Lack der Limousine spiegelt den lila Dämmerungshimmel und wirkt blasser als Arcades sattes Blau (Klarlack-Gesetz von R3/RINT-B, nicht geändert) |
| `S1OVC_*` (12 Uhr, Regen) | dichter Regen über das ganze Bild, nasse Fahrbahn spiegelt den Himmel nach hinten heller, Gischt hinter den Hinterrädern | deutlich besser – Arcade zeigt wenige Striche auf trockener Fahrbahnfarbe |
| `12_…`, `13_…`, `20_…` TEXIT (Testetappe km 52,8, 12 Uhr; 1,0 / 2,4 / 3,8 s; Endstand `866a74c`) | drinnen blaue Limousine mit Rücklichtern, Ausfahrt in 40 m hell, am Portal das Draußen überbelichtet: helles Gras, heller Himmel, Bäume mit Farbe, das Auto davor klar; `20_…` zeigt Arcade / vorherige Fassung (Weißmischung) / Endstand am Portal | **besser als vorher, gleichwertig zu Arcade**: die Weißmischung war ein milchiger Schleier (Sättigung 0,20), jetzt hell und farbig (0,26, Leuchtdichte 0,717 gegen Arcade 0,600); Arcades Gras bleibt greller (Palette), dafür hat Modern Licht und Schatten der Röhre und das Nachglühen nach dem Portal |
| `C1RN_*` (Frankfurt, 21:30, Regen) | nasse Straße mit gelben Laternen-Streifen voraus, rote Rücklicht-Spiegelung unter dem Auto, dichter Regen, Fenster | besser (nach 1.11); vorher oranger Fleck ums Auto |
| `N2_*` (Dortmund–Frankfurt km 121, 16 Uhr, Regen) | dichter Regen, nasse Fahrbahn, Gischt hinter dem GT | Regen besser; **schwächer**: der silberne GT ist heller und flacher als sein Sprite (Stoßfänger Mittel +13 %, p75 +34 %; vor der Halbkugel-Regel +53 %) |
| `03_N2_…` (Dortmund–Frankfurt km 121, 22 Uhr, Regen; Endstand) | Regen im Kegel, Spiegelung des Kegels, rote Streifen unter dem GT, Gischt rot beleuchtet | **besser** bei Regen, Spiegelung und Gischt; **schwächer**: der GT liest sich hellsilbern statt blaugrau wie sein Sprite (Abschnitt 3, Bild 21) |
| `N1_deck`, `N2N_deck` (1280×800, „Steam Deck“) | dasselbe mit der Stufe „Einfach“ der Effekte (Stand vor `2577b30`: nur der Nacht-Schimmer des Spielerautos ist seither farbiger) | Niederschlag und Gischt sichtbar, Bild füllt 16:10 |
| `21_spielerauto_nacht_…` (22 Uhr, „Mittel“; Spalten Arcade / neutraler Schimmer / Endstand) | Kompakt im Schnee, GT im Regen, Limousine klar | Kompakt jetzt bernstein wie das Sprite (vorher cremefarben), Limousine satt blau (Arcade dunkler marineblau); **schwächer**: der silberne GT liest sich heller und neutraler als Arcades blaugraues Sprite – gemessen ist es der Farbton, nicht die Helligkeit: im Clip N2N Median 42 / 75. Perzentil 47 von 255 in beiden Hälften, mittlere Farbe Arcade (43, 44, 61), Modern (44, 45, 56); Sättigung 0,73 × (`check_night`). Eine erste Rasterzählung „Kofferraumdeckel 1,6 ×“ lag auf dem Lichtkegel über dem Dach und ist falsch |

## 4. Tore auf dem Endstand (gemessen; Befehle aus dem Worktree, `XDG_DATA_HOME` absolut, nice 19/10)

| Tor | Befehl | Ergebnis |
|---|---|---|
| Import | `godot --headless --path . --import` | sauber, Exit 0 (28 s) |
| Skripte | `godot --headless --path . -s res://tests/check_scripts.gd` | „318 Skripte geprüft, 0 fehlerhaft“ |
| Tests (Vollauf 2 von 2, `866a74c`) | `tools/run_tests.sh` | 761 Einheitstests, **1 rot**, dazu `check_modern_stage` **rot** – beide Last (Last 15–20, sechs Agenten): (a) `test_modern_checks` „mit Wiedergabe“: Sitzung in 89 von 99 Bildern (< 90 %), Arcade-Bild, kopflos – nichts von R4; einzeln nachgefahren `tools/run_tests.sh test_modern_checks`: **3 von 3 grün** (129 von 136 Bildern); (b) `kern_zeit`: Einhängen eines Stücks 4,07 ms > 3 ms – der Kern-Test benutzt nur Straße/Randstreifen/Hintergrund/Licht/Overlay; im Wechsel nachgemessen (`--only=kern_zeit`): Kopf 1,59 / 1,58 ms, Basis `6e48405` 1,50 / **3,00 ms** (die Basis fiel einmal selbst durch) – Rauschen. Alles andere grün (u. a. `test_light_pool`, `test_weather`, `test_environment_rig`, `test_far_ground_water`, `test_props`) |
| `test_light_pool` auf `7f0eae2` | `tools/run_tests.sh test_light_pool` | 7 von 7 grün (neu: Aufwärm-Ebene) |
| Render-Prüfungen | `RENDER_CHECK_TIMEOUT=2400 tools/run_render_checks.sh all` (`866a74c`) | **„23 von 23 Render-Prüfdateien in Ordnung“** – darunter `check_start_km0`, `check_terrain_cover` (T1–T4, S1, C1, **K1**: 0,000 % Magenta), `check_light_base`, `check_night` (4 OK), `check_weather` (5 OK), beide Tabellen, `check_instance_budget_wald` (2.253 s, knapp unter 2.400 s); auf `7f0eae2` erneut `check_facade_render` (5 OK, `aufwaermen` mit Ebene 20) |
| Arcade gleich | `tools/golden.sh check` (`866a74c` und Endstand `7f0eae2`) | **„GOLDEN arcade: 20 von 20 identisch“**, **„GOLDEN arcade-ui: 17 von 17 identisch“**; auf dem Endstand `7f0eae2` noch einmal: **20 von 20** und **17 von 17 identisch** |
| Modern-Änderungsmelder | `tools/golden.sh modern-check` (`866a74c`) | 0 von 6 identisch – gewollt (Sonnenscheibe, Himmelsspiegelung, Halbkugel-Licht, Nacht-Füll-Licht, Mond); alle sechs Bilder angesehen (`m1/R4/modern_golden_new.jpg`), dann `modern-make` (Hashes = Bilder der Prüfung), Commit `83dbdac`; OpenGL-ES-Stufe OK (höchstens 2/255, PSNR 73,2 dB); auf `7f0eae2` `modern-check modern_s1_nacht`: **1 von 1 identisch** (die Lichtebene ändert kein Bild) |
| Sicht | `godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full` | alle OK: f1 0 Fälle bis 270 m, f1 Außenspuren 0 bis 260 m, f2 ≤ 0,596, f3 0 von 5.923 Zielen später, f7 0 Seiten, Modell 0 abweichend (254 s) |
| Weg | `godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full` | OK: kleinster Abstand 267,6 m (≥ 250), Schleifen frühestens nach 2.064 m (≥ 2.000) |
| Ganze Etappe | `tests/race/run_stage.gd` (Kiel – Hamburg, 21 Uhr, Regen, „Mittel“, Zeitraffer 4) | **ganz durchgefahren, 0 Skript-/Shaderfehler** auf `7f0eae2` (21 Uhr, Regen, Limousine, Saat 11, „Niedrig“, Zeitraffer 16, `m1/R4/sh/stage.sh`; erst mit „Mittel“/Zeitraffer 4 versucht – bei 1 Bild/s unter Last hätte die Etappe Stunden gebraucht): 95 km, Ergebnis gleich der Basis (Schnitt 123,4 km/h, 0 Zusammenstöße – bestimmter Lauf). `perf_stats` Kopf / Basis `6e48405`: `render()` im Mittel **5,30 / 5,35 ms**, höchstens 87,5 / 112,6 ms; Einhängen eines Stücks höchstens **5,29 / 9,82 ms**; **77 / 73** Zeichenaufrufe, **76.330 / 75.674** Dreiecke; Bildzeit Median 388 / 352 ms (llvmpipe, Last 17–19, je 528 Bilder) – R4 kostet im Skript nichts Messbares, auf der GPU 4 Aufrufe (Regen, Gischt, Spiegelungen) und < 1 % Dreiecke |
| Warm-up kalt | `tests/race3d/render/warmup_cold.gd` N1, N2 | siehe Abschnitt 2 |

## 5. Leistung (llvmpipe unter Xvfb, gemessen; echte Grafikchips und Steam Deck: abgeleitet)

Leistungstest des Spiels (`--bench=all --bench-seconds=10`, drei Szenen, 1280×720, Xvfb + llvmpipe, Last 15–21 durch
die anderen Pakete; `m1/R4/sh/bench.sh`, Ergebnisse `m1/R4/bench/*.json`). Kopf `7f0eae2` in allen vier Stufen,
Basis `6e48405` in „Mittel“ (nacheinander gefahren, nicht gleichzeitig):

| Stand | Stufe | Szene | Bilder/s | Median ms | Skript ms (Mittel / max) | Zeichenaufrufe | Dreiecke |
|---|---|---|---|---|---|---|---|
| base | medium | autobahn | 0.7 | 1415 | 5.06 / 16.6 | 155 | 132635 |
| base | medium | stadt_nacht_regen | 1.7 | 552 | 3.83 / 13.6 | 96 | 116356 |
| base | medium | berg_tunnel | 0.8 | 1177 | 6.15 / 16.2 | 95 | 104716 |
| head | medium | autobahn | 0.6 | 1749 | 2.48 / 3.8 | 156 | 131768 |
| head | medium | stadt_nacht_regen | 1.3 | 710 | 3.52 / 6.3 | 99 | 116813 |
| head | medium | berg_tunnel | 0.8 | 1154 | 3.08 / 5.8 | 95 | 104716 |
| head | deck | autobahn | 0.5 | 1820 | 2.90 / 5.1 | 148 | 126030 |
| head | deck | stadt_nacht_regen | 1.2 | 792 | 3.71 / 7.8 | 91 | 110335 |
| head | deck | berg_tunnel | 0.4 | 2179 | 6.52 / 21.7 | 90 | 100253 |
| head | low | autobahn | 2.8 | 320 | 2.81 / 8.8 | 129 | 104100 |
| head | low | stadt_nacht_regen | 1.9 | 445 | 3.23 / 10.4 | 84 | 101423 |
| head | low | berg_tunnel | 2.5 | 317 | 3.30 / 13.3 | 76 | 79928 |
| head | high | autobahn | 0.6 | 1468 | 2.54 / 3.5 | 183 | 164229 |
| head | high | stadt_nacht_regen | 1.4 | 648 | 2.70 / 10.3 | 133 | 159866 |
| head | high | berg_tunnel | 0.6 | 1591 | 2.79 / 5.1 | 126 | 153594 |

Gelesen (gemessen, mit dem Rauschen dieser Maschine): die Zeichenaufrufe steigen durch R4 um 1–3 je Szene (Regen-
bzw. Schneeteilchen ein Aufruf, Gischt ein Aufruf, Spiegelungen ein Aufruf je Ebene), die Dreiecke um < 1 %.
Die Skriptzeit je Bild liegt auf dem Kopf **niedriger** als auf der Basis (Mittel 2,5–3,5 ms gegen 3,8–6,2 ms) – das
ist Last-Rauschen, keine Verbesserung durch R4 (R4 fügt Skriptarbeit hinzu: `weather` ≤ 0,23 ms, `lights` ≤ 1,6 ms,
`flares` ≤ 1,4 ms je Bild im Höchstwert). Die Bildzeit in „Stadt bei Nacht im Regen“ (Mittel) stieg von 552 auf
710 ms Median: bei llvmpipe kosten 1.500 halbtransparente Regenstriche Füllrate in Software; auf einer echten
Grafikkarte ist das eine kleine Teilchenmenge (abgeleitet, nicht gemessen). Steam-Deck-Stufe „deck“: Effekte
„Einfach“ (1.500 Teilchen) – ob das Deck-Budget hält, zeigt nur der Leistungstest auf dem Gerät (abgeleitet).
Kaltstart (Abschnitt 2): `render()` im Mittel 4,7 ms (N1 Nacht Schnee) und 2,5 ms (N2 Regen), Einhängen eines Stücks
höchstens 2,06 / 1,55 ms, 78 / 118 Zeichenaufrufe, 105.720 / 118.658 Dreiecke („Mittel“).

## 6. Clips (60 fps fest, 20 s, „Hoch“, A/B)

`tools/ab_clip.sh` (Movie Maker, 60 fps fest, `CLIP_S=20`, Modern „Hoch“, Arcade links, Modern rechts; `m1/R4/sh/clips.sh`),
alle auf `7f0eae2`, im Abgabeordner:

| Clip | Was zu sehen ist | Urteil gegen Arcade |
|---|---|---|
| `clip_nacht_regen_verkehr_N2.mp4` (Dortmund – Frankfurt ab km 121, 22 Uhr, Regen, GT, Verkehr) | dichter Regen im Kegel, Spiegelung des Kegels und der Rücklichter eines Verkehrsautos als rote Streifen auf der nassen Fahrbahn, rückstrahlende Leitpfeile und Schilder, Radar-Schild | **besser**: Wetter und nasse Straße sind da, wo Arcade wenige Striche zeigt; **schwächer**: der GT liest sich grau statt blaugrau (gleiche Leuchtdichte) |
| `clip_schneefall_nacht_N1.mp4` (Hamburg – Hannover ab km 71, 22 Uhr, Schnee, Kompakt, Verkehr) | Schneefall dicht im Kegel, bei Tempo gezogen, Schneewälle, Rücklichter eines Überholers | **besser**: deutlich mehr Schnee in der Luft als Arcade, Schnee liegt am Rand; Kompakt in der Farbe des Sprites |
| `clip_tunnelausfahrt_tag_TEXIT.mp4` (Testetappe ab km 52,8, 12 Uhr, Limousine) | in der Röhre Lampen und Rücklichter, die Öffnung voraus hell überbelichtet (weißer Himmel, helles Grün), beim Hinausfahren rund 1,5 s Nachglühen über dem ganzen Bild, dann normaler Tag mit Sonnenscheibe | **gleichwertig bis besser**: Arcades Draußen ist greller grün, Modern hat dafür Raum, Licht der Röhre und das Nachglühen; kein milchiger Schleier mehr |

## 7. Abweichungen

1. **Niederschlag als zustandslose GPU-Teilchen** (MultiMesh, ein Zeichenaufruf) statt `GPUParticles3D`: ein
   Teilchenknoten hält Zustand je Bild auf der Grafikkarte – mit `--shot-fast` stünde er still, zwei Läufe gäben
   verschiedene Bilder (Regel 10), beim Ursprungsversatz spränge er. Gleiche Wirkung (Kamera-Raum, kein Schatten,
   im Tunnel aus), bestimmte Bilder.
2. **Gischt auch bei „Effekte: Aus“** (Tabelle: `spray` false): eine Wolke je Auto an der Stelle von Arcades
   Ellipse – sonst zeigte die kleinste Stufe weniger als Arcade (Entscheidung 1: „spray behind every car on wet road“).
3. **Spiegelungen der Lampen auf jeder Stufe** (Tabelle: `wet_reflections` nur „Voll“): analytische Vierecke,
   billig (ein Zeichenaufruf je Ebene); `wet_reflections` bleibt ungenutzt für eine spätere Bildschirm-Spiegelung.
4. **Sonnenscheibe an Arcades Stelle** (mittags vorn hoch), obwohl das Licht der hohen Sonne von hinten links kommt –
   Arcades eigene Abmachung (Panorama vorn, Sprites hinten links beleuchtet); bei tiefer Sonne stimmen beide überein.
5. **Spielerauto nachts**: neues vpbr-Uniform `fill_sheen` (Klarlack-Schimmer des Füll-Lichts) und `fill_tunnel` –
   kein „Licht“, sondern der Look-Hebel, den KRITIK-2 A2 von R4 verlangt.
6. Die Wettertabelle läuft in zwei eigenen Dateien (`check_weather_tabelle.gd` klar/Regen,
   `check_weather_tabelle_schnee.gd` Schnee), damit jede unter 900 s je Datei bleibt (alle 24 Starts: 933 s).
7. Dritte Nachtetappe der Deckel-Prüfung ist C1 (21:30, Regen) statt der Testetappe: deren Tunnellampen haben keine
   Pool-Reichweite (R5), dort gäbe es keine Lampe im Pool zu prüfen.
8. **Tunnelausfahrt mit Bildschirmtextur** (`866a74c`): Viereck und Nachglüh-Ebene lesen das Bild hinter sich (eine
   Bildkopie, nur solange sie zu sehen sind – nur an Tunnelausfahrten bei Tag). Eine Weißmischung ohne Kopie las sich
   milchig; Arcades Gesetz (× 1,7 + 0,25) geht nur mit dem Bild dahinter.
9. **Neue Schranke in `check_night spielerauto`**: Sättigung der Karosserie ≥ 0,7 × Arcade (vorher nur Helligkeit).

## 8. Vertragsfragen

1. §6 R4 nennt `GPUParticles3D` – mit Regel 10 (bestimmte Bilder) und dem schwimmenden Ursprung nicht vereinbar;
   Vorschlag: „Niederschlag als zustandslose Teilchen im Kamera-Raum“.
2. Gfx-Tabelle `effects`: `spray` false bei „Aus“ und `wet_reflections` nur bei „Voll“ widersprechen „keine Stufe
   zeigt weniger als Arcade“ bzw. der Abnahme „nasse Fahrbahn … Spiegelungen“ – Vorschlag: `spray` und analytische
   Spiegelungen auf jeder Stufe, `wet_reflections` für eine echte Bildschirm-Spiegelung (W7) reservieren.
3. A-13: die Fern-Konstanten der Modelle sind gegen `VEHICLE_LOOK` gemessen; R4 hat dort `hemi_side/hemi_down`
   (beide Klassen, vpbr und glass, gleich – das Verhältnis Scheibe/Lack bleibt) und das Nacht-Füll-Licht (nur
   Spielerauto) geändert. Nachmessen durch die Modellpakete empfohlen.
4. Tunnel-Lampen ohne Pool-Reichweite (R5): sie zählen nicht zum Punktlicht-Pool.
5. `assets/shaders/modern/flare.gdshader` steht in der W3-Spalte von §5 bei niemandem (W1: R3); R4 besitzt
   `layers/flares.gd` und hat den Shader um die Variante `CE_STREAK` (Spiegelungen auf nasser Fahrbahn) erweitert –
   Vorschlag: der Shader gehört zum Besitzer von `flares.gd`.

## 9. Für die nächsten Pakete

Siehe Ergebnis (`notes_for_next`); ausführlich:
1. **R5**: der Tunnel-Builder ruft in `update()` `renderer.get("env").set_zone("tunnel", amount)` (duck-typed, `has_method`);
   ab dem ersten Aufruf gilt nur noch der gesetzte Wert. Die Belichtungsrampe braucht Builder „tunnel“ und die Röhre als
   Verdecker des Vierecks. Tunnellampen brauchen eine Pool-Reichweite (`range` in `add_lamps`), sonst zählen sie nicht
   zum Punktlicht-Pool. Brücken über Wasser: `set_zone("bridge", 0…1)` (Wind bis +50 %).
2. **R6**: `add_lamps()` und seine Rollen sind unverändert; `builders/props.gd` unverändert (Einzeiler für eigene
   Bauteile beim Zusammenführen behalten).
3. **FIX-M2 / Zusammenführung**: FIX-M2 (B-03 Blaulicht, B-05 Abblendlicht, B-06 Lack) arbeitet auf derselben Basis in
   R4-Dateien (`vpbr.gdshader`, `modern_materials.gd`, `layers/{vehicles,lights,flares}.gd`) – Konflikte erwartet; R4
   hat `VEHICLE_LOOK` (hemi_side/down, fill_night/sheen/sheen_tint/tunnel/shade) und `fill_*`-Uniforms neu.
4. **Lack (offen)**: der silberne GT nachts im Regen liest sich hellsilbern statt blaugrau – gleiche Leuchtdichte, weniger Blau (Sättigung 0,73 ×),
   vermutlich der Klarlack, der den grauen Regenhimmel spiegelt (`env_night` 0,35) statt Arcades Nachttönung; Dämmerung: die
   Limousine spiegelt den lila Himmel (unten Sättigung 0,8 ×, +7 % hell). Nicht mehr angefasst, weil jede Änderung
   an `vpbr` den Lauf aller Render-Prüfungen (2 h 10 min) und der Modern-Hashes verlangt hätte.
5. **R7**: Zeitfaktor in `billboard.gdshader` gegen das Relief der Impostoren in Dämmerung/Nacht (A-10, nicht gemacht).
6. **Modellpakete**: Fern-Konstanten (`TRAFFIC_GLASS_FAR`, `FAR_PLATE`, `GLASS_FAR`, `CHECK_MEAN_EXP`) gegen den
   geänderten `VEHICLE_LOOK` (hemi_side 0,72 / hemi_down 0,5 für vpbr und glass) nachmessen.
7. **Prüfdauern** (Last 15–20): `check_instance_budget_wald` 2.253 s von 2.400 s – bei mehr Last Zeitlimit;
   `check_weather` 941 s, Tabelle 621 s + 302 s, `check_night` 435 s.




