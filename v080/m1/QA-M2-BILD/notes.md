# QA-M2-BILD working notes (raw, for bericht.md)

## Draft list (B-xx)
B-01 high: F7 bend corridor strips bend interiors (props.gd drop_reason "corridor"; terrain_profile.gd l.284–289
  corr = max(8, 300²·k/8) − shoulder ≈ 80 m at R 136); contract F7 = vegetation only, builder = all decorative
  scenery incl. buildings/rocks. Evidence fair/props_*.txt, occl sheets. Fix: F2-sized chord per bend, vegetation only.
B-02 high: no rain/snow in the air (R4).
B-03 medium: player paint over-saturated: sat S1 0.73/0.58, C1 0.56/0.44, N1 0.95/0.71 (paintbox.py); lum −12…+10 %.
B-04 low/medium: far landmark stand-in dithered fade (S4 dotted ghost; billboard.gdshader l.121–127).
B-05 low: no sun disc at noon (by design SIDE_SWING) – user note.
(perf, vehicles, clips, veg, deck pending)

## Perf (chunk D, 17:03–18:30, load 17–23; refs = M1 QA-BILD drives on the gate1 base ≈ ZS1, load 4–14)
row: load_s | prep/warm | render avg p50 p95 p99 max | commit-frames p50/p95/max | commit_ms_max | DC med/max | tris k | tex | RSS | frame p50
M2 low    59.1 | 58.0/54.8 | 2.41 1.73 6.44 13.1 36.8 | 2.73/6.7/10.6 | 7.5 | 120/158 | 116/157 | 100 | 1046 | 250
M2 medium 47.5 | 42.6/38.3 | 4.04 1.81 7.96 16.8 1154 | 2.92/10.9/157 | 13.0 | 145/181 | 132/179 | 120 | 1066 | 1385
Arcade now 0.8 | – | – | – | – | – | – | 207 | 577 | 204
ref low   15.1 | 14.0/12.1 | 2.10 1.60 4.40 8.9 166 | 2.55/5.9/13.3 | 9.5 | 118/145 | 92/127 | 155 | 937 | 223
ref med   32.1 | 29.8/27.4 | 1.92 1.59 3.66 6.8 92.6 | 2.61/6.5/21.9 | 20.4 | 135/162 | 98/147 | 174 | 981 | 670
ref Arcade 0.7 | – | | | | | | 207 | 578 | 148   (load factor Arcade frame 1.38x)
streamer collect_ms_avg 8.9 (ref 1.64) max 598 (ref 3.6); build_ms_avg 8.0 (ref 4.8) max 42.9 (ref 23.0)
stalls medium: streamer 1152 ms km 87.1, 573 ms km 55.5, 215 ms km 54.5; vehicles 176 ms km 48.5; 14 frames > 40 ms
headless collect probe (probe/qa_collect.gd, perf/collect_*.log): capture avg 2.61/max 41 (ZS1 2.16/29), props
collect avg 0.21/max 12.8 (ZS1 0.07/4.3) – the 598-ms collect is NOT reproduced headless -> load/scheduling suspected;
ZS1 km 40–90 drive in chunk E (same period) to decide.
libwatch (probe/qa_libwatch.gd, headless KH ganz): props library 32 sets / 29 models from live to finish – no set
loaded during the drive (no synchronous load in collect).
headless repeat km 70–95 medium (perf/kh_m2_medium_city_headless.*): streamer collect max 9.9 ms, commit max 2.0 ms –
no streamer stall; but a 531-ms frame in "environment" at km 82.9 (and terrain 111, vehicles 81 ms) – stalls land in
unrelated hooks, not reproducible at the same km -> CPU starvation under load (nice 10, ~20 runnable threads) is the
likely cause; verify on an idle machine.

