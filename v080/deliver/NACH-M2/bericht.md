# NACH-M2 – Nachprüfung der Fix-Runde FIX-M2 (Kopf `515dd51`)

- **Rolle:** Nachprüfung, keine Commits, kein Push, keine Branch. Arbeitsbaum
  `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-6` (Fast-Forward auf `515dd51`,
  `.godot` kopiert, Import sauber). Vergleichsbaum `6e48405` („vorher“) als `git archive` + `.godot` im Scratch
  (`m1/NACH-M2/base`, Import sauber; nach den Läufen gelöscht). Arbeitsbaum am Ende sauber (`git status` leer).
- **Maschine:** 4 Kerne, llvmpipe unter Xvfb, Dummy-Audio, geteilt (Last 15–20 während aller Läufe). „gemessen“ = hier
  an Bild/Log festgestellt; „abgeleitet“ = geschlossen. Steam Deck, echte GPU und Wirkung auf Menschen sind immer
  abgeleitet.
- **Werkzeuge:** Fahrzeugsonde der Prüfung (`m1/FIX-M2/probe/qa_vehicles.gd`, unverändert benutzt), Requisitensonde
  `probe/qa_props.gd`, Zähler `lc.py`, `zoom.py`, `paintbox.py`, `compose.py` der Prüfung; eigene Läufer
  `m1/NACH-M2/sh/{veh,shot,props,q1..q4}.sh`. Positionen wie QA-M2-BILD (`pos.sh`). Die Arcade-, ZS1- und
  M2-Vergleichsbilder der Prüfung wurden wiederverwendet, nachdem gezeigt war, dass sie reproduzierbar sind.

## Reproduzierbarkeit (gemessen)

- Fahrzeugsonde auf `6e48405`: die 6 Tagesbilder d20a–d60c **bitgleich** mit den M2-Bildern der Prüfung; S0 „Mittel“
  (beide Bilder) bitgleich mit `S0_m2med` der Prüfung. Die Prüfungsbilder gelten also für „vorher“.
- Fahrzeugsonde auf `515dd51`: alle 12 Verkehrsbilder (12 und 22 Uhr, d20a–d60c) **bitgleich** mit den `fx1`-Bildern
  von FIX-M2 – die Fahrzeugzahlen im FIX-M2-Bericht sind nachvollziehbar.
- Wo FIX-M2 den Kopf gegen „vorher“ ändert (Pixelvergleich gleicher Aufnahmen): S0, S1, KBT nur im Spielerauto
  (Bounding-Box x 542–756, y 469–671); C1 zusätzlich die Hausfassade im Abblendlicht (höchstens 10/255 je Kanal);
  N1 2 281 Pixel bei den Autos voraus (höchstens 20/255); KBN 13 209–30 797 Pixel an Deck, Pylonbeinen und dem Auto
  voraus – **alle dunkler** (Glanz des Abblendlichts weg), mittlere Leuchtdichte des Pylonbereichs 44,9 → 44,7.

## Ergebnis je Befund

