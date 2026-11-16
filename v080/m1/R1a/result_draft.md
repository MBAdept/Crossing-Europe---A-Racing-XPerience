# Draft of the StructuredOutput of R1a – STATUS OF EVERY CLAIM (updated 03:30 UTC by `date`)

package: R1a · branch: worktree-wf_3b561c53-566-1 · worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b561c53-566-1
head while writing: 72938cd (pushed to wip/v080-r1a). A last commit with docs + tests only is still planned.

## What has actually been observed, and on which code

| claim | observed? | on which commit |
|---|---|---|
| tools/run_tests.sh complete, green (576 unit tests, 80 CHECK lines) | yes | faaf3e7 |
| tools/run_tests.sh complete on the head | RUNNING (b26llv393) – unknown | 72938cd |
| tools/golden.sh check 20 von 20 | yes, but on a MIXED tree (debug_road.gd was being edited) | between faaf3e7 and 72938cd |
| tools/golden.sh check on the head | RUNNING – unknown | 72938cd |
| tools/run_render_checks.sh all, 5 of 5 | yes | faaf3e7, and again on the content of 72938cd (before the commit) |
| render check "nacht" | ran ONCE (03:22) | content of 72938cd |
| ERGEBNIS identity kiel_hamburg + dev_testetappe (28 keys, only gfx) | yes | 300a571 – NOT repeated on the head yet |
| render() 0.15 ms avg headless, prepare 74–77 ms | yes | 300a571 – before the debug-road update() hook; NOT repeated |
| check_facade, check_seam, check_session, unit race3d, check_scripts | yes | content of 72938cd |
| doc examples (layer + builder) run in the real renderer | yes, headless only (no picture) | 300a571 |

## Claims in committed docs / report that were NOT observed (fix wording or measure)

1. "a vehicle casts no shadow on the unshaded debug road" (docs §9.1, bericht §7.6) – inferred. Script ready:
   bin/shadow_on_debug_road.gd (Xvfb).
2. Tunnel behaviour of plain_environment / plain_sky / debug-road tint, and --gfx-debug=cover – code read only; no
   test or picture of this package was ever inside a tunnel. check_facade.gd line 614 comment says "a tunnel as
   well" but there is no tunnel stage.
3. docs §9.6 "the pinned post path pushes values below 12/255 down by up to ten steps" – only the total darkening was
   measured (road 6/13/27 vs 16/21/32; plate 17/22/34 vs 21/25/36); the cause is taken from docs/modelle.md §4.
4. docs §9.6 "at night bright albedos up to a quarter brighter" – the predecessor's computed figure, not re-checked.
5. docs §9.6 list of ce_* globals – set in code; nothing in this package reads them back or shows them.
6. ".gdshaderinc is exported" – inferred from export_filter="all_resources"; no export was built.
7. "minimised window stalls the preparation, the timeout does not count that time" – reasoning about the engine's
   main loop; not tried (no window manager here). The TIMEOUT_FRAME_MS / drawn-frames logic itself is only
   exercised by the headless "ausfall" check (0.3 s limit fires) – the "does NOT fire while nothing is drawn" side
   has no test.

## Not done / out of scope, to be said plainly
- The skeleton's picture is clearly worse than Arcade (day) and darker than Arcade (night).
- No MSAA / 3D scale / shadow atlas per quality level, no watchdog, quality_lowered never emitted.
- Nobody calls ModelDB.release_all() + ModernMaterials.drop_shared() on leaving the mode.
