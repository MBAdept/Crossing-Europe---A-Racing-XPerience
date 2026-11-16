# QA-WASSER – Unabhängige Prüfung des neu gebauten Testbuilds „Zwischenstand 1“ (v0.8.0-zs1 aus `0ad9012`)

Für die Leitung. Prüfrolle, keine Commits, kein Push. Worktree `…/.claude/worktrees/wf_bdb6e1e1-c64-2` (Branch
`worktree-wf_bdb6e1e1-c64-2`, per `--ff-only` auf `0ad9012353855295255c27dd987b90e30ff0f33f`, sauber). Kein Vorgänger
(keine `STAND.md`) – frisch begonnen um 08:22 UTC.
„gemessen“ = auf dieser VM (Mesa llvmpipe unter Xvfb, 4 geteilte Kerne); alles über Steam Deck, echte Grafikkarten,
ANGLE/Direct3D und wie etwas auf einen Menschen wirkt, ist **abgeleitet**.
Alle Bilder aus den **gelieferten** Programmen (nicht aus dem Projekt), mit `--fixed-fps 60 -- --gfx-sync` (gleiche
Bildzeiten in beiden Modi, Wächter aus, die gewählte Stufe bleibt stehen), je Lauf ein frisches `XDG_DATA_HOME`.

## Urteil

**Der Build kann zum Nutzer.** Arcade-Identität 20 von 20 und 17 von 17, Geländesperre grün, der neue Unit-Test ist ein echter Wächter, und das gelieferte Spielpaket ist Datei für Datei der Commit `0ad9012` (bis auf die vorgesehenen Testbuild-Einstellungen). Kein Blocker, kein Befund an der Wasser-Behebung; fünf Befunde mittel/niedrig, alle schon im vorigen Build oder erst durch das jetzt sichtbare Wasser zu sehen – dazu sechs Sätze für die Nutzerdokumente.

- **Die Behebung wirkt im ausgelieferten Build**: Die Elbe liegt unter und neben der Köhlbrandbrücke, die Fähren
  schwimmen – Tag und Nacht, „Hoch“ und Steam-Deck-Stufe (1280 × 800), im Linux-Export und im Windows-Export unter
  Wine (die Windows-Bilder sind **pixelgleich** mit den Linux-Bildern). Keine Grube, keine Naht, kein Springen des
  Bodens beim Absenken der Scheibe (km 67,1) und auf der Anfahrt ab km 76,5.
- **Der Build ist genau der geprüfte Stand**: Gegen den zuvor gelieferten Build (FIX-ZS1) unterscheidet sich im
  eingebetteten Spielpaket **genau eine von 1.011 Dateien** – `scripts/race3d/layers/far_ground.gdc`, in Linux und
  Windows; sie enthält die neuen Namen (`lowest_water`, `WATER_MARGIN_M`, `water_y`). Ein frischer Export des Spielpakets aus dem sauberen `0ad9012` stimmt mit dem gelieferten in 1.010 von 1.011 Dateien überein; anders ist nur `project.binary` (Version und Nutzerordner des Testbuilds).
- **Code und Test**: Nur die vorgesehenen Dateien, keine Arcade-Datei. Die Scheibe kann nur tiefer liegen als vorher –
  sie verdeckt also nichts, worauf der Spieler reagieren muss (F7). Der neue Unit-Test ist ein echter Wächter: vier
  absichtliche Fehler in `far_ground.gd` (alte Regel, kein Abstand zum Wasser, Springen statt Gleiten, überall 0,5 m
  tiefer) werden alle erkannt (3, 3, 1 und 2 von 4 Tests rot), unverändert 4/4 grün.
- **Ehrlich zum Bild**: An der Köhlbrandbrücke ist Modern jetzt **gleichwertig bis etwas besser** als Arcade (echte
  Pylone und Seilfächer, Wasser, Fähren), **nicht deutlich besser**: das Wasser ist eine glatte, zum Horizont grau-
  helle Fläche, am Brückenende fehlt Arcades Kaimauer, nachts leuchten die Pylone fast weiß, die Pylonfüße wirken bei
  Tag verwaschen. Neu gefunden (nicht vom Wasser, schon im vorigen Build): **in sechs Städten fehlt in Modern das
  Wahrzeichen** (Belgrad gesehen; Hannover, Leipzig, Dortmund, Calais, Madrid aus den Daten) – Hannover liegt auf einem
  der zwei Wege des ersten Rennens Kiel – Nürnberg.

## 1. Gelieferte Dateien (gemessen)

Kopiert nach `m1/QA-WASSER/build/`, entpackt in eigene leere Ordner (`lin/`, `win/`).

