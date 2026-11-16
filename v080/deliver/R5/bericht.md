# R5 – Tunnel und Brücken, Wasser und Ufer (Bericht)

Paket **R5** der Welle 3 von M2 (Modus „Modern“, v0.8.0): Tunnel und Brücken – nach Entscheidung der Leitung auch
Wasser, Ufer, Kaimauern, Böschungen, Fernwasser und Fernufer. Branch `worktree-wf_fd1de4ee-28b-2`, Worktree
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-2`, Basis `6e48405`
(`origin/wip/v080-m2int`, per `git merge --ff-only`); jeder Commit gepusht nach `origin/wip/v080-r5` (Sicherung, nie
force). Der Lauf wurde viermal unterbrochen (Container-Neustarts, Nutzungsgrenze); jeder Nachfolger hat nach `STAND.md` im selben
Worktree weitergemacht (keine Arbeit verloren, nichts doppelt). „gemessen“ = auf dieser VM (Mesa llvmpipe unter Xvfb
bzw. headless, 4 geteilte Kerne, Last 10–27 durch die Nachbarpakete); alles über Steam Deck und echte Grafikkarten ist
**abgeleitet**. Schwere Läufe einer nach dem anderen, mit `nice -n 19`, ab dem Erscheinen von `QA_M2_FERTIG` (15.11. gegen 13 Uhr)
mit `nice -n 10`.

**Kurz:** Tunnel mit Arcades Gehwegen, Fliesenpaneelen, Nischen, Notausgängen, Lüftern, Portalrahmen und Arcades Hügel;
Brücken mit eigenem Builder (Wasser, Ufer nach Arcades Regel, Tragwerk je Typ, Pylone der Köhlbrandbrücke mit Seilen
und blinkender Flugbefeuerung, Fachwerkträger und -portale, Steinbögen, Brückenlampen); Fernwasser, Fernland und
Fernufer jenseits der Bänder. Holtenau liest sich wieder als Kanal, das Köhlbrand-Ende als Kai; die Elbbrücken haben
Arcades Fachwerkträger. Keine Datei außerhalb des R5-Eigentums geändert (auch `props.gd` nicht – sein `skip_bridge`
gab es schon) außer der Zeile `modern_s4_mittel` in `tests/golden/modern_slice.md5` (gewollte Bildänderung, angesehen). Arcade bitgleich (20/20, 17/17); die Gates sind grün bis auf Ausfälle unter Last (Waldprüfung, drei
Echtzeit-Klangprüfungen), die einzeln grün nachgeprüft sind (Abschnitt 6). Schwächen, die an fremden Dateien hängen
(Abblendlicht, Fahrbahn im Tunnel, Ausfahrt, Steinbrüstung), stehen offen in Abschnitt 3 und 8.

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

## 1. Was gebaut wurde (Commits `173a412` … Endstand, alle auf `origin/wip/v080-r5`)

| Datei | Inhalt |
|---|---|
| `scripts/race3d/builders/bridge.gd` (neu, Builder `bridge`) | **Wasser** 0,15 m über den Wasserzeilen des Geländebands bis zum letzten Ring (Materialklasse `water`); **Ufer** nach Arcades Regel (Kaimauer aus Naturstein bzw. Klinker an Grachten mit Abdeckung und Pflaster, wo die Böschung ein Segment ist; sonst Böschung auf den Böschungszeilen – Gras in der Uferfarbe mit Steinschüttung, Naturstein in der Kaifarbe); **Tragwerk** je Typ (Randbalken, Untersicht, Pfeiler mit Vorköpfen, Steinbögen mit Stirnmauern und Gesims, Arcades Fachwerkträger, Fundament und Querträger unter Pylonen); **Pylone** `props/bridge_pylon_bare` auf `height_m`/88,8 mit Kopfblock, **Seile** nach Arcades Gesetz (7 je Richtung, 0,07 m, nie über einer Spur), nachts dunkel, **Flugbefeuerung** bei `height_m` + 1,6 m im Takt von Arcade; **Fachwerkportale** und **Brückenlampen** als Modelle mit Lichtkegeln (`renderer.add_lamps()`) |
| `assets/shaders/modern/water.gdshader` (neu) | Wasser: analytische Wellen, Arcades Spiegelanteil (0,16 + dz/600, höchstens 0,7), gespiegelter Himmel aus der Palette, Sonnenglitzern (nachts aus), Lichtkegel, Abblendlicht, Arcades Bodennebel; Ufer: Naturstein, Klinker, Gras mit Steinschüttung, Pflaster |
| `scripts/race3d/builders/tunnel.gd` (ausgebaut) | Röhre mit Arcades Notgehweg (0,9 × 0,25 m), Fliesenpaneelen, Kabeltrassen, Leuchten mit Gehäuse, SOS-Nischen alle 150 m, Notausgängen alle 300 m, Strahlventilatoren (Unterkante ≥ 5,2 m); Kappe bei `peek_m` nur von außen; Portal mit Rahmen, Laibung, Stirnwand, Gesims, Flügelmauern; Arcades Hügel (gleiche gesäte Folge, Nadelbäume, nie durch die Röhre); Rahmen der Ausfahrt; Tunnelzone (`tunnel_state`, `set_zone` duck-typed) |
| `assets/shaders/modern/tunnel.gdshader` (ausgebaut) | Arcades Tunnellicht und -nebel, Paneele mit Fugen und Schmutz, Ringfugen, Ruß, Lampenschein, SOS-Schild, grüne Notausgangsschilder, Arcades Lichthof um die Leuchten von außen bei Tag |
| `scripts/race3d/layers/far_ground.gd` (übernommen, Entscheidung 1) | je Brücke im Fenster Fernwasser bis 3 km, bei tiefem Wasser Fernland auf der alten Scheibenhöhe und Fernufer – eigene Geometrie mit dem Wassermaterial; die Scheibe bleibt bei der ZS1-Regel; Arcades Kaifarben als gepinnte Kopie `ARCADE_QUAY` (Nachfolger 4: ein fester Verweis auf `RoadRenderer` brach `check_terrain_plan`) |
| `tests/unit/race3d/test_bridge.gd` (10 Tests), `test_tunnel.gd` (8 Tests) | Abschnitt 5 |
| `tests/race3d/render/check_tunnel_bridge.gd` | 6 Render-Stellen (U1 Portal/innen/Ausfahrt, Somport, B1, Flugbefeuerung) und der Netzlauf `-- --full` (jede Brücke, jeder Tunnel des Netzes, headless) |
| `tests/golden/modern_slice.md5` | Zeile `modern_s4_mittel` (Köhlbrand-Ende, gewollt, angesehen) |
| `docs/renderer-modern-tunnel-bruecken.md` (neu), `docs/renderer-modern.md` §15 | Doku, `set_zone`-Aufrufe (§15.1), Prüfungen (Abschnitt 7) |

**Nicht geändert:** `builders/props.gd` (sein `skip_bridge` besteht seit R2: Zeilen 78, 108–111, 526, 719–720),
`environment_rig.gd`, `far_ground.gdshader`, alle Arcade-Dateien, alle Dateien von R4/R6.

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

## 3. Bilder – angesehen, ehrlich gegen Arcade (und gegen die Basis)

Ordner `bilder/`. Dreier **Arcade | Modern Basis (6e48405) | Modern R5** desselben Simulationszustands, wo die Basis
gerendert wurde, sonst Paare **Arcade | Modern R5** aus demselben `tools/ab_shot.sh`-Lauf. 1280 × 720, Stufe „Hoch“
(Steam Deck: 1280 × 800, Stufe „deck“; Arcade dort mit Balken). Arcade ist eingefroren und bitgleich, darum stammen die
Arcade-Bilder der Dreier aus dem Lauf der Basis. Alle R5-Bilder zeigen den Code-Endstand (Bilder vor einem späteren
Commit, der sie ändert, wurden neu gerendert: B1, Somport, U1-Ausfahrt, Köhlbrand nachts – Ordner `shots/new4`).
`pruefung_*.jpg` sind Bilder der Render-Prüfung (HUD aus).

| Ort | Bild | Urteil R5 gegen Arcade | gegen die Basis |
|---|---|---|---|
| U1 Gotthard Anfahrt, 12 Uhr | `u1_anfahrt_00/01` | Hügel wie Arcade (dieselbe gesäte Folge, Verlauf, Nadelbäume an denselben Stellen), Portal mit Rahmen und Fasen, Leuchten mit Arcades Lichthof von außen, Fliesenpaneele schon am Eingang – **besser** | besser (Basis: kein Lichthof, glatter Hügel ohne Bäume) |
| U1 innen | `u1_innen_01` | Fliesenpaneele mit Fugen, Gehwege, Kabeltrassen, Leuchtengehäuse, Nischen/Türen; Licht und Nebel wie Arcade, kein Himmel – **deutlich besser** | deutlich besser (Basis: glatte Wände) |
| U1 Ausfahrt | `u1_ausfahrt_01/02` | Rahmen der Ausfahrt, Notausgang; draußen **nicht überbelichtet** wie in Arcade – die Öffnung ist sogar dunkler als die beleuchtete Röhre (Umgebung, R4: Belichtungsrampe) – **gleich**, nicht besser | gleich bis besser |
| U1 22 Uhr | `u1_nacht_00/01` | nah am Portal stimmig (Röhre, Leuchten, Stirnwand dunkel wie Arcade); 60–70 m davor ist die Stirnwand vom Abblendlicht bis oben angestrahlt und liest sich wie bei Tag (R4: keine Abblendkante, gemessen Abschnitt 8); die Fahrbahn in der Röhre ist von außen kalt grau statt Arcades warmem Tunnellicht (R4) – **schlechter** als Arcade auf Bild 00, gleich auf Bild 01 | – |
| Somport | `somport_00–02` | Leuchten mit Lichthof, SOS-Nische, Notausgang mit grünem Schild, Fliesen – **besser** | besser |
| Köhlbrandbrücke Rampe/Deck | `kb_rampe_00/01` | Wasser in Arcades Farbe mit Wellen, Seile dünn wie Arcades Linien, graue Pylone (Sonnenseite etwas heller), fernes Kaiufer aus Naturstein – **besser** | deutlich besser (Basis: weiß-graues Wasser, dicke weiße Seile) |
| Köhlbrandbrücke Ende | `kb_ende_00/01` | graue Natursteinböschung in Arcades Kaifarbe statt „Wasser ins Grün“ – **gleich bis besser** | deutlich besser |
| Köhlbrandbrücke 22 Uhr | `kb_nacht_00–02`, `pruefung_beacon` | Pylone dunkel (Messreihe unter Arcade), Seile, Feuer rot und blinkend, Wasser ruhig – **gleich bis besser** | gleich bis besser |
| Holtenauer Hochbrücke | `holtenau_00/01` | Kanal zwischen grünen Böschungen mit Steinschüttung, Land dahinter, vor der Brücke kein Wasserband am Horizont – wie Arcade, mit Ufertextur – **gleich bis besser** | deutlich besser (Basis: See bis zum Horizont) |
| B1 Severinsbrücke Köln | `b1_koeln_00/01` | Rhein mit Kaimauern, fernes Ufer, Pylon grau, Seile dünn – **gleich bis besser** | besser |
| Elbbrücken (Fachwerk) | `elbbruecken_00/01` | Fachwerkträger an beiden Seiten wie Arcade (Gurte, Pfosten, Diagonalen) zu den Bogenportalen, im Licht schattiert – **besser** | deutlich besser (Basis: nur Portale) |
| Ludwigsbrücke Würzburg (Stein) | `stein_00/01` | Lampen, Wasser, aber geschlossene Brüstung statt Arcades heller Docken (roadside.gd, R4) – **gleich**, an der Brüstung schlechter | gleich |
| Ponte della Libertà (Damm) | `damm_00/01` | Wasser in Arcades Türkis mit Wellen, Brückenlampen als Modelle wie Arcades, Gehweg gepflastert – **gleich bis besser** | – |
| Herengracht Amsterdam (Kanal) | `gracht_00/01` | Gracht mit Hausbooten, Eisengeländer, Wasser etwas blauer als Arcade – **gleich** | – |
| DEV km 48, 21 Uhr | `dev_00–02` | Hügel, Portal, Röhre wie Arcade; Stirnwand nah vom Abblendlicht hell (R4) – **gleich** | gleich |
| Steam Deck (1280 × 800, „deck“) | `kb_nacht_deck_*`, `u1_innen_deck_01`, `kb_rampe_deck_01` | dieselben Bauten, Seile und Fliesen auch in „deck“ sichtbar – **gleich bis besser** | – |

**Clips** (`tools/ab_clip.sh`, 60 fps fest, 30 s, Arcade links, Modern rechts, Stufe „Hoch“): `clips/u1_gotthard.mp4`
(Bern – Mailand ab km 184,4: Portal, Röhre bis km 198 – Gehwege, Paneele, Leuchtenreihen, Lüfter, Gegenverkehr)
und `clips/koehlbrand.mp4` (Kiel – Hamburg ab km 77,2: Rampe, Deck mit Pylonen, Seilen und Wasser über Steinböschung
– die Brücke ist bei 150 km/h nach 10 s überquert –, Ende mit Kaiböschung, Anfahrt der Elbbrücken; der Modern-Lauf
brauchte 2923 s und lief beim ersten Versuch ins Zeitlimit von 3600 s, zweiter Versuch mit `CLIP_TIMEOUT=6000`).
Angesehen: Bilder aus beiden Clips (2 s, 5 s, 7 s, 10 s, 20 s, 28 s) – keine Sprünge, kein Flackern der Wände, das
Portal und die Brücke kommen an derselben Stelle wie in Arcade.

**Gesamturteil:** Wo R5 selbst baut, ist Modern **deutlich besser als die Basis und besser als Arcade**: Tunnelröhren
(Paneele, Gehwege, Nischen, Türen, Lüfter, Leuchten mit Lichthof), Portale mit Hügel, Wasser mit Wellen und Spiegel in
Arcades Farbe, Ufer und Kaimauern nach Arcades Regel, Fachwerkträger, dünne Seile, blinkende Flugbefeuerung, Fernwasser
mit Ufer statt Wasserband bis zum Horizont. **Nicht besser** ist es dort, wo das Bild von fremden Teilen abhängt:
Abblendlicht ohne Hell-Dunkel-Grenze (Gotthard-Stirnwand 22 Uhr aus 60–70 m wie bei Tag – schlechter als Arcade),
Fahrbahn in der Röhre von außen kalt grau statt Arcades warmem Tunnellicht, keine Überbelichtung an der Ausfahrt (die
Öffnung ist dunkler als die Röhre), geschlossene Brüstung statt Arcades Docken an Steinbrücken (alle R4, Abschnitt 8).

## 4. Messungen (gemessen, 1280 × 720, Stufe „Hoch“, Mittelwerte 0–255)

**Wasser bei Tag** (Köhlbrandbrücke km 78,4, Bild `kb_rampe_01`; Spalte x 1180–1240):

| Zeile | Arcade | Basis | R5 |
|---|---|---|---|
| Fernes Ufer (y 345) | 137,136,131 | – | 138,137,132 |
| Wasser mittel (y 430) | 108,135,151 | – | 109,134,154 |
| Wasser nah (y 460) | 105,131,147 | – | 94,118,140 |
| Bereich 200×80 bei (1050,400) | 107,134,150 | 170,182,190 | 116,145,166 |

Die Basis zeigte das Wasser fast weiß-grau, R5 liegt bei Arcade (Spiegelanteil nach Arcades Zeilengesetz: 0,16 + dz/600,
höchstens 0,7, dz = Tiefe in Blickrichtung).

**Holtenau** (Bild 01): fernes grünes Ufer Arcade 70,93,54 / R5 79,104,61; Wasser nah Arcade 105,131,146 / R5
108,142,172.

**Pylon bei Tag** (km 78,4, Säulenausschnitte 30×80): Arcade 169 / 153 (links Sonne/Schatten), 151 (rechts); Basis
189 / 136 / 198; R5 184 / 136 / 187. Sonnenseite des Modells rund 12 % heller als Arcades flach schattierte Säule,
Schattenseite rund 11 % dunkler, im Mittel gleich – die Beine „lesen sich hell“ wegen des Lichts, nicht der Farbe;
gelassen (Modell und Material sind nicht R5s; Hinweis Abschnitt 8).

**Pylonbereich nachts – Messreihe von M2ZS1 hält** (22 Uhr, ab km 77,6 mit 80 km/h und Verkehr, x 500–780 × y 150–350,
Leuchtdichte Rec. 709; `m1/R5/tools/rowmeasure.py`, Bilder `m1/R5/shots/row`, Endstand des Codes):

| Bild | Arcade | M2ZS1 (Basis) | **R5** |
|---|---|---|---|
| 00 (km 77,7) | 76,5 | 70,7 | **73,1** |
| 01 (km 78,1) | 60,1 | 55,9 | **55,9** |
| 02 (km 78,8) | 48,1 | 43,0 | **46,2** |
| 03 | 54,3 | – | **53,1** |
| 04 (km 79,7) | 51,6 | 51,7 | **49,4** |

An allen Stellen unter Arcade; bei km 77,7 und 78,8 etwas heller als M2ZS1 (R5s helle Seile nach Arcades Farbe
`ecebe6` liegen im Messfeld), bei km 78,1 gleich.

**Tunnel** (Render-Prüfung, Abschnitt 6): U1 innen Leuchtdichte 0,322, 612 Leuchtenpunkte, 0,000 % Himmel; Ausfahrt
0,226 (Röhre daneben 0,449), 0,0 % reines Weiß. **U1 22 Uhr** (Bilder `u1_nacht`): Stirnwand 60–70 m vor dem Portal
links unten 89,79,67 gegen Arcade 61,57,56, Gesims 72,72,74 gegen 37,45,60 (Abblendlicht ohne Kante, R4); nah am
Portal 48,54,65 gegen 38,46,62. Fahrbahn in der Röhre von außen: Tag 47,49,57 gegen Arcade 42,33,24, 22 Uhr
94,94,99 gegen 148,126,102 (R4).

## 5. Tests

**Neu** (`tests/unit/race3d/`, laufen in `tools/run_tests.sh` mit):

| Datei | Test | prüft |
|---|---|---|
| `test_bridge.gd` (10) | `test_water_lies_on_the_water_rows_out_to_the_ribbon` | Wasser 0,15 m über den Wasserzeilen bis zum letzten Ring des Bands |
| | `test_banks_follow_arcades_rule` | Kaimauer bei einsegmentiger Böschung ohne Uferfarbe, sonst Böschung; Gras/Stein nach Uferfarbe |
| | `test_far_quay_wall_faces_the_camera_and_reaches_into_the_water` | ferne Kaimauer zeigt zur Kamera, reicht 0,6 m unter das Wasser |
| | `test_koehlbrand_pylons_beacons_and_cables` | 4 Pylone, Höhe `height_m`/88,8, Flugbefeuerung bei `height_m` + 1,6 m, 7 Seile je Richtung |
| | `test_no_cable_reaches_over_a_lane` | kein Seil über einer Spur (≥ 1,5 m jenseits, drei Schrägseilbrücken) |
| | `test_structure_keeps_out_of_the_lanes` | kein Eckpunkt des Tragwerks über den Spuren und dem ersten Meter des Banketts (nur neben und unter dem Deck) |
| | `test_props_builder_leaves_the_bridge_parts_to_this_builder` | `props.gd` lässt die `bridge`-Teile liegen, sobald der Builder existiert |
| | `test_dark_pylon_material_at_night` | Pylon nachts: `emit_energy` 0, `night_albedo` 0,45 (M2ZS1) |
| | `test_every_bridge_type_builds` | jeder Typ (cable_stayed, truss_arch, river, canal, stone_arch, causeway) baut ohne Fehler |
| | `test_far_ground_quay_copy_equals_arcade` (Nachfolger 4) | `far_ground.gd`s Kopie `ARCADE_QUAY` = `RoadRenderer.QUAY` |
| `test_tunnel.gd` (8) | `test_tube_niches_doors_fans_cap_portal_exit` | Röhre, Nischen alle 150 m, Türen alle 300 m, Lüfter, Kappe, Portal, Ausfahrtsrahmen |
| | `test_nothing_of_the_tube_over_the_road` | nichts über den Spuren unter 5,2 m, über dem Bankett unter 4 m (F1) |
| | `test_hill_closes_the_terrain_at_the_portal` | Hügel schließt das Gelände am Portal |
| | `test_hill_never_cuts_through_the_tube` | Hang des Hügels nie durch die Röhre |
| | `test_short_tunnel_low_hill_no_cap` | kurzer Altstadttunnel (Valík 40 m): flacher Hügel, keine Kappe |
| | `test_cap_only_for_a_camera_outside` | Kappe bei `peek_m` nur von außen |
| | `test_zone_follows_the_rigs_law` | `zone_amount` = Gesetz von `EnvironmentRig.tunnel_blend()` |
| | `test_set_zone_only_when_the_rig_has_it` | `set_zone` nur duck-typed und nur bei Änderung; ohne die Methode bleibt `tunnel01` |

**Render-Prüfung** `tests/race3d/render/check_tunnel_bridge.gd` (läuft in `tools/run_render_checks.sh modern`):
U1_portal, U1_innen, U1_ausfahrt, Somport_portal, B1, beacon (Kopf der Datei: Grenzen und Messweise).

**Bestehende Wächter der ZS1-Korrekturen** (müssen halten): `test_far_ground_water` (4/4), `test_props` (12/12),
`test_terrain_builder` (Fernboden unter dem Wasser), Render-Prüfungen `check_start_km0`, `check_terrain_cover` inkl. K1,
`check_light_base` (Abschnitt 6).

Unit-Tests `race3d` vor dem letzten Code-Commit: 137 Tests, 0 fehlgeschlagen (106 s); auf dem Endstand im vollen Lauf: Abschnitt 6. In einem
früheren Lauf (vor dem Neustart) schlug `test_props :: test_library_resolves_every_prop_set` einmal fehl
(„fallback_sets 78“ – die Modellbibliothek war beim Test noch nicht fertig geladen), allein und in allen späteren Läufen
grün; R5 ändert weder `props.gd` noch `prop_library.gd` – ein Zeitproblem des Tests unter Last, gemeldet unter
Für die Nächsten.

## 6. Gates auf dem Endstand (gemessen; nice 19, ab 13:20 nice 10 – `QA_M2_FERTIG`; Last 18–30 durch die Nachbarpakete)

Skript `m1/R5/tools/gates.sh` (je Gate ein Log in `m1/R5/gates/`, eigenes leeres `XDG_DATA_HOME`).

| Gate | Befehl | Ergebnis |
|---|---|---|
| Import | `godot --headless --path . --import` | sauber, Exit 0 (13 s) |
| Skripte | `godot --headless --path . -s res://tests/check_scripts.gd` | „314 Skripte geprüft, 0 fehlerhaft“ |
| Tests (voll, Lauf 1 auf `ef88c1a`) | `tools/run_tests.sh` | 766 Unit-Tests 0 fehlgeschlagen, alle Szenarien und Prüfungen OK **außer** `tests/race3d/check_terrain_plan.gd`: „Identifier not found: SpriteDB“ – R5s `far_ground.gd` verwies fest auf `RoadRenderer.QUAY`; behoben in `2919660` (Kopie `ARCADE_QUAY` + Pin-Test), danach `check_terrain_plan` allein 3/3 OK, `test_bridge` 10/10 |
| Tests (voll, Lauf 2 auf dem Endstand) | `tools/run_tests.sh` | 767 Unit-Tests, **3 fehlgeschlagen** – alle drei Echtzeit-Klangprüfungen unter Last (Last 15–20): `test_engine3_checks` (531 statt 330 Aussetzer im Hauptthread-Mischen), `test_modern_checks` „race“ (Sitzung nur in 74 von 89 Bildern – zu wenige, zu lange Bilder), `test_music_checks` „race“ (Bild im Einzähler bis 484 ms). Keine berührt eine R5-Datei, und R5s Code war in Lauf 1 derselbe (dort grün). Einzeln nachgeprüft (`tools/run_tests.sh <filter>`): `test_engine3_checks` 2/2, `test_modern_checks` 3/3 und `test_music_checks` 2/2 auf R5 grün; `test_modern_checks` fiel zur gleichen Zeit **auch auf der Basis** 6e48405 (Variante „ohne Wiedergabe“). Alle übrigen Prüfungen und Szenarien OK, `check_terrain_plan` 3/3. Ein dritter voller Lauf ist nach der Regel (höchstens zwei) nicht gemacht. |
| Arcade bitgleich | `tools/golden.sh check` | **„GOLDEN arcade: 20 von 20 identisch“**, **„GOLDEN arcade-ui: 17 von 17 identisch“** |
| Modern-Änderungsmelder | `KEEP=… tools/golden.sh modern-check` | 5 von 6 identisch, `modern_s4_mittel` (km 80,6, Köhlbrand-Ende) gewollt anders – angesehen gegen dasselbe Bild der Basis (2350 von 921 600 Bildpunkten > 8: R5s Natursteinböschung rechts hinter dem Tacho, Fernwasser am Horizont), Liste in `5558bdc` nachgezogen (die MD5 des Bildes dieses Laufs, genau was `modern-make` schriebe); OpenGL ES gegen OpenGL OK (2/255, PSNR 73,2 dB) |
| Render-Prüfungen | `tools/run_render_checks.sh all` | 2/2 Arcade, Modern alle Dateien OK – `check_start_km0`, `check_terrain_cover` (T1–T4, S1, C1, **K1** km 78,1: 0,000 % Magenta, 0,00 % Fernboden), `check_light_base`, `check_tunnel_bridge` (U1_portal 0,000 %, U1_innen 0,000 % / 612 Leuchtenpunkte / 0,322, U1_ausfahrt 0,226 / 0,0 % Weiß, Somport_portal 0,000 %, B1 0,000 % / 0,00 % Fernboden / 630 Wasserflächen, beacon 4 Feuer, 4 blinken, 216 rote Bildpunkte) – **außer** `check_instance_budget_wald` Exit 124 nach 900 s (bekannter Basisbefund M2S-01 aus QA-M2-SYSTEM: braucht unter Last 8–49 min; liegt bei km 46,5 Kassel – Würzburg, keine Brücke, kein Tunnel im Fenster); allein mit `RENDER_CHECK_TIMEOUT=3600`: **OK** nach 2188 s (Fahrzeug-Ebene ≤ 127 Instanzen, ganze Szene ≤ 140 von 230) |
| Sicht | `godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full` | alle OK: F1 0 Fälle bis 270 m in 99 424 500 Stichproben (128 Etappenrichtungen), F1 Außenspuren 0 bis 260 m, F2 ≤ 0,593/0,596/0,555, F3 0 von 5923 Zielen später als Arcade, F7 0 von 2 011 532 Querschnittsseiten, Modell 0 abweichend (205 s) |
| Weg | `godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full` | OK: kleinster Abstand 267,6 m (≥ 250 m verlangt), Schleifen frühestens nach 2064 m Weg (≥ 2000 m) (87 s) |
| Netzlauf R5 | `godot --headless --path . -s res://tests/race3d/render/check_tunnel_bridge.gd -- --full` | 122 Brücken (cable_stayed 12, canal 10, causeway 2, river 60, stone_arch 35, truss_arch 3), 26 Tunnel, 0 Mängel, 90 s |

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

