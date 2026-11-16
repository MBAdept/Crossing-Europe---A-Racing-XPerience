## 7. Leistung – ganze Etappe im Modus Modern (gemessen auf llvmpipe; echte Hardware abgeleitet)

`m1/R5/tools/perf.sh new|base`: Kiel – Hamburg ab km 0 bis zum Ziel (Köhlbrandbrücke, Elbbrücken: Wasser, Ufer,
Fernwasser, Pylone, Seile, Fachwerk), Autopilot mit Tankstopp, 12 Uhr, Limousine, Seed 11, `--timescale=4`,
Stufe „Mittel“, Xvfb 1280 × 720, `tests/race/run_stage.gd`; derselbe Aufruf im Worktree (R5-Endstand) und in der
Basiskopie (6e48405). Beide Läufe: Etappe beendet (`aborted` false, 95 km, 326,3 s Spielzeit, 1 Tankstopp),
**0 Skript- und 0 Shaderfehler**.

| | Basis | R5 |
|---|---|---|
| Wanduhr (Last der Nachbarn) | 3127 s | 3914 s |
| `sim_avg_ms` / `sim_max_ms` (von R5 unberührt – Maß der Last) | 1,73 / 169 | 2,00 / 328 |
| Bilder | 2478 | 2478 |
| Bildzeit Median / p95 (llvmpipe) | 1512 / 2461 ms | 1506 / 2451 ms |
| `render()` Mittel / max | 3,13 / 115,7 ms | 3,97 / 139,7 ms |
| `chunk_commit_ms_max` | 19,0 ms | 8,0 ms |
| Stück-Bau im Worker Mittel / max | 10,7 / 98,7 ms | 18,2 / 374,4 ms |
| Haken `bridge` Mittel / max | – | 0,039 / 6,3 ms |
| Haken `tunnel` Mittel / max | 0,012 / 20,1 ms | 0,008 / 8,1 ms |
| Haken `far_ground` Mittel / max | 0,258 / 17,7 ms | 0,423 / 69,9 ms |
| Texturspeicher | 119,9 MB | 120,7 MB |
| Vorbereitung (`prepare_ms`) | 35,4 s | 32,3 s |
| Zeichenaufrufe / Primitive (`perf_stats`: nur das letzte Bild, Hamburg) | 105 / 93 050 | 105 / 93 050 |

**Zeichenaufrufe und Primitive an R5-Stellen** (gemessen, Mittel über 30 Bilder, ruhende Etappe ohne Verkehr, HUD aus,
„Mittel“, 1280 × 720; Skript `m1/R5/scratch_gd/r5_scratch_counters.gd`, nicht eingecheckt):

| Stelle | Basis Aufrufe / Primitive | R5 Aufrufe / Primitive |
|---|---|---|
| Köhlbrandbrücke Deck (km 78,2) | 117 / 112 042 | 139 / 125 400 (+22 / +12 %) |
| Köhlbrandbrücke Rampe (km 77,4) | 125 / 114 117 | 142 / 125 425 (+17 / +10 %) |
| Gotthard vor dem Portal (km 184,4) | 57 / 68 168 | 57 / 78 580 (0 / +15 %) |
| Gotthard innen (km 188) | 35 / 55 716 | 35 / 64 276 (0 / +15 %) |

Gegen die Budgets von §4.10 („Mittel“: 900 Aufrufe, 700 000 Primitive; „deck“: 650 / 450 000) liegen beide Stände
weit darunter; die Röhre bleibt bei denselben Aufrufen (Gehwege, Paneele, Nischen in denselben Meshes). **Über dem
Budget** liegen auf dieser VM unter Last schon in der Basis `render()` im Mittel (Budget 1,5 ms: Basis 3,13, R5 3,97)
und `chunk_commit_ms_max` (Budget 3 ms: Basis 19,0, R5 8,0) – R5 legt beim Mittel 0,84 ms drauf (zum Teil Last, siehe
Lesart), beim Commit nichts.

**Lesart.** Der R5-Lauf lief unter höherer Last (die von R5 unberührte Simulation brauchte 16 % länger, die Wanduhr
25 % länger); die Bildzeit ist gleich. `render()` stieg im Mittel um 0,84 ms, davon gehen 0,17 ms auf `far_ground`
(Fernwasser, Fernland, Fernufer) und 0,04 ms auf `bridge` (Himmel des Wassers) – der Rest liegt in Haken, die R5 nicht
berührt (Umgebung, Gelände), also bei der Last. Der Stück-Bau im Worker kostet mit Wasser, Ufern und Tragwerk im Mittel
7,4 ms mehr; die Spitze 374 ms (ein Köhlbrand-Stück unter Last) verzögert nur das Eintreffen des Stücks, nicht das Bild.
**Die Spitze `far_ground` 69,9 ms** (Basis 17,7 ms) fällt wahrscheinlich auf das Bild, in dem Fluss und Fernland einer
Brücke entstehen – je Brücke einmal; auf einem Steam Deck **abgeleitet** rund ein Viertel davon (≈ 15–20 ms, ein
verlorenes Bild). Hinweis in Abschnitt 8.
