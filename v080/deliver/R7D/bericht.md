# R7d – „Freie Strecke“ (Vertrag A-27)

Zweig `wip/v080-r7d`, Basis `720eaf4` (RINT-M3). Arbeitsbaum `.claude/worktrees/wf_a71eeb2e-3b7-1`.
Arbeitsordner `scratchpad/v080/m1/R7D` (Skripte `sh/`, Logs `logs/`, Bilder `shots/`, Tore `gates/`).

Ziel: Auf der offenen Autobahn erkennt man Modern auf den ersten Blick und findet es deutlich schöner als Arcade – bei
Tag, Dämmerung, Nacht, Regen und Schnee –, ohne dass etwas, worauf der Spieler reagiert, schlechter zu sehen ist.

## 1. Kurzfassung

<!-- KURZ -->

## 2. Was gebaut ist

### 2.1 Himmel mit Haufenwolken
- Neuer Himmelsshader `assets/shaders/modern/sky2d.gdshader` hinter der Leinwand des Hintergrunds: Arcades Verlauf,
  Glühen, Sterne, Mond und Sonne an Arcades Stellen (Arcades Formeln).
- Neue Wolkenschicht `clouds2d.gdshader` in halber Auflösung in einem eigenen Viewport: Haufen auf flacher Basis
  (1.600 m), Kuppeln bis 450 m darüber, ein Blickstrahl durch die Schicht in Proben auf festen Höhen (keine Streifen
  zwischen den Zeilen), Treffer mit Regula falsi, weicher Rand, Licht nach Höhe im Haufen und Neigung zur Sonne,
  Silberrand vor der Sonne, Dunst zum Horizont, ferne Haufen gehen in ein Band über. Regen und Schnee: geschlossene,
  strukturierte Decke. Nachts dunkle Silhouetten vor Mond und Sternen.
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
- Felder (230 × 135 m) mit Frucht: Wiese, junges Getreide, dunkle Reihenkultur, Acker oder Stoppel, die Akzentfrucht
  der Landschaft; Saatreihen, Fahrgassen, Mähstreifen, Vorgewende, Hecken (Knicks) an rund 38 % der Grenzen. Die
  Feldfarben bleiben bis in die Ferne stehen (vorher war jenseits von ~200 m alles ein Mittelgrün).
- Gras: trockenere und frischere Büschel, blühende Flecken im Bankett und im Graben.

### 2.4 Fahrbahn
- **Betonabschnitte** genau dort, wo der Klang Beton spielt (`RoadBuilder.is_concrete()` = `AudioFeed`-Entscheidung,
  Test): Platten 5 m × eine Spur, Fugen quer und längs, polierte Radspuren, nie heller als Asphalt.
- **Asphaltalter** in Abschnitten von 240 m mit Nähten (erneuert dunkler, alt gröber, nie heller).
- **Lesbare Markierungen**: ferne Linien ¼ Pixel je Seite breiter (wie Arcades ganze Pixel), der Himmelsspiegel auf
  nasser Fahrbahn erst ab 110–220 m, nasse Farbe nicht mehr 7 % dunkler.

### 2.5 Bäume
- Jede Pflanze in eigenem, stabilem Ton (±6 % Helligkeit, ±3 % Farbe), nahes Modell und Vertretung gleich.

### 2.6 Bewusst nicht gemacht
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
  0,85), Linienkontrast 20 m 1,009 ×, 60 m 1,010 × (≥ 0,95), Gras 0,764 × (der Schatten ist sichtbar, ≤ 0,93);
  **Auto 0 von 22.779 Pixeln anders** (Maske ohne Sonnenschatten, um 2 px geschrumpft); bei Regen 0 Pixel anders.
- **fern** – F4: Nebelanteil des Bodens je Bildzeile (Nebelfarbe weiß gegen schwarz, Zeilen über die Kamera
  bestimmt, 80. Perzentil, Anzeigeformel) gegen Arcades 0,7 × t. Tag, Dämmerung, Regen, Schnee: Modern zeigt am Boden
  **keinen** Nebel (0,00 gegen das Gesetz 0,54–0,57); Regen 22 Uhr im Mittel 0,22 gegen 0,58. Größter Überschuss
  überall +0,000. Modern ist nirgends nebliger als Arcade.

## 4. Bilder

A/B-Bögen (Arcade links, Modern rechts, „Hoch“, Bild nach 3 s) in `shots/ab/hoch/`, Deck in `shots/ab/deck/`:

| Ort | Bedingungen | Bemerkung |
|---|---|---|
| S1 (Kiel–Hamburg km 2) | 8 Uhr, 12 Uhr, 19:30, 22 Uhr, Regen, Regen 22 Uhr, Schnee | Haufenwolken, Felder bis zum Horizont, Wolkenschatten im Gras |
| S3 (km 60) | dieselben sieben | Dämmerung: Kuppen rosa angestrahlt, Unterseiten mauve; Regen: strukturierte Decke, nasse Spiegelung erst in der Ferne |
| B1 (km 45) | 12 Uhr | Betonabschnitt |
| S0 (Start km 0) | 12 Uhr | Startaufstellung unverändert lesbar |
| S4 (km 80, 50 km/h) | 12 Uhr | |
| T2 (Kassel–Würzburg km 61,9) | 15 Uhr | Beton mit Plattenfugen, Wolkenschatten auf dem Hang |
| S1 Deck | 12 Uhr | gleiches Bild mit `sky_steps` 16 |

Clips (20 s, Arcade und Modern nebeneinander, „Hoch“, Autopilot ab 140 km/h) in `clips/`: `freie_strecke_tag.mp4`
(Kiel–Hamburg ab km 22, 12 Uhr, in einen Betonabschnitt) und `freie_strecke_daemmerung.mp4` (ab km 40, 19:30).

<!-- REST -->
