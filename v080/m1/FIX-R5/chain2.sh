#!/usr/bin/env bash
# FIX-R5: after the gates chain, the forest render check alone with a longer time limit (it timed out at 900 s in the
# full render run under load – the known base finding M2S-01, fixed in FIX-M2's branch, not in this base).
F=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R5
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-6
until grep -q "QUEUE DONE r4mix2" "$F/queue.log"; do sleep 20; done
cd "$WT" || exit 1
t0=$SECONDS
XDG_DATA_HOME=$F/xdg_render RENDER_CHECK_TIMEOUT=2700 nice -n 10 tools/run_render_checks.sh modern instance_budget_wald > "$F/gates/render_wald.log" 2>&1
echo "$(date +%H:%M:%S) render wald exit $? $((SECONDS - t0)) s $(tail -2 "$F/gates/render_wald.log" | tr '\n' ' ' | cut -c1-300)" >> "$F/queue.log"
echo "$(date +%H:%M:%S) CHAIN2 DONE" >> "$F/queue.log"
