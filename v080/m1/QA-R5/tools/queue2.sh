#!/usr/bin/env bash
# QA-R5 queue 2 (after queue 1): mutations, network scans, fairness. One heavy job at a time.
Q=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R5
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-4
while ! grep -q QUEUE1_DONE $Q/queue1.log 2>/dev/null; do sleep 30; done
mkdir -p $Q/tmp/xdg_q2 $Q/logs
export XDG_DATA_HOME=$Q/tmp/xdg_q2
echo "== qa_scan $(date +%T)"
(cd $Q/mut && nice -n 10 timeout 1800 godot --headless --path . -s res://tests/qa_r5/qa_scan.gd > $Q/logs/qa_scan.log 2>&1; echo "qa_scan exit $?")
tail -3 $Q/logs/qa_scan.log
echo "== R5 full scan $(date +%T)"
(cd $WT && nice -n 10 timeout 1800 godot --headless --path . -s res://tests/race3d/render/check_tunnel_bridge.gd -- --full > $Q/logs/r5_full_scan.log 2>&1; echo "full exit $?")
grep -E "RENDER-CHECK|SCRIPT ERROR" $Q/logs/r5_full_scan.log | head
echo "== mutations $(date +%T)"
nice -n 10 python3 $Q/tools/mutate.py > $Q/logs/mutate.log 2>&1
tail -30 $Q/logs/mutate.log
echo "== modern_sight full $(date +%T)"
(cd $WT && nice -n 10 timeout 3600 godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full > $Q/logs/modern_sight_full.log 2>&1; echo "sight exit $?")
grep -E "CHECK|SCRIPT ERROR" $Q/logs/modern_sight_full.log | head -20
echo "== modern_path_check full $(date +%T)"
(cd $WT && nice -n 10 timeout 3600 godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full > $Q/logs/modern_path_full.log 2>&1; echo "path exit $?")
grep -E "CHECK|SCRIPT ERROR" $Q/logs/modern_path_full.log | head -20
echo "QUEUE2_DONE $(date +%T)"
