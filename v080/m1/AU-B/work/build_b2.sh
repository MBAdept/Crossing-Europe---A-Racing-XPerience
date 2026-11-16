#!/bin/bash
# usage: build_b2.sh [extra args of engine_synth3.py]   -> banks and vehicle sounds into work/b2
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B/work
R=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-2
cd "$R" || exit 1
nice -n 10 python3 tools/audio/modern/engine_synth3.py --jobs 2 --out "$W/b2" "$@" 2>&1 | grep -E 'Drehzahlpunkte|vehicle|Traceback|Error|error|File ' | cut -c1-230
