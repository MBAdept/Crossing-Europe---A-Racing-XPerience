Der echte Läufer (`-- --graphics=modern --gfx-preset=<stufe> --bench=all --bench-out=<datei>`) unter Xvfb 1280 × 720,
ohne Bildbegrenzung, Last 9–12. Alle vier Läufe Exit 0, `user://leistungstest.json` jeweils byte-gleich mit
`--bench-out`. Tabelle und Dateien: `leistungstest/tabelle.md`, `leistungstest/*.json`.

| Stufe | Autobahn bei Tag | Stadt bei Nacht im Regen | Bergstrecke mit Tunnel | `render()` Ø | Draw Calls | Dreiecke | Urteil / Vorschlag |
|---|---|---|---|---|---|---|---|
| Niedrig | 6,0 fps (p95 262 ms) | 1,5 fps | 2,8 fps | 2,13–2,79 ms | 64–131 | 24 113–89 515 | too_slow → **Arcade** |
| Mittel | 1,3 fps | 1,0 fps | 1,5 fps | 2,17–2,95 ms | 76–144 | 31 458–93 394 | slow → Niedrig |
| Hoch | 1,2 fps | 1,2 fps | 1,3 fps | 2,22–2,72 ms | 99–160 | 52 545–107 220 | slow → Mittel |
| Steam Deck an S3 / C1 | 1,3 / 1,5 fps | – | – | 2,22 / 3,02 ms | 135 / 115 | 102 558 / 34 788 | slow → Niedrig |

- Die Bildraten sind Software-Grafik auf einer belasteten VM und sagen **nichts** über den Steam Deck (abgeleitet).
  Ein Szenendurchlauf hat bei 1–6 Bildern/s nur 20–121 Bilder; die Perzentile sind entsprechend grob.
- Budget `deck` (650 Draw Calls, 450 000 Dreiecke, 1,5 ms `render()`): Draw Calls und Dreiecke bei S3 und C1 weit
  darunter; `render()` darüber (2,22 / 3,02 ms, unter Last über den GL-Pfad; kopflos bei normalem Tempo 0,911 ms für den
  ganzen Renderer). Abweichung gemeldet; was der Deck-Kern braucht, zeigt der Leistungstest des Nutzers.
- Die Engine meldet für die Schattendurchgänge 0 Draw Calls, aber Dreiecke (Mittel/Hoch: 1 042–21 785) – die Schatten-
  Draw-Calls zählt Compatibility offenbar nicht; das Budget „Draw Calls inkl. Schatten“ ist so nicht vollständig messbar.
- Vorbereitung je Szene 10,7–61,7 s (Modelle, Schilder, Shader-Aufwärmen hinter dem Ladebild; der erste Lauf mit
  kaltem Shader-Cache am längsten).
