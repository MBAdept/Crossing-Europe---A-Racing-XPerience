Ganze Etappe Kiel – Hamburg, 21 Uhr, Regen (nasse Straße: Spiegelungen, Gischt, Regen), Limousine, Saat 11,
„Niedrig“, Zeitraffer 16, unter Xvfb (`m1/FIX-R4/sh/stage.sh` = R4s Lauf), Kopf (`b156763`) dreimal und Basis
`7f0eae2` (Kopie `m1/FIX-R4/base`) zweimal, abwechselnd, Last 15–17 durch andere Pakete. Alle fünf: 95 km, gleiches
`ERGEBNIS` (Schnitt 123,38 km/h, 0 Zusammenstöße), 0 Skript- und Shaderfehler, 528 Bilder.

| Lauf | `render()` Mittel / max (ms) | Einhängen max (ms) | Zeichenaufrufe | Dreiecke | Bildzeit Median (ms) | `flares` / `vehicles` Mittel (ms) | Spitzen > 20 ms (Ebene: ms) | Simulation max (ms) |
|---|---|---|---|---|---|---|---|---|
| Basis 1 | 3,67 / 39,5 | 9,03 | 77 | 76.330 | 276 | 0,24 / 0,78 | streamer 23 | 110 |
| Basis 2 | 3,85 / 81,6 | 8,60 | 77 | 76.330 | 268 | 0,20 / 0,78 | streamer 80 | 74 |
| Kopf 1 | 4,21 / 228,6 | 5,25 | 77 | 76.902 | 283 | 0,28 / 0,84 | lights 226, weather 45, streamer 31 | 313 |
| Kopf 2 | 4,24 / 144,1 | 1,76 | 77 | 76.902 | 277 | 0,49 / 0,95 | streamer 142, flares 121, vehicles 78 | 61 |
| Kopf 3 | 4,31 / 167,1 | 6,21 | 77 | 76.902 | 270 | 0,26 / 0,81 | streamer 165, lights 96 | 246 |

Gelesen (gemessen, llvmpipe): das Mittel von `render()` liegt im Kopf 0,4–0,6 ms höher; der größte Teil davon sind
einzelne Bilder mit 100–230 ms in **unveränderten** Teilen (`lights`, `streamer`), zur selben Zeit wie Hänger der
ebenfalls unveränderten Simulation (bis 313 ms) – Last der Maschine. Ohne die Spitzen kosten die Profile der Streifen
`flares` +0,02–0,06 ms und `vehicles` +0,03–0,06 ms je Bild (7 Aufrufe `height_at()` je Auto mit Spiegelung, je
Laterne mit Spiegelung). Zeichenaufrufe gleich (77), Dreiecke +572 (+0,7 %: die Streifen sind Bänder aus 12
Abschnitten statt Vierecken), Einhängen unverändert klein. Auf dem Steam Deck abgeleitet: vernachlässigbar (≈ 0,1 ms
Skript, 24 statt 2 Dreiecke je Spiegelung). `kern_zeit` (0,284 ms) und `renderer_zeit` (0,766 ms) im Vollauf grün.
