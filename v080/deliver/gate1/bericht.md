# QA1 – Tor 1 und erster Testbuild (Zwischenstand 1, v0.8.0-zs1)

Für die Leitung. Paket QA1 des Schubs M1 auf der Basis `28e4e8e` (FIX1). Branch `worktree-wf_ae4df3ba-14f-5`, Sicherung
`origin/wip/v080-qa1`, Schluss-Commit **`10d836f`** (alle Tore, Testbuild), danach nur noch `92ece73` (Doku: Schluss-Tore
und QA1-B3 in `docs/qa-v080.md`, gemessene Dauern), Worktree
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-5`.
„gemessen“ = auf dieser VM (Mesa llvmpipe unter Xvfb, 4 geteilte Kerne, Last meist 5–12 durch andere Pakete); alles über
Steam Deck, echte Grafikkarten, ANGLE/Direct3D und Klang ist **abgeleitet**.

## Urteil

Technisch ist Zwischenstand 1 für den Nutzertest bereit: Arcade ist bildgleich mit v0.7.0 (jetzt auch Menüs, Start über
GameFlow, Pause, Ladebild, 1280 × 800), die Fairnessprüfungen halten, Modern rendert deterministisch und über OpenGL ES
gleich, der Testbuild läuft unter Linux und unter Wine und berührt keine installierte v0.7.0 (eigener Ordner, eigene
Namen, Version „v0.8.0-zs1“ im Titel). **Bildlich ist Modern noch nicht deutlich besser als Arcade**: mit „Hoch“ auf
freier Strecke bei Tag gleichwertig bis leicht besser, schlechter bei Regen/Schnee, an Kuppen und Kurveninnenseiten und
mit „Niedrig“. **Neu gefunden (QA1-B1, hoch)**: Am Start **jeder** Etappe (km 0, Countdown) steht die Modern-Kamera 9 m zu
weit vorn – das Spielerauto fehlt im Countdown und erscheint danach zu groß. Der Fehler steckt im Testbuild und steht in
`was_neu.md`; die Behebung ist klein, gehört aber dem Kern/Fahrzeug-Besitzer (Abschnitt 4). Empfehlung: Testbuild so
ausgeben (der Fehler stört 2–3 s je Etappe) oder nach der Behebung mit `tools/build_testbuild.sh` neu bauen (3 min).
**Ein Tor ist rot**: `run_render_checks.sh all` 16 von 17 – `check_light_base` „schatten“ scheitert, weil die drei
Lampenringe des Starttors (FIX1) auch bei „Schatten: Aus“ Schatten werfen (QA1-B3, eine Zeile in `builders/gantry.gd`,
für den Spieler unsichtbar). Der Fehler steckt schon in der Basis; QA1 hat keine Spieldatei geändert.

## 1. Tore

| Tor | Ergebnis | Beleg |
|---|---|---|
| `tools/run_tests.sh` Lauf 1 (Basis 28e4e8e, vor allen Änderungen von QA1) | **bestanden**, Exit 0, 882 s: Skripte 302/0, Unit-Tests 693/0, alle Szenarien, Haken grün (u. a. `check_modern_stage` mit `renderer_zeit` 0,911 ms bei Ø 13 Autos, `check_minimal_structures`, `check_benchmark`) | `m1/QA1/gates/run_tests_1.log` |
| Fairness mit ausgelieferter Kamera und Gelände (im Lauf 1) | **grün**: F1 0 Fälle bis 270 m (10,3 Mio. Stichproben), F1-Spuren 0 bis 260 m, F2 ≤ 0,593 / 0,596 / 0,555, F3 0 von 874, F7 0 von 207 166, Pfad ≥ 267,6 m | `run_tests_1.log` |
| `render()` ≤ 1,5 ms bei 12 Autos (kopflos) | **0,911 ms** bei Ø 13 Autos | `run_tests_1.log` |
| Zweite Arcade-Identitätsliste (neu, A-6) aus v0.7.0 | **17 von 17 identisch**, zweimal hintereinander | `m1/QA1/golden/ui_*.log` |
| Modern-Änderungsmelder `modern_slice.md5` (neu) | zwei unabhängige Läufe **6 von 6 MD5-gleich** (ohne `--shot-fast`, verschiedene Vorbereitungszeiten 77–174 s) | `m1/QA1/golden/m_make.log`, `m_check.log` |
| OpenGL ES = OpenGL (§4.9.2, D38) | **OK**: S3 Hoch, größte Abweichung 2/255, PSNR 73,2 dB | `m_check.log` |
| Helligkeit je Wetter × Tageszeit (§4.9.2, neu `check_modern_render.gd`) | **OK**: 10 von 10 (S1 trocken/Regen/Schnee × 12/19:30/22 Uhr + Gotthard): 0,89–0,98 × Arcade, Boden 0,81–0,99 ×, reinschwarz ≤ 0,7 % | `m1/QA1/rc_trial.log` |
| Leistungstest im `deck`-Budget an S3 und C1 | Draw Calls 135 / 115 und Dreiecke 102 558 / 34 788 **im Budget** (650 / 450 000); `render()` 2,22 / 3,02 ms **über** 1,5 ms – unter Last 9–11 über den GL-Pfad (kopflos 0,911 ms) | `leistungstest/` |
| `tools/golden.sh check` (Schluss-Commit) | **20 von 20 identisch** (Rennbilder, 170 s) und **17 von 17 identisch** (zweite Liste, 226 s), Exit 0 – Arcade bildgleich mit v0.7.0 | `m1/QA1/gates/golden_final.log` |
| `tools/run_render_checks.sh all` (Schluss-Commit) | **16 von 17 Dateien OK**, 1 830 s. **FEHLER** in `check_light_base` „schatten“: mit „Schatten: Aus“ werfen 3 Knoten Schatten – die drei Ringe der Countdown-Lampen am Starttor (`builders/gantry.gd` ab Z. 187, aus FIX1, ohne `cast_shadow = OFF`; Befund QA1-B3); die Helligkeit selbst hält (−0,10 %). Alles andere grün, u. a. Pause 30 Bilder 0 px, Linien ≤ 0,22 px (Gerade) / 7,09 / 13,27 px (Kurven), Okklusion 0 px, Rücklicht N1, Sichtgrenze, Geländedeckung 0,000 % (T1–T4, S1, C1), 16:10/21:9 gefüllt, Rückfall, Arcade–Modern–Arcade 0 px, Helligkeit 10/10 | `m1/QA1/gates/render_checks_final.log` |
| `tools/run_tests.sh` Lauf 2 (Schluss-Commit) | **bestanden**, Exit 0, 845 s: Skripte 304/0, Unit-Tests 693/0, alle Szenarien und Haken grün (173 CHECK-Zeilen OK), Fairness wie Lauf 1, `renderer_zeit` 0,825 ms bei Ø 13 Autos | `m1/QA1/gates/run_tests_2.log` |

## 2. Lieferungen (Gate-1-Paket in `<scratch>/v080/deliver/gate1/`)

| Lieferung | Datei(en) | Stand |
|---|---|---|
| A/B-Bögen aller Referenzpositionen (§4.9.2) | `ab_boegen/<Pos>_hoch_00.jpg`, `<Pos>_rechner_niedrig_00.jpg` (14 Positionen × 2), `uebersicht_hoch.jpg`, `uebersicht_rechner_niedrig.jpg`, `index.txt`; dazu `S0_start_km0_*` (Befund QA1-B1) und `S1/S4_steamdeck_1280x800.jpg` | alle angesehen, Abschnitt 3 |
| Drei A/B-Clips je 30 s mit HUD | `clips/kiel_hamburg_start_tag.mp4` (21,1 MB), `clips/dev_km48_nacht_21uhr.mp4` (16 MB), `clips/n2_dortmund_frankfurt_regen.mp4` (23,1 MB) | H.264 2560 × 720, 60 Bilder/s |
| Leistungstest je Voreinstellung | `leistungstest/leistungstest_{low,medium,high}.json`, `leistungstest_deck_s3c1.json`, `tabelle.md` | Abschnitt 5 |
| Goldens | `tests/golden/arcade_ui_frames.txt` + `arcade_ui_v070.md5`, `tests/golden/modern_frames.txt` + `modern_slice.md5` (+ `.env`), eingehängt in `tools/golden.sh` (`check` prüft beide Arcade-Listen, `modern-check` die Modern-Liste + OpenGL ES) | committet |
| Testbuilds | `build/CrossingEurope-ZS1-linux-x86_64.tar.gz` (146,9 MB), `build/CrossingEurope-ZS1-windows-x86_64.zip` (156,6 MB), `LIZENZEN.txt`, `SHA256SUMS`, `BUILDINFO.txt` | Abschnitt 6 |
| Nutzerdokumente | `steamdeck_checkliste.md`, `was_neu.md` | deutsch, ehrlich |
| Klang-Hörproben (von den Klangpaketen, hier nicht neu) | `deliver/AU-B/motor_ab_*.mp3`, `deliver/AU-D1/titel_*.mp3`, `rennmusik_linke_spur_*.mp3`, `rennmix_linke_spur_unter_motor.mp3` | Verweis |

Neue Werkzeuge (committet): `tools/ab_sheet.sh`, `tools/ab_clip.sh`, `tools/build_testbuild.sh`, `tools/smoke_modern.sh`,
`tools/golden.sh` (neue Modi), `tests/golden/ui_shots.gd`, `tests/race3d/render/check_modern_render.gd`,
`docs/qa-v080.md`.

## 3. Bild: Modern gegen Arcade im selben Simulationszustand

Methode: `tools/ab_sheet.sh` (neu) über `tools/ab_shot.sh` an allen 14 Referenzpositionen von §4.9.2, fliegender Start
mit Autopilot, Bild 3 s nach dem Start (S5: 1,5 s, sonst ist das Ziel schon durchfahren), Arcade mit `--shot-fast`,
Modern ohne. Je Position zwei Voreinstellungen: **Hoch** und die, die dieser Rechner selbst wählt (**Niedrig**:
Grafikkarte llvmpipe = Stufe „software“). Jedes der 30 Bilder angesehen. Helligkeit gemessen über die PNGs (mit HUD):
Modern liegt überall bei 0,95–1,05 × Arcade (Boden 0,89–1,05 ×), keine schwarzen Flecken (≤ 0,5 % reinschwarze Pixel).

| Pos. | Hoch | Niedrig (dieser Rechner) |
|---|---|---|
| S1 km 2, 12 Uhr | gleichwertig bis leicht besser: Felder mit Struktur, echte Schatten (Bäume, Leitplanke, Auto), Kartenbäume, Windräder, Dunst am Horizont. Die Spieler-Limousine ist ein anderes Auto als ihr Sprite (steile Heckscheibe, sichtbare Sitze statt Fließheck) | flacher: keine Schattenwerfer, 75 % Auflösung (Treppen an Kanten), weniger Requisiten (die große Eiche rechts fehlt) |
| S2 Tankspur | gleichwertig: Dach, Insel, gelber Bordstein, Säulen, „TANKSTELLE“ wie Arcade; der Busch links vorn ist ein dunkler Klumpen (Arcades Busch ist schöner) | gleichwertig, ohne Schatten unter dem Dach |
| S3 km 60 | leicht besser: Felder in mehreren Farben, Tiefe, Schatten der Eichen | flacher, die große Eiche fehlt |
| S4 km 80 City Limits | gleichwertig: Häuser, Kran und Backsteinblöcke sind in beiden Modi Arcades Bilder; Modern hat gepflasterte Gehwege und Laternen als Modelle | wie Hoch |
| S5 Ziel (Bild bei 1,5 s) | gleichwertig: Zielbrücke „ZIEL“ an Arcades Stelle (FIX1), Stadtsilhouette, Backsteinblöcke als Arcade-Bilder; Gehweg gepflastert | gleichwertig |
| T1 km 47,6 | gleichwertig: Gelände deutlich besser (Hügel mit Schattierung statt flachem Grün), aber links vorn fehlt die große Fichte (Innenseite der Kurve, F7); das Kurvenschild rot-weiß am rechten Rand (≈ 25 m) ist in Arcade zu sehen, in Modern nur als 2-px-Streifen – die Kurvenkamera schaut in die Kurve und schiebt nahe Dinge am Außenrand aus dem Bild | weniger Fichten links |
| T2 Kuppe km 63 | **schlechter**: Arcade zeigt die **Sonnenscheibe** und links große Eichen und Fichten an der Straße, Modern links fast leeres Gras mit ein paar Büscheln (Sichtkorridor, Bodendecker) | **schlechter**, links ganz leer |
| T3 km 173,7 | gleichwertig: echter Hügel links, natürlicher Rand; aber keine Sonnenscheibe und der nahe Findling links fehlt | wie Hoch |
| T4 km 199,7 (R ≈ 136 m) | gleichwertig: die Kurvenkamera zeigt die Kurve besser; die große Fichte an Arcades rechtem Rand (Innenseite) fehlt | der Kompakt bei 75 % sichtbar treppig und unruhig |
| N1 22 Uhr Schnee | **schlechter**: **kein Schneefall**; Kegel und Schneeboden ähnlich; der Kompakt heller und gelber als Arcades Nachtbild | wie Hoch |
| N2 Regen | **schlechter**: **kein Regen** in der Luft; nasse Fahrbahn dunkler und etwas glänzend | wie Hoch |
| C1 Frankfurt 19:30 | leicht schlechter: Arcades großer Straßenbaum rechts (Innenseite) fehlt; Häuser in beiden Modi Arcade-Bilder, Gehweg in Modern schöner | wie Hoch |
| U1 Gotthard | gleichwertig: Röhre mit Fliesenband, Lampen mit Lichthof und dunkler Tiefe (FIX1); Limousine warm beleuchtet | gleichwertig |
| DEV 21 Uhr | gleichwertig: Portal, Hügel, Schild wie Arcade; Hügel heller und glatter, die Eiche rechts nachts recht hell, die Fichte links fehlt; Limousine heller als Arcades (keine Mondflecken mehr) | wie Hoch |
| Start km 0 (Diagnose) | **Fehler** QA1-B1: Spielerauto im Countdown unsichtbar, Kamera 9 m zu weit vorn | – |

**Urteil Bild**: Auf freier Strecke bei Tag ist Modern mit „Hoch“ gleichwertig bis leicht besser als Arcade (Gelände mit
Tiefe, Schatten, Felder, Tunnel, Tankstelle). **Deutlich besser ist es noch nirgends.** Schlechter ist es bei Regen und
Schnee (kein Wetter in der Luft), an Kuppen und Kurveninnenseiten (fehlende Bäume, keine Sonnenscheibe), am Start jeder
Etappe (QA1-B1) und mit „Niedrig“ (flacher als Arcade). Städte sehen in beiden Modi gleich aus, weil die Gebäude noch
Arcade-Bilder sind; Spielerautos ohne Modell (Kombi, Sportwagen, Gran Turismo) ebenso.

### 3.1 Die drei A/B-Clips (je 30 s, nebeneinander mit HUD)

`tools/ab_clip.sh` (neu): Godots Movie Maker nimmt dieselbe Fahrt in beiden Modi mit festen 60 Bildern/s auf
(`--gfx-sync`, gleicher Seed), das Ladebild von Modern wird an seiner Deckfarbe erkannt und abgeschnitten (14 Bilder),
beide Aufnahmen enden nach derselben Spielzeit. Ergebnis: H.264, 2560 × 720 (zweimal 1280 × 720), 60 Bilder/s, ohne
Ton. **Gleichlauf geprüft**: die HUD-Uhren beider Hälften zeigen in jedem herausgezogenen Bild dieselbe Zeit
(0:00.00 im Countdown, 0:01.50, 0:10.00, 0:12.00, 0:20.00, 0:25.00, 0:29.00). Modern jeweils mit „Hoch“.

| Clip | Inhalt | Größe | Aufnahme (gemessen) |
|---|---|---|---|
| `clips/kiel_hamburg_start_tag.mp4` | Kiel – Hamburg ab km 0, 12 Uhr: Countdown, Start, Autobahn bis km 10,5 | 21,1 MB | Arcade 160 s, Modern 1 217 s |
| `clips/dev_km48_nacht_21uhr.mp4` | dev_testetappe ab km 48, 21 Uhr: Tunnel, Nacht mit Mond, Verkehr, Kurven | 16 MB | Arcade 236 s, Modern 918 s |
| `clips/n2_dortmund_frankfurt_regen.mp4` | Dortmund – Frankfurt ab km 121, Regen, 16 Uhr: Verkehr, Radar- und Tankstellenhinweise | 23,1 MB | Arcade 257 s, Modern 1 720 s |

Was man sieht: Im Start-Clip fehlt in Modern das Spielerauto im Countdown und taucht nach „LOS!“ zu groß auf
(QA1-B1); danach laufen beide gleich. Nachts: Tunnel gleichwertig, draußen Mond, Bäume und Verkehr wie Arcade, Bäume in
Modern heller angestrahlt. Regen: in Arcade fallen Regenstriche, in Modern nicht (R4 fehlt) – die Fahrbahn ist in
Modern dunkler; Gran Turismo, Transporter und Sportwagen sind in beiden Modi Arcade-Bilder. Die Beschriftung der Hälften
liegt in diesen drei Clips über der HUD-Uhr (lesbar); `ab_clip.sh` setzt sie seitdem in einen Streifen über dem Bild.
Angesehen habe ich je Clip vier Einzelbilder (Start 1/4,5/15/28 s, Nacht 2/10/20/29 s, Regen 2/12/22/29 s);
Bewegung (Flimmern, LOD-Wechsel) lässt sich daran nicht beurteilen – das beurteilt der Mensch am ganzen Clip.

## 4. Befunde

### QA1-B1 hoch – Start jeder Etappe: Kamera 9 m zu weit vorn, Spielerauto im Countdown unsichtbar

Gemessen mit `tools/ab_shot.sh` (Kiel – Hamburg km 0, stehender Start mit Countdown, Mittel, Bilder bei 1 s, 3,3 s,
3,7 s, 4,5 s): Arcade zeigt das Auto im Countdown; **Modern zeigt kein Auto** – im Countdown nicht und auch 0,7 s nach
„LOS!“ (14 km/h) nicht. Bei 1,5 s (30 km/h) erscheint es, aber **viel zu groß und zu tief**: nur Dach und
Heckscheibe sind im Bild, das Heck liegt unter dem Bildrand (Ausschnitt `m1/QA1/diag/am3.png`). Das Starttor wirkt in Modern deutlich näher als in Arcade, und das große Schild
„Tankstelle 15 km“ rechts am Start fehlt im Bild. Die Modern-Bilder 00–02 sind bis auf HUD/Countdown gleich – die
Kamera bewegt sich in den ersten Metern nicht.

Ursache (Code gelesen): Beim Start steht das Auto bei `pos_z = 0`, die Kamera bei `camera_z = pos_z − 9 m = −9 m`
(`render.camera_distance_m`). `RoadPath3D` kennt nur z ≥ 0 (`first` ≥ 0, `_locate()` klemmt `_lt` auf 0 … 1):
`world()`/`frame_at()` für z < 0 liefern den Punkt bei z = 0 – die Kamera steht also 9 m zu weit vorn, bis das Auto 9 m
gefahren ist. `layers/vehicles.gd::_update_car` blendet ein Auto mit `z < z_lo` (Heck vor dem ersten Pfadpunkt) aus –
das Spielerauto (`z = pos_z − Länge/2 = −2,4 m`) fehlt deshalb im Countdown. Betroffen ist **jede Etappe** im normalen
Spiel (Start bei km 0); Attract-Demos, Leistungstest, Goldens und alle bisherigen A/B-Bilder starten bei km > 0 – darum
fiel es nicht auf.
Vorschlag für den Besitzer (Kern `road_path.gd` und `layers/vehicles.gd`, ab Welle 3 R4): den Pfad vor Punkt 0 gerade
fortsetzen (Arcade zeichnet die Straße hinter der Startlinie gerade weiter), die Straße der ersten Stücke ab z = −15 m
bauen und Autos zeigen, deren Körper hinter z_lo beginnt. Prüfung: ein Render-Check „Start bei km 0: Spielerauto an
Arcades Stelle“. Belege: `deliver/QA1/befund_start_km0_countdown_auto_fehlt.jpg`,
`deliver/QA1/befund_start_km0_nach_1_5s_auto_zu_nah.jpg`, `m1/QA1/diag/`.
Im Testbuild steckt der Fehler; er steht in `was_neu.md` als bekannter Fehler.

### QA1-B2 mittel – Kurvenkamera schiebt nahe Schilder am Außenrand früher aus dem Bild

T1 (Kassel – Würzburg km 47,6, Linkskurve): das rot-weiße Kurvenschild ≈ 25 m voraus am rechten Bildrand ist in Arcade
zu sehen, in Modern nur ein 2-px-Streifen (die Kamera schaut in die Kurve). `modern_sight_f1` prüft nur Ziele auf der
Fahrbahn (Mitte ± eine Spur), keine Schilder am Rand. In 25 m ist das Schild für die Reaktion kaum noch wichtig – aber
Regel 9 zählt Schilder zu dem, worauf der Spieler reagiert. Vertragsfrage 2.

### QA1-B3 mittel – Render-Prüfung „schatten“ rot: Ringe der Countdown-Lampen werfen auch bei „Schatten: Aus“

`tools/run_render_checks.sh all` am Schluss-Commit: `check_light_base` „schatten“ FEHLER „mit „Aus“ wirft kein Knoten
Schatten (3)“ (gemessen; die Helligkeit selbst hält, −0,10 %). Diagnose mit einem eigenen Skript
(`m1/QA1/diag_casters.gd`, gemessen): genau drei unbenannte `MeshInstance3D` unter `World/Chunks/Chunk0` mit
`cast_shadow = ON` bei `shadow_casters = 0` – die drei Ringe (`rim`) der Countdown-Lampen, die `builders/gantry.gd`
(FIX1, Commit 67a24bb) ab Zeile 187 ohne `cast_shadow` anlegt (Standard: an); Pfosten/Banner richten sich nach
`shadow_casters`, Schrift und Lampen sind aus. Behebung (eine Zeile, Besitzer des Builders): `rim.cast_shadow =
GeometryInstance3D.SHADOW_CASTING_SETTING_OFF`. Der Fehler liegt schon in der Basis 28e4e8e (FIX1 hatte die Render-
Prüfungen nicht als Ganzes laufen lassen); QA1 hat keine Spieldatei geändert. Für den Spieler unsichtbar (drei kleine
Ringe werfen Schatten, wo „Aus“ gewählt ist).

### Bekannte Lücken, im Bild bestätigt (nicht neu)

Kein Wetter in der Luft (N1, N2, Regen-Clip), keine Sonnenscheibe (T2, T3), Kurveninnenseiten ohne Bäume (T1–T4, C1),
Fahrzeuge ohne Modell als Arcade-Bild (Kombi, Sportwagen, Gran Turismo, Busse, Transporter), Städte aus Arcade-Bildern,
Spieler-Limousine mit steiler Heckscheibe, Kompakt nachts heller als sein Sprite, „Niedrig“ ohne Schatten und mit 75 %
Auflösung flacher als Arcade.

## 5. Leistung (gemessen auf llvmpipe – für echte Grafik bedeutungslos)

Der echte Läufer (`-- --graphics=modern --gfx-preset=<stufe> --bench=all --bench-out=<datei>`) unter Xvfb 1280 × 720,
ohne Bildbegrenzung, Last 9–12. Alle vier Läufe Exit 0, `user://leistungstest.json` jeweils byte-gleich mit
`--bench-out`. Tabelle und Dateien: `leistungstest/tabelle.md`, `leistungstest/*.json`.

