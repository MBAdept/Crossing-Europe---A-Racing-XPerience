# FIX-WASSER – die Elbe unter der Köhlbrandbrücke (Testbuild Zwischenstand 1)

Für die Leitung. Paket FIX-WASSER auf der Basis `3a23cb8` (FIX-ZS1, `origin/wip/v080-fix-zs1`). Branch
`worktree-wf_bdb6e1e1-c64-1`, Sicherung `origin/wip/v080-fix-wasser`, Worktree
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-1`. Kein Vorgänger gefunden (keine
`STAND.md`, kein Remote-Branch) – frisch begonnen um 05:21 UTC.
„gemessen“ = auf dieser VM (Mesa llvmpipe unter Xvfb, 4 geteilte Kerne, Last 6–10); alles über Steam Deck, echte
Grafikkarten, ANGLE/Direct3D ist **abgeleitet**.

## Urteil

**Die Elbe liegt unter der Köhlbrandbrücke, die Fähren schwimmen – gesehen im exportierten Linux- und Windows-Build;
der Testbuild aus `0ad9012` kann raus.**

- **Ursache** (FIX-ZS1-B1): Die Fernboden-Scheibe lag 4 m unter der tiefsten geladenen Straße, das Wasser 9 m – die
  undurchsichtige Scheibe deckte die Elbe zu. **Behebung an der Wurzel**, eine Spieldatei (`layers/far_ground.gd`):
  die Scheibe liegt jetzt auch 0,3 m unter der tiefsten Wasserfläche des geladenen Fensters; sie bewegt sich dabei nur
  nach unten (F7 bleibt), gleitet mit der alten Steigung (kein Sprung) und liegt ohne tiefes Wasser **bitgenau wie
  bisher**.
- **Betroffen** (aus den Daten aller 128 Etappenrichtungen): 7 Brücken in 15 Richtungen – Köhlbrandbrücke,
  Holtenauer Hochbrücke, Kirchenfeldbrücke und die Schrägseilbrücken in Köln, Budapest, Belgrad und Riga; überall liegt
  die neue Scheibe unter dem Wasser.
- **Bilder** (alle angesehen): Köhlbrandbrücke bei Tag und Nacht, „Hoch“ und Steam-Deck-Stufe – Elbe wie Arcade,
  Fähren auf dem Wasser; Holtenau, Rhein in Köln, Donau in Budapest ebenso; Elbbrücken und der Damm nach Venedig
  unverändert. Die tiefere Scheibe zeigt sich nur als Streifen von ≤ 12 Zeilen am Horizont (0,000 % Löcher) – keine
  Grube.
- **Änderungsmelder**: nur `modern_s4_mittel` neu (393 Pixel am Horizont), die anderen fünf MD5-gleich.
- **Tore** auf `0ad9012` alle grün: Import, 307 Skripte, `run_tests.sh` 703/0 mit unveränderter Fairness, Arcade
  20/20 und 17/17 identisch, Modern 6/6 + OpenGL ES, **18 von 18 Render-Prüfdateien** (Geländesperre, Start bei km 0).
- **Unit-Test** `test_far_ground_water.gd`: 4/4 grün, auf `3a23cb8` 3 von 4 rot.
- **Ehrlich zum Bild**: an der Brücke jetzt gleichwertig bis etwas besser als Arcade, nicht deutlich besser – hinter
  dem Fluss fehlt Arcades graues Ufer (Streifen Wiese, kein Fernwasser), das Wasser ist eine glatte Fläche, nachts sind
  die Pylone grell weiß.

## 1. Ursache und Behebung

### 1.1 Ursache (Code gelesen, nachgerechnet, im Bild bestätigt)

Die Fernboden-Scheibe (`scripts/race3d/layers/far_ground.gd`) lag auf `tiefste Straße des geladenen Fensters −
far_ground_drop_m (4,0 m)`. Das Gelände legt die Ringe einer Wasserreihe (Reihen einer Brücke, `TrackSegment.water`)
auf `Fahrbahnhöhe + water_level` (`terrain_profile.gd`), unter der Köhlbrandbrücke also 9 m unter die Fahrbahn – 5 m
**unter** die undurchsichtige Scheibe, die das Wasser zudeckte. Gemessen mit dem Kern (Skript
`m1/FIX-WASSER/scan_bridges.gd`): Kamera an der Köhlbrandbrücke – Scheibe auf 3,52 m, Wasser auf −1,48 m (Ursprung
des Pfads), also 5,00 m darüber, an allen vier Kamerastellen vor und auf der Brücke.

### 1.2 Behebung (eine Spieldatei)

`scripts/race3d/layers/far_ground.gd`:

    far_y = min(tiefste Straße des Fensters − 4,0 m,  tiefste Wasserfläche des Fensters − 0,3 m)

- `lowest_water()`: jede Reihe jeder Brücke (`Track.bridges`) im geladenen Fenster, die Wasser trägt, auf der Höhe, die
  das Gelände dort zeichnet (`path.height(k) + min(water_level, 0)`) – dasselbe Fenster wie `lowest_road()`
  (`window_rows()`: `keep_behind_m` + ein Stück zurück, min(`load_path_m`, Sicht + zwei Stücke) voraus). Kosten: eine
  Schleife über die Brücken der Etappe (≤ 5), Reihen nur, wenn eine Brücke im Fenster liegt (Köhlbrandbrücke 87 Reihen),
  und nur, wenn die Kamera eine neue Reihe erreicht – wie bisher.
- `WATER_MARGIN_M` = 0,3 m: kleiner als der Abstand an den Elbbrücken (Wasser 3,6 m unter der Fahrbahn, alte Scheibe 4,0 m
  → 0,4 m darunter), damit dort **nichts** anders wird; Tiefenpuffer: bei 12 m Augenhöhe über dem Wasser liegen die
  Treffer von Wasser und Scheibe auf 1 km 25 m auseinander, die Auflösung des 24-Bit-Puffers ist dort 6 cm (gerechnet).
- Gleiten statt Springen: die Höhe folgt ihrem Ziel wie bisher mit höchstens 0,35 m je Meter Fahrt. Die Köhlbrandbrücke
  kommt bei Sicht 900 m 1.092 m voraus ins Fenster; die Scheibe sinkt 5 m in 14 m Fahrt und liegt lange vor der Sicht
  unter dem Wasser; 246 m hinter der Brücke steigt sie ebenso wieder. Erstes Bild und Sprung über 150 m: sofort.
- Die Scheibe bewegt sich nur **nach unten** gegenüber vorher, verdeckt also weiterhin nichts (F7). Ohne Wasser im
  Fenster oder mit Wasser über der alten Scheibe ist `far_y` **genau** die alte Regel (Unit-Test, 1e-5 m).
- `snapshot()` meldet zusätzlich `water_y`.

Nicht geändert: `terrain_profile.gd`, `builders/terrain.gd`, `ground_look.gd` (das Wasser selbst war richtig, nur
verdeckt), kein Arcade-Code, kein Shader, keine Konfiguration.

## 2. Alle hohen Brücken über tiefem Wasser (aus den Daten)

Skript `m1/FIX-WASSER/scan_bridges.gd` (Ausgabe `scan_bridges2.log`, 49 s, gemessen): alle 128 Etappenrichtungen, jede
Brücke ihres Zielorts (122 Brücken-Richtungen), Kamera 300 m davor, am Anfang, in der Mitte und 30 m vor dem Ende; die
alte und die neue Scheibe gegen das tiefste Wasser **dieser** Brücke im Fenster.

| Brücke (Ort) | Typ, Wassertiefe | Richtungen (Etappe ab) | alte Scheibe über dem Wasser | neu |
|---|---|---|---|---|
| Köhlbrandbrücke (Hamburg, Elbe) | Schrägseil, 9 m | kiel_hamburg ab Kiel, hamburg_bremen ab Bremen, hamburg_hannover ab Hannover | 5,00 m (Hannover-Seite 3,27–4,58 m) | 0,30 m darunter |
| Holtenauer Hochbrücke (Kiel, Nord-Ostsee-Kanal) | Fluss, 16 m | kiel_hamburg ab Hamburg, rostock_kiel ab Rostock | 10,89 / 12,00 m | 0,30 m darunter |
| Kirchenfeldbrücke (Bern, Aare) | Fluss, 8 m | lyon_bern ab Lyon (von Mailand her liegt die Straße im Fenster tiefer: nicht verdeckt) | 0,64 m | 0,30 m darunter |
| Severinsbrücke (Köln, Rhein) | Schrägseil, 5 m (Vorgabe) | frankfurt_koeln ab Frankfurt, koeln_bruessel ab Brüssel | 1,00 m | 0,30 m darunter |
| Elisabethbrücke (Budapest, Donau) | Schrägseil, 5 m | budapest_wien ab Wien, belgrad_budapest ab Belgrad, timisoara_budapest ab Timișoara | 1,00 m | 0,30 m darunter |
| Ada-Brücke (Belgrad, Save) | Schrägseil, 5 m | slavonski_brod_belgrad ab Slavonski Brod, belgrad_sofia ab Sofia, belgrad_budapest ab Budapest | 1,00 m | 0,30 m darunter |
| Vanšu-Brücke (Riga, Daugava) | Schrägseil, 5 m | kaunas_riga ab Kaunas | 1,00 m | 0,30 m darunter |

7 Brücken in 15 Etappenrichtungen; in allen 122 Brücken-Richtungen liegt die neue Scheibe unter dem Wasser (0 Fälle
„NEIN“). Nicht betroffen (Wasser schon über der alten Scheibe, Bild unverändert): Elbbrücken 3,6 m (0,40 m darüber),
Steinbrücken 3,2 m, Flussbrücken 3 m, Grachten 1,8 m, Ponte della Libertà (Damm nach Venedig, Lagune) 1,4 m (2,60 m
darüber).

Wo die Scheibe tiefer liegt (Skript `scan_gaps.gd`, Ausgabe `scan_gaps.log`): Kiel – Hamburg km 67,2–82,8 um bis zu
5,30 m; Holtenau um bis zu 12,30 m (15 km Strecke); die Schrägseilbrücken um 1,30 m. In diesen Abschnitten ist das
schmalste Geländeband in 300 m voraus **319 m** breit (Belgrad; Hamburg 424 m, äußerer Ring 480 m) – es gibt dort keinen
Spalt an einer Mittelachse und kein Loch einer engen Kurve nahe der Straße: Die tiefere Scheibe ist nur jenseits der
Bänder am Horizont zu sehen (Messung im Bild: Abschnitt 4.4).

## 3. Unit-Test (Abnahme f)

`tests/unit/race3d/test_far_ground_water.gd` – die Ebene mit ihrem eigenen `update()` an einem Stellvertreter der
Renderer-Fassade (A-7: `cfg`, `track`, `path`, `camera`, `scenery_db`, `world`; Duck-Typing), echte Etappen, das Wasser
zählt der Test selbst Reihe für Reihe aus der Strecke:

| Test | prüft |
|---|---|
| `test_plane_lies_below_the_elbe_under_the_koehlbrand_bridge` | km 73 … 80,3 (Rampe, Deck, beide Fähren): Scheibe ≥ 0,25 m unter dem tiefsten Wasser des Fensters und unter jeder geladenen Straße; die zwei Fähren (`h` = −9 m = Wasserhöhe) stehen über der Scheibe |
| `test_plane_unchanged_away_from_deep_water` | km 2, 30, 60, 65, Elbbrücken-Mitte, km 93: `far_y` = alte Regel (± 1e-5 m); Elbbrücken-Wasser über der Scheibe |
| `test_plane_glides_down_when_the_bridge_enters_the_window` | Fahrt in 1,5-m-Schritten (90 km/h, 60 Bilder/s) von 1.400 bis 700 m vor der Brücke: ohne Wasser im Fenster die alte Regel; die Brücke kommt > 1.000 m vorher ins Fenster; kein Schritt größer als 0,35 × 1,5 m; ab Sichtweite + 50 m liegt die Scheibe unter dem Wasser |
| `test_deep_bridges_of_other_stages_stay_visible` | Holtenauer Hochbrücke, Severinsbrücke, Elisabethbrücke, Kamera auf dem Deck |

Gemessen: mit der Behebung **4 von 4 grün** (3 s); auf der Basis `3a23cb8` (nur `far_ground.gd` zurückgesetzt, Skript
`m1/FIX-WASSER/ut_on_base.sh`, Log `ut_on_base.log`) **3 von 4 rot** mit echten Zusicherungen, z. B. „km 78.95: Fernboden
3.52 m, tiefstes Wasser -1.48 m – die Scheibe muss darunter liegen (liegt 5.00 m darüber)“, „Holtenauer Hochbrücke
(16.0 m tief): Fernboden 12.00 m über dem Wasser“; der vierte Test (alte Regel ohne tiefes Wasser) ist auf beiden grün,
wie er soll.

## 4. Bilder (alle angesehen)

Alle A/B-Bilder mit `tools/ab_shot.sh` (Arcade | Modern, derselbe Simulationszustand; Limousine, Seed 11, Autopilot,
fliegender Start mit 60 km/h, ohne Verkehr). „vorher“ = dieselben Modern-Läufe mit dem `far_ground.gd` von `3a23cb8`
(kurz eingesetzt, danach aus HEAD wiederhergestellt; Skript `m1/FIX-WASSER/before_queue.sh`). Dreierbilder
Arcade | Modern vorher | Modern nachher in `bilder/` (Skript `triptych.sh`).

### 4.1 (a) Köhlbrandbrücke km 77,5–78,5

Bildzeiten 0,3 / 1,5 / 2,5 / 4 s ab km 77,5 → HUD km 77,5 (Rampe, 250 m vor den Fähren), 77,8 (Ende der Rampe), 78,1
(auf dem Deck, Fähren am Bildrand), 78,5 (Deck, Pylone).

| Serie | Bilder (`bilder/`) | angesehen: Modern nachher gegen Arcade |
|---|---|---|
| Tag 12 Uhr, „Hoch“, 1280 × 720 | `kb_tag_high_0[0-3]_arcade_vorher_nachher.jpg` | Die Elbe liegt unter und neben der Brücke wie in Arcade: von der Rampe aus als breites Band quer durchs Bild mit beiden Fähren darauf, vom Deck aus auf beiden Seiten bis zum Horizont; die Fähren schwimmen mit dem Rumpf auf der Wasserlinie (Höhe `h` = −9 m = Wasserhöhe). Farbe: Modern etwas heller und grauer (spiegelt zum Horizont den Himmel), Arcade satter blau. **Vorher**: grüne Wiese bis zum Horizont, wo Arcade die Elbe zeigt, die Fähren stehen auf der Wiese (nachts dunkelgrüne Wiese statt dunklem Wasser) |
| Nacht 22 Uhr, „Hoch“ | `kb_nacht_high_0[0-3]_…` | Elbe dunkel wie Arcade, die Fähren mit erleuchteten Fenstern auf dem Wasser, kein heller oder schwarzer Saum am Ufer. Unabhängig vom Wasser: die Pylone leuchten in Modern fast weiß (Arcade dunkelgrau) |
| Tag, Stufe `deck`, 1280 × 800 | `kb_tag_deck_0[0-3]_…` | wie „Hoch“; das Band reicht hier 480 m, am Horizont ist der Wiesenstreifen etwas breiter (`horizont_koehlbrand_km78_5_deck.jpg`) |
| Nacht, Stufe `deck`, 1280 × 800 | `kb_nacht_deck_0[0-3]_…` | wie Nacht „Hoch“ |

**Fernboden neben dem breiten Fluss** (wie im Auftrag verlangt gezeigt): `bilder/horizont_koehlbrand_km78_5_hoch.jpg`
und `…_deck.jpg` – hinter dem Wasser (ab 1.000 m bzw. 480 m) zeigt Modern einen schmalen Streifen Wiese, wo Arcade
eine graue Uferwand und dahinter Land zeichnet. Es liest sich als fernes Ufer, nicht als Fehler; ein Fernwasser habe ich
nicht begonnen (für die Nächsten 1).

### 4.2 (b) Elbbrücken und (c) drei weitere tiefe Querungen

| Stelle | Bilder | angesehen |
|---|---|---|
| **Elbbrücken** km 84,3–84,9 (Wasser 3,6 m, „Hoch“) | `elb_tag_high_0[0-2]_…` | **unverändert: Modern vorher und nachher bitgleich** (alle drei Bilder MD5-gleich, z. B. `cdeb2b3c…`, gemessen) – das Wasser lag dort schon 0,4 m über der alten Scheibe, und die neue Regel ergibt genau die alte Höhe; Wasser beidseits wie Arcade, Fachwerkportale voraus |
| **Holtenauer Hochbrücke** (rostock_kiel, km 200,0–201,0; Nord-Ostsee-Kanal, 16 m) | `holtenau_0[0-3]_…` | **vorher**: olivbrauner Boden (Fernboden) statt des Kanals, die Fähre rechts stand darauf; **nachher**: Wasser beidseits bis zum Horizont, die Fähre schwimmt. Arcade zeigt hinter der Brücke links schon grünes Ufer, Modern Wasser bis zum Horizont – Arcade zeichnet das Land der Reihen hinter der Brücke anders (Zeilenbänder), kein Fehler dieser Behebung |
| **Severinsbrücke** (frankfurt_koeln, Köln, km 185,9–186,9; Rhein, 5 m) | `severin_0[0-3]_…` | **vorher**: grauer Stadtboden statt des Rheins; **nachher**: der Rhein beidseits wie Arcade, Dom und Pylon mit Seilfächer darüber |
| **Elisabethbrücke** (budapest_wien ab Wien, km 241,1–242,1; Donau, 5 m) | `elisabeth_0[0-3]_…` | **vorher**: graubrauner Boden statt der Donau; **nachher**: die Donau beidseits wie Arcade |
| Gegenprobe **Ponte della Libertà** (mailand_venedig, Lagune, 1,4 m – nicht betroffen) | `venedig_ab_0[0-3].jpg` | Lagune wie Arcade (türkis) bis zum Horizont, unverändert: die alte Scheibe lag 2,6 m unter dem Wasser, die neue liegt genau dort (Abschnitt 2) |

### 4.3 (d) Änderungsmelder: nur das Bild, das tiefes Wasser sieht

`tools/golden.sh modern-make` auf `5f70201` (944 s, gemessen; Skript `m1/FIX-WASSER/golden_make.sh`, Log
`golden_make.log`, Bilder `golden_make_keep/`), Liste committet in `0ad9012`:

| Bild | alt (`3a23cb8`) | neu (FIX-WASSER) |
|---|---|---|
| `modern_start_mittel_00.png` (km 0) | `3978bb555626e1539e5c70f40d5e187f` | gleich |
| `modern_s2_mittel_00.png` (km 13,6) | `fec5e0a9bb2862b179b71ab242a1cc00` | gleich |
| `modern_s3_hoch_00.png` (km 60) | `3ca0da4f93ad810fa1ad02b32cceb2a2` | gleich |
| `modern_s4_mittel_00.png` (km 80 → 80,6, Ende der Köhlbrandbrücke) | `a55e8fa3d930ef1fae8060aff13f0ac6` | **`3b8f9601cc44e5bbef74fe833a9d0e1c`** |
| `modern_s5_niedrig_00.png` (km 94) | `7a1d9df85130bebebfbaeed6f2f13e3a` | gleich |
| `modern_s1_nacht_00.png` (km 2, 22 Uhr) | `155d02ce51a0b68f45690c16398d7214` | gleich |

Genau wie erwartet ändert sich nur `modern_s4_mittel`: das einzige Bild, dessen Fenster tiefes Wasser enthält (die
Kamera steht 3 s nach dem Start bei km 80,6 am Ende der Brücke, das Fenster reicht 246 m zurück).
Angesehen (`bilder/golden_modern_s4_vorher_nachher.jpg`; das alte Bild mit dem `far_ground.gd` von `3a23cb8` neu
gezeichnet – MD5 `a55e8fa3…` = die alte Liste, also genau der alte Stand): **393 Pixel (0,043 %) verschieden, alle in den
Zeilen 328–342, also am Horizont**, größte Abweichung 37/255, nur 66 Pixel über 8/255. Dort ist die Fernboden-Scheibe zu
sehen, die hier 5,3 m tiefer liegt, weil das Fenster die Brücke hinter der Kamera noch enthält. Die Elbe selbst ist in
S4 **nicht** im Bild (die Kamera schaut von der Brücke weg); sonst ist das Bild gleich.

### 4.4 Wo die tiefere Scheibe zu sehen ist (Lücken, „Grube“)

`--gfx-debug=cover,far` an der Köhlbrandbrücke mit der Steam-Deck-Stufe (Band 480 m, dort ist am meisten Fernboden zu
sehen; 1280 × 800), gemessen in den vier Modern-Bildern (`m1/FIX-WASSER/shots/kb_cover_deck_modern_0*.png`): unter der
Horizontzeile (y = 359) **0,000 % Magenta** (kein Loch), Fernboden (cyan) 0,26–0,32 %, Kragen (gelb) 0,43–0,61 % – beide
nur in den Zeilen 364–371, also ein Streifen von höchstens 12 Zeilen am Horizont. Neben der Brücke gibt es keine
Mittelachsen-Lücke und kein Kurvenloch (Abschnitt 2: schmalstes Band 424 m an der Elbe). Bei Tag liest sich dieser
Streifen als fernes Ufer (Wiese), nachts ist er so dunkel wie das Land daneben – keine Grube, kein heller oder schwarzer
Saum (Bilder `kb_nacht_*`).

## 5. Testbuild

`OUT=<scratch>/v080/m1/FIX-WASSER/testbuild tools/build_testbuild.sh 0.8.0-zs1 ZS1 crossing-europe-zwischenstand`
(Skript `m1/FIX-WASSER/build.sh`; Export-Vorlagen in das eigene `XDG_DATA_HOME` verlinkt) aus dem **Schluss-Commit
`0ad9012`** (sauber, gepusht): Exit 0, 187 s (gemessen); danach `project.godot` wieder 0.7.0, `git status` leer.
Version „0.8.0-zs1“, Windows-Version 0.8.0.1, Nutzerordner `crossing-europe-zwischenstand` – wie der Build von FIX-ZS1,
nur aus dem neuen Commit.

| Datei | Größe (gemessen) | SHA-256 |
|---|---|---|
| `CrossingEurope-ZS1-linux-x86_64.tar.gz` (`CrossingEurope-ZS1.x86_64` 440,7 MB + `LIZENZEN.txt`) | 146 920 929 B (140 MiB) | `7f7d8c2f…9e2f` |
| `CrossingEurope-ZS1-windows-x86_64.zip` (`CrossingEurope-ZS1.exe` 476,5 MB + `LIZENZEN.txt`) | 156 566 135 B (149 MiB) | `1ed2728a…ab09` |

Beide unter 400 MiB und unter dem Größentor von `pck_report.py` (Archiv geschätzt 146,8 MB, Grenzen 300/330/350 MB).
Geliefert nach `deliver/FIX-WASSER/build/`: beide Archive, `LIZENZEN.txt`, `SHA256SUMS`, `BUILDINFO.txt`; dort
`sha256sum -c --ignore-missing SHA256SUMS` → alle drei gelieferten Dateien **OK** (`SHA256SUMS` nennt auch die nackten
Programme, die – wie bei gate1 und FIX-ZS1 – nicht mitgeliefert werden). Die Builds in `deliver/gate1/build/` und
`deliver/FIX-ZS1/build/` sind unberührt.

## 6. Rauchtests und Bilder aus den Exporten

Alles mit den **exportierten** Programmen aus `0ad9012` (Skripte `m1/FIX-WASSER/smokes.sh`, `export_shots.sh`,
`chooser_walk.sh`; Logs `smokes.log`, `smoke/`). Die Exporte laufen ohne `--gfx-sync` in Echtzeit: der Wächter senkt
Modern auf der Software-Grafik nach dem Start auf „Niedrig“ (richtig so, Hinweis im Bild).

| Prüfung | Ergebnis (gemessen) |
|---|---|
| **Köhlbrandbrücke aus dem Linux-Export** (Xvfb, OpenGL 4.5, `-- --stage=kiel_hamburg … --start-km=78.6 --start-speed=60 --gfx-preset=high`, Bilder 0,3 s und 1,5 s – HUD km 78,7 / 78,9) | **Die Elbe liegt unter und neben der Brücke wie in Arcade** – `bilder/export_linux_koehlbrand_km78_7.jpg`, `…_km78_9.jpg`. Das Auto steht hier 19–21 px rechts von Arcades Stelle (Kurvenkamera: die Straße biegt hinter der Brücke ab, D12; kein Wasserthema) |
| **Köhlbrandbrücke aus dem Windows-Export unter Wine** (wine64, eigenes Präfix, `TMPDIR` leer, Pfade `Z:…`, `wineserver -w` zwischen den Läufen) | ebenso: Elbe unter und neben der Brücke – `bilder/export_windows_wine_koehlbrand_km78_*.jpg` |
| **Start aus dem Linux-Export** (`--gfx-preset=medium`, Bilder 1 s im Countdown und 1,5 s nach „LOS!“) | Auto an Arcades Stelle: Lackfläche-Kanten links/rechts/oben/unten +0,0/+0,5/+0,0/+0,0 % (Countdown) und +0,0/+0,5/+0,0/+0,5 % (1,5 s nach LOS; `paintbox.py`); Starttor, Startlinie, Schild „Tankstelle 15 km“ wie Arcade – `bilder/export_linux_start_*.jpg` |
| **Start aus dem Windows-Export unter Wine** | ebenso, dieselben Kanten (≤ 0,5 %) – `bilder/export_windows_wine_start_*.jpg` |
| `tools/smoke_modern.sh` Linux | **SMOKE linux: OK** – Arcade 20 s, Modern 159 s, Leistungstest „autobahn“ 5,1 Bilder/s (Last der VM), Version 0.8.0-zs1, Nutzerordner `…/crossing-europe-zwischenstand` (leistungstest.json, logs, shader_cache) |
| `DRIVER=opengl3_es tools/smoke_modern.sh` Linux | **SMOKE linux_opengl3_es: OK** – OpenGL ES 3.2, Arcade 22 s, Modern 164 s, Leistungstest 4,2 Bilder/s |
| `tools/smoke_modern.sh` Windows unter wine64 | **SMOKE windows: OK** – wineboot 9 s, Arcade 27 s, Modern 143 s, Leistungstest 4,8 Bilder/s; Nutzerordner `drive_c/users/root/AppData/Roaming/crossing-europe-zwischenstand` |
| **Erster Start wie ein Spieler** (Linux-Export ohne Argumente, 1280 × 800 wie Steam Deck, Tastatur über xdotool) | „GRAFIK WÄHLEN“ (Arcade empfohlen – Software-Grafik) → ▶ Modern → Titel mit **v0.8.0-zs1** → Rennen starten → Limousine → 08:00 → Etappe 1 → Ladebild → Countdown **mit Auto an seinem Platz** (16:10 füllt, Straße bis zum unteren Rand) → „LOS!“ → Pause. `settings.json` mit `graphics_mode: "modern"`, `savegame.json` geschrieben – `bilder/erststart_linux_*.jpg` |

Bildraten der Software-Grafik sagen über echte Grafikchips nichts (Last 6–10 durch parallele Pakete). ANGLE/Direct3D,
echte Grafikkarten und der Steam Deck selbst sind hier nicht prüfbar (abgeleitet: derselbe Code wie unter OpenGL und
OpenGL ES).

## 7. Nutzerdokumente

`was_neu.md` und `steamdeck_checkliste.md` aus `deliver/FIX-ZS1/` kopiert nach `deliver/FIX-WASSER/`. Entfernt, nachdem
die Elbe in beiden Exporten zu sehen war: in `was_neu.md` der Satz „Unter der Köhlbrandbrücke zeigt Modern noch Wiese
statt der Elbe – die beiden Schiffe dort stehen deshalb auf der Wiese (an den Elbbrücken kurz danach stimmt das
Wasser).“ Sonst nichts geändert; die Checkliste ist unverändert (ihr einziger Satz zur Köhlbrandbrücke – dort auf
Ruckler achten – stimmt weiter).

## 8. Tore auf dem Schluss-Commit `0ad9012`

Alle Tore nacheinander mit `m1/FIX-WASSER/gates.sh` (Logs `m1/FIX-WASSER/gates/`, Zusammenfassung
`gates/summary.txt`), Arbeitskopie sauber; derselbe Commit, aus dem der Testbuild stammt.

| Tor | Aufruf | Ergebnis (gemessen) |
|---|---|---|
| Import | `godot --headless --path . --import` | sauber, Exit 0, 0 Fehlerzeilen (6 s) |
| Skripte | `godot --headless --path . -s res://tests/check_scripts.gd` | **307 Skripte geprüft, 0 fehlerhaft** (306 + der neue Test) |
| Kopflose Tests | `tools/run_tests.sh` (einmal, voll) | **„Tests bestanden“, Exit 0, 914 s**: Unit-Tests **703/0** (FIX-ZS1: 699 + 4 neue), 146 CHECK-Zeilen, 0 FEHLER; Fairness unverändert: F1 0 Fälle bis 270 m (10 296 510 Stichproben), Außenspuren 0 bis 260 m, F2 ≤ 0,593 / 0,596 / 0,555, F3 0 von 874, F7 0 von 207 166 Querschnittsseiten, Pfad ≥ 267,6 m; `renderer_zeit` 0,788 ms |
| Arcade-Identität | `tools/golden.sh check` | **GOLDEN arcade: 20 von 20 identisch** (193 s), **GOLDEN arcade-ui: 17 von 17 identisch** (241 s), Exit 0 |
| Modern-Änderungsmelder | `tools/golden.sh modern-make` (auf `5f70201`, Liste in `0ad9012`) + `tools/golden.sh modern-check` | make: nur `modern_s4_mittel` neu (Abschnitt 4.3); check: **GOLDEN modern: 6 von 6 identisch** (808 s); **OpenGL ES** `modern_s3_hoch` gegen OpenGL: OK, max. 2/255, PSNR 73,2 dB (179 s) |
| Render-Prüfungen | `tools/run_render_checks.sh all` | **18 von 18 Render-Prüfdateien in Ordnung**, Exit 0 (1.714 s, 07:10–07:39 UTC): u. a. **`check_terrain_cover`** OK – an T1, T2, T3, T4, S1, C1 je 0,000 % Magenta unter dem Horizont, Fernboden/Kragen wie vorher (T1 2,80 % + 2,52 %, T4 0,27 % + 1,67 %, C1 1,62 % + 0,16 %, sonst 0 %); **`check_start_km0`** OK (Kamera ≤ 1,14 px, Auto-Kanten ≤ 2 px, Boden 0,032); `check_modern_render` (Helligkeit), `check_light_base` (Schatten), `check_road_parity`, `check_occlusion`, `check_seam_render`, `check_vehicle_lights`, `check_vehicle_standin` – alle OK |

