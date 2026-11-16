Beim Auflösen der Konflikte (Merge-Commit von R3): `assets/shaders/modern/vehicle_shadow.gdshader` (R3s Datei unter
neuem Namen), `scripts/race3d/layers/vehicles.gd` (eine Zeile: Klasse `vehicle_shadow`), `docs/renderer-modern.md`
(§10 R1, §11 R3).

Danach (10 Commits, a27d3ed … fd27c16):

| Bereich | Dateien |
|---|---|
| Shader | `assets/shaders/modern/{terrain, far_ground, vpbr, glass, billboard, leaves, flare}.gdshader`, `vehicle_shadow.gdshader.uid` |
| Renderer | `scripts/race3d/terrain_profile.gd` (3 Kernzeilen), `builders/terrain.gd`, `builders/props.gd`, `layers/far_ground.gd`, `layers/lights.gd`, `prop_library.gd` |
| Sitzung, Audio | `scripts/race/race_renderers.gd` (`leave_modern`), `scripts/ui/game_flow.gd`, `scripts/audio/audio_manager.gd` (`_exit_tree`) |
| Konfiguration | `config/game_config.json` (`graphics.modern.props`, Doku-Text) |
| Prüfungen | `tests/race3d/check_terrain_plan.gd` (STRICT), `tests/race3d/check_vehicles.gd`, `tests/race3d/check_modern_stage.gd` (`kern_zeit`), neu `tests/race3d/fixtures/core_renderer.gd` (+ .uid), `tests/race3d/render/{check_light_base, check_models, check_occlusion, check_props_render}.gd`, neu `tests/race3d/render/check_session_modern.gd` (+ .uid), `tests/unit/race3d/test_props.gd`, `tools/run_tests.sh` |
| Doku | `docs/renderer-modern.md` §1 und §12, `docs/renderer-modern-gelaende.md`, `docs/modelle.md` |

Nicht angefasst: die gefrorenen Arcade-Dateien, `assets/models/player/**`, `assets/models/traffic/**`; aus der
R3E-Liste nur die eine Zeile in `layers/vehicles.gd`.
