## 5. Kosten (llvmpipe-Maschine unter Last 13–16, gemessen; Steam Deck abgeleitet)

- **Je Reihe:** der Kern in `modern_sight` (12 härteste Etappenrichtungen, 103.583 Segmente) 8,4 s → **81 µs je Reihe**;
  Bergstrecken mit dem ersten Stand (vor dem „einfachen“ Fächer) 230–265 µs, Kiel – Hamburg 106–114 µs (`probe/cost.gd`).
  Der einfache Fächer (Straße dreht bis L < 1,2 rad) spart 35–45 % je Kamera (gemessen an den sechs Fällen).
- **Im Spiel** wird jede Reihe einmal gerechnet; bei 250 km/h rückt die Kamera 0,4 Reihen je Bild vor, also
  ~30–100 µs je Bild im Mittel. Damit das nicht in Spitzen beim Sammeln eines Stücks fällt (32 Reihen auf einmal:
  2,5–8 ms), rechnet der Streamer in Bildern ohne Sammeln/Festschreiben voraus (höchstens 0,25 ms und eine Kamera
  je Bild).
- **Vorbereitung (Ladebild):** die ersten ~1,8 km einer Etappe (Vorlauf, Stücke bis 1.500 m, zwei Stücke Reserve):
  ~600 Reihen × 81–250 µs = **50–150 ms** zusätzlich beim ersten `update()` (behind the overlay; RINT-M2: 77–114 ms).
- **Speicher:** je Reihe zwei Float (Hülle) + ein Float (Bedarf) + der Geometrieblock (12 Felder × ~134 Reihen) –
  unter 100 kB je Etappe (abgeleitet aus den Feldgrößen; das Fenster wird mit dem Pfad abgeschnitten).

**Ganze Etappe mit `perf_stats` (gemessen):** `tests/race/run_stage.gd` Kiel – Hamburg, Modern „Mittel“, Autopilot,
Seed 7, 12 Uhr, gleiche Maschine allein (Last 3–4, bei ×4 7–8 durch andere Pakete), warmer Shader-Cache (das erste
Paar lief mit kaltem Cache für R7a: `prepare_ms` 56 s statt 22 s war der Cache, nicht der Korridor – verworfen).
„×40“ = Zeitraffer 40 (ganze Etappe, 1,3 s Fahrt je Bild), „×4“ = Zeitraffer 4, 420 s Wandzeit (die ersten ~2 km, 0,13 s
Fahrt je Bild). `ERGEBNIS` von Basis und R7a identisch (MD5 der Zeile).