## Köhlbrand night (KBN, my own renders 18:32–18:52): pylon region (x 500–780, y 150–350) mean lum km 78.1 / 78.8:
Arcade 60.1 / 48.1, ZS1 58.4 / 49.8, M2 55.9 / 43.0 -> M2 <= both (same numbers as M2ZS1). M2: Elbphilharmonie and
Michel lit at Arcade's place (ZS1: missing), cables dark lines (ZS1 bright sprite bands). Player limousine paint at
night: lum 0.096 vs Arcade 0.118 (−19 %), sat 0.67 vs 0.57 -> "brighter" impression = saturation, not luminance.

## Vehicles at night (probe, Kiel–Hamburg km 2, 22:00, medium; Arcade / ZS1 / M2; crops shots/veh/crops_h22_*.jpg)
- truck_red in own lane, low beam: rear doors 20 m mean RGB Arcade (93,37,40) lum 50 / ZS1=M2 (178,104,89) lum 119,
  223 px > 200 (two hot spots); 60 m: lum 42 / 199 / 199 -> red truck reads as a white glowing box (ZS1 identical)
- sedan_silver rear 60 m: lum 65 / 93 / 94, px>200 29 / 150 / 150 (plate+bumper white block); sports_yellow rear blown
- police/de beacon blue px around the car 20/60/150 m: Arcade 5883/690/110, ZS1 2903/371/47, M2 1958/208/28
  -> M2 beacon ~1/3 of Arcade, ~60 % of ZS1 (ZS1 = Arcade sprite stand-in)
- at 150 m all similar (tail lights, indicators); 20 m blinker glow present in all three

## Checked OK so far
- start km 0 (medium): car in countdown and 1.5 s after LOS at Arcade's place, M2 = ZS1 (S0 sheets)
- S4 high M2 vs ZS1 0.46 % px differ; S1 high mine vs M2INT's (c317625) 0.05 % px > 24 -> M2INT sheets valid
- fairness --full 6/6 + path 2/2 (same numbers as M2ZS1); occlusion 120 cases never later/smaller than Arcade
- no "Too many instances" / SCRIPT ERROR / SHADER ERROR in any of my runs (high on forest/mountain positions included)
- QA-M2-SYSTEM run_tests: renderer_zeit 1.031 ms/frame (render 0.910) headless normal speed – under deck 1.5 ms
- GT at noon (M2INT sheet): whiter than sprite, rear window sky-blue (M2INT open point holds)

## Fairness geometric (measured, 15:09–15:12 UTC, load ~3)
modern_sight --full: 6/6 OK – F1 0 cases to 270 m in 99,424,500 samples (first at 280 m), lanes 0 to 260 m in
326,680,500 (first 270 m), F2 0.593/0.596/0.555, F3 0 of 5923 (vehicle), 0 (sign), F7 0 of 2,011,532, model 0 dev
(0.0002 px). 144 s. modern_path --full 2/2: min 267.6 m (bukarest_sibiu__sibiu km 57.8), loops >= 2064 m. 58 s.
Identical to M2ZS1's numbers. Geometric only (camera, terrain, road): props/trees/buildings not modelled.

## Props corridor (headless probe/qa_props.gd, sh/props_probe.sh -> fair/props_*.txt)
start km 0: big oak seg 9 x -17.1 (z +36.9 from camera) dropped "corridor" (beyond shoulder 9.0 m)
T4 km 199.7: 9 of 12 props within 150 m dropped (spruces up to 30 m beyond shoulder; ribbon 102 m)
T1 km 47.5: 5 of 13; T3 km 173.5: 4 of 8 (pines, rocks); S4 km 80.4: 3 of 12 (2 birches, bush)
C1 km 221.8: 4 of 16 – 3 street trees (event items) + 1 decorative BUILDING city_german_gruenderzeit x +6.9
-> props.gd drop_reason(): (decorative or veg) and not landmark and in_bend_corridor -> also buildings/rocks/bales;
contract F7 text: "no decorative vegetation inside that corridor on the inside of bends"

