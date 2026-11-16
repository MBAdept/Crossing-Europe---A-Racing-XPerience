# RINT-B working notes (measurements for bericht.md)

## Merges
- dfc99b6 R3E (doc conflict only; §11.8), 94ce4a2 AS1R (clean; manifest regen = automerge 28 models/182 sets), b473e90 AU-D1 (clean)
- vehicles re-exported with merged code (21 s): bake byte-identical to AS1R commit; 2nd bake identical; --check-keys OK
- import clean after merges

## Post path LUT (probe probe/post_probe.gd, llvmpipe)
values  2 4 6 8 10 12 14 16 19 22 26 30 36 44 56 70 90 128 180 230
post    0 0 0 1  4  6  9 11 15 18 23 27 34 43 55 70 90 128 180 230
LUT f16 7 7 7 8 10 12 14 16 19 22 26 30 36 44 56 70 90 128 180 230  (texel0=0 -> black stays black)
1D LUT 8-bit: off by 1; 3D LUT 17^3: wrong (darker)

## Night ground (patch medians, luminance vs Arcade)
- N1 snow ground left: before +50.0 %, after +1.7 %; right: +36.7 % -> -8.5 %
- N1 sky 51/53/57: before -1.9 %, after 0.0 %
- N1 road near: +21.5 % -> +11.3 % (LUT only; road ground law not yet in ab1)
- S4N right grass: +34.1 % -> -16.3 %; sky -22.6 % -> -5.0 %
- S1N (baseline only): road +46.7 % near, +59 % far

## Horizon S1 (rows, right x900-1270)
- Arcade: silhouette bottom row 320 (141/170/146), grass 91/149/61 from 321
- before: silhouettes bottom 323, fog 197/219/237 rows 324-325 (left 324-330)
- after: silhouette bottom 320 (139/169/142) = Arcade row; rows 322-330 land 108-114/148-155/66-69

## Paint (paintcmp.py; hue / sat / value vs sprite)
- S1 limousine noon: before(ab1) -2.8°, +0.12, -10.1 %; after(ab2) -3.0°, +0.12, -1.3 %
- N1 kompakt night: base +6.1°, +0.18, +22.2 %; ab1 +5.5°, +0.15, +9.0 %
- T4 kompakt noon (ab1, before paint knee): -0.8°, +0.04, +6.9 %, clipped 62 % (Arcade 27 %)
- S1C kompakt noon (ab2): -1.4°, +0.01, -5.1 %, clipped 7.0 % (Arcade 27.5 %)

## Ground S1 noon (ab2 vs Arcade): asphalt -6.5 %, grass -7.6 %, road centre -1.0 %, sky -0.2 %

## Timing reference (perf_clock): reference_once medians 592 / 610 us normal, 921 us slow mode -> nominal 600 us

## Quit leak: GameFlow.quit_game: stop music ctx off, set_music false, stop_all, 0.3 s timer, quit (check_quit_sound render check)

## Session 2 measurements
- brake/tail (black sedan 18 m ahead, 22:00, lamp area luminance increase): tail 1.20, brake 4.73 -> 3.93x; noon 0.04 / 5.15
- pop lod1->lod2 (machine preset lod1 90 m, switch at 94.5 m, still scene, no traffic, 0.03 m/frame, threshold 0.06):
  before (b473e90) 5.4 % of car pixels in the switch frame, sum 40 frames 17.9 %; after 0 % at switch, spread 3.5/2.3/3.4/1.1 %,
  sum 13.7 %; motion baseline median 0 %
- paint tight box (565,560,715,640): S1 limo noon -3.4° / +0.07 / +6.7 %; S1D limo 19:30 -9.6° / +0.21 / +3.3 %;
  S1C kompakt noon -1.3° / +0.02 / -7.8 % (clip 2.2 % vs 29 %); S1CD kompakt 19:30 +5.9° / +0.05 / -16.2 %;
  S1N limo 22:00 before night factors +53.1 %, after (env_night 0.35, fill_night 0.3) +31.8 % (-2.7°)
- truck at 22:00 18 m ahead: contour tape lit in the low beam (78/0/0 red), triangles and lamps visible
- instance census: see doc13_extra.md 13.8
- check timings: leistung 32.6-34.6 us/car (p90 42-47), kern_zeit 0.233 ms, renderer_zeit 0.801 ms (13 cars)
