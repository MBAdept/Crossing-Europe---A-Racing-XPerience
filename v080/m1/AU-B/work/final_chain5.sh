#!/bin/bash
# After the level trim of Kombi and Sportwagen (mix.gain only): loudness plan and Modern A/B captures for these two
# cars, then the determinism QC on the final files. Run after the banks were regenerated.
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B/work
R=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-2
CARS="kombi sportwagen" bash "$W/capture_all.sh" plan_f4 modern > "$W/plan_f4_modern.log" 2>&1
echo "PLAN FERTIG $(date -u +%H:%M:%S)"
mkdir -p "$W/ab/ab_f4"
cp "$W"/ab/ab_f3/*.wav "$W"/ab/ab_f3/*.wav.json "$W/ab/ab_f4/"
CARS="kombi sportwagen" PROFILES=modern bash "$W/ab_all.sh" ab_f4 > "$W/ab_f4.log" 2>&1
echo "AB FERTIG $(date -u +%H:%M:%S)"
cd "$R" || exit 1
nice -n 10 python3 tools/audio/qc/audio_qc.py --determinism > "$W/qc_final2.log" 2>&1
echo "QC Rückgabewert $? $(date -u +%H:%M:%S)"
echo "KETTE5 FERTIG"
