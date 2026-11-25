# QA-mid – Zwischenabnahme: das ganze Rennen Kiel – Nürnberg in Modern

Stand der Prüfung: `6092197` (wip/v080-r7d = RINT-M3 + R7d); Korrekturen auf `wip/v080-qamid-fix`, FIX-Kopf `072f9ec`,
Testbuild 2 aus `c5533a3`. Arbeitsordner `scratchpad/v080/m1/QA-MID` (Skripte `sh/`,
Läufe `runs/`, Fotos `shots/`, Bögen `sheets/`, Vergleichsbilder `ab/`, Clips `clips/`, Leistung `bench/`).

Vertrag (Welle 5): „whole race Kiel – Nürnberg in Modern in every condition; all render checks; bench per preset; A/B
sheets and clips (night rain, snow, tunnel, bridge, city); test build 2; gate-2 package.“

## 1. Kurzfassung

**Ergebnis: Modern trägt das ganze Rennen Kiel – Nürnberg in jeder Bedingung – ohne Fehler der Engine, mit
derselben Simulation wie Arcade, und fast überall auf den ersten Blick schöner als Arcade.** Drei Bildfehler gefunden
und behoben, im Spiel nachgeprüft; kein offener Fehler, der den Zwischenstand 2 aufhält.

- **48 Rennläufe** (7.240 km, 7 Bedingungen auf dem Hauptweg plus der Weg über Frankfurt), **602 Fotos alle angesehen**;
  **0 Engine-Fehler und -Warnungen**; Prüfsumme der Simulation Modern = Arcade Bit für Bit auf allen fünf
  Hauptetappen (§3).
- **Befunde** (§6): Q-01 Schattenstreifen auf dem Tunnelhügel bei tiefer Sonne (Schattenakne, erste Diagnose falsch,
  zurückgenommen; behoben, indem der Hügel keinen Schatten wirft), Q-02 Fichten im Schnee fast weiß (jetzt
  dunkelgrün mit Schneeflecken), Q-04 Ausfahrtsloch des Tunnels beige statt weiß (Weißabgleich, jetzt farbgleich mit
  Arcade). Q-03 war ein Fehler des Messwerkzeugs (Fotos bis 1,8 km zu spät), behoben, bevor die meisten Läufe
  fuhren. Drei Notizen ohne Handlungsbedarf (N-01 … N-03).
- **Vergleichsbilder und Clips** (§7): Tunnel, Brücke, Stadt, Regennacht, Schnee, Heide – Modern gleich oder besser
  als Arcade; schlechter waren nur die Schneebilder auf `6092197` (Wald, Tunnel Valík, Schnee-Clip) – auf dem FIX-Kopf neu
  aufgenommen gleich bis besser.
- **Tore** auf dem FIX-Kopf `072f9ec` (§4): 855 Tests / 0 fehlgeschlagen; 32 von 32 Render-Prüfdateien in Ordnung.
- **Leistung** (§5): nur Software-Grafik messbar – Skriptzeit 2,6–3,4 ms je Bild, Zeichenaufrufe 70–220, Stufen wie
  geplant gestaffelt. **Die echten Zahlen kommen vom Steam Deck im ZS2** (Leistungstest, Checkliste C.2).
- **Offene Punkte aus R7d** (§8): Nacht erledigt; Regen-/Schneenacht etwas heller (behalten, im ZS2 fragen);
  Schneefelder und Limousinenlack in der Dämmerung bleiben bekannt und offen.
- **Weiter**: ZS2 aus `c5533a3` (= `072f9ec` + Golden-Liste `modern_slice`, nach Ansehen der Bilder neu) – Testbuild 2,
  `was_neu.md` und Checkliste.

## 2. Methode

- **Rennen**: der Hauptweg Kiel – Hamburg – Hannover – Kassel – Würzburg – Nürnberg (5 Etappen, 730 km) in sieben
  Bedingungen (8, 12, 19:30 und 22 Uhr klar, Regen 12 und 22 Uhr, Schnee 12 Uhr), der Weg über Frankfurt (Hamburg –
  Bremen – Dortmund – Frankfurt – Würzburg, 700 km eigene Etappen) bei 12 Uhr und Regen 22 Uhr; Autopilot, Seed 7,
  Zeitraffer 40, „Hoch“, echtes Streaming in Fäden (`sh/stage_shots.gd`, aus NACH-RINT): Fotos alle 15 km, vor jeder
  Tankstelle, an Tunnelportal, -mitte und -ausfahrt und vor dem Ziel; je Lauf Fehler und Warnungen der Engine
  (`ERRORS`), Leistung (`PERF`), Ergebnis und eine Prüfsumme der Simulation je Sekunde (`HASHES`). Je Hauptetappe ein
  Arcade-Lauf zum Vergleich der Prüfsumme.
