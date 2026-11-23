#!/bin/bash
# QA-R7a queue 1: fairness full runs, then the high-day pictures (R7a and base)
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7a/sh/common.sh
echo "$(date -u +%H:%M:%S) start queue1"
memwait
t0=$SECONDS
(cd "$WT" && nice -n 10 timeout 3000 godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full > "$S/logs/sight_full.log" 2>&1)
echo "$(date -u +%H:%M:%S) sight_full exit=$? $((SECONDS - t0)) s"
t0=$SECONDS
(cd "$WT" && nice -n 10 timeout 1800 godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full > "$S/logs/path_full.log" 2>&1)
echo "$(date -u +%H:%M:%S) path_full exit=$? $((SECONDS - t0)) s"
# high day, R7a: the positions with the largest changes first
for n in T2 S0 Muenchen Hannover T4 C1 Belgrad R1 R2 T1 T3 S4 Lyon Bern Nuernberg R3 R4 R5; do
	shot mine "$n" high
done
# base, high day (Modern only matters; Arcade is identical)
for n in T2 S0 C1 R2; do
	shot base "$n" high
done
echo "$(date -u +%H:%M:%S) done queue1"
