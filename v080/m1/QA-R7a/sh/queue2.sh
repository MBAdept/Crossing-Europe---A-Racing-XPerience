#!/bin/bash
# QA-R7a queue 2 (after queue1): gates, occlusion, deck + night pictures, perf, goldens. One heavy job at a time.
# A step is skipped when its marker file exists (restart-safe): $S/done/<step>
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7a/sh/common.sh
mkdir -p "$S/done"
step() { [ -f "$S/done/$1" ]; }
mark() { touch "$S/done/$1"; }
echo "$(date -u +%H:%M:%S) start queue2"
# 1 gate: run_tests (complete)
if ! step run_tests; then
	memwait; t0=$SECONDS
	(cd "$WT" && XDG_DATA_HOME=$S/xdg_tests nice -n 10 timeout 3600 tools/run_tests.sh > "$S/logs/run_tests_1.log" 2>&1)
	echo "$(date -u +%H:%M:%S) run_tests exit=$? $((SECONDS - t0)) s"; mark run_tests
fi
# 2 real builds with the reach fix (scratch copy mut)
if ! step realbuild_fix; then
	t0=$SECONDS
	(cd "$S/mut" && XDG_DATA_HOME=$S/xdg nice -n 10 timeout 3600 godot --headless --path . -s "$S/probe/realbuild.gd" -- --stage=all --dump="$S/logs/dump_all_fix.txt" > "$S/logs/realbuild_all_fix.log" 2>&1)
	echo "$(date -u +%H:%M:%S) realbuild_fix exit=$? $((SECONDS - t0)) s"; mark realbuild_fix
fi
# 3 occlusion at C1 (R7a, R7a + reach fix, base) and S4/T2 base
C1A="--stage=dortmund_frankfurt --from=dortmund --km=221 --hour=13 --vehicle=sportwagen --seed=15"
for w in mine fix base; do
	step "occl_C1_$w" || { bash "$S/sh/occl.sh" $w C1 $C1A; mark "occl_C1_$w"; }
done
# 3b the look after the merge with the reach test in props.gd (R7c's one line): high, day
for n in T2 S0 Muenchen Hannover Belgrad T4; do
	step "fix_$n" || { shot fix "$n" high; mark "fix_$n"; }
done
# 4 render checks (gate), modern + arcade
if ! step render_checks; then
	memwait; t0=$SECONDS
	(cd "$WT" && XDG_DATA_HOME=$S/xdg_rc MESA_SHADER_CACHE_DIR=$S/mesa_rc nice -n 10 tools/run_render_checks.sh all > "$S/logs/render_checks.log" 2>&1)
	echo "$(date -u +%H:%M:%S) render_checks exit=$? $((SECONDS - t0)) s"; mark render_checks
fi
# 5 deck, day: R7a and base
for n in T2 S0 Muenchen Hannover T4 R1 C1; do
	step "deck_mine_$n" || { shot mine "$n" deck; mark "deck_mine_$n"; }
	step "deck_base_$n" || { shot base "$n" deck; mark "deck_base_$n"; }
done
# 6 night (22:00), high: R7a and base
for n in S0 T2 Muenchen R1; do
	step "night_mine_$n" || { shot mine "$n" high 22 _nacht; mark "night_mine_$n"; }
	step "night_base_$n" || { shot base "$n" high 22 _nacht; mark "night_base_$n"; }
done
# 7 perf: Saragossa – Pau mountain bends, Steam Deck preset, time scale 4, 420 s, base and R7a back to back
step perf_base || { bash "$S/sh/stage.sh" sp_deck_base base deck saragossa_pau saragossa 11 normal 4 165 420; mark perf_base; }
step perf_mine || { bash "$S/sh/stage.sh" sp_deck_mine mine deck saragossa_pau saragossa 11 normal 4 165 420; mark perf_mine; }
# 8 gate: Arcade identity
if ! step golden; then
	memwait; t0=$SECONDS
	(cd "$WT" && XDG_DATA_HOME=$S/xdg_gold nice -n 10 tools/golden.sh check > "$S/logs/golden_check.log" 2>&1)
	echo "$(date -u +%H:%M:%S) golden exit=$? $((SECONDS - t0)) s"; mark golden
fi
echo "$(date -u +%H:%M:%S) done queue2"