- **Messfehler des Werkzeugs gefunden und behoben**: Bei Zeitraffer 40 schafft llvmpipe etwa 1 Bild je Sekunde – ein
  Bild springt 1,3 s Spielzeit (bis ~100 m Strecke) weiter. Bei 235 km/h kam das Nachladen nicht hinterher: Fotos
  zeigten das Auto auf dem Fernboden ohne Straße (`alt_ohne_halt/`, Kiel – Hamburg 12 Uhr km 45 / 60). Im Spiel mit
  30–60 Bildern je Sekunde rückt ein Bild 1–2 m vor; das kann dort nicht geschehen. Jetzt läuft die Simulation ab
  jedem Fotopunkt in Echtzeit (60 Schritte je Sekunde, höchstens 8 je Bild), bis der Streamer alles geladen hat
  (`is_idle()`), dann wird fotografiert. Jeder Schritt bleibt 1/60 s – die Prüfsumme mit Fotos ist **identisch** mit der
  ohne (`087ade…`, 347 s). Ein erster Versuch mit Zeitraffer 0 änderte die Simulation (Schritte mit Länge 0 ziehen
  Zufallszahlen) – verworfen.

## 3. Rennläufe (`runs/`, `sheets/`, `logs/qrun.log`)

- **48 von 48 Läufen fertig**, jeder mit `ok`: 7.240 km, 20.111 s Spielzeit, 6,3 h Rechenzeit (zwei Läufe zugleich,
  nice 10). **Engine-Fehler und -Warnungen: 0 in allen 48** (`ERRORS err=0 warn=0`).
- **602 Fotos** auf 43 Bögen (je Lauf einer, die Arcade-Vergleichsläufe ohne Fotos) – **alle angesehen**. Die ersten neun
  Läufe (Kiel – Hamburg 8/12/19:30/22 Uhr, Regen 12/22, Schnee; Hamburg – Hannover 12 und 22 Uhr) liefen noch mit
  `stage_shots.gd` v1 (Fotos bis 1,8 km hinter dem Punkt), alle übrigen mit v2 (±80 m, Tunnelportal, -mitte,
  -ausfahrt und Tankstellen genau getroffen; Q-03).
- **Prüfsumme der Simulation Modern = Arcade** auf allen fünf Hauptetappen bei 12 Uhr (je Sekunde Spieler und jedes
  Verkehrsauto, Bit für Bit; `sh/hashcmp.sh`), `ERGEBNIS` ohne `gfx` ebenfalls gleich:

  | Etappe | Sekunden | Prüfsumme | Ergebnis |
  |---|---|---|---|
  | Kiel – Hamburg | 347 | `087ade2e…` gleich | gleich |
  | Hamburg – Hannover | 323 | `2d0bcf4a…` gleich | gleich |
  | Hannover – Kassel | 428 | `d9073c00…` gleich | gleich |
  | Kassel – Würzburg | 569 | `d7ab0bd1…` gleich | gleich |
  | Würzburg – Nürnberg | 336 | `f8778f3d…` gleich | gleich |

- **Bild über das ganze Rennen** (Tag, Morgen, Dämmerung, Nacht, Regen Tag/Nacht, Schnee): Straße überall geladen,
  Tunnel (Elbtunnel mit Portal, Röhre, Ausfahrt), Tankstellen (Tag und Nacht beleuchtet), Blitzer- und Radarschilder,
  Städte Hamburg, Hannover, Kassel, Würzburg, Nürnberg, Bremen, Dortmund, Frankfurt bei Tag und Nacht, Heide, Wald,
  Mittelgebirge, Ruhrgebiet. Gefunden: Q-01 (Tunnelhügel in der Abendsonne) und Q-02 (Fichten im Schnee) – beide
  behoben; sonst nur Notizen (N-01 … N-03) und bekannte Punkte aus RINT-M3 (Lack der Limousine in der Dämmerung
  grau-lila, A-29/AS5b).

