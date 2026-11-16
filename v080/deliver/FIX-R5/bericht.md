# FIX-R5 – Nacharbeit nach der unabhängigen Prüfung von R5 (Tunnel, Brücken, Wasser und Ufer)

Paket **FIX-R5** der Welle 3 von M2 (Modus „Modern“, v0.8.0). Basis: R5s Kopf `5558bdc` (`origin/wip/v080-r5`), per
`git merge --ff-only` in den frischen Worktree `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-6`
(Branch `worktree-wf_fd1de4ee-28b-6`); einen Vorgänger gab es nicht (kein `STAND.md`, kein `wip/v080-fix-r5`). Jeder Commit
gepusht nach `origin/wip/v080-fix-r5` (Sicherung, nie force). Eigentum: dasselbe wie R5 (`builders/{tunnel,bridge}.gd`,
`tunnel/water.gdshader`, `layers/far_ground.gd`, die drei R5-Prüfdateien, Doku). Geändert habe ich nur
`builders/tunnel.gd`, `tests/unit/race3d/{test_tunnel,test_bridge}.gd`, `tests/race3d/render/check_tunnel_bridge.gd`,
`docs/renderer-modern-tunnel-bruecken.md`, `docs/renderer-modern.md` (§15) – keine Arcade-Datei, keine Datei von R4/R6,
kein Golden.

„gemessen“ = auf dieser VM (Mesa llvmpipe unter Xvfb bzw. headless, 4 geteilte Kerne, Last 10–17 durch die
Nachbarpakete); alles über Steam Deck und echte Grafikkarten ist **abgeleitet**. Schwere Läufe einer nach dem anderen
mit `nice -n 10` (`QA_M2_FERTIG` lag vor). Arbeitsdateien: `m1/FIX-R5/` (Skripte `shots.sh`, `queue.sh`, `perf.sh`,
`mutate.py`, `measure.py`, `cmp.py`; Bilder `shots/`, Läufe `perf/`, Gates `gates/`).

**Kurz:** Den einzigen hohen Befund (QR5-01, Tunnelportale nachts wie bei Tag angestrahlt) habe ich bitgleich
nachgestellt und in R5s eigener Datei behoben: das Portal-Mesh liegt jetzt auf der Bodenebene (Renderlayer 2), die das
Abblendlicht und die Lampen-Omnis auslassen – wie Arcade, das sein Portal nie mit den Scheinwerfern beleuchtet. Stirnwand
U1 22 Uhr L 79 → 56 (Arcade 46), DEV 21 Uhr L 107 → 57 (Arcade 47); bei Tag und überall sonst bitgleich mit R5. Die Tests
schützen jetzt jede Regel, die QA-R5 ungeschützt fand (5 von 5 Mutationen von benannten Tests gefangen), und der Netzlauf
vergleicht genau mit Arcade (122 Brücken, 28 Tunnel, 0 Mängel; fängt 5 von 5 eingebauten Teilverlusten). Für die
Befunde in R4s Dateien liefert R5 jetzt die Daten (`tunnel_state.light`, `tunnel_state.exit_z`); eine Probe mit R4s
Stand zeigt: R4s Belichtungsrampe löst QR5-03, setzt die Fläche aber vor R5s Ausfahrtsrahmen – eine Zeile bei R4 behebt
das (in der Probe gerendert). QR5-09 ist Last, kein Code (headless Commit ≤ 0,25 ms je Tunnelstück). Offen bei R4: Fahrbahn
in der Röhre (QR5-02), Abblendkante, Steinbrüstung (QR5-04), Schiffe (QR5-08). Gates: alle grün auf dem Endstand `80b8141` (gemessen): Import, `check_scripts` 314/0, `run_tests.sh` 769 Tests / 0 Fehler (erster voller Lauf), Arcade 20 von 20 und 17 von 17 identisch, Modern 6 von 6 identisch (+ GLES OK), Render-Prüfungen 20/20 (die Waldprüfung erst allein mit längerem Zeitlimit – bekannter Lastbefund M2S-01), `modern_sight`/`modern_path_check --full` OK, genauer Netzlauf 0 Mängel, ganze Etappe Kiel – Hamburg ohne Fehler und mit `ERGEBNIS` bytegleich zur Basis.

## 1. Befunde der Prüfung QA-R5 – nachgestellt, behoben, abgelehnt

