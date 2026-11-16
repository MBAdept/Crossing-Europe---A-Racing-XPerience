# FIX-M2 – Nacharbeit nach der Prüfung der ersten M2-Montage

- **Arbeitsbaum:** `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-5`, Branch
  `worktree-wf_438996b0-243-5`, Sicherung `origin/wip/v080-fix-m2` (jeder Commit gepusht). Basis `6e48405`
  (Fast-Forward), kein Vorgänger dieses Laufs vorhanden (kein `STAND.md`, keine Branch).
- **Endstand:** `515dd51` (7 Commits auf `6e48405`, alle gepusht nach `origin/wip/v080-fix-m2`)
- **Maschine:** 4 Kerne, Software-OpenGL (llvmpipe) unter Xvfb, Dummy-Audio, geteilt mit R4, R5, R6, AS5a (Last 14–24).
  „gemessen“ = hier an Bild/Log/Datei festgestellt; „abgeleitet“ = geschlossen, nicht gemessen. Steam Deck, echte GPU
  und Wirkung auf Menschen sind immer abgeleitet.
- **Werkzeuge** (Scratch `m1/FIX-M2/`, nichts davon committet): die Sonden von QA-M2-BILD (`probe/qa_vehicles.gd` mit
  zusätzlichen Schaltern `--flaredump`, `--depth_eps`, `--flare_strength`, `--spot_spec`; `probe/qa_props.gd`,
  `probe/qa_occl.gd`), eigene `probe/fx_chord.gd` (Sehne, die F2 je Kurve braucht), `probe/fx_collect.gd`,
  `sh/veh.sh`, `sh/lc.py`, `sh/occl.sh`, `sh/shot.sh`, `sh/preview_corridor.py` (B-01-Vorschau, nur lokal angewandt
  und zurückgenommen). Die QA-Bilder von Arcade/ZS1/M2 der Fahrzeugsonde wurden übernommen – mein eigenes M2-Bild
  derselben Szene ist **bitgleich** mit dem der Prüfung (gemessen, d20a/b/c).

## Ergebnis je Befund

### B-01 (hoch) – Kurvenkorridor F7 nimmt die Innenseiten leer: **nachgestellt, offen (Entscheidung der Leitung), Entscheidungsgrundlage geliefert**

- Nachgestellt mit der Sonde der Prüfung (`fair/props_base_*.txt`, gemessen): T4 9 von 12 Requisiten in 150 m
  ausgelassen, T2 9/18, T1 5/13, C1 4/16 (darunter das Stadthaus `city_german_gruenderzeit`), S4 3/12, T3 4/8, S0 die
  Eiche – genau die Zahlen der Prüfung (T2 einer mehr).
- **Warum nicht behoben:** D14 F7 schreibt die Sehne von 300 m fest; A-3 („ob der Korridor aus der wirklichen Sehne
  gerechnet wird, entscheidet sich mit den Bildern von Zwischenstand 2“) und A-10 („F7 behält seine strenge Lesart bis
  zu den Bergbildern von Zwischenstand 2“) sind ausdrückliche Leitungsentscheidungen. Die strenge Lesart (auch Felsen und
  Häuser einer Landschaftsregel) steht so in docs/renderer-modern.md 12.6.
- **Neue Zahlen für die Entscheidung** (`probe/fx_chord.gd`, ganzes Netz, gemessen = gerechnet mit den ausgelieferten
  Fahrmodellen wie `modern_sight`): Die Sehne, die F2 an einer Kurve braucht (Anhalteweg bei der schnellsten fahrbaren
  Geschwindigkeit / 0,6 + 9 m Kamera), ist **nur an langsamen Bergkurven kürzer als 300 m**: Saragossa–Pau T3/T4 107–119 m
  (Pfeilhöhe 11–13 m statt 83 m). An allen anderen geprüften Stellen braucht F2 **mehr** als 300 m (T1 276–288 m, T2
  375–493 m, C1 345–355 m, S0/S4 375–493 m; netzweit liegen 88 % der Korridorreihen über 300 m, weil die „schnellste
  fahrbare Geschwindigkeit“ Tempolimits nicht kennt). Eine Korridorbreite „aus F2 je Kurve“ hilft also nur den
  Bergstrecken; T1, T2, C1, S4 und die Starteiche kämen damit nicht zurück.
