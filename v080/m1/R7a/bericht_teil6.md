## 9. Commits (Branch `worktree-wf_ba4424b4-294-1`, jeder auf `origin/wip/v080-r7a` gesichert)

| Commit | Inhalt |
|---|---|
| `011c612` | Sichtkorridor aus der wirklichen Geometrie (A-17): `sight_corridor.gd`, `terrain_profile.gd` |
| `26c9b48` | je Kamerareihe exakt, Vorrechnen im Streamer |
| `96e403d` | Folgen: Stadtzaun je Stück, Testvorlagen (`test_props.gd`-Hunk, siehe §7) |
| `a78737d` | F7 prüft die Hülle gegen eine unabhängige Referenz (`fairness.gd`, `modern_sight.gd`) |
| `052de62` | Grenzdach: Pfeiler gegen die genaue Hülle (A-18) |
| `613c0f0` | Doku `renderer-modern.md` 5.3 |
| `738e7fc` | UID des Einheitstests |
| `e81886a` | `ChunkContext`: Kommentar |
| `43cfd97` | `in_bend_corridor(z, x, reach, half_len)` – Fußabdruck-Test, Test |
| `b3f1b67` | Doku Fußabdruck |
| `7d8bbb6` | Vorrechnen bis hinter `landmark_path_m`, Messung `corridor_sync_*` |
| `509bb16` | Doku Vorrechnen (**Endstand**) |

Geänderte Dateien gegen `9b02f05`: `scripts/race3d/{sight_corridor.gd (neu), terrain_profile.gd, chunk_context.gd,
chunk_streamer.gd}`, `scripts/race3d/builders/{border.gd, city.gd}` (Ausnahmen der Leitung), `tests/race3d/fairness.gd`,
`tests/sim/modern_sight.gd`, `tests/unit/race3d/{test_sight_corridor.gd (neu), test_terrain_profile.gd,
test_chunk_streamer.gd, test_structures.gd, test_props.gd}`, `docs/renderer-modern.md`.

## 10. Für die Nächsten

- **R7c (`builders/props.gd`):** in `drop_reason()` und beim Bodendecker-Test den Fußabdruck prüfen:
  `ctx.in_bend_corridor(z, x, reach, half_len)` mit `reach = absf(x) - absf(x_vorderkante)` (bei `align: edge` die
  Ausdehnung × Maßstab, sonst halbe Breite × Maßstab = Kronenradius) und `half_len` = halbe Breite × Maßstab. Gemessen
  bliebe nichts Weglassbares in der Hülle (Rest 269, nicht weglassbar); zurück kämen 15.954 statt 22.432.
  Außerdem den `test_props.gd`-Hunk (Vorlage Stück 13) beim Zusammenführen beachten.
- **Station (`builders/station.gd`):** `bend_corridor_at()` könnte wie der Grenz-Builder die genaue Hülle lesen
  (`tp.sight.width_near(k, side)`) statt der aufgerundeten Kodierung.
- **Leitung:** Stadtkurven – soll in den City Limits der F2-Bedarf aus dem Tempolimit gelten (§8.3)?
- **Integration/QA:** `modern_slice.md5` nach dem Zusammenführen neu erzeugen (4 von 6 Bildern ändern sich gewollt).
- **Leistung:** `perf_stats()` → `streamer.corridor_sync_*` zeigt jedes Nachrechnen im Hauptthread; bei Zeitraffer 40
  ist es unvermeidlich (§5).