| Stufe | Autobahn bei Tag | Stadt bei Nacht im Regen | Bergstrecke mit Tunnel | `render()` Ø | Draw Calls | Dreiecke | Urteil / Vorschlag |
|---|---|---|---|---|---|---|---|
| Niedrig | 6,0 fps (p95 262 ms) | 1,5 fps | 2,8 fps | 2,13–2,79 ms | 64–131 | 24 113–89 515 | too_slow → **Arcade** |
| Mittel | 1,3 fps | 1,0 fps | 1,5 fps | 2,17–2,95 ms | 76–144 | 31 458–93 394 | slow → Niedrig |
| Hoch | 1,2 fps | 1,2 fps | 1,3 fps | 2,22–2,72 ms | 99–160 | 52 545–107 220 | slow → Mittel |
| Steam Deck an S3 / C1 | 1,3 / 1,5 fps | – | – | 2,22 / 3,02 ms | 135 / 115 | 102 558 / 34 788 | slow → Niedrig |

- Die Bildraten sind Software-Grafik auf einer belasteten VM und sagen **nichts** über den Steam Deck (abgeleitet).
  Ein Szenendurchlauf hat bei 1–6 Bildern/s nur 20–121 Bilder; die Perzentile sind entsprechend grob.
- Budget `deck` (650 Draw Calls, 450 000 Dreiecke, 1,5 ms `render()`): Draw Calls und Dreiecke bei S3 und C1 weit
  darunter; `render()` darüber (2,22 / 3,02 ms, unter Last über den GL-Pfad; kopflos bei normalem Tempo 0,911 ms für den
  ganzen Renderer). Abweichung gemeldet; was der Deck-Kern braucht, zeigt der Leistungstest des Nutzers.