| Prüfung | Ergebnis |
|---|---|
| `sha256sum -c --ignore-missing SHA256SUMS` | `…linux-x86_64.tar.gz: OK`, `…windows-x86_64.zip: OK`, `LIZENZEN.txt: OK` |
| Inhalt Linux-Archiv | genau `CrossingEurope-ZS1.x86_64` (440.693.008 B, `-rwxr-xr-x`) + `LIZENZEN.txt` (113.873 B), kein Unterordner |
| Inhalt Windows-Archiv | genau `CrossingEurope-ZS1.exe` (476.471.776 B) + `LIZENZEN.txt` |
| entpackte Programme gegen `SHA256SUMS` | `7eba3af3…` (Linux) und `6ccb6462…` (Windows) = die Einträge; `LIZENZEN.txt` in beiden Archiven = die gelieferte = die von FIX-ZS1 und gate1 |
| Größen | Archive 146.920.929 B und 156.566.135 B – wie im Bericht von FIX-WASSER, unter 350 MB |
| `BUILDINFO.txt` | Commit `0ad9012353855295255c27dd987b90e30ff0f33f` (Commit-Zeit 05:57:21 UTC = die des Commits), Version 0.8.0-zs1, Windows 0.8.0.1, Nutzerordner `crossing-europe-zwischenstand`, Godot 4.7.2 |
| Projekteinstellungen **im** eingebetteten Spielpaket (`project.binary`, Linux = Windows) | `application/config/version` = `0.8.0-zs1`, `use_custom_user_dir`, `custom_user_dir_name` = `crossing-europe-zwischenstand` |
| Spielpaket gegen den vorigen Build (FIX-ZS1, `3a23cb8`), Verzeichnis mit MD5 je Datei (`tools/pck_diff.py`) | **1 von 1.011 Dateien verschieden**: `scripts/race3d/layers/far_ground.gdc` (6.823 → 7.687 B), Linux und Windows gleich; keine Datei neu oder weg; der Programmteil vor dem Paket ist bis 991 B vor dessen Anfang byte-gleich |
| die neue `far_ground.gdc` (zstd entpackt mit Godot, Bezeichner gelesen: `gdc_strings.gd`, `tokens_idents.py`) | enthält `lowest_water`, `WATER_MARGIN_M`, `water_y`, `target_height`, `window_rows` – die Behebung ist im Build; ein erfundener Name zur Gegenprobe fehlt wie erwartet |
| Nachbau: `godot --headless --export-pack` („Linux“ und „Windows Desktop“) aus dem sauberen Worktree auf `0ad9012`, verglichen mit den gelieferten Programmen (`tools/repro.sh`) | **1.010 von 1.011 Dateien MD5-gleich**, verschieden nur `project.binary` (1.667 → 1.812 B: Version 0.8.0-zs1 und Nutzerordner, die der Testbuild für den Export einsetzt) – der Build ist genau `0ad9012` |

Beanstandet wie schon bei QA-ZS1 (B3, unverändert): `SHA256SUMS` nennt auch die beiden nackten Programme, die nicht
geliefert werden – `sha256sum -c SHA256SUMS` ohne Schalter meldet zweimal „FAILED open or read“ (Befund B4).

## 2. Linux-Export unter Xvfb (gemessen; Bilder angesehen)

Aufrufe: `tools/xshot.sh` / `tools/ab.sh` (Arcade und Modern mit denselben Argumenten, Arcade mit `--shot-fast`),
`xvfb-run … CrossingEurope-ZS1.x86_64 --rendering-driver opengl3 --audio-driver Dummy --resolution WxH --fixed-fps 60
-- --screenshot=… <Etappe> --graphics=arcade|modern --gfx-sync`; Limousine, Seed 11, Autopilot. Alle 29 Läufe aus dem Linux-Export Exit 0,
kein Skriptfehler, kein Rückfall auf Arcade. Bilder: `deliver/QA-WASSER/bilder/linux_*`.

### 2.1 Stehender Start Kiel – Hamburg bei km 0 („Mittel“, 1 s im Countdown, 1,5 s nach „LOS!“)

Das Auto steht im Countdown sichtbar an Arcades Platz: Lack-Rahmen (`carbox.py`) Arcade x 544–735, Modern x 544–736
(Countdown) bzw. 545–736, oben/unten 4–5 px weiter (das 3D-Modell ist etwas höher als das Bild); Starttor, Startlinie,
Schild „Tankstelle 15 km“ wie Arcade. Die frühere Behebung hält. (`linux_start_km0_*`)

### 2.2 Köhlbrandbrücke (km 78,0–80,6) bei Tag, „Hoch“, mit Verkehr

Zwei Läufe ab km 77,4 und 79,0 mit 80 km/h (HUD km 77,5 / 77,7 / 78,2 / 78,7 / 79,1 / 79,3 / 80,0 / 80,2 / 80,9).

- **Elbe unter und neben der Brücke wie in Arcade**: von der Rampe als breites Band quer durchs Bild, vom Deck aus auf
  beiden Seiten bis zum fernen Ufer. **Beide Fähren schwimmen** (Rumpf auf der Wasserlinie, `linux_koehlbrand_tag_hoch_km77_7_ab.jpg`).
- Wasser in Modern heller und grauer (spiegelt zum Horizont den Himmel), Arcade satter blau-grau. Fernes Ufer: Modern
  ein schmaler grüner Streifen, Arcade eine graue Kaimauer mit Grün dahinter.
- **Brückenende** (km 80,2, `…km80_2_brueckenende_ab.jpg`): Arcade zeigt beidseits die graue Kaimauer, Modern Wasser,
  das mit einem weichen Übergang in grünes Ufer übergeht – liest sich als flaches Ufer, nicht als Fehler; die Kaimauer
  gehört zum offenen Brückenbau („Uferwände“, R5).
- Keine Grube, keine Naht, kein Loch, kein heller oder schwarzer Saum am Wasser. Nach der Brücke (km 80,9) wieder
  Land wie Arcade, obwohl die Scheibe dort noch 5,3 m tiefer liegt (bis km 83,1) – nichts davon ist zu sehen.
- Unabhängig vom Wasser: Die **Pylonfüße** nah an der Kamera (km 78,7) wirken weißlich verwaschen und rundlich
  (`linux_koehlbrand_km78_7_pylonfuesse_modern_ausschnitt.jpg`) – Befund B2.

### 2.3 Köhlbrandbrücke nachts (22 Uhr), „Hoch“

Elbe dunkel wie in Arcade, die beleuchteten Fähren liegen auf dem Wasser, kein Saum am Ufer
(`…nacht_hoch_km77_7_ab.jpg`). Die **Pylone und Seile leuchten fast weiß** (`…km78_8`, `…km79_6`), Arcade zeigt sie
dunkelgrau – Befund B2. Die Elbphilharmonie ist nachts in Modern nicht zu erkennen (Arcade: beleuchtet).

