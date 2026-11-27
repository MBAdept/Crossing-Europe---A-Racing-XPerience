# Rückmeldung des Nutzers zu ZS2

## 25.11. abends – Hauptrechner (Linux)
- „Gut, auf meinem Hauptrechner GAR KEIN Problem … Gleiche FPS auch unter "high", beide laufen in die FPS-Bremse.
  Sollte auf dem Steam Deck auch gar kein Problem sein, kann ich aber erst am Wochenende testen.“
- leistungstest_pc_rx9070xt_medium.json: AMD Radeon RX 9070 XT (radeonsi, Mesa 26.2.7), Ryzen 9 9950X3D, Manjaro,
  2560×1440, „Mittel“, OpenGL 4.6, vsync aus, 280 Hz.
  | Szene | avg fps | 1 % low | p95 ms | p99 ms | Median ms | Skript ms | Sim ms | Draw Calls (Bild) | VRAM MB |
  |---|---|---|---|---|---|---|---|---|---|
  | Autobahn bei Tag | 592 | 350 | 2,22 | 2,58 | 1,59 | 0,35 | 0,44 | 289 | 447 |
  | Stadt bei Nacht im Regen | 523 | 297 | 2,77 | 3,15 | 1,72 | 0,48 | 0,29 | 270 | 388 |
  | Bergstrecke mit Tunnel | 598 | 311 | 2,50 | 2,93 | 1,49 | 0,44 | 0,40 | 194 | 453 |
  Vorschlag „high“/modern, Urteil ok, schlechteste Szene Stadt Nacht Regen, Reserve 9,69 × gegen 60 Bilder/s, keine
  Spitzen (spikes leer); größter Haken streamer 3,2 ms (Autobahn, erstes Laden), prepare 1,24 s.
  Deutung: der Leistungstest hebt die Bildbremse auf (Engine.max_fps = 0, vsync aus) – ~600 Bilder/s in „Mittel“ und
  „Hoch“ heißt, die Grafikkarte ist kaum ausgelastet; die Grenze ist die Arbeit der CPU je Bild (~1,6 ms).
- Offen: Steam Deck (Wochenende), Windows, Fragen C.1–C.9 (Nacht, Regen-/Schneenacht, Kurvenkamera, Musik).