Zusammenfassung der Tore: `m1/FIX-WASSER/gates/summary.txt` (06:31–07:39 UTC). Arbeitskopie danach sauber.

## 9. Bild gegen Arcade (ehrlich)

Ehrlich gegen Arcade im selben Simulationszustand (alle Bilder angesehen):

- **Köhlbrandbrücke – vorher deutlich schlechter, jetzt gleichwertig bis etwas besser.** Vorher zeigte Modern grüne
  Wiese bis zum Horizont und die Fähren darauf. Jetzt liegt die Elbe in Arcades Ausdehnung unter und neben der Brücke,
  die Fähren schwimmen; dazu zeigt Modern die Brücke als Körper (Pylone, Seilfächer, Geländer, Schatten), was Arcade
  nur als flache Bilder hat. **Nicht deutlich besser**, weil: (1) hinter dem Fluss fehlt Arcades graue Uferwand – Modern
  zeigt dort einen Streifen Wiese (Fernboden jenseits des Wasserbands); (2) das Wasser ist eine glatte, zum Horizont den
  Himmel spiegelnde Fläche ohne Wellen und Glanz – Arcade ist ebenso flach, aber satter blau; (3) nachts leuchten die
  Pylone fast weiß (kein Wasserthema).
- **Steam-Deck-Stufe (1280 × 800)**: wie „Hoch“, das Wasserband reicht 480 m, der Wiesenstreifen am Horizont ist etwas
  breiter.
