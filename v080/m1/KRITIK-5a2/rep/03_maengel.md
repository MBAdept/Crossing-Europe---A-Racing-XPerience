## 3. Mängelliste – sortiert nach dem, was der Spieler am meisten sieht

Zuständig: **AS5a-N** = Nacharbeit der Modelle (`ce3d/cities3d.py`, Hooks in `cesprites/props_cities.py`, Katalog),
**R7** = Fernbild, Tönung, Überblenden, LOD, Anbauten im Requisiten-Bauer, **R4** = Licht, **Import** =
`.import`/`bake.py`. Bilder in diesem Ordner (Nummer vorn im Dateinamen).

### K1 – hoch, nachts (AS5a-N) – Schaufenster und Ladenzeilen leuchten viel schwächer als in Arcade

**Wo:** jede Innenstadt mit Läden – Paris (Haussmann-Bogenläden, Eckhaus-Café), Lyon/Toulouse/Bordeaux (Bäckerei des
Lyoner Hauses), Brüssel/Lüttich (Café der Reihenhäuser), Bern (Läden in den Lauben); dazu Charge 1 (Gründerzeit,
Kontor), weil die Formel geteilt ist.
**Gemessen** (Paris km 387,9, 22 Uhr, Hoch, `py/litpx.py`, Bild 02): Wohnfenster des Eckhauses leuchten gleich wie in
Arcade (4,0 gegen 4,0 % der Fassade), die Bogenläden nur auf **8,9 statt 24,4 %** der Erdgeschossfläche und dunkler
(Mittel (196,155,108) gegen (250,215,158)); 2 s später an der Ladenflanke rechts warme Pixel **3,7 gegen 19,7 %**,
deren Helligkeit **149 gegen 203** (AS5a2: 124 gegen 207). Die ferne Ladenzeile in Bildmitte (150–300 m) hat
3,4–4,9 % warme Pixel gegen 9,8–10,9 % in Arcade.
**Angesehen:** In Arcade ist eine Pariser Straße nachts eine Kette heller gelber Bögen; in Modern liegen dort
warmbraune Auslagen hinter dunklem Glas, die Fassade selbst ist im Mondlicht gut lesbar – stimmungsvoll, aber der
Straßenzug wirkt **dunkler und leerer als in Arcade**. Das widerspricht dem Wunsch des Nutzers nach „besseren
Lichteffekten“ genau dort, wo Städte nachts leben sollen. Teil des Unterschieds ist, dass Arcade die beleuchtete
Flanke als großes Billboard zeigt; die Helligkeit der einzelnen Auslage (149 gegen 203) ist aber eindeutig ein
Modellwert.
**Fix (AS5a-N, beide Chargen in einem Neu-Export):** in `cities3d._display_mat` die Lichtschicht der Auslage
um den Faktor ≈ 1,6 anheben (AS5a2s Vorschlag `shop_glow`) und das obere Drittel der Auslage als helle Rückwand bzw.
Deckenlicht backen statt dunkler Regale, so dass der Mittelwert der beleuchteten Ladenpixel bei ≈ 200 liegt wie in
Arcade; prüfen, wie viel die dunkle Glastönung nachts schluckt. Nachweis: dieselbe A/B-Stelle, Ladenpixel 190–210, Anteil ≥ 0,7 × Arcade;
Tag unverändert (nichts leuchtet bei Tag).

### K2 – mittel, häufig (AS5a-N + R7) – Fassaden werden ab 100 m blass, die Fenster rosa-lila

**Wo:** alle zwölf Modelle, bei jeder Stadteinfahrt im Bild geradeaus (100–350 m), am deutlichsten an farbigen
Putzfassaden (Südhaus, Lyoner Haus, Lauben) und am Maashaus.
**Gemessen** (5.4, `k6_scene --mode=lodcol`): zwischen 60 und 250 m werden die Modelle um 5–10 % heller, das Sprite um
1–3 % dunkler; das dunkle Zehntel (die Fenster) hellt beim Modell um 13–23 Stufen auf, beim Sprite um 2–15. Der
Kontrast der Fassade bei 150 m ist beim Modell kleiner als beim Sprite (Haussmann 59 gegen 75, Lauben 81 gegen 97,
`sparkcam`). lod0 und lod1 verhalten sich gleich – es ist die Mip-Kette des Atlas, nicht die Stufe.
**Angesehen** (Bild 29, 25): bei 200–350 m werden die Fenster zu hellen rosa-lila Flecken, die Lauben verlieren das
Dunkel ihrer Bögen, das Sprite behält dunkle Fensterreihen. Im Rennen ist es schwächer (Dunst, Gegenlicht): in Bern
und Paris lesen sich die fernen Zeilen noch gut, etwas heller als Arcade; in Lyon zeigt die Flanke des Lyoner Hauses bei
≈ 150 m zwischen den grünen Fensterläden rosa-lila Flecken statt dunkler Scheiben (Bild 13, Ausschnitt 6× vergrößert). Das ist die Schwäche „Scheiben ~10 Stufen heller, grau-lila bei 250 m“ aus der Einordnung
von AS4R – sie wurde wiederholt.
**Fix:** (AS5a-N) die Fensterbereiche der kleinen Mips vorfiltern: ab Mip 2 Rahmen, Sohlbank und Sprossen mit dem
Glas mischen und das Ergebnis auf die mittlere Fensterfarbe des Sprites ziehen (eigene Mip-Kette beim Bake, wie das
Sprite bei kleiner Auflösung gerendert ist); billiger Ersatz: in lod1 die Fenster auf eine eigene, dunkle
„Fernfenster“-Kachel im Atlas legen (Glas + schmaler dunkelgrauer Rahmen, ein Mal gebacken, wiederverwendet).
(R7) ab ≈ 200 m das Fernbild des Sets (Sprite-Relief, A-16) – dann bleibt AS5a-N nur 100–200 m. Nachweis:
`lodcol` p10 bei 250 m ≤ p10 bei 60 m + 8, Luma ±3 %.

