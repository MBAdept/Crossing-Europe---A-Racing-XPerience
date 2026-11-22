## Kurzfassung

- **Gebaut (A-17):** der Sichtkorridor der Kurven ist die Hülle aller Sichtlinien der Länge L entlang des wirklichen
  Pfads, Kamera in jeder Spur und auf jeder Reihe, L = min(300 m, F2-Bedarf / 0,6 + 9 m) aus der schnellsten fahrbaren
  Geschwindigkeit (`scripts/race3d/sight_corridor.gd`, einmal je Etappe, vorgerechnet im Streamer). Gelände, Requisiten,
  Stadtzäune und Grenzpfeiler lesen dieselbe Hülle; F7 prüft sie gegen eine unabhängige Referenz (0 von 388.907
  Querschnittsseiten nicht abgedeckt, ganzes Netz).
- **Was zurückkommt (gemessen, 128 Richtungen):** 23.026 Requisiten (16.947 Bäume, 1.878 Stadthäuser …), keines fällt neu
  weg; Stadtzäune 75,3 % statt 64,3 % von Arcade; Grenzdach Belgrad – Sofia km 340 steht wieder auf vier Pfeilern.
  Im Bild: T2-Baumgruppe, Starteiche, Häuserzeilen in München, Belgrad, Hannover – Kompositionen wie Arcade.
- **F2 gehalten:** `modern_sight --full` 0,593 / 0,596 / 0,555; Verdeckungssonde an T1–T4, S0, S4 überall sichtbar bis L;
  C1 bei 270 m schon in der Basis verdeckt.
- **Offen (gemessen):** der Requisiten-Builder (R7c) prüft nur den Fuß – 5.832 Requisiten ragen mit Vorderkante oder Krone
  in die Hülle (Basis 1.124). Die Prüfung mit Reichweite ist in `ChunkContext.in_bend_corridor()` gebaut; der Aufruf
  fehlt (§2, `notes_for_next`).
- **Gates:** Import sauber, Skripte 332/0, Tests 811 mit 2–3 Klang-Lastfehlern (auch auf der Basis), Arcade-Goldens 20/20
  und 17/17, Modern 2/6 (gewollt, angesehen), alle 28 Render-Prüfungen grün, Sicht und Pfad voll grün.

