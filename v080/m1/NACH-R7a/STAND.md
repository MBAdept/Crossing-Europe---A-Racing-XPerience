# STAND NACH-R7a – FERTIG (2026-11-23 ~11:10 UTC)
Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-11 (ff to 4a43944, nothing changed, nothing committed)
Report: deliver/NACH-R7a/bericht.md (complete). Pictures: deliver/NACH-R7a/{m3,kopf,vergleich,ausschnitte}.
Scratch tree m3 (HEAD + FIX-RINT + FIX-R7c eb97a98 + patch B) DELETED after use; xdg/mesa/gold_keep/occl pngs deleted.
Kept: logs/, probe/fp_true.gd, sh/*, props_m3_{patched,unpatched}.gd, test_props_m3_unpatched.gd.

Results:
- QR7a-01 partly: head props_footprint --full FEHLER 5728; patch on m3 -> OK 0 (218103); occl C1 270 m 5/18/19 px;
  overlaps 2327 vs 2341; m3 unit tests green; mutations: M1 only props_footprint, M2/M3 only test_props.
  True AABB residual 5138 (872 > .5 m, 96 > 1 m, max 3.45; 85 city_french_sud extent_m too small) = NR7a-01.
- QR7a-02 fixed: merge-tree clean with fix-rint/fix-r7c/fix-r7b; warm_vs_commit in m3: 1/3000 (Saragossa), 0/3000 (Kiel).
- Gates head: golden 20/20 + 17/17; run_tests 811/0 (1087 s); sight --full 6/6 OK; path OK; render terrain_cover (K1), start_km0,
  light_base, structures(+licht) OK.
- New: NR7a-01..04. Only the StructuredOutput result remains.