- **Vorschau** (lokal angewandt und zurückgenommen, `sh/preview_corridor.py`, nicht committet), T4 Saragossa–Pau km
  198,8, „Hoch“, rotes Testauto 25–270 m in drei Spuren (`probe/qa_occl.gd`, sichtbare Pixel, gemessen):
  | Variante | ausgelassen T4 / T3 | Testauto sichtbar bis |
  |---|---|---|
  | Arcade | – | 40 m (ab 55 m hinter Fels und Fichten) |
  | Modern, Korridor wie geliefert (300 m, streng) | 9 / 4 | 220 m |
  | streng, Sehne 119 m (F2-Bedarf hier) | 2 / 1 | 130 m (≥ F2-Bedarf 109 m), verdeckt ab 170 m |
  | nur Vegetation (D14 wörtlich), Sehne 119 m | 1 / 0 | 40 m (ein Fels bei 8,9 m hinter dem Bankett verdeckt ab 55 m – wie Arcade) |
  Die wörtliche Lesart „nur Vegetation“ holt Felsen zurück, die in der Kurve verdecken – sie verletzt F2 an T4; das
  begründet die strenge Lesart von R2. Die strenge Lesart mit einer Sehne aus F2 gibt fast alle Bäume zurück und bleibt
  fairer als Arcade. Bild: `bilder/B01_T4_korridor_vorschau.jpg`.
- **Empfehlung an die Leitung (Vertragsfrage):** F7-Korridor je Kurve = min(300 m, F2-Bedarf) mit strenger Lesart;
  braucht im Kern (`terrain_profile.gd`) eine Geschwindigkeit je Reihe (Fahrmodelle wie `fairness.speed_profile`) und
  einen neuen Lauf `modern_sight.gd -- --full` sowie der Verdeckungssonde an den Bergkurven.

### B-02 (hoch) – kein Regen/Schnee in der Luft: **offen in FIX-M2, gebaut in R4**
R4 hat die Ebene `weather` (Regen und Schnee als Teilchen, Gischt, nasse Fahrbahn, Spiegelungen) auf
`origin/wip/v080-r4` (818816c ff.). Doppelte Arbeit in derselben Ebene wäre ein sicherer Konflikt; nicht angefasst.
`git merge-tree` meines Endstands mit `origin/wip/v080-r4`, `-r5`, `-r6`: konfliktfrei (gemessen).

### B-03 (mittel) – Blaulicht der Polizei schwach: **behoben**
- Nachgestellt (gemessen, Fahrzeugsonde der Prüfung, Kiel–Hamburg km 2, „Mittel“): blaue Pixel um die Polizei
  20/60 m Tag Arcade 1 601/182, ZS1 1 004/114, M2 411/28. Ursache gemessen: Der Schein selbst folgt Arcades Gesetz
  (Lichtpunkte abgeschaltet → Differenz; die Tiefenproben verdecken nichts: `depth_eps` 3 m ändert 1 128 → 1 193
  Pixel); dem Modell fehlt die Lichtebene des Sprites, die in Arcade/ZS1 den Balken als breiten blauen Fleck malt.
- Behoben: `VehiclePose3D.model_glow_gain()` – Blaulicht eines Modells × 2,4 (`MODEL_BEACON_GAIN`), Sprite- und
  Kastenvertretungen unverändert. Danach (gemessen): Tag 20/60 m 1 004/153 (= ZS1 / zwischen ZS1 und Arcade), Nacht
  20/60/150 m 1 250/103/16 gegen M2 144/49/3 (Arcade 1 530/184/17). Mit R4 zusammengeführt gleich (1 268/100).
- Prüfung: `check_vehicle_lights` → `blaulicht` (60 m, Tag ≥ 200, Nacht ≥ 600 deutlich blauere Pixel; gemessen
  310/1 061, mit Arcades Gesetz allein 102/303).

### B-04 (mittel) – Bremslicht des Sportwagens / Bremslicht bei Tag: **teilweise**
- Nachgestellt (gemessen): rote Pixel des bremsenden Sportwagens 20/60 m Tag Arcade 218/34, ZS1 245/31, M2 119/9;
  Limousine 20 m Arcade 231, M2 95. Die Lampen sind rot und hell (237, 69, 70); es fehlt Fläche: das Bremsband des
  Sportwagens ist 2–3 cm hoch, ein mittleres Bremslicht fehlt im Modell (`lights[]` ohne Mittelanker).
