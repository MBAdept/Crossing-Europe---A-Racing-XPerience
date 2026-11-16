#!/usr/bin/env bash
# Scratch (GEO): the milestone runs with the final code, one after the other.
set -u
G=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/GEO
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-4
cd "$W" || exit 1
export XDG_DATA_HOME=$G/xdg_full
mkdir -p "$XDG_DATA_HOME" "$G/out"
T=${1:-final}
{ time nice -n 10 godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full ; echo "EXIT $?" ; } > "$G/out/sight_full_$T.log" 2>&1
{ time nice -n 10 godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full ; echo "EXIT $?" ; } > "$G/out/path_full_$T.log" 2>&1
{ time nice -n 10 godot --headless --path . -s res://tests/sim/modern_sight.gd ; echo "EXIT $?" ; } > "$G/out/sight_sample_$T.log" 2>&1
{ time nice -n 10 godot --headless --path . -s res://tests/sim/modern_path_check.gd ; echo "EXIT $?" ; } > "$G/out/path_sample_$T.log" 2>&1
{ nice -n 10 godot --headless --path . -s "$G/scratch/measure_kernel.gd" ; echo "EXIT $?" ; } > "$G/out/measure_$T.log" 2>&1
echo done > "$G/out/full_runs_$T.done"
