# QA-ZS1 – Unabhängige Prüfung des neu gebauten Testbuilds „Zwischenstand 1“ (v0.8.0-zs1 aus `3a23cb8`)

Für die Leitung. Reine Prüfrolle: kein Commit, kein Push, kein eigener Branch. Worktree
`/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9559b070-4dd-2` (fast-forward auf `3a23cb8`,
für die Bruchtests kurz verändert und danach aus git wiederhergestellt; `git status` leer). Kein Vorgänger gefunden.
„gemessen“ = auf dieser VM (Mesa llvmpipe unter Xvfb, 4 geteilte Kerne, andere Pakete liefen parallel); alles über
Steam Deck, echte Grafikkarten, ANGLE/Direct3D und Klang ist **abgeleitet**. Geprüft habe ich die **gelieferten**
Dateien aus `deliver/FIX-ZS1/build/` (kopiert, entpackt), keinen eigenen Build.

## Urteil

**Der Testbuild darf heute zum Nutzer – kein Blocker.** Der Startfehler QA1-B1 ist im ausgelieferten Linux- und
Windows-Export behoben, und nichts, was ich geprüft habe, ist kaputt:

- **Start:** Das Auto steht im Countdown und nach „LOS!“ an Arcades Stelle in Arcades Größe (Kanten ≤ 1 % bis
  LOS + 1,5 s). Das Starttor folgt Arcade über 1–5 s auf ≤ 5 px, die Kamera springt nicht. Straße und Boden reichen
  bis zum Bildrand. Gemessen an Kiel – Hamburg und vier weiteren Starts (Steigung, Stadtrand, Regen, Nacht + Schnee),
  dazu einmal 1280 × 800 mit „Steam Deck“.
- **Erster Start wie ein Spieler:** „GRAFIK WÄHLEN“ → Modern → Titel „v0.8.0-zs1“ → Rennen → Countdown mit Auto → Pause.
- **Menüs der Testanleitung:** Optionen beider Seiten und der Leistungstest über die Menüs funktionieren.
- **Windows unter Wine:** Modern und Arcade starten; die Bilder sind pixelgleich mit dem Linux-Export.
- **Nichts nebenbei verändert:** Bei km 2 ist Modern bitgleich mit dem alten Build. Arcade ist bildgleich
  (golden 20/20 und 17/17).
- **Code:** Der Diff berührt nur die beabsichtigten Dateien, keine eingefrorene. Die neue Render-Prüfung ist ein
  echter Wächter: Jeder der drei absichtlichen Brüche wird rot.

**Bildlich ist Modern am Start gleichwertig, nicht deutlich besser als Arcade.**

- **Besser:** Gelände mit Feldern und Tiefe, echte Schatten, Leitplankenpfosten, ein körperliches Starttor; nachts
  leuchtet die START-Schrift.
- **Schlechter, neu erklärt (QA-ZS1-B2):** An drei von vier Tagesstarts fehlen links große Bäume, darunter die Eiche
  am Start von Kiel – Hamburg. Ursache ist der Sichtkorridor F7: Er hält die ganze gerade Startstrecke vor einer
  Linkskurve bei 140–160 m für die Kurveninnenseite.
- **Schlechter, bekannt:** kein Regen, kein Schneefall, keine Sonnenscheibe.
- **Bestätigt im Export (QA-ZS1-B1, hoch):** Unter der Köhlbrandbrücke zeigt Modern Wiese statt Elbe. Das steht
  ehrlich in `was_neu.md`; die Testanleitung schickt den Nutzer genau dorthin (C.3). Eine Behebung vor der Auslieferung
  wäre besser, ist aber keine Bedingung.

Die Dokumente stimmen für diesen Build; kein Schritt der Testanleitung scheitert. Zwei kleine Textkorrekturen schlage
ich vor (B3, B4).

## 1. Gelieferte Dateien (gemessen)

