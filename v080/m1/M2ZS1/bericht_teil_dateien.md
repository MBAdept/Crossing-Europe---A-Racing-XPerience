
## 8. Dateien

- Geändert gegen `49f221e` (25 Dateien): aus ZS1 `scripts/race3d/{road_path,chunk_context,chunk_streamer}.gd`,
  `layers/{vehicles,far_ground}.gd`, `builders/{gantry,props}.gd`, `tests/race3d/render/check_start_km0.gd`,
  `tests/race3d/render/check_terrain_cover.gd`, `tests/race3d/check_terrain_plan.gd`,
  `tests/unit/race3d/{test_start_lead_in,test_far_ground_water}.gd`; von M2ZS1 außerdem `builders/props.gd`
  (Pylon-Modell dunkel, Blinktakt), `layers/flares.gd` (`blink_lit`), `assets/shaders/modern/baked.gdshader`
  (`night_albedo`), `tests/unit/race3d/{test_props,test_terrain_builder}.gd`, `tests/golden/modern_slice.{md5,env}`,
  Doku `docs/{renderer-modern,renderer-modern-gelaende,qa-v080,modelle}.md`.
- Bilder für die Leitung: `deliver/M2ZS1/bilder/` – 26 Dreierbilder Arcade | ZS1 | M2ZS1 (halbe Größe) und
  `pylon_nacht_km78_1_arcade_zs1_vorher_nachher.jpg` (Pylonbereich: Arcade, ZS1, zusammengeführt, behoben).
- Arbeitsdateien: `m1/M2ZS1/` – `STAND.md`, Skripte `sh/` (`tests.sh`, `ab.sh`, `modern_only.sh`, `measure.py`,
  `paintbox.py`, `tri.sh`, `tris.sh`, `pictures.sh`, `after.sh`, `modern_make.sh`, `gates.sh`), Rohbilder `shots/`,
  Proben `probe/`, Modern-Änderungsmelder `golden_make_keep/`, Logs `logs/`, Gates `gates/`.
- Builds liegen im Worktree unter `build/` (aus `6e48405`): `CrossingEurope.x86_64` 496,5 MB,
  `CrossingEurope-windows-x86_64.zip` 194,5 MB, `CrossingEurope.exe`, `LIZENZEN.txt` (nicht committet, `/build/` ist
  ignoriert).
