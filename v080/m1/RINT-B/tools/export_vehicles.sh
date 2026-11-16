#!/bin/bash
# Re-export the six vehicle models with the merged pipeline code (Blender), then report.
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-B
cd "$WT" || exit 1
t0=$(date +%s)
nice -n 10 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only='player/*' --jobs=2 > "$S/export_player.log" 2>&1
e1=$?
nice -n 10 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only='traffic/*' --jobs=2 > "$S/export_traffic.log" 2>&1
e2=$?
echo "player=$e1 traffic=$e2 seconds=$(( $(date +%s) - t0 ))" > "$S/export_vehicles.done"
