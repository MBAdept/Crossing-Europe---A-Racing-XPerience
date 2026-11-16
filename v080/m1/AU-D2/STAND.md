# AU-D2 STAND (handover) – FERTIG

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_2b39c7a4-a94-1
- Branch: worktree-wf_2b39c7a4-a94-1, pushed to origin wip/v080-au-d2
- Base: 03eaeff (AU-D1 head); final commit 2f4f260 (tree clean)

## Result
- Pieces: nachtfahrt (C minor, 105 bpm), rueckenwind (A major, 150 bpm), zwischenspiel (E minor, 100 bpm); extras
  for all three race pieces (ziel, schluss_rekord, schluss_finale, polizei, tank); UI sounds (6 ids, 7 files)
- Gates (once each, on 2f4f260): run_tests.sh full 627/0 + all integration checks OK (641 s);
  golden.sh check "20 von 20 identisch" (204 s); audio_qc --folders music,ui --determinism OK (31 sounds, 50 min)
- Report: scratch v080/deliver/AU-D2/bericht.md (+ MP3s, spectrograms)

## Open (see report sections 6–8, docs 14.14)
- user listening judgement (bass, level, style of the new pieces); change mischung.json + render_all.py
- Linke Spur main keeps the soft-lead phrase-end click (bit-identical to AU-D1 samples); fix with
  race_lib.phrase_end() at the next re-render
- UI2: call ui/ui_tab, ui/ui_toggle, ui/ui_error; AU-E: measure stingers in the full chain

## Scratch helpers (m1/AU-D2)
- deliver.py ROOT OUTDIR WAVDIR (needs render_all.py --wav for the UI demo WAV), band_compare.py ROOT,
  bericht_build.py OUT (parts bericht_teil_*.md + bands.md), doc_splice.py (one-shot, already applied)
- WAV masters deleted (re-render with --wav if needed)
