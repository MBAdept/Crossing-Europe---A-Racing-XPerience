## 2. Entscheidungen der Leitung – Umsetzung

**1. Wasser, Ufer, Kaimauern, Böschungen, Fernwasser, Fernufer sind R5s.** Arcade (`RoadRenderer._draw_water`) malt die
Zeilen der Uferböschung in der Kaifarbe bzw. der Uferfarbe der Brücke; Modern malte sie als Wasser. Jetzt baut
`bridge.gd` auf genau diesen Zeilen die Ufer nach Arcades Regel (`Track._build_bridge`: Böschung = ein Segment bei
niedrigen Brücken ohne Uferfarbe → Kaimauer; sonst Böschung), das Wasser liegt darüber bis zum Bandende, und
`far_ground.gd` setzt den Fluss jenseits der Bänder fort (Fernwasser bis 3 km, Fernland auf der alten Höhe der Scheibe,
Fernufer). **Köhlbrand-Ende**: statt „Wasser, das ins Grün übergeht“ graue Natursteinböschung in Arcades Kaifarbe
(Bilder `kb_ende`). **Holtenau**: grüne Böschungen mit Steinschüttung, dahinter Land – der Kanal liest sich als Kanal
wie in Arcade, nicht mehr als See (Bilder `holtenau`).

**2. Köhlbrandbrücke als Schaustück.** Pylon = `props/bridge_pylon_bare`, Höhe `height_m`/88,8 (95 m), dazu Arcades
Kopfblock; Seile von R5 nach Arcades Gesetz (7 je Richtung, Spannweite `cables` 62,6 m, 0,07 m); nachts dunkel
(`emit_energy` 0, `night_albedo` 0,45 – aus M2ZS1 übernommen) und rote Flugbefeuerung bei 96,6 m mit Arcades Takt
(1,6 s / 0,8 s / Seite × 0,4 s); kein Seil über einer Spur (Unit-Test, ≥ 1,5 m jenseits der Spuren an drei
Schrägseilbrücken); jeder Brückentyp baut headless (Unit-Test; alle 122 Brücken des Netzes mit einem Skript im
Arbeitsordner, 119,5 s, gemessen); Bilder B1 (Severinsbrücke, Schrägseil) + Holtenau (Balken), Elbbrücken
(Fachwerk), Ludwigsbrücke Würzburg (Stein). Pylonbeine bei Tag: Abschnitt 4.

**3. Tunnel U1 und Somport.** Kein Himmel innen (Render-Prüfung: 0,000 % Leinwand im ganzen Bild, U1 km 188); Leuchten
an (612 Leuchtenpunkte über der Horizontzeile; von außen bei Tag Arcades Lichthof); Ausfahrt weder schwarz noch
ausgebrannt (Leuchtdichte 0,226, 0 % reines Weiß; Arcade überbelichtet das Draußen – Sache der Umgebung, Hinweis an R4);
Autos innen nach dem Tunnel-Ausblendgesetz (Ebene `vehicles`, R3: `VehiclePose3D.fade(…, in_tunnel, 260)`, Unit-Test
`test_fade_law` „Tunnel“ grün); Kappe bei `peek_m` nur von außen (Unit-Test, Bilder `u1_anfahrt`); Portalrahmen und
Hügel schließen das Gelände (Render-Prüfung U1/Somport-Portal: 0,000 % Leinwand unter der Horizontzeile, Grenze
0,2 %); Nischen, Gehwege, Wandschilder (Bilder `u1_innen`, `somport`).

**4. `set_zone` duck-typed, `tunnel01` bleibt.** `tunnel.gd` ruft `env.set_zone("tunnel", amount)` nur, wenn das Rig die
Methode hat, und nur bei Änderung; ohne sie bleibt der Weg des Rigs (`tunnel_blend`) unverändert. Aufrufe dokumentiert
in `docs/renderer-modern.md` §15.1. `environment_rig.gd` nicht angefasst.

**5. Fairness F1/F7.** Nichts der Röhre über den Spuren unter 5,2 m, nichts über dem Bankett unter 4 m; nichts vom
Tragwerk in den Spuren; Seile ≥ 1,5 m jenseits der Spuren (Unit-Tests). Der Hügel schneidet nie durch die Röhre
(Unit-Test). `modern_sight --full` und `modern_path_check --full` grün (Abschnitt 6).
