## 5. Im Rennen (`tools/ab_shot.sh`, Arcade | Modern aus demselben Simulationszustand)

Acht Läufe in der Kopie, je mit eigenem `XDG_DATA_HOME`, Autopilot, Samen 11, ohne Countdown; Modern ohne
Skriptfehler (0 Treffer für `SCRIPT ERROR|Parse Error|SHADER ERROR`, gemessen). Die Stellen kommen aus der Zählung
(`census_all.log`) und `positions.gd`.

| Bild | Stelle | Befund |
|---|---|---|
| 01 | Kiel–Hamburg ab Kiel, km 77,9 / 78,3 / 79,0, 12 Uhr, Hoch | **M1**: die Pylon-Seile fallen in die Fahrspuren (ein Seil endet vor dem eigenen Auto), zwischen den Pylon-Paaren ein Käfig aus Stäben; die Fächer reichen vor die Brücke. **M2**: zwei Fähren auf der Wiese. Arcade: Seile zur Deckkante, Elbe, Geländer (Deck und Wasser fehlen in Modern bis R5) |
| 02 | Paris–Tours ab Paris, km 129,3 / 130,5 / 131,2, 12 Uhr, Hoch | Haus (Vorderkante 33 m seitlich) und Kirche (81 m) stehen, wo Arcade sie zeigt, gleich groß; das Haus ist gleich hell (Wand p95 202 gegen 203), die Kirche heller (229 gegen 203, gemessen) und dadurch kalkweiß (Bild 29). Modern zeigt die Anfahrtsseite, Arcade die Dreiviertelansicht – im Spiel wirkt Modern ruhiger und genauer |
| 03 | dieselbe Stelle, 23 Uhr, Hoch | Fenster warm und vereinzelt; Arcade-Fenster heller (bis 225 gegen 165) und das Arcade-Haus dunkler – Modern wirkt nachts flauer (**M6**, Bild 28) |
| 04 | Kassel–Würzburg ab Kassel, km 201,6 / 203,0 / 204,8, 21 Uhr, Mittel | Altstadthaus mit Treppengiebel als Modell zwischen Stadthaus-Platzhaltern (Sprites mit Lichtebene); das Modell hat 41 % weniger helle Fensterpixel als das Sprite (gemessen) und fällt neben den hell leuchtenden Platzhaltern ab (**M6**) |
| – | Bremen–Amsterdam ab Bremen, km 357,0 / 358,3, 12 Uhr, Hoch | kein AS4-Set im Bild: die Hausboote an der Singelgracht liegen hinter den Grachtenhäusern (Platzhalter-Sprites); nicht ausgeliefert. Hausboote auf Wasser: Prüfszene, Bild 13 |
| 05 | Hamburg–Hannover ab Hamburg, km 142,4 / 143,3, 12 Uhr, **Steam-Deck-Voreinstellung, 1280×800** | Stadteinfahrt Hannover: fast alle Häuser sind Stadthaus-Platzhalter (`city_*`, AS5a); das Ladenhaus steht klein in der Ferne. Modern füllt 16:10, Arcade mit Balken; kein Fehler der AS4-Modelle sichtbar |
| 06 | Dresden–Leipzig ab Dresden, km 111,6 / 112,8, 15 Uhr, Hoch | Büroturm (Maßstab 2,15) an derselben Stelle wie das Sprite hinter den Häusern; kurz davor bleibt das Modell am linken Rand im Bild (echtes 3D), das Sprite ist dort schon weg. Das braune Scheibenmuster ist im Rennbild auf diesem Abstand schwach zu sehen |
| 07 | Bremen–Dortmund ab Dortmund, km 2,2 / 2,9, 23 Uhr, Hoch | Fabrik (links gespiegelt) mit hellem Werkszeichen und zwei hellen Hallenfenstern, Wohnblock B mit vielen warmen Fenstern; Arcade zeigt die Hallenfenster der Seitenwand hell, Modern die Front – insgesamt matter (M6); keine Shed-Dreiecke von der Straßenseite (M4) |