- Die Engine meldet für die Schattendurchgänge 0 Draw Calls, aber Dreiecke (Mittel/Hoch: 1 042–21 785) – die Schatten-
  Draw-Calls zählt Compatibility offenbar nicht; das Budget „Draw Calls inkl. Schatten“ ist so nicht vollständig messbar.
- Vorbereitung je Szene 10,7–61,7 s (Modelle, Schilder, Shader-Aufwärmen hinter dem Ladebild; der erste Lauf mit
  kaltem Shader-Cache am längsten).

## 6. Testbuild und Rauchtests

`tools/build_testbuild.sh 0.8.0-zs1 ZS1 crossing-europe-zwischenstand` aus dem Schluss-Commit `10d836f` (sauberer Baum),
174 s, mit `tools/build_linux.sh` und `tools/build_windows.sh`. Nur für den Build eingetragen und danach
wiederhergestellt (nicht committet): `config/version="0.8.0-zs1"`, `config/use_custom_user_dir=true`,
`config/custom_user_dir_name="crossing-europe-zwischenstand"`, in `export_presets.cfg` Datei- und Produktversion
`0.8.0.1` (Windows braucht vier Zahlen). Nach dem Build: `project.godot` wieder 0.7.0, `git status` leer.

| Datei | Größe (gemessen) | SHA-256 |
|---|---|---|
| `CrossingEurope-ZS1-linux-x86_64.tar.gz` (`CrossingEurope-ZS1.x86_64` 440,7 MB + `LIZENZEN.txt`) | 146,9 MB (140 MiB) | `e7e2f5e1…e922` |
| `CrossingEurope-ZS1-windows-x86_64.zip` (`CrossingEurope-ZS1.exe` 476,5 MB + `LIZENZEN.txt`) | 156,6 MB (149 MiB) | `b22f1405…a3d7` |

