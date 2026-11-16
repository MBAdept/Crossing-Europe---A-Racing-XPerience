| Kiel–Hamburg, 12 Uhr | Niedrig (ganz) | Mittel (ganz) | Hoch (km 0–33,7, Abbruch aus Zeitgründen) | Hoch, City km 78–95 | Arcade (ganz) |
|---|---|---|---|---|---|
| Laden bis zur ersten Rennszene | 15,1 s | 32,1 s | 37,5 s | CITY_LOAD | ARC_LOAD |
| davon Vorbereitung / Aufwärmen / Selbsttest | 14,0 / 12,1 / 0,72 s | 29,8 / 27,4 / 1,19 s | – | – | – |
| `render()` GDScript Mittel (Budget) | 2,10 ms (1,2) | 1,92 ms (1,5) | 2,23 ms (2,0) | CITY_AVG | ARC_AVG |
| `render()` p50 / p95 / p99 / max | 1,60 / 4,40 / 8,9 / 166 ms | 1,59 / 3,66 / 6,8 / 93 ms | 1,55 / 5,58 / 10,1 / 61 ms | CITY_P | – |
| Bilder mit Stück-Einhängen: `render()` p50 / p95 / max | 2,55 / 5,9 / 13,3 ms | 2,61 / 6,5 / 21,9 ms | 2,58 / 5,5 / 10,7 ms | CITY_C | – |
| Stück-Einhängen max (`chunk_commit_ms_max`, Budget) | 9,5 ms (3) | 20,4 ms (3) | 3,3 ms (4) | CITY_CM | – |
| Zeichenaufrufe sichtbarer Durchgang Median / max (Budget inkl. Schatten) | 118 / 145 (400) | 135 / 162 (900) | 154 / 170 (1.500) | CITY_DC | – |
| Dreiecke Median / max (Budget) | 92 k / 128 k (250 k) | 99 k / 148 k (700 k) | 103 k / 132 k (1,5 M) | CITY_PR | – |
| Texturspeicher max | 155 MB | 174 MB | 188 MB | CITY_TEX | ARC_TEX |
| Prozess-RSS max | 937 MB | 981 MB | 1.012 MB | CITY_RSS | ARC_RSS |
| Bildzeit llvmpipe p50 (nur Software) | 223 ms | 670 ms | 1.032 ms | CITY_F | ARC_F |
