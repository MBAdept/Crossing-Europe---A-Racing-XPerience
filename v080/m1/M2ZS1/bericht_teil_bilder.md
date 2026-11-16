## 4. Bilder – ehrlich gegen Arcade und gegen den gelieferten ZS1

`tools/ab_shot.sh` (Xvfb, `--fixed-fps 60`, `--gfx-sync`), dieselben Argumente wie die Läufe, aus denen die Bilder von
ZS1 stammen (FIX-ZS1 `kh0`, FIX-WASSER `holtenau`, FIX-WASSER-R `kb_*`, `belgrad`). **Die Arcade-Bilder sind in jeder
verglichenen Szene bitgleich mit denen der ZS1-Läufe** (15 von 15, `cmp`, gemessen) – derselbe Simulationszustand, die
Modern-Bilder lassen sich direkt vergleichen. Dreierbilder Arcade | ZS1 | M2ZS1 in `bilder/` (Hälfte der Größe), alle
angesehen; Rohbilder in `m1/M2ZS1/shots/`.

| Szene | Bild(er) | M2ZS1 gegen ZS1 | M2ZS1 gegen Arcade (ehrlich) |
|---|---|---|---|
| Start Kiel – Hamburg, Countdown 1 s, „Mittel“ | `start_mittel_countdown_1s.jpg` | gleich: Auto an seinem Platz (Lackfläche ±0,5 %), Starttor, Startlinie, Schild „Tankstelle 15 km“; dazu die Bäume von AS3R | gleichwertig, nicht besser: links fehlt Arcades große Eiche (schon in ZS1) |
| Start, 1,5 s nach LOS, „Mittel“ | `start_mittel_los_plus_1_5s.jpg` | gleich (Kanten +0,0/+1,0/−0,5/+0,5 %, FIX-ZS1 maß dasselbe) | gleichwertig |
| Start, Steam-Deck-Stufe 1280 × 800 | `start_deck_countdown_1s.jpg`, `start_deck_los_plus_1_5s.jpg` | (kein Rohbild von ZS1 in dieser Stufe; FIX-ZS1 zeigte den Countdown am Steam-Deck-Format nur über den Erststart) – Auto im Countdown da, 16:10 gefüllt | gleichwertig; Modern füllt 16:10, Arcade mit Balken |
| Köhlbrandbrücke 22 Uhr, „Hoch“, km 77,7 / 78,1 / 78,8 / 78,9 / 79,7 | `kb_nacht_hoch_km*.jpg` | **besser**: Elbphilharmonie und Michel beleuchtet (M2INT, fehlten in ZS1); Pylone dunkel wie in ZS1 (Messreihe Abschnitt 3), Seile dünne dunkle Linien statt der breiten hellen Bänder des Sprites; Elbe und Fähren wie ZS1 | gleichwertig: Pylone so dunkel wie Arcades, Wasser, Schiffe, Wahrzeichen an Arcades Stelle; Spielerauto heller als Arcades Sprite (bekannt) |
| Köhlbrandbrücke 12 Uhr, „Hoch“, km 78,1 / 78,8 / 78,9 | `kb_tag_hoch_km*.jpg` | Pylon als Modell (Beine, Seilfächer bis zur Deckkante) statt Sprite-Vertretung mit verwaschenen Füßen; Wasser wie ZS1 | gleichwertig bis etwas besser (Pylon als Körper, Schatten); die Pylonbeine stehen nah an der Fahrbahn hell im Bild |
| Köhlbrandbrücke 22 Uhr, Steam-Deck-Stufe | `kb_nacht_deck_km*.jpg` | wie „Hoch“: dunkler als ZS1 (69,2 / 57,7 / 43,5 gegen 78,4 / 61,0 / 50,9), Elbphilharmonie da | gleichwertig |
| Köhlbrandbrücke 12 Uhr, Steam-Deck-Stufe | `kb_tag_deck_km*.jpg` | ZS1-Bild aus einem anderen Lauf (60 km/h): Wasser und Schiffe gleich, Pylon als Modell | gleichwertig |
| Holtenauer Hochbrücke (Rostock – Kiel ab km 200), 12 Uhr | `holtenau_0[0-3].jpg` | gleich: Kanal beidseits bis zum Horizont, Fähre auf dem Wasser (Modell von AS4R statt Sprite) | gleichwertig; Arcade zeigt links hinter der Brücke schon Land |
| Ada-Brücke Belgrad (km 198,7 / 199,1 / 199,8 / 200,2 / 200,7), 12 Uhr | `belgrad_0[0-4].jpg` | Ersatzbild jetzt das **Kirchen-Modell** (× 2,3) statt des getönten Sprites: schlanker (Turmseite zur Straße), ungetönt; Pylon als Modell mit weißem Seilfächer statt Sprite-Bändern | **schlechter als Arcade** wie schon ZS1: generische Kirche statt der Kuppelkirche des Heiligen Sava; gegen ZS1 gleichwertig (Modell statt Bild, dafür weniger Masse) |

Nicht im Bild belegt: das **Blinken** der Flugbefeuerung – an den geprüften Stellen liegt die Pylonspitze hinter dem
oberen HUD-Balken (die Brücke liegt hoch). Belegt durch den Unit-Test (Takt gegen Arcades Formel) und die Lampenanker im
Test des Pylonmodells.
