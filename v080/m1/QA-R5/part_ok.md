## 8. Geprüft und in Ordnung

- Eigentum: nur R5-Dateien, `far_ground.gd` (Leitungsentscheidung) und die Doku; keine Arcade-Datei, keine Datei von R4/R6;
  `props.gd` unverändert – sein `skip_bridge` (Z. 78, 111, 526, 719–720) greift, weil alle Builder vor dem ersten
  `setup()` existieren (`modern_renderer.gd` Z. 384–387: „every object exists before the first call“).
- Arcade bitgleich: `GOLDEN arcade: 20 von 20`, `GOLDEN arcade-ui: 17 von 17`.
- Builder-Regeln (A-3): `build()` von `bridge.gd`/`tunnel.gd` nutzt nur Snapshot-Daten und die Eingabe von
  `collect()`; Zustand nur auf dem Hauptthread (`collect`, `commit`, `update`); Seilenden aus dem Pfad in `collect()`.
- `set_zone` duck-typed (`has_method`), nur bei Änderung; ohne die Methode bleibt `tunnel01` (Code + Test).
- Wasser-Shader liest `ce_time`, nie `TIME` (Regel 10); Nebel nach Arcades Bodengesetz (höchstens 70 %, F4).
- Fernboden: ZS1-Regel bleibt (`target_height` = min(Straße − 4 m, Wasser − 0,3 m)), `test_far_ground_water` 4/4, K1 0,000 %;
  Floating-Origin: Flüsse/Land werden in `rebased()` mitverschoben, Höhen ändern sich beim Rebase nicht (road_path.gd Z. 245–254).
- Netz: alle 122 Brücken, 28 Tunnel bauen headless ohne Fehler; Teile = Arcades Ereignisse; Ufer an beiden Enden.
- Fairness: `modern_sight --full` und `modern_path_check --full` grün; nichts von R5 über den Spuren; Seile ≥ 2,15 m;
  Hügel nie im Sichtkorridor der Anfahrt.
- Köhlbrandbrücke: 4 Pylone, Höhe 95/88,8 = 1,07, 56 Seile, 4 Flugfeuer im Takt von Arcade (Bild: gleiche Phase in
  Arcade und Modern), Pylonfeld nachts unter Arcade (gemessen 44,0/45,1/52,3 gegen Arcade 46,4/49,9/55,2, Basis
  42,4/42,9/51,9 – Fenster x 500–780, y 150–350 von `kb_nacht_00–02`).
- Bestimmtheit: Prüflingsbilder = R5s Bilder bitgleich (24 Bilder), Basisbilder = R5s Basisbilder bitgleich.
- Render-Prüfungen des Pakets und die drei ZS1-Wächter (`check_start_km0`, `check_terrain_cover` K1, `check_light_base`) OK.
- R5s Clips (`deliver/R5/clips/`, je 30 s, 60 fps fest) angesehen (Kontaktbögen alle 3 s): keine Sprünge, Portal und
  Brücke an derselben Stelle wie Arcade; nicht neu gerendert.