### 2.4 Steam-Deck-Stufe („deck“, 1280 × 800), Tag und Nacht

Modern füllt 16:10, Arcade mit Balken. Elbe und Fähren wie bei „Hoch“; das Wasserband reicht hier 480 m, am Horizont
der grüne Streifen etwas breiter. Nachts wie „Hoch“ (Pylone grell). (`linux_koehlbrand_*deck*`)

### 2.5 Absenken der Scheibe (km 67,1) und Anfahrt ab km 76,5 – „springt der Boden?“

Gerechnet mit der Ebene selbst (`tools/probe_far.gd`: ihr eigenes `update()` an einem Stellvertreter der Fassade, wie
im Unit-Test, 1,5 m je Bild): Auf Kiel – Hamburg ist 1 Etappen-km = 100 m Weg. Die Köhlbrandbrücke kommt **bei km
67,08** ins geladene Fenster (1.092 m voraus); die Scheibe sinkt dann um 5,30 m in 15 m Weg (Schritt höchstens
0,525 m je 1,5 m = die erlaubte Steigung) und liegt bis km 83,08 tiefer, danach steigt sie ebenso wieder. Das
Absenken geschieht also **11 km (1,1 km Weg) vor der Brücke**, nicht auf der Anfahrt ab km 76,5 – dort liegt sie
schon unten.

- **Bildfolge um das Absenken** (ab km 66,8 mit 120 km/h, 14 Bilder 0,2–2,0 s, „Hoch“): Horizontstreifen
  (`linux_fernboden_sinkt_km66_8_bis_67_5_horizontstreifen_modern.jpg`) ruhig, kein Ruck; die Unterschiede von Bild zu
  Bild verlaufen wie bei Arcade (Bewegung; Verhältnis Modern/Arcade 1,16–1,44 ohne Ausreißer). Gegenprobe aus dem Projekt mit derselben Bildfolge, einmal mit dem alten `far_ground.gd` (`3a23cb8`), einmal mit dem neuen (`tools/baseline.sh`, `oldnew.py`): Bilder 0,2–1,1 s **pixelgleich**, ab 1,2 s nur die Zeilen 329–333 (5 Zeilen am Horizont) verschieden, 0,10–0,21 % der Bildpunkte über 8/255, höchstens 27–56/255; der Unterschied wächst über 0,3 s und bleibt dann gleich – **kein Sprung** (`bilder/projekt_fernboden_sinkt_alt_neu_differenz.jpg`: alt, neu, Unterschied × 4). (Projekt- und Exportbilder sind nicht pixelgleich, weil der Export über `--stage=` startet und das Projekt die Rennszene direkt – A-2; verglichen wird darum nur Projekt mit Projekt.)
- **Anfahrt ab km 76,5** (60 km/h, 10 Bilder 0,25–3 s): die Elbe ist als Band hinter den Wiesen durchgehend da, die
  Fähren darauf, nichts taucht auf oder springt (`linux_anfahrt_koehlbrand_km76_5_bis_77_1_streifen_modern.jpg`,
  `linux_anfahrt_koehlbrand_km76_8_ab.jpg`).

### 2.6 Elbbrücken (km 84,0–86,0)

Wasser beidseits wie Arcade, Fachwerkportale voraus; Arcade zeigt zusätzlich die seitlichen Fachwerkträger. Rechnerisch
liegt die Scheibe hier genau nach der alten Regel (Unterschied 0,00 m ab km 83,5; `probe_far.gd`) – das Bild ist also
dasselbe wie vor der Behebung (abgeleitet; FIX-WASSER hat es bitgleich gemessen). (`linux_elbbruecken_km84_7_ab.jpg`)

### 2.7 Zwei weitere tiefe Querungen

| Stelle | Ergebnis |
|---|---|
| **Holtenauer Hochbrücke** (16 m) auf **Kiel – Hamburg ab Hamburg** (nicht die Richtung, die FIX-WASSER zeigte), km 84,8–86,1 | Kanal sichtbar, die Fähre schwimmt. Vom Deck reicht das Wasser beidseits bis zum Horizont, dort ein olivbrauner Streifen; Arcade zeigt hinter dem Kanal grüne Böschung und Land (`linux_holtenau_ab_hamburg_km86_0_ab.jpg`) – liest sich in Modern wie ein See (Befund B3) |
| **Holtenau-Anfahrt** km 75,6–76,0: Scheibe **12,3 m** tiefer, Brücke noch nicht in Sicht (die stärkste Absenkung im Netz) | Stadtrand und Wiesen wie Arcade, Horizont ruhig, keine Grube (`linux_holtenau_anfahrt_*`). Alt gegen neu aus dem Projekt: nur die Zeilen 329–338 (10 Zeilen am Horizont), 0,12–0,23 % der Bildpunkte über 8/255, höchstens 26/255; vergrößert nicht zu unterscheiden (`bilder/projekt_holtenau_anfahrt_alt_neu_differenz.jpg`). |
| **Ada-Brücke** Belgrad (Save, 5 m), Slavonski Brod – Belgrad km 198,6–199,6 (von FIX-WASSER nicht im Bild) | Save beidseits wie Arcade, Schiff auf dem Wasser, Pylon mit Seilfächer. **Das Wahrzeichen (Kirche des Hl. Sava) fehlt in Modern** in allen drei Bildern, Arcade zeigt es groß rechts (`linux_belgrad_wahrzeichen_fehlt_in_modern_ausschnitt.jpg`) – Befund B1, nicht vom Wasser |

### 2.8 Löcher? Debug-Ansicht des Geländes am Wasser (gemessen, aus dem Linux-Export)

