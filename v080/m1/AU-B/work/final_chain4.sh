#!/bin/bash
# Final evidence with the shipped files (after the clonk of the shift thump was softened), one job after the other:
# Modern A/B captures, loudness plan, determinism QC, 20 shutdowns, check_engine3, Movie Maker sync probe.
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B/work
R=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-2
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AU-B
mkdir -p "$W/ab/ab_f3" "$D"
cp "$W"/ab/ab_f1/*_arcade.wav "$W"/ab/ab_f1/*_arcade.wav.json "$W/ab/ab_f3/"
PROFILES=modern bash "$W/ab_all.sh" ab_f3 > "$W/ab_f3.log" 2>&1
echo "AB FERTIG $(date -u +%H:%M:%S)"
bash "$W/capture_all.sh" plan_f3 modern > "$W/plan_f3_modern.log" 2>&1
echo "PLAN FERTIG $(date -u +%H:%M:%S)"
cd "$R" || exit 1
nice -n 10 python3 tools/audio/qc/audio_qc.py --determinism > "$W/qc_final.log" 2>&1
echo "QC Rückgabewert $? $(date -u +%H:%M:%S)"
bash "$W/shutdown20.sh" 20 > "$W/shutdown20_final.log" 2>&1
echo "SHUTDOWN FERTIG $(date -u +%H:%M:%S)"
export XDG_DATA_HOME=$W/../xdg_quit
timeout -s KILL 300 godot --headless --path . -s res://tests/unit/audio_modern/check_engine3.gd -- --graphics=arcade > "$W/check_engine3_final.log" 2>&1
echo "CHECK Rückgabewert $? $(date -u +%H:%M:%S)"
bash "$W/movie_probe.sh" gran_turismo --audio-sync > "$W/movie_final.log" 2>&1
echo "KETTE4 FERTIG $(date -u +%H:%M:%S)"
