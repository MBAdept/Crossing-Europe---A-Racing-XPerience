## 2. Notizen der Leitung 1–10

1. **Doku-Konflikt** – gelöst wie in Abschnitt 1; §11.8 (Ersatzbilder) im Fahrzeug-Abschnitt, Verweise 11.1/11.7
   angepasst.
2. **run_tests auf dem letzten Kopf** – siehe Gates (Abschnitt 6).
3. **Robuste Zeitprüfungen** – `tests/race3d/fixtures/perf_clock.gd`: Referenz-Arbeitslast im selben Prozess, neben
   jeder Probe gemessen, auf das normale Tempo der VM umgerechnet (`REF_NOMINAL_US` 600 µs; die Thread-CPU-Zeit taugt
   nicht: `schedstat` springt in Scheduler-Ticks, 0 µs für 2 ms Arbeit – gemessen). Benutzt von `check_vehicles` →
   `leistung` (≤ 40 µs je Auto) und `check_modern_stage` → `kern_zeit` (≤ 0,6 ms); neu `renderer_zeit`: **ganzer
   Renderer ≤ 1,5 ms GDScript je Bild** (alle Builder und Ebenen, Verkehr der Sitzung), Tabelle in
   `docs/renderer-modern.md` §13.6. Gemessen: 32,6–34,6 µs je Auto, Kern 0,23 ms, ganzer Renderer 0,80 ms (13 Autos).
4. **Horizont** – Silhouetten auf Arcades Zeile (Kuppenregel `base_y = max(clip, hy − 120)` in `backdrop.gd`), Fernboden
   in Landfarbe mit Arcades Bodennebel statt Tiefennebel (F4: nie mehr Nebel als Arcade), Gelände mit demselben Nebel
   (`FOG` im Compatibility-Renderer), Rand des Fernbodens bis zur Silhouettenzeile, mit dem Mittel des fernen Bodens.
   Gemessen an S1: Unterkante der Silhouetten Zeile 320 = Arcade (vorher 323), Zeilen 321–330 Land 108–114/148–155/
   66–69 statt Nebel 197/219/237; T4 kein „See“ mehr; T1 Land bis an die Hügel (A/B-Bögen). `check_terrain_cover` in
   den Render-Prüfungen.
5. **Nacht** – *Ursache der Dunkel-Quetschung*: der fest eingeschaltete Nachbearbeitungspfad schickt das Bild ein
   zweites Mal durch die Näherungen der Engine (sRGB-Polynom, Anzeige ohne linearen Fuß); geschriebene 8/255 kamen als
   1/255 heraus, 16 als 11 (gemessen, `probe/post_probe.gd`). *Abhilfe*: 1D-LUT im Environment, ab 8/255 genau. *Boden
   zu hell*: Bodengesetz (Fahrbahn, Gelände, Fernboden schreiben den Umgebungsdurchgang selbst: ebener Boden = Albedo ×
   Arcades Umgebung, bei jeder Albedo): N1 Schneeboden +50 %/+37 % → +1,7 %/−8,5 %; S4 22 Uhr Gras +34 % → −16 %
   (gemessen). *Laternen*: Arcades warmer Schein (2,4 m, ≥ 3 px) in `flares`. Abgestimmt an S1 22 Uhr, S4 22 Uhr, N1.
6. **Ersatzbilder ohne Sonnenschatten und ohne zweiten Fleck; Kasten-Ersatzbilder werfen wie Modelle** – umgesetzt,
   `check_vehicles` → `schatten` prüft alle Presets; Bild bei „Hoch“: der gelbe Sportwagen an S1 trägt nur seinen
   eingebackenen Schatten (`look/S1_*`).
7. **F7 streng** – unverändert.
8. **Bögen nur in `prepare()`; Texturspeicher** – Arcade 221,1 MB, Modern 166,8 MB (davon 17 Bögen 51,5 MB), gemessen
   Kiel–Hamburg. Unter der Grenze Arcade + 60 MB (A-6) – keine weitere Einschränkung nötig (Bögen ohnehin nur für Sets
   ohne Modell).
9. **Doku** – §11.1/§11.7 auf die Ersatzbilder (Sprite vor gemaltem Kasten), §11.8 Schattensatz; ARCHITECTURE.md §15:
   `leave_modern(always)`, `quality_lowered`, `gfx_lowered`; `docs/modelle.md` Kanal 15; neuer §13 in
   `docs/renderer-modern.md`.
