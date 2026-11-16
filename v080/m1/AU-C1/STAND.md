# AU-C1 STAND (handover file)

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_f5d01292-ef8-1
- Branch: worktree-wf_f5d01292-ef8-1 (pushed to origin wip/v080-au-c1 after every commit)
- Base: 2f4f260 (AU-D2 final head), fast-forwarded from main; .godot copied + imported (ok)

## Done
- ff-merge to 2f4f260, import
- read contract (§2, §3.5, §4.7, §5, §6 AU-C1, §11 A-5..A-8), docs/audio-modern.md, AU-B bericht, study render_new.py
- baseline audio_qc: OK, sounds 13.37 MB of 23 MB (budget left ~9.6 MB for AU-C1 + AU-C2; target <= 4 MB for me)

## Plan (order)
1. audio_feed.gd v1: paving (asphalt/concrete/cobbles/deck), rumble only on rumble roads, cutting zone,
   deck material, delineator passes (road.delineator_every_m, no guardrail, not city/tunnel) + contact flag
2. tools/audio/modern/vehicle_loops.py (loops -> assets/audio/modern/vehicle, own generator entries only)
   tools/audio/modern/sfx_modern.py (one-shots -> assets/audio/modern/sfx)
3. road_audio.gd: per-side surfaces via 2D players (L/R), wet, rumble, slab rhythm, bridge joints (baked pairs),
   pass-by whooshes, squeal/scrub, wind 3 bands + buffet + gusts + zones; levels from data (audio.modern.road)
   calibrated: wind = full_throttle_lufs - 3 dB, tyres = -4 dB at the car's nominal vmax
4. impact_audio.gd: claims collision/rail_hit; layered crash by rel speed and partner; rail hit + scrape loop;
   delineator contact; keep LEVEL_DB (test_arcade_identity pins it)
5. update AU-A tests that pinned placeholder behaviour: test_modern_audio.gd (wind formula l.127,
   one-shots l.233-279), check_modern_audio.gd (delegation: plays.crash==1 l.323)
6. measure: capture_mix drive (+ --mute-bus variants), worst case capture (own scratch script) <= -0.5 dBTP
7. deliver MP3s + spectrograms + bericht.md; docs/audio-modern.md sections
8. gates: audio_qc --determinism, run_tests.sh once, golden.sh check once

## Commits so far (all pushed to origin wip/v080-au-c1)
- 36f2ff5 feed v1 (+ tests, config audio.modern.feed)
- 063cd85 vehicle_loops.py + 17 loops (2.95 MB)
- 1700749 sfx_modern.py + 17 one-shots (1.57 MB) -> sounds total 6.04 MB... (whole folder sum 13.37 -> ~17.9 MB)

- 23fc4a9 road_audio.gd + impact_audio.gd + modern_audio_pan.gd (new helper), config audio.modern.road/impact,
  test_road_audio.gd (10 tests), adapted test_modern_audio.gd (wind law l.127, one-shots claimed) and
  check_modern_audio.gd (delegation: crash dropped for its collision event) – all green, check_modern_audio both modes OK

## Measured so far (capture_mix drive, cap/*.wav, measure_mix.py) – UNCOMMITTED: per-car reference in road_audio.gd
- GT full: idle -23.9, full thr -15.3, flat out -14.4, cruise130 -21.45, TP -2.9; engine alone flat -17.51; tyres -19.98 (=plan-4);
  wind -18.99 (=plan-3) -> relative to the REAL engine only 2.5/1.5 dB under. Kompakt engine alone flat -18.47, full -16.35.
- decision: road.engine_top_lufs per car (measured engine at top speed, data) is the reference (contract: "under the engine");
  road_audio.gd _calibrate(id) + test updated (not yet committed); fill config table from cap/*_engine.wav flat_out values
- scratch scripts: worst_case.gd, drive_demo.gd, layers_demo.gd (scenarios belaege|ruettel|wind|quietschen|aufprall)

- later commits (all pushed): 118f65b per-car reference, 54099de worst-case peak fixes, a6cd6d0 level tuning from the
  drive, be2f2af rumble/joints at high speed. HEAD be2f2af.
- worst case (worst_case.gd, default master 0.8): after limiter -2.26 dBTP (gate <= -0.5 OK); traffic/siren stand-ins
  drive the limiter ~4 dB (AU-C2 stand-in levels); AU-C1 alone: pre-limiter 0.0 dBFS
- recordings in cap/: drive.wav (+_road), layer_{belaege,ruettel,wind,quietschen,aufprall}.wav (+.json marks, marks lag
  audio by ~0.1 s = dummy driver block)

- ef34418 docs (audio-modern.md §15, §8 feed v1, _doc_modern); 82c73c0 test_road_audio.gd.uid. HEAD 82c73c0 (pushed).
- deliver/AU-C1: 7 MP3 + 7 spectrograms + 7 txt, qc_determinismus.txt, bericht.md (draft, gate placeholders)
- gate 1 audio_qc --folders vehicle,sfx --determinism: OK (45 sounds, 0 problems, 4 generators deterministic) exit 0
- Arcade proof (static): git diff 2f4f260..HEAD touches no frozen file (Rule 1 list) and nothing outside
  scripts/audio/modern, assets/audio/modern, tools/audio/modern, tests/unit/audio_modern, docs/audio-modern.md,
  config (only audio.modern.* + audio._doc_modern string)

- gate 2 run_tests.sh (once, on 82c73c0): 642 tests, 0 failed, all CHECK OK, exit 0 (638 s)
- gate 3 golden.sh check (once, on 82c73c0): 20 von 20 identisch, exit 0
- worst case re-run on final state: -2.44 dBTP (variants: no MWorld -2.07, no AU-C1 -2.60, AU-C1 only -2.40/+0.02 pre)
- impact-only recording: peaks measured at onsets (marks drift up to 0.4 s behind audio!) -> docs 15.4 + bericht
- 4209268 docs fix (impact peaks, worst case final, marks drift, overshoot). HEAD 4209268 pushed. Worktree clean.
- bericht.md final; scratch cleaned (cap, gen1, gen2, xdg dirs, sheets deleted; scripts kept)

## DONE – only StructuredOutput left

## Pitfalls
- every heavy job: nice -n 19, one worker; never two heavy jobs at once
- modern_lib.write_wav_import loses .import head -> use own keep-variant (as engine_synth3.write_wav_import_keep)
- WAV loops need LOOP_GUARD frames after loop_end
- audio_qc full run takes > 2 min (music decode); use --folders vehicle,sfx while iterating