`--gfx-debug=cover,far` (Leinwand magenta, kein Nebel, Fernboden cyan, Kragen gelb; `tools/queue4.sh`, `cover_measure.py`): Köhlbrandbrücke km 77,6–79,0 mit der Steam-Deck-Stufe (1280 × 800, 4 Bilder) und „Hoch“ (4 Bilder), Holtenau-Anfahrt mit 12,3 m tieferer Scheibe (2 Bilder): **0 magenta Bildpunkte unter dem Horizont** in allen 10 Bildern (Horizontzeile 360 bzw. 324; an Holtenau verdecken Häuser den Himmel, dort mit fester Horizontzeile 324 und ohne die HUD-Kästen gemessen). Fernboden und Kragen nur als Linie am Horizont (an vier Bildern ohne HUD gemessen: cyan ≤ 0,09 %, gelb ≤ 0,29 %). (`bilder/linux_koehlbrand_deck_debug_cover_km78_1.jpg`, `bilder/linux_holtenau_anfahrt_debug_cover_km75_6.jpg`)

### 2.9 Bergstrecke mit engen Kurven (Saragossa – Pau km 198,8–200, T4 der Geländeprüfung)

Die Lücken, die der Fernboden schließt, lesen sich als Land: Wiesen bis zum Horizont, Tannen, Bodendecker, kein Loch,
keine Grube. Hier liegt kein Wasser im Fenster, die Scheibe liegt nach der alten Regel. Der große Fels, den Arcade auf
der Kurveninnenseite zeigt, fehlt in Modern (Sichtkorridor F7, angekündigt in `was_neu.md`). (`linux_pyrenaeen_t4_*`)

## 3. Windows-Export unter Wine (gemessen)

wine64 (`/usr/local/bin/wine64`), eigenes `WINEPREFIX` (`m1/QA-WASSER/wine/prefix`), `TMPDIR` leer, Pfade `Z:…`,
OpenGL 4.5 llvmpipe, `platform/windows`-Meldungen im Log (also wirklich die `.exe`). Gleiche Argumente wie die
Linux-Läufe:

| Lauf | Ergebnis |
|---|---|
| Köhlbrandbrücke Modern + Arcade, „Hoch“, ab km 79,0, 0,3 s und 2 s | Elbe unter und neben der Brücke, Fähre auf dem Wasser (`windows_wine_koehlbrand_km79_5_ab.jpg`); **pixelgleich** mit den Linux-Bildern derselben Zeiten (0 von 921.600 Bildpunkten verschieden, `oldnew.py`) |
| Start km 0 Modern + Arcade, „Mittel“, 1 s und 4,5 s | Auto im Countdown an Arcades Platz (`windows_wine_start_km0_*`); **pixelgleich** mit Linux |

`wineboot`/`wineserver` liegen hier nicht im `PATH` (nur unter `/usr/lib/wine/`); die Läufe brauchten sie nicht.

## 4. Code (gelesen, gemessen)

### 4.1 Diff `3a23cb8..0ad9012`

Acht Dateien: `scripts/race3d/layers/far_ground.gd` (die einzige Spieldatei), `tests/unit/race3d/test_far_ground_water.gd`
(+ `.uid`), `tests/golden/modern_slice.md5`/`.env` (nur S4 neu), `docs/qa-v080.md`, `docs/renderer-modern-gelaende.md`,
`docs/renderer-modern.md`. **Keine eingefrorene Arcade-Datei** (Regel 1), kein Shader, keine Konfiguration.

`far_ground.gd`: `far_y = min(tiefste Straße des Fensters − 4 m, tiefstes Wasser des Fensters − 0,3 m)`; das Wasser
wird Reihe für Reihe auf jeder Brücke im Fenster genommen, auf der Höhe, auf die `TerrainProfile` die Ringe legt
(`path.height(k) + min(water_level, 0)`). Geprüft:
- `TrackSegment.water` setzt nur `Track._mark_bridge()` für Reihen in `[z0, z1)` einer Brücke – andere Wasserreihen
  gibt es nicht, die Schleife über `Track.bridges` verpasst keine.
- Fenster wie bisher (`window_rows()` = der alte Ausschnitt von `lowest_road()`), Zeilen in `[path.first, path.last()]`,
  `s.index == k` fängt Umlauf ab; Kosten nur bei neuer Kamerazeile (≤ 5 Brücken, ≤ 87 Reihen).
- `ce_far_y` liest kein Shader (nur gesetzt) – die tiefere Lage ändert sonst nichts.
- Nichts davon wirkt auf die Simulation (Regel 3): die Ebene liest `track`/`path`, schreibt nur ihre Knoten.

### 4.2 Fairness (F7) – kann die tiefere Scheibe etwas verdecken oder zeigen?

**Verdecken: nein.** Die Scheibe liegt höchstens dort, wo sie vorher lag (`minf` mit der alten Regel), und vorher lag
sie schon unter jeder geladenen Straße. Was vorher sichtbar war, bleibt es. **Zeigen**: nur, was zwischen alter und
neuer Höhe liegt – die Wasserringe der Brückenreihen, die Fähren (`h` = −Tiefe), Pfeilerfüße und die Böschung am
Brückenende. Fahrzeuge, Schilder, Lampen und Fahrbahnkanten stehen alle auf geladenen Straßen, also über beiden
Höhen; an ihnen ändert sich nichts. Die Kurveninnenseiten-Regel (Gelände nie über der Straße im Sichtkorridor) betrifft
das Geländeband, nicht die Scheibe. Die Fairness-Tests (F1–F3, F7) laufen ohne die Scheibe; FIX-WASSER hat sie auf
`0ad9012` grün gemeldet (`run_tests.sh` 703/0) – ich habe den vollen Lauf nicht wiederholt.

### 4.3 Ist der neue Unit-Test ein echter Wächter? (gemessen, `tools/mutate_all.sh`, Logs `m1/QA-WASSER/mutate/`)