| Befund | Urteil | Kern (gemessen, wenn nicht anders gesagt) |
|---|---|---|
| B-01 Kurvenkorridor F7 | **nicht behoben** | Code unverändert (`builders/`, `terrain_profile.gd`, `chunk_context.gd`: kein Diff). Sonde auf `515dd51`: T4 9 von 12 ausgelassen, S0-Eiche (seg 9, x −17,1, `corridor=true`) fehlt – zeilengleich mit dem Vorher-Lauf von FIX-M2. Bild: Starteiche fehlt (S0), Baum der Kurveninnenseite C1 fehlt. Leitungsentscheidung nach A-3/A-10 offen. |
| B-02 Niederschlag | **nicht behoben** | Kein `layers/weather.gd` auf `515dd51`; N1 ohne Schneefall (Arcade mit). R4 hat die Ebene (`origin/wip/v080-r4`, im Merge-Baum-Bild von FIX-M2 fällt Schnee). |
| B-03 Blaulicht | **behoben** | Blaue Pixel um die Polizei (Box der Prüfung): Tag 20/60 m Arcade 1 601/182, ZS1 1 004/114, vorher 411/28, **FIX-M2 1 004/153**; 22 Uhr 20/60/150 m Arcade 1 530/184/17, ZS1 481/76/7, vorher 144/49/3, **FIX-M2 1 250/103/16**. Ziel „mindestens ZS1“ überall erreicht; nachts bei 60 m 56 % von Arcade. Im Bild ein deutlicher blauer Hof, der Lichtbalken selbst bleibt schmal. |
| B-04 Bremslicht | **teilweise** | Tag 60 m rote Pixel (Arcade / ZS1 / vorher / FIX-M2): Sportwagen 34/31/9/**11**, Kombi 19/17/4/**6**, Limousine 31/17/17/**20** → 32–65 % von Arcade, Ziel 70 % nicht erreicht. Nachts deutlich stärker (Sportwagen 60 m 95/60/44/**150**). Der rosa Hof liest sich bei Tag nicht als Rot; das schmale Band des Sportwagens ist Modellarbeit. |
| B-05 Abblendlicht | **behoben** | Lkw-Heck (enger Ausschnitt, 22 Uhr) 60 m: Arcade 42, ZS1 194, vorher 194, **FIX-M2 45** mittlere Leuchtdichte, Pixel > 200: 0 / 652 / 652 / **0**; 20 m: 51 / 121 / 121 / **57** (1 537 → 16 Pixel > 200). Limousine silber 60 m: Pixel > 200 12 / 126 / 126 / **13**. Innerhalb ±30 % von Arcade. Der Lkw ist wieder rot, Rückstrahlerband sichtbar. |
| B-06 Spielerlack | **teilweise** | Sättigung der Lackpixel (Arcade / vorher / FIX-M2 / FIX-M2+R4 aus FIX-M2-Bildern): Limousine 12 Uhr (Sonde) 0,583 / 0,731 / **0,634** / 0,631 (+9 %), S1 „Hoch“ 0,583 / 0,732 / **0,635**; Sportwagen 19:30 (Sonde) 0,493 / 0,617 / **0,585** / 0,561 (+19 % / +14 %), C1 0,509 / 0,617 / **0,584** (+15 %); Kompakt 22 Uhr Schnee (Sonde) 0,721 / 0,950 / **0,950** / 0,755, N1 0,719 / 0,944 / **0,944** (+31 %). Ziel ±10 % nur bei Tag erreicht; auf `515dd51` allein ist die Nacht unverändert, erst R4s Nachtgesetz bringt sie heran. |
| B-07 Laden/Hänger | **nicht behoben** | Kein Code geändert (`chunk_streamer.gd` ohne Diff); nicht nachgemessen (keine ruhige Maschine). FIX-M2s kopflose 6,1 ms sind plausibel, belegen aber nur, dass die Spitzen lastabhängig sind (abgeleitet). |
| B-08 LOD-Wechsel 40 m | **nicht behoben (pausiert)** | `XFADE_LODS` = ["lod1","lod2"], `LOD_HYSTERESIS` 0,05 unverändert; auf Nutzerwunsch pausiert (#76). R4 hat lod0 in der Überblendung (`origin/wip/v080-r4` Zeile 68) – kommt mit RINT-M2. |
| M2S-01 Waldprüfung | **teilweise** | ZEITLIMIT-Meldung geprüft: `RENDER_CHECK_TIMEOUT=15` → „ZEITLIMIT (Exit 124, 15 s) – kein Ergebnis“, Skript-Exit 1; Kopfzeile `## render-check-timeout: 1800` wird gelesen. Laufzeit der Waldprüfung auf `515dd51` 456 s bei Last ≈ 18 (Laden 53 s, Fahrt 400 s; vorher 100 s Sicht: 2 940 s) – Ziel < 300 s bei Last 20 nicht erreicht; dafür belastet die kurze Prüfung das Budget nicht mehr (N-02). |

### Weitere Punkte von FIX-M2 (nicht in der Liste, kurz nachgeprüft)
- **M2S-04** (Läufer): Wegwerf-Test mit Laufzeitfehler → „FAIL … Skriptfehler im Test (1×), Test abgebrochen: Invalid
  call. Nonexistent 'float' constructor“, Exit 1; Datei gelöscht, Arbeitsbaum sauber (gemessen).
- **M2S-05** (Fernboden-Test): Mutation `target_height()` ohne Wasserterm → `test_far_ground_lies_below_the_water_of_a_bridge`
  rot („hier entscheidet das Wasser … erwartet −3,21, ist 6,44“); zurückgesetzt, Arbeitsbaum sauber (gemessen).
- **M2S-02** (Ersatzbild-Prüfung): alle sechs Fälle vergleichen wieder (kombi 0,0 px/+0,8 %, sports_red 1/1/0 px,
  bus_blue 2 px, nacht van_white +0,1/+1,2 %, verdeckt 0 Pixel hinter der Kuppe) – gemessen im Tor.
- **M2S-03** (Stufenspeicher): `check_vehicles leistung` OK mit dem neuen Hin-und-her-Teil (Tor).
- **M2S-07** (Rückfalltext): `check_seam rueckfall_dateien` OK – „Grund 'manifest' (Bild 5): Hinweis auf fehlende oder
  beschädigte Spieldateien“; `rueckfall` (shader) behält den Grafiktext (Tor).
- **Mutation der neuen Lichtprüfungen** (SPOT_SPECULAR 0,6, beide Modell-Zuschläge 1,0): beide neuen Prüfungen werden rot – `blaulicht` 102 / 303 Pixel (verlangt 200 / 600), `abblendlicht` 20 m 12,9 % weiß / Mittel 0,48, 60 m 44,5 % / 0,65 (verlangt ≤ 5 %, ≤ 0,35); Dateien zurückgesetzt, `git status` leer (gemessen). Den Bremsschein-Zuschlag bewacht nur der Unit-Test `test_model_glow_gain`, keine Bildprüfung

## Neue Befunde dieser Nachprüfung

1. **N-01 (niedrig, Fahrzeuge) – Bremsschein der Modelle nachts bei 60 m größer als Arcade.** `MODEL_BRAKE_GAIN` 2,2
   gilt auch nachts. Rote Pixel 22 Uhr, 60 m (Box der Prüfung, Arcade / FIX-M2): Sportwagen 95/150, Lkw 74/151,
   Kombi 64/83, Limousine 66/92; enger Ausschnitt Limousine 38/75. Bei 20 m gleich oder kleiner (Sportwagen 567/471).
   Im Bild (`B05_B04_limousine_bremse_60m_22uhr_…`) liegen drei große rote Höfe über dem Heck, die Form des Autos geht
   darin unter. Kein Fairness-Problem (stärkeres Signal), aber gröber als Arcade. Vorschlag: den Zuschlag mit den
   Lichtern der Palette ausblenden (z. B. 1 + 1,2 × (1 − 0,7 × lights)), nachts bei 60 m ≤ 130 % von Arcade.
2. **N-02 (niedrig, Prüfung) – die verkürzte Waldprüfung belastet das Budget nicht mehr.** Vorher (100 s, QA-M2-SYSTEM):
   Fahrzeug-Ebene ≤ 127 von 128, ganze Szene ≤ 142 von 230. Jetzt (20 s, gemessen): Fahrzeug-Ebene ≤ 38, Szene ≤ 51. Die
   Prüfung fängt weiter den Rückfall der statischen Modelle auf Instanz-Uniforms (Mutation von FIX-M2: Szene 144,
   9 Ablehnungen), aber „Hoch + volles Verkehrsbudget + Wald“ prüft keine Datei mehr (`check_instance_budget.gd` läuft mit
   dem Preset dieser Maschine, „Niedrig“). Vorschlag: Verkehr vor dem Start füllen (eingespeiste Autos wie in
   `check_vehicles leistung`) und verlangen, dass die Fahrzeug-Ebene ≥ 90 % des Budgets erreicht – sonst FEHLER
   „nicht belastet“.
3. **N-03 (niedrig, abgeleitet) – `SPOT_SPECULAR` 0 gilt für alles im Abblendlicht.** Gewollt für Fahrzeuge; es nimmt
   aber auch Deck, Leitplanken, Fassaden und – nach dem Zusammenführen mit R4 – der nassen Fahrbahn (`road.gdshader`:
   `SPECULAR` steigt mit `ce_wet`) den Glanz des eigenen Lichts. Auf den geprüften Bildern harmlos (KBN, C1 oben);
   auf nasser Fahrbahn nachts nach RINT-M2 einmal ansehen (N2 bei 22 Uhr). Wenn dort der Lichtkegel auf dem Asphalt
   fehlt: Glanz nur auf Fahrzeugen über einen Materialschalter abschalten statt am Licht.
4. **N-04 (niedrig, Doku)** – `docs/renderer-modern.md` 14.10 nennt drei Test-Sets der Ersatzbild-Prüfung; der Code
   (`TEST_SETS`) nimmt vier (auch `traffic/sports_red`, Commit 86c58e1).

## Was der Nutzer in ZS1 hat – hält es? (gemessen, Bilder angesehen)

| Punkt | Ergebnis |
|---|---|
| Auto am Start (Countdown und LOS + 1,5 s) | **hält.** `check_start_km0`: Auto Arcade 192 × 192 bei (544, 471), Modern 193 × 192 bei (544, 471), Kanten +0/+1/+0/+0 px; Straßenmitte ≤ 1,14 px. Bild `S0_start_km0_…`: Auto in beiden Aufnahmen da, Lack etwas stumpfer (gewollt, B-06). |
| Wasser unter der Köhlbrandbrücke | **hält.** KBT „Hoch“ beide Aufnahmen: Elbe bis zum Horizont, nur das Spielerauto weicht von „vorher“ ab. Unit-Test des Fernbodens schärfer (M2S-05, Mutation rot). |
| Pylone nachts | **hält.** KBN: Pylon dunkel wie Arcade, Bereichsmittel 44,9 → 44,7; die geänderten Pixel sind alle dunkler (Glanz weg). |
| Fahrzeuge nachts | **besser als ZS1.** Roter Lkw wieder rot statt weißer Leuchtkasten, Kennzeichen kein weißer Block, Polizei mit blauem Hof. |
| Kurveninnenseiten, Starteiche, Wetter in der Luft | **wie ZS1** (keine Verschlechterung, aber weiter schlechter als Arcade: B-01, B-02). |

## Tore auf `515dd51` (gemessen, Last 15–20)

| Tor | Ergebnis |
|---|---|
| Diff `6e48405..515dd51` | 20 Dateien, keine eingefrorene Arcade-Datei (Regel 1: Abgleich gegen die Liste in §2, 0 Treffer), kein Asset, keine Bauteil-/Gelände-/Streamer-Datei. Dateieigentum: FIX-M2 ändert Dateien von R4 (siehe Abweichungen von FIX-M2) – `git merge-tree` mit `origin/wip/v080-r4`, `-r5`, `-r6`: Konflikt nur in `tests/golden/modern_slice.{md5,env}` (gemessen). |
| Import | sauber |
| `tools/golden.sh check` (einmal) | **GOLDEN arcade: 20 von 20 identisch** (311 s), **GOLDEN arcade-ui: 17 von 17 identisch** (464 s) |
| `tools/run_render_checks.sh modern` – zu den geänderten Dateien | **7 von 7 OK**: `vehicle_lights` (blinker, ruecklicht_n1, bremslicht, **blaulicht** 310/1 061 Pixel, **abblendlicht** 20 m 0,5 % weiß / Mittel 0,25, 60 m 0,1 % / 0,17, sichtgrenze), `vehicle_standin` (alle sechs Fälle vergleichen), `light_base`, `start_km0` (Auto 193 × 192 gegen 192 × 192 bei (544, 471)), `showroom_render`, `instance_budget` (100 s, Fahrzeug-Ebene ≤ 128, Szene ≤ 142; 322 s), `instance_budget_wald` (20 s, ≤ 38 / ≤ 51; 456 s) |
| ZEITLIMIT-Meldung | `RENDER_CHECK_TIMEOUT=15 … start_km0` → `ZEITLIMIT (Exit 124, 15 s)` + „kein Ergebnis“, Skript-Exit 1 |
| `tools/run_tests.sh` (ein Vollauf, 1 199 s) | 310 Skripte, 0 fehlerhaft; **751 Tests, 2 rot** (`test_engine3_checks` thread: 6 Hänger à 400 ms, 98 Aussetzer; `test_music_checks` race) und **`check_attract.gd` (Arcade) rot** („Demo 0,94 s nach der letzten Eingabe, idle_s 1“). Alles andere grün, darunter `check_seam` (mit `rueckfall_dateien`), `check_vehicles` (`leistung` mit Stufenwechsel), `check_modern_stage` (`kern_zeit` OK), `modern_sight` F1/F1-Spuren/F2/F3/F7/Modell, `modern_path`. Einzeln nachgefahren, Kopf und Vorher-Stand: `test_engine3_checks` Kopf rot (thread, 61 Aussetzer) / Vorher rot (sync, 373 Aussetzer); `test_music_checks` Kopf grün / Vorher rot; `check_attract` idle Kopf grün (1,00 s) / Vorher grün (1,01 s). Dieselben Klangprüfungen fallen also auch auf `6e48405` – Last, nicht FIX-M2 (FIX-M2 ändert keine Klangdatei, Regel 4). Zweiter Vollauf nicht gefahren. |
| `tools/golden.sh modern-check` (Modern-Änderungsmelder, wie von FIX-M2 committet) | **GOLDEN modern: 6 von 6 identisch** (1 472 s) – die von FIX-M2 committete Liste passt zum Kopf; **modern-gles** `modern_s3_hoch`: OK, max. 2/255, PSNR 73,2 dB |
| Mutation der neuen Lichtprüfungen | beide neuen Prüfungen werden rot – `blaulicht` 102 / 303 Pixel (verlangt 200 / 600), `abblendlicht` 20 m 12,9 % weiß / Mittel 0,48, 60 m 44,5 % / 0,65 (verlangt ≤ 5 %, ≤ 0,35); Dateien zurückgesetzt, `git status` leer (gemessen). Den Bremsschein-Zuschlag bewacht nur der Unit-Test `test_model_glow_gain`, keine Bildprüfung |
| Unit-Läufer M2S-04, Fernboden M2S-05 | Wegwerf-Test rot mit „Skriptfehler im Test“; Mutation ohne Wasserterm rot (beide zurückgesetzt) |
| Sicht `modern_sight --full`, Validator, `audio_qc` | nicht gelaufen – keine Platzierung, kein Modell, kein Klang geändert (`capture_mix.gd` ist ein Messwerkzeug); der normale `modern_sight`-Lauf ist im Vollauf grün |

## Bilder (`deliver/NACH-M2/bilder/`)

| Datei | Inhalt |
|---|---|
| `fahrzeuge_tag_20m_60m_arcade_zs1_vorher_fixm2.jpg`, `fahrzeuge_nacht_20m_60m_…` | alle Testautos der Fahrzeugsonde, 12 und 22 Uhr, Arcade / ZS1 / `6e48405` / `515dd51` |
| `B03_polizei_60m_12uhr_…`, `B03_polizei_60m_22uhr_…` | Polizei bei 60 m (8-fach): blauer Hof wieder da, Balken schmal |
| `B04_sportwagen_bremse_60m_12uhr_…` | Sportwagen bremst bei 60 m am Tag: Band bleibt schmal (11 gegen 34 rote Pixel) |
| `B05_lkw_heck_60m_22uhr_…`, `B05_lkw_heck_20m_22uhr_…` | roter Lkw im Abblendlicht: ZS1/vorher weißer Kasten, FIX-M2 rot wie Arcade |
| `B05_B04_limousine_bremse_60m_22uhr_…` | Kennzeichenblock weg (B-05), Bremsschein größer als Arcade (N-01) |
| `B06_spielerlack_arcade_vorher_fixm2_mitR4.jpg` | Limousine 12 Uhr, Sportwagen 19:30, Kompakt 22 Uhr Schnee: Arcade / vorher / FIX-M2 / FIX-M2 + R4 (letzte Spalte aus FIX-M2s Merge-Baum) |
| `S0_start_km0_arcade_zs1_vorher_fixm2_mittel.jpg` | Start km 0, Countdown und LOS + 4,5 s: Auto da; Starteiche fehlt (B-01) |
| `S1_C1_N1_arcade_vorher_fixm2_hoch.jpg` | S1, C1 (Baum der Kurveninnenseite fehlt), N1 (kein Schneefall, Kompakt satt) |
| `KBT_koehlbrand_tag_hoch_…`, `KBN_koehlbrand_nacht_hoch_…` | Köhlbrandbrücke 12 und 22 Uhr: Wasser und dunkle Pylone halten |

## Ehrliches Urteil zum Bild

Jedes Bild angesehen und gegen Arcade desselben Zustands gestellt.
- **Besser als vorher und als ZS1:** Nachts sind die Autos im Abblendlicht wieder Autos – der rote Lkw rot, die
  Rückstrahlerleisten sichtbar, keine weißen Kennzeichenblöcke; die Polizei trägt bei Tag und Nacht einen blauen Hof;
  Bremsen ist nachts deutlich. Die Fahrzeugmodelle zeigen mehr Form als die Sprites (Fenster, Leisten, Auspuff).
- **Gleich oder schlechter als Arcade:** Bremslicht bei Tag (Sportwagen, Kombi bei 60 m ein Drittel der roten Fläche);
  nachts ist der Bremsschein bei 60 m dagegen gröber als Arcade (N-01). Lack des Spielerautos in Dämmerung und Nacht
  satter als das Sprite (C1 +15 %, N1 +31 % auf diesem Kopf). Kurveninnenseiten kahl, Starteiche fehlt, kein
  Niederschlag – unverändert.
- **Gesamt:** An den Fahrzeugen ist Modern jetzt gleichwertig bis besser als Arcade; „deutlich besser als Arcade“ ist es
  an Kurven (B-01) und bei Wetter (B-02) noch nicht.

## Offen / für die Nächsten

1. **Leitung – B-01:** entscheiden (FIX-M2s Vorschlag „Korridor je Kurve = min(300 m, F2-Bedarf), strenge Lesart“
   hilft nur den Bergkurven T3/T4; Starteiche, C1, T1/T2/S4 bräuchten eine andere Regel, z. B. „ein Baum darf stehen,
   wenn Arcade an derselben Stelle dieselbe Sicht nimmt“). Danach `modern_sight.gd -- --full` und die Verdeckungssonde.
2. **RINT-M2:** nach dem Zusammenführen mit R4 nachmessen, was nur R4 liefert: Niederschlag (B-02, N1/N2 A/B), Lack
   nachts (B-06 Kompakt N1: auf diesem Kopf +31 %), lod0-Überblendung (B-08), nasse Fahrbahn nachts im Abblendlicht
   (N-03); Modern-Goldens neu.
3. **N-01:** Bremsschein-Zuschlag der Modelle mit den Lichtern der Palette ausblenden (nachts bei 60 m bis 2 × Arcade).
4. **B-04 (Assets):** Sportwagen Bremsband höher, mittlere Bremsleuchte mit Anker in `lights[]`; bei Tag bleibt der
   Bremsschein aller Modelle bei 60 m 31–65 % von Arcade – ein Tag-Hof, der das Grün senkt (Rot statt Rosa), fehlt.
5. **B-06:** Sportwagen in der Dämmerung +15 … +19 % (C1/Sonde). Ein reines Rot verliert durch Mischen zur Leuchtdichte
   kaum HSV-Sättigung – je Modell die Albedo an das Sprite angleichen statt eines gemeinsamen Anteils.
6. **N-02:** Waldprüfung so füllen, dass die Fahrzeug-Ebene ihr Budget erreicht (oder das als Bedingung prüfen).
7. **B-07 (PERF):** Laden und Hänger auf einer ruhigen Maschine mit ZS1 daneben messen; Vorbau der Verkehrsmodelle.
8. **Zeitprüfungen (A-11):** `test_engine3_checks` thread, `test_music_checks` race und `check_attract` idle fielen im
   Vollauf unter Last; Ergebnis der Einzelläufe oben. Unter A-11 sind lastabhängige Prüfungen selbst Befunde (AU, UI1).