## 4. Tore auf dem FIX-Kopf `072f9ec` (`fix/gates/`, `sh/fixgates.sh`)

Zweig `wip/v080-qamid-fix` auf `6092197`: `b18b0d6` Fichten/Palmen im Schnee (Q-02), `18368c3` + `f93e5d7` Weißabgleich
der Tunnelausfahrt (Q-04), `beb69d2` → `5dea6b5` (falscher erster Versuch zu Q-01, zurückgenommen), `072f9ec` Hügel ohne
Schattenwurf (Q-01).

| Tor | Ergebnis |
|---|---|
| `tools/run_tests.sh` (alles: Skripte, Einheiten, Szenarien, netzweite Prüfungen) | **855 Tests, 0 fehlgeschlagen** (R7d 851 + Blätterschnee 3 + Weißabgleich 1; der Test zum geglätteten Hügel ging mit `5dea6b5` wieder heraus, die Hügel-Prüfung steckt jetzt im Commit-Test des Tunnels), 1.219 s; Sicht F1/F2/F3/F7, Pfad, Sichtmodell OK |
| `tools/run_render_checks.sh` | **32 von 32 Render-Prüfdateien in Ordnung** (5.702 s; u. a. Helligkeit Modern/Arcade Tag ×1,00, Wetter-Tabelle Schnee 0,98–0,99 × Arcade, Fenster 16:10/21:9, Parität der Straße, Tunnel und Brücken ohne Magenta, Glühen im Tunnel und an der Ausfahrt unverändert) |
| `tools/golden.sh check` auf `c5533a3` (Arcade gegen v0.7.0) | **Arcade bildgleich**: 20 von 20 Rennbildern und 17 von 17 Menübildern identisch (422 s) |
| `tools/golden.sh modern-make` auf `072f9ec` | 6 Modern-Bilder neu, alle angesehen (`zs2/goldens_modern_zs2.jpg`), Liste in `c5533a3` |

Auf `b18b0d6` liefen beide Tore schon einmal vollständig: 855 / 0 und 32 von 32 Render-Prüfdateien in Ordnung. Ein
Neustart des Rechners (gegen 00:32) brach die Render-Prüfungen auf `072f9ec` ab; sie liefen danach vollständig neu.

## 5. Leistungstest je Voreinstellung (eingebauter Leistungstest, `bench/`, Stand `6092197`)

Der Leistungstest des Spiels (drei feste Szenen je 20 s) je Voreinstellung, 1280 × 720, **Software-Grafik llvmpipe**
auf 4 Kernen neben einem zweiten Lauf – die Bilder je Sekunde sagen über eine Grafikkarte oder das Steam Deck nichts
aus; vergleichbar sind die Verhältnisse und die Zahlen, die nicht vom Rasterisierer abhängen:

| Voreinstellung | Szene | Bilder/s | p95 ms | Skript ms | Draw Calls | Primitive |
|---|---|---|---|---|---|---|
| deck | Autobahn bei Tag | 1.0 | 1157 | 2.58 | 162 | 136902 |
| deck | Stadt bei Nacht im Regen | 2.4 | 472 | 3.03 | 127 | 172655 |
| deck | Bergstrecke mit Tunnel | 1.3 | 819 | 2.78 | 95 | 117234 |
| low | Autobahn bei Tag | 4.4 | 260 | 2.66 | 147 | 116150 |
| low | Stadt bei Nacht im Regen | 2.9 | 417 | 3.11 | 112 | 149867 |
| low | Bergstrecke mit Tunnel | 4.8 | 273 | 2.82 | 70 | 95176 |
| medium | Autobahn bei Tag | 1.0 | 1100 | 2.60 | 171 | 144944 |
| medium | Stadt bei Nacht im Regen | 2.0 | 613 | 3.17 | 167 | 232780 |
| medium | Bergstrecke mit Tunnel | 1.3 | 872 | 2.85 | 102 | 125931 |
| high | Autobahn bei Tag | 0.8 | 1363 | 2.92 | 195 | 178720 |
| high | Stadt bei Nacht im Regen | 1.9 | 636 | 3.41 | 220 | 320034 |
| high | Bergstrecke mit Tunnel | 1.1 | 1032 | 3.04 | 131 | 166878 |

