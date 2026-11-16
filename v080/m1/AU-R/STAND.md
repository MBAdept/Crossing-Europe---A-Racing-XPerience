# AU-R STAND (handover)

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_5dca29a9-6fb-1
- Branch: worktree-wf_5dca29a9-6fb-1 (pushed as origin wip/v080-au-r after every commit)
- Base: 4209268f (AU-C1 final head). Old head copy for before-captures: scratch AU-R/old – delete at the end.

## Commits
- f0e18ab, 9b9db8f, f16be5e: hash fmix32, joints per deck, fuel lane, side pairs (Ogg), drift, slab sync, snow,
  squeal, pass/crash variety, limiter on MMaster, top-speed plan row, align_ms 6, music low_shelf keys (0)
- 295cfc3: match_loop (1/12 octave), cobbled_blocks (47/47 cities), hit_heavy heavy -11.5 / truck heavy -11.0
- b026acd: concrete_threshold per country + tools/audio/modern/calibrate_concrete.gd (14/18 countries)
- ab113a9: loops matched to the HEARD AU-C1 sound (heard(): two players half a loop apart; rumble one-sided)
- 3d2e6e1: docs 15.9 with final numbers (= state of the gates)

## Final measurements (all on ab113a9 assets)
- R1 game mix: asph130 0.6-1.6k 0.603 -> 0.111; cobbles50 2.5-8k 0.982 -> 0.146; conc130 2.5-8k 0.887 -> 0.647
  (slab rhythm; no-slab 0.113)
- character (deterministic): max 0.97 dB per third octave, max 0.27 LU (char_final2.json)
- R5 at volume 1.0: crash -1.71, truck -1.66, vmax -2.93, worst -1.59 dBTP; crash GR <= 2.36 (24); 200 km/h
  concrete 11 events/56 s <= 0.96 dB (AU-C1 level 15/57 s, 1.47 dB)
- deliverables: deliver/AU-R (5 MP3 + txt, QC log, bericht.md assembled by assemble_bericht.py)

## Gates (running/done)
- audio_qc --determinism: green (59 sounds, 0 errors) -> deliver/AU-R/pruefung_qc_determinismus.txt
- run_tests.sh: running (run_tests_final.log) -> pruefung_run_tests.txt
- golden.sh check: after run_tests -> pruefung_golden.txt

## Pitfalls
- Bash tool refuses heredocs / complex chains: write scripts with Write tool, run plainly
- never edit worktree scripts while Godot recordings run (a half-written feed edit broke one capture)
- headless recordings lose 4-9 % time under load: find events in the audio, scale marks by audio/script length
- check_music race / check_modern_audio race are timing-sensitive under load (flaked once each, OK when re-run)