- **Elbbrücken**: unverändert (vorher und nachher bitgleich); gleichwertig – Arcade zeigt die seitlichen Fachwerkträger, Modern nur
  Geländer und die Portale.
- **Holtenau, Köln, Budapest**: vorher brauner bzw. grauer Boden (der Fernboden in der Farbe des Stadtrands) statt des
  Flusses, jetzt Wasser wie Arcade – **vorher deutlich schlechter, jetzt gleichwertig**; an der Holtenauer Hochbrücke
  zeigt Arcade hinter der Brücke links schon Land, Modern bis zum Horizont Wasser (Arcade zeichnet das Land der Reihen
  hinter der Brücke anders – kein Fehler dieser Behebung).
- **Venedig** (Gegenprobe): unverändert, Lagune wie Arcade.

## 10. Abweichungen, Vertragsfragen, für die Nächsten

**Abweichungen vom Auftrag**

1. **Kamera im Unit-Test**: Der Test hängt die Ebene an einen Stellvertreter der Renderer-Fassade mit einem
   `Camera3D` außerhalb des Szenenbaums (A-1 sagt „keine `Camera3D` in Unit-Tests“). Die Ebene liest davon nur
   `position`; headless gemessen 3 s, keine Fehlermeldung. So prüft der Test das echte `update()` (Gleiten, Sprung) und
   scheitert auf `3a23cb8` an einer echten Zusicherung statt an einer fehlenden Methode.
