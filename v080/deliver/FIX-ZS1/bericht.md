# FIX-ZS1 – Startfehler und Starttor-Schatten behoben, Testbuild Zwischenstand 1 neu gebaut

Für die Leitung. Paket FIX-ZS1 auf der Basis `92ece73` (QA1, `origin/wip/v080-qa1`). Branch
`worktree-wf_9559b070-4dd-1`, Sicherung `origin/wip/v080-fix-zs1`, Worktree
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9559b070-4dd-1`. Kein Vorgänger gefunden (keine
`STAND.md`, kein Remote-Branch) – frisch begonnen um 02:47 UTC.
„gemessen“ = auf dieser VM (Mesa llvmpipe unter Xvfb, 4 geteilte Kerne); alles über Steam Deck, echte Grafikkarten,
ANGLE/Direct3D und Klang ist **abgeleitet**.

## Urteil

**Der Startfehler ist behoben und im exportierten Linux- und Windows-Build gesehen; der Testbuild kann raus.**

- **QA1-B1** (hoch) an der Wurzel behoben: der Pfad führt die Straße vor der Startlinie gerade weiter, der Streamer baut
  dort ein Stück Straße, die Fahrzeugebene zeichnet das Auto mit dem Heck vor z = 0. Im Countdown und nach „LOS!“ steht
  das Spielerauto an Arcades Stelle in Arcades Größe – gemessen an der Lackfläche: Kanten ≤ 1 % bis 1,5 s nach „LOS!“
  in allen Tagesstarts, **≤ 0,5 % im Linux- und im Windows-Export**; Starttor, Startlinie und das Schild „Tankstelle
  15 km“ wie Arcade; die Kamera gleitet ohne Sprung. Drei weitere Starts (Ljubljana mit Gefälle, Köln, Pau nachts) ebenso.
- Bei km > 0 hat sich **kein** Modern-Bild geändert (`modern-make`: nur `modern_start_mittel` neu, 5 von 6 MD5-gleich);
  Arcade bleibt bildgleich (20/20, 17/17); Fairness unverändert.
- **QA1-B3** behoben (eine Zeile): die Lampenringe des Starttors werfen bei „Schatten: Aus“ nicht mehr;
  `check_light_base` grün, **alle 18 Render-Prüfdateien grün** (QA1: 16 von 17).
- Neue Render-Prüfung **„Start bei km 0“** (rot auf `92ece73`, grün jetzt) und 6 Unit-Tests.
- **CHECK 3**: Ja – unter der Köhlbrandbrücke stehen die Fähren in Modern auf der Wiese, weil Modern dort die ganze Elbe
  als Wiese zeichnet (Fernboden-Scheibe 4 m unter der Straße deckt 9 m tiefes Wasser zu). **Nicht behoben** (nicht klein
  und sicher, ändert S4, gehört R2/R5) – gemeldet, im `was_neu.md` mit einem Satz erwähnt.
- **Bild**: Der Start sieht jetzt aus wie in Arcade – gleichwertig, nicht deutlich besser (besseres Gelände, echte
  Schatten, Starttor als Körper; dafür fehlt links die große Eiche, und die Limousine weicht vom Sprite ab).
- Testbuild **v0.8.0-zs1** aus dem Schluss-Commit `3a23cb8`; Rauchtests Linux, OpenGL ES und Windows unter Wine grün,
  Erststart wie ein Spieler (1280 × 800) grün.

## 1. FIX 1 – QA1-B1: Start bei km 0

### 1.1 Ursache und Behebung

Beim stehenden Start steht das Auto bei `pos_z = 0` (Mitte; Heck −2,4 m), die Kamera bei `camera_z = −9 m`.
`RoadPath3D` kannte nur z ≥ 0 und klemmte alles davor auf Grenze 0 – die Kamera stand 9 m zu weit vorn, und
`layers/vehicles.gd` blendete das Spielerauto aus (Heck vor `z_lo = first · 3 m = 0`).

Behebung an der Wurzel, kleinster richtiger Eingriff (fünf Spieldateien, alle in meinem Besitz für diesen Fix):

| Datei | Änderung |
|---|---|
| `scripts/race3d/road_path.gd` | **Vorlauf**: solange der Pfad am Streckenanfang beginnt (`first == 0`, neu `has_lead_in()`), liegen Straßenpositionen z < 0 und Grenzen k < 0 auf der geraden Fortsetzung von Grenze 0 entlang ihrer Tangente, auf ihrer Höhe, mit ihrer Richtung: `point()`, `centre_at()`, `world()`, `frame_at()`, `rows_local()`. Neu `z_min()` = −∞ mit Vorlauf, sonst erste Grenze. Für z ≥ 0 und nach `trim()` (first > 0) ändert sich nichts (Unit-Test: bitgleich). |
| `scripts/race3d/chunk_streamer.gd` | **Stück −1** (Reihen −32 … 0, 96 m) ist das niedrigste Stück, solange der Pfad den Vorlauf hat; dieselbe Lade- und Freigaberegel wie jedes Stück (frei, sobald die Kamera 150 m gefahren ist). |
| `scripts/race3d/chunk_context.gd` | Reihen k < 0 tragen die Daten von Segment 0 mit eigenem Index und eigener Straßenposition, **ohne Requisiten und Schilder** (`lead_in_snapshot()`) – Straße, Markierung, Bankett, Leitplanken und Gelände entstehen in jedem Builder wie sonst, nichts der Etappe steht doppelt (kein zweites Starttor). |
| `scripts/race3d/layers/vehicles.gd` | `z_lo = path.z_min()`; die Regel, welche Autos gezeichnet werden, als `static func in_range()` (für den Unit-Test), inhaltlich unverändert. |

Warum gerade entlang der Tangente: jede Etappe beginnt gerade und eben (`Track._calm`: keine Kurve vor 40 m, keine
Steigung vor 30 m; im ganzen Netz gemessen: Blick-in-die-Kurve der Countdown-Kamera ≤ 0,07°), und Arcade zeichnet die
Straße hinter der Startlinie mit Kurve und Höhe von Segment 0 – also dieselbe Straße. Warum ein volles Stück −1 statt
15 m: so gelten alle Builder-Regeln und die bestehenden Prüfungen („32 Segmente je Stück“ in `check_modern_stage`)
ohne Sonderfall; die Kamera sieht davon nur die letzten Meter (bei 3,4 m Augenhöhe liegt der Boden am unteren Bildrand
6,1 m vor ihr, abgeleitet).

Was den Pfad vor z = 0 liest, geprüft (Code gelesen): Kamera (`ChaseCamera3D.transform/look_yaw` – jetzt auf dem
Vorlauf), Fahrzeugebene (Spieler; Verkehr, den `--traffic-warmup` 30 m und mehr hinter den Spieler setzt – hinter der Kamera,
erst sichtbar, wenn er vorbeifährt), Polizei (kommt später), Sichtprüfungen F1–F3/F7 (`fairness.gd`, `modern_sight.gd`:
Kamerapositionen ab 12 m, unverändert; `wanted_for()` enthält Stück −1 an Kamerapositionen bis 150 m – die
Stück-Statistik von `modern_path_check` und alle Fairness-Prüfungen liefen im Schluss-Tor grün mit QA1s Zahlen), Starttor (Segment 14 m, Stück 0, unverändert, kein zweites), Rebasing (`_rebase` schiebt Stück −1 mit der
Verschiebung, weil `seg_a < first`), Stückbau (`TerrainProfile.rows()` klemmt negative Reihen auf Reihe 0), Licht-Ebene
(`lights.gd` Zeile 379: Scheinwerferkegel des Verkehrs nur für Fronten ≥ `first · 3 m` – im normalen Spiel steht kein
Auto zwischen Kamera und Startlinie; nicht geändert, nicht mein Besitz), Fernboden (`far_ground.gd` beginnt bei Reihe 0
– das Geländeband des Vorlaufs ist vollständig, nichts offen), Umgebungsrig (Richtung 0 = Richtung von Grenze 0).

### 1.2 (a) Kiel – Hamburg bei km 0 gegen Arcade

`tools/ab_shot.sh` mit denselben Argumenten wie QA1 (Limousine, 12 Uhr, Seed 11, Autopilot, `--traffic-warmup`, Modern
„Mittel“), Bildzeiten 1 s und 3 s im Countdown, 0,7 s, 1,5 s und 4 s nach „LOS!“ (3,7 / 4,5 / 7 s); „vorher“ = dieselben
Läufe mit den fünf Spieldateien von `92ece73` (kurz eingesetzt, danach aus HEAD wiederhergestellt).

| Moment | Bild (`bilder/`) | Auto-Box Modern gegen Arcade (Lackfläche, gemessen) |
|---|---|---|
| 1 s im Countdown | `start_km0_00_arcade_vorher_nachher.jpg` | nachher: Kanten +0,0/+0,5/+0,0/+0,0 % – vorher: **kein Auto** |
| 3 s (Ende Countdown) | `start_km0_01_…` | nachher: +0,0/+0,5/−0,5/+0,0 % – vorher: kein Auto |
| 0,7 s nach LOS | `start_km0_02_…` | nachher: +0,0/+0,5/−0,5/+0,5 % – vorher: kein Auto |
| 1,5 s nach LOS | `start_km0_03_…` | nachher: +0,0/+1,0/−0,5/+0,5 % – vorher: **290 × 190 px statt 192 × 192, 30 % zu tief** |
| 4 s nach LOS | `start_km0_04_…` | nachher wie vorher: +3,1/+4,2/−0,5/+0,5 % (die Kurvenkamera schaut 100 m voraus schon in die Linkskurve bei 138 m – an jeder Stelle so, kein Startfehler) |

(Kanten links/rechts/oben/unten in % der Breite bzw. Höhe von Arcades Box; 192 × 192 px bzw. 192 × 238 px, wenn die
Pausen-Einblendung über dem Dach liegt.) Starttor, Startlinie und das Schild „Tankstelle 15 km“ stehen an Arcades Stelle;
die Kamera gleitet ohne Sprung (die Bilder 0,7 / 1,5 / 4 s; Unit-Test „kein Sprung an der Startlinie“: der Pfad ist
dort stetig, gleiche Richtung). Unter der Kamera liegt Straße wie bei Arcade (Render-Prüfung `boden`: 0,031 je Kanal).

### 1.3 (b) Drei weitere Starts

Aus den Daten gewählt (Skript `m1/FIX-ZS1/scan_starts.gd`, alle 128 Etappenrichtungen): **kein Start liegt in einer
Kurve oder in den City Limits** – Kurven beginnen frühestens nach 40 m (Calm-Zone), die City Limits gibt es nur am Ziel.
Gewählt habe ich deshalb die nächsten Fälle:

| Start | Art | Bilder | Auto-Box (gemessen, Countdown … 1,5 s nach LOS) |
|---|---|---|---|
| Venedig – Ljubljana ab **Ljubljana** | stärkstes Gefälle am Start im Netz (−17,1 m auf den ersten 300 m) mit Kurve 0,19 ab 162 m, Waldhügel | `start_ljubljana_gefaelle_*.jpg` | ≤ 0,5 % im Countdown, bei 0,7/1,5 s Breite −1,9/−4,1 % (ein blaues Schild im Messfenster), 4 s −3,1/−2,6 % |
| Köln – Brüssel ab **Köln** | Großstadtrand (Industrie-Landschaft mit Fabriken und Backsteinbauten) | `start_koeln_industrie_*.jpg` | ≤ 1,0 % bis 1,5 s, 4 s +3,6/+4,2 % (Kurvenkamera) |
| Saragossa – Pau ab **Pau, 22 Uhr** | Nacht, Landstraße, schärfste frühe Kurve des Netzes (0,435 bei 162 m) | `start_pau_nacht_22uhr_*.jpg` | Farbmaske nachts nicht messbar; im Bild: Auto, Rücklichter, Starttor an Arcades Stelle |

Angesehen: in allen drei Fällen steht das Auto im Countdown und nach dem Losfahren an Arcades Stelle in Arcades Größe,
das Starttor ebenso; die Straße läuft bis zum unteren Bildrand weiter.

### 1.4 (c) Modern-Bilder bei km > 0 unverändert

`tools/golden.sh modern-make` auf `0906efc` (716 s, gemessen; Liste committet in `634e28b`):

| Bild | alt (`92ece73`) | neu (FIX-ZS1) |
|---|---|---|
| `modern_start_mittel_00.png` (km 0, Countdown 2,2 s) | `0a7600ecd7d4002a39172b8055f2d9bd` | **`3978bb555626e1539e5c70f40d5e187f`** – gewollt: Auto im Countdown, Kamera 9 m zurück |
| `modern_s2_mittel_00.png` | `fec5e0a9bb2862b179b71ab242a1cc00` | gleich |
| `modern_s3_hoch_00.png` | `3ca0da4f93ad810fa1ad02b32cceb2a2` | gleich |
| `modern_s4_mittel_00.png` | `a55e8fa3d930ef1fae8060aff13f0ac6` | gleich |
| `modern_s5_niedrig_00.png` | `7a1d9df85130bebebfbaeed6f2f13e3a` | gleich |
| `modern_s1_nacht_00.png` | `155d02ce51a0b68f45690c16398d7214` | gleich |

Nur `modern_start_mittel` hat sich geändert (angesehen: Auto, Starttor, Schild wie Arcade). `modern-check` auf dem
Schluss-Commit: Abschnitt 6.

### 1.5 (d) Render-Prüfung „Start bei km 0“ und Unit-Tests

`tests/race3d/render/check_start_km0.gd` (läuft in `tools/run_render_checks.sh modern` von selbst mit – das Skript
nimmt jede Datei `tests/race3d/render/check_*.gd`): Kiel – Hamburg ab km 0 mit Countdown in Arcade und Modern („Mittel“,
ohne Verkehr, ohne HUD), gleiche Simulationsschritte, 1 s im Countdown und 1,5 s nach „LOS!“.

| Prüfung | mit der Behebung (gemessen) | auf `92ece73` (fünf Spieldateien zurückgesetzt, gemessen) |
|---|---|---|
| `kamera` (Straßenmitte 0/14/30/60 m, wo im Bild, ≤ 1,5 px neben Arcades Projektion) | **OK**, höchstens 1,14 px | **FEHLER**: Startlinie 99,9 px, 30 m 27,1 px, 60 m 7,3 px neben Arcade |
| `auto` (Lackfläche, jede Kante ≤ 5 %) | **OK**: Kanten ≤ 2 px (192 × 192 px) | **FEHLER**: im Countdown kein Auto; 1,5 s nach LOS 290 × 186 px, 63 px zu tief |
| `boden` (unterste 50 Zeilen neben dem Auto ≤ 0,08 je Kanal) | **OK**, 0,031 | OK (der Boden war auch vorher da – die Kamera stand nur weiter vorn) |

Unit-Tests `tests/unit/race3d/test_start_lead_in.gd` (6/6 grün): Vorlauf = Tangente von Grenze 0 auch auf einer Strecke,
die mit einer Kurve und Steigung beginnt; Reihen des Vorlaufs; z ≥ 0 bitgleich, späterer bzw. gekürzter Pfad geklemmt
wie vorher; **Auto mit Heck vor `z_lo`** (Spielerauto im Countdown gezeigt, mit der alten Grenze nicht; Grenzen 14 m
hinter der Kamera und Sicht + 30 m unverändert); Stück −1 im Streamer (geladen mit der Startansicht, Reihen −32 … 0 auf dem
Vorlauf, keine Requisiten doppelt, frei nach 150 m, nicht bei einem Start mitten in der Etappe); `lead_in_snapshot()`.
Alle 110 Unit-Tests von `tests/unit/race3d` grün.

## 2. FIX 2 – QA1-B3: Schatten der Lampenringe

`builders/gantry.gd`: `rim.cast_shadow = mi.cast_shadow` – die drei Ringe werfen nur, wenn Pfosten und Banner werfen
(`shadow_casters ≥ 1`). Die übrigen `MeshInstance3D`/`MultiMeshInstance3D`/`Label3D` der Builder folgen der Stufe schon
oder sind aus; nur die **Aufwärmknoten** von `signs.gd` und `tunnel.gd` werfen (Standard) – mit Absicht nicht geändert:
sie stehen nur hinter dem Ladebild und übersetzen dabei auch die Schattenvariante des Shaders.
Prüfung im Schluss-Tor (`tools/run_render_checks.sh all`, darin `check_light_base.gd`, gemessen): **`schatten` OK** – „S1
12 Uhr, beleuchtete Flächen (94,1 % des Bodens): Mittel 0,4283, Aus 0,4287 (−0,10 %) … Schattenlicht in beiden Stufen an“;
mit „Aus“ wirft kein Knoten mehr Schatten (bei QA1: 3 Knoten, die Ringe). `tageslicht` OK. Datei OK, 99 s.

## 3. CHECK 3 – Schiffe auf dem Trockenen

Daten (Skript `m1/FIX-ZS1/scan_boats.gd`): auf Kiel – Hamburg stehen drei Fähren – km 78,95 (62 m links) und km 79,14
(101 m rechts) an der Köhlbrandbrücke (Wassertiefe 9 m), km 84,62 (70 m rechts) an den Elbbrücken (3,6 m). Alle drei
stehen laut Geländeprofil auf Wasserreihen auf Wasserhöhe (`h = −depth` = Boden des Profils).

Bilder (`bilder/boote_*.jpg`, Modern „Hoch“): **An der Köhlbrandbrücke zeichnet Modern Wiese statt der Elbe** – Arcade
zeigt beidseits Wasser, Modern grünes Land bis zum Horizont; die beiden Fähren stehen dort sichtbar auf der Wiese. An
den Elbbrücken stimmt das Wasser, die Fähre bei km 84,6 schwimmt.

Ursache (Code und Konfiguration gelesen, durch die beiden Brücken bestätigt): Die Fernboden-Scheibe
(`layers/far_ground.gd`) liegt `far_ground_drop_m` = 4,0 m unter der tiefsten geladenen Straße; das Wasser liegt
`water_depth` unter der Straße – bei 9 m also 5 m **unter** der grünen Scheibe, die es zudeckt; bei 3,6 m darüber.
**Nicht behoben**: Die Behebung gehört an den Fernboden (R2) bzw. die Wasserfläche des Brücken-Builders (R5) und ändert
die Bilder an der Brücke und den Änderungsmelder `modern_s4_mittel` (Fenster reicht 150 m zurück auf die Brücke) –
Abnahme (c) erlaubt das nicht, und klein und sicher ist sie nicht. Vorschlag: die Scheibe unter das tiefste Wasser der
geladenen Reihen legen (oder über tiefem Wasser aussparen). Befund steht in `docs/qa-v080.md` §9 (FIX-ZS1-B1) und als
ein Satz in `was_neu.md`.

## 4. Testbuild

`OUT=<scratch>/v080/m1/FIX-ZS1/testbuild tools/build_testbuild.sh 0.8.0-zs1 ZS1 crossing-europe-zwischenstand`
(Skript `m1/FIX-ZS1/build.sh`). Erst aus `634e28b` (171 s, damit liefen alle Export-Prüfungen von Abschnitt 5), nach der
Doku-Korrektur noch einmal aus dem **Schluss-Commit `3a23cb8`** (sauber, gepusht; 172 s, gemessen) – **geliefert ist der
Build aus `3a23cb8`**. Die nackten Programme beider Builds sind **bitgleich** (SHA-256 `bc147ee4…b8` Linux, `f6e2b703…92`
Windows), nur Dateizeiten und `BUILDINFO.txt` in den Archiven unterscheiden sich; auf dem Build aus `3a23cb8` liefen die
Starts aus dem Export und die Rauchtests Linux und Windows noch einmal (Abschnitt 5). Die Export-Vorlagen liegen unter
`~/.local/share/godot/export_templates`; weil jeder Lauf ein eigenes `XDG_DATA_HOME` hat, habe ich sie dort hinein
verlinkt (der erste Versuch scheiterte daran, das Skript setzte die Projektdateien sauber zurück). Nach jedem Build:
`project.godot` wieder 0.7.0, `git status` leer.

| Datei (aus `3a23cb8`) | Größe (gemessen) | SHA-256 |
|---|---|---|
| `CrossingEurope-ZS1-linux-x86_64.tar.gz` (`CrossingEurope-ZS1.x86_64` 440,7 MB + `LIZENZEN.txt`) | 146 919 755 B (140 MiB) | `97e128d5…f5ce` |
| `CrossingEurope-ZS1-windows-x86_64.zip` (`CrossingEurope-ZS1.exe` 476,5 MB + `LIZENZEN.txt`) | 156 564 758 B (149 MiB) | `52b484fb…02fe` |

Beide unter 400 MiB und unter dem Größentor von `pck_report.py` (Warnung 300, Abbruch 330 MB; Windows gemessen 156,6 MB);
Version „0.8.0-zs1“, Windows-Version 0.8.0.1, Nutzerordner `crossing-europe-zwischenstand` – wie QA1s Build, nur aus dem
neuen Commit (Archive 1 291 bzw. 1 650 Byte größer als die von `10d836f`). Geliefert nach `deliver/FIX-ZS1/build/`:
beide Archive, `LIZENZEN.txt`, `SHA256SUMS`, `BUILDINFO.txt`; dort `sha256sum -c --ignore-missing SHA256SUMS` → alle drei
gelieferten Dateien OK (`SHA256SUMS` nennt auch die beiden nackten Programme, die – wie bei `gate1` – nicht mitgeliefert
werden; ohne `--ignore-missing` meldet `sha256sum` nur deren Fehlen). Der alte Build in `deliver/gate1/build/` ist
unberührt.

## 5. Rauchtests und Bilder aus den Exporten

Alles mit den **exportierten** Programmen (Bilder in `bilder/export_*`, `bilder/erststart_*`; Logs in
`m1/FIX-ZS1/smoke/`, `smokes.log`, `rebuild.log`). „634e28b“ und „3a23cb8“ = Build aus diesem Commit (Programme bitgleich).

| Prüfung | Ergebnis (gemessen) |
|---|---|
| **Start aus dem Linux-Export** (Xvfb, OpenGL 4.5, `-- --stage=kiel_hamburg … --gfx-preset=medium --no-traffic`, Bilder 1 s und 4,5 s) | beide Builds: Auto an Arcades Stelle, Lackfläche-Kanten ≤ 0,5 % im Countdown und 1,5 s nach LOS; Starttor, Startlinie, Schild „Tankstelle 15 km“ wie Arcade. Der Wächter senkte im Countdown auf „Niedrig“ (richtig für Software-Grafik) – `export_linux_start_*.jpg` (3a23cb8) |
| **Start aus dem Windows-Export unter Wine** (wine64, eigenes Präfix, `TMPDIR` leer, Pfade `Z:…`, `wineserver -w` zwischen den Läufen) | beide Builds: ebenso, Kanten ≤ 0,5 % – `export_windows_wine_start_*.jpg` (3a23cb8) |
| `tools/smoke_modern.sh` Linux | 634e28b: **SMOKE linux: OK** (Arcade 17 s, Modern 76 s, Leistungstest „autobahn“ 10,9 Bilder/s); 3a23cb8: **OK** (18 s, 78 s, 9,7 Bilder/s); Version 0.8.0-zs1, Nutzerordner `…/crossing-europe-zwischenstand` (leistungstest.json, logs, shader_cache) |
| `DRIVER=opengl3_es tools/smoke_modern.sh` Linux | 634e28b: **SMOKE linux_opengl3_es: OK** – OpenGL ES 3.2, Arcade 17 s, Modern 74 s, Leistungstest 10,6 Bilder/s |
| `tools/smoke_modern.sh` Windows unter wine64 | 634e28b: **SMOKE windows: OK** (wineboot 8 s, Arcade 21 s, Modern 44 s, 10,5 Bilder/s); 3a23cb8: **OK** (21 s, 46 s, 8,2 Bilder/s); Nutzerordner `drive_c/users/root/AppData/Roaming/crossing-europe-zwischenstand` |
| **Erster Start wie ein Spieler** (634e28b, Linux-Export ohne Argumente, 1280 × 800 wie Steam Deck, Tastatur über xdotool; QA1s `chooser_walk.sh`, angepasst) | „GRAFIK WÄHLEN“ (Arcade empfohlen – Software-Grafik), ▶ Modern → Titel mit **v0.8.0-zs1** → Rennen starten → Limousine → 08:00 → Etappe 1 → Ladebild → Countdown **mit Auto an seinem Platz** (16:10 füllt, Straße bis zum unteren Rand) → Pause. `settings.json` mit `graphics_mode: "modern"`, `savegame.json` geschrieben – `erststart_linux_*.jpg` |

Bildraten der Software-Grafik sagen über echte Grafikchips nichts (die Schwankung 8–11 Bilder/s ist Last der VM).
ANGLE/Direct3D, echte Grafikkarten und der Steam Deck selbst sind hier nicht prüfbar (abgeleitet: derselbe Code wie unter
OpenGL und OpenGL ES).

## 6. Tore auf dem Schluss-Commit

Alle Tore liefen nacheinander mit `m1/FIX-ZS1/gates.sh` auf **`634e28b`** (Logs `m1/FIX-ZS1/gates/`); der Schluss-Commit
`3a23cb8` ändert danach nur zwei Sätze in `docs/` (kein Spielcode, keine Prüfdatei) – der Testbuild ist aus `3a23cb8`.

| Tor | Aufruf | Ergebnis (gemessen) |
|---|---|---|
| Import | `godot --headless --path . --import` | sauber, Exit 0, 0 Fehlerzeilen (5 s) |
| Skripte | `godot --headless --path . -s res://tests/check_scripts.gd` | **306 Skripte geprüft, 0 fehlerhaft** |
| Kopflose Tests | `tools/run_tests.sh` (einmal, voll) | **„Tests bestanden“, Exit 0, 865 s**: Unit-Tests **699/0** (QA1: 693 + 6 neue), 146 CHECK-Zeilen OK, 0 FEHLER; u. a. `check_modern_stage` `inhalt` (km 0: 12 Stücke mit dem Vorlauf, 32 Segmente je Stück), `waechter` (km 0, Countdown), `tore` (ein Starttor), `renderer_zeit` 0,811 ms; Fairness wie QA1: F1 0 Fälle bis 270 m (10 296 510 Stichproben), Spuren 0 bis 260 m, F2 ≤ 0,593 / 0,596 / 0,555, F3 0 von 874, F7 0 von 207 166, Pfad ≥ 267,6 m, Kameramodell 0 Abweichungen |
| Arcade-Identität | `tools/golden.sh check` | **GOLDEN arcade: 20 von 20 identisch** (157 s), **GOLDEN arcade-ui: 17 von 17 identisch** (205 s), Exit 0 |
| Modern-Änderungsmelder | `tools/golden.sh modern-check` | **GOLDEN modern: 6 von 6 identisch** (698 s; Liste aus `modern-make`, Abschnitt 1.4); **OpenGL ES** `modern_s3_hoch` gegen OpenGL: OK, max. 2/255, PSNR 73,2 dB |
| Render-Prüfungen | `tools/run_render_checks.sh all` | **18 von 18 Render-Prüfdateien in Ordnung**, Exit 0 (≈ 25 min, 04:40–05:05 UTC): u. a. `check_light_base` OK (`schatten`: mit „Aus“ wirft nichts mehr, −0,10 %), **neu `check_start_km0` OK** (Kamera ≤ 1,14 px, Auto-Kanten ≤ 2 px, Boden 0,032), `check_road_parity`, `check_occlusion`, `check_terrain_cover`, `check_seam_render`, `check_modern_render` (Helligkeit 10/10), `check_vehicle_standin` – alle OK (QA1: 16 von 17) |

