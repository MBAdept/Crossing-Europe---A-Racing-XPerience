# QA-BILD STAND — FERTIG (20:35)

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-2 (ff 9b6adbc, clean,
  no commits). Scratch: m1/QA-BILD (tools/, probe/, notes.md, bericht_*.md parts, perf/, ab_med/, ab_var/, clips/probe).
- Report: deliver/QA-BILD/bericht.md (assembled by tools/assemble.py from m1/QA-BILD/bericht_*.md) + ab_mittel/,
  ab_varianten/, details/, clips/ (4 mp4), pruefungen/ (logs, samples, save/ pictures).
- Gates: golden 20/20 (20:13), fairness full OK, render checks (terrain_cover, road_parity, light_base, vehicle_lights,
  occlusion, vehicle_standin) OK, ERGEBNIS Arcade=Modern (28 keys, gfx only). run_tests not run (QA-SYSTEM did).
- Findings B1-B12 in bericht.md §1. Cleanup done (AVIs, mesa cache, xdg dirs deleted). No background processes left.
- Next: only the StructuredOutput (if a successor runs: build it from bericht.md §Urteil and §1).