## 8. Für die Nächsten (fremde Dateien: genaue Änderung; dazu R5s eigene Reste)

R5 hat außerhalb seines Eigentums nur die Golden-Zeile `modern_s4_mittel` geändert. Was in fremden Dateien besser würde:

1. **R4 `builders/props.gd`, Schiffe auf das Wasser** (Vertrag A-Nachtrag „R5 sets them on the water surface“): Schiffe
   und Hausboote stehen bei `h = float(it["h"])` (Zeile 599, `h` = −Tiefe = Höhe der Wasserzeilen des Geländes); das
   Wasser von R5 liegt `WATER_LIFT` (`bridge.gd`) = 0,15 m darüber. Änderung: Zeile 599
   `h = float(it["h"]) + (0.15 if bool(inp.get("skip_bridge", false)) else 0.0)` (nur wenn der Brücken-Builder da
   ist). Bis dahin liegt die Wasserlinie 0,15 m zu tief (im Bild kaum zu sehen).
2. **R4 `builders/roadside.gd` `_railing`, Steinbrücken**: Arcade zeigt an Steinbrücken eine Balustrade aus hellen
   Docken (Ludwigsbrücke Würzburg, Bild `stein_01`), Modern eine geschlossene Brüstung. Änderung: für `"stone_arch"`
   das mittlere Band `[0.24, 0.92]` durch Docken ersetzen (alle 0,35 m, 0,14 × 0,14 m, oben/unten 0,03 m breiter),
   Sockel und Handlauf bleiben. Erst dann ist die Steinbrücke besser als Arcade, heute nur gleich.