| ID | Schwere | Ergebnis | Kurz |
|---|---|---|---|
| QR5-01 | hoch | **behoben** (R5-Teil); R4-Teil offen | Portal-Mesh auf Renderlayer 2 – kein Spot des Abblendlichts, kein Lampen-Omni erreicht es (wie Arcade). Nachgestellt bitgleich mit QA-R5s Bildern; danach Stirnwand U1 22 Uhr 79 → 56 (Arcade 46), DEV 21 Uhr 107 → 57 (Arcade 47). Abblendkante bleibt R4s. |
| QR5-02 | mittel | **offen (R4)**, R5 liefert die Daten | Fahrbahn in der Röhre gehört R4 (`road.gd`/`road.gdshader`); R5 legt jetzt das Licht der Röhre in `tunnel_state["light"]`; genaue Änderung für R4 in Abschnitt 8. Bilder unverändert grau (gemessen). |
| QR5-03 | mittel | **von R4 gelöst** (nachgeprüft), Rest an R4 | Probe in einer Scratch-Kopie (dieser Kopf + `origin/wip/v080-fix-r4`): R4s Belichtungsfläche überstrahlt das Draußen wie Arcade. Sie steht aber bei `end_km` − 0,6 m vor dem wahren Röhrenende → R5s Ausfahrtsrahmen glüht mit. R5 liefert `tunnel_state["exit_z"]`; R4 setzt die Fläche dort an (Zeile in Abschnitt 8 Punkt 1, in der Scratch-Kopie gerendert: Abschnitt 3). |
| QR5-04 | mittel | **offen (R4 / Vertrag)** | Steinbrüstung liegt in R4s `roadside.gd`; R5 kann sie nicht ersetzen (eine Brüstung aus R5 stünde hinter der geschlossenen Wand). Vertragslücke „railings per type“ gemeldet. |
| QR5-05 | mittel | **behoben** | Neue/geschärfte Tests; die vier ungeschützten Mutationen (B10, B12, B14, T4) und eine neue für QR5-01 (P1) fängt jetzt je ein benannter Test, ohne Skriptfehler-Umweg (B10). |
| QR5-06 | niedrig | **behoben** | Netzlauf vergleicht genau mit Arcades Elementen; 122 Brücken, 28 Tunnel (Testetappe eingeschlossen), 0 Mängel, 180 s; fängt 5 von 5 eingebauten Teilverlusten. |
| QR5-07 | niedrig | **abgelehnt für FIX-R5** (Sache der Integration) | R5s Golden-Zeile bleibt; FIX-R5 ändert kein Modern-Bild der Liste (modern-check, Abschnitt 5) und fasst `tests/golden/**` nicht an. Beim RINT-M2-Merge die Liste mit `modern-make` neu erzeugen. |
| QR5-08 | niedrig | **offen (R4)** | Schiffe in R4s `props.gd` Z. 599; ohne R4s Zeile nicht lösbar (R5s Wasser bleibt 0,15 m über den Geländewasserzeilen, die R4 noch zeichnet). |
| QR5-09 | niedrig | **abgelehnt** (kein Code-Befund, gemessen) | Gotthard „deck“ 600 s: Commit-Maximum Basis 17,8 ms, FIX-R5 4,1 ms im selben Zustand → Last; headless (Minimum aus 3) Commit je Tunnelstück ≤ 0,25 ms, also 12 × unter dem deck-Budget 3 ms. |

### 1.1 QR5-01 – Nachtportal (hoch)

**Nachgestellt** (gemessen): `shots.sh repro u1_nacht dev` auf 5558bdc – die Bilder sind **bitgleich** (MD5) mit QA-R5s
Renderings (`u1_nacht_modern_00/01`, `dev_modern_00–02`).

**Ursache:** das Portal-Mesh `TunnelPortal` (Rahmen, Stirnwand, Flügelmauern, Hügel; vpbr) lag auf Renderlayer 1. Die
zwei Spots des Abblendlichts (R4 `layers/lights.gd`, 30° rundum, ohne Abblendkante) beleuchten alles auf Layer 1 bis
80 m, also auch eine senkrechte Wand 60–70 m voraus bis oben. Arcade beleuchtet sein Portal nie mit den Scheinwerfern
(`RoadRenderer._draw_portal` färbt mit `_rowc`: Farbe × Umgebungslicht + Nebel – ohne `_light()`), während es Requisiten,
Pylone und Fachwerk sehr wohl im Kegel aufhellt (`_oc(…, light)`). Darum ist die richtige Regel nur fürs Portal: aus
den Positionslichtern heraus.

**Behebung** (`builders/tunnel.gd`, eigene Datei): `const PORTAL_LAYERS := 2`, `pi.layers = PORTAL_LAYERS` im
`commit()`. Layer 2 ist die Bodenebene (Gelände, Fahrbahn, Wasser): `LIGHT_MASK` jedes Spots und Omnis = alles außer
Layer 2 (auch in R4s neuem Stand `0xFFFFF & ~2 & ~(1 << 19)`). Sonne, Mond, Umgebungslicht und Schatten bleiben
(Bilder bei Tag bitgleich mit R5, Abschnitt 4). Die Röhre (unbeleuchteter Shader mit eigenem Scheinwerferkegel) bleibt auf
Layer 1. Sobald R4 eine Abblendkante hat, darf der Fuß des Rahmens wieder auf Layer 1 (Kommentar an der Konstante).

**Gemessen** (PIL-Mittel 0–255, Rechtecke in 1280 × 720, „Hoch“):

| Stelle | Arcade | R5 5558bdc | FIX-R5 |
|---|---|---|---|
| U1 22 Uhr, Bild 00 (km 184,3) – Stirnwand über der Öffnung (560,268–720,284) | 39,47,63 (L 46) | 79,79,81 (L 79) | 50,57,68 (L 56) |
| U1 22 Uhr, Bild 00 – Flügelmauer links (515,320–540,342) | 36,44,59 (L 44) | 70,70,72 (L 70) | 45,50,61 (L 50) |
| U1 22 Uhr, Bild 00 – Hügel über dem Portal (605,180–650,230) | 16,31,23 (L 27) | 14,35,19 (L 30) | 14,35,19 (L 29) |
| DEV 21 Uhr, Bild 01 (km 48,8) – Stirnwand (560,238–650,254) | 39,47,63 (L 47) | 112,107,99 (L 107) | 51,58,69 (L 57) |
| DEV 21 Uhr, Bild 01 – Flügelmauer (440,300–460,318) | 36,44,58 (L 43) | 89,86,82 (L 86) | 46,52,62 (L 51) |