- **Skriptzeit 2,6–3,4 ms je Bild** in allen Szenen und Stufen (CPU, gilt auch für das Deck in der Größenordnung).
- **Zeichenaufrufe 70–220, Primitive 95.000–320.000** – „Niedrig“ < „Steam Deck“ < „Mittel“ < „Hoch“ wie geplant.
- Die Autobahn bei Tag kostet in der Software-Grafik am meisten (Himmel mit Wolken, R7d: rund die Hälfte der
  zusätzlichen Pixelarbeit); „Niedrig“ schaltet die Wolkenproben herunter und ist dort 4,4 × so schnell.
- Der Vorschlag des Tests („suggested_preset“) ist auf llvmpipe bedeutungslos. **Auf dem Steam Deck messen (ZS2).**

## 6. Befunde

| Nr. | Wo | Befund | Stand |
|---|---|---|---|
| Q-01 | jedes Tunnelportal, tiefe Sonne (Hamburg – Hannover 19:30, Elbtunnel km 3,7) | regelmäßige helle Schrägstreifen auf dem Hügel über dem Portal – **Schattenakne**: die tiefe Sonne (13°) streift die große Stirnfläche, die Schattenkarte schattet den Hang mit sich selbst (gleiche Stelle ohne Sonnenschatten: glatt, `fix/vorher_nachher/tunnel_huegel_schatten_test.jpg`). Erste Annahme (Rippen aus Arcades Buckeln, `beb69d2` geglättet) war falsch – im selben Rennlauf nachgestellt blieben die Streifen (Querkontrast 0,93 → 0,93); zurückgenommen `5dea6b5` | behoben `072f9ec`: der Hügel ist ein eigenes Netz `TunnelHill` ohne Schattenwurf (Rahmen, Stirnwand, Flügelmauern werfen weiter Schatten), Tests; im selben Rennlauf nachgeprüft: glatter Hang, Querkontrast 0,93 → 0,62 (`fix/vorher_nachher/tunnel_huegel_rennen*.jpg`) |
| Q-02 | verschneite Fichten (Hannover – Kassel, Kassel – Würzburg; RINT-M3 Notiz 4) | Fichten im Schnee fast ganz weiß mit dünnen grünen Strichen – sie verschwinden vor weißem Boden und Himmel; gemessen: 83 % der Nadelfläche zeigt nach oben, im Mittel 68 % Schneeweiß (Eiche 16, Buche 15, Birke 18, Kiefer 26 %); Arcade zeigt die Fichte dunkelgrün (15 % Graustich) | behoben `b18b0d6`: Fichte (und Palme, 0,83) tragen Schnee nur in Flecken (Anteil 0,29 / 0,24, Zellen im Modellraum), Mittel ≈ 0,2 wie Eiche und Birke; Test `test_leaf_snow` über alle Blätternetze; Bildnachweis `fix/spruce/` (15/40/100/200 m), im Spiel `fix/ab/schnee_wald_ab_00.jpg` – dunkelgrüne Fichten mit Schneeflecken neben Arcades Fichten |
| Q-04 | jede Tunnelausfahrt bei Tag, deutlich im Schnee (Tunel Valík, RINT-M3 Notiz 4a; Elbtunnel ab 100–200 m vor der Ausfahrt) | die Landschaft im Ausfahrtsloch beige-gelb statt weiß: in der Röhre mischt das Rig das Licht zu Bernstein (`Palette.TUNNEL_AMBIENT`), das Draußen hinter dem Überstrahlungsviereck ist in diesem Licht gezeichnet; Arcade zeichnet es in der Außenpalette | behoben `18368c3` (+ Doku `f93e5d7`): Weißabgleich im Viereck (`exit_white_balance`, gleiche Helligkeit), Test; im Spiel nachgeprüft (`fix/vorher_nachher/valik_schnee.jpg`): helle Pixel im Ausfahrtsloch RGB 240/227/200 (B/R 0,84) → 226/230/234 (B/R 1,04) = Arcade 226/230/234; ohne Schnee 12 Uhr (`fix/vorher_nachher/tunnel_ausfahrt.jpg`): 174/160/123 → 163/162/138, Arcade 182/185/157 – der Stich geht auch dort heraus, die Röhre bleibt unverändert |
| Q-03 | Messwerkzeug | Fotos lagen bis 1,8 km hinter ihrem Punkt (Zeitraffer 40: ein Bild bis 80 Schritte) | `stage_shots.gd` v2: Schritte vor dem Punkt begrenzt, ±80 m |
| N-01 | Läden `building_shop` nachts | Schaufenster reinweiß ausgebrannt (255) – so hell wie Arcades Lichtschicht (dort fast weiß); die AS5a-Läden haben eine Auslage | Notiz, kein Fehler gegen Arcade |
| N-02 | Autopilot (Spiel, nicht Modern) | fährt in Tempo-50-Zonen ohne Blitzer bis 235 km/h (Hamburg, Nürnberg nachts), bei Tag meist 40–70 | Notiz für die Spiellogik; in Arcade und Modern gleich (Prüfsummen) |
| N-03 | Leistungsspitzen im Zeitraffer | Haken `landmarks` bis 47 ms = Nachrechnen des Sichtkorridors (`corridor.sync_calls` 1.467–5.438 je Lauf) – bekannt aus RINT-M3: im Zeitraffer 4 null | kein Fehler im Spiel |