3. **R4 `layers/flares.gd`, Tunnelleuchten bei Tag von außen**: Arcade zeigt die Leuchten der Röhre mit Lichthof auch
   von außen bei Tag; die Flare-Ebene schaltet die Rolle `tunnel` nur nachts bzw. mit der Kamera im Tunnel an. R5
   malt den Lichthof deshalb selbst im `tunnel.gdshader` (Zeile 226, `halo_k` = 1 − `lights`). Änderung: in
   `_add_statics` `var on := 1.0 if role == "on" or role == "tunnel" else (…)`; danach in `tunnel.gdshader` Zeile 226
   `halo_k = 0.0` (sonst doppelt).
4. **R4 `environment_rig.gd`, Ausfahrt**: Arcade überbelichtet das Draußen aus dem Tunnel (`RoadRenderer`:
   `amb_out = min(2, amb × 1,7 + 0,25)`, Nebel nach Weiß 0,55); Modern zeigt es normal belichtet (Ausfahrt 0,226
   Leuchtdichte gegen Röhre 0,449, gemessen). Quelle ohne eigene Rechnung: `renderer.builder("tunnel").tunnel_state`
   (`exit_m`, `exit_in_sight`) oder `set_zone("tunnel", amount)` (Abschnitt 15.1 der Doku).