- Behoben, soweit ohne Modellarbeit möglich: Bremsanteil des Scheins eines Modells × 2,2 (`MODEL_BRAKE_GAIN`, ein
  Rücklicht allein bleibt bei Arcades Stärke). Gemessen: Tag Limousine 20/60 m 95 → 105 / 17 → 20 rote Pixel, Sportwagen
  119 → 135 / 9 → 11; nachts Sportwagen 20/60 m 314 → 471 / 44 → 150 (Arcade 567/95), Limousine 275 → 654 (Arcade 539).
  Der Schein ist im Bild deutlich (rosa Hof um die Leuchten, `bilder/B04_*`), die Zählung „rot“ steigt bei Tag wenig,
  weil ein additiver roter Hof über grauem oder gelbem Lack das Grün nicht senkt.
- Offen (Modelle, Assetpaket): Bremsband des Sportwagens höher (≈ 0,35 m Lampengröße) und ein mittleres Bremslicht;
  das 70-%-Ziel bei 60 m am Tag erreicht der Sportwagen ohne das nicht (11 gegen Arcade 34).

### B-05 (mittel) – Fahrzeuge im Abblendlicht überstrahlt: **behoben**
- Nachgestellt (gemessen, 22 Uhr): Lkw-Heck 20/60 m mittlere Leuchtdichte M2 109/152, Arcade 56/42 (mein Ausschnitt);
  Limousine silber 60 m Kennzeichen und Stoßfänger als weißer Block. Ursache: der Glanzanteil der zwei Spots des
  Abblendlichts – mit `light_specular` 0 im selben Bild (Sondenschalter `--spot_spec=0`): Lkw 60 m 152 → 48.
- Behoben: `layers/lights.gd` `SPOT_SPECULAR := 0.0`. Danach (gemessen): Lkw 20/60 m 61/47 (Arcade 56/42, +10/+11 %),
  über 200: 0,5 %/0,5 % statt 13/38 %; Limousine 60 m keine weißen Pixel mehr über Arcade (px > 200: 57 gegen 54);
  mit R4 zusammengeführt 60/53 (gemessen).
- Prüfung: `check_vehicle_lights` → `abblendlicht` (roter Lkw 20/60 m: ≤ 5 % über 200, Mittel ≤ 0,35; mit dem alten
  Wert 12,9/44,5 % → FEHLER, gemessen).

### B-06 (mittel) – Lack der Spielerautos zu satt: **behoben bei Tag, Sportwagen-Dämmerung knapp darüber**
- Nachgestellt (gemessen, `sh/paintbox.py`, Lackpixel farbgefiltert, Bilder der Prüfung): S1 Limousine 0,74 gegen
  Arcade 0,59, C1 Sportwagen 0,54/0,42, N1 Kompakt 0,94/0,72. **Mit R4 zusammengeführt** (Merge-Baum
  FIX-M2 + `origin/wip/v080-r4` als Kopie im Scratch, eigene Aufnahmen „Hoch“): S1 0,74, C1 0,52, N1 0,75 – R4s
  Nachtgesetz hält N1 schon (+4 %), bei Tag bleibt der Befund (+25 %).
- Behoben: `ModernMaterials.VEHICLE_PLAYER_DESAT` 0,35 × (1 − Nacht der Palette), `player_paint()`, die Fahrzeug-Ebene
  setzt den Lack neu, wenn sich die Nacht ändert; nur im Rennen (Showroom unverändert). Gewählt mit der Fahrzeugsonde
  auf dem Merge-Baum (gemessen, „Mittel“): Limousine 12 Uhr ohne 0,726, 0,15 → 0,693, 0,30 → 0,647, Endstand 0,631
  (Arcade 0,583, +8 %); Kompakt 22 Uhr Schnee 0,755 unverändert (0,15 hätte 0,672, 0,30 0,530 ergeben; Arcade 0,718);
  Sportwagen 19:30 0,403 → 0,391 (Arcade 0,344, +14 % – ein reines Rot verliert durch Entsättigung zur Leuchtdichte
  kaum HSV-Sättigung; offen). Leuchtdichte unverändert (0,287 / 0,276 / 0,233).
- Bilder: `bilder/B06_limousine_12uhr_arcade_vorher_nachher.jpg`, `B06_sportwagen_1930_arcade_vorher_nachher.jpg`.

