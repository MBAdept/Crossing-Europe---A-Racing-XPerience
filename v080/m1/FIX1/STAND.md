# FIX1 – Stand (Übergabe)

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-4
- Branch: worktree-wf_ae4df3ba-14f-4 (Sicherung: origin/wip/v080-fix1)
- Basis: 9b6adbce9b2b1443ee3ec795c16460e3890328b3

## Erledigt (Commits, alle gepusht)
- b3588dd QS-01/02/03 Prüfläufe lastfest
- 0d16993 QB-07 Nebelgesetz; QB-05 Mondglanz
- 6132d8d QB-01 Tunnel
- 67a24bb QB-02 Tankstelle, QB-04 Tore, QB-03 Wahrzeichen/Geländer/Wasser
- ad73998 QS-04 Fehlstarts, QS-07, QS-08, check_minimal_structures.gd (5/5)
- 03d5f26 QB-10 Zeit je Teil von render(); QB-11 sichtgrenze-Render-Prüfung
- 28e4e8e Doku renderer-modern.md §14, grafik-modi.md

## Jetzt
- Tore: run_tests.sh Lauf 1 läuft (Log m1/FIX1/gates/run_tests_1.log); danach golden.sh check, run_render_checks.sh all,
  S4-Wasser + S2H22 neu rendern und ansehen, bericht.md (deliver/FIX1) fertig, StructuredOutput.

## Fallen
- Bash: keine heredocs mit cd + git; Patch-Skripte in tools/; git-Befehle einzeln.
- run_tests.sh nur noch 1× erlaubt (Lauf 1 läuft/lief).
- A/B: tools/ab.sh <ABSOLUTER ordner> medium <pos> -- --shot-times=2,6 ; MODES=modern ARCADE_REF=../QA-BILD/ab_med