Je ein absichtlicher Fehler in `far_ground.gd` der Arbeitskopie, dann `tools/run_tests.sh test_far_ground_water`
(307 Skripte kompiliert, je 15 s), danach `git checkout` – Arbeitskopie wieder sauber:

| Fehler | Ergebnis | Meldung (Auszug) |
|---|---|---|
| M0 keiner (Gegenprobe) | 4/4 grün | – |
| M1 alte Regel (Wasser wird ignoriert) | **3 von 4 rot** | „km 78.95: Fernboden 3.52 m, tiefstes Wasser -1.48 m – … (liegt 5.00 m darüber)“ |
| M2 kein Abstand (`WATER_MARGIN_M` = 0, Scheibe auf der Wasserfläche: Z-Kampf) | **3 von 4 rot** | „… (liegt 0.00 m darüber)“ |
| M3 Springen statt Gleiten | **1 von 4 rot** (der Gleit-Test) | „kein Sprung: höchstens 0.52 m je Bild, gemessen 2.000 m“ |
| M4 Scheibe überall 0,5 m tiefer (nicht mehr die alte Regel) | **2 von 4 rot** | „km 2.00: Fernboden wie bisher …: erwartet -12.949 ± 0.00001, ist -13.449“ |

Der Test zählt das Wasser selbst aus der Strecke (nicht über `Track.bridges`) und rechnet das Fenster selbst – er
prüft also nicht die Behebung gegen sich selbst. Die Abweichung „`Camera3D` im Unit-Test“ (A-1) ist harmlos: ein
Knoten außerhalb des Baums, nur `position` wird gelesen, der Test läuft headless in Sekunden.

### 4.4 Arcade-Identität (gemessen, einmal, `XDG_DATA_HOME` eigen)

`tools/golden.sh check` auf `0ad9012`: **„GOLDEN arcade: 20 von 20 identisch“** (142 s), **„GOLDEN arcade-ui: 17 von 17
identisch“** (127 s), Exit 0 (274 s). Log `m1/QA-WASSER/gates/golden_check.log`.

### 4.5 Geländesperre (gemessen)

`tools/run_render_checks.sh modern terrain_cover`: **`check_terrain_cover.gd` OK** (54 s) – an T1, T2, T3, T4, S1, C1 je
**0,000 % Magenta** unter dem Horizont; Fernboden/Kragen T1 2,80 % + 2,52 %, T4 0,27 % + 1,67 %, C1 1,62 % + 0,16 %,
sonst 0 % – genau die Werte von FIX-WASSER (dort liegt kein Wasser, die Scheibe liegt wie vorher). Log
`m1/QA-WASSER/gates/render_terrain_cover.log`.

## 5. Nutzerdokumente (`deliver/FIX-WASSER/was_neu.md`, `steamdeck_checkliste.md`)

Schlichtes Deutsch, keine internen Kürzel (kein Paketname, kein Commit, kein „FIX“/„QA“). Gegen den Build geprüft:

| Aussage | geprüft |
|---|---|
| Version „v0.8.0-zs1“ unten rechts im Titel; eigener Nutzerordner Deck `~/.local/share/crossing-europe-zwischenstand/`, Windows `%APPDATA%\crossing-europe-zwischenstand\` | stimmt (`project.binary` im Paket; Titelbild im Erststart-Bild von FIX-WASSER, Titelcode unverändert) |
| Archiv = Programm + `LIZENZEN.txt`, Ausführbar-Recht bleibt | stimmt (1.) |
| Kiel – Nürnberg als Rennen, Leistungstest 3 Szenen à 20 s, „Klang“ (Wie Grafik/Arcade/Modern), „Musik im Rennen“, Absturzfrage-Text | stimmt (Daten und `tr()`-Texte gelesen) |
| Satz über Wiese statt Elbe | zu Recht entfernt – die Elbe ist da (2.2–2.4, 3.) |
| „Köhlbrandbrücke mit Geländer“ | stimmt, untertreibt (Pylone, Seilfächer) |
| „In **Bergetappen** sind die Kurveninnenseiten kahler …“ | weiter zu eng (QA-ZS1-B4 offen): trifft auch flache Etappen, links am Start von Kiel – Hamburg (B4) |
| Notfall: „Startargument `--graphics=arcade` (Steam: … `-- --graphics=arcade`; Windows: an das Ziel der Verknüpfung anhängen)“ | für Windows missverständlich: das Spiel liest nur Argumente **nach** `--` (`CliArgs` → `OS.get_cmdline_user_args()`); wer nur `--graphics=arcade` anhängt, startet weiter Modern (B4) |
| „dazu `SHA256SUMS` (Prüfsummen)“ | `sha256sum -c` ohne Schalter meldet FAILED für die nicht gelieferten Programme (QA-ZS1-B3 offen, B4) |
| nicht erwähnt | nachts grelle Pylone (B2), fehlende Wahrzeichen in sechs Städten (B1), Kanal/Fluss ohne Ufermauer (B3) |

## 6. Befunde

Kein Befund betrifft die Wasser-Behebung selbst; keiner ist ein Blocker. B1–B3 sind Bildmängel, die schon im vorigen
Build steckten (das Spielpaket ist bis auf `far_ground.gdc` gleich) bzw. erst sichtbar wurden, weil das Wasser jetzt
zu sehen ist; B4–B5 sind Text- und Werkzeugpunkte.

### B1 – mittel – In sechs Städten zeigt Modern kein Wahrzeichen

- **Wo:** `scripts/race3d/prop_library.gd` `_resolve()` und `scripts/race3d/builders/props.gd` (Fall „missing“);
  Ursache in den Daten: sechs `landmark_sets` in `data/cities.json` haben nur eine prozedurale Zeichnung (`proc`) und
  weder Sprite (`assets/sprites/manifest.json`) noch Modell (`assets/models/manifest.json`):
  `hram_svetog_save` (Belgrad), `neues_rathaus_hannover` (Hannover), `voelkerschlachtdenkmal` (Leipzig),
  `florianturm` (Dortmund), `phare_calais` (Calais), `cuatro_torres` (Madrid). `Track._build_landmark()` (eingefroren)
  streicht bei `proc` den `fallback`.
- **Was:** Arcade zeichnet diese Wahrzeichen prozedural (Kuppelkirche, Turm, Leuchtturm, Hochhäuser); Modern lässt sie
  weg. Der Kommentar in `props.gd` („Arcade skips it as well“) stimmt für sie nicht. Hannover liegt auf einem der zwei
  Wege des ersten Rennens Kiel – Nürnberg (und auf Wien – Hamburg, München – Bremen), Calais am Ziel von
  Bukarest – Calais.
- **Beleg:** gemessen in Belgrad: `bilder/linux_ada_bruecke_belgrad_km199_1_ab.jpg`,
  `bilder/linux_belgrad_wahrzeichen_fehlt_in_modern_ausschnitt.jpg` (drei Zeitpunkte, Arcade mit Kirche, Modern ohne).
  Die anderen fünf abgeleitet aus dem Datenabgleich (42 Wahrzeichen-Sets in `data/cities.json`, 6 ohne Sprite und ohne
  Modell). Schon im vorigen Build (Spielpaket-Vergleich, Abschnitt 1).
- **Nachstellen:** `tools/xshot.sh linux <out> 1280x720 modern --stage=slavonski_brod_belgrad --from=slavonski_brod
  --hour=12 --vehicle=limousine --seed=11 --autopilot --no-countdown --no-traffic --gfx-preset=high --start-km=198.6
  --start-speed=80 --shot-times=0.3,2,4` (und dasselbe mit `arcade`).
- **Behebung:** Im Props-Builder ein Wahrzeichen ohne Modell und Sprite mit dem `fallback` aus
  `CityData.landmark_info()` vertreten (Sprite `props/church` bzw. `props/building_tall`, `fallback_scale`,
  `fallback_tint`) – oder Arcades prozedurale Zeichnung einmal in eine Billboard-Textur rendern. Dazu ein Unit-Test:
  „jedes Wahrzeichen aus `data/cities.json` ist in Modern Modell oder Vertretung“. Für diesen Testbuild genügt ein Satz
  in `was_neu.md` (B4).

### B2 – mittel – Köhlbrandbrücke: Pylone nachts fast weiß, Pylonfüße bei Tag verwaschen

- **Wo:** der prozedurale Pylon der Schrägseilbrücke (`prefer_proc` „pylon“) mit seinem Material und dem Licht der
  Brückenlampen (Besitz Brücke/Licht, R4/R5).
- **Was:** Um 22 Uhr leuchten Pylone und Seile fast weiß und überstrahlt, Arcade zeigt sie dunkelgrau. Bei Tag wirken
  die Pylonfüße nah an der Kamera weißlich, weich und rundlich. Ursache nicht untersucht (abgeleitet: Lampen-/Poollicht
  oder Emission am Pylon).
- **Beleg (gemessen):** `bilder/linux_koehlbrand_nacht_hoch_km78_8_ab.jpg`, `…km79_6_ab.jpg`,
  `bilder/linux_koehlbrand_nacht_deck_1280x800_km78_1_ab.jpg`, `bilder/linux_koehlbrand_km78_7_pylonfuesse_modern_ausschnitt.jpg`.
  FIX-WASSER hat das Nachtbild ebenso gesehen.
- **Nachstellen:** `tools/ab.sh linux <out> 1280x720 "…" --stage=kiel_hamburg --from=kiel --hour=22 --vehicle=limousine
  --seed=11 --autopilot --no-countdown --traffic-warmup --gfx-preset=high --start-km=77.6 --start-speed=80
  --shot-times=0.3,2,4,6`.
- **Behebung:** Mit `--gfx-debug=nolight` gegenprüfen, woher das Licht kommt; den Beitrag der Lampen/Pools am Pylon
  begrenzen (Pylonhelligkeit nachts am Arcade-Grau messen); Fuß-Geometrie und Normalen des Pylons prüfen.

### B3 – niedrig – Ufer an hohen Brücken: keine Kaimauer, keine Böschung

- **Wo:** Brückenbau (R5, „Uferwände“ noch offen) und die Uferreihen des Geländes (R2).
- **Was:** Am Ende der Köhlbrandbrücke zeigt Arcade eine graue Kaimauer, Modern Wasser mit weichem Übergang in grünes
  Ufer; an der Holtenauer Hochbrücke zeigt Arcade hinter dem Kanal grüne Böschung, Modern Wasser bis zum Horizont mit
  olivbraunem Streifen – der Kanal wirkt wie ein See. Erst sichtbar, seit das Wasser nicht mehr verdeckt ist; kein
  Rückschritt, kein Loch (2.8).
- **Beleg (gemessen):** `bilder/linux_koehlbrand_tag_hoch_km80_2_brueckenende_ab.jpg`,
  `bilder/linux_holtenau_ab_hamburg_km86_0_ab.jpg`.
- **Behebung:** Kaimauern/Böschungen im Brückenbau; ein fernes Ufer bzw. Fernwasser im Fernboden (Vertragsfrage 3).

### B4 – niedrig – Nutzerdokumente: drei ungenaue Stellen, drei Lücken

- **Wo:** `deliver/FIX-WASSER/was_neu.md`, `deliver/FIX-WASSER/steamdeck_checkliste.md`, `build/SHA256SUMS`.
- **Was und Behebung (Sätze zum Einsetzen):**
  1. `was_neu.md`, Bergetappen (QA-ZS1-B4, offen): „Vor und in Kurven fehlen auf der Innenseite noch Bäume und Felsen
     (absichtlich, damit nichts die Sicht nimmt) – auch auf flachen Etappen, z. B. links am Start von Kiel – Hamburg;
     Bodendecker kommen noch.“
  2. Checkliste, Notfall: das Spiel liest Startargumente nur **nach** `--` (`scripts/core/cli_args.gd` →
     `OS.get_cmdline_user_args()`); für Windows schreiben: „Windows: an das Ziel der Verknüpfung
     ` -- --graphics=arcade` anhängen (mit den zwei Strichen davor, wie bei Steam).“
  3. `SHA256SUMS` nennt zwei nicht gelieferte Dateien – `sha256sum -c SHA256SUMS` meldet „FAILED open or read“ (QA-ZS1-B3,
     offen): in der Checkliste `sha256sum -c --ignore-missing SHA256SUMS` nennen oder `tools/build_testbuild.sh` die
     Summen nur der gelieferten Dateien schreiben lassen.
  4. `was_neu.md`, „Was noch fehlt“, ergänzen: „Nachts leuchten die Pylone der Köhlbrandbrücke noch viel zu hell.“ –
     „In Belgrad, Hannover, Leipzig, Dortmund, Calais und Madrid fehlt in Modern noch das Wahrzeichen.“ – „An hohen
     Brücken fehlen noch Kaimauern und Böschungen; hinter breiten Flüssen zeigt der Horizont einen Streifen Wiese statt
     des fernen Ufers.“
- **Beleg:** Texte gelesen, Code gelesen (`cli_args.gd` Zeile 13), `sha256sum -c` wie bei QA-ZS1; Bilder zu 4 oben.

### B5 – niedrig – Werkzeuge: alte Regel in der Draufsicht, keine Render-Prüfung am Wasser

- **Wo:** `tests/race3d/check_terrain_plan.gd` Zeile 350 (`--dump` schreibt `far_y` = tiefste Straße − 4 m);
  `tests/race3d/render/check_terrain_cover.gd` (T1–T4, S1, C1 – keine Position mit Wasser).
- **Was:** Die Draufsicht-Daten zeigen an tiefen Brücken eine falsche Scheibenhöhe (nur Debug); ein Rückfall der
  Behebung im Bild würde keine Render-Prüfung rot machen (der Unit-Test bewacht die Rechnung, 4.3).
- **Beleg:** Code gelesen; meine Messung 2.8 zeigt, dass die Prüfung an der Köhlbrandbrücke grün wäre (0 Löcher).
- **Behebung:** `check_terrain_plan.gd` über `FarGround.target_height()` rechnen; in `check_terrain_cover.gd` eine
  Position „Köhlbrandbrücke km 78,1“ (Kiel – Hamburg ab Kiel, Deck-Stufe) mit der Grenze 0,2 % Magenta aufnehmen.

## 7. Geprüft und in Ordnung

- Prüfsummen der Archive und von `LIZENZEN.txt` (OK); Archivinhalt genau Programm + `LIZENZEN.txt`, Ausführbar-Recht im
  Linux-Archiv; Größen wie berichtet (gemessen).
- `BUILDINFO.txt`: Commit `0ad9012…`, 0.8.0-zs1, Nutzerordner `crossing-europe-zwischenstand`; dieselben Werte im
  eingebetteten `project.binary` (gemessen).
- Der Build ist genau `0ad9012`: frischer Export des Spielpakets aus dem sauberen Worktree = gelieferte Pakete in
  1.010 von 1.011 Dateien, anders nur `project.binary` (Testbuild-Einstellungen); gegen den vorigen Build nur
  `far_ground.gdc` anders (gemessen).
- Start Kiel – Hamburg bei km 0: Auto im Countdown sichtbar an Arcades Platz (Rahmen ±1 px quer, ≤ 5 px hoch), auch
  1,5 s nach „LOS!“, Linux und Windows (gemessen).
- Köhlbrandbrücke km 77,5–80,9, Tag und Nacht, „Hoch“ und „deck“: Elbe unter und neben der Brücke, Fähren auf dem
  Wasser, keine Grube, keine Naht; 0 Löcher unter dem Horizont in der Debug-Ansicht (gemessen).
- Absenken der Scheibe bei km 67,1: kein Sprung – gegen den alten Stand ändern sich nur 5 Zeilen am Horizont, ≤ 0,21 %
  der Bildpunkte, allmählich über 0,3 s (gemessen); Gleiten mit höchstens 0,35 m je Meter (gerechnet mit der Ebene).
- Anfahrt ab km 76,5: Elbe durchgehend sichtbar, nichts springt (gemessen).
- Elbbrücken: Wasser wie Arcade; Scheibe dort exakt alte Regel (gerechnet).
- Holtenau-Anfahrt mit 12,3 m tieferer Scheibe: alt gegen neu nur 10 Zeilen am Horizont, ≤ 0,23 %, mit dem Auge nicht zu
  unterscheiden; 0 Löcher (gemessen).
- Holtenauer Hochbrücke (ab Hamburg) und Ada-Brücke Belgrad: Wasser und Schiffe sichtbar (gemessen).
- Bergstrecke T4 (Pyrenäen): Lücken lesen sich als Land; Geländesperre an T1–T4, S1, C1 0,000 % Magenta (gemessen).
- Windows-Export unter Wine: Köhlbrandbrücke und Start pixelgleich mit dem Linux-Export (gemessen).
- Diff `3a23cb8..0ad9012`: nur die acht vorgesehenen Dateien, keine Arcade-Datei; die Scheibe liegt nie höher als
  vorher, kann also nichts verdecken (F7); keine Rückwirkung auf die Simulation (gelesen).
- Unit-Test `test_far_ground_water.gd`: 4/4 grün; erkennt alle vier eingebauten Fehler (gemessen).
- Arcade-Identität: `tools/golden.sh check` 20 von 20 und 17 von 17 identisch (gemessen).
- Nutzerdokumente: Dateinamen, Version, Nutzerordner, Menüpunkte, Leistungstest, Rennen Kiel – Nürnberg, Absturzfrage
  stimmen; schlichtes Deutsch, keine internen Kürzel.

## 8. Bild gegen Arcade (ehrlich)

- **Köhlbrandbrücke, Tag**: vorher deutlich schlechter (Wiese statt Elbe), jetzt **gleichwertig bis etwas besser**:
  echte Pylone, Seilfächer, Geländer, Schatten, die Elbe in Arcades Ausdehnung, Fähren auf dem Wasser. Nicht deutlich
  besser: Wasser glatt und blass, kein fernes Ufer und keine Kaimauer, Pylonfüße nah verwaschen.
- **Köhlbrandbrücke, Nacht**: Wasser richtig, aber die fast weiß leuchtenden Pylone sind ein Fremdkörper – hier ist
  Modern **schlechter** als Arcade, solange das Licht nicht gezähmt ist.
- **Steam-Deck-Stufe**: wie „Hoch“, 16:10 gefüllt, etwas weniger Fernsicht – gleichwertig.
- **Elbbrücken**: gleichwertig (Arcade mit seitlichen Fachwerkträgern, Modern ohne).
- **Holtenau**: Wasser statt Boden – vorher klar schlechter, jetzt gleichwertig beim Kanal, aber ohne Böschung wirkt
  der Kanal wie ein See bis zum Horizont.
- **Belgrad**: Save gut, aber ohne das Wahrzeichen **schlechter** als Arcade (B1).
- **Pyrenäen T4**: Gelände und Bäume schöner als Arcade, die Kurveninnenseite kahler (angekündigt).

## 9. Dateien

- Bericht und Bilder: `deliver/QA-WASSER/bericht.md`, `deliver/QA-WASSER/bilder/` (Linux- und Windows-Export,
  Ausschnitte, Bildfolgen).
- Arbeitsdateien: `m1/QA-WASSER/` – `STAND.md`; Werkzeuge `tools/` (`xshot.sh`, `ab.sh`, `queue1–4.sh`, `probe_far.gd`,
  `pck_extract.py`, `pck_diff.py`, `gdc_strings.gd`, `tokens_idents.py`, `carbox.py`, `seq_diff.py`, `oldnew.py`,
  `cover_measure.py`, `mutate.py`, `mutate_all.sh`, `baseline.sh`, `repro.sh`, `deliver_pics.sh`); Bilder `shots/`,
  `shots_win/`, `shots_base/`, `shots_cover/`; Logs `queue*.log`, `gates/`, `mutate/`.
- Nichts committet, nichts gepusht; die Arbeitskopie ist sauber.

## 10. Abweichungen, Vertragsfragen, für die Nächsten

**Abweichungen**
1. Bilder aus den Exporten mit `--fixed-fps 60 -- --gfx-sync` (FIX-WASSER ohne): so bleiben „Hoch“ und „deck“ stehen
   (sonst senkt der Wächter auf der Software-Grafik auf „Niedrig“) und Arcade und Modern zeigen dieselben Zeitpunkte.
   Ein Spieler startet ohne diese Schalter – das Bild ist dasselbe, nur in Echtzeit.
2. Statt „Kiel – Hamburg km 76,5“ zusätzlich die Stelle, an der die Scheibe wirklich sinkt (km 67,1): 1 Etappen-km sind
   dort 100 m Weg, die Brücke kommt 11 km vorher ins Fenster.
3. Den vollen `tools/run_tests.sh` habe ich nicht wiederholt (FIX-WASSER: 703/0 auf demselben Commit); geprüft habe ich
   den neuen Test mit fünf Varianten, die Arcade-Identität und die Geländesperre.

**Vertragsfragen**
1. D16 und A-3 beschreiben die Scheibe noch als „tiefste Straße − 4 m“; umgesetzt und richtig ist min(…, tiefstes
   Wasser − 0,3 m) – nachtragen (wie FIX-ZS1 und FIX-WASSER).
2. Landmarken mit nur prozeduraler Zeichnung (`landmark_sets` mit `proc`, ohne Sprite und Modell) hat der Vertrag
   keinem Modern-Besitzer gegeben; `builders/props.gd` behauptet „Arcade skips it as well“ – Arcade zeichnet sie (B1).
3. Fernwasser und Ufer (Kaimauer, Böschung) haben keinen klaren Besitzer zwischen R2 (Gelände/Fernboden) und R5
   (Brücke: „water plane“, Uferwände).

**Für die Nächsten**
1. B1: Wahrzeichen der sechs Städte in Modern zeigen (Fallback-Sprite aus `landmark_sets` oder Arcades Zeichnung als
   Billboard) und ein Test „jedes Wahrzeichen der Daten ist Modell oder Vertretung“.
2. B2: Pylonlicht nachts und Pylonfüße (R4/R5).
3. B3: Kaimauer/Böschung am Brückenende und Fernwasser (R5/R2).
4. Eine Render-Prüfung mit `--gfx-debug=cover,far` an der Köhlbrandbrücke würde die Behebung im Bild bewachen
   (die Positionen von `check_terrain_cover` haben kein Wasser) – meine Messung mit dem Export (2.8) zeigt den Weg: Position „Köhlbrandbrücke km 78,1“ in `check_terrain_cover.gd`, Grenze 0,2 % Magenta (B5).
5. `tests/race3d/check_terrain_plan.gd -- --dump` schreibt `far_y` noch mit der alten Regel (Zeile 350, nur Debug-Daten).