Beide unter 400 MiB (Lieferweg) und unter dem Größentor von `pck_report.py` (Warnung 300, Abbruch 330 MB); Teile des
Windows-Archivs: Vorlage 37,95, Arcade-Sprites 71,07, Arcade-Klang 14,72, UI/Skripte/Daten 3,77, Modern-Modelle 4,64,
-Texturen 5,59, -Klang 11,14, -Musik 7,54 MB. Die `.exe` trägt Icon und Versionsressource (FileVersion/ProductVersion
0.8.0.1, Produktname = Spielname; `inspect_exe.py`). Die Archive sind reproduzierbar (Dateizeiten = Commit-Zeit).
`SHA256SUMS` nennt Archive, Programme und `LIZENZEN.txt` (`sha256sum -c --ignore-missing SHA256SUMS` im Lieferordner: OK).

**Rauchtests** (`tools/smoke_modern.sh`, Echtzeit, Kiel – Hamburg über GameFlow mit `-- --stage=…`, Bilder bei 6 s und
14 s, danach Leistungstest-Szene „autobahn“ 8 s; Belege in `rauchtest/`):

| Plattform | Arcade | Modern | Leistungstest | Nutzerordner |
|---|---|---|---|---|
| Linux-Export, Xvfb, OpenGL 4.5 | OK, 21 s | OK, 96 s | OK, 5,7 fps, Voreinstellung „low“ (selbst gewählt, Stufe software), `game_version` 0.8.0-zs1, Vorschlag Arcade | `$XDG_DATA_HOME/crossing-europe-zwischenstand/` (leistungstest.json, logs, shader_cache) |
| Linux-Export, OpenGL ES 3.2 (`--rendering-driver opengl3_es`, Weg von ANGLE) | OK, 19 s | OK, 106 s; der Wächter senkte im Countdown von Mittel auf Niedrig (richtig für Software-Grafik) | OK, 6,5 fps | wie oben |
| Windows-Export unter wine64 (OpenGL über Mesa; ANGLE/Direct3D hier nicht prüfbar) | OK, 21 s | OK, 97 s | OK, 7,1 fps, 0.8.0-zs1 | `drive_c/users/root/AppData/Roaming/crossing-europe-zwischenstand/` = `%APPDATA%\crossing-europe-zwischenstand\` |

**Erster Start wie ein Spieler** (Linux-Export ohne Argumente auf einem 1280 × 800-Xvfb, Tastatur über xdotool,
`chooser_walk.sh`): Auswahl „GRAFIK WÄHLEN“ (Untertitel für neue Spieler – der eigene Ordner ist leer; empfohlen Arcade mit
Warnung „Software-Grafik“) → ▶ Modern → Enter → Titel mit **„v0.8.0-zs1“** unten rechts → Rennen starten → Kiel –
Nürnberg → Limousine → 08:00 → Etappe 1 → Start → Ladebild mit Balken → Kiel – Hamburg in Modern füllt 16:10 → Pause
geht. `settings.json` im eigenen Ordner mit `graphics_mode: "modern"`, `savegame.json` geschrieben. Im Rennen ohne Gas
steht das Auto bei km 0 – und ist **nicht zu sehen** (QA1-B1, Bild `rauchtest/linux_modern_start_km0_ohne_auto.png`).
Die Rauchtestbilder verschiedener Läufe sind nicht pixelgleich vergleichbar (Echtzeit, keine feste Bildrate); den
Vergleich OpenGL ES = OpenGL macht `golden.sh modern-check` mit fester Bildrate (2/255, 73,2 dB).

## 7. Abweichungen vom Auftrag und vom Vertrag

1. **`tests/race3d/bench_modern.gd` (§4.9.4, Datei von QA1) nicht geschrieben.** Die Budgetfrage „`deck` an S3 und C1“
   ist mit dem echten Leistungstest-Läufer beantwortet: eine `user://game_config.json` ersetzt die Szenenliste
   (Wörterbücher mischen, Listen ersetzen) – derselbe Läufer, den der Nutzer startet (Abschnitt 5).