### B-07 (mittel) – Laden und Hänger: **teilweise nachgestellt, offen**
- Kopflos ist das Sammeln (`collect`) eines Stücks klein: Kiel–Hamburg km 5–9 höchstens 6,1 ms (gemessen,
  `probe/fx_collect.gd`), die Prüfung fand kopflos km 70–95 höchstens 9,9 ms. Kein Set wurde während der Fahrt
  nachgeladen (die Bibliothek der Requisiten wuchs nicht). Die 598/1 152-ms-Spitzen unter Xvfb bei Last 17–23 lassen
  sich ohne Last nicht erzeugen – CPU-Mangel des Hauptfadens (abgeleitet, wie die Prüfung). Die Vergleichsfahrt mit
  ZS1 auf einer ruhigen Maschine und der kalte Warmlauf sind hier nicht möglich (die Maschine ist nie ruhig, Last 14–24).
- Nicht gebaut: ein Zeitbudget je Bild für `collect` (Kern, R4-Datei in Welle 3; bei ≤ 10 ms ohne Last kein messbarer
  Gewinn) und „Commit > 3 ms = Testfehler“ (auf llvmpipe unter Last nicht haltbar, A-11).
- Hinweis für PERF: der Fahrzeug-Haken hatte in der Prüffahrt 193 ms Spitze (Knotenbau eines Modells beim ersten
  Erscheinen auf dem Hauptfaden) – ein Vorbau der Verkehrsmodelle in `prepare()` wäre der Hebel.

### B-08 (mittel) – harter LOD-Wechsel bei 40 m (#76): **nicht hier**
Der Nutzer hat das Lackflackern pausiert („bitte nicht weiterverfolgen“, Leitungsnotiz 15.11. 09:45: „KEIN
Flacker-Fix nebenbei einbauen“). R4 hat lod0 in die Überblendung aufgenommen (9a5ffe4, e68b51f).

### B-09 (niedrig) – Ordered Dither der fernen Wahrzeichen: **offen (R7)**
Ein weiches Ausblenden braucht eine durchscheinende Variante des Billboard-Materials (Alpha-Mischung oder
Alpha-to-Coverage) für die Wahrzeichen-Vertretungen – das ist die Fern-LOD-Arbeit von R7, kein billiger Fix; der Dither
ist seit gate1 so.

### B-10 (niedrig) – keine Sonnenscheibe mittags: **nicht hier (R4)**
Laut Prüfung kein Codefehler; R4 setzt die Sonnenscheibe an Arcades Stelle (818816c).

### M2S-01 (mittel) – Waldprüfung 8–49 min: **behoben**
- Nachgestellt nicht nötig (die Laufzeit war in jedem Lauf der Prüfung zu lang). Neu: `_sim_s()` überschreibbar, die
  Waldvariante fährt 20 s statt 100 s (der Wald von km 46,5 steht ab dem ersten Bild; die Fahrzeuge allein prüft
  `check_instance_budget.gd` über 100 s), Laufzeit je Phase im Ergebnis, Kopfzeile `## render-check-timeout: 1800`,
  `run_render_checks.sh` meldet Exit 124 als `ZEITLIMIT` (kein Ergebnis).
- Gemessen (Last 20–24): 35 s Sichtzeit 921 s (Laden 90, Fahrt 824), 20 s Sichtzeit 456 s. Mutation „Bäume wieder mit
  `vpbr` statt `VPBR_STATIC`“ (Instanz-Uniforms): die kurze Prüfung wird rot (9 × „Too many instances…“, Szene 144).
  Das Ziel < 300 s bei Last 20 ist nicht erreicht (llvmpipe zeichnet „Hoch“ mit Wald in 2 s je Bild).

### M2S-02 – Ersatzbild-Prüfungen liefen leer: **behoben**
Test-Manifest ohne Modell für `player/kombi`, `traffic/sports_red`, `traffic/van_white`, `traffic/bus_blue`; ein Fall
ohne Vergleich ist FEHLER. Alle sechs Fälle vergleichen wieder (gemessen): spieler kombi 0,0 px / +0,8 %, verkehr
sports_red 1/1/0 px, −1,2/−3,2/+5,0 %, kasten bus_blue 2 px / 0 %, nacht kombi +0,3 %, van_white +0,1/+1,2 %,
verdeckt 0 Pixel hinter der Kuppe. Erst mit van_white fiel auf: „verdeckt“ versteckt einen Punkt 2 m über der Straße,
das Dach des 2,6-m-Transporters ragte darüber (1/15 Pixel) – darum der Sportwagen für Kuppe und Abstände. Nebenbefund:
van_white bei 150 m −12,3 % Helligkeit gegen Arcade (Rückfallweg, nur Information).

