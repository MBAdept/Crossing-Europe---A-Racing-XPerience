# QA-R7c – unabhängige Prüfung von R7c (Fern-LOD der Bauten und Pflanzen), Stand `bd1803b`

- Prüfling: `origin/wip/v080-r7c` = `bd1803bbde9e1b7ccff6c3512fee8872d6a20103` (Basis `9b02f05` = RINT-M2, darin die Mischung
  von `wip/v080-as5ar2` als `43a1fcc`). Bericht des Pakets: `deliver/R7c/bericht.md`.
- Arbeitsbaum `…/worktrees/wf_ba4424b4-294-7` (ff auf `bd1803b`, nichts committet, nichts gepusht). Vergleichsbäume
  (git archive + `.godot`, importiert): Basis `m1/QA-R7c/base` (9b02f05), **`m1/QA-R7c/merge` (43a1fcc = Basis +
  AS5aR2-Modelle, vor R7c's eigenen Commits)** – nötig, weil die Basis des Briefs die neuen Stadthäuser von AS5a2 noch
  nicht hat (Paris, Amsterdam, Bern, Lyon zeigen dort Sprites); nur gegen 43a1fcc sieht man, was R7c selbst ändert. (Die Kopien und die Mutationskopie `mut` sind nach der Prüfung gelöscht – Platz; `sh/mkcopy.sh <rev> <ordner>` baut sie neu.)
- **gemessen** = auf dieser VM (llvmpipe unter Xvfb, 4 Kerne geteilt mit bis zu zwei weiteren Agenten); **angesehen** =
  Urteil nach Bildern; **gefolgert** = hier nicht messbar (echte GPU, Steam Deck, Wirkung auf einen Menschen).
- Werkzeuge und Rohdaten: `m1/QA-R7c/sh/` (Warteschlangen, `tri.sh` Arcade | Basis | [43a1fcc] | R7c, `mutate.py`,
  `perf.sh`, `picstats.py`, `tilepeaks.py`), `m1/QA-R7c/probe/` (`scan_r7c.gd`, `bands_all.gd`), Logs `gates/`, `scan/`,
  `mutlogs/`, `perf/`, `k6/`. Bilder: `deliver/QA-R7c/raw/<ort>_<stufe>_h<stunde>_tri_NN.jpg` (+ Einzel-PNGs, Diff-Bilder).