2. **`scripts/race3d/benchmark.gd`** (laut §6 Datei von QA1) gab es schon (UI1); unverändert benutzt.
3. **A/B-Bögen**: B1 (Brückenankunft Köln/Wien) steht nicht im Auftrag und wurde nicht aufgenommen; die Köhlbrandbrücke
   steckt in S4. Bild je Position bei 3 s, S5 bei 1,5 s.
4. **Testbuild**: die nur für den Build nötigen Änderungen (Version, eigener Nutzerordner, Windows-Versionsnummer
   0.8.0.1) macht `tools/build_testbuild.sh` vor dem Export und nimmt sie danach zurück – nichts davon ist committet.
5. **Clips** ohne Ton (Arcade-Klang in beiden Aufnahmen, Bild nebeneinander); der Modern-Klang liegt als Hörprobe bei
   AU-B/AU-D1.

## 8. Vertragsfragen (contract_issues)

1. **Kurvenkamera „schwächer“**: Der Nutzer soll nach dem Fahren entscheiden „so lassen, stärker oder schwächer“ –
   A-3 erlaubt ohne neuen Beweis nur **stärker** („the look can be made stronger, not weaker“; F1 hat bei 270/260 m
   keinen Rand). Wünscht der Nutzer „schwächer“, braucht es `modern_sight.gd -- --full` und eventuell einen Ausgleich.