## 7. Vergleichsbilder und Clips Arcade | Modern (`ab/`, `fix/ab/`, `clips/`, `sheets/clip_*.jpg`)

Je Bild ein Rennstart an genau der Stelle (`media_pos.txt`, Seed fest, Autopilot, „Hoch“), Arcade und Modern
nebeneinander; je Clip 20 s mit 30 Bildern je Sekunde (`clips_pos.txt`), daraus ein Bogen mit jedem 75. Bild. Positionen
nach dem ersten Durchgang korrigiert (Arcades Welt rückt bei 100 km/h etwa 0,33 km je Sekunde vor – die ersten Bilder
lagen 1 km hinter Portal, Brücke und Altstadt). Alle Bilder und Bögen angesehen.

| Bild / Clip | Ort, Bedingung | Urteil | Was man sieht |
|---|---|---|---|
| `tunnel_portal` | Elbtunnel, Portal, 12 Uhr | **besser** | Hügel mit Grasstruktur, Portal aus Beton mit Tiefe und Laibung, Leitplanke mit Pfosten; Arcade zeigt durch die Röhre Bäume der Ausfahrt (Modern: dunkle Röhre wie in echt) |
| `tunnel_innen` | Elbtunnel, Röhre, 12 Uhr | **besser (Röhre), Auto bekannt dunkler** | Fliesenpaneele, Notgehweg, Deckenträger, Leuchten mit Schein; das eigene Auto wirkt im Tunnel dunkler als Arcades Bild (bekannt seit ZS1, RINT-M3 §7) |
| `tunnel_ausfahrt` | Elbtunnel, Ausfahrt, 12 Uhr | **gleich bis besser** | überstrahltes Draußen im Ausfahrtsloch wie Arcade, Schild „Tankstelle 5 km“ an der Wand gleich lesbar, Lkw als Modell mit Spiegel; Auto dunkler (bekannt) |
| `bruecke_tag` | Köhlbrandbrücke, 12 Uhr | **besser** | Köhlbrandbrücke: Elbe mit Wellen und Spiegelung, Kaimauer und Ufer, Gehweg gepflastert, Seile und Pylone in 3D, Schiffe, Elbphilharmonie und Hafenkran am Horizont |
| `bruecke_nacht` | Köhlbrandbrücke, 22 Uhr | **gleich bis besser** | Nacht wie Arcade (Elbphilharmonie und Stadt erleuchtet, dunkles Wasser), dazu Seile im Laternenlicht, gepflasterter Gehweg, Auto im Lampenlicht klar zu sehen |
| `stadt_nuernberg_tag` | Nürnberg Altstadt, 12 Uhr | **besser** | Altstadt in 3D (Fachwerk, Erker, Giebel mit Tiefe), Baum mit Schatten auf Fahrbahn und Gehweg, Wolkenhimmel; das Auto steht im Hausschatten (dunkler als Arcades Bild, richtig so) |
| `stadt_nuernberg_nacht` | Nürnberg Altstadt, 22 Uhr Regen | **besser** | Regennacht in der Altstadt: nasse Fahrbahn spiegelt Laternen und Rücklichter, erleuchtete Fenster im Fachwerk, Regen im Laternenlicht, Gehwege und Laternen in 3D |
| `regennacht_berge` | Kassel – Würzburg km 60, 22 Uhr Regen | **besser** | Regenstriche im Abblendlicht, nasse Fahrbahn mit Rücklichtspiegelung und Gischt, Wolkendecke; Leitpfosten und Warnschild gleich gut lesbar wie Arcade |
| `schnee_wald` | Hannover – Kassel km 100, 12 Uhr Schnee | **auf 6092197 schlechter, mit b18b0d6 gleich bis besser** | vorher: weiße Fichten-Gerippe gegen Arcades dunkelgrüne Fichten (Q-02); nachher dunkelgrüne Fichten mit Schneeflecken, Schneefall, Schneeränder an der Fahrbahn – vorher_nachher/schnee_wald.jpg |
| `schnee_nacht` | Hannover – Kassel km 100, 22 Uhr Schnee | **gleich (Fichten auf 6092197 blass, mit b18b0d6 dunkel)** | Schneefall im Abblendlicht, Schneeboden bläulich wie Arcade, Wolkendecke etwas heller (K-3, 1,22×); die Fichten stehen auf 6092197 blassgrau statt als dunkle Silhouetten – Nachher-Bild in fix/ab |
| `heide_tag` | Hamburg – Hannover km 70, 15 Uhr | **besser** | Heide mit Heideflächen bis zum Horizont, Kiefern und Birken in 3D, Wolkenhimmel mit Wolkenschatten, Sportwagen als Modell; Bankett mit Gras und Leitplanke in Tiefe |
| `valik_schnee` | Prag – Nürnberg, Tunel Valík, 8 Uhr Schnee | **auf 6092197 schlechter, mit 18368c3 gleich** | Ausfahrtsloch vorher beige-gelb mit beigen Fichten-Gerippen (Q-02, Q-04), nachher weiß mit dunkelgrünen Fichten wie Arcade (Farbe gemessen gleich) |
| `clip_tunnel` | Clip Elbtunnel, 12 Uhr (6092197) | **gleich bis besser** | 20 s Anfahrt – Portal – Röhre – Ausfahrt – Tankstellenanfahrt: Ablauf wie Arcade, kein Springen, Ausfahrt überstrahlt wie Arcade; Modern mit Röhrendetails, Modellen, Wolken (sheets/clip_tunnel.jpg) |
| `clip_bruecke_nacht` | Clip Köhlbrandbrücke, 22 Uhr | **gleich bis besser** | 20 s Kiel – Hamburg km 74,5 bei Nacht: Stadtrand mit Fachwerkhäusern und Laternen, Auffahrt und Köhlbrandbrücke; Ablauf, Verkehr und Tempo wie Arcade; Modern mit Pylon in 3D im Laternenlicht, beleuchteten Seilen, gepflastertem Gehweg, Michel und Elbphilharmonie, Auto im Lampenlicht klar blau (sheets/clip_bruecke_nacht.jpg) |
| `clip_stadt_nuernberg` | Clip Nürnberg, 19:30 Uhr | **besser (Stadt), Lack bekannt** | 20 s Würzburg – Nürnberg km 103 in der Dämmerung bis über die Pegnitzbrücke: Altstadt in 3D (Fachwerk mit Tiefe, Erker, Blumenkästen, erleuchtete Fenster), Brückengeländer, gepflasterte Gehwege, angestrahlte Abendwolken; Ablauf und Verkehr wie Arcade, kein Springen; der Lack der Limousine wirkt in der Dämmerung grau-lila (bekannt, A-29/AS5b) (sheets/clip_stadt_nuernberg.jpg) |
| `clip_regennacht` | Clip Kassel – Würzburg, 22 Uhr Regen | **besser** | 20 s Kassel – Würzburg km 58 bei Nacht im Regen, 140–205 km/h: Regenstriche im Abblendlicht, nasse Fahrbahn mit Lichtspiegelung, Gischt hinter dem Vordermann, Fichten gegen eine etwas hellere Wolkendecke (K-3); Leitpfosten, Markierung und Richtungstafeln so gut lesbar wie in Arcade; Ablauf wie Arcade, kein Springen (sheets/clip_regennacht.jpg) |
| `clip_schnee` | Clip Hannover – Kassel, 12 Uhr Schnee (6092197) | **auf 6092197 schlechter (Fichten weiß, Q-02)** | 20 s Hannover – Kassel km 98 im Schnee, 130–190 km/h: Schneefall, Schneeränder, verschneite Leitplanken und Laubbäume gut; die Fichten stehen als weiße Gerippe vor weißem Boden, Arcades Fichten dunkelgrün – genau Q-02; Clip auf 072f9ec (clip_schnee_fix) folgt (sheets/clip_schnee.jpg) |
| `clip_tunnel_fix` | Clip Elbtunnel, 12 Uhr (FIX-Kopf) | **gleich bis besser (072f9ec)** | derselbe Clip auf dem FIX-Kopf: Ablauf, Verkehr, Portal, Röhre wie vorher; das Ausfahrtsloch jetzt mit grünem Gras, Bäumen und hellem Himmel wie Arcade statt beige (Q-04) – fix/vorher_nachher/clip_tunnel_ausfahrt_10s.jpg, sheets/clip_tunnel_fix.jpg |
| `clip_schnee_fix` | Clip Hannover – Kassel, 12 Uhr Schnee (FIX-Kopf) | **gleich bis besser (c5533a3 = 072f9ec + Goldens)** | derselbe Clip auf dem FIX-Kopf: die Fichten stehen dunkelgrün mit Schneeflecken an der Strecke wie in Arcade (Q-02), dazu Schneefall, verschneite Laubbäume und Leitplanken, Schneeränder an der Fahrbahn; Ablauf wie Arcade – fix/vorher_nachher/clip_schnee_17s.jpg, sheets/clip_schnee_fix.jpg |

