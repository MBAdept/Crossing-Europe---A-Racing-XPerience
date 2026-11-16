#!/bin/bash
# QA-M2-BILD: fairness over the whole network (F1-F3, F7) and path check, headless
WT=${WT:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-3}
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-BILD
TAG=${TAG:-m2}
cd "$WT" || exit 1
export XDG_DATA_HOME=$S/xdg/fair_$TAG
mkdir -p "$XDG_DATA_HOME"
t0=$SECONDS
nice -n 10 godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full --verbose > $S/fair/modern_sight_full_$TAG.log 2>&1
echo "$(date -u +%H:%M) $TAG modern_sight exit=$? $((SECONDS - t0)) s" >> $S/fair/summary.txt
t0=$SECONDS
nice -n 10 godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full > $S/fair/modern_path_full_$TAG.log 2>&1
echo "$(date -u +%H:%M) $TAG modern_path exit=$? $((SECONDS - t0)) s" >> $S/fair/summary.txt