## 7. Nutzerdokumente

`was_neu.md` und `steamdeck_checkliste.md` aus `deliver/gate1/` kopiert. Entfernt (nachdem der Start in beiden Exporten
geprüft war): in `was_neu.md` der Punkt „Fehler beim Start jeder Etappe“, in der Checkliste der Klammersatz „Bekannter
Fehler dieses Zwischenstands …“ unter C.3. Ergänzt in `was_neu.md` (Punkt „Tunnel, Brücken, Tankstelle“) ein Satz zur
Köhlbrandbrücke (Wiese statt Elbe, Schiffe auf der Wiese). Größen nennen beide Dokumente nicht; alles andere unverändert.

## 8. Bild gegen Arcade (ehrlich)

Ehrlich gegen Arcade im selben Simulationszustand (alle Bilder angesehen):

- **Start bei km 0** (Kiel – Hamburg, Ljubljana, Köln, Pau nachts): Modern zeigt jetzt Arcades Bildaufbau – Auto, Starttor,
  Startlinie, Schild „Tankstelle 15 km“ an derselben Stelle in derselben Größe. Vorher war genau das der auffälligste
  Fehler des Testbuilds. **Gleichwertig, nicht deutlich besser**: besser sind das Gelände (Felder mit Struktur, Tiefe),
  echte Schatten von Auto, Leitplanke und Starttor, die Pfosten der Leitplanken, das Starttor als Körper mit leuchtenden
  Lampen; schlechter oder anders: die große Eiche links vom Start bei Kiel (und der Baum links in Pau) fehlt in Modern
  (vorher wie nachher, kein Startthema), die Limousine weicht von ihrem Arcade-Bild ab (steile Heckscheibe, Sitze
  sichtbar), und hinter der Startlinie zeichnet Modern die Leitlinie im normalen Strich-Takt, wo Arcade (durch sein
  Klemmen auf Segment 0) einen durchgehenden Strich zeigt – nur in den untersten Bildzeilen zu sehen.