5. **R4 `builders/terrain.gd`, Wasserzeilen**: die Wasserzeilen des Geländebands liegen 0,15 m unter dem Wasser von R5
   und werden nur verdeckt (rund 768 Dreiecke je Brückenstück). Änderung: Wasser-Quads auslassen, wenn
   `renderer.builder("bridge") != null`.
6. **R4 `layers/lights.gd`, Abblendlicht ohne Hell-Dunkel-Grenze**: der Spot hat 30° halben Öffnungswinkel in alle
   Richtungen (`SPOT_ANGLE_DEG`), also keine Abblendkante: eine senkrechte Fläche 60–70 m voraus wird bis oben
   angestrahlt. Am Gotthard-Portal um 22 Uhr (Bild `u1_nacht_00`) liest sich die Stirnwand dadurch wie bei Tag:
   linke Flügelmauer 89,79,67 gegen Arcade 61,57,56, Gesims 72,72,74 gegen 37,45,60 (gemessen, 0–255); nah am Portal
   (Bild 01) passt es (48,54,65 gegen 38,46,62). Änderung: eine Abblendkante (Projektortextur am Spot oder ein
   zweiter, flacher Kegel) – nicht im Portal ausblenden, das träfe jede Mauer gleich.
7. **R4 `builders/road.gd` / Straßenshader, Fahrbahn im Tunnel von außen**: Arcade beleuchtet die Fahrbahn in der Röhre
   immer mit Tunnellicht (warm), Modern nur, wenn die Kamera im Tunnel ist: von außen ist sie kalt grau (Tag
   47,49,57 gegen Arcade 42,33,24; 22 Uhr 94,94,99 gegen 148,126,102 – gemessen am Gotthard-Portal). Änderung: die
   Tunnel-Segmente (die `road.gd` schon kennt) bekommen dasselbe Licht wie `tunnel.gdshader` (`TUNNEL_FOG`,
   Lampenfarbe, `darkness_m`), unabhängig vom Ort der Kamera.
