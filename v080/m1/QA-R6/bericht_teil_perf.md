## 6. Leistung (gemessen auf dieser VM; über das Deck und echte GPUs nichts gemessen)

### 6.1 GDScript-Zeit des ganzen Renderers bei normalem Tempo (headless, Methode von `renderer_zeit`)

Eigene Variante `tests/race3d/check_qa_zeit.gd` (aus `check_modern_stage.gd`: `_drive_time()`, 600 Bilder bei 150 km/h mit dem
Verkehr der Sitzung, Zeit mit dem Referenztakt `perf_clock.gd` auf das Normaltempo der VM skaliert, je Ort das bessere von
zwei Durchgängen), je viermal Kopf (`c8b18d1`) und Basis (`6e48405`) abwechselnd, Last 14–19:

| Ort (DEV) | Kopf ms (4 Läufe) | Mittel | Basis ms (4 Läufe) | Mittel |
|---|---|---|---|---|
| Autobahn km 30 | 0,87 / 0,88 / 1,00 / 1,08 | 0,96 | 0,92 / 1,16 / 1,17 / 1,13 | 1,10 |
| Tankstelle km 18,4 | 0,99 / 1,04 / 1,18 / 1,27 | 1,12 | 0,80 / 1,08 / 1,10 / 1,32 | 1,08 |
| Grenze km 64,2 | 1,07 / 1,43 / 1,29 / 1,24 | 1,26 | 1,02 / 1,04 / 1,41 / 1,02 | 1,12 |
| Stadt km 109,6 | 1,23 / 1,20 / 1,31 / 1,31 | 1,26 | 1,16 / 1,38 / 1,32 / 1,29 | 1,29 |
| Start km 0 | 0,95 / 1,03 / 1,10 / 1,29 | 1,09 | 0,63 / 1,02 / 1,04 / 1,31 | 1,00 |
| Tankstelle 21 Uhr | 0,99 / 1,12 / 1,22 / 1,16 | 1,12 | 1,11 / 1,25 / 1,35 / 1,24 | 1,24 |
| Stadt 21 Uhr | 1,20 / 1,36 / 1,46 / 2,22* | 1,56 | 1,24 / 1,56 / 1,45 / 1,47 | 1,43 |

\* ein Lauf mit einem 193-ms-Bild (Last). Lesart: Unterschiede Kopf – Basis −0,14 … +0,14 ms, also im Rauschen (±0,15 ms);
alle Mittel bis auf den Ausreißer unter dem Deck-Budget 1,5 ms (§4.10). Längstes Bild je Lauf 6–193 ms in **beiden** Ständen;
Chunk-Einhängen im Hauptthread höchstens 4,9 ms (Kopf) bzw. 9,8 ms (Basis) – beide über dem 3-ms-Budget nur in einzelnen
Läufen, lastabhängig.

`collect()` der fünf Builder im Hauptthread (eigenes Werkzeug `bin/collect_time.gd`, Track wie im Spiel fortlaufend erzeugt,
Pfad 36 Stücke voraus; DEV, Kiel – Hamburg, Prag – Nürnberg): Tankstelle ≤ 0,39 ms, Grenze ≤ 0,27 ms, Tor ≤ 0,14 ms,
Blitzer ≤ 0,02 ms je Stück, Mittel ≤ 0,02 ms – vernachlässigbar.

### 6.2 Ganzer Lauf unter Xvfb, Voreinstellung `deck`, 1280 × 800 (`bin/perf.sh`: `run_stage.gd` DEV 21 Uhr, Zeitraffer 40)

| `perf_stats` | Kopf | Basis |
|---|---|---|
| `render()` ms Mittel / max | 6,75 / 133,9 | 5,42 / 52,7 |
| davon Hook `streamer` ms Mittel / max | 4,11 / 132,2 | 3,07 / 50,4 |
| Chunk-Einhängen max (Hauptthread) | 4,52 ms | 2,39 ms |
| Chunk-Bau ms Mittel / max (Worker-Thread) | 6,84 / 84,7 | 6,17 / 77,0 |
| Draw Calls / Primitive / Schatten-Primitive (letztes Bild, Ziel) | 83 / 75 885 / 8 316 | 77 / 75 885 / 3 384 |
| Instanzen mit Instanz-Uniforms | 63 | 102 |
| Hooks `gantry` / `radar` ms Mittel | 0,009 / 0,004 | 0,013 / – |
| Ergebnis | 130 km, 0 Kollisionen, 0 Skriptfehler, `time_s` 376,85 | gleich |

Lesart: Im Zeitraffer 40 baut und hängt der Streamer je Bild viele Stücke ein; dort kostet R6 im Mittel +1,0 ms im Streamer und
das längste Bild war höher (133,9 gegen 52,7 ms). R6 maß dasselbe Muster (347 gegen 145 ms) – zwei von zwei Läufen, also
wahrscheinlich echt, aber nur im Zeitraffer: bei normalem Tempo (6.1) ist kein Unterschied messbar. Das Einhängen eines Stücks
liegt mit 4,5 ms über dem Deck-Budget von 3 ms (Basis 2,4 ms; R6 maß 5,6 gegen 95,5 ms – sehr verrauscht). Gefolgert: Spitzen
kommen vom Einhängen großer Stadt-Stücke (Zäune als `ArrayMesh`, Laternen-MultiMeshes, `add_lamps`); auf dem Deck nachmessen
(Leistungstest). +6 Draw Calls und ≈ +4 900 Schatten-Dreiecke am Zieltor liegen weit unter dem Budget (650 / 450 000).
