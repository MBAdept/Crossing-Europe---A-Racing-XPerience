### 3.4 Render-Mutationen (gemessen, `tools/run_render_checks.sh modern <datei>` in der Kopie)

| Nr. | Regel | Mutation | Ergebnis |
|---|---|---|---|
| R1 | Raster im Band (1) | `ce_lod_discard` gibt nie „verwerfen“ zurück (beide Stufen voll) | **gefangen** – `check_lod_band` „lod_ueberblenden“ FEHLER: größter Schritt 6,1 % gegen hart 7,1 % |
| R2 | genau eine Stufe wirft Schatten (1) | Schattendurchgang nimmt das Raster des Hauptdurchgangs (`shadow > 5.0`) | **nicht gefangen** – `check_lod_band` OK |
| R2b | dto., der ursprüngliche Fehler des Pakets | im Schattendurchgang entscheidet die Bandmitte | **gefangen** – `check_lod_band` FEHLER: 9,3 % gegen hart 7,1 % (der Fehler, den R7c gemeldet hat) |
| R3 | Fernlicht (2) | `ce_far_attenuation` gibt `att` zurück | **nicht gefangen** – `test_props`, `check_lod_band`, `check_props_render` grün |
| R4 | Fenster in der Dämmerung (4) | `cover_k = 0.0` | **nicht gefangen** – `test_props`, `check_props_render` grün |

### 3.5 Arcade-Identität (gemessen, einmal am Ende)

`tools/golden.sh check` auf `bd1803b`: **`GOLDEN arcade: 20 von 20 identisch` (174 s), `GOLDEN arcade-ui: 17 von 17
identisch` (204 s)**, Exit 0 (`gates/golden_check.log`).