8. **Modell `props/bridge_pylon_bare` (AS4-Nachfolger)**: Sonnenseite bei Tag rund 12 % heller als Arcades Säule,
   Schattenseite rund 11 % dunkler (Mittel gleich, km 78,4). Ein 10 % dunklerer Atlas mit `night_albedo` 0,5 statt
   0,45 hielte die Nachtreihe gleich.
9. **R5 selbst (nicht mehr geschafft): Spitze im Haken `far_ground`** 69,9 ms gegen 17,7 ms der Basis (einmal je Lauf
   gemessen, Last 20): vermutlich das Bild, in dem `build_river()`/`_build_land()` Fluss und Fernland einer Brücke
   anlegen. Auf echter Hardware messen; wenn bestätigt, `river_reach()` (Schleife über das ganze Pfadfenster) und den
   Aufbau auf zwei Bilder verteilen oder im `prepare()` vorbauen.
10. **R5 selbst, klein**: der Kopfblock der Pylone ist nachts heller als der dunkle Pylon (Strukturmaterial ohne
   `night_albedo`) – im 4-fach-Ausschnitt von `kb_flugfeuer_22uhr.jpg` sichtbar, im Spiel 2 × 2 m in 95 m Höhe.
11. **Doku**: `docs/renderer-modern.md` Abschnitt 15 (R5) kann beim Zusammenführen mit R4/R6 kollidieren – dort neu
   nummerieren.
