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
| {{REPRO_ROW}} |

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
  Bild verlaufen wie bei Arcade (Bewegung; Verhältnis Modern/Arcade 1,16–1,44 ohne Ausreißer). {{BASELINE_SENK}}
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
| **Holtenau-Anfahrt** km 75,6–76,0: Scheibe **12,3 m** tiefer, Brücke noch nicht in Sicht (die stärkste Absenkung im Netz) | Stadtrand und Wiesen wie Arcade, Horizont ruhig, keine Grube (`linux_holtenau_anfahrt_*`). {{BASELINE_HOLT}} |
| **Ada-Brücke** Belgrad (Save, 5 m), Slavonski Brod – Belgrad km 198,6–199,6 (von FIX-WASSER nicht im Bild) | Save beidseits wie Arcade, Schiff auf dem Wasser, Pylon mit Seilfächer. **Das Wahrzeichen (Kirche des Hl. Sava) fehlt in Modern** in allen drei Bildern, Arcade zeigt es groß rechts (`linux_belgrad_wahrzeichen_fehlt_in_modern_ausschnitt.jpg`) – Befund B1, nicht vom Wasser |

{{COVER_SECTION}}

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

{{BEFUNDE}}

## 7. Geprüft und in Ordnung

{{OK}}

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
   (die Positionen von `check_terrain_cover` haben kein Wasser) – {{COVER_NOTE}}
5. `tests/race3d/check_terrain_plan.gd -- --dump` schreibt `far_y` noch mit der alten Regel (Zeile 350, nur Debug-Daten).