### M2S-03 – „leistung“ fing den Verlust des Stufenspeichers nicht: **behoben**
Ein Auto wird dreimal zwischen zwei Stufen geschaltet (lod1 → lod0 → lod1 → lod0, gemessen); verlangt werden dieselben
Knoten im Stufenspeicher (Instanz-IDs je Auto – der Zähler aller Bauten war wegen des fahrenden Etappenverkehrs
ungeeignet).

### M2S-04 – Läufer zählte abgebrochene Tests als bestanden: **behoben**
`tests/run_tests.gd` meldet einen `Logger` an; ein Skriptfehler während eines Tests macht ihn FEHLGESCHLAGEN mit der
Fehlerzeile (geprüft mit einer Wegwerf-Testdatei: „FAIL … Skriptfehler im Test (1×) … Nonexistent 'float'
constructor“, Exit 1). `test_props` prüft die Pylon-Parameter auf null.

### M2S-05 – Fernboden-Test entschied nicht: **behoben**
Wasser 30 m unter dem Deck; der Test verlangt jetzt, dass der Wasserterm entscheidet. Mutation (`target_height()` ohne
Wasserterm): rot („erwartet −3,21, ist 6,44“, gemessen).

### M2S-06 – Mitschnitt unter Last zu kurz: **behoben**
`capture_mix.gd` vergleicht Dateilänge und Laufzeit; > 2 % = FEHLER, Exit 2 (gemessen bei Last 20: 3,90 s Klang in
4,02 s, −2,9 % → FEHLER). Werte `wav_seconds`, `clock_drift` im JSON.

### M2S-07 – Rückfalltext nannte immer die Grafik: **behoben**
`RaceSession.fallback_from_files()`: „manifest“ und „script:…“ → „…weil Spieldateien fehlen oder beschädigt sind…“;
`check_seam` → `rueckfall_dateien` (neu) OK, `rueckfall` (shader) und `ohne_renderer` behalten den Grafiktext (gemessen).


## Tore auf dem Endstand

Alle auf `515dd51` bzw. dem Code-Stand `6209384` (515dd51 ändert nur `tests/golden/modern_slice.*`), Last 13–24 (gemessen):

| Tor | Ergebnis |
|---|---|
| Import (`godot --headless --import`) | sauber (8 s), `tests/check_scripts.gd` 310 Skripte, 0 fehlerhaft |
| `tools/run_tests.sh` (ein Vollauf, 1 376 s) | **751 Tests, 3 rot** + `check_modern_stage` `kern_zeit` rot – alles Zeit-/Lastfälle (unten); alle anderen Haken grün, darunter `check_seam` (mit `rueckfall_dateien`), `check_vehicles` (`leistung` mit Stufenwechsel), `modern_sight` F1/F1-Spuren/F2/F3/F7/Modell und `modern_path` |
| `tools/run_render_checks.sh all` | **19 von 19** Dateien OK, darunter `instanzen_wald` 523 s, `vehicle_lights` (blaulicht, abblendlicht), `vehicle_standin` (alle sechs Fälle vergleichen) |
| `tools/golden.sh check` | **GOLDEN arcade: 20 von 20 identisch**, **arcade-ui: 17 von 17 identisch** |
| Modern-Änderungsmelder | `modern-make` mit KEEP, alle sechs Bilder gegen M2ZS1 angesehen: Tag nur das Spielerauto (Lack), S5 dazu der Bremsschein, Nacht 116 Pixel → committet (515dd51) |
| `modern_sight --full`, `modern_path_check --full` | nicht nötig (keine Platzierung, keine Modellgröße geändert); der normale Lauf im Vollauf grün |
| Validator / Export-Determinismus / `audio_qc.py` | nicht nötig (kein Modell, kein Klang geändert; `capture_mix.gd` ist ein Messwerkzeug) |
| Zusammenführbarkeit | `git merge-tree` mit `origin/wip/v080-r4`, `-r5`, `-r6`: Code konfliktfrei; Konflikt nur in den erzeugten `tests/golden/modern_slice.{md5,env}` (nach RINT-M2 neu erzeugen) |