2. **F1 deckt Schilder am Rand nicht ab**: `modern_sight_f1` prüft Ziele auf Fahrbahnmitte ± eine Spur. An T1 steht
   ein rot-weißes Kurvenschild ≈ 25 m voraus am rechten Bildrand in Arcade im Bild, in Modern nur als 2-px-Streifen
   (die Kamera schaut in die Kurve). Regel 9 zählt Schilder zu dem, worauf der Spieler reagiert – der Vertrag sollte
   sagen, ob F1 Schilder am Straßenrand einschließt.
3. **Start bei km 0 nicht im Prüfnetz**: Alle Referenzpositionen, Goldens, Attract-Demos und der Leistungstest starten
   bei km > 0; der Start jeder echten Etappe (km 0, Countdown) war deshalb nie im Bild geprüft (QA1-B1). Vorschlag:
   §4.9.2 um eine Position „S0 – Start bei km 0 mit Countdown“ ergänzen (in `modern_frames.txt` steht sie schon).
4. **A-6 zweite Liste**: Die ◀▶-Pfeile von Fahrzeugwahl und Startzeit folgen der Wanduhr (`Time.get_ticks_msec()`,
   seit v0.7.0) – die zweite Liste maskiert sie. Gleichwertig wäre eine Spieluhr in UI-Dateien (UI2), dann ließe sich
   die Maske streichen.

