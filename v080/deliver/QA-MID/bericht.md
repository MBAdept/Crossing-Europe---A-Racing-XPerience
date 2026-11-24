# QA-mid – Zwischenabnahme: das ganze Rennen Kiel – Nürnberg in Modern

Stand der Prüfung: `6092197` (wip/v080-r7d = RINT-M3 + R7d). Arbeitsordner `scratchpad/v080/m1/QA-MID` (Skripte `sh/`,
Läufe `runs/`, Fotos `shots/`, Bögen `sheets/`, Vergleichsbilder `ab/`, Clips `clips/`, Leistung `bench/`).

Vertrag (Welle 5): „whole race Kiel – Nürnberg in Modern in every condition; all render checks; bench per preset; A/B
sheets and clips (night rain, snow, tunnel, bridge, city); test build 2; gate-2 package.“

## 1. Kurzfassung

<!-- KURZ -->

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

## 4. Befunde

| Nr. | Wo | Befund | Stand |
|---|---|---|---|
| Q-01 | jedes Tunnelportal, tiefe Sonne (Hamburg – Hannover 19:30, Elbtunnel km 3,7) | regelmäßige helle Schrägstreifen auf dem Hügel über dem Portal: Arcades Buckel (ein Zufallswert je Spalte, bis ±1,8 m auf 6 m) machten jede Spalte zur Rippe, die tiefe Sonne (13°) legte ihre Schatten auf den Hang | behoben `beb69d2` (Buckel geglättet, Test `test_hill_bumps_without_ribs`); im Spiel nachgeprüft: `fix/ab/tunnel_portal_abend_ab_00.jpg` – glatter Hang ohne Streifen |
| Q-02 | verschneite Fichten (Hannover – Kassel, Kassel – Würzburg; RINT-M3 Notiz 4) | Fichten im Schnee fast ganz weiß mit dünnen grünen Strichen – sie verschwinden vor weißem Boden und Himmel; gemessen: 83 % der Nadelfläche zeigt nach oben, im Mittel 68 % Schneeweiß (Eiche 16, Buche 15, Birke 18, Kiefer 26 %); Arcade zeigt die Fichte dunkelgrün (15 % Graustich) | behoben `b18b0d6`: Fichte (und Palme, 0,83) tragen Schnee nur in Flecken (Anteil 0,29 / 0,24, Zellen im Modellraum), Mittel ≈ 0,2 wie Eiche und Birke; Test `test_leaf_snow` über alle Blätternetze; Bildnachweis `fix/spruce/` (15/40/100/200 m), im Spiel `fix/ab/schnee_wald_ab_00.jpg` – dunkelgrüne Fichten mit Schneeflecken neben Arcades Fichten |
| Q-03 | Messwerkzeug | Fotos lagen bis 1,8 km hinter ihrem Punkt (Zeitraffer 40: ein Bild bis 80 Schritte) | `stage_shots.gd` v2: Schritte vor dem Punkt begrenzt, ±80 m |
| N-01 | Läden `building_shop` nachts | Schaufenster reinweiß ausgebrannt (255) – so hell wie Arcades Lichtschicht (dort fast weiß); die AS5a-Läden haben eine Auslage | Notiz, kein Fehler gegen Arcade |
| N-02 | Autopilot (Spiel, nicht Modern) | fährt in Tempo-50-Zonen ohne Blitzer bis 235 km/h (Hamburg, Nürnberg nachts), bei Tag meist 40–70 | Notiz für die Spiellogik; in Arcade und Modern gleich (Prüfsummen) |
| N-03 | Leistungsspitzen im Zeitraffer | Haken `landmarks` bis 47 ms = Nachrechnen des Sichtkorridors (`corridor.sync_calls` 1.467–5.438 je Lauf) – bekannt aus RINT-M3: im Zeitraffer 4 null | kein Fehler im Spiel |

<!-- REST -->
