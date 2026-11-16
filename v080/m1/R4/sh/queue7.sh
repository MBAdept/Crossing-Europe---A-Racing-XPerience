#!/bin/bash
# queue7.sh – after queue6: the gates (without import/check_scripts, golden check last of all), then the measurements
R4=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-1
L=$R4/queue7.log
until grep -q QUEUE6_DONE "$R4/shots/v6/queue.log" 2>/dev/null; do sleep 20; done
mkdir -p "$R4/probe/glow"
cp "$R4/probe/glow_probe_tmp.gd" "$WT/tests/race3d/render/glow_probe_tmp.gd"
echo "== glow probe $(date -u +%T)" >> "$L"
"$R4/sh/probe.sh" res://tests/race3d/render/glow_probe_tmp.gd --save=$R4/probe/glow >> "$L" 2>&1
rm -f "$WT/tests/race3d/render/glow_probe_tmp.gd" "$WT/tests/race3d/render/glow_probe_tmp.gd.uid"
QUEUE="${QUEUE7_PICS:-TEXIT}" "$R4/sh/queue5.sh" "$R4/shots/v7"
echo "== gates $(date -u +%T) head $(git -C "$WT" rev-parse --short HEAD)" >> "$L"
"$R4/sh/gates.sh" run_tests sight path render_checks modern_check
echo "== warm $(date -u +%T)" >> "$L"
"$R4/sh/warm.sh" >> "$L" 2>&1
echo "== bench head $(date -u +%T)" >> "$L"
"$R4/sh/bench.sh" head "$WT" medium deck low high >> "$L" 2>&1
echo "== bench base $(date -u +%T)" >> "$L"
"$R4/sh/bench.sh" base "$R4/base" medium >> "$L" 2>&1
echo "== stage head $(date -u +%T)" >> "$L"
"$R4/sh/stage.sh" head "$WT" >> "$L" 2>&1
echo "== stage base $(date -u +%T)" >> "$L"
"$R4/sh/stage.sh" base "$R4/base" >> "$L" 2>&1
echo "== clips $(date -u +%T)" >> "$L"
"$R4/sh/clips.sh" N2N N1 TEXIT >> "$L" 2>&1
echo "QUEUE7_DONE $(date -u +%T)" >> "$L"
