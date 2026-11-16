Ganzer Autopilot-Lauf DEV (`tests/race/run_stage.gd -- --stage=dev_testetappe --from=dev_start --hour=21 --weather=normal
--vehicle=limousine --seed=7 --timescale=40 --graphics=modern`), unter Xvfb mit Mesa llvmpipe (`bin/perf.sh`), Kopf
`c8b18d1` gegen Basis-Kopie `6e48405`, je Voreinstellung direkt nacheinander, Last 15–20, `nice 10` (gemessen). Alle vier
Läufe: 130 km ins Ziel, 0 Kollisionen, 0 Skriptfehler. Die Etappe hat alle R6-Bauten (Start, zwei Tankstellen, Blitzer,
Tunnel, Grenze NL, City Limits mit Laternen, Ziel), 21 Uhr = Nachtlicht.

| Wert (`perf_stats`) | Kopf „Mittel“ | Basis „Mittel“ | Kopf „deck“ | Basis „deck“ |
|---|---|---|---|---|
| `render()` ms Mittel | 8,14 | 7,68 | 8,58 | 8,22 |
| `render()` ms max | 146,0 | 131,8 | 347,2 | 145,3 |
| Chunk-Commit ms max (Hauptthread) | 5,9 | 26,9 | 5,6 | 95,5 |
| Chunk-Bau ms Mittel / max (Worker-Thread) | 12,1 / 235,0 | 8,5 / 97,6 | 10,1 / 231,6 | 7,8 / 124,8 |
| Draw Calls (letztes Bild, Ziel) | 89 | 82 | 83 | 77 |
| Primitive (letztes Bild) | 75 885 | 75 885 | 75 885 | 75 885 |
| Schatten-Primitive (letztes Bild) | 13 752 | 7 998 | 8 316 | 3 384 |
| Bildzeit Median / p95 ms (llvmpipe, Zeitraffer 40) | 1239 / 2324 | 1189 / 2053 | 1165 / 2080 | 1137 / 1979 |
| Instanzen mit Instanz-Uniforms | 63 | 102 | 63 | 102 |
| Hooks `gantry` / `radar` ms Mittel | 0,012 / 0,011 | 0,024 / – | 0,010 / 0,006 | 0,009 / – |

Lesart: `render()` im Mittel +0,4 ms (+5–6 %), die Commits im Hauptthread bleiben klein (max 5,9 ms gegen 26,9 bzw. 95,5 ms
der Basis – Rauschen der Last, nicht besser durch R6); der Chunk-Bau im Worker-Thread wird im Mittel 2,3–3,5 ms teurer
(Inseln, Dächer, Laternen, Zäune werden gebaut) und hatte je einen Ausreißer um 230 ms – er läuft neben dem Bild, nicht
in ihm. Das eine `render()`-Maximum 347 ms (Kopf, deck) steht einzeln bei einer Last von 19; mit nur einem Lauf je Stand
lässt es sich weder R6 zuschreiben noch ausschließen. Die Dächer und Tore werfen auf „Mittel“ Schatten: +5 754
Schatten-Primitive im letzten Bild (Zieltor). Auf echter Hardware (Steam Deck, Windows-GPU) ist nichts davon gemessen –
gefolgert: +7 Draw Calls und ~6 000 Schatten-Dreiecke sind dort vernachlässigbar, der teurere Chunk-Bau trifft nur den
Worker-Thread.
