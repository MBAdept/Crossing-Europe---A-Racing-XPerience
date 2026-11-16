### K3 – mittel bis hoch, häufigstes Modell (AS5a-N) – Gartenbaum als Klumpen, Gartenmauer weich (Südhaus, Loire-Haus)

**Wo:** `city_french_sud` (588 Platzierungen: Vororte von Toulouse, Montpellier, Lyon, Bordeaux, Pau, Tours, Bern-Abfahrt
…) und `city_french_maison` (209: Paris, Tours, Bordeaux, Toulouse) – zusammen 797, die meisten Stadthäuser der Charge.
**Was:** Der Gartenbaum steht auf der Straßenseite des Hauses (Generator: `x0 − 3,2 m`) und ist die dezimierte
Kugelkrone des Generators: aus 10–15 m eine Traube facettierter grüner Steine mit harten Kanten (Bild 30 links). Bei
30 m wirkt sie wie das Sprite (Bild 30 rechts), aber die Vororthäuser stehen 10–19 m vom Rand – der Baum zieht
näher an der Kamera vorbei als die Hauswand. Die Gartenmauer davor hat 14–16 px/m (5.2), unter den 26 px/m des
Vertrags und unter der Angabe von AS5a2 („0,6 der Dichte“ ≈ 32 px/m); sie ist eine glatte, leicht verschwommene Fläche.
Die Vorgabe sagt für Gartenbäume ausdrücklich „the AS3 tree models if a tree stands there“ – das ist nicht umgesetzt.
**Fix (AS5a-N, mit Vertragsfrage 1):** die Krone aus dem Modell nehmen und an ihrer Stelle einen AS3-Baum stellen
(Platane ≈ `tree_beech`/`tree_oak`, Maßstab aus Kronenradius 3,0 / 2,2 m) – als Anbau des Requisiten-Bauers oder als
dritte Oberfläche `leaves`; solange das nicht geht: die Kronenkugeln mit `smooth` schattieren und ihre Facetten im
Atlas mit einer Blattstruktur (Rauschen 2–4 cm) backen, Ziel „weiche Wolke“ wie das Sprite. Gartenmauer in den Chart
der Straßenwand (≥ 32 px/m), Mauerkrone mit Abdeckplatte. Nachweis: Nahansicht `road` und Fahrfilm durch eine Vorortstraße.

### K4 – mittel (Modell + Import/Renderer) – Schmiedeeisen und Fenstergitter schließen sich in der Ferne und flimmern

**Wo:** Haussmann (55), Eckhaus (8), Lyoner Haus (202), Südhaus (588), Chalet (54) – alle Modelle mit `baked_cutout`.
**Gemessen:** Deckung des Alpha-Tests gegen Mip 0 steigt auf 1,2–1,8 (Mip 2, ab ≈ 20 m), 1,5–2,2 (Mip 3, ab ≈ 40 m)
und 1,9–4,2 (Mip 4, ab ≈ 75 m); vor hellem Stein wird das Geländerband dabei 25–89 Stufen dunkler (5.6). Flimmern
Haussmann/Eckhaus 1,0–1,2 % bei 40–100 m gegen 0,0–0,3 % beim Sprite (5.5). **Angesehen:** Bei 100 m sind die
durchgehenden Haussmann-Balkone geschlossene grau-braune Bänder ohne Durchblick (Bild 10 paris, 100 m), dunkler und
dichter als die gemalten Bänder des Sprites; im Paris-Clip von AS5a2 zeigen die fernen Fassaden in der Bildmitte eine fast doppelt so große
zeitliche Unruhe wie Arcade (`py/rough2.py`: 7,0 gegen 3,8, H.264, grob). Halo oder Aufblitzen sehe ich in den
Standbildern nicht – die Klasse `baked_cutout` funktioniert, ihre Mip-Kette nicht.
**Fix:** (Import/`bake.py`, Vertragsfrage 2) eine deckungserhaltende Mip-Kette für die Ausschneide-Inseln (Alpha je
Stufe so skaliert, dass der Anteil ≥ 0,5 dem von Mip 0 gleicht); (AS5a-N) in **lod1** die Geländer als halbdeckendes
gemaltes Band in den deckenden Atlas (dann ist lod1 `baked` statt `baked_cutout`, ohne `discard`, mit Rückseiten-Culling)
und die Fassadenwände von lod0 aus der Ausschneide-Klasse nehmen, sobald drei Oberflächen erlaubt sind (Vertragsfrage 1).
Nachweis: `mipcov.py` 0,9–1,1 für Mip 1–4, `sparkcam` ≤ 0,5 % bei 40–150 m.

### K5 – mittel (R7 + AS5a-N) – Stufenwechsel ohne Überblenden, nachts heller

