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