Die Bilder und die ersten fünf Clips liefen auf `6092197` (dem Prüfstand). Was die Korrekturen ändern, ist auf dem
FIX-Kopf neu entstanden: die drei Schneebilder (`fix/ab/`), Tunnelausfahrt und Valík (`fix/vorher_nachher/`) und die
Clips Tunnel und Schnee (`clips/clip_*_fix.mp4`). **Ergebnis: auf dem FIX-Kopf ist kein Bild und kein Clip schlechter
als Arcade**; besser vor allem Tunnel, Brücke bei Tag, Städte, Regennacht und Heide, gleich vor allem die Nacht (wie
gewollt: Lichter, Fahrbahn und Silhouetten). Bekannt und offen bleibt das eigene Auto (dunkler im Tunnel, Lack der
Limousine in der Dämmerung grau-lila).

## 8. Offene Punkte aus R7d, in QA-mid beurteilt

| Punkt | Beurteilung über das ganze Rennen | Stand |
|---|---|---|
| K-8 Nacht | In allen Nachtläufen (22 Uhr klar und im Regen auf den fünf Hauptetappen, Regen 22 Uhr auf dem Frankfurt-Weg) und im Vergleichsbild Schneenacht ist Modern an Bäumen gegen den Himmel, dunkelgrünem Gelände, Häusern mit erleuchteten Fenstern (Würzburg, Nürnberg), Brücken, Tunnel, beleuchteten Tankstellen, nasser Fahrbahn und den Autos klar zu erkennen; Lichter, Fahrbahn und Schilder so gut lesbar wie in Arcade (`sheets/*_t22.jpg`, `*_r22.jpg`). Ein eigenes Mondlicht auf dem Gelände braucht es nicht. | **erledigt**, nichts zu tun |
| K-3 Regen- und Schneenacht 1,19 × / 1,22 × | Die Wolkendecke ist etwas heller grau als Arcades fast schwarzer Himmel; Bäume stehen besser dagegen, Rück- und Scheinwerfer leuchten wie vorher (`ab/regennacht_berge`, `fix/ab/schnee_nacht`, Regenläufe 22 Uhr). Stört nirgends. | **behalten**; im ZS2 fragen (Checkliste C.4) |
| K-7 Schneefelder | Wo Äcker, Stoppeln oder Hecken an der Strecke liegen, schauen sie aus dem Schnee; über Wiesen bleibt es weiß wie in Arcade. Kein Fehler. | **offen** für eine spätere Welle (Schneeverwehungen, Spuren); in `was_neu.md` genannt |
| Leistung auf dem Steam Deck | nur Software-Grafik gemessen (§5) | **ZS2**: Leistungstest auf dem Deck (Checkliste C.2) |
| Goldens `modern_slice` | – | erzeugt die Integration bei ZS2 nach Ansehen der Bilder neu (A-29) |
| Lack der Limousine in der Dämmerung grau-lila, eigenes Auto im Tunnel dunkler als Arcades Bild (RINT-M3, A-29/AS5b) | in den Läufen unverändert gesehen | **offen**, bekannt; in `was_neu.md` genannt |