Die Stirnwand liegt jetzt im Blau der Nacht wie Arcade, ≈ 10 Stufen heller (Mondlicht auf hellem Beton; Arcade färbt
flach). Bilder, in denen der Kegel das Portal nicht erreicht (DEV 00/02, U1 01), sind bitgleich mit R5. Die senkrechten
hellen Streifen auf dem Hügel, die QA-R5 als „Lichtstreifen“ las, bleiben – sie kommen **nicht** vom Abblendlicht
(R5 und FIX-R5 dort gleich), sondern sind Mondschattierung der Hügelspalten (Arcades gesäte Höhenunterschiede je Spalte
geben jeder Spalte eine eigene Neigung) und die Mondschatten der Nadelbäume auf dem Grat; bei Tag fällt das nicht auf,
nachts schwach (Hinweis in 8).

**Wächter:** `test_tunnel.gd::test_portal_on_the_ground_layer_out_of_the_low_beam` (Portal auf Layer 2, `layers &
LIGHT_MASK == 0` mit R4s Konstante gelesen, Schatten an, Röhre auf Layer 1) – fängt die Mutation P1.

### 1.2 QR5-05 – Tests schützen alle R5-Regeln

| Mutation (wie QA-R5) | vorher | jetzt (gemessen, `mutate.py`, `mutations/results.json`) |
|---|---|---|
| B10 `night_albedo` des Pylons nicht gesetzt | nur `SCRIPT ERROR` (float(null)) | `test_dark_pylon_material_at_night` FAIL, 0 Skriptfehler (erst `!= null`, dann Wert 0,45 als Zahl) |
| B12 5 statt 7 Seile je Seite | grün | `test_koehlbrand_pylons_beacons_and_cables` FAIL (56 als Zahl, Arcades `for i in 7`) |
| B14 Brückenlampen nicht gebaut | grün | neuer `test_bridge_lamps_like_arcades_events` FAIL (Lampen = Arcades `bridge_lamp`-Ereignisse an Ludwigsbrücke und Ponte della Libertà, jede mit Lichteintrag) |
| T4 `set_zone` ohne `has_method` | grün | `test_set_zone_only_when_the_rig_has_it` FAIL (neues Rig `EnvWithoutZone`: kein Aufruf, `zone_calls` 0, `tunnel_state` folgt trotzdem dem Gesetz) |
| P1 (neu) Portal wieder auf Layer 1 | – | `test_portal_on_the_ground_layer_out_of_the_low_beam` FAIL |

Jede Mutation einzeln im Worktree, nur die zuständige Testdatei, Datei danach aus einer Sicherung zurück (`git status`
sauber geprüft). Grundlauf: `test_bridge` 11/11, `test_tunnel` 9/9.

### 1.3 QR5-06 – genauer Netzlauf

`check_tunnel_bridge.gd -- --full` vergleicht jetzt nach QA-R5s Verfahren genau mit Arcades Elementen derselben Strecke
(Einzelheiten im Dateikopf und in `docs/renderer-modern-tunnel-bruecken.md` §7): Pylone, Flugfeuer, 14 Seile je Pylon,
Fachwerkportale, Brückenlampen = Arcades Ereignisse; Wasser; Ufer an beiden Enden; Fachwerk/Bögen je Typ; nichts vom
Tragwerk über einer Spur zwischen 0,3 und 4,5 m; kein Seil näher als 1,5 m an einer Spur; ein Portal, ein
Ausfahrtsrahmen, Kappe wo Arcade die Röhre schließt, Nischen nach Arcades 150-m-Regel, mindestens Arcades zwei
Leuchtenreihen, jedes Tunnelsegment mit Röhre, nichts der Röhre über den Spuren, kein Hügelpunkt im Sichtkorridor der
Anfahrt (F7). Neu auch die Testetappe; `--only-stage=`, `--verbose`.

- **Ergebnis (gemessen):** `RENDER-CHECK tunnel_bridge_full OK – 122 Brücken {cable_stayed 12, canal 10, causeway 2,
  river 60, stone_arch 35, truss_arch 3}, 28 Tunnel exakt gegen Arcade geprüft (Pylone 44, Seile 616, Fachwerkportale 15,
  Brückenlampen 304, Nischen 72, Kappen 26), 0 mit Mängeln, 180 s` (`scan_full.log`).
- Der erste Lauf meldete 29 Flussbrücken ohne Pfeiler: Pfeiler sind Moderns eigene Zutat (Arcade zeichnet keine), eine
  kurze Flussbrücke überspannt ihr Wasser ohne – die Regel war meine, sie ist gestrichen (die Zahl steht in `--verbose`).
- **Wirkung** (gemessen, `mutate_scan.py`): Brückenlampen weg → „Ludwigsbrücke: Brückenlampen 0 statt 6“; 5 Seile →
  „Köhlbrandbrücke: Seile 40 statt 56“; Fachwerkportale weg → „Elbbrücken: 0 statt 5“; Nischen weg → „Sonnenbergtunnel:
  Nischen 0 statt 1“; Kappe weg → „Kappe 0 statt 1“ – jeweils Exit 1.

### 1.4 QR5-09 – Commit-Spitze am Gotthard (Leistung)

