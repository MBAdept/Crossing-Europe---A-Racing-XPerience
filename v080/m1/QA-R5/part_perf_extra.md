
Lesart (gemessen, unter Last 10–15; „max“ sind Einzelwerte und lastempfindlich): Auf der Brückenstrecke kosten R5s
Teile nichts Messbares – `render()` 2,43 gegen 2,40 ms im Mittel, `far_ground` +0,045 ms, `bridge` 0,019 ms,
Texturspeicher +0,8 MB, Commit-Maximum 1,98 ms (Budget deck 3 ms). Am Gotthard ist `render()` im Mittel sogar
niedriger (2,93 gegen 3,57 ms; Last), Commit im Mittel 1,09 gegen 0,85 ms, **ein Einzelwert 6,88 ms über dem
deck-Budget von 3 ms** (Basis 1,97 ms); in einem zweiten Lauf in der Röhre (km 188, 110 s) 0,51 / 0,59 ms (Basis
0,33 / 0,37), headless höchstens 0,28 ms je Röhrenstück – der Einzelwert ist nicht wiederholbar (Befund QR5-09,
niedrig). Zeichenaufrufe mit dem letzten Bild **auf dem Köhlbrand-Deck** („deck“, km 79,7 bzw. 80,3): R5 163 /
136 829 Primitive / 9592 Schatten-Primitive gegen Basis 148 / 145 951 / 6036; **in der Gotthard-Röhre** (km 194):
R5 43 / 81 312 / 9434 gegen 45 / 77 600 / 6832 – weit unter dem deck-Budget 650 / 450 000 (R5s eigene Messung an
seinen Stellen: +17 bis +22 Aufrufe, +10 bis +15 % Primitive bei „Mittel“ – plausibel). Das Steam Deck selbst ist
abgeleitet; es zählt der Leistungstest des Nutzers (A-15).
