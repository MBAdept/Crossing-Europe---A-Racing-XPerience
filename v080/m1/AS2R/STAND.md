# AS2R – Stand (Übergabe für Nachfolger)

**FERTIG (15:05).** Lieferung: `/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS2R/`
(bericht.md + 20 Bilder).

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-4 (git status leer)
- Branch: worktree-wf_72970c4d-66e-4, Ende `c7546c1`; Sicherung origin wip/v080-as2r = c7546c1
- Basis: 19624cd (AS2a + AS2b)
- Commits: 7c86864 (C2), a79f959, d5a62a2, ecff521, 8039c36, 77cea90 (WIP), 2faa219 (Lkw/Bus-Scheiben, Doku 16),
  c7546c1 (Doku-Umbruch)

## Gates (gemessen)
- Prüfer CHECK models OK (37 Modelle, 16,45 MB); check_sprite_geometry 61/61 identisch
- Determinismus: alle Fahrzeuge (14:10) und Polizei+Lkw/Bus nach 2faa219 (14:48): git leer, 2. Bake gleich, check-keys OK
- run_tests (1x, 613 s): 594 Unit-Tests 0 Fehler; rot nur check_vehicles kasten/leistung (R3, wie AS2b)
- golden check (1x): 20 von 20 identisch

## Werkzeuge (Scratch m1/AS2R)
- bin/rebuild.sh, bin/sheet.sh, bin/gates*.sh, bin/final_gates.sh, bin/deliver_images.py, bin/assemble.py
- kritik/: probe.sh, round.sh, run_jobs.sh, bin/*.py (pop_split, bandmean, buswin, winmean, platemean ...)
- kritik/tools_kritik/kritik_render.gd + kritik_dump.gd: für Renders nach <worktree>/tools/kritik/ kopieren (nie committen)
- Zwischenbilder gelöscht; Zahlen in kritik/out/*.txt, Bögen in kritik/sheets/
