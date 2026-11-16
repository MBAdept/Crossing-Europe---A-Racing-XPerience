#!/bin/bash
# QA1 queue 3 (one heavy job at a time): after the smoke runs: chooser walk of the Linux test build, then the final
# gates on the final commit: golden.sh check, run_render_checks.sh all, run_tests.sh (run 2).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA1
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-5
Q=$S/queue3.log
G=$S/gates
mkdir -p "$G"
log() { echo "$(date +%H:%M:%S) $*" >> "$Q"; }
log "queue3 start"
until grep -q ALLDONE "$S/run_smoke.out" 2>/dev/null; do sleep 15; done
log "smoke done"
"$S/chooser_walk.sh" > "$S/chooser_walk.out" 2>&1
log "chooser walk done: $(grep -c shot "$S/chooser_walk.out") shots"
cd "$WT" || exit 1
log "head $(git rev-parse --short HEAD), dirty $(git status --porcelain | wc -l)"
mkdir -p "$S/xdg_gate_golden" "$S/xdg_gate_render"
t0=$SECONDS
XDG_DATA_HOME=$S/xdg_gate_golden KEEP=$S/golden_final_keep nice -n 10 tools/golden.sh check > "$G/golden_final.log" 2>&1
echo "exit=$? dauer=$((SECONDS - t0))s" >> "$G/golden_final.log"
log "golden: $(grep -E '^GOLDEN|^exit' "$G/golden_final.log" | tr '\n' ' ')"
t0=$SECONDS
XDG_DATA_HOME=$S/xdg_gate_render MESA_SHADER_CACHE_DIR=$S/mesa_rc nice -n 10 tools/run_render_checks.sh all > "$G/render_checks_final.log" 2>&1
echo "exit=$? dauer=$((SECONDS - t0))s" >> "$G/render_checks_final.log"
log "render checks: $(grep -E '^==>|^exit' "$G/render_checks_final.log" | tr '\n' ' ')"
"$S/run_tests_bg.sh" 2
log "run_tests 2: $(grep -E '^==> Tests|^exit' "$G/run_tests_2.log" | tr '\n' ' ')"
log "queue3 end"