12. **Test `test_props :: test_library_resolves_every_prop_set`** (R4s Datei) schlug in einem gefilterten Lauf vor dem
   Neustart einmal fehl („fallback_sets zählt die Vertretungen: erwartet 0, ist 78“ – Bibliothek noch nicht fertig
   geladen), allein und in allen späteren Läufen grün: wartet vermutlich unter Last nicht lange genug auf `ModelDB`.

## 9. Vertragsfragen (mit Beleg)

1. **Inventar B / §6 R5 nennt „bridge deck … railings per type“ als R5-Ausgabe** – in Welle 3 zeichnen Deck und Geländer
   `builders/road.gd` und `builders/roadside.gd` (R4, Tabelle §5 Spalte W3 mit A-8). R5 baut so, dass es mit beiden
   arbeitet (Tragwerk hinter `RAIL_BACK_M` 0,32 m der Geländerdicke), ändert sie aber nicht; die fehlende Balustrade
   der Steinbrücken (Bild `stein_01`) steht unter Abschnitt 8.2. Vorschlag: Geländer an Brücken in R5s Eigentum, oder
   §6 R5 streicht sie.
2. **Nachtrag „Boats … R5 sets them on the water surface“** – Schiffe und Hausboote setzt `builders/props.gd` (R4) mit
   `h` = −Tiefe auf die Wasserzeilen des Geländes; R5s Wasser liegt 0,15 m darüber (`WATER_LIFT`, gegen Z-Kampf mit den
   Geländezeilen). R5 kann die Schiffe ohne Zeile in `props.gd` nicht anheben; genaue Änderung Abschnitt 8.1.
