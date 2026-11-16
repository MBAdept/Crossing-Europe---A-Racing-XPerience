f=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/snap_D/scripts/race3d/vehicle_pose3d.gd
cp $f $f.orig
sed -i 's/^const MODEL_BRAKE_NIGHT_SHARE := 0.5/const MODEL_BRAKE_NIGHT_SHARE := 1.0/' $f
grep -n '^const MODEL_B' $f
/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/sh/rc_snap.sh D n4_mut_fullnight check_vehicle_lights --only=bremsschein
cp $f.orig $f
