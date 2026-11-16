# QA-BILD notes (working file)

## Findings so far
- F-S2-STATION (high): S2 fuel station in Modern: no canopy roof ("TANKSTELLE"), no island kerb / walkway, no yellow
  line; pumps stand on the grass; the tutorial's key moment reads weaker than Arcade. ab_med/S2_ab_00.jpg
- F-SUN (low/med): no sun disc at noon in Modern (Arcade draws it behind the HUD timer). ab_med/S1_ab_00.jpg
- F-PLAYER-SHAPE (med): limousine model: upright rear window with visible interior vs fastback sprite; looks like a
  different car. ab_med/crop_s1_car01.png
- F-EDGE (low): near edge line soft/blotchy ("worn paint" noise), dark repair patch rectangle ahead of car.
  ab_med/crop_s1_edge.png, crop_s1_car01.png
- F-TREE (med): oak card crown jagged/noisy edges (alpha scissor, no AA) vs smooth Arcade blob; in motion likely
  sparkles. ab_med/crop_s3_tree.png
- F-FARTREE RESOLVED (medium): with --gfx-debug=cover (fog off) the grey blobs are green trees: props (impostors,
  leaves, baked, vpbr) take the engine's full depth fog (1.0 x t), while terrain/far ground now take Arcade's ground
  law (tint <= 0.7 x t towards fog x 1.25) -> far trees are paler/bluer than the field they stand on ("ghost trees").
  ab_var/crop_s1_far_nofog.png. Fix: give billboard/leaves/baked/vpbr props the same FOG law as terrain.gdshader
  (write FOG with Arcade's 0.7 law) or lower density for props.
- S1 noon trunk paint vs sprite: hue -2.3..-2.7 deg, luminance +1..+3 % (measured, region 590-710 x 600-625) OK.
- S2H22: station at night reads much weaker (no lit canopy, small dark forecourt). ab_var/S2H22_ab_00.jpg
- S1H22: player limousine roof glint p95 112 vs Arcade 50 (mean 31 vs 33); near cone road +18 % (112 vs 95).
  ab_var/crop_s1h22.png
- S1H6 dawn, S1H195 dusk: comparable to Arcade, fine.
- (old) F-FARTREE (?): S1 6 s: far trees right of the road beyond the curve sign = pale grey-blue blobs in Modern
  (129,137,145) where Arcade shows dark green trees (26,37,19). Fog law? experiment nofog queued (batch2).
  ab_med/crop_s1_far.png
- F-BRIDGE (high): S4 Köhlbrandbrücke: no railings, dark water both sides; bridge reads as road on a dam.
  ab_med/S4_ab_00.jpg
- F-LANDMARK (high, NEW, not in RINT-B list): S4 6 s: Elbphilharmonie + Michel tower visible in Arcade, missing in
  Modern (landmarks only via props builder inside loaded chunks; landmarks builder R7 absent -> pop in late).
  ab_med/crop_s4_landmarks.png
- F-FINISH (high): S5 finish gantry "ZIEL" missing in Modern (only checker on road). ab_med/S5_ab_00.jpg
- OK: S4 overtaking wagon LOD0 model crisp, better than blurred Arcade sprite. ab_med/crop_s4_cars.png
- F-CORRIDOR (medium): T1/T2: roadside trees (firs, oaks, boulder) left of the road missing in Modern; probe
  drops.gd at T2: 35 props dropped as "corridor" in chunks 63-70 (-205..+560 m) vs ~47 placed; replaced by
  ground-cover tufts. Roadside reads bare vs Arcade. ab_med/crop_t2_left.png, crop_t2_far.png
- F-GHOSTROAD (low/med): T2 6 s: a far piece of road beyond the crest drawn in pure fog colour (pale band) with the
  ordered-dither speckles of fading far trees around it - white noise dots at the horizon. ab_med/crop_t2_rock.png
- F-JOINT (low): T1: sealed-joint tar line runs as a long dark continuous line next to the lane line (reads as a
  crack/wire). ab_med/crop_t1_traffic.png
- OK: T1 red hatch (model) and van (stand-in) at 60-100 m fine; kombi stand-in identical to Arcade.
- OK: T1/T2 terrain relief gives depth, land instead of fog band at T2 (better than Arcade's pale band).
- F-TUNNEL (high, other stages): U1 Gotthard and DEV Testtunnel: no tube - open green terrain under a black sky,
  HUD says TUNNEL; DEV 2 s: portal + mound missing. ab_med/U1_ab_00.jpg, U1_ab_01.jpg, DEV_ab_00.jpg, DEV_ab_01.jpg
  (Kiel-Hamburg has no tunnel; other stages of the test build do.)
- F-NIGHTCAR (high): DEV 21:00: two white specular hot spots on roof and trunk of the player limousine (moon glint),
  car region p95 luminance 193 vs Arcade 51 (mean 39 vs 34). ab_med/crop_dev_car.png
- F-N1HORIZON (low/med): N1 22:00 snow: Modern far-ground band below the horizon (75,82,94) vs Arcade dark band
  (37-40), looks like a pale fog bank. ab_med/crop_n1_horizon.png
- F-WEATHER (high, known): N1 no snowfall, N2 no rain streaks/spray in Modern. ab_med/N1_ab_00.jpg, N2_ab_00.jpg
- C1: stand-in sportwagen identical; city tree stand-ins identical to Arcade; finish gantry "ZIEL" ahead missing
  (ab_med/crop_c1_far.png).
- T3/T4: boulders/rock outcrop missing (known), curve camera shifts player 100-110 px (within p99/max of D12),
  chevron sign moves under the speedometer at T3 6 s (low).
- fast mode validated: S2 Modern shot-fast lead 1.0 vs full: picture 00 identical, 01: 3 px differ (max 15).

## Fairness (measured, fair/sight_full.log, fair/path_full.log, 17:44)
- F1 0 cases to 270 m (first 280 m) 99.4 M samples; lanes 0 to 260 m (first 270 m) 326.7 M; F2 0.593/0.596/0.555
  (<= 0.60; rain margin 0.004); F3 0/5923 car+sign, Modern p50 534 m vs Arcade 510 m (car), 642 vs 612 (sign);
  F7 0/2,011,532; model 0 dev, eye 0.0002 px. Path: min clearance 267.6 m, loops >= 2064 m. All = contract.
- Gaps: F1-F3 ignore occlusion by props/buildings; F3 only dry day; vehicles/signs take full engine depth fog on top
  of Arcade's fade (Arcade tints sprites only 0.7 x t) -> bright cars near the "seen" distance lose contrast
  (formula: ~25 % of Arcade's for a white car at 0.839 x vis; inferred, no render check exists).
- Fallback --gfx-debug=fail: Arcade + German HUD message, OK (fallback/fail_00.png)
- GLES (opengl3_es) vs opengl3 at S1 medium: max diff 2, PSNR 71.8 / 88.0 dB -> within D38 tier (measured)
- Deck 1280x800 deck preset: Modern fills 16:10, HUD in corners, Arcade bars - OK (ab_var/S1_deck_ab_01.jpg)

## Perf (measured, perf/*)
- kh_modern_low (ts 2, max-steps 32, load 8-12): load 15.1 s (prepare 14.0 s, prewarm 12.1 s, selftest 0.72 s);
  render() p50 1.60 p95 4.40 p99 8.9 max 165.7 ms, avg 2.10; commit frames p50 2.55 p95 5.9 max 13.3; commit_ms_max
  9.5 (budget 3); draw calls 90-145, prims 47k-128k; tex 116-155 MB; vehicle_instances peak 128; frame p50 223 ms.
- kh_modern_medium (ts 2, steps 32, load 4-12): load 32.1 s (prepare 29.8, prewarm 27.4, selftest 1.19);
  render() p50 1.59 p95 3.66 p99 6.81 max 92.6 (at finish km 95.1, vehicles.gd), avg 1.92 (budget 1.5);
  commit frames p50 2.61 p95 6.49 max 21.9; commit_ms_max 20.4 (budget 3; headless runs 4.8-5.1, RINT-B 0.42-0.78
  normalized headless); draw calls 94-162 (visible only, shadow pass reports 0), prims 50k-148k; tex 136-174 MB;
  RSS 882-981 MB; vehicle_instances peak 128 (cap hit); start_frame_ms_max 1308; frame p50 670 ms (llvmpipe).
- spikes: qa_spikes.gd (proxy timing of each hook, headless, nice 19): 130-170 ms single frames in vehicles.gd in 3 of
  5 runs at random km (0.09, 80.4, 91.7), none with a build or trim, none at the same place -> probably VM
  scheduling (nice 19 under load 10); 30 ms frames at the fuel stop km 13.9 (twice in one run). Clips: no hitch seen.
- Clips GPU time (Movie Maker): Arcade 103-132 ms/frame, Modern medium 681-746, high 1317 (llvmpipe).

## Missing mandatory render checks (§4.9.2) - QA1's job, note
- object at visibility limit < 3 % contrast (F4/F5): no check
- mean luminance / no black/NaN frame per weather x hour: no check
- GLES path parity (opengl3_es): no check -> own run queued (batch2)
- tunnel interior/exit: n/a in M1 (no tunnel builder)