2. **(c) Damm in der Lagune**: Der Ponte della Libertà (Venedig) hat 1,4 m Wasser, liegt also über der alten Scheibe und
   ist nicht betroffen – er steht als unveränderte Gegenprobe im Bericht (ohne „vorher“-Bild); die drei tiefen Querungen
   sind Holtenauer Hochbrücke (Nord-Ostsee-Kanal), Severinsbrücke (Rhein) und Elisabethbrücke (Donau).
3. **Reihenfolge**: Testbuild und Rauchtests liefen vor den Toren (kritischer Pfad), die Tore danach auf **demselben**
   Commit `0ad9012`; die Vorher-Bilder und (b)/(c) entstanden nach den Toren.
4. **Steam-Deck-Bilder** in 1280 × 800 (`SCREEN=1280x800`, Modern füllt 16:10, Arcade mit Balken), Stufe `deck`.
5. Der Betreff von `0ad9012` sagt „S4 sieht die Elbe“ – in S4 ist die Elbe aber nicht im Bild (die Kamera
   schaut vom Brückenende weg), es ändern sich nur 393 Pixel am Horizont (4.3). Der Text der Commit-Nachricht ist darin
   ungenau; ein gepushter Commit wird nicht umgeschrieben (kein Force-Push) – richtig steht es in `docs/qa-v080.md` §10.

