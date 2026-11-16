# FIX-R5 – Nacharbeit nach der unabhängigen Prüfung von R5 (Tunnel, Brücken, Wasser und Ufer)

Paket **FIX-R5** der Welle 3 von M2 (Modus „Modern“, v0.8.0). Basis: R5s Kopf `5558bdc` (`origin/wip/v080-r5`), per
`git merge --ff-only` in den frischen Worktree `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-6`
(Branch `worktree-wf_fd1de4ee-28b-6`); einen Vorgänger gab es nicht (kein `STAND.md`, kein `wip/v080-fix-r5`). Jeder Commit
gepusht nach `origin/wip/v080-fix-r5` (Sicherung, nie force). Eigentum: dasselbe wie R5 (`builders/{tunnel,bridge}.gd`,
`tunnel/water.gdshader`, `layers/far_ground.gd`, die drei R5-Prüfdateien, Doku). Geändert habe ich nur
`builders/tunnel.gd`, `tests/unit/race3d/{test_tunnel,test_bridge}.gd`, `tests/race3d/render/check_tunnel_bridge.gd`,
`docs/renderer-modern-tunnel-bruecken.md`, `docs/renderer-modern.md` (§15) – keine Arcade-Datei, keine Datei von R4/R6,
kein Golden.

„gemessen“ = auf dieser VM (Mesa llvmpipe unter Xvfb bzw. headless, 4 geteilte Kerne, Last 10–17 durch die
Nachbarpakete); alles über Steam Deck und echte Grafikkarten ist **abgeleitet**. Schwere Läufe einer nach dem anderen
mit `nice -n 10` (`QA_M2_FERTIG` lag vor). Arbeitsdateien: `m1/FIX-R5/` (Skripte `shots.sh`, `queue.sh`, `perf.sh`,
`mutate.py`, `measure.py`, `cmp.py`; Bilder `shots/`, Läufe `perf/`, Gates `gates/`).

