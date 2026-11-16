#!/usr/bin/env bash
# AS5aR1 round 1 (continued after the background limit): fachwerk probe, bake the three exported probes, then
# mietshaus + house (full atlas), then the review pictures
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR1
source $S/env.sh
cd $WT
echo "start $(date +%H:%M)"
for id in props/city_german_old_fachwerk_b props/city_hanse_gabled props/city_german_old_barock; do
	nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$id" 2>&1 | grep -E "Modelle|Fehler|FEHLER|ERROR" | tail -3
done
$S/tools/cycle.sh probe props/city_german_old_fachwerk
$S/tools/cycle.sh probe props/city_german_mietshaus,props/city_german_house --q=1
echo "=== probe1b fertig $(date +%H:%M)"
$S/views.sh r1 close erker rail