| Prüfung | Ergebnis |
|---|---|
| `sha256sum -c --ignore-missing SHA256SUMS` | beide Archive und `LIZENZEN.txt` **OK** |
| `sha256sum -c SHA256SUMS` (ohne Schalter, wie ein Nutzer es tippt) | **Exit 1**: „CrossingEurope-ZS1.x86_64: FAILED open or read“, ebenso `.exe`, „WARNING: 2 listed files could not be read“ – die Datei nennt die nackten Programme, die nicht mitgeliefert werden (QA-ZS1-B3) |
| Inhalt `CrossingEurope-ZS1-linux-x86_64.tar.gz` (146 919 755 B = 140,1 MiB) | genau `CrossingEurope-ZS1.x86_64` (440 692 144 B, `-rwxr-xr-x`) + `LIZENZEN.txt` (113 873 B), kein Unterordner |
| Inhalt `CrossingEurope-ZS1-windows-x86_64.zip` (156 564 758 B = 149,3 MiB) | genau `CrossingEurope-ZS1.exe` (476 470 912 B) + `LIZENZEN.txt` |
| Programme gegen `SHA256SUMS` | entpackt `bc147ee4…b8` (Linux) und `f6e2b703…92` (Windows) = die Einträge; `LIZENZEN.txt` in beiden Archiven = die gelieferte |
| `BUILDINFO.txt` | Commit `3a23cb8dad346b623118fc0bcab9c0ffaea1efbf`, Testbuild 0.8.0-zs1, Windows-Version 0.8.0.1, Nutzerordner `crossing-europe-zwischenstand`, Godot 4.7.2 – stimmt |
| Im Programm selbst | eingebettetes `project.binary`: `application/config/version` = `0.8.0-zs1`, `custom_user_dir_name` = `crossing-europe-zwischenstand` (beide Programme); `.exe`: Versionsressource 0.8.0.1, Icon mit 7 Größen, PCK eingebettet (`tools/windows/inspect_exe.py`) |
| Laufzeit | Titel zeigt **v0.8.0-zs1**; Linux schreibt nach `$XDG_DATA_HOME/crossing-europe-zwischenstand/` (`settings.json`, `savegame.json` mit `game_version` 0.8.0-zs1, `leistungstest.json`, `logs/godot.log`, `shader_cache/`); Windows nach `drive_c/users/root/AppData/Roaming/crossing-europe-zwischenstand/` (= `%APPDATA%\crossing-europe-zwischenstand\`) |

## 2. Linux-Export unter Xvfb

Alle Läufe mit dem gelieferten `CrossingEurope-ZS1.x86_64`, je Lauf ein frisches, absolutes `XDG_DATA_HOME`, ein
Godot-Lauf zur Zeit. Alle Läufe Exit 0, kein `SCRIPT ERROR`, keine `ERROR`-Zeile, kein Rückfall auf Arcade.

### 2.1 Erster Start wie ein Spieler (gemessen, `erststart_linux_ablauf.jpg`, `erststart_linux_countdown_modern.jpg`)

Ohne Argumente, Bildschirm 1280 × 800, Tastatur über xdotool (`m1/QA-ZS1/walk.sh`): **„GRAFIK WÄHLEN“** erscheint
(Arcade vorgewählt mit „EMPFOHLEN FÜR DIESEN RECHNER“ und dem Hinweis „Software-Grafik“ – richtig für llvmpipe),
▶ → Modern, Enter → Titel mit **„v0.8.0-zs1“** unten rechts → Rennen starten → Kiel – Nürnberg → Limousine → 08:00 →
Etappe 1 Kiel – Hamburg → Start → „Etappe wird geladen …“ mit Balken → **Countdown in Modern mit dem Auto an seinem
Platz**, Starttor, Startlinie, „Tankstelle 15 km“ → Pause-Menü (Weiterfahren / Etappe neu starten / Aufgeben).
`settings.json`: `"graphics_mode":"modern"`.
Zum Prüfaufbau: Xvfb hat keinen Fenstermanager. Das Spiel bleibt deshalb ein 1280 × 720-Fenster mit Balken. Die
Tastatur erreicht es erst mit `xdotool windowfocus`; mein erster Versuch lief daran ins Leere, ein Fehler des Aufbaus,
nicht des Spiels. Auf dem Deck schaltet das Spiel unter gamescope selbst auf Vollbild (`Settings.default_fullscreen`,
Code gelesen). 16:10 zeigt Abschnitt 2.6.

### 2.2 Stehender Start Kiel – Hamburg, Modern gegen Arcade (gemessen, `start_kiel_hamburg_linux_export_ab.jpg`)

Export mit `--fixed-fps 60 -- --stage=kiel_hamburg --from=kiel --hour=12 --vehicle=limousine --seed=11 --autopilot
--gfx-preset=medium --gfx-sync --audio-sync`. Der Verkehr ist wie im Spiel. Je Modus ein Lauf.
Bildzeiten: 1,0 und 2,9 s im Countdown (er dauert 3 s), dann 3,2 / 3,4 / 3,7 / 4,0 / 4,5 / 5,0 / 5,5 / 6,0 / 7,0 s
(LOS + 0,2 … 4 s).
Messung mit eigenen Skripten: `m1/QA-ZS1/boxes.py` misst die Lackfläche nach der Regel von `check_start_km0`,
`gate.py` das dunkle START-Banner.

| Moment | Auto: Kanten L/R/O/U Modern gegen Arcade | START-Banner: Kanten L/R/O/U gegen Arcade |
|---|---|---|
| 1,0 s Countdown | +0,0/+0,5/0,0/0,0 % (Box 192 × 238 px mit Pausen-Hinweis) | 0/0/−1/0 px |
| 2,9 s Countdown-Ende | +0,0/+0,5/0,0/0,0 % | 0/0/−1/0 px |
| LOS + 0,2 / 0,4 s | ≤ 0,5 % | ≤ 1 px |
| LOS + 0,7 s | +0,0/+0,5/−0,5/+0,5 % | −1/+2/0/−1 px |
| LOS + 1,0 s | +0,0/+1,0/−0,5/+0,5 % | −2/+2/+1/−1 px |
| LOS + 1,5 s | +0,0/+1,0/−0,5/+0,5 % | −3/+2/−1/0 px |
| LOS + 2,0 s (die Kamera wechselt vom Vorlauf auf den Pfad) | +0,5/+1,0/−0,5/0,0 % | 0/+5/−2/−2 px |
| LOS + 2,5 / 3,0 s | ≤ 2,1 % | Banner oben aus dem Bild |
| LOS + 4 s | +3,1/+4,2/−0,5/+0,5 % (die Kurvenkamera schaut schon in die Linkskurve ab 138 m – an jeder Stelle so) | – |

Ergebnis: Das Spielerauto steht im Countdown und nach „LOS!“ an Arcades Stelle in Arcades Größe.
Das Starttor wächst in beiden Modi Bild für Bild gleich: 531 → 533 → 540 → 562 → 600 → 721 → 922 px breit.
Es gibt also **keinen Kamerasprung**, auch nicht zwischen LOS + 1,5 und 2,0 s, wo die Kamera z = 0 überfährt.
Straße, Bankett und Gelände reichen in jedem Bild bis zum unteren Rand, hinter und neben dem Auto.
Starttor, Startlinie, Schild „Tankstelle 15 km“ und 120er-Schild stehen wo bei Arcade. Die Countdown-Lampen schalten
gleich: rot, bei „LOS!“ grün.

### 2.3 Vier weitere Starts (gemessen, `start_*_ab.jpg`)

Ich habe bewusst andere Etappen als FIX-ZS1 gewählt (dort Ljubljana, Köln, Pau): Steigung, Stadtrand mit anderem
Auto, Regen, Nacht + Schnee. Eine Kurve oder City Limits direkt am Start gibt es im Netz nicht (Calm-Zone 40 m;
FIX-ZS1-Scan über alle 128 Etappenrichtungen).

| Start | Art | Auto (Kanten, 1 s Countdown / LOS + 1,5 s) | Starttor | Bild |
|---|---|---|---|---|
| Passau – Regensburg ab Passau, 12 Uhr | stärkste Steigung am Start im Netz (+15,8 m auf 300 m), Waldhügel | ≤ 0,5 % / ≤ 0,5 % | L/O/U ≤ 5 px | gleichwertig: Eichen und Fichten wie Arcade, die Straße steigt gleich |
| Paris – Tours ab Paris, 15 Uhr, **Kompakt** | Industrie-Stadtrand (Fabrik, Schlote, Masten) | L/R/U ≤ 1 px (0,6 %); die Oberkante liegt 30 px höher – das Kompakt-Modell hat ein gelbes Dach, das Bild ein graues | ≤ 4 px | Auto an seinem Platz; **links fehlen zwei Bäume** (QA-ZS1-B2) |
| Hamburg – Hannover ab Hamburg, Regen, 16 Uhr | Regen | ≤ 0,8 % / ≤ 2,6 % | ≤ 3 px | Auto an seinem Platz; **kein Regen in der Luft** (bekannt), **links fehlt eine Baumgruppe** (B2) |
| Warschau – Białystok ab Warschau, Schnee, 22 Uhr | Nacht, Schnee | im Bild gleich (Farbmaske nachts nicht messbar) | im Bild gleich | Rücklichter, Scheinwerferkegel, Starttor-Lampen wie Arcade; die START-Schrift leuchtet in Modern, in Arcade ist sie grau; **kein Schneefall** (bekannt) |

### 2.4 Fliegender Start bei km 2: alter gegen neuen Build (gemessen)

Aufruf: `-- --stage=kiel_hamburg --from=kiel --start-km=2 --start-speed=120 --no-countdown --traffic-warmup --hour=12
--gfx-preset=medium --gfx-sync` mit `--fixed-fps 60`, Modern, Bilder bei 1 s und 3 s.
Einmal mit dem gelieferten Build (`3a23cb8`), einmal mit dem alten aus `deliver/gate1/build/` (`10d836f`).
Ergebnis: **beide PNG-Bilder MD5-gleich, 0 Pixel Unterschied** (`compare -metric AE` = 0). Bei km > 0 hat sich
nichts geändert.

### 2.5 Menüs der Testanleitung (gemessen, `menues_optionen_leistungstest.jpg`)

Frischer Nutzerordner, Tastatur (`m1/QA-ZS1/walk_options.sh`): Auswahl → Modern → Titel → **Optionen**.

- Seite **ALLGEMEIN**: „Klang“ (Wie Grafik), „Musik im Rennen“ (An), Vibration. Die Fußzeile nennt „Bild ↑ / Bild ↓,
  LB, RB = Seite“.
- Bild ↓ → Seite **GRAFIK**: Grafik (Modern), Vollbild, „Voreinstellung“ (hier „Niedrig“, weil Software-Grafik),
  Schatten, Details, Auflösung, Kantenglättung, Effekte und **„Leistungstest“**.
- **Leistungstest starten** fährt 3 Szenen zu je 20 s (gemessen 20,2 / 20,7 / 20,3 s) und zeigt die Ergebnisseite mit
  Tabelle, Vorschlag und „Gespeichert als: …/crossing-europe-zwischenstand/leistungstest.json“.
- Die Datei ist geschrieben: `game_version` 0.8.0-zs1, `preset` low, `tier` software, Vorschlag Arcade
  (5,2 / 1,6 / 3,4 Bilder/s auf llvmpipe – für echte Grafik bedeutungslos).

### 2.6 Steam-Deck-Format 1280 × 800 mit „Steam Deck“ (gemessen, `start_kiel_1280x800_preset_steamdeck_ab.jpg`)

Export mit `--resolution 1280x800` und `--gfx-preset=deck`, 08 Uhr. **Modern füllt 16:10, Arcade behält die
Balken.** Das Auto steht im Countdown und bei LOS + 1,5 s an seinem Platz, mit Schatten (Schattenstufe 1).
Links fehlt auch hier die große Eiche (B2).

### 2.7 Köhlbrandbrücke (gemessen, `koehlbrandbruecke_km78_6_linux_export_ab.jpg`)

Aufruf: `--start-km=78.0 --start-speed=60 --no-countdown --no-traffic`, Bild bei 2,5 s (km 78,6), „Mittel“.

- **Arcade** zeigt beidseits der Brücke Wasser.
- **Modern** zeigt grüne Wiese bis zum Horizont, unter Pylonen und Seilen.

Damit stimmt der Satz in `was_neu.md` für diesen Build, und der Befund FIX-ZS1-B1 ist im ausgelieferten Export
bestätigt (QA-ZS1-B1).

## 3. Windows-Export unter Wine (gemessen, `wine_windows_start.jpg`)

`wine64` mit eigenem Präfix, `TMPDIR` nicht gesetzt, Pfade `Z:…`; `wineboot` dauerte 7 s
(`m1/QA-ZS1/wine_run.sh`). Gleiche Argumente wie in 2.2, Bilder bei 1 s und 4,5 s.

- **Modern:** Exit 0, 272 s, OpenGL 4.5 über Mesa, kein Rückfall. **Das Auto steht im Countdown an seinem Platz.**
- **Arcade:** Exit 0, 38 s.
- **Alle vier Wine-Bilder sind pixelgleich mit den Linux-Export-Bildern derselben Zeit** (`compare -metric AE` = 0).
- Nutzerordner: `…/AppData/Roaming/crossing-europe-zwischenstand/` mit `logs/` und `shader_cache/`.
- ANGLE/Direct3D ist hier nicht prüfbar (abgeleitet).

## 4. Code

### 4.1 Der Diff `92ece73..3a23cb8` (gelesen)

13 Dateien:

- **Spieldateien (5):** `scripts/race3d/road_path.gd`, `chunk_streamer.gd`, `chunk_context.gd`, `layers/vehicles.gd`,
  `builders/gantry.gd`.
- **Neue Tests (2):** `tests/unit/race3d/test_start_lead_in.gd` und `tests/race3d/render/check_start_km0.gd`, je mit
  `.uid`.
- **Goldens:** `tests/golden/modern_slice.{md5,env}`; nur `modern_start_mittel` ist neu.
- **Doku:** `docs/qa-v080.md`, `docs/renderer-modern.md`.

**Keine eingefrorene Arcade-Datei** (Regel 1): nichts unter `scripts/race/`, `scripts/gameplay/`, `scripts/data/`,
`data/` oder `assets/sprites/`, kein `project.godot`.
Die neuen statischen Funktionen (`in_range`, `lead_in_snapshot`) kollidieren mit keinem Engine-Namen (A-1).

### 4.2 Wer liest den Pfad vor z = 0 – Nebenwirkungen (Code gelesen)

| Leser | Befund |
|---|---|
| `RoadPath3D` selbst | `_locate()` setzt `_lb` nur bei `z < 0 and first == 0`. `point/centre_at/world/frame_at/rows_local` hängen die Tangente richtig an (Vorzeichen geprüft: rückwärts = −fwd); `heading_at/height_at` liefern Grenze 0. `clearance()`, `floor_y()`, `floor_rows()` und `origin_distance()` klemmen negative Reihen auf 0. Es gibt also keinen negativen Array-Index, den GDScript sonst still von hinten lesen würde. |
| `Track.get_segment(k < 0)` (eingefroren) | klemmt auf 0 → Segment 0; `_collect()` prüft vorher, dass Segment 0 noch im Fenster liegt |
| `TerrainProfile` für Reihen < 0 | `_compute()` nimmt Segment 0; `_kappa()` und `_amp()` vertragen negative Reihen (Ganzzahl-Division; bei z < 60 m kein Relief) |
| Stück-Regeln | Stück −1 ist gewünscht, solange `cam_z < 150 m` (`keep_behind_m`), und wird ab `cam_z > 150 m` frei. Am Start sind es höchstens 17 Stücke (−1 … 15) bei `max_chunks` = 18 – vorn wird nichts verdrängt. |
| Rebasing | `rebase_m` = 2000 m: Solange Stück −1 lebt (Kamera < 150 m vom Start), gibt es kein Rebase. Käme eines, würde Stück −1 richtig mitverschoben (`seg_a < first` → `+ shift`). |
| Fahrzeugebene | `z_lo` ist am Start −∞. Verkehr entsteht im normalen Spiel **nie** bei z < 0: Das eingefrorene `traffic_system.gd` setzt hinten nur ein, wenn `z_behind > 0`. Autos weiter als 14 m hinter der Kamera werden ohnehin nicht gezeichnet. Betroffen ist also nur das Spielerauto (Heck −2,4 m) – gewollt. |
| Polizei | kommt nur nach einem ausgelösten Blitzer und fährt dann hinter der Kamera; im stehenden Countdown gibt es keinen |
| Licht-Ebene (`lights.gd` Z. 379) | Scheinwerferkegel des Verkehrs nur für Fronten ≥ `first · 3 m`. Im normalen Spiel steht kein Verkehrsauto vor der Startlinie → ohne Wirkung; denkbar nur mit dem Testschalter `--traffic-warmup`. |
| Sichtprüfungen F1–F3/F7 | Kamerapositionen ab 12 m; `wanted_for()` enthält jetzt Stück −1. Im FIX-ZS1-Tor grün. Ich habe die Fairness nicht neu gerechnet: Der Diff ändert weder Kamera noch Gelände. |
| Leistungstest, Attract-Demos | Alle Szenen beginnen bei km 77–384 (Konfiguration gelesen) → `first > 0`, kein Vorlauf, unverändert. Bestätigt durch 2.4 (km 2 bitgleich). |

Headless nachgerechnet (gemessen): `tools/run_tests.sh race3d` → 306 Skripte geprüft, 0 fehlerhaft; **110 Unit-Tests,
0 fehlgeschlagen**, darunter alle sechs von `test_start_lead_in.gd`; „Tests bestanden“, Exit 0. Die volle
`run_tests.sh` (Fairness F1–F3/F7) habe ich nicht wiederholt: Der Diff ändert weder Kamera noch Gelände, und das
FIX-ZS1-Tor lief auf demselben Spielcode grün.

### 4.3 Ist `check_start_km0` ein echter Wächter? (gemessen, `bruchtests_check_start_km0.jpg`)

| Lauf | kamera | auto | boden | Ergebnis |
|---|---|---|---|---|
| sauber, über `tools/run_render_checks.sh modern start_km0` | OK, ≤ 1,14 px | OK, Kanten ≤ 2 px | OK, 0,032 | **1 von 1 OK**, 281 s |
| Bruch A: `vehicles.gd` mit der alten Grenze `z_lo = first · seg_len` | OK | **FEHLER** „kein Spielerauto im Modern-Bild“ (Countdown) | OK | Exit 1 |
| Bruch B: `road_path.gd` ohne Vorlauf in `_locate()` (die Kamera klemmt wieder auf z = 0) | **FEHLER** Startlinie 99,9 px, 30 m 27,1 px, 60 m 7,3 px | **FEHLER** kein Auto; LOS + 1,5 s 290 × 186 px, 63 px zu tief | OK | Exit 1 |
| Bruch C: `chunk_streamer.gd` ohne Stück −1 | OK | OK | **FEHLER** 0,222 je Kanal (Wiese statt Straße unter der Kamera) | Exit 1 |

Jeder der drei Teile der Behebung wird von genau der Teilprüfung gefangen, die für ihn gedacht ist. Danach habe ich
alle drei Dateien mit `git checkout --` zurückgeholt; `git status` ist leer.
Eine Schwäche, kein Befund: Die Prüfung läuft nur in `run_render_checks.sh`, nicht in `run_tests.sh`; dort wachen die
sechs Unit-Tests von `test_start_lead_in.gd`.

### 4.4 Arcade-Identität (gemessen)

`tools/golden.sh check`, Exit 0:

- **GOLDEN arcade: 20 von 20 identisch** (207 s)
- **GOLDEN arcade-ui: 17 von 17 identisch** (266 s)

## 5. Nutzerdokumente (`was_neu.md`, `steamdeck_checkliste.md`)

Beide sind in schlichtem Deutsch geschrieben und enthalten keine internen Kürzel (kein Paketname, kein Commit,
kein „FIX“/„QA“). Was ich gegen den Build geprüft habe:

| Aussage / Aufforderung | geprüft |
|---|---|
| eigene Dateinamen, „v0.8.0-zs1“ unten rechts im Titel, eigener Nutzerordner (Deck: `~/.local/share/crossing-europe-zwischenstand/`, Windows: `%APPDATA%\crossing-europe-zwischenstand\`), v0.7.0-Ordner unberührt | stimmt (2.1, 3; v0.7.0 hat `config/name` „Crossing Europe – A Racing Xperience“ ohne eigenen Ordner) |
| A.2 Archiv liefert `CrossingEurope-ZS1.x86_64` + `LIZENZEN.txt`, Ausführbar-Recht bleibt | stimmt (1.) |
| C.1 einmal „GRAFIK WÄHLEN“, auf dem Deck Modern empfohlen, danach Voreinstellung „Steam Deck“ | Auswahl gesehen. Deck-Erkennung im Code: `vangogh`, `Custom GPU 0405/0932`, `sephiroth`, gamescope → Stufe „deck“, empfohlen Modern, Voreinstellung „deck“ (abgeleitet) |
| C.1 Optionen → Seite GRAFIK mit R1 (= RB) | stimmt (Hinweis „LB, RB = Seite“) |
| C.2 Leistungstest über die Menüs, Ergebnisseite mit Pfad, `leistungstest.json` am genannten Ort, 3 Szenen à 20 s | stimmt (2.5) |
| C.3 Kiel – Hamburg in Modern | läuft; Köhlbrandbrücke mit Wiese (B1, im Dokument angekündigt) |
| C.5 Einzelne Etappe mit Uhrzeit und Wetter | Etappenwahl hat „Startzeit“ und „Wetter“ (Code gelesen) |
| C.6 „Klang“ (Wie Grafik / Arcade / Modern), „Musik im Rennen“ (An / Aus), Grafik umschalten | stimmt (2.5) |
| C.7 Voreinstellungen Niedrig / Mittel / Hoch | vorhanden (2.5) |
| D. `logs/godot.log` im Testbuild-Ordner; Frage „Der Modus „Modern“ wurde beim letzten Start nicht richtig beendet.“ | Log vorhanden; Text steht im Titelbild-Code |
| Notfall `-- --graphics=arcade` | gültiger Schalter (§4.2; in 2.2 mit genau dieser Form benutzt); über die Steam-Startoptionen abgeleitet |
| was_neu: Modern füllt 16:10 auf dem Deck | stimmt im Bild (2.6) |
| was_neu: Showroom noch aus | stimmt (`showroom: false` für beide Modelle, Fahrzeugwahl zeigt das Bild) |
| was_neu: kein Wetter in der Luft, keine Sonnenscheibe, Köhlbrandbrücke mit Wiese | stimmt (2.3, 2.7) |
| was_neu: „In **Bergetappen** sind die Kurveninnenseiten kahler …“ | **zu eng** – es trifft auch flache Etappen vor Kurven, schon links am Start von Kiel – Hamburg (B4) |
| „dazu `SHA256SUMS` (Prüfsummen)“ | wer prüft, bekommt ohne `--ignore-missing` „FAILED“ (B3) |

Kein Schritt, um den der Nutzer gebeten wird, scheitert in diesem Build.

## 6. Befunde

### QA-ZS1-B1 – hoch – Köhlbrandbrücke: Wiese statt Elbe (bekannt als FIX-ZS1-B1, jetzt im Export bestätigt)

- **Wo:** Kiel – Hamburg km 78,0–80,6, Modern; gesehen mit „Mittel“ (hier) und „Hoch“ (FIX-ZS1), unabhängig von der
  Stufe (abgeleitet: `far_ground_drop_m` = 4,0 ist kein Qualitätswert). Ursache in
  `scripts/race3d/layers/far_ground.gd` (Besitz R2) bzw. bei der Wasserfläche von `builders/bridge.gd` (R5).
- **Was:** Arcade zeigt beidseits Wasser, Modern grüne Wiese bis zum Horizont. Die Fernboden-Scheibe liegt
  `far_ground_drop_m` = 4 m unter der tiefsten Straße und deckt 9 m tiefes Wasser zu (Ursache laut FIX-ZS1, Code nicht
  neu gerechnet).
- **Beleg:** `koehlbrandbruecke_km78_6_linux_export_ab.jpg`, gemessen mit dem gelieferten Export.
- **Nachstellen:** `ab_export.sh <Linux-Export> <out> "arcade modern" --stage=kiel_hamburg --from=kiel --hour=12
  --vehicle=limousine --seed=11 --autopilot --no-countdown --start-speed=60 --no-traffic --start-km=78.0
  --gfx-preset=medium --shot-times=2.5`.
- **Behebung:** Die Scheibe unter das tiefste Wasser der geladenen Reihen legen oder über Wasserreihen aussparen.
  Danach `tools/golden.sh modern-make` (`modern_s4_mittel` ändert sich) und den Testbuild neu bauen.
- **Bis dahin:** Der Satz in `was_neu.md` reicht als ehrliche Ankündigung. In der Checkliste unter C.3 sollte bei
  „Köhlbrandbrücke“ ein Verweis darauf stehen, damit der Nutzer das Bild dort nicht als neuen Fehler meldet.

### QA-ZS1-B2 – mittel – Links fehlen Bäume an Starts vor einer Linkskurve (Sichtkorridor F7 über die ganze Startgerade)

**Wo:** `scripts/race3d/terrain_profile.gd` `_kappa()` / `_kappa_coarse()` und `builders/props.gd` `drop_reason()`
„corridor“ (Besitz R2; Regel F7, A-3).

**Was:** `_kappa()` nimmt die schärfste Krümmung im Fenster ±`corridor_chord_m`/2. Das sind 52 Reihen = ±156 m um
jede Reihe. Beginnt die erste Linkskurve 138–162 m nach dem Start, gilt die **ganze gerade Startstrecke** links als
Kurveninnenseite. Jeder Baum, Busch und Heuballen innerhalb der Korridorbreite wird weggelassen und durch ≤ 0,5 m
Bodendecker ersetzt.

**Beleg, gemessen headless** (`m1/QA-ZS1/probe_start_props.gd`, Logs `probe_*.log`) – linke Korridorbreite über
Reihe 0–60 (z 0–180 m), rechts stets 5,5 m:

| Start | Korridor links | weggelassen |
|---|---|---|
| Kiel – Hamburg | 16,4 m | die große Eiche (z 27,9 m, x −17,1 m) und eine Eiche bei 190 m |
| Paris – Tours | 12,3 m | drei Birken in den ersten 90 m |
| Hamburg – Hannover | 22,1 m | eine Birke, eine Eiche, Büsche |
| Saragossa – Pau | 37,7 m | acht Pappeln, Eichen und Ballen in den ersten 143 m |

Im Bild: In `start_kiel_hamburg_linux_export_ab.jpg`, `start_paris_stadtrand_kompakt_ab.jpg`,
`start_hamburg_regen_ab.jpg` und `start_kiel_1280x800_preset_steamdeck_ab.jpg` hat Arcade links große Bäume, Modern
dort nur flache Büsche.

**Abgeleitet:** Vom Start aus verläuft die Sichtlinie zu einer Kurve 140 m voraus über der Fahrbahn. Bei 20–30 m nimmt
die Eiche keine Sicht.

**Nachstellen:** `godot --headless --path . -s m1/QA-ZS1/probe_start_props.gd -- --stage=kiel_hamburg --from=kiel`.

**Behebung (M2, R2 mit Fairness-Nachweis):**
- Den Korridor aus der echten Sehne von den Kamerapositionen aus berechnen. A-3 lässt das ausdrücklich offen bis
  Gate 2 – das Bild zeigt jetzt, dass es schon die erste Etappe trifft.
- Mindestens das Krümmungsfenster auf die Reihen beschränken, über die eine Sichtlinie in die Kurve tatsächlich läuft.
- Danach `tests/sim/modern_sight.gd -- --full` (F7).
- Für diesen Testbuild: nur die Doku (B4).

### QA-ZS1-B3 – niedrig – `sha256sum -c SHA256SUMS` meldet „FAILED“

- **Wo:** `deliver/FIX-ZS1/build/SHA256SUMS`, erzeugt von `tools/build_testbuild.sh`.
- **Was:** Die Datei nennt fünf Dateien, geliefert werden drei (plus `BUILDINFO.txt`). Wer die Prüfsummen wie üblich
  prüft, sieht „FAILED open or read“ für beide Programme und Exit 1 – obwohl der Download in Ordnung ist.
- **Beleg:** `sha256sum -c SHA256SUMS` im Lieferordner → 2 × FAILED, „WARNING: 2 listed files could not be read“,
  Exit 1 (gemessen).
- **Behebung:** In `SHA256SUMS` nur die gelieferten Dateien aufführen und die Summen der nackten Programme in
  `BUILDINFO.txt` schreiben. Oder in der Checkliste `sha256sum -c --ignore-missing SHA256SUMS` nennen.

### QA-ZS1-B4 – niedrig – `was_neu.md`: kahle Kurveninnenseiten nur für „Bergetappen“ angekündigt

- **Wo:** `deliver/FIX-ZS1/was_neu.md`, Abschnitt „Was noch fehlt“, Punkt Bergetappen.
- **Was:** Der Nutzer sieht den Effekt schon in der ersten Sekunde der ersten Etappe (Eiche links am Start von
  Kiel – Hamburg) und hält ihn sonst für einen neuen Fehler.
- **Beleg:** B2.
- **Behebung (ein Satz):** „Vor und in Kurven fehlen auf der Innenseite noch Bäume (absichtlich, damit nichts die Sicht
  nimmt) – auch auf flachen Etappen, z. B. links am Start von Kiel – Hamburg; Bodendecker kommen noch.“

## 7. Geprüft und in Ordnung

- Prüfsummen der Archive und von `LIZENZEN.txt`; die entpackten Programme entsprechen `SHA256SUMS` (gemessen).
- Archivinhalt (Programm + `LIZENZEN.txt`), Ausführbar-Recht, Größen 140,1 / 149,3 MiB (gemessen).
- `BUILDINFO.txt`, eingebettete Version 0.8.0-zs1 und eigener Nutzerordner, `.exe`-Version 0.8.0.1 (gemessen).
- Erster Start wie ein Spieler bis zum Countdown mit Auto und Pause; `settings.json` und `savegame.json` (gemessen).
- Stehender Start Kiel – Hamburg: Auto, Starttor, Startlinie, Schilder an Arcades Stelle, Boden vollständig, kein
  Kamerasprung (gemessen).
- Vier weitere Starts und 1280 × 800 mit „Steam Deck“: Auto an seinem Platz, Modern füllt 16:10 (gemessen).
- Fliegender Start bei km 2: neuer und alter Build bitgleich (gemessen).
- Windows unter Wine: Modern und Arcade starten, Bilder pixelgleich mit Linux, Nutzerordner unter `%APPDATA%`
  (gemessen).
- Menüs der Testanleitung, Leistungstest über die Menüs, Ergebnisdatei (gemessen).
- Diff ohne eingefrorene Datei; die Leser des Pfads vor z = 0 haben keine Nebenwirkung im Spiel (Code gelesen).
- `check_start_km0` grün und ein echter Wächter für alle drei Teile der Behebung (gemessen).
- `tools/golden.sh check`: 20/20 und 17/17 identisch (gemessen).
- Nutzerdokumente: stimmen für diesen Build, in schlichtem Deutsch, ohne interne Kürzel (gelesen, gegen den Build
  geprüft).

## 8. Bild gegen Arcade (ehrlich)

**Start bei km 0** (Kiel, Passau, Paris, Hamburg, Warschau): Modern zeigt Arcades Bildaufbau – Auto, Starttor,
Startlinie und Schilder an derselben Stelle in derselben Größe. **Gleichwertig, nicht deutlich besser.**

- **Besser:** Felder mit Struktur und Farbe und Tiefe bis zum Horizont, echte Schatten von Auto, Leitplanke und Tor,
  Leitplankenpfosten, das Starttor als Körper. Bei Passau sind die Bäume als Modelle gleichwertig zu Arcades. Nachts
  leuchtet die START-Schrift.
- **Schlechter:**
  - An drei von vier Tagesstarts fehlen links große Bäume (B2).
  - Keine Sonnenscheibe (Kiel, Paris).
  - Bei Regen kein Regen und bei Schnee kein Schneefall in der Luft – dort zeigt Arcade mehr.
  - Das Kompakt-Modell hat ein gelbes statt graues Dach; die Limousine hat die steile Heckscheibe (beides bekannt).

**Köhlbrandbrücke:** Brücke, Pylone und Seile sind in Modern körperlicher und schöner, aber die Wiese statt der Elbe
macht das Bild dort **deutlich schlechter** als Arcade (B1).

Insgesamt erfüllt dieser Zwischenstand den Anspruch „deutlich besser als Arcade“ am Start noch nicht. Er ist aber
ehrlich als Zwischenstand angekündigt, und dafür taugt er.

## 9. Dateien

- **Lieferung** `<scratch>/v080/deliver/QA-ZS1/`:
  - `bericht.md`
  - `start_kiel_hamburg_linux_export_ab.jpg`, `start_passau_steigung_ab.jpg`, `start_paris_stadtrand_kompakt_ab.jpg`,
    `start_hamburg_regen_ab.jpg`, `start_warschau_nacht_schnee_ab.jpg`, `start_kiel_1280x800_preset_steamdeck_ab.jpg`
  - `koehlbrandbruecke_km78_6_linux_export_ab.jpg`, `wine_windows_start.jpg`, `bruchtests_check_start_km0.jpg`
  - `erststart_linux_ablauf.jpg`, `erststart_linux_countdown_modern.jpg`, `menues_optionen_leistungstest.jpg`
- **Arbeitsdateien** `<scratch>/v080/m1/QA-ZS1/`:
  - Steuerung: `STAND.md`
  - Skripte: `walk.sh`, `walk_options.sh`, `ab_export.sh`, `queue_ab.sh`, `queue2.sh`–`queue4.sh`, `rc_breaks.sh`,
    `wine_run.sh`, `boxes.py`, `gate.py`, `sheet.sh`, `probe_start_props.gd`
  - Logs: `queue*.log`, `rc_breaks.log`, `rc/*.log`, `golden_check.log`, `wine_run.log`, `probe_*.log`,
    `run_tests_race3d.log`
  - Bilder: `ab/`, `walk/`, `walk_opt/`, `wine/`, `rc/`
  - Die entpackten Programme und die Wine-, Mesa- und Nutzerordner habe ich am Ende gelöscht.

## 10. Abweichungen, Vertragsfragen, für die Nächsten

**Abweichungen vom Auftrag**

1. Die A/B-Läufe aus dem Export laufen mit `--fixed-fps 60 -- --gfx-sync`, damit beide Modi denselben Moment zeigen.
   Der Wächter ist dabei aus und „Mittel“ bleibt. Echtzeit wie beim Spieler lief im Erststart-Gang (2.1) und im
   Leistungstest (2.5).
2. „3 s im Countdown“ habe ich als 2,9 s genommen: Der Countdown dauert 3,0 s, und 3,0 s ist schon der Moment von
   „LOS!“. Dazu kommen dichte Bilder bei LOS + 0,2 … 4 s.
3. Die weiteren Starts sind andere als bei FIX-ZS1. Einen Start in einer Kurve oder in City Limits gibt es im Netz
   nicht.
4. Die volle `run_tests.sh` habe ich nicht wiederholt (nur `race3d`), die Fairness nicht neu gerechnet; der Diff
   ändert weder Kamera noch Gelände.
5. Die erste A/B-Schlange wurde bei der Hintergrund-Grenze von 30 min während des km-2-Laufs beendet. Dessen Bilder
   waren schon vollständig geschrieben (gültige PNG). Den Vergleichslauf mit dem alten Build habe ich danach getrennt
   gestartet.

**Vertragsfragen**

1. **A-3 / F7:** Das Krümmungsfenster ±`corridor_chord_m`/2 lässt den Sichtkorridor 150 m vor einer Kurve beginnen –
   auch auf der geraden Startstrecke jeder Etappe, deren erste Kurve früh links liegt. A-3 vertagt „Korridor aus der
   echten Sehne“ auf Gate 2. Das Bild zeigt den Verlust jetzt schon an der ersten Etappe (B2); die Entscheidung sollte
   vorgezogen werden.
2. **§4.5.2:** Die Schnittstelle von `RoadPath3D` kennt den Vorlauf nicht (`has_lead_in()`, `z_min()`, Stück −1).
   `layers/lights.gd` nimmt deshalb weiter `first · seg_len` als Untergrenze. Ich schließe mich der FIX-ZS1-Vertragsfrage
   1 an: als Nachtrag aufnehmen.

**Für die Nächsten**

1. Die Köhlbrandbrücke beheben (B1), dann `tools/golden.sh modern-make` und den Testbuild neu bauen. Der Neubau sollte
   eine **unterscheidbare Version** tragen (z. B. `0.8.0-zs1b`): Der alte gate1-Build und dieser zeigen beide
   „v0.8.0-zs1“.
2. Bis dahin in der Checkliste unter C.3 auf die bekannte Wiese an der Köhlbrandbrücke hinweisen (B1) und den Satz zu
   den Kurveninnenseiten in `was_neu.md` erweitern (B4).
3. `tools/build_testbuild.sh` soll `SHA256SUMS` nur aus den gelieferten Dateien schreiben (B3).
4. `layers/lights.gd` Z. 379: Untergrenze `path.z_min()` statt `first · seg_len`. Heute ohne Wirkung, weil am Start
   kein Verkehr vor der Linie steht.
5. Den F7-Korridor aus der echten Sichtlinie berechnen und `modern_sight.gd -- --full` laufen lassen (B2).
6. `check_start_km0` erkennt das Auto am Blau der Limousine. Ändert sich deren Lack, muss die Maske mit.
