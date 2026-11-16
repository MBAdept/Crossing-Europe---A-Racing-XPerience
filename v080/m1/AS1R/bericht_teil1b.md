## 2. Was sich am Modell geändert hat

**Spielerautos (Heck in 9 m = die ganze Spielzeit im Bild)**
- Rückleuchten: Der Leuchtenkörper hat das volle Gewicht auf Kanal 2 – nachts glimmt die ganze Leuchte mit dem
  Rücklicht, nicht nur die Lichtleiter; die Bremse bleibt ein großer Schritt (Bild 01, 02).
- Schulter über den Rückleuchten (Kompakt) ohne schwarzes Blatt; Hutablage folgt der Außenhaut (Bild 03).
- Stoßfänger enden am Radlauf und laufen dort mit 5 cm Radius in die Karosserie; der vordere des Kompakten stand
  vorher 9 cm im Radlauf und 52 mm im Reifen. Wanne und Armaturenbrett bleiben aus den Radhäusern, auch bei 25°
  Lenkeinschlag (Netzanalyse: 0 Ecken im Reifenvolumen).
- Räder: Bremsscheibe mit harten Kanten und matt, Limousinen-Felge anthrazit wie im Sprite.
- Kennzeichen hellgrau mit kräftigeren Zeichen, Fugen 8 mm.
- Innenverkleidung als grober eigener Loft: Innenraum 3 560 / 3 658 Dreiecke (Budget 6 000); der Export bricht
  über 6 000 ab.
- Dritte Bremsleuchte der Limousine als nach hinten blickende Fläche (Lichtanker mit `dir`).
- Schattenwerfer 12 mm innerhalb der Haut **mit** Lampen- und Grillmulden, Radläufe offen.

**Verkehrsautos (10–150 m)**
- Felgen anthrazit, Glas heller und spiegelnd (alle Stufen), dritte Bremsleuchte unbeleuchtet dunkel.
- Kennzeichen in `lod1`/`lod2` grau (Mittelwert mit Zeichen) und in `lod2` behalten; Spiegelglas in allen Stufen;
  dunkler Heckabschluss in `lod2` (Limousine, Kombi).
- Heck aus der Nähe: Fugen von Kofferraumklappe bzw. Heckklappe, Emblem, Stoßfänger-Enden rund, Auspuff als dunkles
  Rohr unter dem Auto statt eines schwebenden Chromrings.
- Reifen mit 9 Profilpunkten (Platz im Budget), Schattenwerfer mit offenen Radläufen.

**Sattelzug**
- Rückstrahlende Kontur, Seitenband und Dreiecke leuchten nachts (Kanal 14), bei Tag in ihrer Farbe.
- Weiße Lackierungen `#d8d8d6` statt `#ececea`.
- Schattenwerfer aus den wirklichen Teilen statt Kasten und Platte.

**Werkzeuge und Prüfer**
- Kontaktbogen: `--clay` (Ton), `--caster` (Werfer rot), Ansichten Vorderrad / Radhaus / Heck bei Nacht aus Kamerahöhe.
- Prüfer: Lichtanker von Fahrzeugen ohne `dir` sind ein Fehler (A-4).
