## 0. Abnahme auf einen Blick

| Punkt | Ergebnis | Beleg |
|---|---|---|
| §6 R5: U1 und Somport – kein Himmel innen, Leuchten an, Ausfahrt nicht schwarz, Autos nach dem Tunnel-Ausblendgesetz | erfüllt | Render-Prüfung `tunnel_bridge_*` (0,000 % Himmel, 612 bzw. 532 Leuchtenpunkte, Ausfahrt 0,226 bzw. 0,215, 0,0 % Weiß); `test_fade_law` „Tunnel“ |
| §6 R5: B1-A/B-Bogen | erfüllt | `bilder/b1_koeln_00/01.jpg`, Render-Prüfung B1 (0,000 % offen, 0,00 % Fernboden) |
| §6 R5: Geländedeckung ≤ 0,2 % an Portalen | erfüllt | U1_portal und Somport_portal 0,000 % |
| §6 R5: jede Brücke des Netzes baut headless | erfüllt | Netzlauf `--full`: 122 Brücken, 26 Tunnel, 0 Mängel; Unit-Test je Typ |
| Entscheidung 1: Wasser, Ufer, Kaimauern, Fernwasser, Fernufer; ZS1-Regel | erfüllt | Bilder `kb_ende`, `holtenau`; `test_far_ground_water` 4/4, K1 0,000 % |
| Entscheidung 2: Köhlbrandbrücke (Pylon, Seile, nachts dunkel, Flugbefeuerung, alle Typen) | erfüllt; Pylonbeine bei Tag ± 12 % gegen Arcade (Modell) | Unit-Tests, Nachtreihe, `kb_flugfeuer_22uhr.jpg`, Bilder je Typ |
| Entscheidung 3: Tunnel (Kappe, Portal, Hügel, Nischen, Gehwege, Schilder, Altstadttunnel) | erfüllt | `test_tunnel` 8/8, Bilder `u1_*`, `somport_*`, Clip |
| Entscheidung 4: `set_zone` duck-typed, `tunnel01` bleibt, Doku | erfüllt | `test_set_zone_only_when_the_rig_has_it`, renderer-modern.md §15.1 |
| Entscheidung 5: Fairness F1/F7 | erfüllt | Unit-Tests (Röhre, Tragwerk, Seile), `modern_sight --full` |
| Bilder bei Tag und Nacht, „Hoch“ und „deck“, Clips | geliefert | Abschnitt 3 |
| Gates | grün bis auf Lastausfälle: Waldprüfung (Basisbefund M2S-01, mit längerem Zeitlimit OK) und im 2. vollen Testlauf drei Echtzeit-Klangprüfungen (einzeln grün, eine auch auf der Basis rot) | Abschnitt 6 |
| Leistung: ganze Etappe ohne Fehler, neben der Basis | gemessen | Abschnitt 7 |
