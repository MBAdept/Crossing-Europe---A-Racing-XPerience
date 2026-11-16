#!/bin/bash
# check_sprite_geometry.py alone (the queue was stopped by its background time limit while it ran), in the scratch copy.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM
cd "$S/mut" || exit 2
t0=$SECONDS
nice -n 10 timeout 3000 /home/user/tools/bpyenv/bin/python tools/blender/check_sprite_geometry.py --jobs 2 > "$S/exportdet/sprite_geometry.log" 2>&1
echo "check_sprite_geometry exit=$? $((SECONDS - t0)) s"
tail -5 "$S/exportdet/sprite_geometry.log"
