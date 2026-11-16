# NACH-WASSER notes (working file, not a report)

## Build identity (measured 11:40 UTC)
- sha256sum -c --ignore-missing SHA256SUMS in deliver/FIX-WASSER/build: tar.gz OK, zip OK, LIZENZEN.txt OK
- extracted: CrossingEurope-ZS1.x86_64 59248e24… = SHA256SUMS; CrossingEurope-ZS1.exe 96130d5d… = SHA256SUMS
- BUILDINFO: Commit 39849f0263921f798da4326b83dff30d83a947d2, Godot 4.7.2.stable.official.ed1daf0bf
- pck_diff alt(0ad9012) vs new Linux: CHANGED scripts/race3d/builders/props.gdc 25480 -> 27471; files 1011/1011, new 0, gone 0
- pck_diff new Linux vs new Windows: 0 changed, 0 new, 0 gone (1011 files)
- props.gdc (decompressed, 92700 B): identifiers landmark_fallbacks, dark_material, _lm_fallback, _dark_mats present (XOR-UTF32)

## Diff 0ad9012..39849f0
- 7 files: docs/qa-v080.md, docs/renderer-modern-gelaende.md, docs/renderer-modern.md, scripts/race3d/builders/props.gd,
  tests/race3d/check_terrain_plan.gd, tests/race3d/render/check_terrain_cover.gd, tests/unit/race3d/test_props.gd
- none frozen (Rule 1 list), no data/**, no assets/**
- side effect: _update_far_landmarks now reads it["tint"] for every far landmark -> tinted far stand-in (MultiMesh) for
  20 sprite landmarks with tint (lm_scan.py). Not on Kiel->Hamburg (Elbphilharmonie/Michel no tint); on Hamburg->Kiel the
  "Rathausturm" (props/church #c4927a, km 92.8). queue4 measures it.
- shader: lights_rect.z > 0 gate -> zero rect = no light layer; headlight_color material uniform; ce_* globals -> dark copy follows day/night

## Pictures (Linux export unless noted)
- KB night high: old vs new Modern differ only on the two pylon legs (bbox x498-745 / x376-846); Arcade identical
- pylon legs frame 01 (km 78.1) left/right: Modern high 50.5/46.4, medium 50.5/46.4, low 50.7/46.0; Arcade 66.3/45.1
  frame 03 (km 79.6) regions: Modern high 46.0/35.1, medium 46.1/35.0, low 44.5/34.2; Arcade 42.0/30.7
- FIX-WASSER-R's region 500-780x150-350 frame 01: Modern 58.0 (6.1 % >200), Arcade 60.2 (6.4 %) (includes HUD banners)
- deck 1280x800 night: Arcade old==new; Modern differs only on pylons (2.1-9.5 %)
- day kb_tag_hoch_b: old==new bit-identical 8/8 (Arcade + Modern) -> pylon feet unchanged
- start km0: new == old (QA-WASSER) == FIX-WASSER-R pictures, bit-identical (Arcade + Modern)
- Windows/Wine: KB night 8/8 + start 4/4 pixel-identical with Linux
- Belgrad: Arcade == QA's ada; Modern differs only in bbox x1036-1175 y87-344 (the stand-in church)
- Hannover, Calais, Dortmund: stand-in present at Arcade's place; Calais lighthouse -> village church; Dortmund TV tower ->
  giant office slab (building_tall x3.2: 211 m high, 71 m wide)
- lm_chunk_check.gd: 6 sets x all 20 approach directions -> stand-in DRAWN in its chunk (unit-test kernel context)
- lm_corridor.gd: no stand-in footprint in a bend sight corridor (0/15 samples, 20 approaches) -> no F7 issue
- drop_check.gd Dortmund km 152.6-154.6: right-hand city buildings dropped "corridor" (F7, decorative) -> pre-existing,
  explains missing houses (also Calais/Belgrade, inferred); not caused by this round

## Gates
- golden.sh check: GOLDEN arcade 20 von 20 identisch (149 s); GOLDEN arcade-ui 17 von 17 identisch (214 s); exit 0