**Vertragsfragen (contract_issues)**

1. **D16 und A-3** beschreiben die Fernboden-Scheibe als „tiefste Straße des geladenen Fensters − 4,0 m“; unter Brücken
   über Wasser tiefer als 4 m deckt genau diese Regel den Fluss zu (7 Brücken, 15 Etappenrichtungen, Abschnitt 2).
   Umgesetzt: min(…, tiefstes Wasser des Fensters − 0,3 m). Der Vertrag sollte D16/A-3 so nachtragen (FIX-ZS1 hat das
   als Vertragsfrage 3 schon gemeldet).
2. **Fernwasser hat keinen Besitzer**: Das Wasser einer Brücke reicht nur so weit wie das Geländeband (480 m,
   „Hoch“ 1.000 m); Arcade zeigt den Fluss als Band über das ganze Bild und am Horizont ein graues Ufer. §4.5.5 gibt
   die „water plane“ dem Brücken-Builder (R5) – der Vertrag sollte festlegen, dass sie (oder der Fernboden) bis zum
   Horizont reicht und wer das ferne Ufer baut.

**Für die Nächsten (notes_for_next)**

1. **Fernwasser und fernes Ufer** (R5/R2): am Horizont hinter der Elbe ein Streifen Wiese statt Arcades grauer
   Uferwand (`bilder/horizont_koehlbrand_km78_5_*.jpg`).
