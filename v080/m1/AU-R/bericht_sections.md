## 2. Abnahme – Punkt für Punkt

| Punkt | Ergebnis | Beleg |
|---|---|---|
| R1 Wiederholung im Spielmix (20 s, festes Tempo): keine Spitze ≥ 0,40 bei 0,3–3 s | Asphalt 130 (0,6–1,6 kHz) **bestanden**: {R1_ASPH}; Pflaster 50 **bestanden**: {R1_COB}; Beton 130 (2,5–8 kHz) **nicht bestanden**: {R1_CONC} – das ist der Takt der Platten (eine Fuge alle 5 m), ohne Plattenschicht 0,11 | 3.1 |
| R1 Mittel: eigene Schleife je Seite (zweiter Seed, Längen 4,1–7,6 s, Verhältnis kein kleiner Bruch), zufälliger Start, Pegeldrift ±1,5 dB (τ 0,8 s), rechts × 1,02 (Rüttelstreifen genau), Ogg q5 mit geprüfter Naht | umgesetzt; QC: Nähte ×0,02–1,89 (erlaubt ×2; am rauesten `wind_buffet`, deshalb q8), 59 Klänge 0 Fehler | `pruefung_qc_determinismus.txt` |
| R2 fmix32 auf `key.hash()`; Anteile je Land/Stadt über alle Etappen ±0,05 | Pflaster: 47 von 47 Altstädten (0,55–0,64), gesamt 0,566; Beton: 14 von 18 Ländern, gesamt 0,205 (Soll 0,207); SI, LT, BG, LV können es nicht (1–5 Abschnitte) | 3.2 |
| R3 Plattenmuster nie gegenphasig; `slabs.db` 3; Tunnel-Wind 0 | **bestanden**: 141 s Fahrt 100–160 km/h, größter Abstand 4,5 ms, 0 Nachstellungen | 3.3 |
| R4 Fugen je Deck, belegt im Triggerlog | **bestanden**: Köhlbrandbrücke 12 → 4, Elbbrücken 9 → 3, Damm Venedig 17 → 13, Steinbogen Paris 6 → 0 | 3.4 |
| R5 Begrenzer nur im Modern-Zweig (MMaster hinter dem Kleber, −2,0 dB, 0,12 s) | umgesetzt (`audio.modern.limiter`, `modern_buses.gd`); Test `test_limiter_from_config` | |
| R5 Unfall 130, Höchsttempo, schlimmster Fall ≤ −1,0 dBTP bei Gesamtlautstärke 1,0 | **bestanden**: −1,71 / −2,93 / −1,59 dBTP (Lkw −1,66); vorher −0,62 / −2,77 / −0,47 | 3.5 |
| R5 Reisen 130–200 km/h: Begrenzung ≤ 0,5 dB | 130 und 170 km/h, 200 auf Asphalt: 0 dB; **200 km/h auf Beton nicht**: 12 Eingriffe je Minute, höchstens 1,0 dB (mit dem Pegel von AU-C1 wären es 16 und 1,5 dB) – die Plattenschläge liegen bei −2,7 dBFS | 3.5 |
| R5 Unfall: Begrenzung > 3 dB → nur die lauteste schwere Schicht senken | `hit_heavy` (schwer) −9,0 → −11,5 dB, Lkw-Schlag (schwer) −10 → −11 dB: höchstens 2,4 dB (24 Unfälle) bzw. 2,1 dB (16) | 3.5 |
| R5 Plan-Zeile Höchsttempo −15 ± 1 LUFS mit Test | **bestanden**: −14,9 LUFS (Gesamtlautstärke 0,8); `test_top_speed_row_of_the_plan` | |
| R5 Arcade-Busse, -Begrenzer, -Konfiguration unverändert | **bestanden** (3.8) | |
| R6 je ≥ 4 Varianten Glas / Kleinteile / Lkw-Schlag, Spektrum ±1 dB | **bestanden**: höchstens 0,20–0,91 dB gegen die Datei von AU-C1 | 3.6 |
| R6 Zufall ±2 dB / ±10 ms je Schicht (Unfall, Vorbeifahrten), Glas ab 80 km/h oder 40 %, Quietschen ±5 %, keine Rüttellinie neben der Tankspur, eigene Schnee-Schleife | **umgesetzt**, Tests in `test_road_audio.gd` / `test_audio_feed.gd`; Tankspur im Triggerlog 5 → 0 Bilder | 3.4, 3.6 |
| Klangfarbe: Terzen ±1 dB bei den Bezugstempi, Lautheit ±0,5 LU | {CHAR_SUMMARY} | 3.7 |
| QC (Nähte, Pegel, Determinismus) | **bestanden**: „59 Klänge geprüft, 0 mit Fehlern“, alle vier Generatoren deterministisch | `pruefung_qc_determinismus.txt` |
| `check_arcade_lean`, eingefrorene Dateien | **bestanden**: 0 von 35 Modern-Skripten geladen; 0 eingefrorene Dateien seit AU-C1 geändert | 3.8 |
| `tools/run_tests.sh` | {TESTS} | `pruefung_run_tests.txt` |
| `tools/golden.sh check` | {GOLDEN} | `pruefung_golden.txt` |
