**Kiel – Hamburg ab km 76 (Köhlbrandbrücke, Elbbrücken), 12 Uhr, Seed 11**

| | Basis 6e48405 | R5 5558bdc |
|---|---|---|
| Strecke erreicht (km) | 94.0 (Zeitlimit) | 94.4 (Zeitlimit) |
| Bilder | 937 | 959 |
| `render()` Mittel / max (ms) | 2.40 / 68.9 | 2.43 / 105.8 |
| Bildzeit Median / p95 (ms, llvmpipe) | 1249 / 1811 | 1189 / 1717 |
| `sim_avg_ms` / max (Lastmaß, R5 berührt es nicht) | 1.57 / 376 | 1.37 / 65 |
| Haken `bridge` Mittel / max (ms) | – | 0.019 / 0.1 |
| Haken `tunnel` Mittel / max (ms) | 0.003 / 0.1 | 0.005 / 2.2 |
| Haken `far_ground` Mittel / max (ms) | 0.293 / 11.6 | 0.338 / 5.4 |
| Stück-Bau Worker Mittel / max (ms) | 4.9 / 19.1 | 5.0 / 20.5 |
| `chunk_commit_ms_max` (Budget deck 3 ms) | 1.08 | 1.98 |
| Zeichenaufrufe / Primitive (letztes Bild; Budget deck 650 / 450 000) | 133 / 138709 | 129 / 138299 |
| Schatten-Primitive (letztes Bild) | 4264 | 4404 |
| Texturspeicher (MB) | 119.7 | 120.5 |
| Vorbereitung `prepare_ms` | 29.2 s | 25.4 s |
| Wanduhr (s) | 1200 | 1201 |

**Bern – Mailand ab km 183 (Gotthard-Portal und Röhre), 12 Uhr, Seed 16**

| | Basis 6e48405 | R5 5558bdc |
|---|---|---|
| Strecke erreicht (km) | 222.4 (Zeitlimit) | 219.9 (Zeitlimit) |
| Bilder | 635 | 592 |
| `render()` Mittel / max (ms) | 3.57 / 329.1 | 2.93 / 134.9 |
| Bildzeit Median / p95 (ms, llvmpipe) | 1345 / 1825 | 1100 / 1689 |
| `sim_avg_ms` / max (Lastmaß, R5 berührt es nicht) | 1.08 / 77 | 1.27 / 592 |
| Haken `bridge` Mittel / max (ms) | – | 0.004 / 0.1 |
| Haken `tunnel` Mittel / max (ms) | 0.045 / 1.2 | 0.074 / 2.3 |
| Haken `far_ground` Mittel / max (ms) | 0.081 / 3.3 | 0.104 / 3.4 |
| Stück-Bau Worker Mittel / max (ms) | 9.4 / 83.7 | 17.4 / 109.6 |
| `chunk_commit_ms_max` (Budget deck 3 ms) | 1.97 | 6.88 |
| Zeichenaufrufe / Primitive (letztes Bild; Budget deck 650 / 450 000) | 141 / 142640 | 133 / 127223 |
| Schatten-Primitive (letztes Bild) | 9556 | 6736 |
| Texturspeicher (MB) | 117.3 | 114.6 |
| Vorbereitung `prepare_ms` | 19.3 s | 27.2 s |
| Wanduhr (s) | 601 | 600 |


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