Nachgestellt mit QA-R5s Lauf (`run_stage.gd`, Bern – Mailand ab km 183, „deck“, 1280 × 800, Zeitraffer 4, 600 s
Wanduhr), Basis und FIX-R5 hintereinander (gemessen, Last 13–17):

| | Basis 5558bdc | FIX-R5 |
|---|---|---|
| Ende | FEHLER: Zeitlimit überschritten bei km 218.12 | FEHLER: Zeitlimit überschritten bei km 219.58 |
| Wanduhr (s) | 601 | 600 |
| Spielzeit (s) | 73.8 | 78.0 |
| Bilder | 554 | 585 |
| Bildzeit Median / p95 (ms, llvmpipe) | 1190 / 1706 | 1103 / 1581 |
| render() Mittel / max (ms) | 3.27 / 309.5 | 3.19 / 396.0 |
| sim_avg_ms / max (Lastmaß) | 1.26 / 452 | 1.16 / 226 |
| Stück-Commit Mittel / max (ms) | 1.34 / 17.77 | 1.03 / 4.13 |
| Stück-Bau Worker Mittel / max (ms) | 18.6 / 96.4 | 17.4 / 94.5 |
| Haken tunnel Mittel / max (ms) | 0.071 / 3.0 | 0.080 / 4.4 |
| Haken bridge Mittel / max (ms) | 0.004 / 0.0 | 0.006 / 0.8 |
| Haken far_ground Mittel / max (ms) | 0.094 / 4.0 | 0.092 / 1.8 |
| Zeichenaufrufe / Primitive (letztes Bild) | 126 / 112295 | 135 / 125871 |
| Schatten-Primitive (letztes Bild) | 5212 | 6802 |
| Texturspeicher (MB) | 114.6 | 114.6 |
| prepare_ms | 64529 | 61990 |

Lesart: Die Spitze ist Last, kein Code: im selben Lauf hatte die **Basis** 17,8 ms, FIX-R5 4,1 ms (die Simulation, die
R5 nicht berührt, hatte zugleich Spitzen von 452 bzw. 226 ms). Lastfest (A-11) gemessen, headless, Minimum aus 3
(`bench_r5.gd` von QA-R5, `perf/bench_new.log`): Commit je Tunnelstück höchstens **0,23 ms** (Gotthard) / **0,25 ms**
(Somport), Brückenstücke ≤ 0,61 ms (Elbbrücken) – weit unter dem deck-Budget 3 ms. Die Worker-Bauzeit am Tunnel
(Mittel 3,0 ms, max 4,2 ms) verzögert nur das Eintreffen eines Stücks (3,4 km Vorlauf). Darum keine Code-Änderung;
im Leistungstest des Nutzers bleibt `chunk_commit_ms_max` an Portalen zu beobachten (echte Hardware: abgeleitet).

## 2. Neue Daten für R4 (duck-typed, R5s Datei)

Beide Befunde, die an R4 hängen (QR5-02 Fahrbahn in der Röhre, QR5-03 Ausfahrt), brauchen Werte, die nur R5 kennt.
Ohne eine fremde Datei anzufassen, legt `builders/tunnel.gd` sie jetzt in seine Eigenschaft `tunnel_state` (lesbar über
`renderer.builder("tunnel")`, dokumentiert in `docs/renderer-modern.md` §15.1 und `renderer-modern-tunnel-bruecken.md` §2.4,
Unit-Tests in `test_tunnel.gd`):

- `tunnel_state["light"]` – das Licht der Röhre in diesem Bild, genau die Uniforms von `tunnel.gdshader`:
  `ambient_in`, `ambient_out` (Arcades Tunnelumgebung, von außen × (0,5 + 0,5 × Lichter)), `fog` (`Palette.TUNNEL_FOG`),
  `darkness_m`, `peek_m`, `cam_tunnel_z`, `lights`. Damit kann R4s Fahrbahn in der Röhre Arcades warmes Tunnellicht zeigen.
- `tunnel_state["exit_z"]` – Straßen-z, an dem die Röhre wirklich endet (Segmentgrenze nach `end_km`, wie Arcades
  Tunnelsegmente; INF draußen). `exit_m` misst wie bisher bis `end_km`.

Ohne Leser ändert beides nichts (Bilder bitgleich, Abschnitt 4).

## 3. Probe mit R4s Stand (QR5-03) – gemessen in einer Scratch-Kopie

Damit die Leitung weiß, was nach RINT-M2 an der Ausfahrt zu sehen ist, habe ich R4s Code (`git diff 6e48405
origin/wip/v080-fix-r4` ohne `docs/` und `tests/golden/`, sauber angewendet) auf diesen Kopf gelegt – nur in
`m1/FIX-R5/r4mix` (danach gelöscht), nichts davon ist committet – und U1 bei Tag und Nacht gerendert:

| U1 Ausfahrt 12 Uhr, Bild 01 (km 201,7) | Arcade | FIX-R5 allein | FIX-R5 + R4 (fix-r4) | + R4-Fläche an `exit_z` − 0,05 |
|---|---|---|---|---|
| Rahmen der Ausfahrt, oberer Balken (500,265–680,269) | (Arcade: kein Rahmen) L 157 | 166,130,86 (L 134) | 253,247,185 (L **244**, ausgebrannt) | 166,130,86 (L 134) |
| Gras jenseits der Öffnung (470,285–530,325) | 181,248,160 (L 227) | 59,77,24 (L 69) | 137,166,86 (L 154) | 134,161,82 (L 150) |

