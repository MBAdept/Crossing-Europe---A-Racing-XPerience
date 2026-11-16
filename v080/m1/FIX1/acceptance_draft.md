QB-01 pass: tunnel.gd/tunnel.gdshader; U1/DEV/Elbtunnel pictures; check_minimal_structures tunnel OK (110 segments, 1 portal, 1 cap, 54 lamps)
QB-02 pass: station.gd; S2 picture; check station OK (34 island, 23 canopy segments, 5 fronts with lettering)
QB-03 pass: landmarks (far nodes + landmark_law), railing, water; S4 picture; checks wahrzeichen, bruecke OK
QB-04 pass: gantry.gd; S5 picture; check tore OK
QB-05 pass: coat_sun/sun_spec; DEV 21h p95 193 -> 69 (Arcade 51)
QB-06 not_run: weather = R4 (M2); listed in renderer-modern.md §14.10 for test notes
QB-07 pass: fog_law.gdshaderinc; S1 far trees; render check sichtgrenze OK (16 % vs 22 %, 0.00 % at limit)
QB-08 not_run: lead decision per A-3 (proposal in bericht)
QB-09 not_run: model rework belongs to asset pipeline (AS packages running in parallel)
QB-10 partial: hooks_ms_avg/max in perf_stats + Leistungstest; Xvfb budget checks not added
QB-11 partial: sichtgrenze added; luminance per weather×hour and GLES=GL not (QA1)
QB-12 not_run: low, untouched
QS-01 pass: run_tests.sh always runs steps 3/4 + failure list (run_tests run 1 shows ...)
QS-02 pass: check_facade projection law + frames>5 (OK under load ...)
QS-03 pass: check_attract both modes OK (unloaded) + under load in run_tests
QS-04 pass: crash strikes; test_crash_guard_strikes OK
QS-05 not_run: lead decision (project.godot owned by REL W8)
QS-06 not_run: waits for sun disc
QS-07 pass: note 10 px lower; screenshot
QS-08 pass: docs updated
