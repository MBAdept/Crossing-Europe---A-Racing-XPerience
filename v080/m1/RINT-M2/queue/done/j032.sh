f=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/snap_D/scripts/race3d/vehicle_pose3d.gd
cp $f $f.orig
sed -i 's/^const MODEL_BRAKE_GAIN := 2.2/const MODEL_BRAKE_GAIN := 1.0/; s/^const MODEL_BEACON_GAIN := 2.4/const MODEL_BEACON_GAIN := 1.0/' $f
grep -n '^const MODEL_B' $f
/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/sh/rc_snap.sh D n4_mut_gain1 check_vehicle_lights --only=bremsschein,blaulicht
cp $f.orig $f