3. **Inventar B: „tunnel ambient and fog, exposure ramp at the exit“ als R5-Ausgabe** – nach Entscheidung 4 der Leitung
   bei R4 (`EnvironmentRig.set_zone`). R5 liefert die Zone (`set_zone("tunnel", amount)`, `tunnel_state` mit `exit_m`,
   `exit_in_sight`); die Belichtungsrampe fehlt bis R4 sie baut (Ausfahrt 0,226 gegen Röhre 0,449, gemessen).
4. **Regel für „-s“-Skripte und feste Verweise auf den Arcade-Renderer** – `road.gd`, `roadside.gd`, `tunnel.gd`,
   `bridge.gd`, `lights.gd`, `flares.gd`, `vehicle_pose3d.gd` nennen `RoadRenderer.*` fest; ein „-s“-Skript, das eine
   davon per `preload` lädt, kompiliert nicht („Identifier not found: SpriteDB“, gemessen an `check_terrain_plan` mit
   R5s `far_ground.gd`, behoben). Der Vertrag sagt es nur für die Skripte selbst (§2), nicht für die Dateien, die sie
   vorladen; ein Satz in §4 (Konstanten Arcades als gepinnte Kopie, wie `GroundLook.GROUND_BLEND_M`) würde es klären.

## 10. Wo was liegt

- **Branch/Worktree:** `worktree-wf_fd1de4ee-28b-2` in
  `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-2`, Sicherung
  `origin/wip/v080-r5` (Endstand `5558bdc`). Commits: `173a412`, `937d3b2`, `452d96b`, `51774de`, `649be5d`, `8456140`
  (Vorgänger), `cb08179`, `ef88c1a`, `2919660`, `5558bdc` (Nachfolger 4).
- **Bilder:** `deliver/R5/bilder/` (Dreier/Paare, Render-Prüfungsbilder), **Clips:** `deliver/R5/clips/`.
- **Arbeitsordner:** `m1/R5/` – `tools/` (ab.sh, mo.sh, batch2–6.sh, gates.sh, perf.sh, counters.sh, rowmeasure.py,
  deliver2.sh), `gates/*.log` (Gate-Protokolle), `perf/` (Etappenläufe, Zähler), `shots/` (Rohbilder: `base`,
  `new2`, `new3`, `new4`, `row`), `check5/` (Render-Prüfung mit Bildern), `full_scan.log` (Netzlauf), `STAND.md`.
- Die Basiskopie (`m1/R5/base`, 577 MB) ist gelöscht; Rohbilder bleiben für die Nacharbeit.
