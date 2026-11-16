## 1. Ergebnis in Kürze

Jeder Befund der Kritik wurde vor der Änderung am Netz, mit dem Strahltest oder im Bild nachgeprüft. Kein Befund war
falsch, keiner ist abgelehnt. Alle hohen und mittleren Befunde, die am Modell liegen, sind behoben; von den niedrigen
A6, A7 und B6, nicht aber A8 (Diffusor-Finnen), A9 und der Kleinkram von B7 (Abschnitt 3). Bei dreien lag die
Ursache anders als vermutet: B3 (nicht die Kontur der Verkleidung, sondern zwei verschiedene Kunststoff-Höhen von
Stoßfänger und Schweller), B6 (die Rückstrahler waren in den Karosserie-Loft hinter dem Stoßfänger geschnitten) und
A6 beim Kompakt (die Diffusorplatte lag über den Leuchten).

Was der Spieler am meisten sieht, und was sich dort geändert hat (gemessen mit den Werkzeugen der Kritik, Renn-Look):

- **Verkehr in 90–160 m:** Die ferne Stufe hat jetzt Heckscheiben nach der Kontur des Entwurfs mit Säulen in Lack,
  der Transporter keine Glaskiste mehr. Wechsel bei 120 m: Transporter 46,4 -> 12,0 %, Kombi 31,4 -> 6,9 %, Limousine
  26,9 -> 14,4 %, Schrägheck 35,7 -> 22,4 %, Sportwagen 31,6 -> 28,4 %, SUV 32,3 -> 29,8 %; nachts SUV 14,1 -> 4,5 %,
  Transporter 30,1 -> 3,6 %. Alle `lod2` bleiben im Budget (höchstens 1 197 / 1 200).
- **Verkehr in 25–60 m:** Die Scheiben von `lod1` haben die Farbe, die das Glas von `lod0` mit dem Renn-Look zeigt:
  Transporter 17,8 -> 4,2 % bei 40 m (25 m: 20,8 -> 8,0 %), Sportwagen 13,3 -> 11,4 %.
- **Weiß:** Die weißen Verkehrsautos und 16 der 18 Polizeiautos (weiß oder fast weiß) sind wie Lkw und Bus auf
  `#d8d8d6` begrenzt. Transporter in 10 m: Pixel mit allen Kanälen ≥ 250 22 473 -> 7 565. Der Rest ist Belichtung
  (Renderer).
- **Spielerheck nachts:** Der GT leuchtet nicht mehr nur als dünne Linie (Rücklicht 353 -> 477, Bremse 587 -> 716
  rote Pixel in 8 m; Arcade 733 / 957). Die Rückfahrlichter von Kombi und Kompakt sind zu sehen (Strahltest 10 bzw.
  0 % -> 100 %).
- **Seitlich und im Showroom:** Sportwagen und GT haben über dem Vorderrad Luft: 0 Ecken im Reifen bei 0° und ±7°
  (vorher 114 Ecken bis 84 mm bzw. 71 bis 61 mm). Die SUV-Front hat keine Sägezähne mehr, die SUV-Rückstrahler sind
  sichtbar (0 -> 100 %).

Unverändert, weil sie im Renderer liegen: Lackbelichtung (Kompakt 87 %, Sportwagen 55 % geclippt), unbeleuchtete
Lampen mit `lamp_off` 0,5, Flocken des GT, Nacht ohne Flares, der Look im Showroom (Abschnitt 8).

Lkw, Bus und Polizei (AS2b) habe ich mit derselben Strenge geprüft (Abschnitt 4). Hecks, Lampen, Blaulicht A/B
und die Stufen stimmen mit Arcade überein. Behoben habe ich:

- das Weiß der Polizei (wie oben);
- die ferne Heckscheibe der Polizei;
- die fernen Scheiben von Bus und Lkw: Wechsel des Busses bei 60 m 11,0 -> 6,8 %, die Heckscheibe ändert statt
  43 % noch 0,1 % ihrer Pixel;
- das Karoband der Polizei in der Ferne: Es war 27–33 Stufen zu hell, jetzt höchstens 13;
- das Kennzeichen der fernen Stufen.

Offen bleiben der hellere Lichtbalken von `lod0` bei Tag und das Lüftungsgitter des Busses in `lod2` (beides
gemessen und begründet).

**Eine Zahl ist schlechter geworden:** Mit dem dunkleren fernen Kennzeichen steigt die Zählung der Kritik beim
Wechsel bei 25–60 m um etwa 1 Punkt (SUV bei 25 m 2,6). Die mittlere Helligkeit stimmt dafür (Abschnitt 5).

`showroom` bleibt bei allen fünf Spielerautos `false` (Abschnitt 6). Gates: {GATES_SHORT}.
