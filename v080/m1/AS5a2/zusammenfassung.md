Alle zwölf Sets der Charge 2 (`city_dutch_canal`, `city_dutch_canal_b`, `city_dutch_terrace`, `city_belgian_terrace`,
`city_belgian_stone`, `city_french_maison`, `city_french_sud`, `city_french_immeuble`, `city_paris_haussmann`,
`city_paris_corner`, `city_swiss_chalet`, `city_swiss_laube`) haben echte Echtzeit-Modelle aus dem Bauer `city`,
gebaut aus denselben Generatoren wie die Sprites. Front, Umriss, Dach und Farben sind das Sprite (IoU 0,945–0,999);
dazu echte Tiefe (Laibungen, Rahmen, Sprossen, Läden mit Auslage, Fensterläden, Haussmann-Balkone, Fenstergitter,
Arkaden) und Straßenflanken mit Fenstern und Türen statt blinder Flächen (Hooks `close3d`, Sprites unverändert:
86 von 86 identisch). Nachts leuchten dieselben Fenster wie im Sprite. Budgets eingehalten: höchstens 6 518 Dreiecke
in lod0, zwei Zeichenaufrufe je Stufe, Archiv 0,93 MB Netze / 5,79 MB Texturen (Grenze 3 / 7 MB), Erdgeschoss
≥ 40 px/m bis auf die Lauben beim größten Maßstab (39,8).

Im Rennen (A/B an fünf Ankünften, 13 Läufe, alle ohne Fehler) ist Modern dort, wo Arcade eine flache Hausflanke zeigt,
deutlich feiner. **Schwächster Punkt:** Die Schaufenster sind nachts dunkler als in Arcade (Ladenpixel 124 gegen 207,
gemessen) – gemeinsame Formel mit Charge 1, nicht behoben, weil ein Fix alle 23 Stadthäuser neu exportiert
(Abschnitt 8). Weitere Mängel: blanke Rückseiten des Eckhauses, lod1 bei 250 m heller als das Sprite, Modelle
flimmern 2–5-mal so stark wie die Sprites.

Neu im Bauer (rückwärtskompatibel, Charge 1 + Brücken + Hausboot byte-gleich): Geländer als Modul (`rail_module`),
`weights.solid`, `openings.cover_skip`, `openings.chamfer`, `smooth`.
