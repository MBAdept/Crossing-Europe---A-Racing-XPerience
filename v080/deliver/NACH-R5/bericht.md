# NACH-R5 – Nachprüfung der Nacharbeit FIX-R5 (Tunnel, Brücken)

Rolle: gezielte Nachprüfung von FIX-R5 (`origin/wip/v080-fix-r5`, Kopf `80b8141`) gegen R5 (`5558bdc`) und Arcade.
Keine Commits, keine Pushes, kein eigener Zweig. Worktree
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-8` (per `git merge --ff-only 80b8141`,
`.godot` kopiert, Import Exit 0); am Ende sauber (`git status` leer). Arbeitsdateien und Skripte:
`/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R5/`
(`shots.sh`, `base.sh`, `r4probe.sh`, `mutate.py`, `gates.sh`, `exitz_scan.gd`, `measure.py`, Logs `queue.log`, `gates/`,
`mutations/`). „gemessen“ = auf dieser VM (llvmpipe unter Xvfb bzw. headless, 4 geteilte Kerne); alles über echte GPUs,
Steam Deck oder Wirkung auf Menschen ist „abgeleitet“. Schwere Läufe nacheinander mit `nice -n 10` (`QA_M2_FERTIG` lag vor).

## Kurz

FIX-R5 hält, was es verspricht, und bleibt in R5s Dateien. Der einzige Code-Unterschied `5558bdc..80b8141` ist
`scripts/race3d/builders/tunnel.gd` (Portal-Mesh auf Renderlayer 2, `tunnel_state.light`, `tunnel_state.exit_z`); dazu
R5s Tests, R5s Render-Prüfung und Doku. Keine Arcade-Datei, keine Datei von R4/R6, kein Golden.

- **QR5-01 (hoch) behoben** (R5-Teil): nachts ist das Portal nicht mehr wie bei Tag angestrahlt. Gemessen, selbst
  gerendert gegen R5 und Arcade: U1 22 Uhr Stirnwand L 79 → 56 (Arcade 46), Flügelmauer 70 → 50 (44); DEV 21 Uhr
  Stirnwand 107 → 57 (47), Flügelmauer 86 → 51 (43). Wo der Kegel das Portal nicht trifft, sind die Bilder **bitgleich**
  mit R5 (9 von 9 Tag- und Nachtbildern). Rest: die schwachen hellen Streifen auf dem Portalhügel bei Mondlicht sind
  unverändert – sie kommen nicht vom Abblendlicht (in R5 und FIX-R5 gleich), also neuer kleiner Befund N-01.
- **QR5-05 (mittel) behoben**: alle vier ungeschützten Mutationen von QA-R5 plus P1 und zwei eigene (L1, X1) fängt je
  ein benannter Test (7 von 7, gemessen).
- **QR5-02, QR5-03, QR5-04 (mittel) nicht behoben** – erwartungsgemäß, sie liegen in R4s Dateien. Gemessen unverändert:
  Fahrbahn in der Röhre 12 Uhr 49,51,59 gegen Arcade 42,33,24; Ausfahrt draußen L 69 gegen Arcade 227; Steinbrüstung
  geschlossen. Die von R5 gelieferten Schnittstellen dafür stimmen: `exit_z` = Arcades erstes Nicht-Tunnelsegment in
  28 von 28 Tunneln (eigener Netzlauf), und die Probe mit R4s `fix-r4`-Code bestätigt FIX-R5s Zeile für R4 (Rahmen L 244 →
  134, draußen L 154/150 statt 69).
- Gates grün (gemessen): `check_scripts` 314/0, Unit-Tests `test_tunnel` 9/9, `test_bridge` 11/11,
  `test_far_ground_water` 4/4, `test_props` 12/12, Render-Prüfungen `tunnel_bridge` 6/6, `terrain_cover` T1–T4/S1/C1/K1,
  `start_km0`, `light_base`, Netzlauf `--full` 122 Brücken / 28 Tunnel / 0 Mängel, `minimal_structures` tunnel/bruecke OK,
  Arcade-Golden **20 von 20 und 17 von 17 identisch**.

## 1. Befunde von QA-R5 – je Befund

| ID | Schwere | Urteil | Beleg (gemessen, wo nicht anders gesagt) |
|---|---|---|---|
| QR5-01 | hoch | **behoben** (R5-Teil); Abblendkante bei R4 offen; Hügelstreifen → N-01 | Selbst gerendert (`tools/ab_shot.sh`, „Hoch“, 1280×720), R5 durch Tausch von `tunnel.gd` auf `5558bdc` (einziger Code-Unterschied). Mittelwerte (PIL, 0–255, Rechtecke wie FIX-R5): siehe Tabelle 1.1. Unit-Test `test_portal_on_the_ground_layer_out_of_the_low_beam` liest `LIGHT_MASK` aus R4s `lights.gd` und prüft `layers & LIGHT_MASK == 0`; Mutation P1 fällt. Mit R4s `fix-r4`-Code (Probe, Abschnitt 4) bleibt das Portal gleich dunkel (L 56,3 – R4s neue Maske schließt Layer 2 weiter aus). |
| QR5-02 | mittel | **nicht behoben** (R4: `road.gd`/`road.gdshader`) | U1 Anfahrt 12 Uhr Bild 01, Fahrbahn in der Röhre (600,365–680,385): FIX-R5 49,51,59 (L 51) = R5 bitgleich, Arcade 42,33,24 (L 34) – kalt grau statt warm (`bilder/u1_fahrbahn_roehre_12uhr_ausschnitt.jpg`). Nachts DEV/U1: dunkles Loch statt Arcades warmem Licht (`dev_21uhr_ab_01.jpg`). R5 liefert jetzt `tunnel_state.light` (Unit-Test, Mutation L1 fällt). |
| QR5-03 | mittel | **nicht behoben** auf diesem Kopf (R4: `environment_rig.gd`); mit R4 + einer Zeile gelöst (Probe) | U1 Ausfahrt 12 Uhr Bild 01: Gras jenseits der Öffnung (470,285–530,325) L 69 (Arcade 227), Röhrenwand L 120 – das Draußen ist dunkler als die Röhre. Render-Prüfung `U1_ausfahrt` meldet OK mit 0,226 gegen Röhre 0,449 (sie prüft nur „nicht schwarz“). Probe Abschnitt 4: R4 allein → draußen L 154, Ausfahrtsrahmen L 244 (ausgebrannt); R4 + Fläche an `exit_z − 0,05` → draußen L 150, Rahmen L 134. |
| QR5-04 | mittel | **nicht behoben** (R4 `roadside.gd`; Vertragslücke) | `bilder/stein_ab_01.jpg` (Kassel – Würzburg km 205,5, angesehen): Modern zeigt eine geschlossene graue Brüstung, Arcade helle Docken. FIX-R5 ändert keinen Brückencode. Vertrag §6 R5 nennt „railings per type“ als R5-Ausgabe, §5 gibt `roadside.gd` (W3) R4 – die Lücke besteht. |
| QR5-05 | mittel | **behoben** | `mutate.py` (je Mutation nur die zuständige Testdatei, Datei danach zurück, `git status` leer): B10 → `test_dark_pylon_material_at_night` FAIL ohne Skriptfehler; B12 → `test_koehlbrand_pylons_beacons_and_cables`; B14 → `test_bridge_lamps_like_arcades_events`; T4 → `test_set_zone_only_when_the_rig_has_it` (2 Skriptfehler durch den Aufruf selbst, aber benannter FAIL über `zone_calls`); P1 → `test_portal_on_the_ground_layer_out_of_the_low_beam`; eigene: L1 (`tunnel_state.light` im Frühausstieg nicht gesetzt) → `test_cap_only_for_a_camera_outside`; X1 (`exit_z` = `end_km`) → `test_set_zone_only_when_the_rig_has_it`. Grundlauf 11/11 und 9/9. |

Nicht im Auftrag, aber gestreift: QR5-06 (Netzlauf) – nachgefahren, `122 Brücken … 28 Tunnel exakt gegen Arcade geprüft
({"cables":616,"caps":26,"lamps":304,"niches":72,"portals":15,"pylons":44}), 0 mit Mängeln, 171 s` = FIX-R5s Zahlen.
QR5-07 (Golden-Zeile), QR5-08 (Schiffe, R4), QR5-09 (Leistung) nicht nachgeprüft.

### 1.1 QR5-01 gemessen

| Stelle (Rechteck in 1280×720) | Arcade | R5 5558bdc | FIX-R5 80b8141 |
|---|---|---|---|
| U1 22 Uhr Bild 00 – Stirnwand (560,268–720,284) | 39,47,63 (L 46,3) | 79,79,81 (L 79,1) | 50,57,68 (L 56,3) |
| U1 22 Uhr Bild 00 – Flügelmauer (515,320–540,342) | 36,44,59 (L 43,5) | 70,70,72 (L 69,8) | 45,50,61 (L 49,7) |
| U1 22 Uhr Bild 00 – Hügel (605,180–650,230) | 16,31,23 (L 27,4) | 14,35,19 (L 29,6) | 14,35,19 (L 29,3) |
| DEV 21 Uhr Bild 01 – Stirnwand (560,238–650,254) | 39,47,63 (L 46,5) | 112,107,99 (L 107,3) | 51,58,69 (L 56,9) |
| DEV 21 Uhr Bild 01 – Flügelmauer (440,300–460,318) | 36,44,58 (L 43,0) | 89,86,82 (L 86,2) | 46,52,62 (L 51,4) |

Bitgleich R5 = FIX-R5 (MD5): `u1_nacht_01`, `dev_00`, `dev_02`, `u1_anfahrt_00/01`, `u1_ausfahrt_00/01/02`; Arcade-Bilder
beider Läufe bitgleich. Meine Zahlen stimmen mit FIX-R5s Tabelle auf ±0,5 überein.

## 2. Diff `5558bdc..80b8141` – Nebenwirkungen, Eigentum, Arcade

- Dateien: `scripts/race3d/builders/tunnel.gd`, `tests/unit/race3d/{test_tunnel,test_bridge}.gd`,
  `tests/race3d/render/check_tunnel_bridge.gd`, `docs/renderer-modern-tunnel-bruecken.md`, `docs/renderer-modern.md` –
  alles R5-Eigentum (Vertrag §6 R5, A-8). Keine eingefrorene Arcade-Datei, nichts von R4/R6, kein Golden. Die Basis
  `6e48405` ist Vorfahr.
- Renderlayer 2: im ganzen Baum setzt nur `lights.gd`/`prewarm.gd` Lichtmasken (`LIGHT_MASK = 0xFFFFF & ~2`); keine Kamera
  hat eine `cull_mask`, die Sonne/der Mond keine `light_cull_mask` → das Portal bleibt sichtbar, im Sonnen- und Mondlicht,
  wirft und empfängt Schatten (Tagbilder bitgleich). Keine Prüfung erwartet Layer 1 für das Portal
  (`check_modern_stage` prüft nur `Road`/`Roadside`). Debug-Ansicht `cover` hängt nicht an Layern.
- `tunnel_state` wird jedes Bild neu gebaut; `light` wird auch im Frühausstieg gesetzt (sonst fehlte es ab dem zweiten
  Bild – Mutation L1 fängt das). Auf Etappen ohne Tunnel bleibt `tunnel_state` leer (Leser müssen `.get()` nehmen –
  so dokumentiert).
- `check_tunnel_bridge.gd -- --full`: Vergleich mit Arcades Ereignissen, Spurfreiheit, Seilabstand, Hügel-Sichtkorridor
  (F7) – sinnvoll; nur die Röhrenzählung „Röhre n von m Segmenten“ ist nicht unabhängig (beide Seiten nutzen dieselbe
  `ceil`-Formel) – darum mein eigener Netzlauf in Abschnitt 3.

## 3. Schnittstelle `exit_z` unabhängig geprüft

`exitz_scan.gd` (headless, gemessen): für jeden Tunnel jeder Richtung (und der Testetappe) Portal-z und `exit_z` nach
der Formel von `tunnel.gd` gegen Arcades eigene Segmentflags (`Track.get_segment(k).tunnel`, erstes Tunnel- und erstes
Nicht-Tunnelsegment): **`EXITZ-SCAN OK: 28 Tunnel, 0 abweichend`** – auch für Tunnel, deren `end_km` genau auf einer
Segmentgrenze liegt (Jagdbergtunnel, Abstand 0,0000 Segmente). Der Unit-Test vergleicht `exit_z` dagegen mit einem
Helfer derselben Formel (nicht unabhängig, kleiner Hinweis N-03).

## 4. Probe mit R4s Stand (nichts committet)

`r4probe.sh`: `git diff 6e48405 b156763 -- assets scripts` (R4 `origin/wip/v080-fix-r4`, 24 Dateien) auf `80b8141`
angewendet, U1 Ausfahrt 12 Uhr und U1 22 Uhr gerendert, dann FIX-R5s Zeile in R4s `environment_rig.gd`
(`var z_quad := ceilf(z_exit / _track.seg_len - 1.0e-6) * _track.seg_len - 0.05`) gesetzt, Ausfahrt erneut gerendert;
danach alles zurück (`git apply -R`, Status leer). 0 Skript-/Shaderfehler.

| U1 Ausfahrt 12 Uhr, Bild 01 | Arcade | FIX-R5 allein | + R4 fix-r4 | + R4 + Fläche an `exit_z` |
|---|---|---|---|---|
| Rahmen oben (500,265–680,269) | L 157 (kein Rahmen) | L 134,4 | **L 243,5** (ausgebrannt) | L 134,4 |
| Gras jenseits (470,285–530,325) | L 227,2 | L 68,9 | L 153,7 | L 149,7 |
| Röhrenwand links (100,300–250,400) | L 114,4 | L 120,3 | L 120,3 | L 120,3 |

`bilder/u1_ausfahrt_12uhr_mit_r4.jpg` (angesehen): R4 allein legt die Fläche vor R5s Ausfahrtsrahmen – ein heller Ring und
überstrahlte letzte Fahrbahnmeter; mit der Zeile bleibt der Rahmen Beton, das Draußen ist überstrahlt („Licht am Ende des
Tunnels“), weniger grell als Arcade. Nachts mit R4: Stirnwand L 56,3 wie FIX-R5 allein. FIX-R5s Hinweis 1 ist damit
bestätigt.

## 5. Bilder – angesehen, ehrlich gegen Arcade

`bilder/` (Arcade | R5 | FIX-R5 bzw. Arcade | Modern; „Hoch“, 1280×720):

| Bild | gegen Arcade | Beobachtung |
|---|---|---|
| `u1_22uhr_portal_ausschnitt.jpg`, `u1_22uhr_ganz.jpg`, `u1_22uhr_ab_00.jpg` | **gleich bis etwas besser** (R5: schlechter) | Stirnwand im Nachtblau, Rahmen mit Laibung und Gesims lesbar; ≈ 10 Stufen heller als Arcade (Mond auf hellem Beton). Fahrbahn in der Röhre dunkel statt warm (QR5-02). |
| `dev_21uhr_portal_ausschnitt.jpg`, `dev_21uhr_ganz.jpg`, `dev_21uhr_ab_01.jpg` | **gleich bis etwas besser** (R5: deutlich schlechter – Wand fast weiß) | wie U1. |
| `u1_huegel_nacht_kontrast.jpg` (Tonwert 0–40 %) | **etwas schlechter** | Helle, vom Grat abwärts fächernde Streifen auf dem Portalhügel in R5 und FIX-R5 gleich; Arcades Hügel ist eben. Im normalen Bild schwach sichtbar (N-01). |
| `u1_22uhr_innen_ab_01.jpg`, `somport_22uhr_ab_01.jpg` | **besser** | Paneele, Fugen, Notausgang mit Schild, Leuchten mit Lichthof, Gehwege. |
| `u1_anfahrt_12uhr_ab_01.jpg`, `u1_fahrbahn_roehre_12uhr_ausschnitt.jpg` | Röhre besser, **Fahrbahn in der Röhre schlechter** | kalt grau statt Arcades warmem Tunnellicht (QR5-02, R4). |
| `u1_ausfahrt_12uhr_ab_01.jpg`, `u1_ausfahrt_12uhr_mit_r4.jpg` | allein **schlechter** (Draußen dunkler als die Röhre); mit R4 + Zeile gleich bis besser | QR5-03. |
| `stein_ab_01.jpg` | Brüstung **schlechter** | geschlossene Wand statt Docken (QR5-04, R4/Vertrag). |

Urteil: FIX-R5 macht das Nachtportal vom Rückschritt zu einem Gleichstand mit leichtem Vorteil; klar besser als Arcade
sind weiter das Röhreninnere. Klar besser ist Modern an Tunneln und Steinbrücken erst, wenn R4s drei Stellen
(Fahrbahn in der Röhre, Belichtungsfläche an `exit_z`, Brüstung) gemergt sind.

## 6. Gates (gemessen, Worktree auf `80b8141`, sauber)

| Gate | Befehl | Ausgabe |
|---|---|---|
| Import | `godot --headless --path . --import .` | Exit 0 |
| Skripte | `godot --headless --path . -s res://tests/check_scripts.gd` | „314 Skripte geprüft, 0 fehlerhaft“ |
| Unit | `tools/run_tests.sh test_tunnel` / `test_bridge` / `test_far_ground_water` / `test_props` | 9/0, 11/0, 4/0, 12/0 – je „==> Tests bestanden“ |
| Render R5 | `RENDER_CHECK_TIMEOUT=1800 tools/run_render_checks.sh modern tunnel_bridge` | 6/6 OK: U1_portal 0,000 % Magenta; U1_innen 612 Leuchtenpunkte, 0,322; U1_ausfahrt 0,226 (Röhre 0,449), 0,0 % Weiß; Somport_portal 0,000 %; B1 0,000 % / 0,00 % Fernboden / 630 Wasserflächen; beacon 4 Feuer / 4 blinken |
| Render ZS1-Wächter | `… modern terrain_cover`, `start_km0`, `light_base` | T1–T4, S1, C1, **K1** je 0,000 % Magenta; kamera/auto/boden OK; tageslicht/schatten OK |
| Netzlauf | `godot --headless --path . -s res://tests/race3d/render/check_tunnel_bridge.gd -- --full` | „122 Brücken …, 28 Tunnel exakt gegen Arcade geprüft …, 0 mit Mängeln, 171 s“ |
| exit_z | `exitz_scan.gd` (eigen) | „EXITZ-SCAN OK: 28 Tunnel, 0 abweichend“ |
| Mutationen | `mutate.py` | 7 von 7 von benannten Tests gefangen |
| Strukturen | `tools/run_tests.sh minimal_structures` | `CHECK tunnel OK` (Elbtunnel: 110 Tunnelsegmente mit Röhre, Portal, Kappe, 56 Lampen), `CHECK bruecke OK` (Köhlbrandbrücke 130 Segmente mit Geländer), station/tore/wahrzeichen OK |
| Arcade-Identität (einmal, am Ende) | `tools/golden.sh check` | **„GOLDEN arcade: 20 von 20 identisch (166 s)“, „GOLDEN arcade-ui: 17 von 17 identisch (201 s)“** |

