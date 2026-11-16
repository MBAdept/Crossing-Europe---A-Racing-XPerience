# Look notes per A/B sheet (QA1, Modern vs Arcade same sim state, 3 s after flying start)

- DIAG km0 standing start (medium): Modern NO player car in countdown and until ~1.5 s; camera 9 m too far forward; gantry
  closer; "Tankstelle 15 km" sign missing; at 1.5 s car far too big/low. BUG (QA1-B1).
- S1 high: equal to slightly better. Fields with stripes/texture, real shadows (trees, guardrail, car), card trees
  (birch/oak), turbines with rotors, haze at horizon. Player limousine model: steep rear window with visible seats vs
  sprite fastback. No sun disc in either at noon. Not "clearly better".
- S2 high: station equal to Arcade (canopy, island, yellow kerb, pumps, TANKSTELLE). Left foreground bush in Modern a
  dark blocky blob, worse than Arcade's sprite bush. Overall equal.
- S3 high: slightly better: field patches with colour variety (yellow), terrain depth, oak shadows. Car as S1.
- S4 high: equal, Modern slightly better at the roadside (paved sidewalk texture, 3D street lights); the houses, crane
  and the brick blocks are Arcade sprites in both (stand-ins) -> the city reads the same.
- S5 high (3 s = after the finish line, ZIEL panel of the HUD covers the top): equal; brick blocks are sprites, ground
  brown in both, Modern sidewalk paved. Gate not in view at 3 s -> rerun S5 at 1.5 s (gate).
- T1 high (km 47.6, left bend): terrain clearly better (rolling hills with shading vs Arcade's flat green). Vegetation
  sparser: left foreground conifer missing (inside of bend, F7 corridor). Kombi = Arcade sprite stand-in in both. The
  red/white chevron sign at the right edge (~25 m) is visible in Arcade, in Modern only a 2-px sliver at the edge – the
  curve camera looks into the bend and pushes near-right roadside objects out of view (F1 covers road points, not the
  roadside sign at the edge). Overall equal (better ground, poorer vegetation).
- T2 high (crest, km 63.0): WORSE: Arcade shows the SUN DISC (15:00) and big oaks/conifers left near the road; Modern
  no sun disc, left side nearly empty grass with a few low tufts (corridor + ground cover). Right side conifers equal.
- T3 high (Saragossa–Pau km 173.7, climbing left bend): Arcade SUN DISC (11:00) + boulders near left; Modern no sun,
  near-left boulder missing (inside of bend), but a real hill on the far left and a natural verge/slope. Kompakt model
  (black roof like the sprite). Overall equal (better ground, missing sun and near rocks).
- T4 high (km 199.7, R~136 m right bend): equal; Modern shows the bend better (camera looks into it), field texture;
  the big conifer at Arcade's right edge (inside of the right bend) missing in Modern.
- N1 high (snow 22:00): WORSE: no snowfall in Modern (Arcade: flakes). Headlight cone and the snowy ground read
  similar; the Kompakt model is brighter and more saturated yellow than Arcade's night-shaded sprite.
- N2 high (rain 16:00, GT = sprite stand-in in both): WORSE: no rain streaks in Modern; the wet road is darker and a
  little glossier, otherwise similar. Left trees slightly fewer in Modern.
- C1 high (Frankfurt 19:30, City Limits): slightly WORSE: Arcade's big street tree on the right (near, inside of the
  right bend) is missing in Modern; the buildings are Arcade sprites in both, Modern's paved sidewalk is nicer; dusk
  sky identical (backdrop). Sportwagen = sprite stand-in in both.
- U1 high (Gotthard tunnel): equal: tube with tile band, lamps with halos and the dark depth as in Arcade (FIX1); the
  limousine model warmly lit, the road with a slight sheen. Arcade's green emergency sign far ahead is hard to see in
  Modern.
- DEV high (21:00, approaching the test tunnel): equal; portal, hill and sign as Arcade; Modern's hill is a smooth,
  lighter green mound (Arcade: dark hill with conifers) and the oak on the right is lit quite brightly for night; the big
  conifer at Arcade's left is missing; the limousine is brighter than Arcade's (no white moon flecks any more).
## auto (= Niedrig on this machine: tier software; no shadow casters, 75 % 3D scale, details low, density 0.6)
- S1 auto: no cast shadows (car has its contact shadow), softer and stair-stepped edges (75 %), fewer props (Arcade's
  big oak on the right missing). Equal at best, plainer than Arcade.
- S2 auto: station equal; no canopy shadow; fewer trees; plainer.
- S3 auto: fewer trees (the big oak right missing), no shadows; plainer than Arcade.
- S4 auto, S5 auto: as high (the city is Arcade sprites in both), softer; S5 again after the finish line.
- T1 auto: fewer conifers on the left than high and than Arcade; chevron at the right edge missing as in high.
- T2 auto: WORSE: left side completely empty grass (Arcade: oaks and conifers), no sun disc.
- T3 auto: no sun disc, near boulder missing; the hill and the verge are nice; equal to slightly worse.
- T4 auto: the Kompakt model at 75 % scale is visibly stair-stepped/noisy (yellow body, dark roof); fewer conifers.
- N1 auto / N2 auto: as high: no snowfall / no rain; plainer.
- C1 auto: as high (street tree missing). U1 auto: equal (tube as Arcade). DEV auto: as high (lighter hill, missing
  conifer left, brighter car).