- **Nachts** (Pau 22 Uhr): Rücklichter, Starttor-Lampen und Scheinwerferlicht gleichwertig; Modern-Auto dunkler.
- **Köhlbrandbrücke**: **deutlich schlechter** als Arcade – Wiese statt Elbe, Schiffe auf der Wiese (Abschnitt 3).
- **Elbbrücken**: gleichwertig (Wasser, Fachwerkbögen, Fähre auf dem Wasser).

## 9. Abweichungen, Vertragsfragen, für die Nächsten

**Abweichungen vom Auftrag**

1. Vorlauf als **volles Stück −1** (96 m) statt „etwa 15 m“: hält die Builder-Regeln und die bestehende Prüfung „32
   Segmente je Stück“ ohne Sonderfall; Kosten: ein Stück mehr während der ersten 150 m (hinter der Kamera, verworfen).
2. **(b) „in einer Kurve“ und „in einer Stadt“ gibt es im Netz nicht** (Calm-Zone, City Limits nur am Ziel): gewählt
   stärkstes Startgefälle mit früher Kurve (Ljubljana), Großstadtrand (Köln), Nacht mit schärfster früher Kurve (Pau).
3. **„3 s im Countdown“** = Bildzeit 3,0 s, der Augenblick von „LOS!“ (der Countdown dauert 3 s).
4. **CHECK 3 nicht behoben** (Ursache im Fernboden, Behebung änderte `modern_s4_mittel`); nur gemeldet.
5. **`sha256sum -c` mit `--ignore-missing`**: `SHA256SUMS` nennt auch die nicht gelieferten nackten Programme (wie gate1).
6. **„vorher“-Bilder** entstanden mit den fünf Spieldateien von `92ece73` im eigenen Worktree (kurz eingesetzt, aus HEAD
   wiederhergestellt, `git status` danach leer) – kein zweiter Checkout nötig.