## S0 start (medium) – M2 = ZS1, car in place, oak missing in both
## S4 high – M2 vs ZS1 0.46 % px differ (>8); equal; birch at the left missing (corridor)
## S4 dithered landmark ghost: dark dotted disc + teal dots at ~(540-600, 285-320), also in gate1 (ZS1 era);
billboard.gdshader landmark law: far_keep < 1 -> ordered dither discard (lines 121-127) -> halftone pattern; Arcade
blends smoothly. Not from loaded chunks (qa_screen: no placed prop there) -> far landmark stand-in (Hamburg:
elbphilharmonie, michel ~1.0–1.2 km ahead).

## Occlusion (probe/qa_occl.gd; count sh/occl_count.py)
T4 arcade: car visible to 40 m (all lanes), 55 m lane -1 only; hidden from 55/70 m by the cliff sprite
T4 m2high: 0.89–1.07 x Arcade at 25–55 m; visible 55–220 m where Arcade shows 0 px (cliff + spruces dropped by the
corridor); 270 m 0 in both. Picture shots/occl/T4_d100_sheet.jpg: Modern bend interior bare (cliff, spruces gone).
F2 view: need at ~85 km/h ≈ 58 m -> must show from ~97 m; Arcade (cliff) shows only 55 m -> Arcade itself fails F2
here; an F2-sized corridor (chord ~106 m incl. camera -> sagitta ~10 m + crown radius) would keep most spruces.
T3 (km 172.8, climbing left bend): M2 high 0.99–2.6 x Arcade at every distance/lane (25–220 m); 270 m lane +1 only
Modern. No case smaller/later than Arcade. Picture shots/occl/T3_d130_sheet.jpg (pines inside of bend fewer).
T1 (Kassel–Würzburg km 46.5, bend into descent): M2 0.69–1.01 x Arcade 25–170 m, 0.88–2.1 at 220/270 m; never 0
where Arcade > 0. Zoom shots/occl/T1_d100_zoom.jpg: car fully visible in both; the lower count = Arcade sprite's
baked shadow/soft edge + curve-camera view, not occlusion.
W1 (Dortmund–Frankfurt km 121.4, forest, 16:00): M2 0.70–1.09 x Arcade, never hidden where Arcade shows it.
SUMMARY occlusion: 4 positions x 10 distances x 3 lanes = 120 cases (Arcade vs M2 high): min ratio 0.69, never 0
where Arcade > 0; T4 Modern visible 55–220 m where Arcade's cliff hides the car. Trees/models do not hide cars
later than Arcade at these bends – because the corridor rule removed the trees on the inside (the look cost).

## Vehicles by day (probe 12:00 medium; crops shots/veh/crops_h12_20/60.jpg; counts sh/lightcount.py, zooms sh/zoom.py)
- all cars sit on the road, wheels/shadow fine at 20/60/150 m; rows a/b (hatch, sedan, suv, van, truck, bus) M2 = ZS1
  in light counts; new van/suv/bus models clean
- NEW sports model (traffic/sports, sprite stand-in in ZS1): brake light = thin strip; own lane braking, red px (tight
  box) 20 m day Arcade 216 / ZS1 245 / M2 119; 60 m 32 / 31 / 9; night 20 m 375 / 449 / 180 -> braking cue ~30 % at 60 m
  (zoom shots/veh/sport_d20_h12.jpg, sport_d60_h12.jpg)
- general (also ZS1): Modern brake/tail red px ~45 % of Arcade at 20 m day (hatch 123 vs 319, sedan 95 vs 209)
- NEW police model (police/de): beacon by day blue px 20/60/150 m Arcade 1601/182/17, ZS1 1004/114/11, M2 411/28/7
  (zoom shots/veh/police_d60_h12.jpg: thin blue bar, no halo) – night 1958/208/28 vs ZS1 2903/371/47
- M2 police shows the indicator (ZS1 stand-in did not) – fine
