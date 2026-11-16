## 2. Entscheidungen der Leitung – Umsetzung

**1. Wasser, Ufer, Kaimauern, Böschungen, Fernwasser, Fernufer sind R5s.** Arcade (`RoadRenderer._draw_water`) malt die
Zeilen der Uferböschung in der Kaifarbe bzw. der Uferfarbe der Brücke; Modern malte sie als Wasser. Jetzt baut
`bridge.gd` auf genau diesen Zeilen die Ufer nach Arcades Regel (`Track._build_bridge`: Böschung = ein Segment bei
niedrigen Brücken ohne Uferfarbe → Kaimauer; sonst Böschung), das Wasser liegt 0,15 m darüber bis zum Bandende, und
`far_ground.gd` setzt den Fluss jenseits der Bänder fort (Fernwasser bis 3 km, bei tiefem Wasser Fernland auf der alten
Höhe der Scheibe, Fernufer) – als eigene Geometrie mit dem Wassermaterial von `bridge.gd`, `far_ground.gdshader` (R4)
unverändert. Die ZS1-Regel bleibt (Scheibe höchstens tiefstes Wasser − 0,3 m; `test_far_ground_water` 4/4 grün,
`check_terrain_cover` K1 Abschnitt 6). **Köhlbrand-Ende**: statt „Wasser, das ins Grün übergeht“ graue
Natursteinböschung in Arcades Kaifarbe (Bilder `kb_ende`). **Holtenau**: grüne Böschungen mit Steinschüttung, dahinter
Land – der Kanal liest sich als Kanal wie in Arcade, nicht mehr als See (Bilder `holtenau`).

**2. Köhlbrandbrücke als Schaustück.** Die Platzierung der Brückenteile liegt jetzt in `bridge.gd`; `props.gd` blieb
**unverändert** – sein Überspringen gab es schon seit R2 (`props.gd` Zeile 78 `var _skip_bridge`, Zeile 111
`_skip_bridge = renderer.call(&"builder", "bridge") != null`, Zeile 526 Weitergabe an den Worker, Zeile 719–720
`if it.has("bridge") and bool(inp.get("skip_bridge", false)): return ""`); es greift für alle Teile mit
`bridge`-Schlüssel (Pylone, Fachwerkportale, Brückenlampen), sobald `builders/bridge.gd` existiert. Pylon =
`props/bridge_pylon_bare`, Höhe `height_m`/88,8 (95 m), dazu Arcades Kopfblock (1,6 m); Seile von R5 nach Arcades Gesetz
(7 je Richtung, Spannweite `cables` 62,6 m, 0,07 m), keines über einer Spur (Unit-Test: ≥ 1,5 m jenseits der Spuren an
drei Schrägseilbrücken). Nachts dunkel wie M2ZS1 (Materialkopie mit `emit_energy` 0, `night_albedo` 0,45 –
unverändert übernommen; Nachtreihe Abschnitt 4: an allen fünf Stellen unter Arcade). Rote Flugbefeuerung bei
`height_m` + 1,6 m = 96,6 m (wo Arcade sie hat) im Takt von Arcade (`PYLON_BLINK` 1,6 s / 0,8 s / Seite × 0,4 s, gelesen
von `blink_lit()` der Flare-Ebene); Bild mit Pylonspitze und Feuer: `kb_flugfeuer_22uhr.jpg` (Render-Prüfung, HUD aus, Spitzen vergrößert –
mit HUD liegt die Spitze ab km 73 hinter Tipp-Leiste und Fortschrittsbalken, wie schon bei M2ZS1). Jeder Brückentyp
des Netzes baut headless ohne Fehler: Netzlauf `check_tunnel_bridge.gd -- --full` (Abschnitt 6) und je Typ ein
Unit-Test; Bilder an B1 (Severinsbrücke, Schrägseil) und Holtenau (Balken), Elbbrücken (Fachwerk), Ludwigsbrücke
Würzburg (Stein), Ponte della Libertà (Damm), Herengracht (Kanal). Pylonbeine bei Tag: Abschnitt 4.

**3. Tunnel U1 und Somport.** Kein Himmel innen (Render-Prüfung U1_innen: 0,000 % Leinwand im ganzen Bild); Leuchten an
(Leuchtenpunkte über der Horizontzeile; von außen bei Tag Arcades Lichthof); Ausfahrt weder schwarz noch ausgebrannt
(Render-Prüfung U1_ausfahrt; Arcade überbelichtet das Draußen – Sache der Umgebung, Hinweis an R4); Autos innen nach
dem Tunnel-Ausblendgesetz (Ebene `vehicles`: `VehiclePose3D.fade(…, in_tunnel, 260)`, Unit-Test `test_fade_law`
„Tunnel“ grün); Kappe bei `peek_m` nur von außen (Unit-Test, Bilder `u1_anfahrt`); Portalrahmen und Hügel schließen das
Gelände (Render-Prüfung U1/Somport-Portal: 0,000 % Leinwand unter der Horizontzeile, Grenze 0,2 %); Nischen, Gehwege,
Wandschilder (Bilder `u1_innen`, `somport`). Kurze Altstadttunnel (Valík 40 m, Radejčín 60 m): flacher Hügel, keine
Kappe (Unit-Test); Galerien gibt es in den Daten nicht.

**4. `set_zone` duck-typed, `tunnel01` bleibt.** `tunnel.gd` ruft `env.set_zone("tunnel", amount)` nur, wenn das Rig die
Methode hat, und nur bei Änderung; ohne sie bleibt der Weg des Rigs (`tunnel_blend`) unverändert (Unit-Test). Aufrufe
dokumentiert in `docs/renderer-modern.md` §15.1; `environment_rig.gd` nicht angefasst.

**5. Fairness F1/F7.** Nichts der Röhre über den Spuren unter 5,2 m, nichts über dem Bankett unter 4 m; kein Tragwerk über
der Fahrbahn; Seile ≥ 1,5 m jenseits der Spuren (Unit-Tests). Der Hügel schneidet nie durch die Röhre (Unit-Test).
Fachwerkportale stehen wie in Arcade über der Fahrbahn (Arcades Lichtraum). `modern_sight --full` und
`modern_path_check --full` Abschnitt 6.
