#!/usr/bin/env bash
# Fix-wave helper: view.sh <jobs.json> <out dir> <sheet.png> [cols]
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/FIX0/env.sh
cd $W
nice -n 10 timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
	-s $F/tools/view_models.gd -- --jobs="$1" --out="$2" --sheet="$3" --cols="${4:-4}" 2>&1 | grep -E "VIEW|SCRIPT ERROR|ERROR|shader" | head -20
