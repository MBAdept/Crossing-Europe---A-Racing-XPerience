#!/usr/bin/env bash
# AS5aR1 round 1: wait for the before pictures, then probe exports of the changed models
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR1
until grep -q "=== before vor fertig" $S/logs/before_vor.out 2>/dev/null; do sleep 20; done
echo "start $(date +%H:%M)"
$S/tools/cycle.sh probe props/city_german_old_fachwerk_b,props/city_hanse_gabled,props/city_german_old_barock,props/city_german_old_fachwerk
$S/tools/cycle.sh probe props/city_german_mietshaus,props/city_german_house --q=1
echo "=== probe1 fertig $(date +%H:%M)"
