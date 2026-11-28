#!/bin/bash
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AUC2/env.sh
cd $WT
for d in final final_amb final_trf; do rm -rf $S/$d; mkdir -p $S/$d; done
timeout 1200 nice -n 5 godot --headless --path . -s $S/tools/drive_c2.gd -- --out=$S/final --horn-always > $S/logs/final.log 2>&1
echo "$(date +%T) drive final rc $?" >> $S/logs/final_runs.log
timeout 1200 nice -n 5 godot --headless --path . -s $S/tools/drive_c2.gd -- --out=$S/final_amb --horn-always --mute-bus=MCar,MWorld,MImpact,MMusic,MUI > $S/logs/final_amb.log 2>&1
echo "$(date +%T) drive amb rc $?" >> $S/logs/final_runs.log
timeout 1200 nice -n 5 godot --headless --path . -s $S/tools/drive_c2.gd -- --out=$S/final_trf --only=autobahn,tunnel,unfall --horn-always --mute-bus=MCar,MAmb,MMusic,MUI > $S/logs/final_trf.log 2>&1
echo "$(date +%T) drive trf rc $?" >> $S/logs/final_runs.log
mkdir -p $S/worst_final
for v in "std:" "m1:--master=1.0" "ohneverkehr:--mute-bus=MWorld"; do name=${v%%:*}; arg=${v#*:}; timeout 300 nice -n 5 godot --headless --path . -s $S/tools/worst_case2.gd -- --out=$S/worst_final/w_$name.wav $arg > $S/logs/worst_$name.log 2>&1; done
echo "$(date +%T) worst done" >> $S/logs/final_runs.log
echo "$(date +%T) FINAL RUNS DONE" >> $S/logs/final_runs.log