**Gemessen** (5.3): bei 60 m („Mittel“) 9–18 % der Pixel, auf „Hoch“ bei 120 m bis 22,6 % (Grachtenhäuser); nachts
springt die Helligkeit um +3 bis +5 % (lod1-Scheiben ohne Laibung, p90 der Fensterpixel beim Maashaus 80 → 119).
Bestätigt AS5a2. In einer dichten Zeile geht der Wechsel im Bewegungsrauschen unter (Prüfstraße Paris, `py/swappop.py`: 10,8 % neu
geänderte Pixel im Wechselbild gegen 10,4 % davor und danach; so auch KRITIK-5a1), sichtbar bleibt er bei frei stehenden Häusern und nachts. **Fix:** (R7) Dither-Überblenden 0,3–0,5 s auch für
`city`/`building`; (AS5a-N) lod1-Scheiben nachts um den Laibungsschatten dimmen (`light_mul` lod1 ≈ 0,8).

### K6 – mittel (AS5a-N) – Flimmern von Sprossen und Rahmen auch ohne Geländer

**Gemessen** (5.5): Grachtenhäuser B 0,7 / 1,0 / 0,6 / 0,9 % gegen 0,1 / 0,2 / 0,2 / 0,4 %; Loire-Haus in lod1 1,0 / 1,4 %
bei 100 / 150 m (Sprite 0,6 / 0,9); Lauben und Südhaus 1,5–3× das Sprite. Das Sprite ist vorgefiltert, das Modell
zeigt 1–2 Pixel breite weiße Rahmen und Sprossen vor dunklem Glas. In Bewegung (Abschnitt 4, Clip): ferne Zeilen
2,0–2,8× so unruhig wie die Arcade-Platzhalter (Prüfstraße Paris), Rennclip Amsterdam 1,7–1,9× (H.264, grob). **Fix:** dieselbe Ursache wie K2 – die Fensterregion
der kleinen Mips vorfiltern (Rahmen und Sprossen ab Mip 2 mit dem Glas mischen, Kontrast der Sprossen 30 % senken);
Sprossen-Geometrie erst ab lod0 < 40 m.

### K7 – niedrig bis mittel (AS5a-N) – Chalet: Geranien als Perlenkette

**Wo:** `city_swiss_chalet` (54, Vororte Bern, Mailand-Abfahrt) – Balkon- und Fensterkästen. **Was:** Die Geranien sind
eine Reihe großer, facettierter roter und grüner Kugeln (Bild 31): aus 10–20 m eine Perlenkette aus Plastik. Aus 30 m
wie das Sprite. **Fix:** Blumenkasten als niedriger Wulst mit gebackenem Blütenrauschen (rote Tupfen 3–5 cm auf Grün),
dazu 3–5 kleine Kugeln je Meter mit `smooth`; nicht mehr als heute an Dreiecken.

### K8 – niedrig (AS5a-N) – Rück- und Gegenseiten

Eckhaus: Rückseite und Gegenseite blanke Putzflächen mit 9–12 px/m (Bild 32; bekannt, AS5a2). Grachtenhäuser A/B:
Gegenseite (+x) 12–15 px/m, blank. Lauben: die Rückseite zeigt Läden ohne Arkaden (die Arkaden stehen nur vorn). Zu
sehen nur in Kurven und beim Zurückschauen (gefolgert: selten). **Fix:** Fernwand-Zuordnung für Grundrisse mit
abgeschrägter Ecke (AS5a2 nennt sie), sonst der Straßenwand-Chart gespiegelt.

### K9 – niedrig (AS5a-N/AS5b) – Nachts keine Wand- und Eingangsleuchten

Die zwölf Generatoren rufen `wall_lamp` nicht auf (die Funktion gibt es, das Hausboot nutzt sie); die Vorgabe nennt
„entrance and wall lamps as light anchors (lamp channel 12 + lights)“. Arcade zeigt dort auch keine Leuchten – Modern
ist nachts also nicht schlechter, aber auch nicht lebendiger als Arcade, wo es leicht wäre: Haussmann-Portal,
Café-Markise, Bäckerei Lyon, Lauben-Gewölbe. **Fix:** über `close3d` je Haus eine Wandleuchte am Eingang
(`wall_lamp`, Kanal 12, `lights`-Anker), Sprite unverändert.

### K10 – niedrig – Kleinkram

- **Tönung (R7):** 50 Reihenhausreihen im Ruhrgebiet stehen ohne `#ead6cc` (Bild 27), bis R7 die Tönung auf Modelle legt.
- **lod1 spart wenig beim häufigsten Modell:** Südhaus lod1 = 69 % von lod0 (3 716 / 5 359), Haussmann 57 %, Eckhaus
  60 % – Baumkrone und Geländer bleiben in lod1 fast voll. Ziel ≤ 40 %.
- **Sonnige Fassaden heller als Arcade (R4):** im Rennen Paris rechte Flanke Median-Luma 182 gegen 152 (+20 %),
  Amsterdam +15 % (gemessen, `py/boxlum.py`) – wie KRITIK-5a1 K8; Licht, nicht Modell.