2. **Pylone nachts grell weiß**: An der Köhlbrandbrücke um 22 Uhr leuchten die Pylone in Modern fast weiß
   (`bilder/kb_nacht_*`), Arcade zeigt sie dunkelgrau – kein Wasserthema, Besitzer Brücke/Licht (R4/R5).
3. `tests/race3d/check_terrain_plan.gd -- --dump` schreibt `far_y` noch mit der alten Regel (nur die Draufsicht-Daten,
   keine Prüfung) – beim Kern-Besitzer nachziehen.
4. **M2INT**: `scripts/race3d/layers/far_ground.gd`, `tests/unit/race3d/test_far_ground_water.gd` (+ `.uid`),
   `tests/golden/modern_slice.*` (nur S4 neu) und die drei Doku-Dateien übernehmen; danach
   `tools/run_tests.sh test_far_ground_water` und `tools/golden.sh modern-check`.
5. Eine Render-Prüfung an einer tiefen Brücke (S4 oder B1 mit `--gfx-debug=cover,far`) würde einen Rückfall bewachen
   – die Positionen von `check_terrain_cover` haben kein Wasser.
6. **Holtenau**: dort liegt die Scheibe 15 km lang 12,3 m tiefer (kiel_hamburg ab Hamburg, rostock_kiel) – mit den
   Bildern von Zwischenstand 2 auf der ganzen Anfahrt ansehen (hier nur an der Brücke geprüft).

