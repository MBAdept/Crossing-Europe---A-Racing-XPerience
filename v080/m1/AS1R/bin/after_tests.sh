#!/usr/bin/env bash
# AS1R: after run_tests: golden check, model render check, deliverable renders (sequential, niced).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1R
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9693abb2-cee-3
until grep -q '^exit ' "$S/logs/run_tests.log"; do sleep 10; done
cd "$WT"
mkdir -p "$S/xdg_golden" "$S/xdg_render"
XDG_DATA_HOME=$S/xdg_golden nice -n 10 tools/golden.sh check > "$S/logs/golden.log" 2>&1
echo "exit $?" >> "$S/logs/golden.log"
XDG_DATA_HOME=$S/xdg_render nice -n 10 tools/run_render_checks.sh modern check_models > "$S/logs/render_check.log" 2>&1
echo "exit $?" >> "$S/logs/render_check.log"
"$S/bin/deliver.sh" > "$S/logs/deliver.log" 2>&1
python3 "$S/bin/finish_images.py" >> "$S/logs/deliver.log" 2>&1
echo "alles fertig"
tail -3 "$S/logs/golden.log"
grep -E "RENDER-CHECK|exit" "$S/logs/render_check.log" | tail -12
tail -14 "$S/logs/deliver.log"
