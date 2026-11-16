#!/usr/bin/env bash
# KRITIK-3: prop_scene dist sheet with sprites, race look. run_dist.sh <name> <hour> <preset> <models> [extra args]
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-3/env.sh
cd "$T"
name=$1; hour=$2; preset=$3; models=$4; shift 4
start=$(date +%s)
nice -n 19 tools/models/prop_scene.sh "$K/shots/$name.png" --mode=dist --look=race --hour="$hour" --preset="$preset" --sprite --models="$models" "$@" > "$K/logs/$name.log" 2>&1
echo "$name exit $? $(( $(date +%s) - start )) s"