10. **Ladezeit Kiel–Hamburg Modern** – 5,2–5,6 s ab km 0 bis „live“ (Arcade 0,85 s), gemessen wie `prepare_s` des
    Leistungstests; die ganze Zeit hinter dem Ladebild. Der Balken lief vorher einmal rückwärts (0,1 → 0,05) und stand
    während des Ladens der Startansicht bei 0,05; jetzt 0,05 → 0,1 → 0,65 → 0,83 … 1,0. Offen: das Laden der
    Startansicht ist ein Bild von 1,6–1,9 s (der Balken steht so lange).

## 3. Fahrzeuge, Showroom, Klang, Leistungstest

- **Lampen**: unbeleuchtet 0,28 (`lamp_off`), Rücklicht Kanal 2 bei 0,5 (`tail_level`); **Bremse 3,9 × Rücklicht**
  um 22 Uhr (gemessen, `probe/brake_probe.gd`, schwarze Limousine 18 m voraus).
- **Lack** (Knie über 0,7, Steigung 0,45, 8 % Entsättigung; nachts Himmelsspiegel 35 %, Fülllicht 30 %), gemessen
  gegen die Cycles-Sprites in der Spielkamera (Farbton / Helligkeit): Limousine mittags −3,4° / +6,7 %, 19:30 −9,6° /
  +3,3 %; Kompakt mittags −1,3° / −7,8 % (am Anschlag 2 % statt 29 % bei Arcade), 19:30 +5,9° / **−16,2 %** (Sonne
  voraus, Heck im Schatten – außerhalb der 10 %); nachts Limousine +31,8 % (vorher +53 %), Kompakt −10,5 %.
- **Rückstrahler** (Kanal 15 `retro`): Konturband und Dreiecke des Lkw im Kegel des eigenen Abblendlichts
  (`ce_headlight_*`), Lkw neu exportiert/gebacken; Schilder strahlen schon das echte Abblendlicht zurück.
- **lod1 → lod2**: Dither-Überblendung über 0,5 s (`xfade`). Gemessen (ruhige Szene, Auto zieht langsam durch die
  Grenze bei 94,5 m, Preset der Maschine): vorher **5,4 %** der Autopixel in einem Bild, jetzt 0 % im Wechselbild und
  ≤ 3,5 % je Bild verteilt; Kosten ein Zeichenaufruf je blendendem Auto. Prüfung `check_vehicles` → `ueberblendung`.
- **Showroom**: A/B mit derselben Kamera (`models_contact_sheet.sh … --only="player/*" --showroom`, jetzt mit dem Look
  des Showrooms) – Echtzeit heller, gesättigter, aber flacher als die Sprites → `showroom` bleibt `false` (Manifest
  unverändert). Bild `showroom_ab.png`.
- **Klang**: `GameFlow.quit_game()` stellt den Klang ab, wartet 0,3 s, dann `quit()`; Render-Prüfung
  `check_quit_sound.gd` (je Profil drei Starts). Motor v3, Rennmusik zum Einzählen, Ducking, Arcade unverändert,
  Ende ohne Lecks: AU-D1-Prüfungen in `run_tests` (`check_music`, `check_engine3`, `check_modern_audio`).
- **Leistungstest**: siehe Gates.

## 4. Neu gefunden: Instanz-Uniforms sprengten Godots globalen Shader-Puffer

Bei den Messungen fiel „Too many instances using shader instance variables“ auf (15 Meldungen in 900 Bildern mit
Verkehr am Stand b473e90, gemessen). Godot (Compatibility) gibt jeder Instanz mit `instance uniform` 16 Plätze eines
Puffers, der nur so groß ist wie der Uniform-Block der GPU (64 KB = 4096 Plätze – llvmpipe und die meisten
Desktop-Treiber): ≈ 250 Instanzen in der ganzen Szene; darüber zeichnet Godot eine Instanz mit den Werten einer
anderen. Die Fahrzeug-Pools behielten ihre gebauten Stufen, die Zahl wuchs mit dem Verkehr ohne Ende. Abhilfe:
`INSTANCE_BUDGET` 128 in `layers/vehicles.gd` (gepoolte Autos zuerst freigeben, dann nicht gezeigte Stufen); Prüfungen
`check_vehicles` → `instanzen`, Render-Prüfung `check_instance_budget.gd` (Logger fängt die Ablehnung), und
`run_render_checks.sh` lässt jede Render-Prüfung mit dieser Meldung scheitern. Gemessen: ganze Szene höchstens 196
(100 s Verkehr) bzw. 229 Instanzen, keine Ablehnung; am alten Stand nach 100 s schon 220 und wachsend.
