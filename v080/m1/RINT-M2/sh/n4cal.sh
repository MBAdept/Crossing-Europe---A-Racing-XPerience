#!/bin/bash
# RINT-M2: calibrate the bremsschein check – head, gains 1.0, full night gain (worktree file edited and restored)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1
F=$W/scripts/race3d/vehicle_pose3d.gd
cp $F $S/vehicle_pose3d.keep
TO=900 $S/sh/rc_snap.sh $W n4c_head check_vehicle_lights --only=bremsschein
sed -i 's/^const MODEL_BRAKE_GAIN := 2.2/const MODEL_BRAKE_GAIN := 1.0/' $F
TO=900 $S/sh/rc_snap.sh $W n4c_gain1 check_vehicle_lights --only=bremsschein
cp $S/vehicle_pose3d.keep $F
sed -i 's/^const MODEL_BRAKE_NIGHT_SHARE := 0.5/const MODEL_BRAKE_NIGHT_SHARE := 1.0/' $F
TO=900 $S/sh/rc_snap.sh $W n4c_full check_vehicle_lights --only=bremsschein
cp $S/vehicle_pose3d.keep $F
cmp $F $S/vehicle_pose3d.keep && echo restored