Nicht gelaufen: der volle `tools/run_tests.sh` (FIX-R5: 769/0; die Änderung berührt nur `tunnel.gd`, dessen Tests und
Prüfungen liefen), `modern_sight --full` (keine Platzierung geändert – nur der Renderlayer), `golden.sh modern-check`
(die Modern-Goldens zeigen Kiel – Hamburg, dort gibt es keinen Tunnel; FIX-R5 maß 6/6).

## 7. Neue Befunde

| ID | Schwere | Wo | Befund |
|---|---|---|---|
| N-01 | niedrig | R5 `builders/tunnel.gd` `_hill` | Nachts im Mondlicht helle, vom Grat abwärts fächernde Streifen auf dem Portalhügel (je Spalte gesäte Höhe → eigene Normale; Mondschatten der Nadelbäume am Grat). In R5 und FIX-R5 bitgleich in diesem Bereich, also nicht vom Abblendlicht – QA-R5 las sie als Lichtstreifen. Arcades Hügel ist eben (`u1_huegel_nacht_kontrast.jpg`). Vorschlag (FIX-R5s eigener Hinweis): Normalen aus der ungestörten Form rechnen. |
| N-02 | niedrig | `docs/renderer-modern-tunnel-bruecken.md` Z. 207–213; `docs/renderer-modern.md` §15.2 | Der eingefügte Absatz „Jede dieser Regeln …“ steht mitten in der Testtabelle – die Zeilen `check_tunnel_bridge.gd`, `check_minimal_structures.gd`, `test_far_ground_water.gd` verlieren ihren Tabellenkopf (Markdown). Der Portal-Absatz steht unter der Überschrift „Wasser im Licht“. `tunnel_state` in §2.4 nennt `exit_z` nicht. |
| N-03 | niedrig | `tests/unit/race3d/test_tunnel.gd` `_exit_z` | Der Test vergleicht `exit_z` mit einem Helfer derselben Formel; ein gemeinsamer Fehler bliebe grün. Unabhängig wäre: erstes Segment nach dem Portal mit `get_segment(k).tunnel == false` (wie `exitz_scan.gd`). |