7. **Exporte laufen ohne `--gfx-sync`** in Echtzeit: Modern senkte dort auf „Niedrig“, die Uhren der beiden Bilder
   weichen um einige Hundertstel ab (0:01,48 / 0:01,55) – die Lage des Autos ist davon unabhängig.

**Vertragsfragen (contract_issues)**

1. §4.5 / A-3 beschreiben `RoadPath3D` nur ab der ersten Grenze; der stehende Start (Auto bei 0, Kamera bei −9 m)
   braucht Straße davor. Neu im Kern: `has_lead_in()`, `z_min()`, Stück −1 – sollte als Nachtrag in §4.5 stehen
   (Fassade A-7 unberührt).
2. §4.9.2 kennt keine Referenzposition „Start bei km 0“ (QA1-Vertragsfrage 3); die neue Render-Prüfung deckt sie jetzt
   ab – Vorschlag: als S0 in die Liste aufnehmen.
3. A-3 sagt, die Fernboden-Scheibe deckt Lücken des Geländes; sie deckt aber auch Wasser zu, das tiefer als 4 m unter
   der Straße liegt (Köhlbrandbrücke). Der Vertrag sollte festlegen, dass `far_y` unter dem tiefsten Wasser der geladenen
   Reihen liegt bzw. wer die Wasserfläche unter Brücken besitzt (R2 oder R5).