## 9. Commits auf `wip/v080-qamid-fix` (Basis `6092197` = `wip/v080-r7d`)

| Commit | Inhalt |
|---|---|
| `beb69d2` | Tunnelhügel: Buckel geglättet (erste, falsche Diagnose zu Q-01) |
| `b18b0d6` | Fichte und Palme tragen Schnee in Flecken (Q-02), Test `test_leaf_snow`, Doku §15.5 und `modelle.md` |
| `18368c3` | Weißabgleich des Draußen an der Tunnelausfahrt (Q-04), Test |
| `f93e5d7` | Doku `renderer-modern.md` §15.6 zum Weißabgleich (Q-04) |
| `5dea6b5` | Rücknahme von `beb69d2` |
| `072f9ec` | Tunnelhügel als eigenes Netz ohne Schattenwurf (Q-01), Tests, Render-Prüfung, Doku |
| `c5533a3` | ZS2: Golden-Liste `modern_slice` nach Ansehen der sechs Bilder neu (A-29) – **Stand des Testbuilds 2** |

Der Zweig baut auf `wip/v080-r7d` auf und enthält ihn ganz; die Integration nimmt `wip/v080-qamid-fix` statt
`wip/v080-r7d` (kein eigener Merge nötig).

## 10. Testbuild 2 (`zs2/`, `sh/zs2_build.sh`, Lieferordner `deliver/ZS2/`)