## 11. Dateien

- Spielcode: `scripts/race3d/layers/far_ground.gd` (einzige Spieldatei); Test `tests/unit/race3d/test_far_ground_water.gd`
  (+ `.uid`); `tests/golden/modern_slice.md5` / `.env`; Doku `docs/renderer-modern-gelaende.md`, `docs/renderer-modern.md`,
  `docs/qa-v080.md`. Commits `5f70201` (Behebung + Test), `0ad9012` (Änderungsmelder + Doku), beide gepusht nach
  `origin/wip/v080-fix-wasser`.
- Arbeitsdateien: `<scratch>/v080/m1/FIX-WASSER/` (`STAND.md`; Skripte `scan_bridges.gd`, `scan_gaps.gd`,
  `ut_on_base.sh`, `ab_one.sh`, `modern_only.sh`, `queue2.sh` … `queue6.sh`, `after_queue.sh`, `before_queue.sh`,
  `triptych.sh`, `golden_make.sh`, `gates.sh`, `build.sh`, `smokes.sh`, `export_shots.sh`, `chooser_walk.sh`,
  `paintbox.py`; Logs und Bilder `shots/`, `before/`, `gates/`, `smoke/`).
- Lieferung: `<scratch>/v080/deliver/FIX-WASSER/` – `bericht.md`, `bilder/` (50 Bilder: Dreierbilder Arcade |
  vorher | nachher, Horizont-Ausschnitte, Fernboden-Debug, S4 alt/neu, Export- und Erststart-Bilder), `build/`,
  `was_neu.md`, `steamdeck_checkliste.md`.
- Aufgeräumt: die nackten Programme in `m1/FIX-WASSER/testbuild/` (die Archive liegen in `build/`), das Wine-Präfix, die
  Mesa-Caches und Daten-Ordner der Läufe (≈ 2 GB).