**Für die Nächsten (notes_for_next)**

1. **FIX-ZS1-B1 beheben** (Fernboden/Wasser an der Köhlbrandbrücke), danach `tools/golden.sh modern-make`
   (`modern_s4_mittel` ändert sich).
2. `layers/lights.gd` Zeile 379: Scheinwerferkegel des Verkehrs nehmen als untere Grenze `path.first · 3 m` – mit dem
   Vorlauf könnte es `path.z_min()` sein (nur relevant für Autos zwischen Kamera und Startlinie, z. B. mit
   `--traffic-warmup` nachts).
3. Die große Eiche links vom Start Kiel – Hamburg (und ein Baum links in Pau) fehlt in Modern – vorher wie nachher, auf
   „Mittel“ beobachtet; Grund im Requisiten-Builder nicht untersucht.
4. M2INT: die fünf Spieldateien (`road_path.gd`, `chunk_streamer.gd`, `chunk_context.gd`, `layers/vehicles.gd`,
   `builders/gantry.gd`), zwei neue Tests und `tests/golden/modern_slice.*` (nur `modern_start_mittel`) übernehmen; nach
   dem Zusammenführen `tools/run_render_checks.sh modern start_km0` laufen lassen.
5. Die Render-Prüfung misst die blaue Lackfläche der Limousine; ändert sich deren Farbe, muss die Maske mit.

## 10. Dateien

- Arbeitsdateien: `<scratch>/v080/m1/FIX-ZS1/` (`STAND.md`, Skripte `ab_start.sh`, `before_shots.sh`, `rc_start.sh`,
  `golden_make.sh`, `gates.sh`, `export_start.sh`, `chooser_walk.sh`, `paintbox.py`, `scan_starts.gd`, `scan_boats.gd`;
  Logs `rc_start_*.log`, `gates/`, `smoke/`; Bilder `shots/`, `before/`, `starts/`, `boats/`).
- Lieferung: `<scratch>/v080/deliver/FIX-ZS1/` – `bericht.md`, `bilder/`, `build/`, `was_neu.md`, `steamdeck_checkliste.md`.
