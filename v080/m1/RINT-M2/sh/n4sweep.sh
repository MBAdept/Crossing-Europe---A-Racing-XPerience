#!/bin/bash
# RINT-M2: sweep MODEL_BRAKE_NIGHT_SHARE in the probe at 22:00 (worktree file edited and restored)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1
F=$W/scripts/race3d/vehicle_pose3d.gd
cp $F $S/vehicle_pose3d.keep2
for sh in 0.0 0.15; do
	cp $S/vehicle_pose3d.keep2 $F
	sed -i "s/^const MODEL_BRAKE_NIGHT_SHARE := 0.35/const MODEL_BRAKE_NIGHT_SHARE := $sh/" $F
	grep '^const MODEL_BRAKE_NIGHT_SHARE' $F
	$S/sh/veh.sh $W modern n4s${sh/./}_h22 --hour=22 --only=d20,d60
done
cp $S/vehicle_pose3d.keep2 $F
cmp $F $S/vehicle_pose3d.keep2 && echo restored
python3 $S/sh/vehlum.py $S/shots/veh mrg_h22 arc_h22,n4s00_h22,n4s015_h22,n4b_h22 d60c:sports d20a:sedan d20c:sports
