# STAND KRITIK-5a2 (independent art review of AS5a2, read-only)
- Target: worktree .claude/worktrees/wf_db8ba6cd-508-4 commit 3c5e37a (READ-ONLY, never touch)
- Working copy: K/tree (K = this folder; copy w/o .git/build/_cache3d, with its .godot; import OK 5 s)
- env: source K/env.sh ; runner K/k5.sh <script> <name> <args> (shots K/shots, logs K/logs); items K/items.sh
- review tools installed in K/tree/tools/kritik (from AS5aR1/kt) via K/install_tools.sh; py helpers K/py (KRITIK-5a1)
- Census: m1/AS5a1/census_all.log (positions: pa luettich_paris 387.5, am bremen_amsterdam 357.3, br koeln_bruessel 195.5,
  lyon montpellier_lyon ~297.0, bordeaux tours_bordeaux ~337.4, bern lyon_bern 302.4)
## done
- 09:58 setup, import, dist/PAR_h12 test (28 s)
## doing
- batch1.sh (bg, logs/batch1.out): dist 5 styles x 12/19.5/22 + close 12/22 -> shots/dist, shots/close
## next
- validate --report, share.py bytes, texel_k5, lods (medium 12/22), sparkcam subset, outline2, tint, drive clips,
  A/B race (pa am br lyon be), clip, sheets, bericht.md
## 10:00
- dist sheets PAR/DUT/BEL/FRA day+night viewed: models clearly finer than sprite at 10-100 m; lod1 at 250 m paler/
  pinkish than sprite (laube, immeuble, belgian, canal) -> measure with k6_scene lodcol (new scratch tool, in batch2)
- validate OK (logs/validate.log), share.py bytes = 0.94 / 5.82 MB (logs/share.log), texel logs/texel*.log
  (french_sud road garden wall 15 px/m; corner far/back 9-12 px/m blank)
- chain1.sh (bg): waits batch1 -> batch2 (lods, outline, tint, lodcol, spark) -> ab_all 11 runs -> K/ab
## 10:05 findings so far (D = defect candidates)
- D-tree: french_sud (588!) + maison (209): garden tree = faceted generator crown, from the road "crumpled green
  rocks" (shots/close/FRA_h12_city_french_sud_road.png) - bar says AS3 tree models; sprite soft blob reads better
- D-lod1far: lod1 at 250 m paler/pinkish vs sprite (laube, immeuble, belgian, canal) -> lodcol numbers pending
- D-cutout: 5/12 models (immeuble, sud, haussmann, corner, chalet = 907 placements) whole building in baked_cutout
  (cull_disabled + discard; perf inferred); railings mip coverage grows x1.5-2.7 (mip2-4), immeuble x4.2 @mip4
  (logs/mip.log, bg stone) -> railings become solid dark bands at 40-150 m