**Die roten Fälle des Vollaufs sind Last, nicht FIX-M2 (gemessen):** `test_engine3_checks` (thread) und
`test_music_checks` (race) einzeln nachgefahren: grün. `check_modern_stage` einzeln: grün (`kern_zeit` war Einhängen
4,39 ms > 3 ms). `test_modern_checks` (race) bleibt wackelig – abwechselnd mit dem Basisstand `6e48405` (eigene Kopie
im Scratch, gleicher Import) je viermal direkt gefahren: Basis 1 von 4 OK, FIX-M2 1 von 4 OK; rot immer dann, wenn
die Prüfung bei Zeitraffer 8 zu wenige Bilder bekommt (9–75 Bilder: Sitzung < 90 % der Bilder da oder der
Tunnelausgang fällt zwischen zwei Bilder), grün bei 95–150 Bildern. Dieselben drei Klangprüfungen meldete R4 als
Lastartefakte. FIX-M2 ändert keine Klangdatei (Regel 4).

## Bilder (`deliver/FIX-M2/bilder/`)

| Datei | Inhalt |
|---|---|
| `B01_T4_korridor_vorschau.jpg` | T4 Saragossa–Pau km 198,8, 11 Uhr, „Hoch“: Arcade / Modern wie geliefert (Innenseite kahl, Bodendecker) / Vorschau Sehne 119 m streng (Fichten zurück) – Vorschau nicht committet |
| `B03_polizei_60m_tag_zoom.jpg` | Polizei bei 60 m, 12 Uhr: Arcade / ZS1 / M2 / FIX-M2 – blauer Schein wieder da |
| `B03_B04_tag_60m_arcade_zs1_m2_fixm2.jpg` | drei Reihen Testautos bei 60 m, 12 Uhr |
| `B04_sportwagen_bremse_60m_tag_zoom.jpg`, `B04_limousine_bremse_60m_tag_zoom.jpg` | bremsende Autos bei 60 m: rosa Hof um die Leuchten; das schmale Band des Sportwagens bleibt schmal |
| `B05_lkw_nacht_60m_zoom.jpg` | roter Lkw bei 60 m, 22 Uhr: ZS1/M2 weißer Kasten, FIX-M2 rot wie Arcade |
| `B05_B03_nacht_20m_…`, `B05_B03_nacht_60m_…` | alle Testautos 22 Uhr, Arcade / ZS1 / M2 / FIX-M2 |
| `B03_B05_nacht_mit_R4_zusammen.jpg` | dieselben Szenen auf dem Merge-Baum FIX-M2 + R4: gleiches Ergebnis, dazu R4s blaue Lichtlache |
| `B06_limousine_12uhr_arcade_vorher_nachher.jpg`, `B06_sportwagen_1930_…` | Spielerauto (Merge-Baum mit R4): Arcade / ohne / mit Entsättigung |


## Ehrliches Urteil zum Bild

Gemessen auf llvmpipe; jedes Bild angesehen und gegen Arcade desselben Zustands gestellt.

**Besser als vorher (und als ZS1):**
- Nachts im Abblendlicht sind Autos wieder Autos: der rote Lkw bleibt rot (statt weißer Leuchtkasten), Kennzeichen und
  Stoßfänger der silbernen Limousine kein weißer Block mehr, der Bus ohne Glanzstreifen. Hier ist Modern jetzt so ruhig
  wie Arcade und zeigt mehr Form (Türen, Leisten, Rückstrahlerband).
- Die Polizei ist bei Tag und Nacht wieder ein blauer Lichtpunkt mit Hof, nicht nur ein dünner Balken (bei 60 m Tag
  zwischen ZS1 und Arcade, nachts unter Arcade).
- Bremsen liest man wieder: ein deutlicher roter Hof um die Leuchten, nachts so kräftig wie Arcade.
- Der Lack der Limousine bei Tag ist näher am Sprite (Sättigung +8 % statt +25 %), der Sportwagen in der Dämmerung
  etwas tiefer rot statt orange.

**Gleich oder noch schlechter als Arcade:**
- Kurveninnenseiten (T1–T4, C1, S4, Starteiche) bleiben kahler als Arcade – Leitungsentscheidung (B-01); die Vorschau
  zeigt, dass mit einer F2-Sehne die Bergkurven wieder bewaldet wären, ohne die Fairness aufzugeben.
