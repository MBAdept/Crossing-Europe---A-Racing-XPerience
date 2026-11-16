#!/usr/bin/env bash
# AS5aR2: sprite geometry unchanged after the props_cities hooks (check_sprite_geometry --only props --jobs 1)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR2
source $S/env.sh
cd $WT
TAG=${1:-r}
waitmem
t0=$(date +%s)
nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/check_sprite_geometry.py --only props --jobs 1 > $S/logs/geom_$TAG.log 2>&1
echo "geom $TAG exit $? $(( $(date +%s) - t0 )) s: $(grep -c ANDERS $S/logs/geom_$TAG.log) ANDERS; $(tail -2 $S/logs/geom_$TAG.log | tr '\n' ' ')"