- **R4s Belichtungsrampe löst QR5-03**: das Draußen ist überstrahlt (L 69 → 150; Arcade 227), das „Licht am Ende des
  Tunnels“ ist da (`bilder/u1_ausfahrt_12uhr_01.jpg`, `ausschnitt_u1_ausfahrt_mit_r4.jpg`).
- **Aber** R4 setzt die Fläche bei `end_km` − 0,6 m; die Röhre endet erst an der Segmentgrenze danach. Dadurch liegt die
  Fläche vor R5s Ausfahrtsrahmen und den letzten Röhrenmetern – der Rahmen glüht als heller Ring (L 244). Mit der Fläche
  bei `exit_z` − 0,05 m (eine Zeile in R4s `environment_rig.gd`, Abschnitt 8 Punkt 1) bleibt der Rahmen Beton (L 134, gleich
  FIX-R5 allein) und das Draußen überstrahlt. Das ist die genaue Änderung für R4.
- Nachts mit R4s Stand: das Portal bleibt dunkel wie bei FIX-R5 allein (R4s neue `LIGHT_MASK` schließt Layer 2 weiter
  aus); die Fahrbahn in der Röhre bleibt grau (QR5-02 bei R4 offen).

## 4. Bilder – angesehen, ehrlich gegen Arcade

`bilder/` (Bögen Arcade | R5 5558bdc | FIX-R5 bzw. Arcade | FIX-R5; Ausschnitte `ausschnitt_*`), 1280 × 720 „Hoch“,
Steam Deck 1280 × 800 „deck“. Arcade-Bilder und R5-Bilder sind QA-R5s Renderings (meine Nachstellung des R5-Kopfs war
mit ihnen bitgleich, Abschnitt 1.1); FIX-R5-Bilder aus `m1/FIX-R5/shots/{fix1,fix2}` mit dem Code-Endstand (spätere
Commits ändern nur `tunnel_state` – ohne Bildwirkung, belegt durch bitgleiche Tagbilder).

**Bitgleich mit R5** (gemessen, MD5, `cmp.py`): U1 Anfahrt 12 Uhr (2 Bilder), U1 innen (2), U1 Ausfahrt (3), Somport
12 Uhr (3), Köhlbrandbrücke 22 Uhr (3), DEV 21 Uhr Bild 00/02, U1 22 Uhr Bild 01 – überall dort, wo der Abblendkegel das
Portal nicht erreicht. Der Fix ändert also nur, was er soll. Für alle übrigen Orte (Köhlbrand Rampe/Ende/Pylonspitzen,
Holtenau, B1, Elbbrücken, Stein, Kanal) gelten R5s und QA-R5s Bilder unverändert: FIX-R5 ändert dort keine Zeile Code.

| Ort | Bild | gegen Arcade | gegen R5 | Beobachtung |
|---|---|---|---|---|
| U1 22 Uhr, 60–70 m vor dem Portal | `u1_nacht_00/01`, `ausschnitt_u1_nacht_portal` | **gleich bis besser** (vorher schlechter) | besser | Stirnwand und Flügelmauern im Nachtblau wie Arcade statt bis oben angestrahlt; Rahmen, Laibung und Gesims bleiben als Form lesbar (Arcade: flache Fläche). Die Röhre leuchtet warm. Fahrbahn in der Röhre grau (R4, QR5-02). |
| U1 22 Uhr, Anfahrt bis in die Röhre | `u1_nacht_nah_fix` | – | – | Portal dunkel bis zur Einfahrt, innen Paneele, Gehwege, Leuchten; kein Himmel. |
| DEV 21 Uhr | `dev_21uhr_00–02`, `ausschnitt_dev_portal_21uhr` | **gleich bis besser** (vorher schlechter) | besser | Bild 01: Stirnwand L 107 → 57 (Arcade 47); die Wand liest sich nicht mehr wie bei Tag. |
| Somport 22 Uhr | `somport_22uhr_00–02` | **besser** | (R5 hatte kein Nachtbild) | Rahmen dunkel wie Arcades Portal, Röhre mit Paneelen, SOS-Nische, Notausgang; Fahrbahn in der Röhre grau statt Arcades warm (R4). |
| U1 12 Uhr | `u1_anfahrt_12uhr_00` | besser (wie R5) | bitgleich | Tag unverändert. |
| U1 Ausfahrt 12 Uhr | `u1_ausfahrt_12uhr_01`, `ausschnitt_u1_ausfahrt_mit_r4` | allein gleich; mit R4 + `exit_z` gleich bis besser | bitgleich | siehe Abschnitt 3. |
| Steam Deck 22 Uhr / 12 Uhr | `deck_u1_nacht_00/01`, `deck_u1_anfahrt_00/01` | Nacht gleich bis besser, Tag besser | – | Modern füllt 16:10, Arcade mit Balken; Portal nachts dunkel auch in „deck“. |

