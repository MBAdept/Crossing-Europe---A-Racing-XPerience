#!/bin/bash
# Final Modern measurements with the final assets: loudness plan for all five cars, then the Modern half of the A/B
# captures (the Arcade half of ab_f1 is reused: Arcade did not change).
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B/work
bash "$W/capture_all.sh" plan_f2 modern > "$W/plan_f2_modern.log" 2>&1
mkdir -p "$W/ab/ab_f2"
cp "$W"/ab/ab_f1/*_arcade.wav "$W"/ab/ab_f1/*_arcade.wav.json "$W/ab/ab_f2/"
PROFILES=modern bash "$W/ab_all.sh" ab_f2 > "$W/ab_f2.log" 2>&1
echo KETTE2 FERTIG
