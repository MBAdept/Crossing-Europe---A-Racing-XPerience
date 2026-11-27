#!/bin/bash
# W6 C1: after the Plattenbau, export the other nine sets one by one (resumable: an id whose model.json exists is skipped)
W6=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/qamid-fix
until grep -q "REAL DONE" $W6/logs/run_plattenbau.log 2>/dev/null || ! pgrep -f "only=props/city_eastern_plattenbau" > /dev/null; do sleep 20; done
for s in vienna_zinshaus spanish_casa spanish_block italian_block vienna_palais italian_palazzo spanish_ladrillo italian_venezia vienna_kirche; do
	[ -f $WT/assets/models/props/city_$s/model.json ] && { echo "skip $s" >> $W6/logs/queue_c1.log; continue; }
	bash $W6/real.sh props/city_$s >> $W6/logs/queue_c1.log 2>&1
done
echo "QUEUE C1 DONE $(date +%T)" >> $W6/logs/queue_c1.log
