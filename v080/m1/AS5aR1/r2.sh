#!/usr/bin/env bash
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR1
echo "start $(date +%H:%M)"
$S/views.sh r1 lods
$S/tools/cycle.sh probe props/city_german_gruenderzeit --q=1
$S/views.sh r1b rail
echo "=== r2 fertig $(date +%H:%M)"