**Ehrliches Urteil:** Wo R5 baut, ist Modern jetzt auch **nachts am Portal** nicht mehr schlechter als Arcade, sondern
gleich bis besser (Form des Portals lesbar, dunkel wie Arcade, ≈ 10 Stufen heller durch Mondlicht). **Klar besser als
Arcade** sind weiter Röhre, Wasser, Ufer, Seile, Fachwerk. **Nicht besser** bleiben die drei Stellen, die an R4 hängen:
Fahrbahn in der Röhre von außen (grau statt warm, QR5-02), Ausfahrt ohne Überstrahlung, solange R4 nicht gemergt ist
(mit R4 + der Zeile aus Abschnitt 8 Punkt 1 gelöst, Abschnitt 3), Steinbrüstung (QR5-04). Schwach sichtbar nachts: Spaltenstreifen
auf dem Portalhügel im Mondlicht (Abschnitt 8).

## 5. Gates auf dem Endstand `80b8141` (gemessen; Befehle und Ausgaben in `m1/FIX-R5/gates/`, `queue.log`)

Alle Läufe im Worktree, einer nach dem anderen, `nice -n 10`, `XDG_DATA_HOME` absolut unter `m1/FIX-R5/`.

| Gate | Befehl | Ergebnis |
|---|---|---|
| Import | `godot --headless --path . --import` | Exit 0, kein Fehler |
| Skripte | `godot --headless --path . -s res://tests/check_scripts.gd` | „314 Skripte geprüft, 0 fehlerhaft“ |
| Tests voll (1. und einziger Lauf) | `tools/run_tests.sh` | **„769 Tests, 0 fehlgeschlagen … ==> Tests bestanden (935 s)“** – darunter `test_bridge` 11/11, `test_tunnel` 9/9, `test_far_ground_water` 4/4, `test_props` grün, `check_terrain_plan`, `modern_sight`/`modern_path_check` (Normallauf) |
| Arcade-Identität | `tools/golden.sh check` | **„GOLDEN arcade: 20 von 20 identisch (247 s)“, „GOLDEN arcade-ui: 17 von 17 identisch (352 s)“** |
| Modern-Änderungsmelder | `KEEP=… tools/golden.sh modern-check` | **„GOLDEN modern: 6 von 6 identisch (970 s)“**; „GOLDEN modern-gles: modern_s3_hoch OpenGL ES gegen OpenGL: OK max. Abweichung 2/255, PSNR 73,2 dB“ – kein Modern-Golden geändert, darum kein `modern-make` |
| Render-Prüfungen | `tools/run_render_checks.sh all` | 19 von 20 Dateien OK; `check_tunnel_bridge` 6/6 (U1_portal 0,000 % Magenta, U1_innen 612 Leuchtenpunkte / 0,322, U1_ausfahrt 0,226 (Röhre 0,449) / 0,0 % Weiß, Somport_portal 0,000 %, B1 0,000 % / 0,00 % Fernboden / 630 Wasserflächen, beacon 4 Feuer / 4 blinken); ZS1-Wächter `check_terrain_cover` T1–T4, S1, C1, **K1 0,000 %**, `check_start_km0` OK, `check_light_base` Tageslicht/Schatten OK. **`check_instance_budget_wald`: Zeitlimit 900 s** – der bekannte Lastbefund M2S-01 der Basis (in FIX-M2s Zweig behoben, nicht in dieser Basis; R5 und QA-R5 sahen dasselbe); allein mit längerem Zeitlimit nachgeprüft: **OK** – `RENDER_CHECK_TIMEOUT=2700 tools/run_render_checks.sh modern instance_budget_wald` allein: „instanzen_wald OK – 1018 Bilder, Fahrzeug-Ebene höchstens 127 Instanzen (Budget 128), ganze Szene höchstens 140 mit Instanz-Uniforms“ (770 s). Damit alle 20 Render-Prüfdateien grün |
| Sicht voll | `godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full` | alle OK: F1 0 Fälle bis 270 m (erster bei 280 m) in 99 424 500 Stichproben, F1 Außenspuren 0 bis 260 m, F2 ≤ 0,593 / 0,596 / 0,555, F3 0 von 5923, F7 0 von 2 011 532, Modell 0 abweichend (143 s) |
| Weg voll | `… -s res://tests/sim/modern_path_check.gd -- --full` | OK: kleinster Abstand 267,6 m (≥ 250), Schleifen frühestens nach 2064 m (57 s) |
| Netzlauf genau | `… -s res://tests/race3d/render/check_tunnel_bridge.gd -- --full` | OK: 122 Brücken, 28 Tunnel, 0 Mängel (180 s) |
| ganze Etappe Modern | Abschnitt 6 | Kiel – Hamburg ganz, Modus Modern, „Mittel“, Xvfb: Ziel erreicht, 0 Skript-/Shaderfehler, `ERGEBNIS` bytegleich mit der Basis; `render()` 2,22 / 24,6 ms (Basis 2,09 / 18,4), Commit max 2,92 ms (2,66), 105 Aufrufe / 93 050 Primitive (gleich) – Abschnitt 6 |

## 6. Leistung (gemessen auf llvmpipe unter Last; echte Hardware und Steam Deck abgeleitet)

### 6.1 Ganze Etappe Kiel – Hamburg im Modus Modern (Gate)

`m1/FIX-R5/perf.sh new|base kh`: `tests/race/run_stage.gd`, Kiel – Hamburg ab km 0 bis zum Ziel (Köhlbrandbrücke,
Elbbrücken: Wasser, Ufer, Fernwasser, Pylone, Seile, Fachwerk – R5s Bauten), Autopilot mit Tankstopp, 12 Uhr,
Limousine, Seed 11, Zeitraffer 4, Stufe „Mittel“, Xvfb 1280 × 720 – R5s Lauf. Derselbe Aufruf im Worktree (FIX-R5
`80b8141`) und in der Basiskopie (`git archive 5558bdc` + Import), direkt nacheinander.