## 9. Für die Nächsten

1. **QA1-B1 beheben** (Kern `road_path.gd`, `layers/vehicles.gd`, Straße der ersten Stücke): Pfad vor km 0 gerade
   fortsetzen, Straße ab z = −15 m bauen, Autos mit Heck vor z_lo zeigen; Render-Check „Start bei km 0“ dazu und
   `tools/golden.sh modern-make` (der Melder `modern_start_mittel` zeigt den Fehler heute).
2. **QA1-B3 beheben** (`builders/gantry.gd`: `rim.cast_shadow = OFF`), dann `tools/run_render_checks.sh modern light_base`.
3. Wetter (R4), Sonnenscheibe, Bodendecker an Kurveninnenseiten, Spielerauto-Modelle: die größten Lücken zu „deutlich
   besser als Arcade“; die Bögen T2/N1/N2 und die Clips sind dafür die Vergleichsbilder.
4. Nach jeder gewollten Änderung am Bild von Modern: `tools/golden.sh modern-make` im selben Commit; `golden.sh check`
   prüft jetzt 20 + 17 Arcade-Bilder (gemessen 402 s, ≈ 7 min).
5. Für Gate 2: `tools/build_testbuild.sh 0.8.0-zs2 ZS2` baut den nächsten Testbuild; `tools/smoke_modern.sh` prüft ihn
   (Linux, OpenGL ES, Wine).
6. Schatten-Draw-Calls zählt die Engine in Compatibility als 0 (Dreiecke werden gezählt) – PERF braucht für das Budget
   „Draw Calls inkl. Schatten“ eine eigene Zählung.
7. Die Rückmeldung des Nutzers zur Kurvenkamera: „schwächer“ braucht einen neuen Fairnessbeweis (Vertragsfrage 1).

## 10. Dateien und Werkzeuge

- Arbeitsdateien: `<scratch>/v080/m1/QA1/` (Skripte `run_*.sh`, `queue*.sh`, `chooser_walk.sh`, Logs, `ab/` mit den
  PNGs der Helligkeitsmessung, `clips/` mit Logs und Einzelbildern, `bench/`, `golden/`, `diag/`, `smoke/`), Übergabe
  `STAND.md`. Gelöscht (Aufräumen am Schluss): die Doppel der Archive und Clips – sie liegen nur noch im Lieferordner –,
  Shader-Caches und die Nutzerordner der einzelnen Läufe.
- Befundbilder: `<scratch>/v080/deliver/QA1/befund_start_km0_*`.