`tools/build_testbuild.sh 0.8.0-zs2 ZS2 crossing-europe-zwischenstand` aus `c5533a3` (sauber, Windows-Version 0.8.0.2,
Dateizeiten = Commit-Zeit): `CrossingEurope-ZS2-linux-x86_64.tar.gz` 189 MiB, `CrossingEurope-ZS2-windows-x86_64.zip`
198 MiB (Grenze 400 MiB), `SHA256SUMS`, `BUILDINFO.txt`, `LIZENZEN.txt`. Der Export patcht `project.godot` und
`export_presets.cfg` nur für die Dauer des Exports (Version, eigener Nutzerordner) – danach war die Arbeitskopie wieder
sauber. (Erster Anlauf brach nach 11 s ab: der eigene `XDG_DATA_HOME` des Laufs verdeckte die Export-Vorlagen; mit
einem Verweis auf die Vorlagen im Laufordner neu gebaut.)

| Rauchtest (`tools/smoke_modern.sh` mit dem **exportierten** Programm) | Ergebnis |
|---|---|
| Linux, OpenGL 4.5 | **SMOKE linux: OK** – Arcade 16 s, Modern 58 s, Leistungstest „autobahn“ 4,8 Bilder/s (Software, „Niedrig“), Version 0.8.0-zs2, Nutzerordner `…/crossing-europe-zwischenstand` (leistungstest.json, logs, shader_cache); Bilder `zs2/smoke_linux_bogen.jpg` |
| Linux, OpenGL ES 3.2 (der Weg von ANGLE) | **SMOKE linux_opengl3_es: OK** – Arcade 17 s, Modern 128 s (ZS1: 74 s – mehr Shader zu übersetzen, Software-Grafik), 4,7 Bilder/s |
| Windows unter wine64 | **SMOKE windows: OK** – Arcade 22 s, Modern 65 s, 4,5 Bilder/s, Nutzerordner `AppData/Roaming/crossing-europe-zwischenstand`; Bilder `zs2/smoke_windows_bogen.jpg` |

Im Countdown senkt der Wächter auf „Niedrig“ (richtig für Software-Grafik). Direct3D/ANGLE, echte Grafikchips und das
Steam Deck sind hier nicht prüfbar – dafür der Leistungstest und die Checkliste im ZS2.