- D-back: corner back walls blank 9-12 px/m (shots/close/PAR_h12.png back) - known, 8 placements
- garden wall sud road side 15 px/m (texel_o45.log)
- good: haussmann/immeuble/belgian/canal close-ups clearly finer; night windows irregular warm; shop displays lit
## 10:08
- batch1 done (dist/, close/). batch2 running (lods G1 G2 done). lods 60 m medium: swap 11.9-16.4 % (day), 7.8-12.4 %
  (night, +1.3..+4.0 % luma) - logs/lods/*.log
- D-lilac confirmed visually at 200 m (lods/G1_m_h12, G2_m_h12): windows smear to pale lilac (sud, immeuble,
  belgian_stone, canal); sprite keeps dark windows
- D-geranium: chalet flower boxes = big faceted red/green balls (close/SWI_h12_city_swiss_chalet_oblique.png)
- AS5a2 clip frames extracted K/as5clip; py/rough2.py: centre box Modern 7.0 vs Arcade 3.8 roughness (crude, h264)
- deliver helper: K/cap.sh <png> <name.jpg> <caption> [w]
## 10:15 batch2 partial
- lods: medium 60 m swap 9.0-18.3 % day (+-0.6 % luma), 7.8-14.5 % night (+1.3..+4.9 %); high 120 m 9.7-22.6 %
- outline IoU 0.945 (chalet) .. 0.999 = AS5a2 confirmed; tint dutch_terrace x #ead6cc ~ sprite x tint (shots/tint.png)
- lodcol_h12 (logs/lodcol_h12.log): lod0 ~= lod1 at same distance (dL <= 3 except canal 250 m -7). Model brightens
  with distance 60->250 m by +5..+10 % (haussmann +10.5, canal +10.3, sud +9.6), sprite -1..-3 %; dark p10
  (windows) model +13..+23 levels, sprite +2..+11 -> washed/lilac far facades (both levels, not only lod1)
## 10:20 batch2 done; chain1 now in ab_all (K/ab, logs/chain1.out); chain2 (drive clips) waits for chain1
- spark (logs/spark.log, medium 12h, 40/60/100/150 m): haussmann 1.0/1.2/1.0/0.6 % (sprite 0.0/0.2/0.3/0.4), corner
  1.1/1.2/1.0/0.7 (0.1/0.2/0.2/0.3), canal_b 0.7/1.0/0.6/0.9 (0.1/0.2/0.2/0.4), laube 0.3/0.4/0.3/0.5 (0.1/0.1/0.2/0.3),
  sud 0.4/0.4/0.6/0.8 (0.2/0.3/0.4/0.6), maison 0.4/0.5/1.0/1.4 (0.2/0.4/0.6/0.9); contrast at 150 m model < sprite
- delivered so far: 10_*, 20/21_*, 25_*, 26, 27, 29, 30, 31, 32 (deliver1.sh + manual compose in K/tmpimg)
## 10:30
- A/B run = 7.5 min (pa high 12 done, exit 0, 0 errors; K/ab). Modern clearly finer at 4 s (Haussmann flank).
- report parts K/rep: 02_methode.md, 05_messungen.md written; next 01 answer, 03 defects, 04 race, 06 confirm, 07 contract,
  08 next, 09 pictures; assemble with py/assemble.py (copy from KRITIK-5a1, adapt)
## 10:45
- A/B done: pa am br ly (high 12): Modern clearly finer near; ly 2 s: right immeuble MISSING in Modern (bend
  corridor F7, FIX-M2 B-01 not in this base); br: Arcade low brick walls (scenery "fence" style wall of
  city_belgian_outskirts) missing in Modern (renderer, not AS5a2). Sunny facades +15-20 % vs Arcade (R4).
- rep/: 02, 03b (K3-K10), 05, 06 (placeholders BEST_LADEN BEST_FERN), 07 written; todo 00, 01, 03 (K1 Fernbild, K2 Laden), 04, 08, 09
## 11:05
- A/B done also pa/am/be 22 h. Paris night: shops 8.9 vs 24.4 % lit area, warm px luma 149 vs 203 (K1 confirmed);
  Bern night lit px 1.5-2.0 vs 3.7-4.0 %; Amsterdam night equal (1.65 vs 1.35-1.94 %). rep/03 (K1 shops night, K2 far)
  + 03b (K3-K10) + ph_BEST_LADEN written. deliver2.sh = race images with captions (run after ab_all done)
- remaining: br medium 19.5, ly_out, am_out; then chain2 drive clips (SPAR SAMS model, SPAR sprite, SBER model)
## 11:20
- ab_all done (11 runs, all exit 0, 0 errors). deliver2.sh run -> 01-09, 11, 12 race images; 13 crops.
- rep/ 00 01 02 03 03b 04 05 06 07 08 written (placeholders: CLIP, BEST_FERN; RENNEN_VORORT, BEST_LADEN filled)
- chain3 (bg, logs/chain2.out): drive SPAR model (~12 min), SPAR sprite, race clip Amsterdam 6 s medium (clip/),
  then SAMS/SBER drive -> KILL chain3 after race clip (time). Then: rough2/clipstat on clips, mp4 of drive clips,
  09_bilder, assemble, StructuredOutput, cleanup (tree 635M, clips, mesa, xdg).
## 11:27
- drive SPAR model done (clips/SPAR_model, mp4 clips/SPAR_model.mp4); swappop: swap at 60 m drowned in motion
  (10.8 vs 10.4 % around). rough2 numbers need the sprite clip -> chain5 (bg) runs SPAR sprite after chain4.
- chain4 (bg): race clip Amsterdam 6 s medium -> clip/fahrt_amsterdam_50kmh.mp4 (logs/clip_am.log)
- report assembled draft OK (py/assemble.py); open placeholders CLIP, BILDER_CLIP
## 11:34
- race clip done: clip/fahrt_amsterdam_50kmh.mp4 (exit 0, Modern 311 s) -> deliver 40 (mp4), 41 stills, 42 consecutive
  frames. rough2 centre (far facades): Modern 10.8 vs Arcade 5.7 (flicker px 11.4 vs 6.6 %), h264 crop, content differs.
- chain5 (bg): SPAR sprite drive clip -> then rough2 model vs sprite + side-by-side mp4 (43), fill CLIP/BILDER_CLIP,
  assemble, final read, StructuredOutput, cleanup
## 11:40 FERTIG (bis auf StructuredOutput)
- bericht.md complete in deliver/KRITIK-5a2 (py/assemble.py from rep/*.md + rep/ph_*.md), 40+ pictures, 2 mp4.
- cleanup done: tree, frame dirs, mesa, xdg, clip deleted. Kept: kt/ (incl. new k6_scene.gd), py/, logs/, shots/, ab/,
  rep/, tmpimg/, clips/*.log + SPAR_model.mp4. AS5a2 worktree untouched (git status clean, 3c5e37a).
- A successor only needs to send the StructuredOutput (summary in rep/01_antwort.md).
