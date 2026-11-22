#!/bin/bash
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-RINT
while pgrep -f "sh/q2.sh" > /dev/null; do sleep 5; done
echo "q4: sportwagen start $(date +%T)"
$S/sh/rc_one.sh $S/logs/rc_night_sw$1.log res://tests/race3d/render/check_night.gd --only=spielerauto --fall=Sportwagen --save=$S/shots/night_sw$1
echo "q4: done $(date +%T)"