- Das schmale Bremsband des Sportwagens bei 60 m am Tag (11 gegen 34 rote Pixel) – Modellthema.
- Der Sportwagen in der Dämmerung bleibt 14 % satter als sein Sprite.
- Kein Wetter in der Luft (R4), kein weicher Fern-Wahrzeichen-Übergang (R7), Lackflackern-Frage pausiert.

Insgesamt: an den Fahrzeugbefunden ist Modern jetzt gleichwertig bis besser als Arcade (Form, Licht), an den
Kurveninnenseiten noch sichtbar schlechter – „deutlich besser als Arcade“ ist Modern an diesen Stellen noch nicht.

## Offen / für die Nächsten

1. **B-01 (Leitung):** F7-Korridor je Kurve = min(300 m, F2-Bedarf), strenge Lesart (Zahlen und Vorschau oben). Bauen
   im Kern (`terrain_profile.gd`: Geschwindigkeit je Reihe), dann `modern_sight.gd -- --full` und die Verdeckungssonde.
   Hilft nur den Bergstrecken; T1/T2/C1/S4/S0 bräuchten eine andere Regel (z. B. Bäume, die in Arcade dieselbe Sicht
   nehmen, dürfen stehen).
2. **B-04 (Assets):** Sportwagen: Bremsband höher (Lampengröße ≈ 0,35 m), mittleres Bremslicht mit Anker in `lights[]`.
3. **B-06:** Sportwagen in der Dämmerung +14 % Sättigung; nach RINT-M2 an S1/C1/N1 mit `sh/paintbox.py` nachmessen
   (die Entsättigung hängt an R4s Nachtgesetz: nachts 0).
4. **RINT-M2:** `git merge-tree` von FIX-M2 mit `origin/wip/v080-r4`, `-r5`, `-r6` ist konfliktfrei (gemessen); R4 ändert
   dieselben Dateien (`vehicles.gd`, `modern_materials.gd`, `lights.gd`, `flares.gd`) an anderen Stellen. Die
   Modern-Goldens danach neu.
5. **B-07 (PERF):** Ladezeit und Hänger auf einer ruhigen Maschine mit ZS1 daneben nachmessen; den Bau der
   Verkehrsmodelle (193 ms Spitze im Fahrzeug-Haken) in `prepare()` vorziehen.
6. **B-09 (R7):** ferne Wahrzeichen weich ausblenden (durchscheinende Variante statt Dither).
7. **Rückfallweg:** Ersatzbild `traffic/van_white` bei 150 m −12 % Helligkeit gegen Arcade (nur Information).
8. **Waldprüfung:** 20 s Sicht dauern bei Last 20 noch 456 s; schneller ginge es nur mit „Mittel“ statt „Hoch“ (aber
   „Hoch“ hat die meisten Bäume).

## Abweichungen

- **Dateieigentum:** Als Nacharbeitspaket habe ich Dateien geändert, die in Welle 3 R4 gehören (`layers/vehicles.gd`,
  `layers/lights.gd`, `vehicle_pose3d.gd`, `modern_materials.gd`, `scripts/race/race_session.gd`), dazu
  `tools/run_render_checks.sh` und `tests/golden/**` (Integration/QA) und `tools/audio/modern/capture_mix.gd` (Klang).
  Jede Änderung ist klein und an Stellen, die R4 nicht anfasst; `git merge-tree` mit R4/R5/R6 ist im Code konfliktfrei.
- **B-01, B-02, B-08, B-10 nicht im Code behoben:** B-01 ist nach A-3/A-10 eine Entscheidung der Leitung (Zahlen und
  Vorschau geliefert), B-02/B-10 baut R4, B-08 ist auf Wunsch des Nutzers pausiert.
- **B-04 nur zum Teil:** der fehlende Teil (Bremsband, Mittelleuchte des Sportwagens) ist Modellarbeit.
- **B-07 nicht behoben:** ohne Last nicht nachstellbar; ein Zeitbudget für `collect` brächte bei ≤ 10 ms ohne Last
  nichts Messbares.
- **B-09 und M2S-06:** B-09 bleibt bei R7; M2S-06 mit der Variante „Abweichung > 2 % = FEHLER“ statt Movie-Maker-Uhr.
- **Vorschau B-01** wurde nur lokal angewandt und wieder zurückgenommen (Arbeitsbaum danach sauber, geprüft).
- **Ein Vollauf von `run_tests.sh`** statt zwei; die vier roten Fälle einzeln bzw. im Wechsel mit der Basis nachgefahren.
