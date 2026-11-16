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
