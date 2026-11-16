#!/usr/bin/env bash
# AS5a2: sprite geometry gate (no sprite vertex may move)
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a2/env.sh
cd $WT
waitmem
nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/check_sprite_geometry.py --only props --jobs 1 > $S/logs/geom_$1.log 2>&1
echo "GEOM exit $? $(date +%H:%M): $(grep -E 'Sprite-Sets gebaut|CHECK|ANDERS' $S/logs/geom_$1.log | tr '\n' ' ')"
