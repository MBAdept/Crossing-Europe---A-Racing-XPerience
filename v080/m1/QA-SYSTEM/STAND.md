# QA-SYSTEM STAND — FERTIG (18:20)

Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-3 (ff 9b6adbc, clean, no commits)
Report: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/QA-SYSTEM/bericht.md
(assembled from bericht_teil*.md by bin/assemble_bericht.py) + pictures in the same deliver folder.

## Done (all lens items)
- frozen 0 diff; ERGEBNIS x3 = v0.7.0; golden 20/20 (golden.log); golden provenance + no-shot-fast + 1280x800 = v0.7.0;
  menus 9/12 + loading overlay + pause identical (vehicle/start_time: wall-clock arrows only); audio fingerprint = v0.7.0
- migration 23/23 (real v0.7.0 data), chooser once, champ switch 9/9, pad walk 14/14 at 720/800, text >= 18 px
- sound: 18 captures, spectrograms, loudness/ducking/race music off, title seam; 1 dropout under load (repeats clean)
- fallback (fail/no/broken manifest), bench JSON OK (+wine), quit 4/4 clean, kill -> crash question, SIGTERM finding
- soak 20 min Modern 0 errors; render subset all green; export det 6/6 byte-identical; builds 156.5 MB; wine A+M
- run_tests #1: unit 692/0, attract Modern flaky -> hook skipped; hook by hand 10/11 (check_facade fails here)
- cleanup done (build/, _cache3d, wineprefix, ref070, xdg_*, mesa_*, duplicate WAVs)

## Findings QS-01..08 (see bericht.md)
## Next: nothing (StructuredOutput delivered)
