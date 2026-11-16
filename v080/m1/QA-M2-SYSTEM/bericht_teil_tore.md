## 6. Tore auf dem Kopf `6e48405` (gemessen; Last der VM 13–33 durch die anderen Pakete)

| Tor | Aufruf | Ergebnis |
|---|---|---|
| Import / Skripte | `godot --headless --path . --import`; `check_scripts.gd` (in `run_tests.sh`) | Exit 0; 310 Skripte, 0 fehlerhaft |
| Kopflose Tests | `tools/run_tests.sh` (einmal voll, 15:07–15:26) | **„Tests bestanden“, Exit 0, 1 133 s**: 749 Unit-Tests / 0 fehlgeschlagen, 175 CHECK-Zeilen OK, 0 FEHLER; Fairness F1 0 Fälle bis 270 m (Spuren 260 m), F2 ≤ 0,593 / 0,596 / 0,555, F3 0 von 874, F7 0 von 207 166; Pfad 267,6 m / Schleifen ab 2 064 m. Das Ziel ≤ 12 min (A-6) ist unter dieser Last überschritten (M2ZS1: 881 s; V-4) |
| Render-Prüfungen Arcade | `tools/run_render_checks.sh arcade` | **2 / 2 OK**: `check_glow_occlusion` 16/16, `check_sprite_flip` |
| Render-Prüfungen Modern | `tools/run_render_checks.sh modern` (Lauf 1 ganz; nach dem Zeitlimit die übrigen Dateien einzeln, nice 10) | **17 von 17 Dateien OK** (eine erst mit erhöhtem Zeitlimit): `facade_render`, `instance_budget` (ganze Szene ≤ 142 Instanz-Uniforms, Grenze 230), `light_base` (Schatten −0,10 %), `models`, `modern_render` (Helligkeit 10/10, × 0,90–0,99), `occlusion`, `props_render`, `quit_sound` (3 Starts, kein „leaked“), `road_parity`, `seam_render`, `session_modern`, `showroom_render`, `start_km0` (Kanten ± 1 px, Kamera ≤ 1,14 px), `terrain_cover` (T1–T4, S1, C1, K1: 0,000 % Magenta), `vehicle_lights`, `vehicle_standin` (leer bestanden, M2S-02). `instance_budget_wald`: in den Läufen 1–2 unter Last kein Ergebnis (Exit 124 nach 900 s; Wiederholung nach 21 min abgebrochen, M2S-01); ⟨WALD⟩ |
| Arcade-Bilder | `tools/golden.sh check` (einmal, zum Schluss) | ⟨GOLDEN⟩ |
| Modern-Änderungsmelder | `KEEP=… tools/golden.sh modern-check` | ⟨MODERNCHECK⟩ |