| | Basis 5558bdc | FIX-R5 |
|---|---|---|
| Ende | Ziel, 95,0 km, nicht abgebrochen, 1 Tankstopp (42,2 L), 0 Skript-/Shaderfehler | dasselbe; `ERGEBNIS` bytegleich mit der Basis (MD5 c38986e4…) |
| Wanduhr (s) | 1506 | 1815 |
| Spielzeit (s) | 326.3 | 326.3 |
| Bilder | 2478 | 2478 |
| Bildzeit Median / p95 (ms, llvmpipe) | 500 / 745 | 712 / 1075 |
| render() Mittel / max (ms) | 2.09 / 18.4 | 2.22 / 24.6 |
| sim_avg_ms / max (Lastmaß) | 1.03 / 61 | 1.13 / 91 |
| Stück-Commit Mittel / max (ms) | 1.13 / 2.66 | 1.11 / 2.92 |
| Stück-Bau Worker Mittel / max (ms) | 5.0 / 19.2 | 6.3 / 36.8 |
| Haken tunnel Mittel / max (ms) | 0.004 / 0.1 | 0.004 / 1.1 |
| Haken bridge Mittel / max (ms) | 0.023 / 3.0 | 0.021 / 0.5 |
| Haken far_ground Mittel / max (ms) | 0.209 / 4.6 | 0.229 / 8.9 |
| Zeichenaufrufe / Primitive (letztes Bild) | 105 / 93050 | 105 / 93050 |
| Schatten-Primitive (letztes Bild) | 5353 | 5353 |
| Texturspeicher (MB) | 120.7 | 120.7 |
| prepare_ms | 34223 | 32631 |

Lesart (gemessen, llvmpipe, Last 10–17; die Basis lief direkt nach FIX-R5): Kiel – Hamburg hat **keinen Tunnel** – FIX-R5 ändert dort keinen Bau (die Bilder der Köhlbrandbrücke sind bitgleich mit R5), darum ist alles Gleiche gleich: dieselben 2478 Bilder, dasselbe `ERGEBNIS`, dieselben Zeichenaufrufe / Primitive / Schatten-Primitive im letzten Bild (105 / 93 050 / 5353), derselbe Texturspeicher (120,7 MB). `render()` im Mittel 2,22 gegen 2,09 ms, Commit-Maximum 2,92 gegen 2,66 ms (Budget „Mittel“ 3 ms gehalten), Worker-Bau 6,3 gegen 5,0 ms im Mittel – im Rahmen der Last: der FIX-R5-Lauf brauchte 21 % mehr Wanduhr (1815 gegen 1506 s) und seine Simulation, die R5 nicht berührt, 10 % mehr (`sim_avg_ms` 1,13 gegen 1,03). Gegen die Budgets von §4.10 („Mittel“: 900 Aufrufe, 700 000 Primitive) weit darunter. Steam Deck und echte GPU: abgeleitet; es zählt der Leistungstest des Nutzers.

### 6.2 Gotthard (Tunnel, „deck“) – Nachprüfung QR5-09

Siehe Abschnitt 1.4 (dieselben Läufe, gemessen): Commit-Maximum Basis 17,77 ms / FIX-R5 4,13 ms bei Lastspitzen der unberührten Simulation von 452 / 226 ms; headless (Minimum aus 3) ≤ 0,25 ms je Tunnelstück.

## 7. Commits (Branch `worktree-wf_fd1de4ee-28b-6`, gepusht nach `origin/wip/v080-fix-r5`)

| Commit | Inhalt |
|---|---|
| `7e575e6` | Portal auf Renderlayer 2 (`tunnel.gd` `PORTAL_LAYERS`); Tests: Brückenlampen, 56 Seile als Zahl, `night_albedo`/`emit_energy` auf null geprüft, Rig ohne `set_zone`, Portal-Layer; genauer Netzlauf |
| `7610875` | Netzlauf ohne die falsche Pfeilerregel – 0 Mängel; Doku |
| `ea5d8f7` | `tunnel_state["light"]` für R4s Fahrbahn in der Röhre; Test; Doku |
| `80b8141` | `tunnel_state["exit_z"]` für R4s Belichtungsfläche; Test; Doku |

Geänderte Dateien (`git diff --stat 5558bdc..80b8141`): `scripts/race3d/builders/tunnel.gd` (+30), `tests/unit/race3d/test_tunnel.gd`
(+58), `tests/unit/race3d/test_bridge.gd` (+46), `tests/race3d/render/check_tunnel_bridge.gd` (+246/−45),
`docs/renderer-modern-tunnel-bruecken.md`, `docs/renderer-modern.md` (§15) – alles R5-Eigentum.

## 8. Offen – genaue Änderungen für die Eigentümer (notes_for_next)

