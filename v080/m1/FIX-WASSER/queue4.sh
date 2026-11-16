#!/usr/bin/env bash
# FIX-WASSER queue 4: waits for queue 3 (build + smokes), then the remaining A/B pictures and the "before" pictures
# (base far_ground.gd set in and restored). The gates run separately (queue5.sh: a background job lives 2 h at most).
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-WASSER
until grep -q '^== fertig' "$S/queue3.log"; do sleep 5; done
echo "== after $(date -u +%T)"
bash "$S/after_queue.sh" > "$S/after_queue.log" 2>&1
echo "after exit $? $(date -u +%T)"
echo "== before $(date -u +%T)"
bash "$S/before_queue.sh" > "$S/before_queue.log" 2>&1
echo "before exit $? $(date -u +%T)"
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-1 || exit 1
git status --short
echo "== fertig $(date -u +%T)"
