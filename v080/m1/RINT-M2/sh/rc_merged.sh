#!/bin/bash
# render checks of the merged areas on the untouched merged copy (baseline of the assembly)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2
export XDG_DATA_HOME=$S/xdg_rc_merged
mkdir -p $XDG_DATA_HOME
cd $S/merged
for f in check_night_nass check_night. check_weather. check_tunnel_bridge check_structures. check_structures_licht check_vehicle_lights; do
  RENDER_CHECK_TIMEOUT=1800 tools/run_render_checks.sh modern "$f" >> $S/logs/rc_merged.log 2>&1
done
echo FERTIG >> $S/logs/rc_merged.log
