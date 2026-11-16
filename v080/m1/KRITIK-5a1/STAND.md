# STAND KRITIK-5a1 (read-only art review of AS5a1, 63544b6)

- Start 15.11. 14:45, no predecessor. Copy of the AS5a1 worktree (incl. its .godot, without .git/build/_cache3d) in
  K/tree (K = this folder), imported OK. env: source K/env.sh. Review tools in K/tree/tools/kritik (copies from AS4R
  scratch + k5_scene.gd drive mode + census_k5.gd). NEVER touch the AS5a1 worktree.
- Runner: K/k5.sh <script> <name> <args>  (pictures K/shots, logs K/logs). Items: K/items.sh (anchor x = edge x + extent_l*sc)
- Census (K/logs/census_k5.log): city sets only at stage ARRIVALS (none at departures). Positions:
  Hamburg kiel_hamburg km 75-95 (outskirts 81.5 tinted houses+crane; centre 87-94), Hannover hamburg_hannover 130-150
  (centre 142-149.5), Kassel hannover_kassel 145-165 (centre 157-164), Würzburg kassel_wuerzburg 190-210 (centre 202-209),
  Nürnberg wuerzburg_nuernberg 90-110 (centre 102-109), München muenchen_nuernberg from nuernberg 150-170 (centre 161.5-169,
  tints #f6eee2 mietshaus, #f6eedc gruenderzeit; vienna_zinshaus stand-in)

## Done
- 14:50 setup, census, timing (prop scene dist2 32 s)

## Doing
- batch1.sh (background): dist sheets 3 styles x 12/19.5/22 high, close-ups day/night, lods medium 12/22

## Next
- sparkcam (shimmer) medium, drive clips 50 km/h (k5_scene --mode=drive, model vs sprite), tint, texel probe,
  validator --report, outline sample, ab_shot at 7 arrivals (high noon, night; medium dusk), sheets + bericht.md

## 15:10
- batch1 dist sheets done (shots/dist_{GER,OLD,HAN}_h{12,19.5,22}.png), close/lods running. chain1.sh (bg) waits for
  batch1 -> batch2 (drive clips K/clips, sparkcam) -> ab_all noon high (K/ab, logs/abA.out).
- Findings so far: models finer than sprite at 10-100 m by day (crisp, depth); hanse_gabled road flank = blank brick
  wall 16x17 m (generator has only front grids) - dominates close passes in Hamburg (AS5a1 ab_hamburg_hoch_nacht left);
  old-town/barock flanks: blank stone ground floor; prop-scene stand-in shows NO night light (compare night in race only);
  at dusk 19.5 model windows lit (stand-in not) -> check vs Arcade in race; kontor/gruenderzeit panes paler than sprite at 100-250 m
- validate --report OK (logs/validate.log); share.py: mesh 0.79 MB, tex 5.25 MB archive (logs/share.log) = AS5a1 numbers

## 15:16
- batch1 done (dist, close, lods: logs/lods_h12.log, lods_h22.log); texel probe outer walls (logs/texel_k5_outer.log);
  mipcov railing mip1-3 1.1-1.4, mip4 0.29/0.59 (confirmed). sparkcam full set too slow -> killed; reduced set in batch3.
- RUNNING: chain1 (bg) = ab_all noon high 7 positions -> K/ab, logs/abA.out ; chain2 (bg) waits for chain1, then
  batch3 = outline_all, tint_all, 7 drive clips (K/clips/<street>_<as>_<preset>/f_NNN.png + f.log), spark6.
- NEXT after chain2: ab_all "hh:high:22 nu:high:22 mu:high:22 ks:high:22 ho:medium:19.5 hn:medium:19.5 wu:medium:19.5"
  (logs/abB.out), then clipstat.py on clips, compose sheets (py/tiles.py), bericht.md.
- Measured: lod1@200m vs stand-in sprite: model 11-23 % brighter (logs/lods_h12.log Fernbild>Sprite); swap 60 m
  fachwerk 32 % (+4.7 %), kontor 24.7 %, night fachwerk 23.8 % (+9 %), kontor 18 % (+9.9 %).
- Defects so far: D1 hanse_gabled blank flank; D2 fachwerk_b oriel windows painted + white plastic corbel;
  D3 model paler than sprite at distance (panes light) - verify in race; D4 swap pop fachwerk/kontor; D5 railings mip;
  D6 office lobby flat white at night; D7 house garden blobs, lod1 only 15 % cheaper.

## 16:10
- Race A/B noon high done: hh, nu, hn (K/ab/*_ab_0{0,1}.jpg) - Modern clearly finer at all three. Runs take 15-21 min.
  chain1 continues with mu, ho; chain3 (bg) then kills chain1 (skips ks/wu noon) and runs batch3.
- Report parts in K/rep/ (02_methode.md, 05_mess_budget.md, notes_race.md). Delivered so far in deliver/KRITIK-5a1:
  10-12 abstaende, 20/21 nahansichten, 25 stufenwechsel, 30 flanke (title too long - redo), 31 erker.
- AFTER chain3: run ab_all "hh:high:22 nu:high:22 hn:medium:19.5" (night/dusk; keep short), clipstat, mp4, bericht.

## 16:31
- Noon A/B done: hh nu hn mu ho (K/ab). ks/wu noon skipped (time; 11-21 min per run). chain3 runs batch3 now.
- Big in-race finding: München km 161.7-162.6 LEFT side empty in Modern (Barock model + vienna stand-in dropped) –
  FIX-M2 B-01 (bend corridor) is OPEN (lead decision), so RINT-M2 will not fix it. Nürnberg km 103.6 fachwerk_b dropped too.
- Tint missing (R7): Hamburg outskirts houses white instead of pink (ho_*).
- NEXT: after batch3: ab_all "hh:high:22 nu:high:22 hn:medium:19.5" (bg, ~45-60 min), clipstat, mp4, report.

## 16:45
- Drive clips are slow (3.7 s/frame). SOLD_model_medium (240 frames, 4 s) done/finishing. chain4 (bg) stops batch3,
  then SOLD_sprite + SGER_model (2.5 s each), spark3 (fachwerk, gruenderzeit, gabled). Then start chain5:
  ab_all "hh:high:22 nu:high:22 hn:medium:19.5" > logs/abB.out.
- Delivered: 26 umrisse, 27 toenung. Report drafts in K/rep (02, 03b, 05, 06, notes_race).

## 16:58
- Delivered: 01-05,09 race A/B noon; 10-12, 20/21, 25-27, 30 (flanks, replaces old 30), 31, 40 (mp4 old town).
- Report parts K/rep: 02_methode, 03_maengel (K1-K4), 03c_maengel (K5-K10 with {{FLIMMER}} {{DAEMMERUNG*}}
  placeholders), 04_rennen ({{NACHT_ZEILEN}}), 05_mess_budget, 06_bestaetigt. Still to write: 00 head, 01 answer,
  07 contract, 08 next steps, 09 pictures, then assemble -> deliver/KRITIK-5a1/bericht.md.
- RUNNING: chain4 (SGER clip, spark3) -> chain5 (abB: hh/nu 22 high, hn 19.5 medium).

## 17:12
- All report parts written; `python3 K/py/assemble.py` builds deliver/KRITIK-5a1/bericht.md (draft exists). Open
  placeholders only from night/dusk: write rep/ph_NACHT_SATZ.md, ph_R4_ZUSATZ.md, ph_DAEMMERUNG_TITEL.md,
  ph_DAEMMERUNG.md, ph_NACHT_ZEILEN.md (table rows for 04), ph_NACHT_BILDER.md (rows 06/07/08 for 09) then reassemble.
- chain5 running (abB.out): hh 22 high, nu 22 high, hn 19.5 medium. Then copy ab jpgs as 06/07/08 into deliver.
- Shimmer measured (logs/spark3.log), K6 filled. Clips: 40/41/42 mp4 delivered.
- FINAL: StructuredOutput; cleanup K/tree (600 MB), K/clips frames, K/mesa.

## FERTIG (17:55)
- bericht.md complete in deliver/KRITIK-5a1 (assembled by py/assemble.py from rep/*.md + rep/ph_*.md), 30 pictures/films.
- Cleanup done: tree, clips frames, mesa, xdg deleted. Kept: tools_kritik/, clip_logs/, shots/, ab/, logs/, rep/, py/.
- AS5a1 worktree untouched (git status clean, 63544b6). Only the StructuredOutput call remains for a successor.
