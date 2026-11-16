## Leistung (llvmpipe, Last 17–23 – nur Proxies)

### Methode

`probe/qa_drive.gd` – dieselbe Sonde, mit der M1-QA-BILD den Stand von gate1 (= ZS1 ohne die Behebungen, Code der
Strecke gleich) gemessen hat, unverändert: Kiel–Hamburg ab km 0, Autopilot (Tankstopp km 13,9), 12 Uhr, Limousine,
Seed 11, `--timescale=2` (8 Physikschritte je Bild, 0,133 s Spielzeit je Bild, 2 476 Bilder für die ganze Etappe), Xvfb
1280 × 720, `nice -n 10`, gemeinsamer warmer Mesa-Shader-Cache, eigenes leeres `XDG_DATA_HOME` je Fahrt. Je Bild
Wanduhr, GDScript-Zeit von `render()`, ob ein Stück eingehängt wurde; alle 5 s Speicher, Zähler, `perf_stats()`.
Referenz: die Fahrten von M1-QA-BILD (Last 4–14). Weil die Last diesmal höher war, ist das Arcade-Bild der Maßstab:
Arcade brauchte dieselbe Fahrt im Median 204 ms je Bild statt 148 ms (× 1,38).

### Ganze Etappe Kiel–Hamburg (gemessen)

| | Niedrig M2 | Niedrig Ref. | Mittel M2 | Mittel Ref. | Arcade jetzt / Ref. |
|---|---|---|---|---|---|
| Laden bis zum ersten Rennbild | 59,1 s | 15,1 s | 47,5 s | 32,1 s | 0,8 / 0,7 s |
| davon Vorbereitung / Aufwärmen | 58,0 / 54,8 s | 14,0 / 12,1 s | 42,6 / 38,3 s | 29,8 / 27,4 s | – |
| `render()` GDScript Mittel / p50 / p95 / p99 | 2,41 / 1,73 / 6,44 / 13,1 ms | 2,10 / 1,60 / 4,40 / 8,9 | 4,04 / 1,81 / 7,96 / 16,8 ms | 1,92 / 1,59 / 3,66 / 6,8 | (Arcade `_draw` ≈ 9 ms, M1) |
| `render()` längstes Bild | 36,8 ms | 166 ms | **1 154 ms** | 92,6 ms | – |
| Bilder mit Stück-Einhängen p50 / p95 / max | 2,7 / 6,7 / 10,6 ms | 2,6 / 5,9 / 13,3 | 2,9 / 10,9 / 157 ms | 2,6 / 6,5 / 21,9 | – |
| `chunk_commit_ms_max` (Budget 3 ms) | 7,5 ms | 9,5 | 13,0 ms | 20,4 | – |
| Sammeln (`collect`) eines Stücks Mittel / max | – | – | 8,9 / 598 ms | 1,6 / 3,6 | – |
| Bauen eines Stücks (Worker) Mittel / max | – | – | 8,0 / 42,9 ms | 4,8 / 23,0 | – |
| Zeichenaufrufe sichtbar Median / max | 120 / 158 | 118 / 145 | 145 / 181 | 135 / 162 | – |
| Dreiecke Median / max | 116 k / 157 k | 92 k / 127 k | 132 k / 179 k | 98 k / 147 k | – |
| Texturspeicher max | 100 MB | 155 MB | 120 MB | 174 MB | 207 / 207 MB |
| Prozess-RSS max | 1 046 MB | 937 MB | 1 066 MB | 981 MB | 577 / 578 MB |
| Bildzeit p50 (llvmpipe, nur Software) | 250 ms | 223 ms | 1 385 ms | 670 ms | 204 / 148 ms |