## 8. Hinweise für die Leitung (RINT-M2)

1. R4 `environment_rig.gd` (fix-r4, Z. 433): `var z_quad := ceilf(z_exit / _track.seg_len - 1.0e-6) * _track.seg_len - 0.05`
   (oder `renderer.builder("tunnel").tunnel_state["exit_z"] - 0.05`) – in dieser Probe gerendert und bestätigt.
2. R4 `road.gd`/`road.gdshader`: Tunnel-Fragmente im Tunnellicht aus `tunnel_state.light` (QR5-02) – offen.
3. R4 `roadside.gd` `stone_arch`: Docken statt Wand (QR5-04) oder die Leitung gibt Brückengeländer an R5 (Vertragslücke).
4. R4 `lights.gd`: Abblendkante; danach darf der Fuß des Portalrahmens wieder auf Layer 1.
5. R5 klein: N-01 bis N-03.
6. `tests/golden/modern_slice.md5` beim Merge mit `modern-make` neu erzeugen (QR5-07, unverändert offen).

## 9. Aufräumen

Worktree sauber (keine Änderung, kein Commit). Mesa-Cache, Xdg-Ordner und Zwischenbilder in `m1/NACH-R5/` gelöscht
bis auf die Logs, die PNGs der Bilder in `shots/` (für Nachmessungen) und die Skripte.
