## 9. Geprüft und in Ordnung

- Keine eingefrorene Arcade-Datei geändert; R7c bleibt in seinen Dateien (Abschnitt 3.1); `environment_rig.gd` unberührt.
- Gates: Skripte, 808 Tests, 29/29 Render-Prüfungen (darunter `check_start_km0`, `check_terrain_cover` mit K1,
  `check_light_base`, `test_far_ground_water`/`test_props` in den Tests, `check_instance_budget*` ≤ 216/230), Sicht
  F1–F3/F7/Modell und Wege mit `--full`, Arcade-Goldens (3.5).
- Datenscan aller 128 Richtungen + DEV: R7c zeichnet genau dieselben 195 741 Requisiten wie 43a1fcc; 602 113
  Instanzen mit gültiger Phase; Bänder aller 77 Modelle × 3 Detailstufen lückenlos.
- Stufenwechsel ohne Sprung: `check_lod_band` (0,6 % gegen 7,1 %; Eiche 1,1 % gegen 36,6 %); R7cs Clips Nürnberg und
  Paris Kachel für Kachel ohne Stufen-Spitze (Spitzen-Verteilung wie Arcade).
- Schattendurchgang: genau eine Stufe wirft; Modelle mit eigenem Schattennetz werfen ohne Band.
- Fernlicht-Mechanik gelesen: Einblenden mit `directional_shadow_fade_start` 0,85 der Engine; in der Nähe unverändert
  (Hoch-Bilder Hamburg/Nürnberg/Wald 0,05–0,5 % Pixel gegen die Basis, Luma ±0,6).
- `ground_sink` versenkt höchstens 0,33 m (10 % der Höhe); `face_road` dreht Klippen höchstens ±20° (Test grün).
- Instanzbudget A-19: keine neue Instanz-Uniform; Bänder/Fernlicht als Material-Uniforms, Phase in MultiMesh-Custom.
- Leistung: Bildzeit und `render_ms` gleich, 10–13 % weniger Primitive, Zeichenaufrufe weit im Budget; `ERGEBNIS`
  identisch (Regel 3).
- lod1 bei 32–50 m für Kontor, Fachwerk, Haussmann, Block A im Studio bei 1× fast gleich lod0 (Speicher nicht – QR7c-01).
- Bei Tag ist Modern in Hamburg, Nürnberg, Paris, Amsterdam, Bern klar besser als Arcade; R7c verschlechtert dort bei
  „Hoch“ nichts gegen die Basis.
- Zusammenbau-Probe: kein Konflikt mit R7a, R7b, FIX-R7b, FIX-R7a (`4a43944`); nur `test_props.gd` mit FIX-RINT.
