# Leistungstest auf der Bau-VM (Software-Grafik llvmpipe) – Zwischenstand 1

Gemessen am 12.11.2026 mit dem echten Läufer (`-- --graphics=modern --gfx-preset=<stufe> --bench=all
--bench-out=<datei>`), Xvfb 1280 × 720, ohne Bildbegrenzung, Last der Maschine 9–12 (andere Pakete liefen mit).
**Diese Zahlen sagen nichts über den Steam Deck oder eine echte Grafikkarte** – sie zeigen, dass der Test durchläuft,
die Datei richtig schreibt (`user://leistungstest.json` = `--bench-out`, alle vier Läufe) und wie sich Draw Calls,
Dreiecke und Skriptzeit je Stufe verhalten. Die Szenen dauern je 20 s; bei 1–6 Bildern/s sind das nur 20–121 Bilder.

| Stufe | Szene | Ø fps | 1 %-low | Bildzeit p95 / p99 ms | `render()` ms Ø (max) | Draw Calls | Dreiecke (davon Schatten) | Vorbereitung s |
|---|---|---|---|---|---|---|---|---|
| Niedrig | Autobahn bei Tag | 6,0 | 2,4 | 262 / 374 | 2,13 (7,5) | 131 | 89 515 (0) | 36,0 (kalter Shader-Cache) |
| Niedrig | Stadt bei Nacht im Regen | 1,5 | 0,7 | 1 076 / 1 335 | 2,16 (8,1) | 70 | 30 393 (0) | 12,9 |
| Niedrig | Bergstrecke mit Tunnel | 2,8 | 1,7 | 455 / 590 | 2,79 (9,8) | 64 | 24 113 (0) | 13,6 |
| Mittel | Autobahn bei Tag | 1,3 | 0,9 | 1 057 / 1 061 | 2,17 (6,8) | 144 | 93 394 (7 485) | 61,7 |
| Mittel | Stadt bei Nacht im Regen | 1,0 | 0,8 | 1 211 / 1 213 | 2,95 (17,7) | 76 | 31 458 (1 756) | 15,8 |
| Mittel | Bergstrecke mit Tunnel | 1,5 | 0,9 | 1 152 / 1 171 | 2,26 (6,1) | 80 | 33 187 (7 193) | 23,6 |
| Hoch | Autobahn bei Tag | 1,2 | 0,9 | 1 090 / 1 133 | 2,22 (5,0) | 160 | 107 220 (18 796) | 47,5 |
| Hoch | Stadt bei Nacht im Regen | 1,2 | 0,8 | 1 064 / 1 273 | 2,72 (7,1) | 99 | 52 568 (17 052) | 13,7 |
| Hoch | Bergstrecke mit Tunnel | 1,3 | 1,0 | 990 / 1 013 | 2,27 (6,3) | 101 | 52 545 (21 785) | 19,2 |
| Steam Deck | S3 Kiel – Hamburg km 60 | 1,3 | 0,8 | 973 / 1 304 | 2,22 (14,7) | 135 | 102 558 (6 488) | 29,6 |
| Steam Deck | C1 Dortmund – Frankfurt km 221 | 1,5 | 1,2 | 789 / 845 | 3,02 (11,1) | 115 | 34 788 (1 042) | 10,7 |

Urteil des Tests selbst: Niedrig „too_slow“ → Vorschlag **Arcade**; Mittel und Hoch „slow“ → eine Stufe tiefer
(richtig für Software-Grafik). Gerät „llvmpipe (LLVM 20.1.2, 256 bits)“, Stufe „software“, Version im Feld
`game_version` hier 0.7.0 (im Testbuild 0.8.0-zs1).

**Budget `deck` an S3 und C1** (Vertrag §4.10, Steam Deck: 650 Draw Calls, 450 000 Dreiecke, `render()` 1,5 ms):
Draw Calls 135 / 115 und Dreiecke 102 558 / 34 788 liegen weit darunter; **`render()` mit 2,22 / 3,02 ms darüber** –
gemessen unter Last 9–11 auf geteilten Kernen über den GL-Pfad. Kopflos bei normalem Tempo misst
`check_modern_stage` 0,911 ms für den ganzen Renderer bei Ø 13 Autos (Lauf 1). Was der Deck-Kern wirklich braucht,
zeigt erst der Leistungstest des Nutzers (abgeleitet).
Auffällig: Die Engine meldet für die Schattendurchgänge 0 Draw Calls, aber Dreiecke (Mittel/Hoch) – die Zählung der
Schatten-Draw-Calls fehlt in Compatibility offenbar; das Budget „Draw Calls inkl. Schatten“ ist so nicht vollständig
messbar (Hinweis an PERF).
