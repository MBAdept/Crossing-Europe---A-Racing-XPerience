#!/usr/bin/env bash
# NACH-R5 queue: everything heavy one after the other.
set -uo pipefail
N=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R5
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-8
echo "Q start $(date +%T)"
"$N/shots.sh" new u1_nacht_nah somport_nacht stein
echo "Q r4probe $(date +%T)"
"$N/r4probe.sh"
echo "Q mutate $(date +%T)"
python3 "$N/mutate.py"
echo "Q clean? [$(git -C "$WT" status --porcelain)] head $(git -C "$WT" rev-parse --short HEAD)"
if [ -n "$(git -C "$WT" status --porcelain)" ]; then echo "Q ABORT: worktree not clean"; exit 1; fi
echo "Q gates $(date +%T)"
"$N/gates.sh" scripts units render full golden
echo "Q clean after gates? [$(git -C "$WT" status --porcelain)]"
echo "Q DONE $(date +%T)"