| Wert | Basis ×40 | R7a `e81886a` ×40 | R7a `7d8bbb6` ×40 | Basis ×4 | R7a `e81886a` ×4 | R7a `7d8bbb6` ×4 |
|---|---|---|---|---|---|---|
| render_ms_avg | 3.62 | 4.33 | 4.46 | 1.92 | 1.82 | 2.06 |
| render_ms_max | 10.30 | 21.32 | 24.16 | 30.59 | 26.02 | 21.84 |
| frame_ms_median | 639.15 | 614.37 | 774.41 | 757.92 | 740.16 | 714.15 |
| frame_ms_p95 | 865.39 | 903.49 | 1157.44 | 1045.72 | 1005.70 | 947.69 |
| frames | 263 | 263 | 263 | 547 | 622 | 538 |
| streamer.collect_ms_avg | 1.61 | 3.15 | 2.95 | 1.98 | 1.96 | 2.02 |
| streamer.collect_ms_max | 5.60 | 10.24 | 9.66 | 4.05 | 2.38 | 2.85 |
| streamer.commit_ms_max | 1.90 | 2.82 | 1.66 | 2.07 | 1.69 | 9.85 |
| load.collect_ms_avg | 2.72 | 5.33 | 5.83 | 2.84 | 5.73 | 5.60 |
| load.collect_ms_max | 7.17 | 12.87 | 12.93 | 7.18 | 14.04 | 14.36 |
| load.commit_ms_max | 12.84 | 6.89 | 8.89 | 9.38 | 8.23 | 64.52 |
| chunk_build_ms_avg | 4.67 | 5.34 | 5.55 | 5.40 | 6.47 | 7.84 |
| chunk_build_ms_max | 21.35 | 16.16 | 22.45 | 10.74 | 25.88 | 31.21 |
| streamer.corridor_warm_ms_avg | – | 0.12 | 0.24 | – | 0.06 | 0.09 |
| streamer.corridor_warm_ms_max | – | 0.63 | 2.15 | – | 1.77 | 8.23 |
| hooks_ms_avg.props | 0.09 | 0.15 | 0.15 | 0.05 | 0.05 | 0.06 |
| hooks_ms_max.props | 0.41 | 14.32 | 13.47 | 1.21 | 1.68 | 3.53 |
| hooks_ms_avg.streamer | 1.72 | 2.35 | 2.35 | 0.29 | 0.36 | 0.46 |
| hooks_ms_max.streamer | 7.66 | 10.99 | 12.63 | 4.28 | 6.77 | 19.72 |
| draw_calls | 156 | 156 | 156 | 137 | 137 | 131 |
| primitives | 181985 | 181985 | 181985 | 109974 | 142440 | 108995 |
| primitives_shadow | 70557 | 70557 | 70557 | 12190 | 12480 | 9310 |
| prepare_ms | 16271.00 | 15256.00 | 17692.00 | 20870.00 | 15622.00 | 19772.00 |
| prewarm_ms | 13661.81 | 12984.33 | 15025.23 | 18252.03 | 13109.22 | 16938.52 |
| wall_s | 175.10 | 177.72 | 211.37 | 420.18 | 420.86 | 420.18 |

- **Zeitraffer 40** fährt 12 Reihen je Bild; der Korridor kostet dann 1–3 ms je Bild, mehr als das Vorrechnen in freien
  Bildern schafft: Sammeln +1,3–1,5 ms im Mittel, und der Requisiten-Hook rechnete bis 14 ms nach (die fernen
  Wahrzeichen lesen das Gelände ihrer Reihe bis 1.900 m voraus, das Vorrechnen reichte nur bis load_path_m + 2 Stücke).
  `7d8bbb6` rechnet bis hinter `landmark_path_m` voraus (beim Laden auf einmal) und misst das Nachrechnen
  (`corridor_sync_*`): bei ×40 bleibt es (2.124 Aufrufe, 133 ms, höchstens 13 ms) – das ist der Zeitraffer.
- **Zeitraffer 4** (näher am Spiel): Sammeln im Mittel gleich (2,02 / 1,96 gegen 1,98 ms), Requisiten-Hook im Mittel
  gleich (0,06 / 0,05 gegen 0,05 ms), `render()` im Mittel 2,06 / 1,82 gegen 1,92 ms; **nach dem Laden kein
  Nachrechnen** (`corridor_sync`: alle 385 Aufrufe mit 31 ms im Laden). Die Maxima streuen unter der Last der anderen
  Pakete (die Basis hat selbst `render_ms_max` 30,6 ms); `load.commit_ms_max` 64,5 ms in einem Lauf ist ein
  Einzelwert beim Laden.
- **Laden:** `load.collect_ms_avg` 5,3–5,8 statt 2,7–2,8 ms, höchstens 14 ms (die Hülle der ersten Stücke, hinter dem
  Ladebild); `prepare_ms` gleich (15–20 s, die Shader überwiegen).
- **Draw Calls / Primitive** am Ziel gleich (156 / 181.985 / 70.557 im Schatten); bei ×4 enden die Läufe an
  verschiedenen Stellen (nicht vergleichbar).
- **Steam Deck (abgeleitet):** bei 60 fps und 250 km/h rückt die Kamera 0,4 Reihen je Bild vor; das Vorrechnen schafft
  in freien Bildern 1–3 Reihen – drei- bis achtfach genug. Ein Spieler sieht die ×40-Spitzen nicht; ein Rechner, der
  unter 15 fps fällt, käme in den Bereich von ×4.