1. **R4 `environment_rig.gd` (Stand `origin/wip/v080-fix-r4`, Zeile 433) – Belichtungsfläche an die wahre Ausfahrt**
   (QR5-03-Rest): `var z_quad := z_exit - 0.6` → `var z_quad := ceilf(z_exit / _track.seg_len - 1.0e-6) * _track.seg_len - 0.05`
   (oder duck-typed `renderer.builder("tunnel").tunnel_state["exit_z"] - 0.05`). Die Röhre endet an der Segmentgrenze
   nach `end_km` (wie Arcades Tunnelsegmente), R5s Ausfahrtsrahmen steht von `exit_z` − 0,35 bis `exit_z`; bei
   `end_km` − 0,6 m liegt die Fläche bis zu 3,6 m davor und überstrahlt Rahmen und letzte Röhrenmeter. In der
   Scratch-Kopie gerendert: Abschnitt 3.
2. **R4 `road.gdshader` / `road.gd` – Fahrbahn in der Röhre im Tunnellicht** (QR5-02): für Fragmente mit Flag 64
   (`tunnel`) statt Bodengesetz (Umgebung des Himmels + Sonne) Arcades Tunnellicht: `ALBEDO = vec3(0)` (kein Sonnen-
   und Himmelsanteil der Engine), `EMISSION = ce_pools_encode(ce_ground_unshow(mix(base * tunnel_ambient, tunnel_fog, f))
   + ce_pools_to_lin(lit) * extra)` mit
   `f = pow(clamp((length(VERTEX) − 12) / tunnel_darkness_m, 0, 1), 0.8)` (Gesetz von `tunnel.gdshader`);
   `road.gd update()` setzt die drei Uniforms jedes Bild aus `renderer.builder("tunnel").tunnel_state["light"]`
   (duck-typed; `ambient_in` wenn `cam_tunnel_z` > −1e8, sonst `ambient_out`; `fog`, `darkness_m`). Ziel (Arcade,
   gemessen von QA-R5): U1-Portal 12 Uhr 42,33,24, 22 Uhr 103,87,70 statt heute 48,50,57 / 66,65,67.
3. **R4 `layers/lights.gd` – Abblendkante** (Ursache von QR5-01): ein flacher zweiter Kegel oder eine Projektortextur am
   Spot, damit senkrechte Flächen 60–70 m voraus nicht bis oben hell werden. Danach darf der Fuß des Portalrahmens wieder
   auf Layer 1 (`tunnel.gd PORTAL_LAYERS`).
4. **R4 `builders/roadside.gd` `_railing` für `stone_arch`** (QR5-04, 35 Steinbrücken): das geschlossene Mittelband
   [0,24, 0,92] durch Docken alle 0,35 m (0,14 m Kante) ersetzen wie Arcade – oder die Leitung gibt Geländer auf
   Brückensegmenten R5 (Vertragsfrage 1).
5. **R4 `builders/props.gd` Zeile 599** (QR5-08, A-16 „Schiffe auf der Wasseroberfläche“):
   `h = float(it["h"]) + (0.15 if bool(inp.get("skip_bridge", false)) else 0.0)`.
6. **R4 `builders/terrain.gd`**: die Wasserquads des Geländebands weglassen, wenn `renderer.builder("bridge")` existiert
   (sie liegen 0,15 m unter R5s Wasser, etwa 768 Dreiecke je Brückenstück) – danach kann R5s `WATER_LIFT` auf 0.
7. **Integration (RINT-M2) `tests/golden/modern_slice.md5`** (QR5-07): mit `tools/golden.sh modern-make` neu erzeugen, nicht
   von Hand mischen (R5, R4, R6 ändern Zeilen). FIX-R5 ändert kein Modern-Golden.
8. **R5-Rest, klein:** der Kopfblock der Köhlbrand-Pylone ist nachts etwas heller als der dunkle Pylon (Struktur-Material
   ohne `night_albedo`; im Rennbild hinter dem HUD); die Spalten des Portalhügels zeigen nachts schwache helle/dunkle
   Streifen im Mondlicht (Arcades gesäte Höhen je Spalte; Normalen könnten aus der ungestörten Form berechnet werden).
9. **Leistung:** `chunk_commit_ms_max` an Portalen im Leistungstest des Nutzers beobachten (llvmpipe unter Last 4–18 ms
   in Basis und FIX-R5, headless ≤ 0,25 ms). Worker-Bauzeit am Tunnel 3–4 ms je Stück (Basis-FIX1 0,6 ms) – nur
   Eintreffzeit.
10. **Doku-Merge:** `docs/renderer-modern.md` §15 (R5) kann mit R4/R6 kollidieren (R4 hat 232 Zeilen ergänzt) –
    beim Merge neu nummerieren.

## 9. Vertragsfragen

1. **Geländer an Brücken** (wie QA-R5 7.1-1): Inventar B / §6 R5 nennt „railings per type“ als R5-Ausgabe, §5 W3 gibt
   `builders/roadside.gd` R4. Die Steinbrüstung (QR5-04) hat damit keinen Besitzer, der sie an Arcades Docken bringen
   muss. Beleg: `ausschnitt_stein_bruestung.jpg` von QA-R5; R5 kann eine geschlossene Wand nicht von außen durchsichtig
   machen.
2. **Licht in der Röhre über Paketgrenzen** (QR5-02/03): das Tunnellicht entsteht in R5s `tunnel.gdshader`, die Fahrbahn
   und die Belichtung gehören R4. Lösung ohne Vertragsänderung: R5 liefert `tunnel_state.light` und `exit_z`
   (dokumentiert in renderer-modern.md §15.1), R4 liest duck-typed. Vorschlag: so im Vertrag festhalten.
