#!/bin/bash
# queue2.sh [jobs…] – gates after queue1 (one heavy job at a time, nice 10). Log gates/queue2.log; per job "== <job> exit=N".
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R4
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-7
L=$S/gates/queue2.log
until grep -q QUEUE1_DONE $S/queue1.log; do sleep 10; done
job() { local n=$1; shift; echo "== $n start $(date +%T)" >> $L; "$@" >> $L 2>&1; echo "== $n exit=$? $(date +%T)" >> $L; }
JOBS=${*:-base_nass night weather start terrain lightbase vlights golden tests}
for j in $JOBS; do
  case $j in
  base_nass) job base_nass $S/sh/rcd.sh base check_night_nass.gd nass ;;
  head_nass) job head_nass $S/sh/rcd.sh head check_night_nass.gd nass ;;
  night) job night $S/sh/rc.sh head check_night night ;;
  weather) job weather $S/sh/rc.sh head check_weather weather ;;
  start) job start $S/sh/rc.sh head check_start_km0 start ;;
  terrain) job terrain $S/sh/rc.sh head check_terrain_cover terrain ;;
  lightbase) job lightbase $S/sh/rc.sh head check_light_base lightbase ;;
  vlights) job vlights $S/sh/rc.sh head check_vehicle_lights vlights ;;
  golden) job golden $S/sh/golden.sh ;;
  tests) job tests $S/sh/tests.sh ;;
  esac
done
echo "QUEUE2_DONE $(date +%T)" >> $L
