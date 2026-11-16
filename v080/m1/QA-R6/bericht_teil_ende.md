## 7. Geprüft und in Ordnung

- Arcade bildgleich (20/20, 17/17), keine eingefrorene Datei berührt, `arcade_lean` grün.
- Fairness-Gates `modern_sight --full` (F1, F1-Spuren, F2, F3, F7, Modell) und `modern_path_check --full` grün.
- Regel 3: gleiches `ERGEBNIS` und gleiche Verkehrs-Hashes in allen 400 Sekunden der Testetappe ab km 10 (Arcade gegen Modern).
- Jede Tankstelle, Grenze, jedes Tor, jeder Blitzer und jede Stadtlaterne des Netzes wird gebaut, wo Arcade sie zeichnet
  (0 Abweichungen in 5366 Stücken, 0 Skriptfehler).
- Tankspur-Geometrie = `Track.fuel_lane_*` (Unit-Test, durch Mutation M01 bewacht).
- Dachhöhen über Fahrbahn und Spur: nichts unter 5,6 m (Tankstelle) bzw. 6,0 m (Grenze) außer den Leuchtkästen (6 bzw. 10 cm),
  Unit-Test grün (Wächter siehe B-04).
- Nach außen gerückte Pfeiler/Stützen verdecken praktisch nie ein Schild (2 Paare netzweit, beide ≥ 475 m).
- Schrift nur als Tafel (`PanelAtlas`), kein `Label3D`; „ČESKO“ mit Diakritik richtig; „TANKSTELLE“ nachts lesbar.
- Countdown-Regel = Arcades `_start_light_glows` (Render-Prüfung und Unit-Test, Mutation M10 erkannt); Auto im Countdown an
  Arcades Stelle (`check_start_km0`: 193×193 bei (544, 470) gegen 192×192 bei (544, 471)).
- Laternen alle 33 m im Seitenwechsel mit Lichtkegel, Kegel 0,490 gegen Arcade 0,501 (Render-Prüfung `stadt`).
- Blitz folgt `view.radar_flash01`, unter 0,05 aus (Mutation M11 erkannt); sichtbar am Kopf (Render-Prüfung `blitz`).
- Fixes des ersten Testbuilds halten: `check_start_km0`, `check_light_base`, `check_terrain_cover` (K1 0,000 %),
  `test_far_ground_water` 4/4, `test_props` 12/12.
- `props.gd` braucht keine Ausnahme: es überlässt die Laternen dem Builder `city` bereits selbst (`_skip_objects`).
- Kein Builder spricht ein anderes Paket dieser Welle über eine `class_name` an; nur Fassade und `has_method`.
- Statisches `vpbr` ohne Instanz-Uniforms (63 statt 102 Instanzen mit Uniforms laut R6; Unit-Test, Mutation M13 erkannt);
  Bauten werfen bei „Schatten: Aus“ nichts (M12 erkannt, Render-Prüfung `schatten`).
- Gegen die Basis `6e48405` sieht nichts schlechter aus (Bilder 03, 03b, 25, 26, 27).

## 8. Für die Nächsten (genaue Änderungen)

1. **B-01** `scripts/race3d/builders/border.gd:420` – Leitungsentscheidung: `front_out` von der Korridor-Regel ausnehmen
   (`if str(p[2]) != "front" and str(p[2]) != "front_out" and ctx.in_bend_corridor(zp, px): continue`) oder Kragträger zeichnen.
   Danach `bin/scan_all.gd` erneut: erwartet 0 einseitige Dächer.
2. **B-02** `station.gd` `columns_in_chunk()`/`column_plan()`: Endstütze `end` nur, wenn keine Sichtlinie von einer
   Fahrspurmitte 55–400 m vor einem Schild bis 400 m hinter dem Dach sie schneidet (Vorlage `bin/scan_f1.gd`), sonst `end_out`.
3. **B-04** `tests/unit/race3d/test_structures.gd:144/249/358`: Arcades Literale 5.6, 6.0 und die Kegelmitte 0,55 statt der
   Builder-Konstanten.
4. **B-03** `gantry.gd`: helle Stützen (`STEEL` ≈ `e6e8ea`), `NIGHT_GLOW` ≈ 0,8; Shop-Nachtbild beim Modell-Paket (A-16).
5. RINT-M2: `tools/golden.sh modern-make` einmal auf dem Gesamtstand (R4, R5, R6 ändern `modern_slice.md5`).
6. `docs/renderer-modern.md` (R4): ein Verweis auf `docs/renderer-modern-bauten.md`.
7. `flares.gd` (R4): Einträge mit Rolle `"on"` und `energy` 0 überspringen (heute je Bild eine unsichtbare Instanz je
   Blitzerkamera und Countdown-Lampe); optionale Schlüssel `glow`/`halo`, wie R6 vorschlägt.
8. QA: `check_attract.gd` „idle“ gegen Spielzeit messen (lastfest, A-11).
9. B-05 folgt der offenen Korridor-Entscheidung (FIX-M2 B-01); danach `scan_all.gd` für die Zaun-Quote.

## 9. Werkzeuge und Rohdaten (Scratch, nicht committet)

`…/scratchpad/v080/m1/QA-R6/`: `bin/scan_all.gd` (Netz-Funktionstest), `bin/scan_f1.gd` (Sichtlinien Pfeiler/Stützen →
Schilder), `bin/info.gd` (Elementpositionen), `bin/mutate.py` (18 Mutationen), `bin/make_qa_zeit.py` + `bin/qa_zeit_rep.sh`
(Renderer-Zeit Kopf/Basis), `bin/perf.sh`, `bin/chain_a.sh`, `bin/chain_b.sh`; Logs in `gates/`, `scan/`, `perf/`, `mutlogs/` (die Kopien `base/` und `mut/` sind gelöscht; `check_qa_zeit.gd` und `check_session_qa.gd` liegen in `bin/`);
A/B-Einzelbilder als JPEG in `shots/` (PNG gelöscht).
